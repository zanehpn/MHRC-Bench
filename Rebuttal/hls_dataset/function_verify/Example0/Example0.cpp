constexpr int N = 1024;

void InitiationInterval(float const *a_mem, float const *b_mem, float *c_mem) {
  for (int i = 0; i < N; ++i) {
    const auto a = a_mem[i];
    const auto b = b_mem[i];
    #pragma HLS PIPELINE II=1
<TARGET>
    c_mem[i] = c;
  }
}
