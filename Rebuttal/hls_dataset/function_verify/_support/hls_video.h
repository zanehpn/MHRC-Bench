
#pragma once

// Minimal mock of Xilinx Vivado HLS hls_video.h for C++ testbench compilation.

#include <cstring>
#include <queue>
#include <vector>
#include "ap_int.h"
#include "ap_fixed.h"
#include "hls_stream.h"
#include "ap_axi_sdata.h"

// ---------- pixel-type constants ----------
#define HLS_8UC1  0
#define HLS_8UC2  1
#define HLS_8UC3  2
#define HLS_8UC4  3
#define HLS_16SC1 4
#define HLS_32FC1 5

// colour-conversion codes
#define HLS_BGR2GRAY 0
#define HLS_GRAY2BGR 1
#define HLS_RGB2GRAY 2

namespace hls {

// ---------- Scalar ----------
template <int N, typename T>
struct Scalar {
    T val[N];
    Scalar() { for (int i = 0; i < N; i++) val[i] = T(); }
    Scalar(T v) { val[0] = v; for (int i = 1; i < N; i++) val[i] = T(); }
    template <typename U>
    Scalar &operator=(U v) { val[0] = static_cast<T>(v); return *this; }
    operator T() const { return val[0]; }
};

// ---------- Point_ ----------
template <typename T>
struct Point_ {
    T x, y;
    Point_() : x(0), y(0) {}
    Point_(T _x, T _y) : x(_x), y(_y) {}
};

// ---------- Mat ----------
template <int ROWS, int COLS, int TYPE>
class Mat {
public:
    static const int rows = ROWS;
    static const int cols = COLS;
    static const int type = TYPE;

    Mat() {}
    Mat(int, int) {}

    // pixel type helper
    using pixel_t = typename std::conditional<
        (TYPE == HLS_8UC3), Scalar<3, unsigned char>,
        typename std::conditional<
            (TYPE == HLS_8UC4), Scalar<4, unsigned char>,
            Scalar<1, unsigned char>
        >::type
    >::type;

    void write(const pixel_t &v) { q_.push(v); }
    pixel_t read() {
        if (q_.empty()) return pixel_t();
        pixel_t v = q_.front(); q_.pop(); return v;
    }
    void read(pixel_t &v) { v = read(); }

    bool empty() const { return q_.empty(); }

private:
    std::queue<pixel_t> q_;
};

// ---------- Window ----------
template <int ROWS, int COLS, typename T>
struct Window {
    T val[ROWS][COLS];
    Window() { std::memset(val, 0, sizeof(val)); }
    T getval(int r, int c) const { return val[r][c]; }
    void setval(int r, int c, T v) { val[r][c] = v; }
};

// ---------- LineBuffer ----------
template <int ROWS, int COLS, typename T>
struct LineBuffer {
    T val[ROWS][COLS];
    LineBuffer() { std::memset(val, 0, sizeof(val)); }
    T getval(int r, int c) const { return val[r][c]; }
    void setval(int r, int c, T v) { val[r][c] = v; }
    void shift_pixels_up(int col) {
        for (int i = 0; i < ROWS - 1; i++) val[i][col] = val[i + 1][col];
    }
    void insert_bottom_row(T v, int col) { val[ROWS - 1][col] = v; }
};

// ---------- Stream-based image functions (stubs) ----------

template <typename STREAM, int ROWS, int COLS, int TYPE>
void AXIvideo2Mat(STREAM &strm, Mat<ROWS, COLS, TYPE> &mat) {
    (void)strm; (void)mat;
}

template <int ROWS, int COLS, int TYPE, typename STREAM>
void Mat2AXIvideo(Mat<ROWS, COLS, TYPE> &mat, STREAM &strm) {
    (void)mat; (void)strm;
}

template <int CODE, int SRC_T, int DST_T, int ROWS, int COLS>
void CvtColor(Mat<ROWS, COLS, SRC_T> &src, Mat<ROWS, COLS, DST_T> &dst) {
    (void)src; (void)dst;
}

template <int ROWS, int COLS, int TYPE>
void EqualizeHist(Mat<ROWS, COLS, TYPE> &src, Mat<ROWS, COLS, TYPE> &dst) {
    (void)src; (void)dst;
}

template <int ROWS, int COLS, int SRC_T, int DST_T, int K_ROWS, int K_COLS, typename KT>
void Filter2D(Mat<ROWS, COLS, SRC_T> &src, Mat<ROWS, COLS, DST_T> &dst,
              Window<K_ROWS, K_COLS, KT> &kernel, Point_<int> anchor) {
    (void)src; (void)dst; (void)kernel; (void)anchor;
}

template <int ROWS, int COLS, int TYPE>
void Duplicate(Mat<ROWS, COLS, TYPE> &src,
               Mat<ROWS, COLS, TYPE> &dst1,
               Mat<ROWS, COLS, TYPE> &dst2) {
    (void)src; (void)dst1; (void)dst2;
}

}  // namespace hls

// AXI stream types commonly used with hls_video.h
typedef hls::stream<ap_axiu<24, 2, 5, 6>> AXI_STREAM_24;
typedef hls::stream<ap_axiu<8,  2, 5, 6>> AXI_STREAM_8;
