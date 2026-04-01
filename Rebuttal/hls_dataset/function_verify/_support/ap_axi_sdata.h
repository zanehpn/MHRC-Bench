
#pragma once

#include "ap_int.h"

template <int D, int U, int TI, int TD>
struct ap_axiu {
    ap_uint<D> data{};
    ap_uint<((D + 7) / 8)> keep{};
    ap_uint<((D + 7) / 8)> strb{};
    ap_uint<U> user{};
    ap_uint<1> last{};
    ap_uint<TI> id{};
    ap_uint<TD> dest{};
};

namespace hls {
template <typename T, int U, int TI, int TD>
struct axis {
    T data{};
    ap_uint<1> last{};
    ap_uint<1> keep{};
    ap_uint<1> strb{};
    ap_uint<U> user{};
    ap_uint<TI> id{};
    ap_uint<TD> dest{};
};
}  // namespace hls
