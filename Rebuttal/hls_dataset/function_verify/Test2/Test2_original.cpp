#include <algorithm>
#include <iostream>
#include <random>
#include <vector>

constexpr int N = 32;
constexpr int M = 32;

void Stencil2D(float const in[], float out[]) {
  for (int i = 1; i < N - 1; ++i) {
    for (int j = 0; j < M; ++j) {
      out[i * M + j] =
          0.3333f * (in[(i - 1) * M + j] + in[i * M + j] + in[(i + 1) * M + j]);
    }
  }
}

void Reference(float const in[], float out[]) {
  for (int i = 1; i < N - 1; ++i) {
    for (int j = 0; j < M; ++j) {
      out[i * M + j] =
          0.3333f * (in[(i - 1) * M + j] + in[i * M + j] + in[(i + 1) * M + j]);
    }
  }
}

int main() {
  std::vector<float> in(N * M);
  std::default_random_engine rng;
  std::uniform_real_distribution<float> dist;
  std::for_each(in.begin(), in.end(), [&](float &i) { i = dist(rng); });

  std::vector<float> out_ref(N * M);
  std::vector<float> out_res(N * M);

  Stencil2D(in.data(), out_res.data());
  Reference(in.data(), out_ref.data());

  for (int i = 0; i < N; ++i) {
    for (int j = 0; j < M; ++j) {
      const auto diff = std::abs(out_ref[i * M + j] - out_res[i * M + j]);
      if (diff > 1e-4) {
        std::cerr << "Mismatch at (" << i << ", " << j << ")\n";
        return 1;
      }
    }
  }
  std::cout << "Test ran successfully.\n";
  return 0;
}
