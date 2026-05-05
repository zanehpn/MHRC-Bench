#!/usr/bin/env python3
"""
Function verification via differential testing.

Strategy:
  1. Compile & run the *original* testbench (with ground-truth code) → golden stdout + rc.
  2. Replace <TARGET> in the DUT source with model-generated code, then compile & run
     the *same* testbench (rewritten to #include the DUT instead of _original) → candidate output.
  3. PASS iff the candidate compiles, runs, and produces the same (stdout, returncode) as golden.

This approach does not depend on testbench assertion quality; any observable
output difference between ground-truth and generated code is caught.

Usage:
    python3 run_function_verify.py responses_grok4_hls.jsonl
    python3 run_function_verify.py responses_grok4_hls.jsonl --output results.jsonl
    python3 run_function_verify.py responses_grok4_hls.jsonl --folders flat spmv
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

BASE = os.path.dirname(os.path.abspath(__file__))
CANDIDATES_JSONL = os.path.join(BASE, "design_function_verify_candidates_50.jsonl")
TEST_CONTENT_JSONL = os.path.join(BASE, "..", "test_content.jsonl")

CXX = os.environ.get("CXX", "g++")
CXXFLAGS = ["-std=c++17", "-w"]
SUPPORT = f"-I{os.path.join(BASE, '_support')}"
TIMEOUT = 120


# ── helpers ──────────────────────────────────────────────────────────

def load_candidates():
    cands = []
    with open(CANDIDATES_JSONL) as f:
        for line in f:
            cands.append(json.loads(line.strip()))
    return cands


def load_test_content_index():
    idx = {}
    with open(TEST_CONTENT_JSONL) as f:
        for i, line in enumerate(f):
            obj = json.loads(line.strip())
            idx[obj["path"]] = i
    return idx


def load_all_responses(response_jsonl):
    responses = []
    with open(response_jsonl) as f:
        for line in f:
            responses.append(json.loads(line.strip()))
    return responses


def find_original_tb(folder_path):
    """Find *_original_tb* file."""
    for fn in os.listdir(folder_path):
        if "_original_tb" in fn:
            return os.path.join(folder_path, fn)
    return None


def find_target_tb(folder_path):
    """Find *_target_tb* file (fallback)."""
    for fn in os.listdir(folder_path):
        if "_target_tb" in fn:
            return os.path.join(folder_path, fn)
    return None


def find_dut_and_original(folder_path, folder_name, local_file):
    """Find the DUT source (with <TARGET>) and its _original counterpart."""
    # Try local_file first
    if local_file:
        dut_path = os.path.join(BASE, local_file)
        if os.path.exists(dut_path) and "<TARGET>" in open(dut_path).read():
            # Derive original path
            base_name = os.path.basename(dut_path)
            name, ext = os.path.splitext(base_name)
            original_name = f"{name}_original{ext}"
            original_path = os.path.join(os.path.dirname(dut_path), original_name)
            if os.path.exists(original_path):
                return dut_path, original_path
    # Scan folder
    for fn in os.listdir(folder_path):
        fp = os.path.join(folder_path, fn)
        if not os.path.isfile(fp):
            continue
        if "_original" in fn or "_target_tb" in fn or "_original_tb" in fn:
            continue
        if fn.endswith((".cpp", ".cc", ".c")):
            with open(fp) as f:
                content = f.read()
            if "<TARGET>" in content:
                name, ext = os.path.splitext(fn)
                original_path = os.path.join(folder_path, f"{name}_original{ext}")
                if os.path.exists(original_path):
                    return fp, original_path
    return None, None


def compile_and_run(tb_path, folder_path):
    """Compile and run. Returns (success, stage, stdout, stderr, rc)."""
    with tempfile.NamedTemporaryFile(suffix="_tb", delete=False) as tmp:
        bin_path = tmp.name
    try:
        cmd = [CXX] + CXXFLAGS + [SUPPORT, f"-I{folder_path}", "-o", bin_path, tb_path]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
        if result.returncode != 0:
            return False, "build", "", result.stderr[:500], result.returncode
        result = subprocess.run([bin_path], capture_output=True, text=True, timeout=TIMEOUT)
        return True, "run", result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return False, "timeout", "", "", -1
    finally:
        if os.path.exists(bin_path):
            os.unlink(bin_path)


def make_target_tb(original_tb_path, dut_basename, original_basename):
    """Create a temporary testbench that includes the DUT instead of the _original source.

    Rewrites #include "xxx_original.cpp" → #include "xxx.cpp" (the DUT with <TARGET> replaced).
    """
    with open(original_tb_path) as f:
        content = f.read()
    new_content = content.replace(
        f'#include "{original_basename}"',
        f'#include "{dut_basename}"',
    )
    if new_content == content:
        # Try broader replacement
        new_content = content.replace(original_basename, dut_basename)
    tmp = tempfile.NamedTemporaryFile(
        suffix=".cpp", dir=os.path.dirname(original_tb_path),
        delete=False, mode="w",
    )
    tmp.write(new_content)
    tmp.close()
    return tmp.name


# ── golden cache ─────────────────────────────────────────────────────

_golden_cache = {}   # folder → (stdout, rc)  or  None on failure


def get_golden(folder, folder_path):
    """Compile & run the original TB once per folder. Cache the result."""
    if folder in _golden_cache:
        return _golden_cache[folder]

    original_tb = find_original_tb(folder_path)
    if not original_tb:
        _golden_cache[folder] = None
        return None

    ok, stage, stdout, stderr, rc = compile_and_run(original_tb, folder_path)
    if not ok or rc != 0:
        print(f"  WARN  {folder:30s}  golden TB failed [{stage}] rc={rc}")
        _golden_cache[folder] = None
        return None

    _golden_cache[folder] = (stdout, rc)
    return (stdout, rc)


# ── per-model runner ─────────────────────────────────────────────────

def run_one_model(response_jsonl, candidates, tc_index, folder_filter=None):
    model_name = os.path.basename(response_jsonl)
    m = re.search(r'responses_(.+?)_hls', model_name)
    short_name = m.group(1) if m else model_name

    responses = load_all_responses(response_jsonl)

    results = []
    pass_count = 0
    fail_count = 0
    skip_count = 0

    for cand in candidates:
        folder = cand["local_folder"]
        path = cand["path"]
        folder_path = os.path.join(BASE, folder)
        local_file = cand.get("local_file", "")

        if folder_filter and folder not in folder_filter:
            continue

        if path not in tc_index:
            skip_count += 1
            continue

        line_idx = tc_index[path]
        if line_idx >= len(responses):
            skip_count += 1
            continue

        resp = responses[line_idx]
        generated_code = resp["generated_code"]

        # Find DUT and original
        dut_path, original_path = find_dut_and_original(folder_path, folder, local_file)
        if not dut_path or not original_path:
            print(f"  SKIP  {folder:30s}  no DUT/<TARGET> pair")
            skip_count += 1
            continue

        dut_basename = os.path.basename(dut_path)
        original_basename = os.path.basename(original_path)

        # Read original DUT content (with <TARGET>)
        with open(dut_path) as f:
            dut_template = f.read()

        if "<TARGET>" not in dut_template:
            print(f"  SKIP  {folder:30s}  no <TARGET>")
            skip_count += 1
            continue

        # Step 1: get golden output (from _original_tb + _original.cpp)
        golden = get_golden(folder, folder_path)
        if golden is None:
            print(f"  SKIP  {folder:30s}  golden TB failed")
            skip_count += 1
            continue

        golden_stdout, golden_rc = golden

        # Step 2: replace <TARGET> with generated code
        new_content = dut_template.replace("<TARGET>", generated_code)
        with open(dut_path, "w") as f:
            f.write(new_content)

        entry = {
            "model": short_name,
            "local_folder": folder,
            "generated_code": generated_code,
            "ground_truth": resp.get("ground_truth", ""),
            "em_score": resp.get("em_score", None),
        }

        tmp_tb = None
        try:
            # Step 3: create TB that includes DUT instead of _original
            original_tb = find_original_tb(folder_path)
            if not original_tb:
                print(f"  SKIP  {folder:30s}  no original_tb")
                skip_count += 1
                continue

            tmp_tb = make_target_tb(original_tb, dut_basename, original_basename)

            ok, stage, stdout, stderr, rc = compile_and_run(tmp_tb, folder_path)

            if not ok:
                print(f"  FAIL  {folder:30s}  [build] {stderr[:60]}")
                fail_count += 1
                entry["status"] = f"fail_{stage}"
                entry["error"] = stderr[:500]
            elif rc != golden_rc or stdout != golden_stdout:
                detail = f"rc={rc}(exp {golden_rc})"
                if stdout != golden_stdout:
                    detail += " stdout_mismatch"
                print(f"  FAIL  {folder:30s}  [diff] {detail}")
                fail_count += 1
                entry["status"] = "fail_diff"
                entry["error"] = detail
            else:
                print(f"  PASS  {folder}")
                pass_count += 1
                entry["status"] = "pass"
        finally:
            # Restore original DUT content
            with open(dut_path, "w") as f:
                f.write(dut_template)
            if tmp_tb and os.path.exists(tmp_tb):
                os.unlink(tmp_tb)

        results.append(entry)

    total = pass_count + fail_count
    rate = (pass_count / total * 100) if total > 0 else 0

    print()
    print(f"  [{short_name}] {pass_count}/{total} PASS ({rate:.1f}%)  |  FAIL: {fail_count}  |  SKIP: {skip_count}")
    print()

    return results, {"model": short_name, "pass": pass_count, "fail": fail_count,
                     "total": total, "skip": skip_count, "pass_rate": round(rate, 1)}


# ── main ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="HLS function verification (differential)")
    parser.add_argument("response_jsonls", nargs="+",
                        help="Path(s) to model response JSONL file(s)")
    parser.add_argument("--folders", nargs="*", help="Only test specific folders")
    parser.add_argument("--output", help="Output detailed results to JSONL")
    args = parser.parse_args()

    candidates = load_candidates()
    tc_index = load_test_content_index()
    folder_filter = set(args.folders) if args.folders else None

    all_results = []
    summaries = []

    for resp_file in args.response_jsonls:
        print(f"{'=' * 60}")
        print(f"  Model: {os.path.basename(resp_file)}")
        print(f"{'=' * 60}")
        results, summary = run_one_model(resp_file, candidates, tc_index, folder_filter)
        all_results.extend(results)
        summaries.append(summary)

    if len(summaries) > 1:
        print("=" * 60)
        print(f"  {'Model':<20s} {'Pass':>5s} {'Fail':>5s} {'Total':>5s} {'Rate':>8s}")
        print("-" * 60)
        for s in summaries:
            print(f"  {s['model']:<20s} {s['pass']:>5d} {s['fail']:>5d} {s['total']:>5d} {s['pass_rate']:>7.1f}%")
        print("=" * 60)

    if args.output:
        with open(args.output, "w") as f:
            for r in all_results:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        print(f"Results written to {args.output}")


if __name__ == "__main__":
    main()
