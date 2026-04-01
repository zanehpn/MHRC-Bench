#include <cmath>
#include <complex>
#include <iostream>

#define main dut_main
#include "FFT_main_original.cpp"
#undef main

int main() {
    // FFT of {1,1,1,1} should be {4, 0, 0, 0}
    std::complex<double> vec[4] = {1,1,1,1};
    FFT(vec, 4, 1.0);

    if (std::abs(vec[0] - std::complex<double>(4,0)) > 1e-6) {
        std::cerr << "FAIL: FFT[0] = " << vec[0] << " expected (4,0)\n";
        return 1;
    }
    for (int i = 1; i < 4; i++) {
        if (std::abs(vec[i]) > 1e-6) {
            std::cerr << "FAIL: FFT[" << i << "] = " << vec[i] << " expected 0\n";
            return 1;
        }
    }
    std::cout << "PASS: FFT_main\n";
    return 0;
}
