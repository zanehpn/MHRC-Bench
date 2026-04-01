#!/usr/bin/env python3
"""Run mutation test on all 50 candidates."""

import json, os, subprocess, glob

BASE = "/ssd1/zqy/Multi-hdl-language-repo/hls_dataset/function_verify"
SUPPORT = os.path.join(BASE, "_support")
JSONL = os.path.join(BASE, "design_function_verify_candidates_50.jsonl")

with open(JSONL) as f:
    entries = [json.loads(l) for l in f]

print(f"Testing {len(entries)} candidates...\n")

passed = 0
failed = 0
errors = []

for i, e in enumerate(entries):
    name = e["local_folder"]
    folder = os.path.join(BASE, name)

    # Find the original TB - could be {name}_original_tb.cpp or use local_testbench path
    # First try the original_tb pattern
    orig_tb_candidates = glob.glob(os.path.join(folder, "*_original_tb.cpp"))
    if not orig_tb_candidates:
        print(f"  [{i+1:2d}] {name:30s} SKIP (no original_tb)")
        errors.append((name, "NO_TB"))
        failed += 1
        continue
    orig_tb = orig_tb_candidates[0]

    # Find the DUT (with <TARGET>) - could be .cpp or .cc, could have different name
    dut_candidates = []
    for ext in ['.cpp', '.cc', '.c']:
        for f in os.listdir(folder):
            fpath = os.path.join(folder, f)
            if not f.endswith(ext):
                continue
            if 'original' in f or 'tb' in f or 'target' in f or 'mutant' in f or 'tmp' in f:
                continue
            # Check if file has <TARGET>
            try:
                with open(fpath) as fp:
                    content = fp.read()
                if '<TARGET>' in content:
                    dut_candidates.append((fpath, content))
            except:
                pass

    if not dut_candidates:
        print(f"  [{i+1:2d}] {name:30s} SKIP (no DUT with TARGET)")
        errors.append((name, "NO_DUT"))
        failed += 1
        continue

    dut_path, dut_src = dut_candidates[0]

    # Find the original file
    orig_candidates = glob.glob(os.path.join(folder, "*_original.cpp")) + \
                      glob.glob(os.path.join(folder, "*_original.cc"))
    if not orig_candidates:
        print(f"  [{i+1:2d}] {name:30s} SKIP (no original)")
        errors.append((name, "NO_ORIGINAL"))
        failed += 1
        continue

    with open(orig_tb) as f:
        tb_src = f.read()

    # Extra include dirs
    extra_include = f"-I{folder}"

    # === Golden test ===
    exe = os.path.join(folder, "golden_exe_tmp")
    cmd = f"g++ -std=c++17 -I{SUPPORT} {extra_include} -o {exe} {orig_tb} 2>&1"
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        print(f"  [{i+1:2d}] {name:30s} GOLDEN_BUILD_FAIL: {(r.stdout+r.stderr)[:80]}")
        errors.append((name, "GOLDEN_BUILD_FAIL"))
        failed += 1
        continue

    r2 = subprocess.run(exe, shell=True, capture_output=True, text=True, timeout=10)
    try: os.remove(exe)
    except: pass
    if r2.returncode != 0:
        print(f"  [{i+1:2d}] {name:30s} GOLDEN_RUN_FAIL: {r2.stderr[:80]}")
        errors.append((name, "GOLDEN_RUN_FAIL"))
        failed += 1
        continue

    # === Mutation test ===
    # Figure out the original file name that TB includes
    orig_basename = os.path.basename(orig_candidates[0])
    dut_basename = os.path.basename(dut_path)

    mutant_src = dut_src.replace("<TARGET>", "/* REMOVED */")
    mutant_basename = dut_basename.replace('.', '_mutant_tmp.')
    mutant_path = os.path.join(folder, mutant_basename)
    with open(mutant_path, "w") as f:
        f.write(mutant_src)

    # In the TB, replace the include of original with mutant
    mutant_tb = tb_src.replace(orig_basename, mutant_basename)
    mutant_tb_path = os.path.join(folder, "mutant_tmp_tb.cpp")
    with open(mutant_tb_path, "w") as f:
        f.write(mutant_tb)

    cmd = f"g++ -std=c++17 -I{SUPPORT} {extra_include} -o {exe} {mutant_tb_path} 2>&1"
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        print(f"  [{i+1:2d}] {name:30s} GOLDEN=PASS  MUTATION=DETECTED (BUILD_FAIL)")
        passed += 1
        os.remove(mutant_path); os.remove(mutant_tb_path)
        continue

    r2 = subprocess.run(exe, shell=True, capture_output=True, text=True, timeout=10)
    try: os.remove(exe)
    except: pass
    os.remove(mutant_path); os.remove(mutant_tb_path)

    if r2.returncode != 0:
        print(f"  [{i+1:2d}] {name:30s} GOLDEN=PASS  MUTATION=DETECTED (RUN_FAIL)")
        passed += 1
    else:
        print(f"  [{i+1:2d}] {name:30s} GOLDEN=PASS  MUTATION=NOT_DETECTED *** FAIL ***")
        errors.append((name, "MUTATION_NOT_DETECTED"))
        failed += 1

print(f"\n{'='*60}")
print(f"RESULTS: {passed} DETECTED / {passed+failed} TOTAL")
print(f"{'='*60}")
if errors:
    print(f"\nFailed/errors ({len(errors)}):")
    for e in errors:
        print(f"  {e}")
if passed == 50:
    print("\nALL 50/50 PASS!")
