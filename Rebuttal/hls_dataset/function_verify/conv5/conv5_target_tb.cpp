
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "conv5.cpp"

int main() {
    static float inp_img[INP_IMAGE_SIZE * INP_IMAGE_SIZE * INP_IMAGE_CHANNEL] = {};
    static float out_img[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH] = {};
    static float filter[FILTER_BATCH * INP_IMAGE_CHANNEL * FILTER_SIZE * FILTER_SIZE] = {};
    static float bias[FILTER_BATCH] = {};

    inp_img[0] = 1.5f;
    filter[0] = 2.0f;
    bias[0] = 0.5f;
    conv5(inp_img, out_img, filter, bias);

    if (std::fabs(out_img[0] - 3.5f) > 1e-5f) {
        std::cerr << "conv5 bias/writeback mismatch\n";
        return 1;
    }
    return 0;
}
