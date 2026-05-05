
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "norm2_original.cpp"

int main() {
    static float inp_img[INP_IMAGE_SIZE * INP_IMAGE_SIZE * INP_IMAGE_CHANNEL] = {};
    static float out_img[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * OUT_IMAGE_CHANNEL] = {};

    const int x = 0;
    const int y = 0;
    for (int c = 0; c < 5; ++c) {
        inp_img[c * INP_IMAGE_SIZE * INP_IMAGE_SIZE + x * INP_IMAGE_SIZE + y] = float(c + 1);
    }

    norm2(inp_img, out_img);

    const float sum = 1.0f + 4.0f + 9.0f + 16.0f + 25.0f;
    const float expected = 3.0f / std::pow(1.0f + 0.00002f * sum, 0.75f);
    const int index = 2 * INP_IMAGE_SIZE * INP_IMAGE_SIZE + x * INP_IMAGE_SIZE + y;
    if (std::fabs(out_img[index] - expected) > 1e-5f) {
        std::cerr << "norm2 channel-window normalization mismatch\n";
        return 1;
    }
    return 0;
}
