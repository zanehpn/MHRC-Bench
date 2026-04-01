#include <cstdlib>
#include <iostream>
#include "mod.cpp"

int main() {
    ap_int<32> x = 5, y = 3;
    ap_uint<32> p = 2147565569ULL;
    auto r1 = modular_multiplication(x, y, p, 0);
    auto r2 = modular_multiplication(x, y, p, 0);
    if ((long long)r1 != (long long)r2) {
        std::cerr << "mod: non-deterministic\n";
        return 1;
    }
    return 0;
}
