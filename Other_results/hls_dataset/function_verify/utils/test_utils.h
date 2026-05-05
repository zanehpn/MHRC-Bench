#ifndef TEST_UTILS_H
#define TEST_UTILS_H

#include "../firmware/data.h"

bool track_equals(const TkObj &out_ref, const TkObj &out, const char *what, int idx) {
    return out_ref.hwPt == out.hwPt && out_ref.hwEta == out.hwEta && out_ref.hwPhi == out.hwPhi;
}
bool had_equals(const HadCaloObj &out_ref, const HadCaloObj &out, const char *what, int idx) {
    return out_ref.hwPt == out.hwPt && out_ref.hwEta == out.hwEta && out_ref.hwPhi == out.hwPhi;
}
bool em_equals(const EmCaloObj &out_ref, const EmCaloObj &out, const char *what, int idx) {
    return out_ref.hwPt == out.hwPt && out_ref.hwEta == out.hwEta && out_ref.hwPhi == out.hwPhi;
}
bool mu_equals(const MuObj &out_ref, const MuObj &out, const char *what, int idx) {
    return out_ref.hwPt == out.hwPt && out_ref.hwEta == out.hwEta && out_ref.hwPhi == out.hwPhi;
}
bool pf_equals(const PFChargedObj &out_ref, const PFChargedObj &out, const char *what, int idx) {
    return out_ref.hwPt == out.hwPt && out_ref.hwEta == out.hwEta && out_ref.hwPhi == out.hwPhi;
}
bool pf_equals(const PFNeutralObj &out_ref, const PFNeutralObj &out, const char *what, int idx) {
    return out_ref.hwPt == out.hwPt && out_ref.hwEta == out.hwEta && out_ref.hwPhi == out.hwPhi;
}

template<typename T>
unsigned int count_nonzero(const T arr[], unsigned int N) {
    unsigned int cnt = 0;
    for (unsigned int i = 0; i < N; ++i) {
        if (arr[i].hwPt > 0) cnt++;
    }
    return cnt;
}

#endif
