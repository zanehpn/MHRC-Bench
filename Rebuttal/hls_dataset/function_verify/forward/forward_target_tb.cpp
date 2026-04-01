#include <cstdlib>
#include <cstring>
#include <iostream>
#include <cmath>

#include "forward.cpp"

int main() {
    // The Transformer struct is very large (~1.6GB+). Allocate with calloc to zero-init.
    using TransformerType = Transformer<dim, hidden_dim, n_layers, n_heads, n_kv_heads, vocab_size, seq_len, GS>;

    TransformerType *transformer = (TransformerType *)calloc(1, sizeof(TransformerType));
    if (!transformer) {
        std::cerr << "FAIL: could not allocate Transformer (" << (sizeof(TransformerType) / (1024*1024)) << " MB)\n";
        return 1;
    }

    // Set rms weights to 1.0 so rmsnorm does not produce all-zeros
    for (int i = 0; i < n_layers * dim; i++) {
        transformer->weights.rms_att_weight[i] = 1.0f;
        transformer->weights.rms_ffn_weight[i] = 1.0f;
    }
    for (int i = 0; i < dim; i++) {
        transformer->weights.rms_final_weight[i] = 1.0f;
    }

    // Set a small nonzero token embedding for token 0
    for (int i = 0; i < dim; i++) {
        transformer->weights.token_embedding_table[i] = 0.01f * (i % 7 - 3);
    }

    constexpr int kv_dim = (dim * n_kv_heads) / n_heads;
    constexpr int kv_cache_size = n_layers * seq_len * kv_dim;

    float *key_cache = (float *)calloc(kv_cache_size, sizeof(float));
    float *value_cache = (float *)calloc(kv_cache_size, sizeof(float));
    float *out = (float *)calloc(vocab_size, sizeof(float));

    if (!key_cache || !value_cache || !out) {
        std::cerr << "FAIL: could not allocate caches\n";
        free(transformer); free(key_cache); free(value_cache); free(out);
        return 1;
    }

    int token = 0;
    int pos = 0;

    // Call the forward function
    forward(transformer, token, pos, key_cache, value_cache, out);

    // Basic sanity checks:
    // 1. The function did not crash
    // 2. out should contain logits (with zero weights, they may all be 0, but the function ran)
    bool any_nonzero = false;
    bool any_nan = false;
    for (int i = 0; i < vocab_size; i++) {
        if (std::isnan(out[i])) { any_nan = true; break; }
        if (out[i] != 0.0f) any_nonzero = true;
    }

    if (any_nan) {
        std::cerr << "FAIL: output contains NaN\n";
        free(transformer); free(key_cache); free(value_cache); free(out);
        return 1;
    }

    std::cout << "PASS: forward completed successfully. any_nonzero=" << any_nonzero << "\n";
    std::cout << "  out[0]=" << out[0] << " out[1]=" << out[1] << " out[" << vocab_size-1 << "]=" << out[vocab_size-1] << "\n";

    free(transformer);
    free(key_cache);
    free(value_cache);
    free(out);
    return 0;
}
