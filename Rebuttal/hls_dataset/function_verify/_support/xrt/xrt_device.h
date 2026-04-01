#pragma once
// Mock XRT device header for compilation testing
#include <string>
#include <cstddef>

// Forward declare uuid type
namespace xrt {

class uuid {
public:
    uuid() = default;
};

class device {
public:
    device() = default;
    explicit device(int /*index*/) {}
    uuid load_xclbin(const std::string & /*path*/) { return uuid(); }
};

} // namespace xrt
