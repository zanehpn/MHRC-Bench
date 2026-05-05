#include "config.h"
#include "typedefs.h"
#include <cstring>
#include <math.h>

extern "C" void
forward(Transformer<dim, hidden_dim, n_layers, n_heads, n_kv_heads, vocab_size,
                    seq_len, GS> *transformer,
        int token, int pos,
        float key_cache[n_layers * seq_len * ((dim * n_kv_heads) / n_heads)],
        float value_cache[n_layers * seq_len * ((dim * n_kv_heads) / n_heads)],
        float *out);

template <int S> void dequantize(QuantizedTensor<S> *qx, float x[S], int GS) {
#pragma HLS INLINE off
#pragma HLS ALLOCATION instances = fmul limit = 1 operation
#pragma HLS ALLOCATION instances = mul limit = 1 operation

  for (int i = 0; i < S; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    x[i] = qx->q[i] * qx->s[i / GS];
  }
}

template <int S> void quantize(QuantizedTensor<S> *qx, float x[S], int GS) {
#pragma HLS INLINE off
// Severely limit all floating point operations for maximum area savings
#pragma HLS ALLOCATION instances = fadd limit = 1 operation
#pragma HLS ALLOCATION instances = fsub limit = 1 operation
#pragma HLS ALLOCATION instances = fmul limit = 1 operation
#pragma HLS ALLOCATION instances = fdiv limit = 1 operation
#pragma HLS ALLOCATION instances = fcmp limit = 1 operation
#pragma HLS ALLOCATION instances = add limit = 1 operation
#pragma HLS ALLOCATION instances = mul limit = 1 operation
#pragma HLS ALLOCATION instances = icmp limit = 1 operation

  constexpr int num_groups = S / 64;
  constexpr float Q_MAX = 1.0f; // Maximum value for ternary quantization

  // Use single small buffers instead of large partitioned arrays
  static float scale_buffer[num_groups];
  static int8_t quantized_buffer[S];

  // Remove all array partitioning to save LUTs
  // No pragma HLS ARRAY_PARTITION - use default single-port memories

main_loop:
  for (int group = 0; group < num_groups; group++) {
    // Remove all unrolling and pipelining for maximum area savings
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1

    float wmax = 0.0;
    int base_idx = group * GS;

  // Calculate the max absolute value in the current group - sequential
  // processing
  max:
    for (int i = 0; i < GS; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
      float val = fabs(x[base_idx + i]);
      if (val > wmax) {
        wmax = val;
      }
    }

    // Calculate and store the scaling factor
    float scale = wmax / Q_MAX;
    scale_buffer[group] = scale;

  // Calculate and store the quantized values - sequential processing
  quantize_values:
    for (int i = 0; i < GS; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1

      float quant_value = (scale != 0.0f) ? x[base_idx + i] / scale : 0.0f;
      int8_t quantized = (quant_value > 0.5f)    ? 1
                         : (quant_value < -0.5f) ? -1
                                                 : 0; // ternary quantization
      quantized_buffer[base_idx + i] = quantized;
    }
  }

// Copy results - these will be sequential memory accesses
copy_q:
  for (int i = 0; i < S; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    qx->q[i] = quantized_buffer[i];
  }

copy_s:
  for (int i = 0; i < num_groups; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    qx->s[i] = scale_buffer[i];
  }
}
