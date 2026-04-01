#include <iostream>
#include <cstring>
#define TESTMP7
#include "regionizer.cpp"

int main() {
    // Test merge_hadcalo and regionize_hadcalo (target version with <TARGET>)
    hls::stream<HadCaloObj> fibers[N_IN_SECTORS];
    HadCaloObj regions[N_OUT_REGIONS][NCALO];

    for (int r = 0; r < N_OUT_REGIONS; r++)
        for (int c = 0; c < NCALO; c++)
            clear(regions[r][c]);

    for (int s = 0; s < N_IN_SECTORS; s++) {
        for (int i = 0; i < NCALO_PER_SECTOR; i++) {
            HadCaloObj obj;
            clear(obj);
            if (i < 2) {
                obj.hwPt = (s * 10 + i + 1);
                obj.hwEta = 0;
                obj.hwPhi = 0;
            }
            fibers[s].write(obj);
        }
    }

    regionize_hadcalo(fibers, regions);

    int total_nonzero = 0;
    for (int r = 0; r < N_OUT_REGIONS; r++)
        for (int c = 0; c < NCALO; c++)
            if ((int)regions[r][c].hwPt > 0)
                total_nonzero++;

    if (total_nonzero == 0) {
        std::cerr << "FAIL: regionize_hadcalo produced all-zero output\n";
        return 1;
    }

    HadCaloObj list1[NCALO_PER_SECTOR_PER_ETA], list2[NCALO_PER_SECTOR_PER_ETA], list3[NCALO_PER_SECTOR_PER_ETA];
    HadCaloObj out[NCALO];
    for (int i = 0; i < NCALO_PER_SECTOR_PER_ETA; i++) {
        clear(list1[i]); clear(list2[i]); clear(list3[i]);
    }
    for (int i = 0; i < NCALO; i++) clear(out[i]);

    list1[0].hwPt = 100; list1[0].hwEta = 5; list1[0].hwPhi = 10;
    list2[0].hwPt = 200; list2[0].hwEta = 3; list2[0].hwPhi = 8;
    list3[0].hwPt = 50;  list3[0].hwEta = 7; list3[0].hwPhi = 12;

    merge_hadcalo(list1, 0, list2, 0, list3, 0, out);

    if ((int)out[0].hwPt != 200) {
        std::cerr << "FAIL: merge_hadcalo top pt=" << (int)out[0].hwPt << " expected 200\n";
        return 1;
    }
    if ((int)out[1].hwPt != 100) {
        std::cerr << "FAIL: merge_hadcalo 2nd pt=" << (int)out[1].hwPt << " expected 100\n";
        return 1;
    }

    std::cout << "PASS: regionizer target tests passed\n";
    return 0;
}
