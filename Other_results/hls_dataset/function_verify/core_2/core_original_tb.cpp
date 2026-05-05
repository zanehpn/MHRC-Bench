// Testbench for core_2/core_original.cpp
// Includes the DUT source directly.
// Since the HLS image processing functions (Duplicate, etc.) are stubs,
// we test that the code compiles and link correctly, and exercise only
// the parts that don't depend on live pixel streams.

#include <iostream>
#include "core_original.cpp"

int main() {
    // Verify types and constants compile
    GRAY_IMAGE img_a(IMG_HEIGHT_OR_ROWS, IMG_WIDTH_OR_COLS);
    GRAY_IMAGE img_b(IMG_HEIGHT_OR_ROWS, IMG_WIDTH_OR_COLS);

    // Feed a single pixel and read it back to confirm Mat API works
    hls::Scalar<1, unsigned char> px;
    px.val[0] = 42;
    img_a.write(px);

    hls::Scalar<1, unsigned char> out = img_a.read();
    if (out.val[0] != 42) {
        std::cerr << "FAIL: core_2 pixel round-trip mismatch\n";
        return 1;
    }

    // Verify expArray table is accessible and has expected values
    if (expArray[0] != 0.0f) {
        std::cerr << "FAIL: expArray[0] expected 0.0\n";
        return 1;
    }

    std::cout << "PASS: core_2 original compiled and basic API verified\n";
    return 0;
}
