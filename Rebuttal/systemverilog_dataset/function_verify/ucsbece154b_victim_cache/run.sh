#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

rm -f _patched_*

tb="testbench/ucsbece154b_victim_cache_target_tb.sv"
original_basename="ucsbece154b_victim_cache_original.sv"

# Patch the original:
# 1. always_ff -> always
# 2. always_comb -> always @(*) (fixes ICPD: variable "i" driven by multiple always_comb blocks)
# 3. Remove inline initialization of integer i = 0 (ICPD conflict with always_comb driver)
patched_original="_patched_${original_basename}"
sed -e 's/\balways_ff\b/always/g' \
    -e 's/\balways_comb\b/always @( * )/g' \
    -e 's/^integer i = 0;/integer i;/' \
    "$original_basename" > "$patched_original"

patched_tb="_patched_$(basename "$tb")"
sed "s|\"../${original_basename}\"|\"../${patched_original}\"|g" "$tb" > "$patched_tb"

rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log

{
  vcs -full64 -sverilog +timescale+1ns/1ps +incdir+.+testbench "$patched_tb" -o simv
  ./simv
} 2>&1 | tee run.log

rm -f _patched_*
