#pragma once
// Mock XRT kernel header for compilation testing
#include <string>

namespace xrt {

class device;
class uuid;
class bo;

class run {
public:
    run() = default;
    void wait() {}
    void start() {}
    template <typename T>
    void set_arg(int /*index*/, T /*value*/) {}
};

class kernel {
public:
    kernel() = default;
    kernel(const device & /*dev*/, const uuid & /*id*/, const std::string & /*name*/) {}
    int group_id(int /*arg_index*/) { return 0; }

    // Variadic operator() to accept any number of arguments
    template <typename... Args>
    run operator()(Args&&... /*args*/) { return run(); }
};

} // namespace xrt
