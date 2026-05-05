
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "dense_original.cc"

int main() {
    hls::stream<float> flat_to_dense_stream;
    hls::stream<float> dense_to_softmax_stream;

    flat_to_dense_stream.write(1.0f);
    for (int i = 1; i < FLAT_SIZE / FILTERS; ++i) {
        flat_to_dense_stream.write(0.0f);
    }

    dense(flat_to_dense_stream, 0, dense_to_softmax_stream);

    for (int d = 0; d < DENSE_SIZE; ++d) {
        const float observed = dense_to_softmax_stream.read();
        const float expected = dense_weights[0][d];
        if (std::fabs(observed - expected) > 1e-5f) {
            std::cerr << "dense output mismatch at " << d << "\n";
            return 1;
        }
    }
    return 0;
}
