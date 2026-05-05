#!/usr/bin/env python3
"""
Evaluate LLM-generated VHDL code via functional verification.

Usage:
  python3 eval_model.py --responses <responses.jsonl> [--design <name>]

The responses JSONL must have 50 entries matching design_function_verify_candidates_50.jsonl
(matched by order). Each entry needs at least a 'generated_code' field.

Workflow:
  1. Read candidates_50 to get (local_folder, local_file, groundtruth)
  2. Read responses JSONL to get generated_code per candidate
  3. For each candidate: replace <TARGET> in the design file with generated_code
  4. Run run_eval.sh (which uses the filled-in files as DUT)
  5. Report pass/fail per design and overall pass rate
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
CANDIDATES = os.path.join(BASE, "design_function_verify_candidates_50.jsonl")


def load_candidates():
    """Load the 50 candidate tasks."""
    tasks = []
    with open(CANDIDATES, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                tasks.append(json.loads(line))
    return tasks


def load_responses(path):
    """Load responses JSONL. Returns list of dicts with 'generated_code'."""
    responses = []
    with open(path, encoding="utf-8") as f:
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
        print(f"  WARNING: no <TARGET> in {src_path}", file=sys.stderr)
        filled = content
    else:
        filled = content.replace("<TARGET>", generated_code, 1)

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, "w", encoding="utf-8") as f:
        f.write(filled)


def main():
    parser = argparse.ArgumentParser(description="Evaluate LLM VHDL completions")
    parser.add_argument("--responses", required=True, help="Path to responses JSONL")
    parser.add_argument("--design", default=None,
                        help="Run only this design (e.g. 'counter')")
    parser.add_argument("--eval-dir", default=None,
                        help="Directory for filled-in DUT files (default: .eval_work)")
    args = parser.parse_args()

    candidates = load_candidates()
    responses = load_responses(args.responses)

    if len(responses) != len(candidates):
        print(f"WARNING: {len(responses)} responses vs {len(candidates)} candidates. "
              f"Matching by position up to min({len(responses)}, {len(candidates)}).",
              file=sys.stderr)

    eval_dir = args.eval_dir or os.path.join(BASE, ".eval_work")
    os.makedirs(eval_dir, exist_ok=True)

    # Phase 1: Fill <TARGET> for each design
    design_filter = []
    n = min(len(responses), len(candidates))
    for i in range(n):
        cand = candidates[i]
        resp = responses[i]
        folder = cand["local_folder"]

        if args.design and folder != args.design:
            continue

        local_file = cand["local_file"]  # e.g. "counter/counter.vhd"
        src_path = os.path.join(BASE, local_file)
        dst_path = os.path.join(eval_dir, local_file)

        generated = resp.get("generated_code", "")
        if not generated:
            print(f"  SKIP {folder}: no generated_code in response")
            continue

        fill_target(src_path, generated, dst_path)
        design_filter.append(folder)
        print(f"  Filled {folder}: {len(generated)} chars -> {dst_path}")

    if not design_filter:
        print("No designs to evaluate.")
        return

    # Phase 2: Run verification
    run_eval = os.path.join(BASE, "run_eval.sh")
    env = os.environ.copy()
    env["EVAL_DIR"] = eval_dir

    cmd = ["bash", run_eval] + design_filter
    print(f"\nRunning: {' '.join(cmd)}")
    print(f"EVAL_DIR={eval_dir}\n")

    result = subprocess.run(cmd, cwd=BASE, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            universal_newlines=True, timeout=7200)

    print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)

    # Phase 3: Parse results
    pass_count = 0
    fail_count = 0
    skip_count = 0
    results = {}
    for line in result.stdout.splitlines():
        line = line.strip()
        # Match "PASS  <name>" but not "PASS: 1 ..." (summary) or "Failed designs:"
        parts = line.split()
        if (len(parts) >= 2
                and parts[0] in ("PASS", "FAIL", "SKIP")
                and not parts[1].startswith(":")
                and parts[1] not in ("designs:", "Rate:")):
            name = parts[1]
            status = parts[0]
            if name not in results:  # avoid double-counting
                results[name] = status
                if status == "PASS":
                    pass_count += 1
                elif status == "FAIL":
                    fail_count += 1
                else:
                    skip_count += 1

    total = pass_count + fail_count + skip_count
    print(f"\n{'='*60}")
    print(f"  EVALUATION RESULTS")
    print(f"  PASS: {pass_count}/{total}  FAIL: {fail_count}/{total}  SKIP: {skip_count}/{total}")
    if total > 0:
        print(f"  Pass Rate: {pass_count/total*100:.1f}%")
    print(f"{'='*60}")

    # Write results to JSON
    out_path = args.responses.replace(".jsonl", "_func_verify.json")
    summary = {
        "responses_file": args.responses,
        "total": total,
        "pass": pass_count,
        "fail": fail_count,
        "skip": skip_count,
        "pass_rate": pass_count / total if total > 0 else 0,
        "per_design": results,
    }
    with open(out_path, "w") as f:
        json.dump(summary, f, indent=2)
    print(f"\nResults written to {out_path}")


if __name__ == "__main__":
    main()
