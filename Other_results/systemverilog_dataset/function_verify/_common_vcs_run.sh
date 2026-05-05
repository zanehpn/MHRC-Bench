#!/usr/bin/env bash
set -euo pipefail

# Clean up any leftover patched files from previous runs
rm -f _patched_*

tb="$(find testbench -maxdepth 1 -type f \( -name '*_target_tb.sv' -o -name '*_target_tb.v' \) | head -n 1)"

if [[ -z "$tb" ]]; then
  echo "Missing testbench in $PWD" >&2
  exit 1
fi

design_basename="$(sed -n 's/.*"local_file": "[^"]*\/\([^"]*\)".*/\1/p' testbench_manifest.json | head -n 1)"
original_basename="$(sed -n 's/.*"local_original_file": "\([^"]*\)".*/\1/p' testbench_manifest.json | head -n 1)"

sources=()
while IFS= read -r file; do
  if grep -q '<TARGET>' "$file"; then
    continue
  fi
  sources+=("$file")
done < <(
  find . -maxdepth 1 -type f \( -name '*.sv' -o -name '*.v' \) \
    ! -name "$design_basename" \
    ! -name "$original_basename" \
    ! -name '_patched_*' \
    | sort
)

# Work around VCS L-2016.06 issues:
# 1. ICPD: variable initialization + always_ff → replace always_ff with always
# 2. Unpacked array default values in ports → remove them
patched_original="_patched_${original_basename}"
sed -e 's/\balways_ff\b/always/g' \
    -e "s/= *'{\([^}]*\)}//g" \
    "$original_basename" > "$patched_original"

patched_tb="_patched_$(basename "$tb")"
# Replace include of original with patched, and remove includes of extra sources
# (since they're compiled as separate patched files by this script)
sed_expr="s|\"../${original_basename}\"|\"../${patched_original}\"|g"
for src in "${sources[@]}"; do
  srcbase=$(basename "$src")
  sed_expr="${sed_expr}; /\`include.*${srcbase}/d"
done
sed "$sed_expr" "$tb" > "$patched_tb"

# Also patch any extra source files
patched_sources=()
for src in "${sources[@]}"; do
  base=$(basename "$src")
  patched="_patched_${base}"
  sed -e 's/\balways_ff\b/always/g' -e 's/\balways_comb\b/always @( * )/g' -e "s/^\([^?]*\)= *'{[^}]*}/\1/g" "$src" > "$patched"
  patched_sources+=("$patched")
done

rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log

{
  vcs -full64 -sverilog +timescale+1ns/1ps +incdir+.+testbench "${patched_sources[@]}" "$patched_tb" -o simv
  ./simv
} 2>&1 | tee run.log

rm -f _patched_*
