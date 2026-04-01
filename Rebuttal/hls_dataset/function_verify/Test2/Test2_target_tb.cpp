#include <cmath>
#include <iostream>

#define main dut_main
#include "Test2.cpp"
#undef main

int main() {
    float in[N*M], out1[N*M] = {}, out2[N*M] = {};
    for (int i = 0; i < N*M; i++) in[i] = (float)(i % 11);

    Stencil2D(in, out1);
    Reference(in, out2);

    for (int i = 0; i < N*M; i++) {
        if (std::fabs(out1[i] - out2[i]) > 1e-4f) {
            std::cerr << "FAIL at " << i << "\n";
            return 1;
        }
    }
    std::cout << "PASS: Test2\n";
    return 0;
}
