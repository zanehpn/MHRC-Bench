// Mock systemc.h for g++ compilation of HL5 RISC-V processor modules
#ifndef MOCK_SYSTEMC_H
#define MOCK_SYSTEMC_H

#include <cstdint>
#include <cstring>
#include <string>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <cassert>

using std::ostream;
using std::endl;
using std::hex;
using std::dec;

// Forward declarations
class sc_trace_file;
class sc_module_name;
class sc_object;
template<int W> class sc_uint;
template<int W> class sc_int;

// ---------------------------------------------------------------
// sc_bv<W> - bit vector
// ---------------------------------------------------------------
template<int W>
class sc_bv {
    uint64_t val_;
    static constexpr uint64_t MASK = (W >= 64) ? ~0ULL : ((1ULL << W) - 1);
public:
    sc_bv() : val_(0) {}
    sc_bv(int v) : val_((uint64_t)(uint32_t)v & MASK) {}
    sc_bv(unsigned int v) : val_((uint64_t)v & MASK) {}
    sc_bv(long long v) : val_((uint64_t)v & MASK) {}
    sc_bv(unsigned long long v) : val_(v & MASK) {}
    sc_bv(const char* s) {
        val_ = 0;
        if (!s) return;
        for (int i = 0; s[i]; i++)
            val_ = (val_ << 1) | (s[i] - '0');
        val_ &= MASK;
    }

    template<int W2> sc_bv(const sc_bv<W2>& other) : val_(other.to_uint64() & MASK) {}
    template<int W2> sc_bv(const sc_uint<W2>& u);  // defined after sc_uint
    template<int W2> sc_bv(const sc_int<W2>& s);   // defined after sc_int

    uint64_t to_uint64() const { return val_; }
    unsigned int to_uint() const { return (unsigned int)(val_ & 0xFFFFFFFF); }
    int to_int() const {
        uint32_t v = (uint32_t)(val_ & 0xFFFFFFFF);
        if (W < 32 && (v & (1U << (W-1)))) v |= ~((1U << W) - 1);
        return (int)v;
    }

    // Assignment operators
    sc_bv<W>& operator=(int v) { val_ = (uint64_t)(uint32_t)v & MASK; return *this; }
    sc_bv<W>& operator=(unsigned int v) { val_ = (uint64_t)v & MASK; return *this; }
    sc_bv<W>& operator=(long long v) { val_ = (uint64_t)v & MASK; return *this; }
    sc_bv<W>& operator=(unsigned long long v) { val_ = v & MASK; return *this; }
    sc_bv<W>& operator=(const char* s) {
        val_ = 0;
        if (!s) return *this;
        for (int i = 0; s[i]; i++) val_ = (val_ << 1) | (s[i] - '0');
        val_ &= MASK;
        return *this;
    }
    template<int W2> sc_bv<W>& operator=(const sc_bv<W2>& other) { val_ = other.to_uint64() & MASK; return *this; }
    template<int W2> sc_bv<W>& operator=(const sc_uint<W2>& u);  // defined after sc_uint
    template<int W2> sc_bv<W>& operator=(const sc_int<W2>& s);   // defined after sc_int

    // Comparison
    bool operator==(const sc_bv<W>& o) const { return val_ == o.val_; }
    bool operator==(const char* s) const { sc_bv<W> t(s); return val_ == t.val_; }
    bool operator==(int v) const { return val_ == ((uint64_t)(uint32_t)v & MASK); }
    bool operator!=(const sc_bv<W>& o) const { return val_ != o.val_; }
    bool operator!=(const char* s) const { return !(*this == s); }
    template<int W2> bool operator==(const sc_bv<W2>& o) const { return val_ == (o.to_uint64() & MASK); }

    // Bitwise operators
    sc_bv<W> operator^(const sc_bv<W>& o) const { return sc_bv<W>((unsigned long long)((val_ ^ o.val_) & MASK)); }
    sc_bv<W> operator|(const sc_bv<W>& o) const { return sc_bv<W>((unsigned long long)((val_ | o.val_) & MASK)); }
    sc_bv<W> operator&(const sc_bv<W>& o) const { return sc_bv<W>((unsigned long long)((val_ & o.val_) & MASK)); }
    sc_bv<W> operator~() const { return sc_bv<W>((unsigned long long)((~val_) & MASK)); }

    sc_bv<W>& operator|=(const sc_bv<W>& o) { val_ = (val_ | o.val_) & MASK; return *this; }
    sc_bv<W>& operator&=(const sc_bv<W>& o) { val_ = (val_ & o.val_) & MASK; return *this; }

    // range(hi, lo) extracts bits [hi:lo]
    sc_bv<W> range(int hi, int lo) const {
        int len = hi - lo + 1;
        uint64_t m = (len >= 64) ? ~0ULL : ((1ULL << len) - 1);
        return sc_bv<W>((unsigned long long)((val_ >> lo) & m));
    }

    // bit access
    int operator[](int i) const { return (val_ >> i) & 1; }

    friend ostream& operator<<(ostream& os, const sc_bv<W>& v) {
        for (int i = W - 1; i >= 0; i--)
            os << ((v.val_ >> i) & 1);
        return os;
    }
};

// Concatenation operator for sc_bv: (a, b) -> sc_bv<W1+W2>
template<int W1, int W2>
sc_bv<W1+W2> operator,(const sc_bv<W1>& a, const sc_bv<W2>& b) {
    uint64_t combined = (a.to_uint64() << W2) | b.to_uint64();
    return sc_bv<W1+W2>((unsigned long long)combined);
}

// Concatenation: (const char*, sc_bv<W>)
template<int W>
sc_bv<64> operator,(const char* s, const sc_bv<W>& b) {
    sc_bv<64> a(s);
    uint64_t combined = (a.to_uint64() << W) | b.to_uint64();
    return sc_bv<64>((unsigned long long)combined);
}

// ---------------------------------------------------------------
// sc_uint<W> - unsigned integer
// ---------------------------------------------------------------
template<int W>
class sc_uint {
    uint64_t val_;
    static constexpr uint64_t MASK = (W >= 64) ? ~0ULL : ((1ULL << W) - 1);
public:
    sc_uint() : val_(0) {}
    sc_uint(int v) : val_((uint64_t)(uint32_t)v & MASK) {}
    sc_uint(unsigned int v) : val_((uint64_t)v & MASK) {}
    sc_uint(long v) : val_((uint64_t)(unsigned long)v & MASK) {}
    sc_uint(unsigned long v) : val_(v & MASK) {}
    sc_uint(long long v) : val_((uint64_t)v & MASK) {}
    sc_uint(unsigned long long v) : val_(v & MASK) {}

    template<int W2> sc_uint(const sc_bv<W2>& bv) : val_(bv.to_uint64() & MASK) {}
    template<int W2> sc_uint(const sc_uint<W2>& other) : val_(other.to_uint64() & MASK) {}
    template<int W2> sc_uint(const sc_int<W2>& s) : val_((uint64_t)s.to_int64() & MASK) {}

    uint64_t to_uint64() const { return val_; }
    unsigned int to_uint() const { return (unsigned int)(val_ & 0xFFFFFFFF); }
    int to_int() const { return (int)(val_ & 0xFFFFFFFF); }

    // Implicit conversion to unsigned int -- needed for switch statements and array indexing
    operator unsigned int() const { return to_uint(); }

    // Assignment
    sc_uint<W>& operator=(int v) { val_ = (uint64_t)(uint32_t)v & MASK; return *this; }
    sc_uint<W>& operator=(unsigned int v) { val_ = (uint64_t)v & MASK; return *this; }
    sc_uint<W>& operator=(long long v) { val_ = (uint64_t)v & MASK; return *this; }
    sc_uint<W>& operator=(unsigned long long v) { val_ = v & MASK; return *this; }
    template<int W2> sc_uint<W>& operator=(const sc_bv<W2>& bv) { val_ = bv.to_uint64() & MASK; return *this; }
    template<int W2> sc_uint<W>& operator=(const sc_uint<W2>& o) { val_ = o.to_uint64() & MASK; return *this; }

    // Comparison
    bool operator==(unsigned int v) const { return val_ == ((uint64_t)v & MASK); }
    bool operator==(int v) const { return val_ == ((uint64_t)(uint32_t)v & MASK); }
    bool operator==(const sc_uint<W>& o) const { return val_ == o.val_; }
    template<int W2> bool operator==(const sc_uint<W2>& o) const { return val_ == (o.to_uint64() & MASK); }
    bool operator!=(unsigned int v) const { return !(*this == v); }
    bool operator!=(int v) const { return !(*this == v); }
    bool operator!=(const sc_uint<W>& o) const { return val_ != o.val_; }
    template<int W2> bool operator!=(const sc_uint<W2>& o) const { return !(*this == o); }

    bool operator<(const sc_uint<W>& o) const { return val_ < o.val_; }
    bool operator<(unsigned int v) const { return val_ < v; }
    bool operator>=(const sc_uint<W>& o) const { return val_ >= o.val_; }
    bool operator>=(unsigned int v) const { return val_ >= v; }
    bool operator>(const sc_uint<W>& o) const { return val_ > o.val_; }
    bool operator>(int v) const { return val_ > (uint64_t)(unsigned)v; }
    bool operator<=(const sc_uint<W>& o) const { return val_ <= o.val_; }

    // Arithmetic
    sc_uint<W> operator+(const sc_uint<W>& o) const { return sc_uint<W>((unsigned long long)((val_ + o.val_) & MASK)); }
    sc_uint<W> operator+(int v) const { return sc_uint<W>((unsigned long long)((val_ + (uint64_t)(unsigned)v) & MASK)); }
    sc_uint<W> operator-(const sc_uint<W>& o) const { return sc_uint<W>((unsigned long long)((val_ - o.val_) & MASK)); }
    sc_uint<W>& operator+=(int v) { val_ = (val_ + v) & MASK; return *this; }
    sc_uint<W>& operator-=(const sc_uint<W>& o) { val_ = (val_ - o.val_) & MASK; return *this; }
    sc_uint<W>& operator++() { val_ = (val_ + 1) & MASK; return *this; }
    sc_uint<W> operator++(int) { sc_uint<W> t = *this; ++(*this); return t; }

    // Shift
    sc_uint<W> operator<<(int s) const { return sc_uint<W>((unsigned long long)((val_ << s) & MASK)); }
    sc_uint<W> operator<<(const sc_uint<W>& s) const { return sc_uint<W>((unsigned long long)((val_ << s.val_) & MASK)); }
    template<int W2> sc_uint<W> operator<<(const sc_uint<W2>& s) const { return sc_uint<W>((unsigned long long)((val_ << s.to_uint64()) & MASK)); }
    sc_uint<W> operator>>(int s) const { return sc_uint<W>((unsigned long long)(val_ >> s)); }
    sc_uint<W> operator>>(const sc_uint<W>& s) const { return sc_uint<W>((unsigned long long)(val_ >> s.val_)); }
    template<int W2> sc_uint<W> operator>>(const sc_uint<W2>& s) const { return sc_uint<W>((unsigned long long)(val_ >> s.to_uint64())); }
    template<int W2> sc_uint<W> operator>>(const sc_int<W2>& s) const { return sc_uint<W>((unsigned long long)(val_ >> (int)s.to_int64())); }

    // Bitwise
    sc_uint<W> operator|(const sc_uint<W>& o) const { return sc_uint<W>((unsigned long long)((val_ | o.val_) & MASK)); }
    sc_uint<W> operator|(unsigned int v) const { return sc_uint<W>((unsigned long long)((val_ | v) & MASK)); }
    sc_uint<W> operator&(const sc_uint<W>& o) const { return sc_uint<W>((unsigned long long)((val_ & o.val_) & MASK)); }
    sc_uint<W> operator&(unsigned int v) const { return sc_uint<W>((unsigned long long)((val_ & v) & MASK)); }
    sc_uint<W> operator^(const sc_uint<W>& o) const { return sc_uint<W>((unsigned long long)((val_ ^ o.val_) & MASK)); }
    sc_uint<W> operator~() const { return sc_uint<W>((unsigned long long)((~val_) & MASK)); }
    sc_uint<W> operator*(const sc_uint<W>& o) const { return sc_uint<W>((unsigned long long)((val_ * o.val_) & MASK)); }
    sc_uint<W> operator%(int v) const { return sc_uint<W>((unsigned long long)(val_ % (unsigned)v)); }

    sc_uint<W>& operator|=(const sc_uint<W>& o) { val_ = (val_ | o.val_) & MASK; return *this; }
    sc_uint<W>& operator|=(unsigned int v) { val_ = (val_ | v) & MASK; return *this; }
    sc_uint<W>& operator&=(const sc_uint<W>& o) { val_ = (val_ & o.val_) & MASK; return *this; }
    sc_uint<W>& operator&=(uint64_t v) { val_ = (val_ & v) & MASK; return *this; }

    // range
    sc_uint<W> range(int hi, int lo) const {
        int len = hi - lo + 1;
        uint64_t m = (len >= 64) ? ~0ULL : ((1ULL << len) - 1);
        return sc_uint<W>((unsigned long long)((val_ >> lo) & m));
    }

    friend ostream& operator<<(ostream& os, const sc_uint<W>& v) {
        os << v.val_;
        return os;
    }
};

// ---------------------------------------------------------------
// sc_int<W> - signed integer
// ---------------------------------------------------------------
template<int W>
class sc_int {
    int64_t val_;
    static constexpr uint64_t MASK = (W >= 64) ? ~0ULL : ((1ULL << W) - 1);

    int64_t sign_extend(int64_t v) const {
        if (W >= 64) return v;
        uint64_t uv = (uint64_t)v & MASK;
        if (uv & (1ULL << (W - 1)))
            return (int64_t)(uv | ~MASK);
        return (int64_t)uv;
    }
public:
    sc_int() : val_(0) {}
    sc_int(int v) : val_(sign_extend(v)) {}
    sc_int(unsigned int v) : val_(sign_extend(v)) {}
    sc_int(long v) : val_(sign_extend(v)) {}
    sc_int(unsigned long v) : val_(sign_extend((int64_t)v)) {}
    sc_int(long long v) : val_(sign_extend(v)) {}
    sc_int(unsigned long long v) : val_(sign_extend((int64_t)v)) {}

    template<int W2> sc_int(const sc_bv<W2>& bv) : val_(sign_extend((int64_t)bv.to_uint64())) {}
    template<int W2> sc_int(const sc_uint<W2>& u) : val_(sign_extend((int64_t)u.to_uint64())) {}
    template<int W2> sc_int(const sc_int<W2>& other) : val_(sign_extend(other.to_int64())) {}

    int64_t to_int64() const { return val_; }
    int to_int() const { return (int)val_; }
    unsigned int to_uint() const { return (unsigned int)((uint64_t)val_ & MASK); }
    uint64_t to_uint64() const { return (uint64_t)val_ & MASK; }

    operator int() const { return to_int(); }

    // Assignment
    sc_int<W>& operator=(int v) { val_ = sign_extend(v); return *this; }
    sc_int<W>& operator=(long long v) { val_ = sign_extend(v); return *this; }
    template<int W2> sc_int<W>& operator=(const sc_bv<W2>& bv) { val_ = sign_extend((int64_t)bv.to_uint64()); return *this; }
    template<int W2> sc_int<W>& operator=(const sc_int<W2>& o) { val_ = sign_extend(o.to_int64()); return *this; }

    // Comparison
    bool operator<(int v) const { return val_ < v; }
    bool operator<(const sc_int<W>& o) const { return val_ < o.val_; }
    bool operator>=(int v) const { return val_ >= v; }
    bool operator>=(const sc_int<W>& o) const { return val_ >= o.val_; }
    bool operator==(const sc_int<W>& o) const { return val_ == o.val_; }
    bool operator!=(const sc_int<W>& o) const { return val_ != o.val_; }

    // Arithmetic
    sc_int<W> operator+(const sc_int<W>& o) const { return sc_int<W>((long long)(val_ + o.val_)); }
    sc_int<W> operator+(int v) const { return sc_int<W>((long long)(val_ + v)); }
    sc_int<W> operator-(const sc_int<W>& o) const { return sc_int<W>((long long)(val_ - o.val_)); }
    sc_int<W> operator-() const { return sc_int<W>((long long)(-val_)); }
    sc_int<W> operator*(const sc_int<W>& o) const { return sc_int<W>((long long)(val_ * o.val_)); }

    // Shift
    sc_int<W> operator>>(int s) const { return sc_int<W>((long long)(val_ >> s)); }
    template<int W2> sc_int<W> operator>>(const sc_uint<W2>& s) const { return sc_int<W>((long long)(val_ >> s.to_uint64())); }
    sc_int<W> operator<<(int s) const { return sc_int<W>((long long)(val_ << s)); }

    // Increment/decrement
    sc_int<W>& operator++() { val_ = sign_extend(val_ + 1); return *this; }
    sc_int<W> operator++(int) { sc_int<W> t = *this; ++(*this); return t; }
    sc_int<W>& operator--() { val_ = sign_extend(val_ - 1); return *this; }
    sc_int<W> operator--(int) { sc_int<W> t = *this; --(*this); return t; }

    friend ostream& operator<<(ostream& os, const sc_int<W>& v) {
        os << v.val_;
        return os;
    }
};

// Deferred implementations for sc_bv constructors/assignments from sc_uint/sc_int
template<int W> template<int W2>
sc_bv<W>::sc_bv(const sc_uint<W2>& u) : val_(u.to_uint64() & MASK) {}

template<int W> template<int W2>
sc_bv<W>::sc_bv(const sc_int<W2>& s) : val_((uint64_t)s.to_uint64() & MASK) {}

template<int W> template<int W2>
sc_bv<W>& sc_bv<W>::operator=(const sc_uint<W2>& u) { val_ = u.to_uint64() & MASK; return *this; }

template<int W> template<int W2>
sc_bv<W>& sc_bv<W>::operator=(const sc_int<W2>& s) { val_ = (uint64_t)s.to_uint64() & MASK; return *this; }

// ---------------------------------------------------------------
// sc_signal<T>
// ---------------------------------------------------------------
template<typename T>
class sc_signal {
    T val_;
public:
    sc_signal() : val_() {}
    sc_signal(const char*) : val_() {}
    void write(const T& v) { val_ = v; }
    const T& read() const { return val_; }
    operator const T&() const { return val_; }
    sc_signal<T>& operator=(const T& v) { val_ = v; return *this; }
    sc_signal<T>& operator=(const char* s) { val_ = T(s); return *this; }
    bool operator==(const char* s) const { return val_ == T(s); }
};

// ---------------------------------------------------------------
// sc_in<T>, sc_out<T>
// ---------------------------------------------------------------
template<typename T>
class sc_in {
    T val_;
public:
    sc_in() : val_() {}
    sc_in(const char*) : val_() {}
    const T& read() const { return val_; }
    void write(const T& v) { val_ = v; }
    operator const T&() const { return val_; }
    void operator()(sc_signal<T>&) {}
    void bind(sc_signal<T>&) {}
};

template<typename T>
class sc_out {
    T val_;
public:
    sc_out() : val_() {}
    sc_out(const char*) : val_() {}
    void write(const T& v) { val_ = v; }
    const T& read() const { return val_; }
    operator const T&() const { return val_; }
    void operator()(sc_signal<T>&) {}
    void bind(sc_signal<T>&) {}
};

// sc_in_clk
class sc_clock_edge {};

class sc_in_clk {
public:
    sc_in_clk() {}
    sc_in_clk(const char*) {}
    sc_clock_edge pos() const { return sc_clock_edge(); }
    sc_clock_edge neg() const { return sc_clock_edge(); }
    void operator()(sc_signal<bool>&) {}
};

// ---------------------------------------------------------------
// sc_module infrastructure
// ---------------------------------------------------------------
class sc_module_name {
    const char* name_;
public:
    sc_module_name(const char* n) : name_(n) {}
    operator const char*() const { return name_; }
};

class sc_object {
public:
    const char* name() const { return "mock_sc_object"; }
};

class sc_module : public sc_object {
public:
    sc_module() {}
    sc_module(sc_module_name) {}
    void reset_signal_is(sc_in<bool>&, bool) {}
    void wait() {} // no-op in mock
};

#define SC_MODULE(name) struct name : public sc_module
#define SC_CTOR(name) name(sc_module_name _name)
#define SC_HAS_PROCESS(name)
#define SC_THREAD(func)
#define SC_CTHREAD(func, edge)
#define SC_METHOD(func)

// ---------------------------------------------------------------
// Tracing stubs
// ---------------------------------------------------------------
class sc_trace_file {
public:
    template<typename T>
    void trace(const T&, const std::string&) {}
};

template<typename T>
inline void sc_trace(sc_trace_file*, const T&, const std::string&) {}

// ---------------------------------------------------------------
// Reporting stubs
// ---------------------------------------------------------------
#define SC_REPORT_INFO(name, msg) do { std::cout << "[INFO] " << name << ": " << msg; } while(0)
#define SC_REPORT_ERROR(name, msg) do { std::cerr << "[ERROR] " << name << ": " << msg << std::endl; } while(0)
#define sc_assert(cond) assert(cond)

// wait() as free function
inline void wait() {}

#endif // MOCK_SYSTEMC_H
