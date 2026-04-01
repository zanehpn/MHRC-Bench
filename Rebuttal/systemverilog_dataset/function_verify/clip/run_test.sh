#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log
vcs -full64 -sverilog +incdir+.+testbench testbench/clip_target_tb.sv -o simv 2>&1 | tail -5
./simv 2>&1
