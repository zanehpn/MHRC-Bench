
#include <cstdlib>
#include <iostream>
#include "lock_free_SPSCq_original.cpp"

int main() {
    hls::stream<data_t> in_stream;
    hls::stream<data_t> out_stream;
    static volatile data_t buffer[QDEPTH] = {};
    static queue_state state{0, 0};

    in_stream.write(42);
    spsc_top(in_stream, out_stream, buffer, state);

    if (out_stream.empty()) {
        std::cerr << "lock_free_SPSCq produced no output\n";
        return 1;
    }
    const auto out = out_stream.read();
    if (out != 42 || state.head != 1 || state.tail != 1) {
        std::cerr << "lock_free_SPSCq enqueue/dequeue mismatch\n";
        return 1;
    }
    return 0;
}
