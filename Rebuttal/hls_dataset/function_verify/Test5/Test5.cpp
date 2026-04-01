#include <algorithm>
#include <iostream>
#include <random>
#include <vector>

constexpr int N = 32;
constexpr int K = N;
constexpr int M = N;

void MatrixMultiplication(double const A[], double const B[], double C[]) {
  for (int n = 0; n < N; ++n) {
    for (int m = 0; m < M; ++m) {
      C[n * M + m] = 0;
      for (int k = 0; k < K; ++k) {
        C[n * M + m] += A[n * K + k] * B[k * M + m];
      }
    }
  }
}

void Reference(double const a[], double const b[], double c[]) {
<TARGET>
    for (int m = 0; m < M; ++m) {
      c[n * M + m] = 0;
      for (int k = 0; k < K; ++k) {
        c[n * M + m] += a[n * K + k] * b[k * M + m];
      }
    }
  }
}

int main() {
  std::vector<double> a(N * K);
  std::vector<double> b(K * M);
  std::vector<double> c(N * M);
  std::vector<double> c_ref(N * M, 0);

  std::random_device rd;
  std::default_random_engine rng;
  std::uniform_real_distribution<double> dist;
  std::for_each(a.begin(), a.end(), [&](double &i) { i = dist(rng); });
  std::for_each(b.begin(), b.end(), [&](double &i) { i = dist(rng); });

  MatrixMultiplication(a.data(), b.data(), c.data());
  Reference(a.data(), b.data(), c_ref.data());

  for (int i = 0; i < N * M; ++i) {
    const auto diff = std::abs(c_ref[i] - c[i]);
    if (diff >= 1e-3) {
      std::cout << "Mismatch at (" << i / M << ", " << i % M << "): " << c[i]
                << " (should be " << c_ref[i] << ").\n";
      return 1;
    }
  }
  std::cout << "Test ran successfully.\n";
  return 0;
}
