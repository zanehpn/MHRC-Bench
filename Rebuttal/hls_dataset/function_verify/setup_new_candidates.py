#!/usr/bin/env python3
"""
Set up 13 new function-verify candidates from the hls repos directly.
Uses the actual repo files (which have <TARGET>) as DUT source.
"""

import json
import os
import shutil
import subprocess
import tempfile

ROOT = "/ssd1/zqy/Multi-hdl-language-repo"
FV = os.path.join(ROOT, "hls_dataset", "function_verify")
HLS = os.path.join(ROOT, "hls")
TRAIN = os.path.join(ROOT, "hls_dataset", "train_content.jsonl")

CXX = "g++"
CXXFLAGS = ["-std=c++17", "-w"]
SUPPORT = f"-I{os.path.join(FV, '_support')}"


# ── Candidate definitions ────────────────────────────────────────────
# (train_idx, folder_name, repo_subpath_to_cpp, header_inline, has_main_in_src)

CANDIDATES = [
    # hls-eval chstone: one-liner bit ops
    (2120, "extractFloat64Exp",
     "hls-eval/hls_eval_data/chstone/df_extractFloat64Exp/extractFloat64Exp.cpp",
     "typedef int int16;\ntypedef unsigned long long float64;\n",
     False),
    (2126, "float64_abs",
     "hls-eval/hls_eval_data/chstone/df_float64_abs/float64_abs.cpp",
     "typedef unsigned long long float64;\n",
     False),
    (2136, "float64_neg",
     "hls-eval/hls_eval_data/chstone/df_float64_neg/float64_neg.cpp",
     "typedef unsigned long long float64;\n",
     False),
    (2140, "packFloat64",
     "hls-eval/hls_eval_data/chstone/df_packFloat64/packFloat64.cpp",
     "typedef int flag;\ntypedef int int16;\ntypedef unsigned long long int bits64;\ntypedef unsigned long long float64;\n",
     False),
    (2146, "sub128",
     "hls-eval/hls_eval_data/chstone/df_sub128/sub128.cpp",
     "typedef unsigned long long int bits64;\n",
     False),
    # hls-eval c2hlsc
    (2089, "monobit",
     "hls-eval/hls_eval_data/c2hlsc/monobit/monobit.cpp",
     "#define N 128\n",
     False),
    (2087, "mix_columns",
     "hls-eval/hls_eval_data/c2hlsc/mix_columns/mix_cols.cpp",
     "#include <cstdint>\ntypedef uint8_t state_t[4][4];\n",
     False),
    # hls-eval machsuite
    (2181, "gemm_ncubed",
     "hls-eval/hls_eval_data/machsuite/gemm_ncubed/gemm_ncubed.cpp",
     "#define row_size 64\n#define col_size 64\n#define N 64\ntypedef double TYPE;\n",
     False),
    (2506, "op_or",
     "Shang/testsuite/SimpleTest/op_or.cpp",
     "", True),
    (2239, "jacobi_2d",
     "hls-eval/hls_eval_data/polybench/jacobi-2d/jacobi-2d.cpp",
     "",
     False),
    # hls-eval polybench
    (2241, "lu",
     "hls-eval/hls_eval_data/polybench/lu/lu.cpp",
     "",
     False),
    # Shang self-contained
    (2475, "cfg_loop_sum",
     "Shang/testsuite/Loops/cfg_loop_sum.cpp",
     "", True),
    (2489, "op_add",
     "Shang/testsuite/SimpleTest/op_add.cpp",
     "", True),
]

TESTBENCHES = {
    "extractFloat64Exp": """\
#include <iostream>
typedef int int16;
typedef unsigned long long float64;
{inc}
int main() {{
    if (extractFloat64Exp(0x3FF0000000000000ULL) != 1023) {{ std::cerr<<"FAIL 1\\n"; return 1; }}
    if (extractFloat64Exp(0x4000000000000000ULL) != 1024) {{ std::cerr<<"FAIL 2\\n"; return 1; }}
    if (extractFloat64Exp(0x3FE0000000000000ULL) != 1022) {{ std::cerr<<"FAIL 3\\n"; return 1; }}
    if (extractFloat64Exp(0x7FF0000000000000ULL) != 2047) {{ std::cerr<<"FAIL 4\\n"; return 1; }}
    if (extractFloat64Exp(0x0ULL) != 0) {{ std::cerr<<"FAIL 5\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "float64_abs": """\
#include <iostream>
typedef unsigned long long float64;
{inc}
int main() {{
    if (float64_abs(0xBFF0000000000000ULL) != 0x3FF0000000000000ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if (float64_abs(0x3FF0000000000000ULL) != 0x3FF0000000000000ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if (float64_abs(0x8000000000000000ULL) != 0x0ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "float64_neg": """\
#include <iostream>
typedef unsigned long long float64;
{inc}
int main() {{
    if (float64_neg(0x3FF0000000000000ULL) != 0xBFF0000000000000ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if (float64_neg(0xBFF0000000000000ULL) != 0x3FF0000000000000ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if (float64_neg(0x0ULL) != 0x8000000000000000ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "packFloat64": """\
#include <iostream>
typedef int flag; typedef int int16;
typedef unsigned long long int bits64; typedef unsigned long long float64;
{inc}
int main() {{
    if (packFloat64(0,1023,0) != 0x3FF0000000000000ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if (packFloat64(1,1023,0) != 0xBFF0000000000000ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if (packFloat64(0,1024,0x8000000000000ULL) != 0x4008000000000000ULL) {{ std::cerr<<"FAIL\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "sub128": """\
#include <iostream>
typedef unsigned long long int bits64;
{inc}
int main() {{
    bits64 z0, z1;
    sub128(0,5,0,3,&z0,&z1);
    if (z0!=0||z1!=2) {{ std::cerr<<"FAIL basic\\n"; return 1; }}
    sub128(1,0,0,1,&z0,&z1);
    if (z0!=0||z1!=0xFFFFFFFFFFFFFFFFULL) {{ std::cerr<<"FAIL borrow\\n"; return 1; }}
    sub128(2,0,1,1,&z0,&z1);
    if (z0!=0||z1!=0xFFFFFFFFFFFFFFFFULL) {{ std::cerr<<"FAIL hi\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "monobit": """\
#include <iostream>
#define N 128
{inc}
int main() {{
    int r; int e[N];
    for(int i=0;i<N;i++) e[i]=1; Frequency(&r,e);
    if(r!=128) {{ std::cerr<<"FAIL all1 "<<r<<"\\n"; return 1; }}
    for(int i=0;i<N;i++) e[i]=0; Frequency(&r,e);
    if(r!=-128) {{ std::cerr<<"FAIL all0 "<<r<<"\\n"; return 1; }}
    for(int i=0;i<N;i++) e[i]=(i<64)?1:0; Frequency(&r,e);
    if(r!=0) {{ std::cerr<<"FAIL half "<<r<<"\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "mix_columns": """\
#include <iostream>
#include <cstdint>
typedef uint8_t state_t[4][4];
{inc}
int main() {{
    if(xtime(0x57)!=0xAE) {{ std::cerr<<"FAIL 57\\n"; return 1; }}
    if(xtime(0xAE)!=0x47) {{ std::cerr<<"FAIL AE\\n"; return 1; }}
    if(xtime(0x01)!=0x02) {{ std::cerr<<"FAIL 01\\n"; return 1; }}
    if(xtime(0x80)!=0x1B) {{ std::cerr<<"FAIL 80\\n"; return 1; }}
    if(xtime(0x00)!=0x00) {{ std::cerr<<"FAIL 00\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "gemm_ncubed": """\
#include <iostream>
#include <cstring>
#include <cmath>
#define row_size 64
#define col_size 64
#define N 64
typedef double TYPE;
{inc}
int main() {{
    static TYPE m1[N*N],m2[N*N],prod[N*N];
    memset(m1,0,sizeof(m1));
    for(int i=0;i<N;i++) m1[i*N+i]=1.0;
    for(int i=0;i<N*N;i++) m2[i]=(double)(i%7);
    memset(prod,0,sizeof(prod));
    gemm(m1,m2,prod);
    for(int i=0;i<N*N;i++) if(std::fabs(prod[i]-m2[i])>1e-10) {{ std::cerr<<"FAIL "<<i<<"\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "op_or": """\
#include <iostream>
#define main dut_main
#define printf(...) 0
{inc}
#undef main
#undef printf
int main() {{
    if(op_or(0xFF,0x00)!=0xFF) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if(op_or(0xAA,0x55)!=0xFF) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if(op_or(0,0)!=0) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if(op_or(-1,0)!=-1) {{ std::cerr<<"FAIL\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "jacobi_2d": """\
#include <iostream>
#include <cmath>
{inc}
int main() {{
    static double A[30][30],B[30][30];
    for(int i=0;i<30;i++) for(int j=0;j<30;j++) {{ A[i][j]=(double)(i*30+j); B[i][j]=0; }}
    kernel_jacobi_2d(A,B);
    // After 20 timesteps, interior should have changed from initial
    if(std::fabs(A[15][15]-(double)(15*30+15))<1e-10) {{ std::cerr<<"FAIL unchanged\\n"; return 1; }}
    // B should also be modified
    if(std::fabs(B[15][15])<1e-10) {{ std::cerr<<"FAIL B zero\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "lu": """\
#include <iostream>
#include <cmath>
{inc}
int main() {{
    static double A[40][40]={{}};
    A[0][0]=4; A[0][1]=3; A[1][0]=6; A[1][1]=3;
    kernel_lu(A);
    if(std::fabs(A[0][0]-4.0)>1e-10||std::fabs(A[0][1]-3.0)>1e-10) {{ std::cerr<<"FAIL r0\\n"; return 1; }}
    if(std::fabs(A[1][0]-1.5)>1e-10||std::fabs(A[1][1]+1.5)>1e-10) {{ std::cerr<<"FAIL r1\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "cfg_loop_sum": """\
#include <iostream>
#define main dut_main
#define printf(...) 0
{inc}
#undef main
#undef printf
int main() {{
    unsigned a1[]={{1,2,3,4,5}};
    if(cfg_loop_sum(a1,5)!=15) {{ std::cerr<<"FAIL 15\\n"; return 1; }}
    unsigned a2[]={{10}};
    if(cfg_loop_sum(a2,1)!=10) {{ std::cerr<<"FAIL 10\\n"; return 1; }}
    if(cfg_loop_sum(a1,0)!=0) {{ std::cerr<<"FAIL 0\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
    "op_add": """\
#include <iostream>
#define main dut_main
#define printf(...) 0
{inc}
#undef main
#undef printf
int main() {{
    if(op_add(3,4)!=7) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if(op_add(-10,10)!=0) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if(op_add(0,0)!=0) {{ std::cerr<<"FAIL\\n"; return 1; }}
    if(op_add(-1,-1)!=-2) {{ std::cerr<<"FAIL\\n"; return 1; }}
    std::cout << "PASSED\\n"; return 0;
}}
""",
}


def load_train():
    with open(TRAIN) as f:
        return [json.loads(l) for l in f]


def w(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def compile_and_run(tb_path, folder_path):
    with tempfile.NamedTemporaryFile(suffix="_tb", delete=False) as tmp:
        bp = tmp.name
    try:
        cmd = [CXX] + CXXFLAGS + [SUPPORT, f"-I{folder_path}", "-o", bp, tb_path]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            return False, "build", r.stderr[:500]
        r = subprocess.run([bp], capture_output=True, text=True, timeout=120)
        return r.returncode == 0, "run", r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return False, "timeout", ""
    finally:
        if os.path.exists(bp):
            os.unlink(bp)


def setup_one(train_idx, folder_name, repo_subpath, header_inline, has_main, train_data):
    folder_path = os.path.join(FV, folder_name)
    if os.path.exists(folder_path):
        shutil.rmtree(folder_path)
    os.makedirs(folder_path)

    entry = train_data[train_idx]
    gt = entry["groundtruth"]
    ext = os.path.splitext(repo_subpath)[1]

    # Read the ACTUAL repo file (which has <TARGET>)
    repo_file = os.path.join(HLS, repo_subpath)
    with open(repo_file) as f:
        repo_content = f.read()

    assert "<TARGET>" in repo_content, f"No <TARGET> in {repo_file}"

    # Replace #include "xxx.h" with inline header (since headers also have <TARGET>)
    import re
    repo_content_fixed = re.sub(
        r'#include\s+"[^"]+\.h"',
        header_inline,
        repo_content,
    )

    dut_file = f"{folder_name}{ext}"
    original_file = f"{folder_name}_original{ext}"
    tb_file = f"{folder_name}_original_tb.cpp"

    # DUT = repo content with <TARGET> (header replaced)
    w(os.path.join(folder_path, dut_file), repo_content_fixed)
    # Original = DUT with <TARGET> replaced by ground truth
    w(os.path.join(folder_path, original_file),
      repo_content_fixed.replace("<TARGET>", gt))

    # TB
    inc = f'#include "{original_file}"'
    tb = TESTBENCHES[folder_name].format(inc=inc)
    w(os.path.join(folder_path, tb_file), tb)

    # Test golden
    ok, stage, msg = compile_and_run(os.path.join(folder_path, tb_file), folder_path)
    if not ok:
        return False, f"golden FAIL [{stage}]: {msg[:300]}"

    # Mutation test
    mutant = repo_content_fixed.replace("<TARGET>", "/* REMOVED */")
    w(os.path.join(folder_path, dut_file), mutant)
    inc_mut = f'#include "{dut_file}"'
    tb_mut = TESTBENCHES[folder_name].format(inc=inc_mut)
    mt_path = os.path.join(folder_path, "_mut.cpp")
    w(mt_path, tb_mut)

    ok_m, stg_m, msg_m = compile_and_run(mt_path, folder_path)

    # Restore
    w(os.path.join(folder_path, dut_file), repo_content_fixed)
    os.unlink(mt_path)

    if ok_m:
        return False, f"BLIND: mutation not detected"

    return True, f"OK (mutation detected [{stg_m}])"


def main():
    train_data = load_train()
    print("Setting up 13 new candidates...")
    print("=" * 70)

    ok_list, fail_list = [], []
    for train_idx, name, repo_path, hdr, has_main in CANDIDATES:
        print(f"  {name:25s}", end=" ")
        ok, msg = setup_one(train_idx, name, repo_path, hdr, has_main, train_data)
        print("PASS" if ok else "FAIL", msg)
        (ok_list if ok else fail_list).append((train_idx, name, msg))

    print(f"\n{'=' * 70}")
    print(f"Success: {len(ok_list)}, Failed: {len(fail_list)}")
    if fail_list:
        for _, n, m in fail_list:
            print(f"  {n}: {m}")


if __name__ == "__main__":
    main()
