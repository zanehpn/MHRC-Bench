#include <cmath>
#include <iostream>
#include <vector>

#define main dut_main
#include "Test3_original.cpp"
#undef main

int main() {
    float in[N*M], out1[N*M] = {}, out2[N*M] = {};
    for (int i = 0; i < N*M; i++) in[i] = (float)(i % 7) * 0.5f;

    Example3(in, out1);
    Reference(in, out2);

    // The comparison loop (the TARGET) iterates i from 0 to N-1
    // If TARGET is removed, the comparison never runs, so mismatches go undetected
    // But in our TB we check directly:
    for (int i = 1; i < N-1; i++) {
        for (int j = 0; j < M; j++) {
            if (std::fabs(out1[i*M+j] - out2[i*M+j]) > 1e-4f) {
                std::cerr << "FAIL at (" << i << "," << j << ")\n";
                return 1;
            }
        }
    }
    std::cout << "PASS: Test3\n";
    return 0;
}
