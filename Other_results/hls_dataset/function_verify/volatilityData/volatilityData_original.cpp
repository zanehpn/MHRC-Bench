#include <cmath>

typedef float data_t;

class volData {
public:
    data_t expect, kappa, variance, initValue, correlation;
    volData() : expect(0), kappa(0), variance(0), initValue(0), correlation(0) {}
    static data_t truncFun1(data_t x) { return x; }
    static data_t truncFun2(data_t x)
{ 	return fmax(x,0); }
    static data_t truncFun3(data_t x) { return fmax(x,0); }
};
