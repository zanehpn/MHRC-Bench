
#include <cstdlib>
#include <iostream>
#include "rf_doppler_spoof_engine.cpp"

int main() {
    hls::stream<axis_in_t> adc_stream;
    hls::stream<axis_out_t> alert_stream;

    // Feed AXIS_WORDS_PER_FRAME = 2*FFT_SIZE I/Q samples
    // All zeros: should produce no spoof alert (magnitude ~0, not strong)
    for (int i = 0; i < AXIS_WORDS_PER_FRAME; i++) {
        axis_in_t x;
        x.data = 0;
        x.last = (i == AXIS_WORDS_PER_FRAME - 1) ? 1 : 0;
        adc_stream.write(x);
    }

    rf_doppler_spoof_engine(adc_stream, alert_stream);

    if (alert_stream.empty()) {
        std::cerr << "rf_doppler: no output produced\n";
        return 1;
    }

    axis_out_t out = alert_stream.read();
    // With all-zero input, magnitude=0, so no spoof (code bit0=0)
    if ((int)out.data != 0) {
        std::cerr << "rf_doppler: expected no alert for zero input, got " << (int)out.data << "\n";
        return 1;
    }

    return 0;
}
