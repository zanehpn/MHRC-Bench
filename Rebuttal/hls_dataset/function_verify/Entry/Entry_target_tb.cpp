
#include <cstdlib>
#include <cstring>
#include <iostream>

static int g_calls = 0;

void MatrixMultiplication(const double A[], const double B[], double C[]) {
    ++g_calls;
    C[0] = A[0] + B[0];
}

#include "Entry.cpp"

int main() {
    double A[N * K] = {};
    double B[K * M] = {};
    double C[N * M] = {};
    A[0] = 2.0;
    B[0] = 5.0;

    Example5_Reordered(A, B, C);

    if (g_calls != 1 || C[0] != 7.0) {
        std::cerr << "Entry wrapper did not invoke MatrixMultiplication\n";
        return 1;
    }
    return 0;
}
