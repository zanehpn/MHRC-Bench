
#pragma once

#include <cassert>
#include <queue>
#include <string>

namespace hls {

// DEPTH is ignored in the mock — it only affects synthesis.
// stream_impl is the real class; stream<T,DEPTH> is an alias so all depths
// resolve to the same type (allowing stream<T,12>* -> stream<T,0>* etc.).
template <typename T>
class stream_impl {
public:
    stream_impl() = default;
    explicit stream_impl(const char *) {}
    explicit stream_impl(const std::string &) {}

    void write(const T &value) { q_.push(value); }

    T read() {
        assert(!q_.empty());
        T value = q_.front();
        q_.pop();
        return value;
    }

    bool empty() const { return q_.empty(); }
    bool full() const { return false; }
    std::size_t size() const { return q_.size(); }

private:
    std::queue<T> q_;
};

// stream<T, DEPTH> is always the same type regardless of DEPTH.
template <typename T, int DEPTH = 0>
using stream = stream_impl<T>;

template <typename T>
stream_impl<T> &operator<<(stream_impl<T> &s, const T &value) {
    s.write(value);
    return s;
}

template <typename T>
stream_impl<T> &operator>>(stream_impl<T> &s, T &value) {
    value = s.read();
    return s;
}
}  // namespace hls
