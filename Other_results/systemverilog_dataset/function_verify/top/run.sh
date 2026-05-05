#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

rm -f _patched_*

tb="testbench/top_target_tb.sv"
original_basename="top_original.sv"

# Patch the original:
# 1. always_ff -> always
# 2. always_comb -> always @(*)
# 3. Remove inline initializations for variables that have structural drivers
#    (tready, rvalid, rready, rdata, tvalid, tdata - connected to uart output ports)
patched_original="_patched_${original_basename}"
sed -e 's/\balways_ff\b/always/g' \
    -e 's/\balways_comb\b/always @( * )/g' \
    -e 's/bit tvalid = 0;/bit tvalid;/' \
    -e 's/bit tready = 0;/bit tready;/' \
    -e 's/bit rvalid = 0;/bit rvalid;/' \
    -e 's/bit rready = 0;/bit rready;/' \
    -e 's/bit \[7:0\] tdata = 0;/bit [7:0] tdata;/' \
    -e 's/bit \[7:0\] rdata = 0;/bit [7:0] rdata;/' \
    "$original_basename" > "$patched_original"

patched_tb="_patched_$(basename "$tb")"
sed "s|\"../${original_basename}\"|\"../${patched_original}\"|g" "$tb" > "$patched_tb"

rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log

{
  vcs -full64 -sverilog +timescale+1ns/1ps +incdir+.+testbench "$patched_tb" -o simv
  ./simv
} 2>&1 | tee run.log

rm -f _patched_*
