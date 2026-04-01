
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "spmv_naive_stream.cpp"

int main() {
    int rowPtr[NUM_ROWS + 1] = {};
    int cols[NNZ] = {};
    DTYPE values[NNZ] = {};
    DTYPE y[SIZE] = {};
    DTYPE x[SIZE] = {};

    rowPtr[0] = 0;
    rowPtr[1] = 2;
    rowPtr[2] = 3;
    for (int i = 2; i <= NUM_ROWS; ++i) rowPtr[i] = 3;

    cols[0] = 0;
    values[0] = 1.0f;
    cols[1] = 2;
    values[1] = 2.0f;
    cols[2] = 1;
    values[2] = 5.0f;

    x[0] = 10.0f;
    x[1] = -1.0f;
    x[2] = 3.0f;

    spmv(rowPtr, cols, values, y, x);

    if (std::fabs(y[0] - 16.0f) > 1e-5f || std::fabs(y[1] + 5.0f) > 1e-5f) {
        std::cerr << "spmv_naive_stream row rollover mismatch\n";
        return 1;
    }
    return 0;
}
