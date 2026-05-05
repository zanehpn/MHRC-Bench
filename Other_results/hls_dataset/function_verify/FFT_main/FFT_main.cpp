#include <iostream>
#include <complex>
#include <cstdlib>
#include <cstdio>
#include <cmath>

#define MAX 200
#define MY_PI 3.1415926535897932384

using namespace std;

int log2_fft(int N) {
    int k = N, i = 0;
    while(k) { k >>= 1; i++; }
    return i - 1;
}

int check(int n) {
    return n > 0 && (n & (n-1)) == 0;
}

int reverse_bits(int N, int n) {
    int j, p = 0;
    for(j = 1; j <= log2_fft(N); j++) {
        if(n & (1 << (log2_fft(N) - j)))
            p |= 1 << (j - 1);
    }
    return p;
}

void ordina(complex<double>* f1, int N) {
    complex<double> f2[MAX];
    for(int i = 0; i < N; i++)
        f2[i] = f1[reverse_bits(N, i)];
    for(int j = 0; j < N; j++)
        f1[j] = f2[j];
}

void transform(complex<double>* f, int N) {
    ordina(f, N);
    complex<double> W;
    int n = 1;
    int a = N / 2;
    for(int j = 0; j < log2_fft(N); j++) {
        for(int i = 0; i < N; i++) {
            if(!(i & n)) {
                W = polar(1., -2. * MY_PI * (i % n) / (2.0 * n));
                complex<double> temp = f[i];
                complex<double> Temp = W * f[i + n];
                f[i] = temp + Temp;
                f[i + n] = temp - Temp;
            }
        }
        n *= 2;
        a = a / 2;
    }
}

void FFT(complex<double> f[4], int N, double d) {
    transform(f, N);
    for(int i = 0; i < N; i++)
        f[i] *= d;
}

int main()
{
  int n = 4;
  double d = 1;
  complex<double> vec[4] = {1,1,1,1};

  FFT(vec, n, d);
  cout << "...printing the FFT of the array specified" << endl;
<TARGET>
    cout << vec[j] << endl;
  return 0;
}
