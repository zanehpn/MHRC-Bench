#include <iostream>
#include "filter_c_original.c"
int main() {
    // (10+20) & 0xFF = 30, >>2 = 7, > 5 → true
    if (!adder(10, 20, 5, 0xFF)) { std::cerr<<"FAIL 1\n"; return 1; }
    // (10+20) & 0xFF = 30, >>2 = 7, > 10 → false
    if (adder(10, 20, 10, 0xFF)) { std::cerr<<"FAIL 2\n"; return 1; }
    // (0+0) & 0xFF = 0, >>2 = 0, > 0 → false
    if (adder(0, 0, 0, 0xFF)) { std::cerr<<"FAIL 3\n"; return 1; }
    // mask test: (100+200) & 0xF = 12 (300&0xF=12), >>2 = 3, > 2 → true
    if (!adder(100, 200, 2, 0xF)) { std::cerr<<"FAIL 4\n"; return 1; }
    std::cout << "PASS: filter_c\n"; return 0;
}
