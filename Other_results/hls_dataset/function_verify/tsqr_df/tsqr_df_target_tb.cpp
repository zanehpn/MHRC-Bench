
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "tsqr_df.cpp"

int main() {
    MATRIX_T A1[LEN] = {};
    MATRIX_T A2[LEN] = {};
    fixed_cs Q_L[Q_LEN] = {};
    fixed_cs Q_R[Q_LEN] = {};
    MATRIX_T R[LEN] = {};

    // Initialize with simple identity-like pattern
    // A1 diagonal = 1, A2 diagonal = 0
    int count = 0;
    for (int j = 0; j < COLS; j++) {
        for (int i = j; i < COLS; i++) {
            A1[count] = (i == j) ? 1.0f : 0.0f;
            A2[count] = 0.0f;
            count++;
        }
    }

    int ret = top(A1, A2, Q_L, Q_R, R);

    if (ret != 0) {
        std::cerr << "tsqr_df: top returned non-zero\n";
        return 1;
    }

    // R[0] should be the magnitude of the first diagonal element
    // For identity-like input, R[0] should be close to 1
    if (std::fabs((float)R[0] - 1.0f) > 0.1f) {
        std::cerr << "tsqr_df: R[0] = " << (float)R[0] << ", expected ~1.0\n";
        return 1;
    }

    return 0;
}
