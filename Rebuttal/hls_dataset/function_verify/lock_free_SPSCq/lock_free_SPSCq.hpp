
#pragma once
#include <ap_int.h>
#include <hls_stream.h>
#define QDEPTH 1024
#define BITS 32
typedef ap_uint<BITS> data_t;
struct queue_state {
    ap_uint<10> head;
    ap_uint<10> tail;
};
void spsc_top(hls::stream<data_t> &in, hls::stream<data_t> &out, volatile data_t buffer_r[QDEPTH], volatile queue_state &state);
