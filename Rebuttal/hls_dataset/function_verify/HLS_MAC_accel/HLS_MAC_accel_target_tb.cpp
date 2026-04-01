
#include <cstdlib>
#include <iostream>
#include "HLS_MAC_accel.cpp"

int main() {
    hls::stream<axis_t> in_stream;
    hls::stream<axis_t> out_stream;
    axis_t a{};
    axis_t b{};
    a.data = 3;
    b.data = 4;
    in_stream.write(a);
    in_stream.write(b);

    mac_top(in_stream, out_stream, 5);

    axis_t out = out_stream.read();
    if (out.data != 35 || out.last != 1) {
        std::cerr << "HLS_MAC_accel output mismatch\n";
        return 1;
    }
    return 0;
}
