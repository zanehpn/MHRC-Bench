
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "conv2_original.cpp"

int main() {
    static DataType inp_img[INP_IMAGE_SIZE * INP_IMAGE_SIZE * INP_IMAGE_CHANNEL] = {};
    static DataType out_img[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH] = {};
    static DataType filter_w[FILTER_BATCH * INP_IMAGE_CHANNEL * FILTER_SIZE * FILTER_SIZE] = {};
    static DataType bias_arr[FILTER_BATCH] = {};

    // Set a single known input/filter value for group 1
    inp_img[0] = 1.0f;
    filter_w[0] = 2.0f;
    bias_arr[0] = 0.5f;

    conv2(inp_img, out_img, filter_w, bias_arr);

    // The convolution of a single 1.0 pixel with a 2.0 filter weight plus 0.5 bias
    float expected = 1.0f * 2.0f + 0.5f;
    if (std::fabs(out_img[0] - expected) > 1e-4f) {
        std::cerr << "conv2 output mismatch: " << out_img[0] << " vs " << expected << "\n";
        return 1;
    }

    // Determinism check
    static DataType out_img2[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH] = {};
    conv2(inp_img, out_img2, filter_w, bias_arr);

    for (int i = 0; i < OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH; i++) {
        if (std::fabs(out_img[i] - out_img2[i]) > 1e-6f) {
            std::cerr << "conv2: non-deterministic at index " << i << "\n";
            return 1;
        }
    }

    // Test ReLU: negative bias should zero the output
    static DataType out_img3[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH] = {};
    static DataType filter_w2[FILTER_BATCH * INP_IMAGE_CHANNEL * FILTER_SIZE * FILTER_SIZE] = {};
    static DataType bias_neg[FILTER_BATCH] = {};
    bias_neg[0] = -100.0f;
    conv2(inp_img, out_img3, filter_w2, bias_neg);
    if (out_img3[0] != 0.0f) {
        std::cerr << "conv2 ReLU fail: expected 0, got " << out_img3[0] << "\n";
        return 1;
    }

    std::cout << "conv2: all tests passed\n";
    return 0;
}
