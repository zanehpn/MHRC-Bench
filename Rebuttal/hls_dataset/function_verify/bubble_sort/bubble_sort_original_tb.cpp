// Testbench for bubble_sort_original.cpp
// Includes the DUT source directly, redirecting CCS_MAIN so it does not
// collide with the testbench main().

#include <cstdlib>
#include <iostream>

// Override CCS_MAIN so the embedded main becomes a helper function
#define CCS_MAIN(...) static int _dut_main(__VA_ARGS__)
#include "bubble_sort_original.cpp"
#undef CCS_MAIN

int main() {
    const int N = 5;
    T values[N];
    values[0] = 5.0f;
    values[1] = 3.0f;
    values[2] = 4.0f;
    values[3] = 1.0f;
    values[4] = 2.0f;

    bubbleSort<N>(values);

    // Verify ascending order
    for (int i = 0; i < N; ++i) {
        float observed = values[i].to_float();
        float expected = float(i + 1);
        if (observed != expected) {
            std::cerr << "FAIL: bubble_sort_original mismatch at index "
                      << i << ": got " << observed
                      << " expected " << expected << "\n";
            return 1;
        }
    }
    std::cout << "PASS: bubble_sort_original sorted correctly\n";
    return 0;
}
