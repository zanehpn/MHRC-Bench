#include <cmath>
#include <iostream>

#define main dut_main
#include "Test5_original.cpp"
#undef main

int main() {
    double a[N*K], b[K*M], c[N*M], c_ref[N*M];
    // Simple deterministic input
    for (int i = 0; i < N*K; i++) a[i] = (i % 7) * 0.1;
    for (int i = 0; i < K*M; i++) b[i] = (i % 5) * 0.2;

    MatrixMultiplication(a, b, c);
    Reference(a, b, c_ref);

    for (int i = 0; i < N*M; i++) {
        if (std::fabs(c[i] - c_ref[i]) > 1e-6) {
            std::cerr << "FAIL at " << i << "\n";
            return 1;
        }
    }
    std::cout << "PASS: Test5\n";
    return 0;
}
