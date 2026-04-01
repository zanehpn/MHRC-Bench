
#include <cstdlib>
#include <iostream>
#include "doHiststretch.cpp"

static unsigned char expected_value(unsigned char x, unsigned char xMin, unsigned char xMax) {
    float xMax_minus_xMin = xMax - xMin;
    float y_t_float = 0.0f;
    if (x > xMax) {
        y_t_float = (x - xMax) / 2.0f + 242.0f;
    } else if (x > xMin) {
        y_t_float = (x - xMin) / xMax_minus_xMin * 230.0f + 13.0f;
    } else {
        y_t_float = x / float(xMin) * 13.0f;
    }
    return static_cast<unsigned char>(y_t_float);
}

int main() {
    hls::stream<uint8_sidechannel> in_stream;
    hls::stream<uint8_sidechannel> out_stream;

    for (int i = 0; i < 320 * 240; ++i) {
        uint8_sidechannel sample{};
        sample.data = (i == 0) ? 5 : (i == 1) ? 60 : (i == 2) ? 150 : 0;
        sample.keep = 1;
        sample.strb = 1;
        sample.last = (i == 320 * 240 - 1);
        in_stream.write(sample);
    }

    doHiststretch(in_stream, out_stream, 10, 110);

    const unsigned char expected0 = expected_value(5, 10, 110);
    const unsigned char expected1 = expected_value(60, 10, 110);
    const unsigned char expected2 = expected_value(150, 10, 110);
    auto out0 = out_stream.read();
    auto out1 = out_stream.read();
    auto out2 = out_stream.read();

    if (out0.data != expected0 || out1.data != expected1 || out2.data != expected2) {
        std::cerr << "doHiststretch output mismatch\n";
        return 1;
    }
    return 0;
}
