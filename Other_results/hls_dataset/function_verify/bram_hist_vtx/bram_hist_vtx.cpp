#include <cstdio>

#define BHV_NHALFBINS 32
#define BHV_NSECTORS 4

typedef short ptsum_t;
typedef short zbin_t;

static ptsum_t hist[BHV_NSECTORS][2*BHV_NHALFBINS];

void find_best_bin(zbin_t &best_bin, ptsum_t &best_sum) {
    zbin_t ibest = 0;
    int sbest = 0;
    for (unsigned int i = 0; i < BHV_NHALFBINS; ++i) {
<TARGET>
        for (unsigned int is = 0; is < BHV_NSECTORS; ++is) {
            ptsum_t p1 = hist[is][BHV_NHALFBINS + i];
            ptsum_t p2 = hist[is][BHV_NHALFBINS - 1 - i];
            sum1 += p1;
            sum2 += p2;
        }
        if (sum1 > sbest) { sbest = sum1; ibest = BHV_NHALFBINS + i; }
        if (sum2 > sbest) { sbest = sum2; ibest = BHV_NHALFBINS - 1 - i; }
    }
    best_bin = ibest;
    best_sum = sbest;
}
