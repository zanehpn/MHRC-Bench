#include <iostream>
#include "present_perm_original.cpp"

int main() {
    // Test: set only bit 0, it should end up at position perm[0]=0
    present_block_t input = 1; // bit 0 set
    present_block_t output = pLayer(input);
    // perm[0]=0, so bit 0 of input goes to bit 0 of output
    if ((long long)output != 1) {
        std::cerr << "FAIL test1: got " << (long long)output << " expected 1\n";
        return 1;
    }

    // Set bit 1, it should end up at position perm[1]=16
    present_block_t input2 = 2; // bit 1 set
    present_block_t output2 = pLayer(input2);
    // bit 1 -> perm[1]=16
    if (((long long)output2 >> 16) & 1 != 1) {
        std::cerr << "FAIL test2: got " << (long long)output2 << "\n";
        return 1;
    }
    // Only one bit should be set
    long long v = (long long)output2;
    if (v != (1LL << 16)) {
        std::cerr << "FAIL test2b: got " << v << " expected " << (1LL<<16) << "\n";
        return 1;
    }

    // Test identity: pLayer is a permutation, so applying it to all-ones should give all-ones
    // (all 64 bits set)
    // But ap_uint<64> all ones = (2^64-1) which is tricky. Let's use a different test:
    // Set bit 4, perm[4]=1, so output should have bit 1 set
    present_block_t input3 = (long long)1 << 4; // bit 4
    present_block_t output3 = pLayer(input3);
    if ((long long)output3 != (1LL << 1)) {
        std::cerr << "FAIL test3: got " << (long long)output3 << " expected " << (1LL<<1) << "\n";
        return 1;
    }

    std::cout << "PASS: present_perm\n";
    return 0;
}
