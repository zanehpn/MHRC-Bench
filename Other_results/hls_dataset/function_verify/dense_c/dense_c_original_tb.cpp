#include <cmath>
#include <iostream>
#include "dense_c_original.cpp"

int main() {
    // Set simple weights: identity-like
    for (int f = 0; f < FLAT_SIZE; f++)
        for (int d = 0; d < DENSE_SIZE; d++)
            dense_weights[f][d] = (f == d) ? 1.0f : 0.0f;
    for (int d = 0; d < DENSE_SIZE; d++)
        dense_biases[d] = 0.0f;

    float flat[FLAT_SIZE] = {1.0f, 2.0f, 3.0f, 4.0f, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    float pred[DIGITS];
    dense_layer(flat, pred);

    // pred should be softmax of {1,2,3,4}
    float expected[4];
    float sum = 0;
    for (int i = 0; i < 4; i++) { expected[i] = expf((float)(i+1)); sum += expected[i]; }
    for (int i = 0; i < 4; i++) expected[i] /= sum;

    for (int i = 0; i < DIGITS; i++) {
        if (std::fabs(pred[i] - expected[i]) > 1e-4f) {
            std::cerr << "FAIL at " << i << ": " << pred[i] << " vs " << expected[i] << "\n";
            return 1;
        }
    }
    std::cout << "PASS: dense_c\n";
    return 0;
}
