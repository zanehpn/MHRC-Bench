#include <cmath>
#include <cstdlib>
#include <iostream>
#include "Example0_original.cpp"

int main() {
    float a[N], b[N], c[N];
    a[0] = 3.0f; b[0] = 1.0f;  // (4)*(2) = 8
    a[1] = 5.0f; b[1] = 2.0f;  // (7)*(3) = 21
    a[2] = 0.0f; b[2] = 0.0f;  // 0
    a[3] = -4.0f; b[3] = 3.0f; // (-1)*(-7) = 7
    for (int i = 4; i < N; ++i) { a[i] = 0; b[i] = 0; }
    InitiationInterval(a, b, c);
    float expected[] = {8.0f, 21.0f, 0.0f, 7.0f};
    for (int i = 0; i < 4; ++i) {
        if (std::fabs(c[i] - expected[i]) > 1e-4f) {
            std::cerr << "FAIL at " << i << ": got " << c[i] << " expected " << expected[i] << "\n";
            return 1;
        }
    }
    std::cout << "PASS: Example0\n";
    return 0;
}
