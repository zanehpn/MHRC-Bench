
#include <cstdlib>
#include <iostream>
#include "aes.cpp"

int main() {
    aes_block_t plaintext = 0;
    aes_key_t key = 0;
    aes_block_t maskIn = 0;
    aes_block_t maskOut = 0;

    aes_block_t ct = aes_encrypt(plaintext, key, maskIn, maskOut);

    // Test with non-zero values
    aes_block_t pt2 = 0x00112233;
    aes_key_t key2 = 0x0F1571C9;
    aes_block_t ct2 = aes_encrypt(pt2, key2, maskIn, maskOut);

    // Different inputs should give different outputs
    if (ct == ct2) {
        std::cerr << "aes: different inputs produced same output\n";
        return 1;
    }

    return 0;
}
