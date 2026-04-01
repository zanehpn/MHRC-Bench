#include <iostream>
#include "K_mov_original.cpp"

int main() {
    data_t in[RNS_NUM*N], out[RNS_NUM*N];
    for (int i = 0; i < RNS_NUM*N; i++) {
        in[i] = (data_t)(i * 7 + 3);
        out[i] = 0;
    }
    K_mov(in, out);
    for (int i = 0; i < RNS_NUM*N; i++) {
        if ((long long)out[i] != (long long)in[i]) {
            std::cerr << "FAIL at " << i << ": got " << (long long)out[i]
                      << " expected " << (long long)in[i] << "\n";
            return 1;
        }
    }
    std::cout << "PASS: K_mov\n";
    return 0;
}
