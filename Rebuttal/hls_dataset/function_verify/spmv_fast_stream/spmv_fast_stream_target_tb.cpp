
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "spmv_fast_stream.cpp"

int main() {
    int rowPtr[NUM_ROWS + 1] = {};
    int cols[NNZ] = {};
    DTYPE values[NNZ] = {};
    DTYPE y[SIZE] = {};
    DTYPE x[SIZE] = {};

    rowPtr[0] = 0;
    rowPtr[1] = 0;
    rowPtr[2] = 1;
    for (int i = 2; i <= NUM_ROWS; ++i) rowPtr[i] = 1;

    cols[0] = 5;
    values[0] = 3.0f;
    x[5] = 2.0f;

    spmv(rowPtr, cols, values, y, x);

    if (std::fabs(y[0] - 0.0f) > 1e-5f || std::fabs(y[1] - 6.0f) > 1e-5f) {
        std::cerr << "spmv_fast_stream padding/zero-row mismatch\n";
        return 1;
    }
    return 0;
}
