
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "Example1_original.cpp"

int main() {
    float in[N] = {};
    float out[N] = {};
    in[1] = 3.0f;
    in[2] = 6.0f;
    in[3] = 9.0f;

    Simple1DStencil(in, out);

    const float expected = 0.3333f * (3.0f + 6.0f + 9.0f);
    if (std::fabs(out[2] - expected) > 1e-4f) {
        std::cerr << "Example1 stencil mismatch\n";
        return 1;
    }
    return 0;
}
