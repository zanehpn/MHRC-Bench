// Minimal mock of Mentor Graphics ac_fixed for C++ testbench compilation.
// Provides just enough functionality for fast_float.h.

#ifndef __AC_FIXED_H
#define __AC_FIXED_H

#include "ac_int.h"

template <int W, int I, bool S = true, int Q = 0, int O = 0>
class ac_fixed {
    // Store value internally as a double for simulation simplicity.
    double val_;

    static double scale() { return (double)(1LL << (W - I)); }

public:
    ac_fixed() : val_(0) {}
    ac_fixed(double v) : val_(v) {}
    ac_fixed(float v) : val_((double)v) {}
    ac_fixed(int v) : val_((double)v) {}
    ac_fixed(long long v) : val_((double)v) {}

    operator double() const { return val_; }
    operator float() const { return (float)val_; }
    operator int() const { return (int)val_; }

    // Bit access (approximate: convert to fixed-point integer, then access bit)
    int operator[](int i) const {
        long long fixed_val = (long long)(val_ * scale());
        return (int)((fixed_val >> i) & 1);
    }

    // Arithmetic
    ac_fixed operator+(const ac_fixed &o) const { return ac_fixed(val_ + o.val_); }
    ac_fixed operator-(const ac_fixed &o) const { return ac_fixed(val_ - o.val_); }
    ac_fixed operator*(const ac_fixed &o) const { return ac_fixed(val_ * o.val_); }

    bool operator==(const ac_fixed &o) const { return val_ == o.val_; }
    bool operator<(const ac_fixed &o) const { return val_ < o.val_; }
    bool operator>(const ac_fixed &o) const { return val_ > o.val_; }

    ac_fixed &operator=(double v) { val_ = v; return *this; }
    ac_fixed &operator=(float v) { val_ = (double)v; return *this; }
    ac_fixed &operator=(int v) { val_ = (double)v; return *this; }
};

#endif // __AC_FIXED_H
