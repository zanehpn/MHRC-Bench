#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

tb="testbench/ucsbece154b_icache_target_tb.sv"

rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h run.log

{
  vcs -full64 -sverilog +incdir+.+testbench "$tb" -o simv
  ./simv
} 2>&1 | tee run.log
