// Minimal mock of Mentor Graphics ac_int for C++ testbench compilation.
// Provides just enough functionality for fast_float.h.

#ifndef __AC_INT_H
#define __AC_INT_H

#include <cstdint>
#include <cstring>
#include <type_traits>

namespace ac {
  template <int N> struct log2_ceil {
    static const int val = (N <= 1) ? 0 :
                           (N <= 2) ? 1 :
                           (N <= 4) ? 2 :
                           (N <= 8) ? 3 :
                           (N <= 16) ? 4 :
                           (N <= 32) ? 5 :
                           (N <= 64) ? 6 : 7;
  };
  template <int N> struct nbits {
    static const int val = log2_ceil<N>::val + 1;
  };
}

// Bit-reference proxy
template <int W, bool S> class ac_int;

template <int W, bool S>
class ac_bit_ref {
    ac_int<W,S> &parent_;
    int bit_;
public:
    ac_bit_ref(ac_int<W,S> &p, int b) : parent_(p), bit_(b) {}
    inline operator int() const;
    inline ac_bit_ref &operator=(int v);
    ac_bit_ref &operator=(const ac_bit_ref &o) { return *this = (int)o; }
};

template <int W, bool S = true>
class ac_int {
    // Store as 64-bit; sufficient for testbench simulation up to 64 bits.
    long long val_;

    static long long mask() {
        if (W >= 64) return ~0LL;
        return (1LL << W) - 1;
    }
    void clamp() {
        val_ &= mask();
        // For signed types, sign-extend from bit W-1
        if (S && W < 64 && W > 0 && (val_ & (1LL << (W - 1)))) {
            val_ |= ~mask();
        }
    }
public:
    ac_int() : val_(0) {}
    ac_int(long long v) : val_(v) { clamp(); }
    ac_int(unsigned long long v) : val_((long long)v) { clamp(); }
    ac_int(int v) : val_(v) { clamp(); }
    ac_int(unsigned int v) : val_(v) { clamp(); }
    ac_int(long v) : val_(v) { clamp(); }
    ac_int(unsigned long v) : val_((long long)v) { clamp(); }
    ac_int(bool v) : val_(v ? 1 : 0) { clamp(); }
    ac_int(double v) : val_((long long)v) { clamp(); }
    ac_int(float v) : val_((long long)v) { clamp(); }

    // Conversion
    operator long long() const { return val_; }
    long long to_int64() const { return val_; }
    unsigned long long to_uint64() const { return (unsigned long long)val_ & mask(); }
    int to_int() const { return (int)val_; }
    unsigned int to_uint() const { return (unsigned int)(val_ & mask()); }

    // Bit access
    ac_bit_ref<W,S> operator[](int i) { return ac_bit_ref<W,S>(*this, i); }
    int operator[](int i) const { return (int)((val_ >> i) & 1); }

    // Slice: return W2 bits starting at position pos
    template <int W2>
    ac_int<W2, false> slc(int pos) const {
        long long shifted = (val_ >> pos);
        return ac_int<W2, false>(shifted);
    }

    // Reduce operations
    bool or_reduce() const { return (val_ & mask()) != 0; }
    bool and_reduce() const {
        if (W >= 64) return val_ == ~0LL;
        return (val_ & mask()) == mask();
    }

    ac_int<W, false> bit_complement() const {
        return ac_int<W, false>(~val_);
    }

    // Arithmetic
    template <int W2, bool S2>
    ac_int<(W > W2 ? W : W2) + 1, S || S2> operator+(const ac_int<W2, S2> &o) const {
        const int RW = (W > W2 ? W : W2) + 1;
        const bool RS = S || S2;
        return ac_int<RW, RS>(val_ + (long long)o);
    }
    ac_int operator+(int o) const { return ac_int(val_ + o); }
    ac_int operator+(long long o) const { return ac_int(val_ + o); }
    friend ac_int operator+(int a, const ac_int &b) { return ac_int(a + b.val_); }

    template <int W2, bool S2>
    ac_int<(W > W2 ? W : W2) + 1, true> operator-(const ac_int<W2, S2> &o) const {
        const int RW = (W > W2 ? W : W2) + 1;
        return ac_int<RW, true>(val_ - (long long)o);
    }
    ac_int operator-(int o) const { return ac_int(val_ - o); }
    ac_int operator-() const { return ac_int(-val_); }

    template <int W2, bool S2>
    ac_int operator*(const ac_int<W2, S2> &o) const {
        return ac_int(val_ * (long long)o);
    }
    ac_int operator*(int o) const { return ac_int(val_ * o); }

    // Shifts
    ac_int operator<<(int n) const { return ac_int(val_ << n); }
    template <int W2, bool S2>
    ac_int operator<<(const ac_int<W2, S2> &n) const { return ac_int(val_ << (int)(long long)n); }
    ac_int operator>>(int n) const {
        if (S) return ac_int(val_ >> n);
        return ac_int((long long)((unsigned long long)(val_ & mask()) >> n));
    }
    template <int W2, bool S2>
    ac_int operator>>(const ac_int<W2, S2> &n) const { return *this >> (int)(long long)n; }

    ac_int &operator<<=(int n) { val_ <<= n; clamp(); return *this; }
    template <int W2, bool S2>
    ac_int &operator<<=(const ac_int<W2, S2> &n) { return *this <<= (int)(long long)n; }
    ac_int &operator>>=(int n) { *this = *this >> n; return *this; }
    template <int W2, bool S2>
    ac_int &operator>>=(const ac_int<W2, S2> &n) { return *this >>= (int)(long long)n; }

    // Compound assignment
    ac_int &operator+=(int n) { val_ += n; clamp(); return *this; }
    template <int W2, bool S2>
    ac_int &operator+=(const ac_int<W2, S2> &o) { val_ += (long long)o; clamp(); return *this; }
    ac_int &operator-=(int n) { val_ -= n; clamp(); return *this; }
    template <int W2, bool S2>
    ac_int &operator-=(const ac_int<W2, S2> &o) { val_ -= (long long)o; clamp(); return *this; }

    // Bitwise
    template <int W2, bool S2>
    ac_int operator&(const ac_int<W2, S2> &o) const { return ac_int(val_ & (long long)o); }
    template <int W2, bool S2>
    ac_int operator|(const ac_int<W2, S2> &o) const { return ac_int(val_ | (long long)o); }
    template <int W2, bool S2>
    ac_int operator^(const ac_int<W2, S2> &o) const { return ac_int(val_ ^ (long long)o); }
    ac_int operator~() const { return ac_int(~val_); }

    // Comparison
    template <int W2, bool S2>
    bool operator==(const ac_int<W2, S2> &o) const { return val_ == (long long)o; }
    bool operator==(int o) const { return val_ == o; }
    bool operator==(long long o) const { return val_ == o; }
    template <int W2, bool S2>
    bool operator!=(const ac_int<W2, S2> &o) const { return val_ != (long long)o; }
    bool operator!=(int o) const { return val_ != o; }
    template <int W2, bool S2>
    bool operator<(const ac_int<W2, S2> &o) const { return val_ < (long long)o; }
    bool operator<(int o) const { return val_ < o; }
    template <int W2, bool S2>
    bool operator<=(const ac_int<W2, S2> &o) const { return val_ <= (long long)o; }
    bool operator<=(int o) const { return val_ <= o; }
    template <int W2, bool S2>
    bool operator>(const ac_int<W2, S2> &o) const { return val_ > (long long)o; }
    bool operator>(int o) const { return val_ > o; }
    template <int W2, bool S2>
    bool operator>=(const ac_int<W2, S2> &o) const { return val_ >= (long long)o; }
    bool operator>=(int o) const { return val_ >= o; }

    // Assignment
    ac_int &operator=(long long v) { val_ = v; clamp(); return *this; }
    ac_int &operator=(int v) { val_ = v; clamp(); return *this; }
    ac_int &operator=(unsigned int v) { val_ = v; clamp(); return *this; }
    ac_int &operator=(bool v) { val_ = v ? 1 : 0; clamp(); return *this; }
    template <int W2, bool S2>
    ac_int &operator=(const ac_int<W2, S2> &o) { val_ = (long long)o; clamp(); return *this; }

    // Needed by ac_bit_ref
    void set_bit(int i, int v) {
        if (v) val_ |= (1LL << i);
        else   val_ &= ~(1LL << i);
        clamp();
    }
    int get_bit(int i) const { return (int)((val_ >> i) & 1); }
};

// ac_bit_ref implementation
template <int W, bool S>
inline ac_bit_ref<W,S>::operator int() const { return parent_.get_bit(bit_); }

template <int W, bool S>
inline ac_bit_ref<W,S> &ac_bit_ref<W,S>::operator=(int v) {
    parent_.set_bit(bit_, v & 1);
    return *this;
}

#endif // __AC_INT_H
