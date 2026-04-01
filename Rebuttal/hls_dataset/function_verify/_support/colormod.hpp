// Mock colormod.hpp - color modifiers for terminal output
#ifndef COLORMOD_HPP
#define COLORMOD_HPP

#include <ostream>

namespace Color {
    enum Code {
        FG_RED = 31,
        FG_GREEN = 32,
        FG_YELLOW = 33,
        FG_BLUE = 34,
        FG_DEFAULT = 39,
    };
    class Modifier {
        Code code_;
    public:
        Modifier(Code c) : code_(c) {}
        friend std::ostream& operator<<(std::ostream& os, const Modifier&) {
            return os; // no-op
        }
    };
}

#endif
