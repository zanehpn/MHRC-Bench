
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "Example5_original.cpp"

int main() {
    double A[N * K] = {};
    double B[K * M] = {};
    double C[N * M] = {};
    A[0] = 2.0;
    B[0] = 3.0;

    MatrixMultiplication(A, B, C);

    if (std::fabs(C[0] - 6.0) > 1e-9) {
        std::cerr << "Example5 matrix multiply mismatch\n";
        return 1;
    }
    return 0;
}
