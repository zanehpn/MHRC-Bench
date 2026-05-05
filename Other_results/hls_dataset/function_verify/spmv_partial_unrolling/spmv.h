
#pragma once
const static int SIZE = 256;
const static int NNZ = 3277;
const static int NUM_ROWS = 256;
typedef float DTYPE;
void spmv(int rowPtr[NUM_ROWS + 1], int columnIndex[NNZ], DTYPE values[NNZ], DTYPE y[SIZE], DTYPE x[SIZE]);
