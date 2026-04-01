#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

rm -f _patched_*

tb="testbench/virtio_available_ring_monitor_target_tb.sv"
original_basename="virtio_available_ring_monitor_original.sv"

# Patch the original: always_ff -> always
patched_original="_patched_${original_basename}"
sed -e 's/\balways_ff\b/always/g' \
    -e 's/\balways_comb\b/always @( * )/g' \
    "$original_basename" > "$patched_original"

# Patch the testbench to include the patched original
patched_tb="_patched_$(basename "$tb")"
sed "s|\"../${original_basename}\"|\"../${patched_original}\"|g" "$tb" > "$patched_tb"

# Patch the interface file to remove inline initializations that cause ICPSD with VCS
patched_if="_patched_logic_axi4_stream_if.sv"
sed -e 's/\balways_ff\b/always/g' \
    -e "s/= 'X;/;/g" \
    "logic_axi4_stream_if.sv" > "$patched_if"

# Also update the TB to include the patched interface
sed -i "s|\"../logic_axi4_stream_if.sv\"|\"../${patched_if}\"|g" "$patched_tb"

rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log

{
  vcs -full64 -sverilog +define+LOGIC_MODPORT_DISABLED +incdir+.+testbench "$patched_tb" -o simv
  ./simv
} 2>&1 | tee run.log

rm -f _patched_*
