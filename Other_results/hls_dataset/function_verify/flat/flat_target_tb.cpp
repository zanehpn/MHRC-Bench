
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "flat.cc"

int main() {
    hls::stream<float> in_stream;
    hls::stream<float> out_stream;
    for (int i = 0; i < POOL_IMG_ROWS * POOL_IMG_COLS; ++i) {
        in_stream.write(static_cast<float>(i));
    }

    flattening(in_stream, out_stream);

    for (int i = 0; i < POOL_IMG_ROWS * POOL_IMG_COLS; ++i) {
        const float observed = out_stream.read();
        if (std::fabs(observed - static_cast<float>(i)) > 1e-5f) {
            std::cerr << "flat stream order mismatch\n";
            return 1;
        }
    }
    return 0;
}
