#include <cmath>
#include <iostream>
#include "volatilityData_original.cpp"

int main() {
    // truncFun2 should return fmax(x,0)
    if (std::fabs(volData::truncFun2(5.0f) - 5.0f) > 1e-6f) {
        std::cerr << "FAIL: truncFun2(5) != 5\n"; return 1;
    }
    if (std::fabs(volData::truncFun2(-3.0f) - 0.0f) > 1e-6f) {
        std::cerr << "FAIL: truncFun2(-3) != 0\n"; return 1;
    }
    if (std::fabs(volData::truncFun2(0.0f) - 0.0f) > 1e-6f) {
        std::cerr << "FAIL: truncFun2(0) != 0\n"; return 1;
    }
    std::cout << "PASS: volatilityData\n";
    return 0;
}
