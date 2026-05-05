#pragma once
// Mock XRT buffer object header for compilation testing
#include <cstddef>
#include <cstring>

// Sync direction constants
#ifndef XCL_BO_SYNC_BO_TO_DEVICE
#define XCL_BO_SYNC_BO_TO_DEVICE 0
#endif
#ifndef XCL_BO_SYNC_BO_FROM_DEVICE
#define XCL_BO_SYNC_BO_FROM_DEVICE 1
#endif

namespace xrt {

class device; // forward
class kernel; // forward

class bo {
public:
    bo() = default;
    bo(const device & /*dev*/, size_t size, int /*group_id*/)
        : buf_(new char[size]), size_(size) { std::memset(buf_, 0, size); }
    ~bo() { delete[] buf_; }
    bo(const bo &) = delete;
    bo &operator=(const bo &) = delete;
    bo(bo &&o) noexcept : buf_(o.buf_), size_(o.size_) { o.buf_ = nullptr; o.size_ = 0; }
    bo &operator=(bo &&o) noexcept { delete[] buf_; buf_ = o.buf_; size_ = o.size_; o.buf_ = nullptr; o.size_ = 0; return *this; }

    void write(const void *src, size_t n, size_t offset = 0) {
        if (buf_ && src) std::memcpy(buf_ + offset, src, n);
    }
    void read(void *dst, size_t n, size_t offset = 0) {
        if (buf_ && dst) std::memcpy(dst, buf_ + offset, n);
    }
    void sync(int /*direction*/) {}

private:
    char *buf_ = nullptr;
    size_t size_ = 0;
};

} // namespace xrt
