#include <cmath>
#include <iostream>

#include "../spmv.h"
#include "../spmv_original.cpp"

int main() {
  static int rowPtr[NUM_ROWS + 1] = {0};
  static int columnIndex[NNZ] = {0};
  static DTYPE values[NNZ] = {0};
  static DTYPE x[SIZE] = {0};
  static DTYPE y[SIZE] = {0};
  static DTYPE expected[SIZE] = {0};
  static DTYPE dense[SIZE][SIZE] = {{0}};

  rowPtr[0] = 0;
  rowPtr[1] = 2;
  rowPtr[2] = 3;
  rowPtr[3] = 5;
  for (int i = 4; i <= NUM_ROWS; ++i) {
    rowPtr[i] = 5;
  }

  columnIndex[0] = 0;
  values[0] = 1.5f;
  columnIndex[1] = 3;
  values[1] = -2.0f;
  columnIndex[2] = 1;
  values[2] = 4.0f;
  columnIndex[3] = 0;
  values[3] = 0.5f;
  columnIndex[4] = 2;
  values[4] = 3.0f;

  x[0] = 2.0f;
  x[1] = -1.0f;
  x[2] = 4.0f;
  x[3] = 1.0f;

  for (int r = 0; r < 3; ++r) {
    for (int k = rowPtr[r]; k < rowPtr[r + 1]; ++k) {
      dense[r][columnIndex[k]] = values[k];
    }
  }

  mv(dense, expected, x);
  spmv(rowPtr, columnIndex, values, y, x);

  for (int i = 0; i < SIZE; ++i) {
    if (std::fabs(y[i] - expected[i]) > 1e-5f) {
      std::cerr << "Mismatch at row " << i << ": got " << y[i]
                << ", expected " << expected[i] << "\n";
      return 1;
    }
  }

  std::cout << "spmv target behavior verified\n";
  return 0;
}
