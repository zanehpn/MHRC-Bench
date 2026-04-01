
#include <cstdlib>
#include <iostream>
#include "doHist_original.cpp"

int main() {
    hls::stream<uint8_sidechannel> in_stream;
    int histo[256] = {};

    for (int i = 0; i < 320 * 240; ++i) {
        uint8_sidechannel sample{};
        sample.data = (i == 0) ? 7 : (i == 1) ? 7 : (i == 2) ? 3 : 0;
        in_stream.write(sample);
    }

    doHist(in_stream, histo);

    const int zeros = 320 * 240 - 3;
    if (histo[7] != 2 || histo[3] != 1 || histo[0] != zeros) {
        std::cerr << "doHist histogram mismatch\n";
        return 1;
    }
    return 0;
}
