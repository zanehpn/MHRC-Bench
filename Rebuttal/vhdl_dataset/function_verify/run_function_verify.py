#!/usr/bin/env python3
"""
VHDL function verification: replace <TARGET> with model-generated code, run VCS testbench.

Usage:
    python3 run_function_verify.py responses_deepseek_v3_2_vhdl.jsonl
    python3 run_function_verify.py responses_deepseek_v3_2_vhdl.jsonl --folders counter add_preamble
    python3 run_function_verify.py responses_deepseek_v3_2_vhdl.jsonl --output results.jsonl
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
RUN_EVAL_SH = os.path.join(BASE, "run_eval.sh")

TIMEOUT = 7200  # seconds for entire run_eval.sh call


def load_candidates():
    cands = []
    with open(CANDIDATES_JSONL, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                cands.append(json.loads(line))
    return cands


def load_test_content_index():
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


def fill_target(src_path, generated_code, dst_path):
    """Read src_path, replace <TARGET> with generated_code, write to dst_path."""
    with open(src_path, encoding="utf-8", errors="replace") as f:
        content = f.read()

    if "<TARGET>" not in content:
        return False

    filled = content.replace("<TARGET>", generated_code, 1)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, "w", encoding="utf-8") as f:
        f.write(filled)
    return True


def run_eval_one(design_name, eval_dir):
    """Run run_eval.sh for a single design. Returns (status, error_msg)."""
    env = os.environ.copy()
    env["EVAL_DIR"] = eval_dir

    cmd = ["bash", RUN_EVAL_SH, design_name]
    try:
        result = subprocess.run(
            cmd, cwd=BASE, env=env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, timeout=TIMEOUT
        )
        output = result.stdout + result.stderr

        # Parse PASS/FAIL from output
        for line in result.stdout.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[1] == design_name:
                if parts[0] == "PASS":
                    return "pass", ""
                elif parts[0] == "FAIL":
                    # Extract failure stage
                    stage_match = re.search(r'\[(.*?)\]', line)
                    stage = stage_match.group(1) if stage_match else "run"
                    return f"fail_{stage}", output[-500:]
                elif parts[0] == "SKIP":
                    return "skip", "skipped by run_eval.sh"

        # If we didn't find PASS/FAIL for this design, check summary
        if "PASS: 0" in output and "FAIL: 0" in output:
            return "skip", "design not found in run_eval.sh"

        # Fallback: check for any PASS/FAIL
        for line in result.stdout.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0] in ("PASS", "FAIL", "SKIP"):
                if parts[0] == "PASS":
                    return "pass", ""
                elif parts[0] == "FAIL":
                    stage_match = re.search(r'\[(.*?)\]', line)
                    stage = stage_match.group(1) if stage_match else "run"
                    return f"fail_{stage}", output[-500:]

        return "skip", "no result parsed"
    except subprocess.TimeoutExpired:
        return "fail_timeout", ""


def run_one_model(response_jsonl, candidates, tc_index, folder_filter=None):
    model_name = os.path.basename(response_jsonl)
    m = re.search(r'responses_(.+?)_vhdl', model_name)
    short_name = m.group(1) if m else model_name

    responses = load_all_responses(response_jsonl)

    # Prepare eval work directory
    eval_dir = os.path.join(BASE, ".eval_work_verify")
    os.makedirs(eval_dir, exist_ok=True)

    results = []
    pass_count = 0
    fail_count = 0
    skip_count = 0

    for cand in candidates:
        folder = cand["local_folder"]
        path = cand["path"]

        if folder_filter and folder not in folder_filter:
            continue

        if path not in tc_index:
            print(f"  SKIP  {folder:30s}  path not in test_content")
            skip_count += 1
            continue

        line_idx = tc_index[path]
        if line_idx >= len(responses):
            print(f"  SKIP  {folder:30s}  no response at index {line_idx}")
            skip_count += 1
            continue

        resp = responses[line_idx]
        generated_code = resp.get("generated_code", "")
        if not generated_code:
            print(f"  SKIP  {folder:30s}  empty generated_code")
            skip_count += 1
            continue

        local_file = cand.get("local_file", "")
        src_path = os.path.join(BASE, local_file)

        if not os.path.exists(src_path):
            print(f"  SKIP  {folder:30s}  source file not found: {local_file}")
            skip_count += 1
            continue

        # Fill <TARGET> into eval work dir
        dst_path = os.path.join(eval_dir, local_file)
        if not fill_target(src_path, generated_code, dst_path):
            print(f"  SKIP  {folder:30s}  no <TARGET> in source")
            skip_count += 1
            continue

        entry = {
            "model": short_name,
            "local_folder": folder,
            "generated_code": generated_code,
            "ground_truth": resp.get("ground_truth", ""),
            "em_score": resp.get("em_score", None),
        }

        # Run verification
        status, error_msg = run_eval_one(folder, eval_dir)

        if status == "pass":
            print(f"  PASS  {folder}")
            pass_count += 1
            entry["status"] = "pass"
        elif status == "skip":
            print(f"  SKIP  {folder:30s}  {error_msg[:80]}")
            skip_count += 1
            entry["status"] = "skip"
            entry["error"] = error_msg
        else:
            print(f"  FAIL  {folder:30s}  [{status}] {error_msg[:80]}")
            fail_count += 1
            entry["status"] = status
            entry["error"] = error_msg

        results.append(entry)

    total = pass_count + fail_count
    rate = (pass_count / total * 100) if total > 0 else 0

    print()
    print(f"  [{short_name}] {pass_count}/{total} PASS ({rate:.1f}%)  |  FAIL: {fail_count}  |  SKIP: {skip_count}")
    print()

    return results, {"model": short_name, "pass": pass_count, "fail": fail_count,
                     "total": total, "skip": skip_count, "pass_rate": round(rate, 1)}


def main():
    parser = argparse.ArgumentParser(description="VHDL function verification")
    parser.add_argument("response_jsonls", nargs="+", help="Path(s) to model response JSONL file(s)")
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
        with open(args.output, "w", encoding="utf-8") as f:
            for r in all_results:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        print(f"Results written to {args.output}")


if __name__ == "__main__":
    main()
