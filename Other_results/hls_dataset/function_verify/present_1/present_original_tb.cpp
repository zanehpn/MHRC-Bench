
#include <cstdlib>
#include <iostream>
#include "present_original.cpp"

int main() {
    present_block_t plaintext = 0;
    present_key_t key = 0;
    present_block_t maskIn = 0;
    present_block_t maskOut = 0;

    present_block_t ct = present_encrypt(plaintext, key, maskIn, maskOut);

    // Test with non-zero values
    present_block_t pt2 = 0x00112233;
    present_key_t key2 = (present_key_t)0x0F1571C947AE1234ULL;
    present_block_t ct2 = present_encrypt(pt2, key2, maskIn, maskOut);

    // Different inputs should give different outputs
    if (ct == ct2) {
        std::cerr << "present_1: different inputs produced same output\n";
        return 1;
    }

    return 0;
}
