
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "spmv_naive_stream_original.cpp"

int main() {
    int rowPtr[NUM_ROWS + 1];
    int cols[NNZ] = {};
    DTYPE values[NNZ] = {};
    DTYPE y[SIZE] = {};
    DTYPE x[SIZE] = {};

    // Distribute NNZ entries evenly across rows
    int per_row = NNZ / NUM_ROWS;
    int extra = NNZ - per_row * NUM_ROWS;
    rowPtr[0] = 0;
    for (int i = 0; i < NUM_ROWS; i++) {
        int rlen = per_row + (i < extra ? 1 : 0);
        rowPtr[i + 1] = rowPtr[i] + rlen;
    }

    // All values/cols = 0, x = 0 → y should be all zero
    spmv(rowPtr, cols, values, y, x);

    for (int i = 0; i < NUM_ROWS; i++) {
        if (std::fabs(y[i]) > 1e-6f) {
            std::cerr << "spmv_naive_stream: y[" << i << "]=" << y[i] << " expected 0\n";
            return 1;
        }
    }
    return 0;
}
