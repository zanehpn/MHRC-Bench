#pragma once
#include <cstring>

// Minimal stub for ac_std_float used only by fast_float.h to_float()
template <int W, int E>
struct ac_std_float {
    unsigned int raw;

    template <typename T>
    void set_data(const T& data) {
        raw = (unsigned int)(data.to_uint());
    }

    float to_float() const {
        float f;
        std::memcpy(&f, &raw, sizeof(float));
        return f;
    }
};
