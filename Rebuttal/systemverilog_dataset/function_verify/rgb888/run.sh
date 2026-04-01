#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

rm -f _patched_*

tb="testbench/rgb888_target_tb.sv"
original_basename="rgb888_original.sv"

# Patch the original: fix the incomplete ternary on line 23 by adding a default `: 24'd0`
# Also replace always_ff with always
patched_original="_patched_${original_basename}"
sed -e 's/\balways_ff\b/always/g' \
    -e "s/state == 2'd2 ? {image_data\[0\], last_upper_image_data\[3\], last_upper_image_data\[2\]};/state == 2'd2 ? {image_data[0], last_upper_image_data[3], last_upper_image_data[2]} : 24'd0;/" \
    -e "s/= *'{\([^}]*\)}//g" \
    "$original_basename" > "$patched_original"

patched_tb="_patched_$(basename "$tb")"
sed "s|\"../${original_basename}\"|\"../${patched_original}\"|g" "$tb" > "$patched_tb"

rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log

{
  vcs -full64 -sverilog +timescale+1ns/1ps +incdir+.+testbench "$patched_tb" -o simv
  ./simv
} 2>&1 | tee run.log

rm -f _patched_*
