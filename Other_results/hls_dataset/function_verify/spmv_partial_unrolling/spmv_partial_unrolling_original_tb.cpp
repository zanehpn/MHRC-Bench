
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "spmv_partial_unrolling_original.cpp"

int main() {
    int rowPtr[NUM_ROWS + 1] = {};
    int columnIndex[NNZ] = {};
    DTYPE values[NNZ] = {};
    DTYPE y[SIZE] = {};
    DTYPE x[SIZE] = {};

    rowPtr[0] = 0;
    rowPtr[1] = 3;
    for (int i = 1; i <= NUM_ROWS; ++i) rowPtr[i] = 3;

    columnIndex[0] = 0;
    values[0] = 2.0f;
    columnIndex[1] = 1;
    values[1] = 4.0f;
    columnIndex[2] = 2;
    values[2] = -1.0f;

    x[0] = 3.0f;
    x[1] = 5.0f;
    x[2] = 7.0f;

    spmv(rowPtr, columnIndex, values, y, x);

    if (std::fabs(y[0] - 19.0f) > 1e-5f) {
        std::cerr << "spmv_partial_unrolling chunk accumulation mismatch\n";
        return 1;
    }
    return 0;
}
