
#pragma once
#include <hls_stream.h>
#include <ap_int.h>
typedef float data_t;
void dsp_pipeline(hls::stream<data_t>& in_stream, hls::stream<data_t>& out_stream, float gain);
