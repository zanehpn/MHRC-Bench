// Testbench for cnn (CNN inference pipeline)
// Provides stub implementations for sub-layer functions, then includes the DUT.
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <cmath>
#include <iostream>

#include "cnn.hh"
#include "utils.hh"
#include "conv.hh"
#include "pool.hh"
#include "flat.hh"
#include "dense.hh"
#include "hls_stream.h"

// Stub: normalization_and_padding
void normalization_and_padding(float img_in[IMG_ROWS][IMG_COLS],
                                float img_out[PAD_IMG_ROWS][PAD_IMG_COLS]) {
    for (int i = 0; i < PAD_IMG_ROWS; i++)
        for (int j = 0; j < PAD_IMG_COLS; j++)
            img_out[i][j] = 0.0f;
    for (int i = 0; i < IMG_ROWS; i++)
        for (int j = 0; j < IMG_COLS; j++)
            img_out[i + (PAD_ROWS/2)][j + (PAD_COLS/2)] = img_in[i][j] / 255.0f;
}

// Stub: convolutional_layer
void convolutional_layer(float pad_img0[PAD_IMG_ROWS][PAD_IMG_COLS],
                         float pad_img1[PAD_IMG_ROWS][PAD_IMG_COLS],
                         float pad_img2[PAD_IMG_ROWS][PAD_IMG_COLS],
                         float pad_img3[PAD_IMG_ROWS][PAD_IMG_COLS],
                         hls::stream<float> conv_to_pool_streams[FILTERS]) {
    for (int f = 0; f < FILTERS; f++)
        for (int i = 0; i < IMG_ROWS * IMG_COLS; i++)
            conv_to_pool_streams[f].write(0.1f);
}

// Stub: max_pooling_layer
void max_pooling_layer(hls::stream<float> conv_to_pool_streams[FILTERS],
                       hls::stream<float> pool_to_flat_streams[FILTERS]) {
    for (int f = 0; f < FILTERS; f++) {
        while (!conv_to_pool_streams[f].empty())
            conv_to_pool_streams[f].read();
        for (int i = 0; i < POOL_IMG_ROWS * POOL_IMG_COLS; i++)
            pool_to_flat_streams[f].write(0.1f);
    }
}

// Stub: flattening_layer
void flattening_layer(hls::stream<float> pool_to_flat_streams[FILTERS],
                      hls::stream<float> flat_to_dense_streams[FILTERS]) {
    for (int f = 0; f < FILTERS; f++)
        while (!pool_to_flat_streams[f].empty())
            flat_to_dense_streams[f].write(pool_to_flat_streams[f].read());
}

// Stub: dense_layer
void dense_layer(hls::stream<float> flat_to_dense_streams[FILTERS],
                 hls::stream<float> dense_to_softmax_streams[FILTERS]) {
    for (int f = 0; f < FILTERS; f++) {
        while (!flat_to_dense_streams[f].empty())
            flat_to_dense_streams[f].read();
        for (int i = 0; i < DENSE_SIZE; i++)
            dense_to_softmax_streams[f].write(0.1f);
    }
}

// Stub: dense_layer_soft_max
void dense_layer_soft_max(hls::stream<float> dense_to_softmax_streams[FILTERS],
                          float prediction[DIGITS]) {
    for (int d = 0; d < DIGITS; d++) {
        float sum = 0;
        for (int f = 0; f < FILTERS; f++) {
            if (!dense_to_softmax_streams[f].empty())
                sum += dense_to_softmax_streams[f].read();
        }
        prediction[d] = sum / FILTERS;
    }
}

// Now include the DUT: cnn and dataflow_section functions
// The sub-functions are already defined above as stubs, so the DUT will call them.
#include "cnn.cc"

int main() {
    float img[IMG_ROWS][IMG_COLS] = {};
    float prediction[DIGITS] = {};
    img[0][0] = 255.0f;
    img[5][5] = 128.0f;

    cnn(img, prediction);

    bool any_nonzero = false;
    for (int i = 0; i < DIGITS; i++) {
        if (prediction[i] != 0.0f) any_nonzero = true;
    }
    if (!any_nonzero) {
        std::cerr << "FAIL: cnn pipeline produced all-zero prediction\n";
        return 1;
    }

    std::cout << "cnn: PASS\n";
    return 0;
}
