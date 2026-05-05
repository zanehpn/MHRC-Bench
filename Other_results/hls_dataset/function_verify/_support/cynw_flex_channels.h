// Mock cynw_flex_channels.h for g++ compilation
// Provides stubs for Catapult HLS flex channel types
#ifndef MOCK_CYNW_FLEX_CHANNELS_H
#define MOCK_CYNW_FLEX_CHANNELS_H

#include "systemc.h"

template<typename T>
class put_initiator {
    T data_;
public:
    put_initiator() {}
    put_initiator(const char*) {}
    void put(const T& v) { data_ = v; }
    void reset_put() {}
    void clk_rst(sc_in_clk&, sc_in<bool>&) {}
    const T& last_put() const { return data_; }
};

template<typename T>
class get_initiator {
    T data_;
public:
    get_initiator() {}
    get_initiator(const char*) {}
    T get() { return data_; }
    void reset_get() {}
    void clk_rst(sc_in_clk&, sc_in<bool>&) {}
    void set_data(const T& v) { data_ = v; }
};

template<typename T>
class put_target {
    T data_;
public:
    put_target() {}
    put_target(const char*) {}
    void put(const T& v) { data_ = v; }
    void reset_put() {}
    void clk_rst(sc_in_clk&, sc_in<bool>&) {}
};

template<typename T>
class get_target {
    T data_;
public:
    get_target() {}
    get_target(const char*) {}
    T get() { return data_; }
    void reset_get() {}
    void clk_rst(sc_in_clk&, sc_in<bool>&) {}
};

#endif // MOCK_CYNW_FLEX_CHANNELS_H
