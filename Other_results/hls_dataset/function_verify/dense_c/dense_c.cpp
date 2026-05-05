#include <cmath>
#include <cstring>

#define FLAT_SIZE 16
#define DENSE_SIZE 8
#define DIGITS 4

// Simplified weights and biases
static float dense_weights[FLAT_SIZE][DENSE_SIZE];
static float dense_biases[DENSE_SIZE];

void soft_max(float dense_array[DENSE_SIZE], float pred[DIGITS]) {
    float sum = 0;
    for (int i = 0; i < DIGITS; i++) {
        pred[i] = expf(dense_array[i]);
        sum += pred[i];
    }
    for (int i = 0; i < DIGITS; i++) pred[i] /= sum;
}

void dense_layer(float flat_array[FLAT_SIZE], float prediction[DIGITS])
{
<TARGET>
  float dense_array[DENSE_SIZE] = { 0 };

  for (int d = 0; d < DENSE_SIZE; ++d)
  {
    w_sum = 0.0;
    for (int f = 0; f < FLAT_SIZE; ++f)
    {
      w_sum += dense_weights[f][d] * flat_array[f];
    }
    dense_array[d] = w_sum + dense_biases[d];
  }

  soft_max(dense_array, prediction);
}
