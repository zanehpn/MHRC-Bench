#include <cstdio>
#include <cstring>
#include <iostream>

#define main dut_main
#include "fft_1_original.cpp"
#undef main

int main() {
    // Forward FFT on linear ramp and check golden output values
    for (int j = 0; j < SAMPLE_SZ; j++) {
        inBuf[j] = j - (SAMPLE_SZ >> 1);
    }
    fix_fftr(FFT_SAMP, 0);

    // Hardcoded golden values from verified correct implementation
    if (inBuf[0] != -257) { std::cerr << "FAIL: [0]=" << inBuf[0] << " expected -257\n"; return 1; }
    if (inBuf[1] != 39)   { std::cerr << "FAIL: [1]=" << inBuf[1] << " expected 39\n"; return 1; }
    if (inBuf[10] != 3)   { std::cerr << "FAIL: [10]=" << inBuf[10] << " expected 3\n"; return 1; }
    if (inBuf[100] != -1) { std::cerr << "FAIL: [100]=" << inBuf[100] << " expected -1\n"; return 1; }
    if (inBuf[500] != 1)  { std::cerr << "FAIL: [500]=" << inBuf[500] << " expected 1\n"; return 1; }

    std::cout << "PASS: fft_1\n";
    return 0;
}
