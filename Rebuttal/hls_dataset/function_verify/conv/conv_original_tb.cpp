
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "conv_original.cc"

int main() {
    float pad_img[PAD_IMG_ROWS][PAD_IMG_COLS] = {};
    hls::stream<float> conv_to_pool_stream;
    pad_img[0][0] = 1.0f;

    convolution(pad_img, 0, conv_to_pool_stream);

    const float expected = relu(conv_weights[0][0][0] + conv_biases[0]);
    const float observed = conv_to_pool_stream.read();
    if (std::fabs(observed - expected) > 1e-5f) {
        std::cerr << "conv first activation mismatch\n";
        return 1;
    }
    return 0;
}
