
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "Example3_Time.cpp"

int main() {
    float in[N * M] = {};
    float out[N * M] = {};
    in[0 * M + 4] = 3.0f;
    in[1 * M + 4] = 6.0f;
    in[2 * M + 4] = 9.0f;

    Stencil2D(in, out);

    const float expected = 0.3333f * (3.0f + 6.0f + 9.0f);
    if (std::fabs(out[1 * M + 4] - expected) > 1e-4f) {
        std::cerr << "Example3_Time vertical stencil mismatch\n";
        return 1;
    }
    return 0;
}
