from __future__ import annotations

import json
import os
import shutil
import textwrap
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent.parent.parent.parent
FV = ROOT / "hls_dataset" / "function_verify"
HLS = ROOT / "hls"
MANIFEST = FV / "design_function_verify_candidates_50.jsonl"


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n")


support_files = {
    FV / "_support" / "hls_stream.h": r"""
        #pragma once

        #include <cassert>
        #include <queue>
        #include <string>

        namespace hls {
        template <typename T, int DEPTH = 0>
        class stream {
        public:
            stream() = default;
            explicit stream(const char *) {}
            explicit stream(const std::string &) {}

            void write(const T &value) { q_.push(value); }

            T read() {
                assert(!q_.empty());
                T value = q_.front();
                q_.pop();
                return value;
            }

            bool empty() const { return q_.empty(); }
            bool full() const { return false; }
            std::size_t size() const { return q_.size(); }

        private:
            std::queue<T> q_;
        };

        template <typename T, int DEPTH>
        stream<T, DEPTH> &operator<<(stream<T, DEPTH> &s, const T &value) {
            s.write(value);
            return s;
        }

        template <typename T, int DEPTH>
        stream<T, DEPTH> &operator>>(stream<T, DEPTH> &s, T &value) {
            value = s.read();
            return s;
        }
        }  // namespace hls
    """,
    FV / "_support" / "hls_math.h": r"""
        #pragma once

        #include <cmath>

        namespace hls {
        template <typename T>
        inline auto sqrt(T value) {
            return std::sqrt(value);
        }
        }  // namespace hls
    """,
    FV / "_support" / "ap_fixed.h": r"""
        #pragma once

        #ifndef AP_RND_CONV
        #define AP_RND_CONV 0
        #endif

        template <int W, int I, int Q = 0, int O = 0, int N = 0>
        using ap_fixed = float;

        template <int W, int I, int Q = 0, int O = 0, int N = 0>
        using ap_ufixed = float;
    """,
    FV / "_support" / "ap_int.h": r"""
        #pragma once

        template <int W>
        using ap_int = long long;

        template <int W>
        using ap_uint = unsigned long long;
    """,
    FV / "_support" / "ap_axi_sdata.h": r"""
        #pragma once

        #include "ap_int.h"

        template <int D, int U, int TI, int TD>
        struct ap_axiu {
            ap_uint<D> data = 0;
            ap_uint<(D + 7) / 8> keep = 0;
            ap_uint<(D + 7) / 8> strb = 0;
            ap_uint<U> user = 0;
            ap_uint<1> last = 0;
            ap_uint<TI> id = 0;
            ap_uint<TD> dest = 0;
        };

        namespace hls {
        template <typename T, int U, int TI, int TD>
        struct axis {
            T data{};
            ap_uint<1> last = 0;
            ap_uint<1> keep = 0;
            ap_uint<1> strb = 0;
            ap_uint<U> user = 0;
            ap_uint<TI> id = 0;
            ap_uint<TD> dest = 0;
        };
        }  // namespace hls
    """,
    FV / "_support" / "mc_scverify.h": r"""
        #pragma once

        #ifndef CCS_BLOCK
        #define CCS_BLOCK(x) x
        #endif

        #ifndef CCS_MAIN
        #define CCS_MAIN(...) int main(__VA_ARGS__)
        #endif

        #ifndef CCS_RETURN
        #define CCS_RETURN(x) return (x)
        #endif
    """,
}


copied_headers = {
    FV / "03-Headers" / "definitions.h": HLS / "HLS-CNN" / "Code" / "03-Headers" / "definitions.h",
}


local_headers = {
    FV / "conv2" / "conv2.h": """
        #pragma once
        #define INP_IMAGE_SIZE 31
        #define INP_IMAGE_CHANNEL 96
        #define OUT_IMAGE_SIZE 27
        #define FILTER_BATCH 256
        #define FILTER_CHANNEL 48
        #define FILTER_SIZE 5
        #define STRIDE 1
        #define STRIDE_NEW 5
        #define GROUP 2
    """,
    FV / "norm2" / "norm2.h": """
        #pragma once
        #define INP_IMAGE_SIZE 13
        #define INP_IMAGE_CHANNEL 256
        #define OUT_IMAGE_SIZE 13
        #define OUT_IMAGE_CHANNEL 256
    """,
    FV / "conv4" / "conv4.h": """
        #pragma once
        #define INP_IMAGE_SIZE 15
        #define INP_IMAGE_CHANNEL 384
        #define OUT_IMAGE_SIZE 13
        #define FILTER_BATCH 384
        #define FILTER_CHANNEL 192
        #define FILTER_SIZE 3
        #define STRIDE 1
        #define STRIDE_NEW 3
        #define GROUP 2
    """,
    FV / "conv5" / "conv5.h": """
        #pragma once
        #define INP_IMAGE_SIZE 15
        #define INP_IMAGE_CHANNEL 384
        #define OUT_IMAGE_SIZE 13
        #define FILTER_BATCH 256
        #define FILTER_CHANNEL 192
        #define FILTER_SIZE 3
        #define STRIDE 1
        #define STRIDE_NEW 3
        #define GROUP 2
    """,
    FV / "spmv" / "spmv.h": """
        #pragma once
        const static int SIZE = 256;
        const static int NNZ = 3277;
        const static int NUM_ROWS = 256;
        typedef float DTYPE;
        void spmv(int rowPtr[NUM_ROWS + 1], int columnIndex[NNZ], DTYPE values[NNZ], DTYPE y[SIZE], DTYPE x[SIZE]);
        void mv(DTYPE A[SIZE][SIZE], DTYPE y[SIZE], DTYPE x[SIZE]);
    """,
    FV / "spmv_fast_stream" / "spmv.h": """
        #pragma once
        const static int SIZE = 256;
        const static int NNZ = 3277;
        const static int NUM_ROWS = 256;
        typedef float DTYPE;
        void spmv(int rowPtr[NUM_ROWS + 1], int cols[NNZ], DTYPE values[NNZ], DTYPE y[SIZE], DTYPE x[SIZE]);
    """,
    FV / "spmv_naive_stream" / "spmv.h": """
        #pragma once
        const static int SIZE = 256;
        const static int NNZ = 3277;
        const static int NUM_ROWS = 256;
        typedef float DTYPE;
        void spmv(int rowPtr[NUM_ROWS + 1], int cols[NNZ], DTYPE values[NNZ], DTYPE y[SIZE], DTYPE x[SIZE]);
    """,
    FV / "spmv_partial_unrolling" / "spmv.h": """
        #pragma once
        const static int SIZE = 256;
        const static int NNZ = 3277;
        const static int NUM_ROWS = 256;
        typedef float DTYPE;
        void spmv(int rowPtr[NUM_ROWS + 1], int columnIndex[NNZ], DTYPE values[NNZ], DTYPE y[SIZE], DTYPE x[SIZE]);
    """,
    FV / "Entry" / "Example5.h": """
        #pragma once
        constexpr int N = 32;
        constexpr int K = N;
        constexpr int M = N;
        void MatrixMultiplication(const double A[], const double B[], double C[]);
        void Example5(double const A[], double const B[], double C[]);
        void Example5_Reordered(double const A[], double const B[], double C[]);
    """,
    FV / "Example5" / "Example5.h": """
        #pragma once
        constexpr int N = 32;
        constexpr int K = N;
        constexpr int M = N;
        void MatrixMultiplication(const double A[], const double B[], double C[]);
        void Entry(double const A[], double const B[], double C[]);
    """,
    FV / "Example3_Time" / "Example3.h": """
        #pragma once
        constexpr int N = 10;
        constexpr int M = 10;
        constexpr int T = 10;
        void Stencil2D(float const memory_in[N * M], float memory_out[N * M]);
        void Example3(float const *in, float *out);
    """,
    FV / "dsp_pipeline" / "HLS_dataflow_accel_dsp.hpp": """
        #pragma once
        #include <hls_stream.h>
        #include <ap_int.h>
        typedef float data_t;
        void dsp_pipeline(hls::stream<data_t>& in_stream, hls::stream<data_t>& out_stream, float gain);
    """,
    FV / "HLS_MAC_accel" / "HLS_MAC_accel.hpp": """
        #pragma once
        #include <ap_int.h>
        #include <ap_axi_sdata.h>
        #include <hls_stream.h>
        typedef ap_int<16> data_t;
        typedef ap_int<32> acc_t;
        typedef hls::axis<data_t, 0, 0, 0> axis_t;
        void load_input(hls::stream<axis_t>& in, data_t& a, data_t& b);
        acc_t multiply_accumulate(data_t a, data_t b, data_t coefficient);
        void store_result(hls::stream<axis_t>& out, acc_t result);
        void mac_top(hls::stream<axis_t>& in, hls::stream<axis_t>& out, data_t coefficient);
    """,
    FV / "lock_free_SPSCq" / "lock_free_SPSCq.hpp": """
        #pragma once
        #include <ap_int.h>
        #include <hls_stream.h>
        #define QDEPTH 1024
        #define BITS 32
        typedef ap_uint<BITS> data_t;
        struct queue_state {
            ap_uint<10> head;
            ap_uint<10> tail;
        };
        void spsc_top(hls::stream<data_t> &in, hls::stream<data_t> &out, volatile data_t buffer_r[QDEPTH], volatile queue_state &state);
    """,
    FV / "doHist" / "core.h": """
        #pragma once
        #include <hls_stream.h>
        #include <ap_axi_sdata.h>
        typedef ap_axiu<8,2,5,6> uint8_sidechannel;
        void doHist(hls::stream<uint8_sidechannel> &instream,int histo[256]);
    """,
    FV / "doHiststretch" / "core.h": """
        #pragma once
        #include <hls_stream.h>
        #include <ap_axi_sdata.h>
        typedef ap_axiu<8,2,5,6> uint8_sidechannel;
        void doHiststretch(hls::stream<uint8_sidechannel> &instream,hls::stream<uint8_sidechannel> &outstream, unsigned char xMin, unsigned char xMax);
    """,
    FV / "conv" / "conv.hh": """
        #pragma once
        #include "../03-Headers/definitions.h"
        #include "hls_stream.h"
        float relu(float x);
        void convolution(float pad_img [PAD_IMG_ROWS][PAD_IMG_COLS], int filter, hls::stream<float> & conv_to_pool_stream);
        void convolutional_layer(float pad_img0 [PAD_IMG_ROWS][PAD_IMG_COLS], float pad_img1 [PAD_IMG_ROWS][PAD_IMG_COLS], float pad_img2 [PAD_IMG_ROWS][PAD_IMG_COLS], float pad_img3 [PAD_IMG_ROWS][PAD_IMG_COLS], hls::stream<float> conv_to_pool_streams [FILTERS]);
    """,
    FV / "dense" / "dense.hh": """
        #pragma once
        #include "../03-Headers/definitions.h"
        #include "hls_stream.h"
        void dense_layer_soft_max(hls::stream<float> dense_to_softmax_streams [FILTERS], float prediction [DIGITS]);
        void dense(hls::stream<float> & flat_to_dense_stream, int filter, hls::stream<float> & dense_to_softmax_stream);
        void dense_layer(hls::stream<float> flat_to_dense_streams [FILTERS], hls::stream<float> dense_to_softmax_streams [FILTERS]);
    """,
    FV / "flat" / "flat.hh": """
        #pragma once
        #include "../03-Headers/definitions.h"
        #include "hls_stream.h"
        void flattening(hls::stream<float> & pool_to_flat_stream, hls::stream<float> & flat_to_dense_stream);
        void flattening_layer(hls::stream<float> pool_to_flat_streams[FILTERS], hls::stream<float> flat_to_dense_streams[FILTERS]);
    """,
    FV / "03-Headers" / "conv_weights.h": """
        #pragma once
        #include "definitions.h"
        static const float conv_weights[FILTERS][KRN_ROWS][KRN_COLS] = {
            {
                {1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f},
                {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f},
                {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f},
                {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f},
                {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f},
                {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f},
                {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}
            },
            {},
            {},
            {}
        };
        static const float conv_biases[FILTERS] = {0.5f, 0.0f, 0.0f, 0.0f};
    """,
    FV / "03-Headers" / "dense_weights.h": """
        #pragma once
        #include "definitions.h"
        static const float dense_weights[FLAT_SIZE][DENSE_SIZE] = {
            {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f, 10.0f}
        };
        static const float dense_biases[DENSE_SIZE] = {0.0f};
    """,
}


runtime_testbenches = {
    "conv2": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "conv2.cpp"

        int main() {
            static float inp_img[INP_IMAGE_SIZE * INP_IMAGE_SIZE * INP_IMAGE_CHANNEL] = {};
            static float out_img[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH] = {};
            static float filter[FILTER_BATCH * INP_IMAGE_CHANNEL * FILTER_SIZE * FILTER_SIZE] = {};
            static float bias[FILTER_BATCH] = {};

            const int second_group_offset = INP_IMAGE_SIZE * INP_IMAGE_SIZE * (INP_IMAGE_CHANNEL / GROUP);
            const int batch = FILTER_BATCH / GROUP;
            inp_img[second_group_offset] = 2.0f;
            filter[batch * FILTER_CHANNEL * FILTER_SIZE * FILTER_SIZE] = 3.0f;

            conv2(inp_img, out_img, filter, bias);

            const float expected = 6.0f;
            if (std::fabs(out_img[batch * OUT_IMAGE_SIZE * OUT_IMAGE_SIZE] - expected) > 1e-5f) {
                std::cerr << "conv2 first second-group output mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "norm2": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "norm2.cpp"

        int main() {
            static float inp_img[INP_IMAGE_SIZE * INP_IMAGE_SIZE * INP_IMAGE_CHANNEL] = {};
            static float out_img[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * OUT_IMAGE_CHANNEL] = {};

            const int x = 0;
            const int y = 0;
            for (int c = 0; c < 5; ++c) {
                inp_img[c * INP_IMAGE_SIZE * INP_IMAGE_SIZE + x * INP_IMAGE_SIZE + y] = float(c + 1);
            }

            norm2(inp_img, out_img);

            const float sum = 1.0f + 4.0f + 9.0f + 16.0f + 25.0f;
            const float expected = 3.0f / std::pow(1.0f + 0.00002f * sum, 0.75f);
            const int index = 2 * INP_IMAGE_SIZE * INP_IMAGE_SIZE + x * INP_IMAGE_SIZE + y;
            if (std::fabs(out_img[index] - expected) > 1e-5f) {
                std::cerr << "norm2 channel-window normalization mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "conv4": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "conv4.cpp"

        int main() {
            static float inp_img[INP_IMAGE_SIZE * INP_IMAGE_SIZE * INP_IMAGE_CHANNEL] = {};
            static float out_img[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH] = {};
            static float filter[FILTER_BATCH * INP_IMAGE_CHANNEL * FILTER_SIZE * FILTER_SIZE] = {};
            static float bias[FILTER_BATCH] = {};

            inp_img[0] = 4.0f;
            filter[0] = 2.0f;
            conv4(inp_img, out_img, filter, bias);

            if (std::fabs(out_img[0] - 8.0f) > 1e-5f) {
                std::cerr << "conv4 first output mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "conv5": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "conv5.cpp"

        int main() {
            static float inp_img[INP_IMAGE_SIZE * INP_IMAGE_SIZE * INP_IMAGE_CHANNEL] = {};
            static float out_img[OUT_IMAGE_SIZE * OUT_IMAGE_SIZE * FILTER_BATCH] = {};
            static float filter[FILTER_BATCH * INP_IMAGE_CHANNEL * FILTER_SIZE * FILTER_SIZE] = {};
            static float bias[FILTER_BATCH] = {};

            inp_img[0] = 1.5f;
            filter[0] = 2.0f;
            bias[0] = 0.5f;
            conv5(inp_img, out_img, filter, bias);

            if (std::fabs(out_img[0] - 3.5f) > 1e-5f) {
                std::cerr << "conv5 bias/writeback mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "spmv": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "spmv.cpp"

        int main() {
            int rowPtr[NUM_ROWS + 1] = {};
            int columnIndex[NNZ] = {};
            DTYPE values[NNZ] = {};
            DTYPE y[SIZE] = {};
            DTYPE x[SIZE] = {};

            rowPtr[0] = 0;
            rowPtr[1] = 2;
            rowPtr[2] = 3;
            for (int i = 2; i <= NUM_ROWS; ++i) rowPtr[i] = 3;

            columnIndex[0] = 0;
            values[0] = 2.0f;
            columnIndex[1] = 3;
            values[1] = 4.0f;
            columnIndex[2] = 1;
            values[2] = -1.0f;

            x[0] = 3.0f;
            x[1] = 7.0f;
            x[3] = 5.0f;

            spmv(rowPtr, columnIndex, values, y, x);

            if (std::fabs(y[0] - 26.0f) > 1e-5f || std::fabs(y[1] + 7.0f) > 1e-5f) {
                std::cerr << "spmv row accumulation mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "spmv_fast_stream": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "spmv_fast_stream.cpp"

        int main() {
            int rowPtr[NUM_ROWS + 1] = {};
            int cols[NNZ] = {};
            DTYPE values[NNZ] = {};
            DTYPE y[SIZE] = {};
            DTYPE x[SIZE] = {};

            rowPtr[0] = 0;
            rowPtr[1] = 0;
            rowPtr[2] = 1;
            for (int i = 2; i <= NUM_ROWS; ++i) rowPtr[i] = 1;

            cols[0] = 5;
            values[0] = 3.0f;
            x[5] = 2.0f;

            spmv(rowPtr, cols, values, y, x);

            if (std::fabs(y[0] - 0.0f) > 1e-5f || std::fabs(y[1] - 6.0f) > 1e-5f) {
                std::cerr << "spmv_fast_stream padding/zero-row mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "spmv_naive_stream": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "spmv_naive_stream.cpp"

        int main() {
            int rowPtr[NUM_ROWS + 1] = {};
            int cols[NNZ] = {};
            DTYPE values[NNZ] = {};
            DTYPE y[SIZE] = {};
            DTYPE x[SIZE] = {};

            rowPtr[0] = 0;
            rowPtr[1] = 2;
            rowPtr[2] = 3;
            for (int i = 2; i <= NUM_ROWS; ++i) rowPtr[i] = 3;

            cols[0] = 0;
            values[0] = 1.0f;
            cols[1] = 2;
            values[1] = 2.0f;
            cols[2] = 1;
            values[2] = 5.0f;

            x[0] = 10.0f;
            x[1] = -1.0f;
            x[2] = 3.0f;

            spmv(rowPtr, cols, values, y, x);

            if (std::fabs(y[0] - 16.0f) > 1e-5f || std::fabs(y[1] + 5.0f) > 1e-5f) {
                std::cerr << "spmv_naive_stream row rollover mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "spmv_partial_unrolling": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "spmv_partial_unrolling.cpp"

        int main() {
            int rowPtr[NUM_ROWS + 1] = {};
            int columnIndex[NNZ] = {};
            DTYPE values[NNZ] = {};
            DTYPE y[SIZE] = {};
            DTYPE x[SIZE] = {};

            rowPtr[0] = 0;
            rowPtr[1] = 3;
            for (int i = 1; i <= NUM_ROWS; ++i) rowPtr[i] = 3;

            columnIndex[0] = 0;
            values[0] = 2.0f;
            columnIndex[1] = 1;
            values[1] = 4.0f;
            columnIndex[2] = 2;
            values[2] = -1.0f;

            x[0] = 3.0f;
            x[1] = 5.0f;
            x[2] = 7.0f;

            spmv(rowPtr, columnIndex, values, y, x);

            if (std::fabs(y[0] - 19.0f) > 1e-5f) {
                std::cerr << "spmv_partial_unrolling chunk accumulation mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "Entry": r'''
        #include <cstdlib>
        #include <cstring>
        #include <iostream>

        static int g_calls = 0;

        void MatrixMultiplication(const double A[], const double B[], double C[]) {
            ++g_calls;
            C[0] = A[0] + B[0];
        }

        #include "Entry.cpp"

        int main() {
            double A[N * K] = {};
            double B[K * M] = {};
            double C[N * M] = {};
            A[0] = 2.0;
            B[0] = 5.0;

            Example5_Reordered(A, B, C);

            if (g_calls != 1 || C[0] != 7.0) {
                std::cerr << "Entry wrapper did not invoke MatrixMultiplication\n";
                return 1;
            }
            return 0;
        }
    ''',
    "Example1": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "Example1.cpp"

        int main() {
            float in[N] = {};
            float out[N] = {};
            in[1] = 3.0f;
            in[2] = 6.0f;
            in[3] = 9.0f;

            Simple1DStencil(in, out);

            const float expected = 0.3333f * (3.0f + 6.0f + 9.0f);
            if (std::fabs(out[2] - expected) > 1e-4f) {
                std::cerr << "Example1 stencil mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "Example3_Time": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "Example3_Time.cpp"

        int main() {
            float in[N * M] = {};
            float out[N * M] = {};
            in[0 * M + 4] = 3.0f;
            in[1 * M + 4] = 6.0f;
            in[2 * M + 4] = 9.0f;

            Stencil2D(in, out);

            const float expected = 0.3333f * (3.0f + 6.0f + 9.0f);
            if (std::fabs(out[1 * M + 4] - expected) > 1e-4f) {
                std::cerr << "Example3_Time vertical stencil mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "Example5": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "Example5.cpp"

        int main() {
            double A[N * K] = {};
            double B[K * M] = {};
            double C[N * M] = {};
            A[0] = 2.0;
            B[0] = 3.0;

            MatrixMultiplication(A, B, C);

            if (std::fabs(C[0] - 6.0) > 1e-9) {
                std::cerr << "Example5 matrix multiply mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "dsp_pipeline": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "dsp_pipeline.cpp"

        int main() {
            hls::stream<data_t> in_stream;
            hls::stream<data_t> out_stream;
            in_stream.write(4.0f);
            in_stream.write(0.0f);
            in_stream.write(0.0f);
            for (int i = 3; i < 1024; ++i) {
                in_stream.write(0.0f);
            }

            dsp_pipeline(in_stream, out_stream, 2.0f);

            const float expected0 = 2.0f;
            const float expected1 = 4.0f;
            const float expected2 = 2.0f;
            const float out0 = out_stream.read();
            const float out1 = out_stream.read();
            const float out2 = out_stream.read();
            if (std::fabs(out0 - expected0) > 1e-5f || std::fabs(out1 - expected1) > 1e-5f || std::fabs(out2 - expected2) > 1e-5f) {
                std::cerr << "dsp_pipeline FIR/gain mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "HLS_MAC_accel": r'''
        #include <cstdlib>
        #include <iostream>
        #include "HLS_MAC_accel.cpp"

        int main() {
            hls::stream<axis_t> in_stream;
            hls::stream<axis_t> out_stream;
            axis_t a{};
            axis_t b{};
            a.data = 3;
            b.data = 4;
            in_stream.write(a);
            in_stream.write(b);

            mac_top(in_stream, out_stream, 5);

            axis_t out = out_stream.read();
            if (out.data != 35 || out.last != 1) {
                std::cerr << "HLS_MAC_accel output mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "lock_free_SPSCq": r'''
        #include <cstdlib>
        #include <iostream>
        #include "lock_free_SPSCq.cpp"

        int main() {
            hls::stream<data_t> in_stream;
            hls::stream<data_t> out_stream;
            static volatile data_t buffer[QDEPTH] = {};
            static queue_state state{0, 0};

            in_stream.write(42);
            spsc_top(in_stream, out_stream, buffer, state);

            if (out_stream.empty()) {
                std::cerr << "lock_free_SPSCq produced no output\n";
                return 1;
            }
            const auto out = out_stream.read();
            if (out != 42 || state.head != 1 || state.tail != 1) {
                std::cerr << "lock_free_SPSCq enqueue/dequeue mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "doHiststretch": r'''
        #include <cstdlib>
        #include <iostream>
        #include "doHiststretch.cpp"

        static unsigned char expected_value(unsigned char x, unsigned char xMin, unsigned char xMax) {
            float xMax_minus_xMin = xMax - xMin;
            float y_t_float = 0.0f;
            if (x > xMax) {
                y_t_float = (x - xMax) / 2.0f + 242.0f;
            } else if (x > xMin) {
                y_t_float = (x - xMin) / xMax_minus_xMin * 230.0f + 13.0f;
            } else {
                y_t_float = x / float(xMin) * 13.0f;
            }
            return static_cast<unsigned char>(y_t_float);
        }

        int main() {
            hls::stream<uint8_sidechannel> in_stream;
            hls::stream<uint8_sidechannel> out_stream;

            for (int i = 0; i < 320 * 240; ++i) {
                uint8_sidechannel sample{};
                sample.data = (i == 0) ? 5 : (i == 1) ? 60 : (i == 2) ? 150 : 0;
                sample.keep = 1;
                sample.strb = 1;
                sample.last = (i == 320 * 240 - 1);
                in_stream.write(sample);
            }

            doHiststretch(in_stream, out_stream, 10, 110);

            const unsigned char expected0 = expected_value(5, 10, 110);
            const unsigned char expected1 = expected_value(60, 10, 110);
            const unsigned char expected2 = expected_value(150, 10, 110);
            auto out0 = out_stream.read();
            auto out1 = out_stream.read();
            auto out2 = out_stream.read();

            if (out0.data != expected0 || out1.data != expected1 || out2.data != expected2) {
                std::cerr << "doHiststretch output mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "doHist": r'''
        #include <cstdlib>
        #include <iostream>
        #include "doHist.cpp"

        int main() {
            hls::stream<uint8_sidechannel> in_stream;
            int histo[256] = {};

            for (int i = 0; i < 320 * 240; ++i) {
                uint8_sidechannel sample{};
                sample.data = (i == 0) ? 7 : (i == 1) ? 7 : (i == 2) ? 3 : 0;
                in_stream.write(sample);
            }

            doHist(in_stream, histo);

            const int zeros = 320 * 240 - 3;
            if (histo[7] != 2 || histo[3] != 1 || histo[0] != zeros) {
                std::cerr << "doHist histogram mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "conv": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "conv.cc"

        int main() {
            float pad_img[PAD_IMG_ROWS][PAD_IMG_COLS] = {};
            hls::stream<float> conv_to_pool_stream;
            pad_img[0][0] = 1.0f;

            convolution(pad_img, 0, conv_to_pool_stream);

            const float expected = relu(conv_weights[0][0][0] + conv_biases[0]);
            const float observed = conv_to_pool_stream.read();
            if (std::fabs(observed - expected) > 1e-5f) {
                std::cerr << "conv first activation mismatch\n";
                return 1;
            }
            return 0;
        }
    ''',
    "dense": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "dense.cc"

        int main() {
            hls::stream<float> flat_to_dense_stream;
            hls::stream<float> dense_to_softmax_stream;

            flat_to_dense_stream.write(1.0f);
            for (int i = 1; i < FLAT_SIZE / FILTERS; ++i) {
                flat_to_dense_stream.write(0.0f);
            }

            dense(flat_to_dense_stream, 0, dense_to_softmax_stream);

            for (int d = 0; d < DENSE_SIZE; ++d) {
                const float observed = dense_to_softmax_stream.read();
                const float expected = dense_weights[0][d];
                if (std::fabs(observed - expected) > 1e-5f) {
                    std::cerr << "dense output mismatch at " << d << "\n";
                    return 1;
                }
            }
            return 0;
        }
    ''',
    "flat": r'''
        #include <cmath>
        #include <cstdlib>
        #include <iostream>
        #include "flat.cc"

        int main() {
            hls::stream<float> in_stream;
            hls::stream<float> out_stream;
            for (int i = 0; i < POOL_IMG_ROWS * POOL_IMG_COLS; ++i) {
                in_stream.write(static_cast<float>(i));
            }

            flattening(in_stream, out_stream);

            for (int i = 0; i < POOL_IMG_ROWS * POOL_IMG_COLS; ++i) {
                const float observed = out_stream.read();
                if (std::fabs(observed - static_cast<float>(i)) > 1e-5f) {
                    std::cerr << "flat stream order mismatch\n";
                    return 1;
                }
            }
            return 0;
        }
    ''',
    "bubble_sort": r'''
        #include <cstdlib>
        #include <iostream>

        #define CCS_MAIN(...) static int bubble_sort_embedded_main(__VA_ARGS__)
        #include "bubble_sort.cpp"
        #undef CCS_MAIN

        int main() {
            T values[5];
            values[0] = 5.0f;
            values[1] = 4.0f;
            values[2] = 3.0f;
            values[3] = 2.0f;
            values[4] = 1.0f;

            bubbleSort<5>(values);

            for (int i = 0; i < 5; ++i) {
                const float observed = values[i].to_float();
                const float expected = float(i + 1);
                if (observed != expected) {
                    std::cerr << "bubble_sort order mismatch\n";
                    return 1;
                }
            }
            return 0;
        }
    ''',
}


blockers = {
    "K_add": "Requires faithful ap_int/ap_fixed modular arithmetic semantics from the encrypted-computing kernel stack; a lightweight stub would not validate the signed modular wrap behavior.",
    "K_mulWise": "Depends on encrypted-computing RNS kernels and ap_int-based modular multiplication semantics across multiple companion headers; not realistic to isolate faithfully with local stubs.",
    "mod": "The target logic is bit-window modular reduction over ap_int/ap_uint values; validating it in isolation needs real arbitrary-width integer semantics, not the lightweight local support used for stream-only designs.",
    "forward-unrolling": "The BitNet forward path relies on multiple mutated config/typedef headers and large templated model structures, so isolating a trustworthy DUT harness here would require reconstructing substantial project context.",
    "K_ntt": "NTT correctness depends on wide ap_int bit-level behavior, twiddle tables, and RNS support code across the encrypted-computing kernel stack.",
    "forward-min-area": "The forward kernel depends on multiple damaged model/config headers and large transformer state definitions, so an isolated local bench would be more reconstruction than validation.",
    "forward": "The forward kernel depends on multiple damaged model/config headers and large transformer state definitions, so an isolated local bench would be more reconstruction than validation.",
    "execute": "This `hl5` unit is a SystemC/Stratus-style module and needs the broader processor simulation harness plus real SystemC types to exercise the DUT meaningfully.",
    "fedec": "This `hl5` unit is a SystemC/Stratus-style module and needs the broader processor simulation harness plus real SystemC types to exercise the DUT meaningfully.",
    "memwb": "This `hl5` unit is a SystemC/Stratus-style module and needs the broader processor simulation harness plus real SystemC types to exercise the DUT meaningfully.",
    "regionizer_ref": "The regionizer reference depends on GlobalCorrelator firmware types, utility headers, and HLS-specific stream/object definitions across multiple directories.",
    "llama2": "Tokenizer/model setup depends on multiple damaged headers plus checkpoint-driven transformer structs; a realistic isolated DUT harness would need substantial project reconstruction.",
    "regionizer": "The firmware regionizer depends on GlobalCorrelator type definitions and multi-header HLS object plumbing that are not practical to reconstruct locally here.",
    "present_1": "Masked PRESENT uses bit-sliced arbitrary-width crypto datatypes and helper headers where lightweight integer aliases would not exercise the real logic correctly.",
    "core_1": "This OpenCV/Vivado-HLS image kernel depends on project-specific image/stream/OpenCV types that are not available under the allowed local scope.",
    "tsqr_df": "TSQR depends on ap_fixed/ap_uint numerics and HLS math behavior across a larger numeric kernel stack; lightweight aliases would not validate the design reliably.",
    "simple_vtx_ref": "Vertexing depends on GlobalCorrelator firmware datatypes and helper headers across multiple modules, not just the copied source file.",
    "core_2": "This anisotropic-diffusion kernel depends on project-specific image container types and Vivado-HLS/OpenCV support code outside the candidate folder.",
    "simple_fullpfalgo": "The PF algorithm depends on GlobalCorrelator firmware types and matching helper headers across the full project, so a small isolated bench would be misleading.",
    "rf_doppler_spoof_engine": "The Doppler engine mixes ap_uint bit operations, ap_fixed numerics, and AXI types; the lightweight local support is not faithful enough for a credible behavioral test.",
    "aes": "AES uses arbitrary-width crypto datatypes and bit-slice operators that require real vendor integer semantics for a meaningful test.",
    "present_2": "PRESENT uses arbitrary-width crypto datatypes and bit-slice operators that require real vendor integer semantics for a meaningful test.",
    "serpent": "Serpent uses arbitrary-width crypto datatypes and bit-slice operators that require real vendor integer semantics for a meaningful test.",
    "cnn": "The top-level CNN integrates multiple sibling kernels and several mutated headers, so standing up a credible isolated DUT harness would require reconstructing most of the project build context.",
    "main_1": "The source depends on missing project headers (`common.h`, `launch_model.h`) and a larger application model that is not present in the candidate folder.",
    "hl5_datatypes": "This candidate is a SystemC-heavy datatype header rather than a standalone callable DUT; validating it needs the surrounding `hl5` simulation environment.",
    "ppu": "The PPU source is tightly coupled to the full NES emulator global state and companion C modules; reconstructing that harness locally is not realistic within the allowed scope.",
    "registers": "The register block depends on the full NES emulator global state and companion CPU/PPU/MBC modules, not just the copied translation unit.",
    "main_2": "This NES testbench-style `main.c` depends on the larger emulator program and shared header/global setup, so a small standalone DUT harness would be artificial.",
}


def blocker_body(folder: str, reason: str, row: dict) -> str:
    return textwrap.dedent(
        f"""
        # Blocker

        - Folder: `{folder}`
        - Local source: `{row['local_file']}`
        - Local original: `{row['local_original_file']}`
        - Inferred DUT entry: `{infer_entry(row['local_folder'])}`
        - Reason: {reason}

        A fake snippet-only check was not added here because it would not exercise the real DUT in a credible local configuration.
        """
    ).strip()


def infer_entry(folder: str) -> str:
    entries = {
        "K_add": "K_add(ap_int<PRIME_BIT> *poly1, ap_int<PRIME_BIT> *poly2, ap_int<PRIME_BIT> *out, int inv)",
        "K_mulWise": "K_mulWise(ap_int<PRIME_BIT> *poly1, ap_int<PRIME_BIT> *poly2, ap_int<PRIME_BIT> *out, int inv)",
        "mod": "reduction(...) / modular_multiplication(...) helpers in mod.cpp",
        "forward-unrolling": "forward(...) plus helper templates in forward-unrolling.cpp",
        "K_ntt": "K_ntt(ap_int<PRIME_BIT> *in, ap_int<PRIME_BIT> *out, int mode, int which_poly)",
        "forward-min-area": "forward(...) plus helper templates in forward-min-area.cpp",
        "forward": "forward(...) plus helper templates in forward.cpp",
        "execute": "execute::behavior() via execute.cpp",
        "fedec": "fedec::behavior() via fedec.cpp",
        "memwb": "memwb::behavior() via memwb.cpp",
        "regionizer_ref": "regionize_ref(...) / regionize_*_ref(...)",
        "llama2": "Tokenizer/model helpers in llama2.cpp",
        "regionizer": "regionize_* and merge helpers in regionizer.cpp",
        "present_1": "present_encrypt(...) and round helpers",
        "core_1": "doConv(...)",
        "tsqr_df": "top(...)",
        "simple_vtx_ref": "simple_vtx_ref(...)",
        "core_2": "anisotropic_diffusion(...)",
        "simple_fullpfalgo": "simple_fullpfalgo(...) family",
        "rf_doppler_spoof_engine": "rf_doppler_spoof_engine(...)",
        "aes": "aes_encrypt(...) and helpers",
        "present_2": "present_encrypt(...) and helpers",
        "serpent": "serpent_encrypt(...) and helpers",
        "cnn": "cnn(...)",
        "main_1": "main(int argc, char* argv[])",
        "hl5_datatypes": "operator== / datatype methods in hl5_datatypes.hpp",
        "ppu": "r_name_table(...) and other PPU helpers",
        "registers": "regs_read(...) / regs_write(...)",
        "main_2": "main() plus BMP helpers",
    }
    return entries.get(folder, "unknown")


for path, content in support_files.items():
    write(path, textwrap.dedent(content))

for dest, src in copied_headers.items():
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)

for path, content in local_headers.items():
    write(path, textwrap.dedent(content))


manifest_rows = []
for raw in MANIFEST.read_text().splitlines():
    row = json.loads(raw)
    folder = row["local_folder"]
    if folder in runtime_testbenches:
        tb_name = f"{folder.replace('-', '_')}_target_tb.cpp"
        tb_path = FV / folder / tb_name
        write(tb_path, textwrap.dedent(runtime_testbenches[folder]))
        row["local_testbench"] = f"{folder}/{tb_name}"
        row["testbench_kind"] = "dut_target_tb"
    else:
        blocker_path = FV / folder / "BLOCKER.md"
        write(blocker_path, blocker_body(folder, blockers[folder], row))
        row["local_testbench"] = f"{folder}/BLOCKER.md"
        row["testbench_kind"] = "blocked"
    manifest_rows.append(row)

MANIFEST.write_text("\n".join(json.dumps(row) for row in manifest_rows) + "\n")
