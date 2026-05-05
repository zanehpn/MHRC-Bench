#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

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
    | sort
)

# Work around ICPD errors in VCS L-2016.06: variable initialization + always_ff
# is flagged as illegal. Create a patched copy that replaces always_ff with always.
patched_original="_patched_${original_basename}"
sed 's/\balways_ff\b/always/g' "$original_basename" > "$patched_original"

# Patch the testbench to include the patched copy instead of the original
patched_tb="_patched_$(basename "$tb")"
sed "s|\"../${original_basename}\"|\"../${patched_original}\"|g" "$tb" > "$patched_tb"

rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log

{
  vcs -full64 -sverilog +incdir+.+testbench "${sources[@]}" "$patched_tb" -o simv
  ./simv
} 2>&1 | tee run.log

rm -f "$patched_original" "$patched_tb"
