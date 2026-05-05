
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "spmv_fast_stream_original.cpp"

int main() {
    int rowPtr[NUM_ROWS + 1];
    int cols[NNZ] = {};
    DTYPE values[NNZ] = {};
    DTYPE y[SIZE] = {};
    DTYPE x[SIZE] = {};

    // Each row must have a length that is a multiple of II=9 for the
    // stream kernel to work correctly. Use 9 elements per row for the
    // first ceil(NNZ/9/NUM_ROWS)*NUM_ROWS rows, rest empty.
    // Actually: distribute so that each row gets exactly 9 or 18.
    // 256 rows * 9 = 2304; need 3277. Extra = 973 -> 108 rows get +9.
    // But 108*9=972 not 973. So 107 rows get 18, 1 row gets 9+1=10 (non-multiple)
    // This is inherently impossible with NNZ=3277 and II=9.
    //
    // Use: all 256 rows have 9 elements each = 2304 entries, set NNZ used = 2304
    // and fill cols[0..2303], values, leaving rest zero.
    // The spmv wrapper computes new_nnz from actual row lengths.
    rowPtr[0] = 0;
    for (int i = 0; i < NUM_ROWS; i++) {
        rowPtr[i + 1] = rowPtr[i] + 9;
    }
    // rowPtr[256] = 2304 < NNZ=3277, remaining cols/values are 0

    // Set row 0 col 0 to test: values[0]=2, x[0]=3 => y[0] = 6
    values[0] = 2.0f;
    cols[0] = 0;
    x[0] = 3.0f;

    spmv(rowPtr, cols, values, y, x);

    if (std::fabs(y[0] - 6.0f) > 1e-3f) {
        std::cerr << "spmv_fast_stream: y[0]=" << y[0] << " expected 6\n";
        return 1;
    }
    // Other rows: all values=0, so y[i]=0
    for (int i = 1; i < NUM_ROWS; i++) {
        if (std::fabs(y[i]) > 1e-3f) {
            std::cerr << "spmv_fast_stream: y[" << i << "]=" << y[i] << " expected 0\n";
            return 1;
        }
    }
    return 0;
}
