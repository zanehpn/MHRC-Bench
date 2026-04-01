#include "ap_int.h"

#define LOG_RNS 2
#define LOG_N 3
#define RNS_NUM (1 << LOG_RNS)
#define N (1 << LOG_N)

typedef ap_uint<32> data_t;

void K_mov(data_t in[RNS_NUM*N], data_t out[RNS_NUM*N]) {
#pragma HLS INTERFACE ap_ctrl_hs port=return
  for (ap_uint<LOG_RNS+LOG_N+1> i = 0; i < RNS_NUM*N; i++) {
  #pragma HLS PIPELINE
    out[i] = in[i];

  }
}
