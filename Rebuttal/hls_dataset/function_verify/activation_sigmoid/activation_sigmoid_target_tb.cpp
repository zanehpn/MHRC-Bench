#include <cmath>
#include <iostream>
#include "activation_sigmoid.cpp"

int main() {
    // sigmoid(0) = 1/(1+exp(0)) = 0.5
    float v0 = activation_sigmoid(0.0f);
    if (std::fabs(v0 - 0.5f) > 1e-5f) {
        std::cerr << "FAIL: sigmoid(0) = " << v0 << " expected 0.5\n";
        return 1;
    }

    // sigmoid(large positive) -> ~1
    float v1 = activation_sigmoid(10.0f);
    if (v1 < 0.99f) {
        std::cerr << "FAIL: sigmoid(10) = " << v1 << " expected ~1\n";
        return 1;
    }

    // sigmoid(large negative) -> ~0
    float v2 = activation_sigmoid(-10.0f);
    if (v2 > 0.01f) {
        std::cerr << "FAIL: sigmoid(-10) = " << v2 << " expected ~0\n";
        return 1;
    }

    // sigmoid(1) = 1/(1+exp(-1)) ≈ 0.7311
    float v3 = activation_sigmoid(1.0f);
    if (std::fabs(v3 - 0.7310586f) > 1e-4f) {
        std::cerr << "FAIL: sigmoid(1) = " << v3 << " expected 0.7311\n";
        return 1;
    }

    std::cout << "PASS: activation_sigmoid\n";
    return 0;
}
