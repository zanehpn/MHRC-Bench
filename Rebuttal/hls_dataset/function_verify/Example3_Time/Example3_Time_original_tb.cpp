
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "Example3_Time_original.cpp"

int main() {
    float in[N * M] = {};
    float out[N * M] = {};

    // The stencil uses above_buffer[i] and center_buffer[i] where i is the row
    // index (0..M-1 init from memory_in[0..M-1]). Set memory_in[1] nonzero
    // so above_buffer[1] = memory_in[1] is non-zero for row i=1.
    in[1] = 3.0f;
    in[M + 1] = 6.0f;   // memory_in[11], but center_buffer[1]=memory_in[1]
    in[2*M + 0] = 9.0f; // below for (i=1, j=0)

    Stencil2D(in, out);

    // For i=1, j=0:
    //   above = above_buffer[1] = memory_in[1] = 3.0
    //   center = center_buffer[1] = memory_in[1] = 3.0
    //   below = memory_in[2*M+0] = 9.0
    //   average = 0.3333 * (3+3+9) = 0.3333*15 = 4.9995
    float expected = 0.3333f * (3.0f + 3.0f + 9.0f);
    if (std::fabs(out[1 * M + 0] - expected) > 0.01f) {
        std::cerr << "Example3_Time mismatch: got " << out[1*M+0]
                  << " expected " << expected << "\n";
        return 1;
    }
    return 0;
}
