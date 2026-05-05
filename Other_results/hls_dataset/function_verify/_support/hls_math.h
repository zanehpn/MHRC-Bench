
#pragma once

#include <cmath>

namespace hls {
template <typename T>
inline auto sqrt(T value) {
    return std::sqrt((double)value);
}
inline float sqrtf(float v) { return std::sqrt(v); }
inline float expf(float v) { return std::exp(v); }
inline float powf(float base, float exp) { return std::pow(base, exp); }
inline float logf(float v) { return std::log(v); }
inline float fabsf(float v) { return std::fabs(v); }
inline void sincosf(float v, float *sinval, float *cosval) {
    *sinval = std::sin(v);
    *cosval = std::cos(v);
}
inline float sinf(float v) { return std::sin(v); }
inline float cosf(float v) { return std::cos(v); }
template <typename T>
inline T abs(T v) { return std::abs(v); }
inline float absf(float v) { return std::fabs(v); }
}  // namespace hls
