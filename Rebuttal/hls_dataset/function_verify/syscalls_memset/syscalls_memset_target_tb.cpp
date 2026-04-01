#include <cstring>
#include <iostream>
#include "syscalls_memset.cpp"

int main() {
    // Test aligned case
    uintptr_t buf[4] = {0};
    my_memset(buf, 0xAB, sizeof(buf));
    unsigned char *p = (unsigned char*)buf;
    for (size_t i = 0; i < sizeof(buf); i++) {
        if (p[i] != 0xAB) {
            std::cerr << "FAIL aligned at " << i << ": got " << (int)p[i] << "\n";
            return 1;
        }
    }

    // Test unaligned case
    char buf2[7] = {0};
    my_memset(buf2, 0x42, 7);
    for (int i = 0; i < 7; i++) {
        if ((unsigned char)buf2[i] != 0x42) {
            std::cerr << "FAIL unaligned at " << i << "\n";
            return 1;
        }
    }

    std::cout << "PASS: syscalls_memset\n";
    return 0;
}
