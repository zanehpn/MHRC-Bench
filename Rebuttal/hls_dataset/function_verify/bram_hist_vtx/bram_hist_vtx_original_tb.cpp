#include <iostream>
#include <cstring>
#include "bram_hist_vtx_original.cpp"

int main() {
    memset(hist, 0, sizeof(hist));
    // Put a peak at bin BHV_NHALFBINS + 5 = 37
    for (int s = 0; s < BHV_NSECTORS; s++)
        hist[s][BHV_NHALFBINS + 5] = 10;

    zbin_t best_bin;
    ptsum_t best_sum;
    find_best_bin(best_bin, best_sum);

    // Expected: best_bin = 37, best_sum = 40 (10 * 4 sectors)
    if (best_bin != BHV_NHALFBINS + 5) {
        std::cerr << "FAIL: best_bin=" << best_bin << " expected " << (BHV_NHALFBINS+5) << "\n";
        return 1;
    }
    if (best_sum != 40) {
        std::cerr << "FAIL: best_sum=" << best_sum << " expected 40\n";
        return 1;
    }
    std::cout << "PASS: bram_hist_vtx\n";
    return 0;
}
