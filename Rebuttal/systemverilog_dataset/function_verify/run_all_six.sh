#!/usr/bin/env bash
set -uo pipefail

BASE="/ssd1/zqy/Multi-hdl-language-repo/systemverilog_dataset/function_verify"

for mod in axi_lite_master axi_lite_slave axi_master axi_stream_master axi_riscv_amos axi_riscv_lrsc; do
  echo "=== Running $mod ==="
  cd "$BASE/$mod"
  bash ..//_common_vcs_run.sh 2>&1 | tail -20
  echo ""
done
