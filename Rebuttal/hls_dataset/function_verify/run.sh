#!/usr/bin/env bash
#
# run.sh — Compile & run every *_original_tb.cpp under function_verify/
#
# Usage:
#   ./run.sh              # run all testbenches
#   ./run.sh spmv aes     # run only listed folders
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CXX="${CXX:-g++}"
CXXFLAGS="-std=c++17 -w"
SUPPORT="-I_support"
TIMEOUT=60
TMPBIN=$(mktemp -d)/tb

pass=0
fail=0
skip=0
total=0
failed_list=""

# Collect folders to test
if [ $# -gt 0 ]; then
    folders=("$@")
else
    folders=()
    for d in */; do
        d="${d%/}"
        [[ "$d" == "_support" || "$d" == "03-Headers" || "$d" == "hl5_datatypes" || "$d" == "testbench" ]] && continue
        folders+=("$d")
    done
fi

for d in "${folders[@]}"; do
    # Find the testbench source
    tb=$(find "$d" -maxdepth 1 -name "*_original_tb*" 2>/dev/null | head -1)
    if [ -z "$tb" ]; then
        continue
    fi

    total=$((total + 1))

    # Compile
    if ! $CXX $CXXFLAGS $SUPPORT -I"$d" -o "$TMPBIN" "$tb" 2>/dev/null; then
        echo "FAIL [build]  $d"
        fail=$((fail + 1))
        failed_list="$failed_list $d"
        continue
    fi

    # Run
    if timeout "$TIMEOUT" "$TMPBIN" >/dev/null 2>&1; then
        echo "PASS          $d"
        pass=$((pass + 1))
    else
        echo "FAIL [run]    $d"
        fail=$((fail + 1))
        failed_list="$failed_list $d"
    fi

    rm -f "$TMPBIN"
done

echo ""
echo "========================================"
echo "  Total: $total  |  PASS: $pass  |  FAIL: $fail"
echo "========================================"

if [ $fail -gt 0 ]; then
    echo "  Failed:$failed_list"
    exit 1
fi

exit 0
