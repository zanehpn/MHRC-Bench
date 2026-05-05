#include <cmath>

typedef float TYPE_T;

inline TYPE_T activation_linear(TYPE_T x) {
    return x;
}

inline TYPE_T activation_sigmoid(TYPE_T x) {
    const TYPE_T c = -1.0;
<TARGET>
}

inline TYPE_T activation_hardsigmoid(TYPE_T x) {
    const TYPE_T m = 0.2;
    const TYPE_T n = 0.5;
    TYPE_T v = x * m + n;
    if (v <= 0) return 0;
    else if (v >= 1) return 1;
    else return v;
}

inline TYPE_T activation_relu(TYPE_T x) {
    if (x >= 0) return x;
    else return 0;
}
