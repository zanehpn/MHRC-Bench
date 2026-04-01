#include "Example5.h"

void MatrixMultiplication(const double A[], const double B[], double C[]) {

<TARGET>
    for (int m = 0; m < M; ++m) {
      double acc = 0;
      for (int k = 0; k < K; ++k) {
        #pragma HLS PIPELINE II=1
        acc += A[n * K + k] * B[k * M + m];
      }
      C[n * M + m] = acc;
    }
  }
}
