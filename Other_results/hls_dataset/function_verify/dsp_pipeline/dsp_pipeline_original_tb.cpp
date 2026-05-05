
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "dsp_pipeline_original.cpp"

int main() {
    hls::stream<data_t> in_stream;
    hls::stream<data_t> out_stream;
    in_stream.write(4.0f);
    in_stream.write(0.0f);
    in_stream.write(0.0f);
    for (int i = 3; i < 1024; ++i) {
        in_stream.write(0.0f);
    }

    dsp_pipeline(in_stream, out_stream, 2.0f);

    const float expected0 = 2.0f;
    const float expected1 = 4.0f;
    const float expected2 = 2.0f;
    const float out0 = out_stream.read();
    const float out1 = out_stream.read();
    const float out2 = out_stream.read();
    if (std::fabs(out0 - expected0) > 1e-5f || std::fabs(out1 - expected1) > 1e-5f || std::fabs(out2 - expected2) > 1e-5f) {
        std::cerr << "dsp_pipeline FIR/gain mismatch\n";
        return 1;
    }
    return 0;
}
