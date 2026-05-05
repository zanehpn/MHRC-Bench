
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "conv4.cpp"

int main() {
    static float inp_img[INP_IMAGE_SIZE * INP_IMAGE_SIZE * INP_IMAGE_CHANNEL] = {};
    static float out_img[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH] = {};
    static float filter[FILTER_BATCH * INP_IMAGE_CHANNEL * FILTER_SIZE * FILTER_SIZE] = {};
    static float bias[FILTER_BATCH] = {};

    inp_img[0] = 4.0f;
    filter[0] = 2.0f;
    conv4(inp_img, out_img, filter, bias);

    if (std::fabs(out_img[0] - 8.0f) > 1e-5f) {
        std::cerr << "conv4 first output mismatch\n";
        return 1;
    }
    return 0;
}
