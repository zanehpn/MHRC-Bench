
#include <cstdlib>
#include <iostream>
#include "doHiststretch_original.cpp"

int main() {
    hls::stream<uint8_sidechannel> in_stream;
    hls::stream<uint8_sidechannel> out_stream;

    unsigned char test_vals[] = {5, 60, 150};
    int n_test = 3;

    for (int i = 0; i < 320 * 240; ++i) {
        uint8_sidechannel sample{};
        sample.data = (i < n_test) ? test_vals[i] : 0;
        sample.keep = 1;
        sample.strb = 1;
        sample.last = (i == 320 * 240 - 1) ? 1 : 0;
        in_stream.write(sample);
    }

    unsigned char xMin = 10, xMax = 110;
    doHiststretch(in_stream, out_stream, xMin, xMax);

    // Read and verify first pass outputs (just check non-crash + determinism)
    for (int i = 0; i < 320 * 240; ++i) {
        if (out_stream.empty()) {
            std::cerr << "doHiststretch: output stream ended early at " << i << "\n";
            return 1;
        }
        out_stream.read();
    }

    // Run again with same input to verify determinism
    for (int i = 0; i < 320 * 240; ++i) {
        uint8_sidechannel sample{};
        sample.data = (i < n_test) ? test_vals[i] : 0;
        sample.keep = 1;
        sample.strb = 1;
        sample.last = (i == 320 * 240 - 1) ? 1 : 0;
        in_stream.write(sample);
    }
    doHiststretch(in_stream, out_stream, xMin, xMax);

    hls::stream<uint8_sidechannel> out_stream2;
    for (int i = 0; i < 320 * 240; ++i) {
        uint8_sidechannel sample{};
        sample.data = (i < n_test) ? test_vals[i] : 0;
        sample.keep = 1;
        sample.strb = 1;
        sample.last = (i == 320 * 240 - 1) ? 1 : 0;
        in_stream.write(sample);
    }
    doHiststretch(in_stream, out_stream2, xMin, xMax);

    for (int i = 0; i < 320 * 240; ++i) {
        auto a = out_stream.read();
        auto b = out_stream2.read();
        if ((int)a.data != (int)b.data) {
            std::cerr << "doHiststretch: non-deterministic at pixel " << i << "\n";
            return 1;
        }
    }

    return 0;
}
