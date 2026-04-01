#!/usr/bin/env python3
import subprocess, os, sys

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "systemverilog_dataset", "function_verify")
modules = ["axi_riscv_amos", "axi_riscv_lrsc"]

for mod in modules:
    d = os.path.join(BASE, mod)
    print("\n" + "="*60)
    print("Running " + mod)
    print("="*60)
    sys.stdout.flush()
    try:
        result = subprocess.run(
            ["bash", os.path.join(BASE, "_common_vcs_run.sh")],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120, cwd=d
        )
        output = result.stdout.decode('utf-8', errors='replace')
        lines = output.strip().split('\n')
        for line in lines[-10:]:
            print(line)
    except subprocess.TimeoutExpired:
        print("TIMEOUT for " + mod)
    except Exception as e:
        print("Error: " + str(e))
    sys.stdout.flush()
