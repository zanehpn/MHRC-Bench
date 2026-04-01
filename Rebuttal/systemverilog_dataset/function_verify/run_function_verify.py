#!/usr/bin/env python3
"""
SystemVerilog function verification: replace <TARGET> with model-generated code,
compile & run testbench via VCS.

Testbenches include the design file (not _original), so replacing <TARGET> in the
design file is sufficient for the testbench to exercise the generated code.

Usage:
    python3 run_function_verify.py responses_deepseek_v3_2_systemverilog.jsonl
    python3 run_function_verify.py responses_deepseek_v3_2_systemverilog.jsonl --folders AXI_Arbiter_R flat
    python3 run_function_verify.py responses_deepseek_v3_2_systemverilog.jsonl --output results.jsonl
"""

import argparse
import json
import os
import re
import subprocess
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
CANDIDATES_JSONL = os.path.join(BASE, "design_function_verify_candidates_50.jsonl")
TEST_CONTENT_JSONL = os.path.join(BASE, "..", "test_content.jsonl")
VCS_RUN_SH = os.path.join(BASE, "_common_vcs_run.sh")

TIMEOUT = 120  # seconds per design


def load_candidates():
    cands = []
    with open(CANDIDATES_JSONL, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                cands.append(json.loads(line))
    return cands


def load_test_content_index():
    """Build path -> line-index mapping from test_content.jsonl."""
    idx = {}
    with open(TEST_CONTENT_JSONL, encoding="utf-8") as f:
        for i, line in enumerate(f):
            obj = json.loads(line.strip())
            idx[obj["path"]] = i
    return idx


def load_all_responses(response_jsonl):
    responses = []
    with open(response_jsonl, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                responses.append(json.loads(line))
    return responses


def compile_and_run(design_dir):
    """
    Run _common_vcs_run.sh inside design_dir.
    Returns (success, stage, message).
    """
    try:
        result = subprocess.run(
            ["bash", VCS_RUN_SH],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, timeout=TIMEOUT,
            cwd=design_dir,
        )
        output = result.stdout + result.stderr

        # Check for compilation failure
        if result.returncode != 0:
            if "Error-" in output or "error:" in output.lower():
                return False, "build", output[-500:]
            return False, "run", output[-500:]

        # Check for assertion/error in simulation output
        # Look at run.log if it exists
        run_log_path = os.path.join(design_dir, "run.log")
        if os.path.exists(run_log_path):
            with open(run_log_path, encoding="utf-8", errors="replace") as f:
                log_content = f.read()
        else:
            log_content = output

        # Check for explicit FAIL markers and VCS runtime errors
        for line in log_content.splitlines():
            # VCS runtime errors: Error-[SIMERR_...], Error-[URMI], etc.
            if re.match(r'^Error-\[', line):
                return False, "run", log_content[-500:]
            low = line.lower()
            if "error" in low and ("$error" in low or "error:" in low):
                return False, "run", log_content[-500:]
            if re.search(r'\bFAIL\b', line, re.IGNORECASE):
                if "FAILURE" in line or "$error" in line or "FAIL" in line.split("//")[0]:
                    return False, "run", log_content[-500:]

        # Non-zero exit code
        if result.returncode != 0:
            return False, "run", output[-500:]

        return True, "pass", ""

    except subprocess.TimeoutExpired:
        return False, "timeout", ""


def run_one_model(response_jsonl, candidates, tc_index, folder_filter=None):
    """Run verification for one model. Returns (results_list, summary_dict)."""
    model_name = os.path.basename(response_jsonl)
    m = re.search(r'responses_(.+?)_systemverilog', model_name)
    short_name = m.group(1) if m else model_name

    responses = load_all_responses(response_jsonl)

    results = []
    pass_count = 0
    fail_count = 0
    skip_count = 0

    for cand in candidates:
        folder = cand["local_folder"]
        path = cand["path"]
        design_dir = os.path.join(BASE, folder)

        if folder_filter and folder not in folder_filter:
            continue

        # Map candidate to response via test_content index
        if path not in tc_index:
            print(f"  SKIP  {folder:40s}  path not in test_content")
            skip_count += 1
            continue

        line_idx = tc_index[path]
        if line_idx >= len(responses):
            print(f"  SKIP  {folder:40s}  no response at index {line_idx}")
            skip_count += 1
            continue

        resp = responses[line_idx]
        generated_code = resp.get("generated_code", "")
        if not generated_code:
            print(f"  SKIP  {folder:40s}  empty generated_code")
            skip_count += 1
            continue

        # Read the design file containing <TARGET>
        local_file = cand.get("local_file", "")
        source_path = os.path.join(BASE, local_file) if local_file else None
        if not source_path or not os.path.exists(source_path):
            print(f"  SKIP  {folder:40s}  source file not found: {local_file}")
            skip_count += 1
            continue

        with open(source_path, encoding="utf-8", errors="replace") as f:
            original_content = f.read()

        if "<TARGET>" not in original_content:
            print(f"  SKIP  {folder:40s}  no <TARGET> in source")
            skip_count += 1
            continue

        # Replace <TARGET> with generated code
        filled_content = original_content.replace("<TARGET>", generated_code, 1)
        with open(source_path, "w", encoding="utf-8") as f:
            f.write(filled_content)

        entry = {
            "model": short_name,
            "local_folder": folder,
            "generated_code": generated_code,
            "ground_truth": resp.get("ground_truth", ""),
            "em_score": resp.get("em_score", None),
        }

        try:
            success, stage, msg = compile_and_run(design_dir)
            if success:
                print(f"  PASS  {folder}")
                pass_count += 1
                entry["status"] = "pass"
            else:
                print(f"  FAIL  {folder:40s}  [{stage}] {msg[:80]}")
                fail_count += 1
                entry["status"] = f"fail_{stage}"
                entry["error"] = msg
        finally:
            # Always restore original source
            with open(source_path, "w", encoding="utf-8") as f:
                f.write(original_content)

        results.append(entry)

    total = pass_count + fail_count
    rate = (pass_count / total * 100) if total > 0 else 0

    print()
    print(f"  [{short_name}] {pass_count}/{total} PASS ({rate:.1f}%)"
          f"  |  FAIL: {fail_count}  |  SKIP: {skip_count}")
    print()

    return results, {
        "model": short_name,
        "pass": pass_count,
        "fail": fail_count,
        "total": total,
        "skip": skip_count,
        "pass_rate": round(rate, 1),
    }


def main():
    parser = argparse.ArgumentParser(
        description="SystemVerilog function verification")
    parser.add_argument("response_jsonls", nargs="+",
                        help="Path(s) to model response JSONL file(s)")
    parser.add_argument("--folders", nargs="*",
                        help="Only test specific folders")
    parser.add_argument("--output",
                        help="Output detailed results to JSONL")
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
        results, summary = run_one_model(
            resp_file, candidates, tc_index, folder_filter)
        all_results.extend(results)
        summaries.append(summary)

    # Summary table
    if len(summaries) > 1:
        print("=" * 60)
        print(f"  {'Model':<20s} {'Pass':>5s} {'Fail':>5s}"
              f" {'Total':>5s} {'Rate':>8s}")
        print("-" * 60)
        for s in summaries:
            print(f"  {s['model']:<20s} {s['pass']:>5d} {s['fail']:>5d}"
                  f" {s['total']:>5d} {s['pass_rate']:>7.1f}%")
        print("=" * 60)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            for r in all_results:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        print(f"Results written to {args.output}")


if __name__ == "__main__":
    main()
