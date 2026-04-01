#include <cmath>
#include <iostream>
#include "pool_cc_original.cpp"

int main() {
    hls::stream<float> in_stream, out_stream;

    // 4x4 input fed in row-major order
    // The pooling reads sequentially from the stream in blocks of POOL_ROWS*POOL_COLS=4
    // Window (r=0,c=0): reads 4 values -> picks max
    // Window (r=0,c=2): reads next 4 values -> picks max
    // etc.
    // So we feed values where the expected max per group of 4 is known:
    // Group 0: 1, 5, 3, 7 => max=7
    // Group 1: 2, 6, 4, 8 => max=8
    // Group 2: 9, 13, 11, 15 => max=15
    // Group 3: 10, 14, 12, 16 => max=16
    float input[16] = {
        1, 5, 3, 7,
        2, 6, 4, 8,
        9, 13, 11, 15,
        10, 14, 12, 16
    };
    for (int i = 0; i < 16; i++) in_stream.write(input[i]);

    max_pooling(in_stream, out_stream);

    float expected[4] = {7, 8, 15, 16};
    for (int i = 0; i < 4; i++) {
        float val = out_stream.read();
        if (std::fabs(val - expected[i]) > 1e-6f) {
            std::cerr << "FAIL at " << i << ": got " << val << " expected " << expected[i] << "\n";
            return 1;
        }
    }
    std::cout << "PASS: pool_cc\n";
    return 0;
}
