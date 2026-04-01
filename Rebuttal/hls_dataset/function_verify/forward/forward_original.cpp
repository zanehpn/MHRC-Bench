#include "forward.h"
#include "config.h"
#include <cstdint>
#include <cstring>

#include "hls_math.h"

// neural net blocks; the dynamics of the Transformer
template <int S>

// o = output, x = input, weight = array of gain params
void rmsnorm(float o[S], float x[S], float weight[S]) {
#pragma HLS INLINE off
#pragma HLS ALLOCATION instances = fmul limit = 1 operation
#pragma HLS ALLOCATION instances = fadd limit = 1 operation
#pragma HLS ALLOCATION instances = fdiv limit = 1 operation
#pragma HLS ALLOCATION instances = fsqrt limit = 1 operation

  // calculate sum of squares
  float ss = 0.0f;
sum_of_squares:
  for (int j = 0; j < S; j++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    float x_j = x[j];
    ss += x_j * x_j;
  }
  ss /= S;
  ss += 1e-5f;
  ss = 1.0f / hls::sqrtf(ss);
// normalize and scale
norm_and_scale:
  for (int j = 0; j < S; j++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    // o[j] = weight[j] * (ss * x[j]);
    float x_j = x[j];
    float weight_j = weight[j];
    o[j] = weight_j * (ss * x_j);
  }
}

template <int MAXSIZE> void softmax(float *x, int size) {
#pragma HLS INLINE off
#pragma HLS ALLOCATION instances = fcmp limit = 1 operation
#pragma HLS ALLOCATION instances = fadd limit = 1 operation
#pragma HLS ALLOCATION instances = fmul limit = 1 operation
#pragma HLS ALLOCATION instances = fdiv limit = 1 operation
#pragma HLS ALLOCATION instances = fsub limit = 1 operation

  // find max value (for numerical stability)
  float buffer[MAXSIZE];
#pragma HLS ARRAY_RESHAPE variable = buffer type = complete dim = 0
  float max_val = x[0];
max:
  for (int i = 1; i < size; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    float x_i = x[i];
    if (x_i > max_val) {
      max_val = x_i;
    }
  }
  // exp and sum

exp:
  for (int i = 0; i < size; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    float x_i = hls::expf(x[i] - max_val);
    buffer[i] = x_i;
  }
  float sum = 0.0f;
sum:
  for (int i = 0; i < size; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    sum += buffer[i];
  }
  // normalize
  const float inv_sum = 1.0 / sum;
norm:
  for (int i = 0; i < size; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    x[i] = buffer[i] * inv_sum;
  }
}

template <int N, int D>
void matmul(float *xout, int8_t *xq, float *xs, int8_t *wq, float *ws) {
#pragma HLS INLINE off

  // W (d,n) @ x (n,) -> xout (d,)
  static int8_t x_buffer[N];
#pragma HLS ARRAY_PARTITION variable = x_buffer type = cyclic factor =         \
    GS dim = 1

  static float xs_buffer[N / GS];
#pragma HLS ARRAY_PARTITION variable = xs_buffer type = cyclic factor =        \
    GS dim = 1

  // Load xq and xs into local buffers
x_buff:
  for (int i = 0; i < N; i++) {
#pragma HLS pipeline II = 1
    x_buffer[i] = xq[i];
  }
xs_buff:
  for (int j = 0; j <= N - GS; j += GS) {
#pragma HLS pipeline II = 1
    xs_buffer[j / GS] = xs[j / GS];
  }

matmul1:
  for (int i = 0; i < D; i++) {
    const int w_row_offset = i * N;
    const int ws_row_offset = i * (N / GS);

    xout[i] = 0.0f;

  matmul2:
    for (int j = 0; j <= N - GS; j += GS) {
#pragma HLS pipeline II = 1
      int8_t ival = 0;
    matmul3:
      for (int k = 0; k < GS; k++) {
#pragma HLS pipeline II = 1
        int8_t in_val = x_buffer[j + k];
        int8_t w_val = wq[w_row_offset + j + k];
        if (in_val == 1)
          ival += w_val;
        else if (in_val == -1)
          ival -= w_val;
      }
      // store partial result in array
      xout[i] += ((float)ival) * ws[ws_row_offset + j / GS] * xs_buffer[j / GS];
    }
  }
}

extern "C" void
forward(Transformer<dim, hidden_dim, n_layers, n_heads, n_kv_heads, vocab_size,
                    seq_len, GS> *transformer,
        int token, int pos,
        float key_cache[n_layers * seq_len * ((dim * n_kv_heads) / n_heads)],
        float value_cache[n_layers * seq_len * ((dim * n_kv_heads) / n_heads)],
        float *out) {
#pragma HLS INTERFACE m_axi port = transformer offset = slave bundle = gmem0
#pragma HLS INTERFACE m_axi port = out offset = slave bundle = gmem1

// Area optimization directives
#pragma HLS ALLOCATION instances = fadd limit = 2 operation
#pragma HLS ALLOCATION instances = fmul limit = 2 operation
#pragma HLS ALLOCATION instances = fsub limit = 1 operation
#pragma HLS ALLOCATION instances = fdiv limit = 1 operation
#pragma HLS ALLOCATION instances = fcmp limit = 1 operation
#pragma HLS ALLOCATION instances = fsqrt limit = 1 operation
#pragma HLS ALLOCATION instances = add limit = 2 operation
#pragma HLS ALLOCATION instances = mul limit = 2 operation
#pragma HLS ALLOCATION instances = rmsnorm limit = 1 function
#pragma HLS ALLOCATION instances = matmul limit = 1 function
#pragma HLS ALLOCATION instances = softmax limit = 1 function

  // a few convenience variables
  auto w = &transformer->weights;
  static float x[config.dim]; // activation at current time stamp (dim,)
#pragma HLS ARRAY_RESHAPE variable = x type = block factor = 4 dim = 1
  static float xb[config.dim]; // same, but inside a residual branch (dim,)
#pragma HLS ARRAY_RESHAPE variable = xb type = block factor = 4 dim = 1
  static float
      xb2[config.dim]; // an additional buffer just for convenience (dim,)
#pragma HLS ARRAY_RESHAPE variable = xb2 type = block factor = 4 dim = 1
  static float hb[config.hidden_dim]; // buffer for hidden dimension in the ffn
                                      // (hidden_dim,)
#pragma HLS ARRAY_RESHAPE variable = hb type = block factor = 4 dim = 1
  static float hb2[config.hidden_dim]; // buffer for hidden dimension in the ffn
                                       // (hidden_dim,)
#pragma HLS ARRAY_RESHAPE variable = hb2 type = block factor = 4 dim = 1
  static QuantizedTensor<config.dim> xq;        // quantized x (dim,)
  static QuantizedTensor<config.hidden_dim> hq; // quantized hb (hidden_dim,)
  static float q[config.dim];                   // query (dim,)
#pragma HLS ARRAY_RESHAPE variable = q type = block factor = 4 dim = 1
  static float
      k[(config.dim * config.n_kv_heads) / config.n_heads]; // key (dim,)
#pragma HLS ARRAY_RESHAPE variable = k type = block factor = 4 dim = 1
  static float
      v[(config.dim * config.n_kv_heads) / config.n_heads]; // value (dim,)
#pragma HLS ARRAY_RESHAPE variable = v type = block factor = 4 dim = 1
  static float
      att[config.n_heads * config.seq_len]; // buffer for scores/attention
                                            // values (n_heads, seq_len)
#pragma HLS ARRAY_RESHAPE variable = att type = block factor = 4 dim = 1

  constexpr int kv_dim = (config.dim * config.n_kv_heads) / config.n_heads;
  constexpr int kv_mul =
      config.n_heads /
      config.n_kv_heads; // integer multiplier of the kv sharing in multiquery
  constexpr int head_size = dim / config.n_heads;

  // copy the token embedding into x
  std::memcpy(x, w->token_embedding_table + token * dim, dim * sizeof(float));

// forward all the layers
main_forward_loop:
  for (int l = 0; l < config.n_layers; l++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
    // attention rmsnorm
    rmsnorm<dim>(xb, x, w->rms_att_weight + l * dim);

    // qkv matmuls for this position
    quantize(&xq, xb, GS);
    matmul<dim, dim>(q, xq.q, xq.s, (w->wq + l)->q, (w->wq + l)->s);
    matmul<dim, kv_dim>(k, xq.q, xq.s, (w->wk + l)->q, (w->wk + l)->s);
    matmul<dim, kv_dim>(v, xq.q, xq.s, (w->wv + l)->q, (w->wv + l)->s);

  // RoPE relative positional encoding: complex-valued rotate q and k in each
  // head Process the portion where both query and key vectors are involved (i <
  // kv_dim)
  rotation1:
    // Rotation for both query and key vectors (i < kv_dim)
    for (int i = 0; i < kv_dim; i += 2) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
      int head_dim = i % head_size;
      float freq = 1.0f / hls::powf(10000.0f, head_dim / (float)head_size);
      float val = pos * freq;
      float fcr, fci;
      hls::sincosf(val, &fci, &fcr);

      // Rotate the query vector
      float v0_q = q[i];
      float v1_q = q[i + 1];
      q[i] = v0_q * fcr - v1_q * fci;
      q[i + 1] = v0_q * fci + v1_q * fcr;

      // Rotate the key vector
      float v0_k = k[i];
      float v1_k = k[i + 1];
      k[i] = v0_k * fcr - v1_k * fci;
      k[i + 1] = v0_k * fci + v1_k * fcr;
    }
  rotation2:
    // Rotation for only the query vector (i >= kv_dim)
    for (int i = kv_dim; i < dim; i += 2) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
      int head_dim = i % head_size;
      float freq = 1.0f / hls::powf(10000.0f, head_dim / (float)head_size);
      float val = pos * freq;
      float fcr, fci;
      hls::sincosf(val, &fci, &fcr);

      // Rotate only the query vector
      float v0 = q[i];
      float v1 = q[i + 1];
      q[i] = v0 * fcr - v1 * fci;
      q[i + 1] = v0 * fci + v1 * fcr;
    }
    // save key,value at this time step (pos) to our kv cache
    int loff =
        l * config.seq_len * kv_dim; // kv cache layer offset for convenience
    float *key_cache_row = key_cache + loff + pos * kv_dim;
    float *value_cache_row = value_cache + loff + pos * kv_dim;

    std::memcpy(key_cache_row, k, kv_dim * sizeof(*key_cache_row));
    std::memcpy(value_cache_row, v, kv_dim * sizeof(*value_cache_row));

    // multihead attention. iterate over all heads
    int h;

  multihead_attention:
    for (h = 0; h < n_heads; h++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
      const int q_offset = h * head_size;
      const int att_offset = h * seq_len;
    iterate:
      for (int t = 0; t <= pos; t++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
        const int key_offset = loff + t * kv_dim + (h / kv_mul) * head_size;
        float score = 0.0f;
        for (int i = 0; i < head_size; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
          score += q[i + q_offset] * key_cache[i + key_offset];
        }
        score /= hls::sqrtf(head_size);
        att[t + att_offset] = score;
      }

      softmax<257>(att + att_offset, pos + 1);

      const int xb_offset = h * head_size;
      memset(xb + xb_offset, 0, head_size * sizeof(float));
    acc:
      for (int t = 0; t <= pos; t++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
        const int v_offset = loff + t * kv_dim + (h / kv_mul) * head_size;
        float a = att[t + att_offset];
      acc_inner:
        for (int i = 0; i < head_size; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
          xb[i + xb_offset] += a * value_cache[i + v_offset];
        }
      }
    }

    // final matmul to get the output of the attention
    quantize(&xq, xb, GS);
    matmul<dim, dim>(xb2, xq.q, xq.s, (w->wo + l)->q, (w->wo + l)->s);

  residual:
    for (int i = 0; i < dim; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
      x[i] += xb2[i];
    }

    // ffn rmsnorm
    rmsnorm<dim>(xb, x, w->rms_ffn_weight + l * dim);

    // Now for FFN in PyTorch we have: self.w2(F.silu(self.w1(x)) * self.w3(x))
    quantize(&xq, xb, GS);
    matmul<dim, hidden_dim>(hb, xq.q, xq.s, (w->w1 + l)->q, (w->w1 + l)->s);
    matmul<dim, hidden_dim>(hb2, xq.q, xq.s, (w->w3 + l)->q, (w->w3 + l)->s);
    float hb_out[hidden_dim];
#pragma HLS ARRAY_RESHAPE variable = hb_out type = block factor = 4 dim = 1
  swi_glu:
    for (int i = 0; i < hidden_dim; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
      float val = hb[i];
      // silu(x)=x*σ(x), where σ(x) is the logistic sigmoid
      val *= (1.0f / (1.0f + hls::expf(-val)));
      // elementwise multiply with w3(x)
      val *= hb2[i];
      hb_out[i] = val;
    }
    std::memcpy(hb, hb_out, hidden_dim * sizeof(float));

    quantize(&hq, hb, GS);
    matmul<hidden_dim, dim>(xb, hq.q, hq.s, (w->w2 + l)->q, (w->w2 + l)->s);

  residual2:
    for (int i = 0; i < dim; i++) {
#pragma HLS PIPELINE off
#pragma HLS UNROLL factor = 1
      x[i] += xb[i];
    }
  }

  // final rmsnorm
  rmsnorm<dim>(x, x, w->rms_final_weight);

  // classifier into logits
  quantize(&xq, x, GS);
  matmul<dim, vocab_size>(out, xq.q, xq.s, w->wcls->q, w->wcls->s);
}
