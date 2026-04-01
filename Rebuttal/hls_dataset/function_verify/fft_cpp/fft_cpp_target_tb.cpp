#include <cmath>
#include <complex>
#include <iostream>
#include "fft_cpp.cpp"

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

    // FFT of {1,0,0,0} should be {1,1,1,1}
    std::complex<double> vec2[4] = {1,0,0,0};
    FFT(vec2, 4, 1.0);
    for (int i = 0; i < 4; i++) {
        if (std::abs(vec2[i] - std::complex<double>(1,0)) > 1e-6) {
            std::cerr << "FAIL: FFT2[" << i << "] = " << vec2[i] << " expected (1,0)\n";
            return 1;
        }
    }

    std::cout << "PASS: fft_cpp\n";
    return 0;
}
