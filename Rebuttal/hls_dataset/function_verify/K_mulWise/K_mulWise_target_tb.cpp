
#include <cstdlib>
#include <iostream>
#include "K_mulWise.cpp"

int main() {
    // Smoke test: verify the function can be called without crashing
    static ap_int<PRIME_BIT> poly1[N * RNS_NUM] = {};
    static ap_int<PRIME_BIT> poly2[N * RNS_NUM] = {};
    static ap_int<PRIME_BIT> out[N * RNS_NUM] = {};

    K_mulWise(poly1, poly2, out, 0);

    // Determinism check: calling with same input produces same output
    static ap_int<PRIME_BIT> out2[N * RNS_NUM] = {};
    K_mulWise(poly1, poly2, out2, 0);

    for (int i = 0; i < N * RNS_NUM; i++) {
        if ((long long)out[i] != (long long)out2[i]) {
            std::cerr << "K_mulWise: non-deterministic at index " << i << "\n";
            return 1;
        }
    }

    return 0;
}
