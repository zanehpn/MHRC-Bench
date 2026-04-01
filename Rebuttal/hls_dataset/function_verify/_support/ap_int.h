
#pragma once

#include <cstdint>
#include <cstring>
#include <type_traits>

// ---------------------------------------------------------------------------
// Lightweight ap_int / ap_uint emulation for C++ testbenches.
// Supports: arithmetic, comparison, bitwise ops, bit-indexing [i],
// range selection (hi,lo), and concatenation via operator,().
// ---------------------------------------------------------------------------

// Forward declarations
template <int W, bool S> class ap_int_base;

// ---- Bit-reference (returned by operator[]) ----
template <int W, bool S>
class ap_bit_ref {
    ap_int_base<W,S> &parent_;
    int bit_;
public:
    ap_bit_ref(ap_int_base<W,S> &p, int b) : parent_(p), bit_(b) {}
    operator int() const;
    ap_bit_ref &operator=(int v);
    ap_bit_ref &operator=(const ap_bit_ref &o) { return *this = (int)o; }
};

// ---- Range-reference (returned by operator()) ----
template <int W, bool S>
class ap_range_ref {
    ap_int_base<W,S> &parent_;
    int hi_, lo_;
public:
    ap_range_ref(ap_int_base<W,S> &p, int h, int l) : parent_(p), hi_(h), lo_(l) {}
    int width() const { return hi_ - lo_ + 1; }

    operator long long() const;
    operator unsigned long long() const { return (unsigned long long)(long long)(*this); }
    operator int() const { return (int)(long long)(*this); }
    operator unsigned int() const { return (unsigned int)(long long)(*this); }
    operator long() const { return (long)(long long)(*this); }

    template <int W2, bool S2>
    operator ap_int_base<W2,S2>() const {
        return ap_int_base<W2,S2>((long long)(*this));
    }

    ap_range_ref &operator=(long long v);

    template <int W2, bool S2>
    ap_range_ref &operator=(const ap_int_base<W2,S2> &v) {
        return *this = (long long)v;
    }

    ap_range_ref &operator=(const ap_range_ref &o) {
        return *this = (long long)o;
    }

    template <int W2, bool S2>
    ap_range_ref &operator=(const ap_range_ref<W2,S2> &o) {
        return *this = (long long)o;
    }

    // XOR-assign
    ap_range_ref &operator^=(long long v) {
        long long cur = (long long)(*this);
        *this = cur ^ v;
        return *this;
    }
    // OR-assign
    ap_range_ref &operator|=(long long v) {
        long long cur = (long long)(*this);
        *this = cur | v;
        return *this;
    }

    // Comparisons
    bool operator==(long long v) const { return (long long)(*this) == v; }
    bool operator!=(long long v) const { return (long long)(*this) != v; }
    bool operator<(long long v) const { return (long long)(*this) < v; }
    bool operator>(long long v) const { return (long long)(*this) > v; }
    bool operator<=(long long v) const { return (long long)(*this) <= v; }
    bool operator>=(long long v) const { return (long long)(*this) >= v; }

    bool operator==(const char *s) const {
        // Compare with binary string like "1" or "0" or "11111..."
        long long val = 0;
        int len = 0;
        while (s[len]) len++;
        for (int i = 0; i < len; i++)
            val = (val << 1) | (s[i] - '0');
        return (long long)(*this) == val;
    }
    bool operator!=(const char *s) const { return !(*this == s); }

    // Arithmetic
    long long operator+(long long v) const { return (long long)(*this) + v; }
    long long operator-(long long v) const { return (long long)(*this) - v; }
    long long operator*(long long v) const { return (long long)(*this) * v; }
    long long operator^(long long v) const { return (long long)(*this) ^ v; }
    long long operator|(long long v) const { return (long long)(*this) | v; }
    long long operator&(long long v) const { return (long long)(*this) & v; }
    long long operator<<(int v) const { return (long long)(*this) << v; }
    long long operator>>(int v) const { return (long long)(*this) >> v; }

    // Cross-type operators with ap_int_base
    template <int W2, bool S2>
    ap_int_base<W2,S2> operator+(const ap_int_base<W2,S2> &v) const { return ap_int_base<W2,S2>((long long)(*this) + (long long)v); }
    template <int W2, bool S2>
    ap_int_base<W2,S2> operator-(const ap_int_base<W2,S2> &v) const { return ap_int_base<W2,S2>((long long)(*this) - (long long)v); }
    template <int W2, bool S2>
    ap_int_base<W2,S2> operator*(const ap_int_base<W2,S2> &v) const { return ap_int_base<W2,S2>((long long)(*this) * (long long)v); }
    template <int W2, bool S2>
    long long operator^(const ap_int_base<W2,S2> &v) const { return (long long)(*this) ^ (long long)v; }
    template <int W2, bool S2>
    long long operator|(const ap_int_base<W2,S2> &v) const { return (long long)(*this) | (long long)v; }
    template <int W2, bool S2>
    bool operator>=(const ap_int_base<W2,S2> &v) const { return (long long)(*this) >= (long long)v; }

    long long to_uint() const { return (long long)(*this); }
    long long to_int() const { return (long long)(*this); }
};

// Non-member: ap_int_base op range_ref
template <int W1, bool S1, int W2, bool S2>
ap_int_base<W1,S1> operator^(const ap_int_base<W1,S1> &a, const ap_range_ref<W2,S2> &b) {
    return ap_int_base<W1,S1>((long long)a ^ (long long)b);
}
template <int W1, bool S1, int W2, bool S2>
ap_int_base<W1,S1> operator|(const ap_int_base<W1,S1> &a, const ap_range_ref<W2,S2> &b) {
    return ap_int_base<W1,S1>((long long)a | (long long)b);
}

// ---- Const range reference ----
template <int W, bool S>
class ap_const_range_ref {
    const ap_int_base<W,S> &parent_;
    int hi_, lo_;
public:
    ap_const_range_ref(const ap_int_base<W,S> &p, int h, int l) : parent_(p), hi_(h), lo_(l) {}
    int width() const { return hi_ - lo_ + 1; }
    operator long long() const;
    operator unsigned long long() const { return (unsigned long long)(long long)(*this); }
    template <int W2, bool S2>
    operator ap_int_base<W2,S2>() const {
        return ap_int_base<W2,S2>((long long)(*this));
    }
    bool operator==(const char *s) const {
        long long val = 0;
        int len = 0; while (s[len]) len++;
        for (int i = 0; i < len; i++) val = (val << 1) | (s[i] - '0');
        return (long long)(*this) == val;
    }
    bool operator!=(const char *s) const { return !(*this == s); }
    bool operator==(long long v) const { return (long long)(*this) == v; }
    bool operator<(long long v) const { return (long long)(*this) < v; }
    bool operator>(long long v) const { return (long long)(*this) > v; }
    bool operator>=(long long v) const { return (long long)(*this) >= v; }
    long long operator^(long long v) const { return (long long)(*this) ^ v; }
    long long operator|(long long v) const { return (long long)(*this) | v; }
    long long operator&(long long v) const { return (long long)(*this) & v; }
    long long operator+(long long v) const { return (long long)(*this) + v; }
    long long operator-(long long v) const { return (long long)(*this) - v; }
    long long operator*(long long v) const { return (long long)(*this) * v; }
    long long operator<<(int v) const { return (long long)(*this) << v; }
    long long operator>>(int v) const { return (long long)(*this) >> v; }
    long long to_uint() const { return (long long)(*this); }
    long long to_int() const { return (long long)(*this); }
};

// ---- Concatenation result ----
template <int W1, bool S1, int W2, bool S2>
struct ap_concat_ref {
    long long hi_val;
    long long lo_val;
    int lo_width;
    ap_concat_ref(long long h, int hw, long long l, int lw)
        : hi_val(h), lo_val(l & ((1LL << lw) - 1)), lo_width(lw) {}
    operator long long() const {
        return (hi_val << lo_width) | lo_val;
    }
    template <int W3, bool S3>
    operator ap_int_base<W3,S3>() const {
        return ap_int_base<W3,S3>((long long)(*this));
    }
};

// ---- Storage type selector ----
template <int W> struct ap_storage { using type = long long; };
// Use __int128 if available and W > 64
#ifdef __SIZEOF_INT128__
template <> struct ap_storage<65> { using type = __int128; };
template <> struct ap_storage<66> { using type = __int128; };
template <> struct ap_storage<80> { using type = __int128; };
template <> struct ap_storage<128> { using type = __int128; };
// For very wide types (>128), store in struct with array
#endif

// ---- Wide integer helper (for W > 128) ----
struct wide256 {
    unsigned long long lo = 0, hi = 0, hi2 = 0, hi3 = 0;
    wide256() = default;
    wide256(long long v) : lo(v), hi(v < 0 ? ~0ULL : 0), hi2(v < 0 ? ~0ULL : 0), hi3(v < 0 ? ~0ULL : 0) {}
    wide256(unsigned long long l, unsigned long long h, unsigned long long h2, unsigned long long h3)
        : lo(l), hi(h), hi2(h2), hi3(h3) {}
    bool getBit(int i) const {
        if (i < 64) return (lo >> i) & 1;
        if (i < 128) return (hi >> (i - 64)) & 1;
        if (i < 192) return (hi2 >> (i - 128)) & 1;
        return (hi3 >> (i - 192)) & 1;
    }
    void setBit(int i, bool v) {
        unsigned long long mask = 1ULL << (i % 64);
        unsigned long long *w = (i < 64) ? &lo : (i < 128) ? &hi : (i < 192) ? &hi2 : &hi3;
        if (v) *w |= mask; else *w &= ~mask;
    }
    long long getRange(int hi_bit, int lo_bit) const {
        long long result = 0;
        for (int i = lo_bit; i <= hi_bit && i < 256; i++) {
            if (getBit(i)) result |= (1LL << (i - lo_bit));
        }
        return result;
    }
    void setRange(int hi_bit, int lo_bit, long long val) {
        for (int i = lo_bit; i <= hi_bit && i < 256; i++) {
            setBit(i, (val >> (i - lo_bit)) & 1);
        }
    }
    wide256 operator^(const wide256 &o) const { return {lo ^ o.lo, hi ^ o.hi, hi2 ^ o.hi2, hi3 ^ o.hi3}; }
    wide256 operator|(const wide256 &o) const { return {lo | o.lo, hi | o.hi, hi2 | o.hi2, hi3 | o.hi3}; }
    wide256 operator&(const wide256 &o) const { return {lo & o.lo, hi & o.hi, hi2 & o.hi2, hi3 & o.hi3}; }
    wide256 operator~() const { return {~lo, ~hi, ~hi2, ~hi3}; }
    bool operator==(const wide256 &o) const { return lo == o.lo && hi == o.hi && hi2 == o.hi2 && hi3 == o.hi3; }
    bool operator!=(const wide256 &o) const { return !(*this == o); }
    wide256 operator<<(int n) const {
        wide256 r;
        for (int i = 255; i >= 0; i--) {
            if (i - n >= 0) r.setBit(i, getBit(i - n));
        }
        return r;
    }
    wide256 operator>>(int n) const {
        wide256 r;
        for (int i = 0; i < 256; i++) {
            if (i + n < 256) r.setBit(i, getBit(i + n));
        }
        return r;
    }
    wide256 operator+(const wide256 &o) const {
        unsigned long long carry = 0;
        wide256 r;
        auto add64 = [](unsigned long long a, unsigned long long b, unsigned long long &c) -> unsigned long long {
            unsigned long long s = a + b + c;
            c = ((a & b) | ((a | b) & ~s)) >> 63;
            return s;
        };
        r.lo = add64(lo, o.lo, carry);
        r.hi = add64(hi, o.hi, carry);
        r.hi2 = add64(hi2, o.hi2, carry);
        r.hi3 = add64(hi3, o.hi3, carry);
        return r;
    }
    wide256 operator-(const wide256 &o) const {
        wide256 neg_o = ~o + wide256(1);
        return *this + neg_o;
    }
    operator long long() const { return (long long)lo; }
};

// ---- Main ap_int_base class ----
template <int W, bool S>
class ap_int_base {
    static_assert(W <= 256, "ap_int stub limited to 256 bits");

    // For W<=64 use long long, for W<=128 use __int128, for W<=256 use wide256
    using val_t = typename std::conditional<(W <= 64), long long,
                  typename std::conditional<(W <= 128),
#ifdef __SIZEOF_INT128__
                  __int128,
#else
                  wide256,
#endif
                  wide256>::type>::type;
    val_t val_;

    static constexpr bool use_wide = (W > 128);
    static constexpr bool use_128 = (W > 64 && W <= 128);

    long long mask64() const {
        if (W >= 64) return ~0LL;
        return (1LL << W) - 1;
    }

    void normalize() {
        if constexpr (W <= 64) {
            long long m = mask64();
            val_ &= m;
            if (S && W < 64 && (val_ & (1LL << (W - 1))))
                val_ |= ~m;
        }
#ifdef __SIZEOF_INT128__
        else if constexpr (W <= 128 && !use_wide) {
            __int128 m = (W >= 128) ? ~(__int128)0 : ((__int128)1 << W) - 1;
            val_ &= m;
            if (S && W < 128 && (val_ & ((__int128)1 << (W - 1))))
                val_ |= ~m;
        }
#endif
        else if constexpr (use_wide) {
            // Mask high bits
            for (int i = W; i < 256; i++) val_.setBit(i, S && val_.getBit(W - 1));
        }
    }
public:
    ap_int_base() : val_{} {}
    ap_int_base(long long v) : val_((val_t)v) { normalize(); }
    ap_int_base(unsigned long long v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(int v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(unsigned int v) : val_((val_t)(unsigned long long)v) { normalize(); }
    ap_int_base(long v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(unsigned long v) : val_((val_t)(unsigned long long)v) { normalize(); }
    ap_int_base(short v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(unsigned short v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(signed char v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(unsigned char v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(double v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(float v) : val_((val_t)(long long)v) { normalize(); }
    ap_int_base(bool v) : val_((val_t)(v ? 1LL : 0LL)) {}

    // String constructor (decimal or binary)
    ap_int_base(const char *s, int radix = 10) : val_{} {
        long long tmp = 0;
        if (radix == 10) {
            bool neg = false;
            const char *p = s;
            if (*p == '-') { neg = true; p++; }
            while (*p) { tmp = tmp * 10 + (*p - '0'); p++; }
            if (neg) tmp = -tmp;
        } else if (radix == 2) {
            const char *p = s;
            while (*p) { tmp = (tmp << 1) | (*p - '0'); p++; }
        } else if (radix == 16) {
            const char *p = s;
            while (*p) {
                int d = 0;
                if (*p >= '0' && *p <= '9') d = *p - '0';
                else if (*p >= 'a' && *p <= 'f') d = *p - 'a' + 10;
                else if (*p >= 'A' && *p <= 'F') d = *p - 'A' + 10;
                tmp = (tmp << 4) | d;
                p++;
            }
        }
        val_ = (val_t)tmp;
        normalize();
    }

    // Cross-width copy/conversion constructor
    template <int W2, bool S2>
    ap_int_base(const ap_int_base<W2,S2> &o) : val_((long long)o._get_val()) { normalize(); }
    // Volatile copy
    template <int W2, bool S2>
    ap_int_base(const volatile ap_int_base<W2,S2> &o) : val_((long long)const_cast<const ap_int_base<W2,S2>&>(o)._get_val()) { normalize(); }

    // Conversions
    operator long long() const { return val_; }
    operator unsigned long long() const { return (unsigned long long)val_; }
    operator int() const { return (int)val_; }
    operator unsigned int() const { return (unsigned int)val_; }
    operator float() const { return (float)val_; }
    operator double() const { return (double)val_; }
    operator bool() const { return val_ != 0; }
    operator short() const { return (short)val_; }
    operator unsigned short() const { return (unsigned short)val_; }
    operator unsigned char() const { return (unsigned char)val_; }
    // Array subscript helper: allow use as size_t index
    operator long() const { return (long)val_; }

    long long to_int() const { return val_; }
    unsigned long long to_uint() const { return (unsigned long long)val_; }
    long long to_int64() const { return val_; }

    // Reduction operators (HLS builtins)
    bool or_reduce() const { return val_ != 0; }
    bool and_reduce() const {
        long long mask = (W < 64) ? ((1LL << W) - 1) : -1LL;
        return (val_ & mask) == mask;
    }
    bool xor_reduce() const {
        long long v = val_;
        bool r = false;
        for (int i = 0; i < W; i++) { r ^= (v & 1); v >>= 1; }
        return r;
    }

    // Assignment
    ap_int_base &operator=(long long v) { val_ = (val_t)v; normalize(); return *this; }
    ap_int_base &operator=(int v) { val_ = (val_t)(long long)v; normalize(); return *this; }
    ap_int_base &operator=(unsigned long long v) { val_ = (val_t)(long long)v; normalize(); return *this; }
    ap_int_base &operator=(unsigned int v) { val_ = (val_t)(long long)v; normalize(); return *this; }
    // Assignment from range_ref
    template <int W2, bool S2>
    ap_int_base &operator=(const ap_range_ref<W2,S2> &r) { val_ = (val_t)(long long)r; normalize(); return *this; }
    template <int W2, bool S2>
    ap_int_base &operator=(const ap_const_range_ref<W2,S2> &r) { val_ = (val_t)(long long)r; normalize(); return *this; }
    // Volatile support
    volatile ap_int_base &operator=(long long v) volatile {
        auto &ref = const_cast<val_t&>(val_);
        ref = (val_t)v; return *this;
    }
    volatile ap_int_base &operator=(const ap_int_base &o) volatile {
        auto &ref = const_cast<val_t&>(val_);
        ref = o.val_; return *this;
    }
    template <int W2, bool S2>
    volatile ap_int_base &operator=(const ap_int_base<W2,S2> &o) volatile {
        auto &ref = const_cast<val_t&>(val_);
        ref = (val_t)(long long)o; return *this;
    }

    // Compound assignment
    ap_int_base &operator+=(long long v) { val_ = val_ + (val_t)v; normalize(); return *this; }
    ap_int_base &operator-=(long long v) { val_ = val_ - (val_t)v; normalize(); return *this; }
    ap_int_base &operator*=(long long v) { if constexpr(W<=64) { val_ *= v; } else { val_ = (val_t)((long long)val_ * v); } normalize(); return *this; }
    ap_int_base &operator/=(long long v) { if constexpr(W<=64) { val_ /= v; } else { val_ = (val_t)((long long)val_ / v); } normalize(); return *this; }
    ap_int_base &operator%=(long long v) { if constexpr(W<=64) { val_ %= v; } else { val_ = (val_t)((long long)val_ % v); } normalize(); return *this; }
    ap_int_base &operator^=(long long v) { val_ = val_ ^ (val_t)v; normalize(); return *this; }
    ap_int_base &operator|=(long long v) { val_ = val_ | (val_t)v; normalize(); return *this; }
    ap_int_base &operator&=(long long v) { val_ = val_ & (val_t)v; normalize(); return *this; }
    ap_int_base &operator<<=(int v) { val_ = val_ << v; normalize(); return *this; }
    ap_int_base &operator>>=(int v) { val_ = val_ >> v; normalize(); return *this; }
    ap_int_base &operator++() { val_ = val_ + (val_t)1; normalize(); return *this; }
    ap_int_base operator++(int) { ap_int_base t = *this; val_ = val_ + (val_t)1; normalize(); return t; }
    ap_int_base &operator--() { val_ = val_ - (val_t)1; normalize(); return *this; }
    ap_int_base operator--(int) { ap_int_base t = *this; val_ = val_ - (val_t)1; normalize(); return t; }

    // Arithmetic
    ap_int_base operator+(const ap_int_base &o) const { ap_int_base r; r.val_ = val_ + o.val_; r.normalize(); return r; }
    ap_int_base operator-(const ap_int_base &o) const { ap_int_base r; r.val_ = val_ - o.val_; r.normalize(); return r; }
    ap_int_base operator*(const ap_int_base &o) const { return ap_int_base((long long)val_ * (long long)o.val_); }
    ap_int_base operator/(const ap_int_base &o) const { return ap_int_base((long long)val_ / (long long)o.val_); }
    ap_int_base operator%(const ap_int_base &o) const { return ap_int_base((long long)val_ % (long long)o.val_); }
    ap_int_base operator-() const { ap_int_base r; r.val_ = (val_t)0 - val_; r.normalize(); return r; }
    ap_int_base operator~() const { ap_int_base r; r.val_ = ~val_; r.normalize(); return r; }
    ap_int_base operator^(const ap_int_base &o) const { ap_int_base r; r.val_ = val_ ^ o.val_; r.normalize(); return r; }
    ap_int_base operator|(const ap_int_base &o) const { ap_int_base r; r.val_ = val_ | o.val_; r.normalize(); return r; }
    ap_int_base operator&(const ap_int_base &o) const { ap_int_base r; r.val_ = val_ & o.val_; r.normalize(); return r; }
    ap_int_base operator<<(int v) const { ap_int_base r; r.val_ = val_ << v; r.normalize(); return r; }
    ap_int_base operator>>(int v) const { ap_int_base r; r.val_ = val_ >> v; r.normalize(); return r; }

    // With different width
    template <int W2, bool S2>
    ap_int_base operator+(const ap_int_base<W2,S2> &o) const { return ap_int_base(val_ + (long long)o); }
    template <int W2, bool S2>
    ap_int_base operator-(const ap_int_base<W2,S2> &o) const { return ap_int_base(val_ - (long long)o); }
    template <int W2, bool S2>
    ap_int_base operator*(const ap_int_base<W2,S2> &o) const { return ap_int_base((long long)val_ * (long long)o); }
    template <int W2, bool S2>
    ap_int_base operator/(const ap_int_base<W2,S2> &o) const { return ap_int_base((long long)val_ / (long long)o); }
    template <int W2, bool S2>
    ap_int_base operator%(const ap_int_base<W2,S2> &o) const { return ap_int_base((long long)val_ % (long long)o); }
    template <int W2, bool S2>
    ap_int_base &operator+=(const ap_int_base<W2,S2> &o) { val_ = val_ + (val_t)(long long)o; normalize(); return *this; }
    template <int W2, bool S2>
    ap_int_base &operator-=(const ap_int_base<W2,S2> &o) { val_ -= (long long)o; normalize(); return *this; }
    template <int W2, bool S2>
    ap_int_base &operator^=(const ap_int_base<W2,S2> &o) { val_ ^= (long long)o; normalize(); return *this; }
    template <int W2, bool S2>
    ap_int_base &operator|=(const ap_int_base<W2,S2> &o) { val_ |= (long long)o; normalize(); return *this; }
    template <int W2, bool S2>
    ap_int_base &operator&=(const ap_int_base<W2,S2> &o) { val_ &= (long long)o; normalize(); return *this; }
    template <int W2, bool S2>
    ap_int_base operator^(const ap_int_base<W2,S2> &o) const { return ap_int_base(val_ ^ (long long)o); }
    template <int W2, bool S2>
    ap_int_base operator|(const ap_int_base<W2,S2> &o) const { return ap_int_base(val_ | (long long)o); }
    template <int W2, bool S2>
    ap_int_base operator&(const ap_int_base<W2,S2> &o) const { return ap_int_base(val_ & (long long)o); }

    template <int W2, bool S2>
    ap_int_base &operator=(const ap_int_base<W2,S2> &o) { val_ = (long long)o; normalize(); return *this; }

    // Comparison
    bool operator==(const ap_int_base &o) const { return val_ == o.val_; }
    bool operator!=(const ap_int_base &o) const { return val_ != o.val_; }
    bool operator<(const ap_int_base &o) const {
        if (S) return val_ < o.val_;
        return (unsigned long long)(val_ & mask64()) < (unsigned long long)(o.val_ & mask64());
    }
    bool operator>(const ap_int_base &o) const { return o < *this; }
    bool operator<=(const ap_int_base &o) const { return !(o < *this); }
    bool operator>=(const ap_int_base &o) const { return !(*this < o); }

    bool operator==(long long v) const { return val_ == v; }
    bool operator!=(long long v) const { return val_ != v; }
    bool operator<(long long v) const { return val_ < v; }
    bool operator>(long long v) const { return val_ > v; }
    bool operator<=(long long v) const { return val_ <= v; }
    bool operator>=(long long v) const { return val_ >= v; }
    bool operator==(int v) const { return val_ == (long long)v; }
    bool operator!=(int v) const { return val_ != (long long)v; }
    bool operator<(int v) const { return val_ < (long long)v; }
    bool operator>(int v) const { return val_ > (long long)v; }
    bool operator<=(int v) const { return val_ <= (long long)v; }
    bool operator>=(int v) const { return val_ >= (long long)v; }
    friend bool operator==(int a, const ap_int_base &b) { return (long long)a == b.val_; }
    friend bool operator!=(int a, const ap_int_base &b) { return (long long)a != b.val_; }
    friend bool operator<(int a, const ap_int_base &b) { return (long long)a < b.val_; }
    friend bool operator>(int a, const ap_int_base &b) { return (long long)a > b.val_; }

    // Mixed-type arithmetic (resolve ambiguity with built-in operators)
    friend ap_int_base operator+(const ap_int_base &a, int b) { ap_int_base r; r.val_ = a.val_ + (val_t)(long long)b; r.normalize(); return r; }
    friend ap_int_base operator+(int a, const ap_int_base &b) { ap_int_base r; r.val_ = (val_t)(long long)a + b.val_; r.normalize(); return r; }
    friend ap_int_base operator-(const ap_int_base &a, int b) { ap_int_base r; r.val_ = a.val_ - (val_t)(long long)b; r.normalize(); return r; }
    friend ap_int_base operator-(int a, const ap_int_base &b) { return ap_int_base((long long)a - (long long)b); }
    friend ap_int_base operator*(const ap_int_base &a, int b) { return ap_int_base((long long)a * (long long)b); }
    friend ap_int_base operator*(int a, const ap_int_base &b) { return ap_int_base((long long)a * (long long)b); }
    friend ap_int_base operator/(const ap_int_base &a, int b) { return ap_int_base((long long)a / (long long)b); }
    friend ap_int_base operator%(const ap_int_base &a, int b) { return ap_int_base((long long)a % (long long)b); }
    friend ap_int_base operator^(const ap_int_base &a, int b) { ap_int_base r; r.val_ = a.val_ ^ (val_t)(long long)b; r.normalize(); return r; }
    friend ap_int_base operator|(const ap_int_base &a, int b) { ap_int_base r; r.val_ = a.val_ | (val_t)(long long)b; r.normalize(); return r; }
    friend ap_int_base operator&(const ap_int_base &a, int b) { ap_int_base r; r.val_ = a.val_ & (val_t)(long long)b; r.normalize(); return r; }
    friend ap_int_base operator<<(const ap_int_base &a, int b) { ap_int_base r; r.val_ = a.val_ << b; r.normalize(); return r; }
    friend ap_int_base operator>>(const ap_int_base &a, int b) { ap_int_base r; r.val_ = a.val_ >> b; r.normalize(); return r; }
    friend ap_int_base operator+(const ap_int_base &a, long long b) { ap_int_base r; r.val_ = a.val_ + (val_t)b; r.normalize(); return r; }
    friend ap_int_base operator-(const ap_int_base &a, long long b) { ap_int_base r; r.val_ = a.val_ - (val_t)b; r.normalize(); return r; }
    friend ap_int_base operator*(const ap_int_base &a, long long b) { return ap_int_base((long long)a * b); }
    friend ap_int_base operator^(const ap_int_base &a, long long b) { ap_int_base r; r.val_ = a.val_ ^ (val_t)b; r.normalize(); return r; }
    friend ap_int_base operator|(const ap_int_base &a, long long b) { ap_int_base r; r.val_ = a.val_ | (val_t)b; r.normalize(); return r; }
    // long variants
    friend ap_int_base operator+(const ap_int_base &a, long b) { return a + (long long)b; }
    friend ap_int_base operator+(long a, const ap_int_base &b) { return (long long)a + b; }
    friend ap_int_base operator-(const ap_int_base &a, long b) { return a - (long long)b; }
    friend ap_int_base operator-(long a, const ap_int_base &b) { return (long long)a - b; }
    friend ap_int_base operator*(const ap_int_base &a, long b) { return a * (long long)b; }
    friend ap_int_base operator*(long a, const ap_int_base &b) { return (long long)a * b; }
    friend ap_int_base operator^(const ap_int_base &a, long b) { return a ^ (long long)b; }
    friend ap_int_base operator|(const ap_int_base &a, long b) { return a | (long long)b; }
    friend ap_int_base operator&(const ap_int_base &a, long b) { return a & (long long)b; }
    // unsigned long long variants
    friend ap_int_base operator+(const ap_int_base &a, unsigned long long b) { return a + (long long)b; }
    friend ap_int_base operator-(const ap_int_base &a, unsigned long long b) { return a - (long long)b; }
    friend ap_int_base operator^(const ap_int_base &a, unsigned long long b) { return a ^ (long long)b; }
    // int << ap_int_base and int >> ap_int_base
    friend long long operator<<(int a, const ap_int_base &b) { return (long long)a << (int)(long long)b; }
    friend long long operator>>(int a, const ap_int_base &b) { return (long long)a >> (int)(long long)b; }
    // long long op ap_int_base
    friend ap_int_base operator*(long long a, const ap_int_base &b) { return ap_int_base(a * (long long)b); }
    friend ap_int_base operator+(long long a, const ap_int_base &b) { ap_int_base r; r.val_ = (val_t)a + b.val_; r.normalize(); return r; }
    friend ap_int_base operator-(long long a, const ap_int_base &b) { return ap_int_base(a - (long long)b); }

    template <int W2, bool S2>
    bool operator<(const ap_int_base<W2,S2> &o) const { return val_ < (long long)o; }
    template <int W2, bool S2>
    bool operator>(const ap_int_base<W2,S2> &o) const { return val_ > (long long)o; }
    template <int W2, bool S2>
    bool operator==(const ap_int_base<W2,S2> &o) const { return val_ == (long long)o; }
    template <int W2, bool S2>
    bool operator>=(const ap_int_base<W2,S2> &o) const { return val_ >= (long long)o; }
    template <int W2, bool S2>
    bool operator<=(const ap_int_base<W2,S2> &o) const { return val_ <= (long long)o; }
    template <int W2, bool S2>
    bool operator!=(const ap_int_base<W2,S2> &o) const { return val_ != (long long)o; }

    // Bit indexing
    ap_bit_ref<W,S> operator[](int i) { return ap_bit_ref<W,S>(*this, i); }
    int operator[](int i) const { return (int)((val_ >> i) & 1); }

    // Range selection
    ap_range_ref<W,S> operator()(int hi, int lo) {
        return ap_range_ref<W,S>(*this, hi, lo);
    }
    ap_const_range_ref<W,S> operator()(int hi, int lo) const {
        return ap_const_range_ref<W,S>(*this, hi, lo);
    }

    ap_range_ref<W,S> range(int hi, int lo) {
        return ap_range_ref<W,S>(*this, hi, lo);
    }
    ap_const_range_ref<W,S> range(int hi, int lo) const {
        return ap_const_range_ref<W,S>(*this, hi, lo);
    }

    // Raw access for bit_ref and range_ref
    long long _get_val() const {
        if constexpr (W <= 64) return val_;
        else return (long long)val_;
    }
    void _set_val(long long v) {
        if constexpr (W <= 64) { val_ = v; }
        else { val_ = (val_t)v; }
        normalize();
    }
    // Wide bit access
    int _get_bit(int i) const {
        if constexpr (W <= 64) return (int)((val_ >> i) & 1);
#ifdef __SIZEOF_INT128__
        else if constexpr (use_128) return (int)((val_ >> i) & 1);
#endif
        else return val_.getBit(i);
    }
    void _set_bit(int i, int v) {
        if constexpr (W <= 64) {
            if (v & 1) val_ |= (1LL << i); else val_ &= ~(1LL << i);
        }
#ifdef __SIZEOF_INT128__
        else if constexpr (use_128) {
            __int128 mask = (__int128)1 << i;
            if (v & 1) val_ |= mask; else val_ &= ~mask;
        }
#endif
        else { val_.setBit(i, v & 1); }
        normalize();
    }
    long long _get_range(int hi, int lo) const {
        if constexpr (W <= 64) {
            int w = hi - lo + 1;
            long long m = (w >= 64) ? ~0LL : ((1LL << w) - 1);
            return (val_ >> lo) & m;
        }
#ifdef __SIZEOF_INT128__
        else if constexpr (use_128) {
            int w = hi - lo + 1;
            __int128 m = (w >= 128) ? ~(__int128)0 : ((__int128)1 << w) - 1;
            return (long long)((val_ >> lo) & m);
        }
#endif
        else { return val_.getRange(hi, lo); }
    }
    void _set_range(int hi, int lo, long long v) {
        if constexpr (W <= 64) {
            int w = hi - lo + 1;
            long long m = (w >= 64) ? ~0LL : ((1LL << w) - 1);
            val_ &= ~(m << lo);
            val_ |= ((v & m) << lo);
        }
#ifdef __SIZEOF_INT128__
        else if constexpr (use_128) {
            int w = hi - lo + 1;
            __int128 m = (w >= 128) ? ~(__int128)0 : ((__int128)1 << w) - 1;
            val_ &= ~(m << lo);
            val_ |= (((__int128)v & m) << lo);
        }
#endif
        else { val_.setRange(hi, lo, v); }
        normalize();
    }

    // Stream support
    template <typename OS>
    friend OS &operator<<(OS &os, const ap_int_base &v) {
        os << (long long)v;
        return os;
    }
};

// ---- Implement bit_ref ----
template <int W, bool S>
ap_bit_ref<W,S>::operator int() const {
    return parent_._get_bit(bit_);
}
template <int W, bool S>
ap_bit_ref<W,S> &ap_bit_ref<W,S>::operator=(int v) {
    parent_._set_bit(bit_, v);
    return *this;
}

// ---- Implement range_ref ----
template <int W, bool S>
ap_range_ref<W,S>::operator long long() const {
    return parent_._get_range(hi_, lo_);
}
template <int W, bool S>
ap_range_ref<W,S> &ap_range_ref<W,S>::operator=(long long v) {
    parent_._set_range(hi_, lo_, v);
    return *this;
}

// ---- Implement const_range_ref ----
template <int W, bool S>
ap_const_range_ref<W,S>::operator long long() const {
    return parent_._get_range(hi_, lo_);
}

// ---- Public aliases ----
template <int W>
using ap_int = ap_int_base<W, true>;

template <int W>
using ap_uint = ap_int_base<W, false>;
