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

rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log

# Create a preprocessed copy of the original
# The original has a forward reference: function K (line 10) uses variable k (line 61)
# VCS L-2016.06 doesn't allow this. We move the k and initial_hashes declarations
# before the functions to fix the forward reference.
mkdir -p testbench/preproc
python3 -c "
import re
with open('sha_mainloop_original.sv') as f:
    content = f.read()

# Extract the two variable declaration lines (initial_hashes and k)
lines = content.split('\n')
decl_lines = []
remaining_lines = []
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('logic [255:0] initial_hashes') or stripped.startswith('logic [2047:0] k'):
        decl_lines.append(line)
    else:
        remaining_lines.append(line)

# Insert them right after the module port declaration (after 'output logic done);')
output_lines = []
for line in remaining_lines:
    output_lines.append(line)
    if line.strip() == 'output logic done);':
        for dl in decl_lines:
            output_lines.append(dl)

# Join and fix the %4294967296 issue (too large for VCS 32-bit signed literal)
# Since these are 32-bit values, modulo 2^32 is a no-op, just remove it
result = '\n'.join(output_lines)
result = result.replace('%4294967296', '% (33\\'d4294967296)')

with open('testbench/preproc/sha_mainloop_original.sv', 'w') as f:
    f.write(result)
"

# Create a modified testbench that includes from preproc
sed 's|"../sha_mainloop_original.sv"|"preproc/sha_mainloop_original.sv"|' "$tb" > testbench/preproc_tb.sv

{
  vcs -full64 -sverilog +incdir+.+testbench "${sources[@]}" testbench/preproc_tb.sv -o simv
  ./simv
} 2>&1 | tee run.log
