
#pragma once
#include "../03-Headers/definitions.h"
#include "hls_stream.h"
void flattening(hls::stream<float> & pool_to_flat_stream, hls::stream<float> & flat_to_dense_stream);
void flattening_layer(hls::stream<float> pool_to_flat_streams[FILTERS], hls::stream<float> flat_to_dense_streams[FILTERS]);
