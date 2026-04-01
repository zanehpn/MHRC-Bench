#!/usr/bin/env python3
"""
Chisel function verification: replace <TARGET> with model-generated code, compile & run testbench via sbt.

Usage:
    python3 run_function_verify.py responses_deepseek_v3_2_chisel.jsonl
    python3 run_function_verify.py responses_deepseek_v3_2_chisel.jsonl --folders Aligner Buffer
    python3 run_function_verify.py responses_deepseek_v3_2_chisel.jsonl --output results.jsonl
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
PROJECT_DIR = os.path.join(BASE, "test_project")
SRC_DIR = os.path.join(PROJECT_DIR, "src/main/scala")

SBT = "sbt"
TIMEOUT = 300  # seconds


# Complete mapping: candidate folder name -> (source filename in test_project, test class)
FOLDER_TO_CONFIG = {
    # === Modules with full test specs ===
    "counter":              ("counter.scala",              "loywong.examples.CounterExampleFuncSpec"),
    "maxpool":              ("maxpool.scala",              "final_project.MaxpoolFuncSpec"),
    "Bitmap":               ("Bitmap.scala",               "magmasi.components.BitmapFuncSpec"),
    "Regor":                ("Regor.scala",                "magmasi.components.RegorFuncSpec"),
    "RegFile":              ("RegFile.scala",              "rself.RegFileFuncSpec"),
    "encoder":              ("encoder.scala",              "loywong.examples.EncoderExampleFuncSpec"),
    "PMNaive":              ("PMNaive.scala",              "MSM.PMNaiveFuncSpec"),
    "MaxN":                 ("MaxN.scala",                 "pythia.MaxNFuncSpec"),
    "GCD":                  ("GCD.scala",                  "gcd.GCDFuncSpec"),
    "ArpCache":             ("ArpCache.scala",             "router.table.ArpCacheFuncSpec"),
    "Memory":               ("Memory.scala",               "cpu.MemoryFuncSpec"),
    "DMem":                 ("DMem.scala",                 "mem.DMemFuncSpec"),
    "IMem":                 ("IMem.scala",                 "mem.IMemFuncSpec"),
    "Counter":              ("Counter.scala",              "perfect.CounterModuleFuncSpec"),
    "PWM":                  ("PWM.scala",                  "perfect.util.PwmFuncSpec"),
    "DecoupledGCD":         ("DecoupledGCD.scala",         "gcd.DecoupledGcdFuncSpec"),
    "MemLoadStoreUnit":     ("MemLoadStoreUnit.scala",     "lsu.MemLoadStoreUnitFuncSpec"),
    "accumu":               ("accumu.scala",               "final_project.AccumuFuncSpec"),
    "Benes":                ("Benes.scala",                "magmasi.components.BenesFuncSpec"),
    "Scheduler":            ("Scheduler.scala",            "scheduler.SchedulerFuncSpec"),
    "Aligner":              ("Aligner.scala",              "icenet.AlignerFuncSpec"),
    # === New modules with test specs ===
    "SynchronizerReg":      ("SynchronizerReg.scala",      "asyncqueue.modules.SynchronizerRegFuncSpec"),
    "DeviceControlRegister":("DeviceControlRegister.scala", "dcr.DeviceControlRegisterFuncSpec"),
    "Limiter":              ("Limiter.scala",              "icenet.LimiterFuncSpec"),
    "Pauser":               ("Pauser.scala",               "icenet.PauserFuncSpec"),
    "TestUtils":            ("TestUtils.scala",            "icenet.TestUtilsFuncSpec"),
    "Buffer":               ("Buffer.scala",               "icenet.BufferFuncSpec"),
    "Tap":                  ("Tap.scala",                  "icenet.TapFuncSpec"),
    # === Elaboration-only (BlackBox/RawModule - compile check) ===
    "ClockDividerN":        ("ClockDividerN.scala",        None),  # BlackBox, no chiseltest
    "PeekQueue":            ("PeekQueue.scala",            None),  # RawModule, no chiseltest
}


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


def get_local_folder(cand):
    path = cand["path"]
    filename = os.path.basename(path).replace(".scala", "")
    folder_path = os.path.join(BASE, filename)
    if os.path.isdir(folder_path):
        return filename
    return None


def run_sbt_test(test_class):
    """Run sbt test. Returns (success, stage, message)."""
    env = os.environ.copy()
    env["PATH"] = "/tmp/sbt/bin:" + env.get("PATH", "")

    try:
        result = subprocess.run(
            [SBT, f'testOnly {test_class}'],
            capture_output=True, text=True, timeout=TIMEOUT,
            cwd=PROJECT_DIR, env=env,
        )
        if result.returncode != 0:
            output = result.stdout + result.stderr
            if "Compilation failed" in output or "[error]" in output:
                return False, "build", output[-500:]
            else:
                return False, "run", output[-500:]
        return True, "pass", ""
    except subprocess.TimeoutExpired:
        return False, "timeout", ""


def run_sbt_compile():
    """Just compile to check syntax. Returns (success, message)."""
    env = os.environ.copy()
    env["PATH"] = "/tmp/sbt/bin:" + env.get("PATH", "")

    try:
        result = subprocess.run(
            [SBT, "compile"],
            capture_output=True, text=True, timeout=TIMEOUT,
            cwd=PROJECT_DIR, env=env,
        )
        if result.returncode != 0:
            output = result.stdout + result.stderr
            return False, output[-500:]
        return True, ""
    except subprocess.TimeoutExpired:
        return False, "timeout"


def run_one_model(response_jsonl, candidates, tc_index, folder_filter=None):
    model_name = os.path.basename(response_jsonl)
    m = re.search(r'responses_(.+?)_chisel', model_name)
    short_name = m.group(1) if m else model_name

    responses = load_all_responses(response_jsonl)

    results = []
    pass_count = 0
    fail_count = 0
    skip_count = 0

    for cand in candidates:
        path = cand["path"]
        folder = get_local_folder(cand)

        if not folder:
            skip_count += 1
            continue

        if folder_filter and folder not in folder_filter:
            continue

        if folder not in FOLDER_TO_CONFIG:
            print(f"  SKIP  {folder:30s}  not configured for testing")
            skip_count += 1
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

        source_filename, test_class = FOLDER_TO_CONFIG[folder]
        source_path = os.path.join(SRC_DIR, source_filename)

        if not os.path.exists(source_path):
            print(f"  SKIP  {folder:30s}  source not in test_project")
            skip_count += 1
            continue

        # Read original content (the _original version with ground truth)
        with open(source_path) as f:
            original_content = f.read()

        # Build modified source from left_context + generated_code + right_context
        left = cand["left_context"]
        right = cand["right_context"]
        new_source = left + generated_code + "\n" + right

        entry = {
            "model": short_name,
            "local_folder": folder,
            "generated_code": generated_code,
            "ground_truth": resp.get("ground_truth", ""),
            "em_score": resp.get("em_score", None),
        }

        # Write modified source
        with open(source_path, "w") as f:
            f.write(new_source)

        try:
            if test_class is None:
                # No test available - just compile
                success, msg = run_sbt_compile()
                if success:
                    print(f"  PASS  {folder:30s}  (compile-only)")
                    pass_count += 1
                    entry["status"] = "pass"
                    entry["note"] = "compile-only"
                else:
                    print(f"  FAIL  {folder:30s}  [build] {msg[:100]}")
                    fail_count += 1
                    entry["status"] = "fail_build"
                    entry["error"] = msg
            else:
                success, stage, msg = run_sbt_test(test_class)
                if success:
                    print(f"  PASS  {folder}")
                    pass_count += 1
                    entry["status"] = "pass"
                else:
                    print(f"  FAIL  {folder:30s}  [{stage}] {msg[:100]}")
                    fail_count += 1
                    entry["status"] = f"fail_{stage}"
                    entry["error"] = msg
        finally:
            # Restore original source
            with open(source_path, "w") as f:
                f.write(original_content)

        results.append(entry)

    total = pass_count + fail_count
    rate = (pass_count / total * 100) if total > 0 else 0

    print()
    print(f"  [{short_name}] {pass_count}/{total} PASS ({rate:.1f}%)  |  FAIL: {fail_count}  |  SKIP: {skip_count}")
    print()

    return results, {"model": short_name, "pass": pass_count, "fail": fail_count,
                     "total": total, "skip": skip_count, "pass_rate": round(rate, 1)}


def main():
    parser = argparse.ArgumentParser(description="Chisel function verification")
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
        with open(args.output, "w") as f:
            for r in all_results:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        print(f"Results written to {args.output}")


if __name__ == "__main__":
    main()
