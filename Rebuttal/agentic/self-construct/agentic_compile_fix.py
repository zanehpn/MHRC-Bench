#!/usr/bin/env python3
"""
Agentic Compile-Fix Workflow for HDL Code Completion Evaluation.

This script implements a simple agentic loop:
  Round 0: Single-shot completion (from existing verified results)
  Round 1-N: If compilation/simulation fails, feed error back to LLM → regenerate → re-verify

Usage:
    python3 agentic_compile_fix.py --lang chisel --model gpt5 --max-rounds 3
    python3 agentic_compile_fix.py --lang systemverilog --model gpt5 --max-rounds 3
    python3 agentic_compile_fix.py --lang all --model gpt5 --max-rounds 3
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
import copy
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# ============================================================
# Paths
# ============================================================
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
EVAL_BASE = REPO_ROOT / "Model_evaluation" / "No_RAG" / "function_verified" / "eval_results_fill_in"

# Import API functions
sys.path.insert(0, str(SCRIPT_DIR.parent / "lib_function"))
from api_function import gpt5, gemini2_5, deepseek_v3_2, grok4

# Model dispatch
MODEL_FN = {
    "gpt5": gpt5,
    "gemini2_5": gemini2_5,
    "deepseek_v3_2": deepseek_v3_2,
    "grok4": grok4,
}

LANG_CONFIG = {
    "chisel": {
        "dataset_dir": REPO_ROOT / "chisel_dataset",
        "verify_dir": REPO_ROOT / "chisel_dataset" / "function_verify",
        "test_content": REPO_ROOT / "chisel_dataset" / "test_content.jsonl",
        "candidates": REPO_ROOT / "chisel_dataset" / "function_verify" / "design_function_verify_candidates_50.jsonl",
        "verified_pattern": "responses_{model}_chisel_verified.jsonl",
        "file_ext": ".scala",
    },
    "hls": {
        "dataset_dir": REPO_ROOT / "hls_dataset",
        "verify_dir": REPO_ROOT / "hls_dataset" / "function_verify",
        "test_content": REPO_ROOT / "hls_dataset" / "test_content.jsonl",
        "candidates": REPO_ROOT / "hls_dataset" / "function_verify" / "design_function_verify_candidates_50.jsonl",
        "verified_pattern": "responses_{model}_hls_verified.jsonl",
        "file_ext": ".c",
    },
    "systemverilog": {
        "dataset_dir": REPO_ROOT / "systemverilog_dataset",
        "verify_dir": REPO_ROOT / "systemverilog_dataset" / "function_verify",
        "test_content": REPO_ROOT / "systemverilog_dataset" / "test_content.jsonl",
        "candidates": REPO_ROOT / "systemverilog_dataset" / "function_verify" / "design_function_verify_candidates_50.jsonl",
        "verified_pattern": "responses_{model}_systemverilog_verified.jsonl",
        "file_ext": ".sv",
    },
    "vhdl": {
        "dataset_dir": REPO_ROOT / "vhdl_dataset",
        "verify_dir": REPO_ROOT / "vhdl_dataset" / "function_verify",
        "test_content": REPO_ROOT / "vhdl_dataset" / "test_content.jsonl",
        "candidates": REPO_ROOT / "vhdl_dataset" / "function_verify" / "design_function_verify_candidates_50.jsonl",
        "verified_pattern": "responses_{model}_vhdl_verified.jsonl",
        "file_ext": ".vhd",
    },
}


# ============================================================
# Prompt Templates
# ============================================================
SYSTEM_PROMPT = """You are an expert hardware design engineer. You are helping to fix code that failed to compile or pass simulation tests.
Given the original code context, the previously generated code, and the error message, generate a corrected version of ONLY the missing code snippet.
Return ONLY the raw code — no markdown fences, no explanations, no comments about what you changed."""

# Import scoring functions
sys.path.insert(0, str(SCRIPT_DIR.parent / "lib_function"))
try:
    from exact_match import evaluate_em, evaluate_es, normalize_code
except ImportError:
    def evaluate_em(pred, ref, lang=""):
        return 1.0 if pred.strip() == ref.strip() else 0.0
    def evaluate_es(pred, ref, lang=""):
        return 0.0

FIX_PROMPT_TEMPLATE = """The following {lang} code completion failed with an error.

## Code Context (before the missing part):
```
{left_context}
```

## Code Context (after the missing part):
```
{right_context}
```

## Previously Generated Code (FAILED):
```
{failed_code}
```

## Error Message:
```
{error_message}
```

## Ground Truth (reference, for understanding intent only):
The missing code should complete the functionality between the left and right context.

Please generate the corrected code snippet that should replace the failed code.
Output ONLY the replacement code, nothing else. Do not include markdown fences or explanations."""


# ============================================================
# Load Round-0 results (from existing verified files)
# ============================================================
def load_round0_results(lang: str, model: str) -> List[Dict]:
    """Load the already-verified single-shot results as Round 0."""
    config = LANG_CONFIG[lang]
    pattern = config["verified_pattern"].format(model=model)
    verified_path = EVAL_BASE / pattern

    if not verified_path.exists():
        # Try alternative patterns
        for f in EVAL_BASE.glob(f"responses_{model}_{lang}*_verified.jsonl"):
            verified_path = f
            break

    if not verified_path.exists():
        print(f"  WARNING: No verified file found for {model}/{lang}")
        print(f"  Searched: {EVAL_BASE / pattern}")
        return []

    results = []
    with open(verified_path) as f:
        for line in f:
            if line.strip():
                obj = json.loads(line)
                # Skip summary lines or entries without local_folder
                if "local_folder" not in obj or "status" not in obj:
                    continue
                if not obj.get("status"):
                    obj["status"] = "unknown"
                results.append(obj)

    print(f"  Loaded {len(results)} Round-0 results from {verified_path.name}")
    return results


# ============================================================
# Load candidates (to get left_context / right_context)
# ============================================================
def load_candidates(lang: str) -> Dict[str, Dict]:
    """Load candidates indexed by local_folder."""
    config = LANG_CONFIG[lang]
    cand_path = config["candidates"]

    if not cand_path.exists():
        print(f"  WARNING: Candidates file not found: {cand_path}")
        return {}

    cands = {}
    with open(cand_path) as f:
        for line in f:
            if line.strip():
                obj = json.loads(line)
                folder = obj.get("local_folder", Path(obj["path"]).stem)
                cands[folder] = obj

    return cands


# ============================================================
# Compilation / Verification
# ============================================================
def run_verification_vhdl(lang: str, local_folder: str, generated_code: str,
                          candidates: Dict) -> Tuple[str, str]:
    """VHDL-specific: use central run_eval.sh with <TARGET> replacement."""
    config = LANG_CONFIG[lang]
    verify_dir = config["verify_dir"]

    cand = candidates.get(local_folder)
    if not cand:
        return "skip", "No candidate found"

    local_file = cand.get("local_file", "")
    source_path = verify_dir / local_file
    if not source_path.exists():
        return "skip", "Source file not found"

    # Read original (has <TARGET>), replace, run, restore
    with open(str(source_path), encoding="utf-8", errors="replace") as f:
        original_content = f.read()

    if "<TARGET>" not in original_content:
        return "skip", "No <TARGET> in source"

    filled = original_content.replace("<TARGET>", generated_code, 1)

    # Write filled to eval_dir
    eval_dir = verify_dir / ".eval_work_agentic"
    dst = eval_dir / local_file
    os.makedirs(str(dst.parent), exist_ok=True)
    with open(str(dst), "w", encoding="utf-8") as f:
        f.write(filled)

    run_eval_sh = verify_dir / "run_eval.sh"
    env = os.environ.copy()
    env["EVAL_DIR"] = str(eval_dir)

    try:
        result = subprocess.run(
            ["bash", str(run_eval_sh), local_folder],
            cwd=str(verify_dir), env=env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, timeout=300,
        )
        output = result.stdout + result.stderr

        for line in result.stdout.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[1] == local_folder:
                if parts[0] == "PASS":
                    return "pass", ""
                elif parts[0] == "FAIL":
                    return "fail_build", output[-500:]

        # Fallback
        for line in result.stdout.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0] in ("PASS", "FAIL"):
                if parts[0] == "PASS":
                    return "pass", ""
                else:
                    return "fail_build", output[-500:]

        return "fail_run", output[-500:]
    except subprocess.TimeoutExpired:
        return "fail_timeout", "Timed out (300s)"


def run_verification(lang: str, local_folder: str, generated_code: str,
                     candidates: Dict) -> Tuple[str, str]:
    """
    Run compilation + simulation for a single test case.
    Returns (status, error_message).
    """
    # VHDL uses central run_eval.sh
    if lang == "vhdl":
        return run_verification_vhdl(lang, local_folder, generated_code, candidates)

    config = LANG_CONFIG[lang]
    verify_dir = config["verify_dir"]
    design_dir = verify_dir / local_folder

    if not design_dir.exists():
        return "skip", f"Design directory not found: {design_dir}"

    run_sh = design_dir / "run.sh"
    if not run_sh.exists():
        return "skip", "No run.sh found"

    cand = candidates.get(local_folder)
    if not cand:
        return "skip", f"No candidate found for {local_folder}"

    # Locate the target source file
    local_file = cand.get("local_file", "")
    if local_file:
        target_file = design_dir / os.path.basename(local_file)
    else:
        target_file = None
        for ext in [config["file_ext"], ".v", ".sv", ".vhd", ".vhdl", ".cpp", ".h", ".c"]:
            for sf in design_dir.glob(f"*{ext}"):
                if "_original" not in sf.name and "tb" not in sf.name.lower():
                    target_file = sf
                    break
            if target_file:
                break

    if not target_file or not target_file.exists():
        return "skip", f"Source file not found: {local_file}"

    # Build new source
    left_context = cand.get("left_context", "")
    right_context = cand.get("right_context", "")
    new_source = left_context + generated_code + "\n" + right_context

    manifest_path = design_dir / "testbench_manifest.json"
    if lang == "systemverilog" and manifest_path.exists():
        with open(manifest_path) as f:
            manifest = json.load(f)
        write_file = design_dir / manifest["local_original_file"]
    else:
        write_file = target_file

    with open(str(write_file)) as f:
        original_content = f.read()

    try:
        with open(str(write_file), "w") as f:
            f.write(new_source)

        for pf in design_dir.glob("_patched_*"):
            pf.unlink()

        try:
            env = os.environ.copy()
            env["PATH"] = "/tmp/sbt/bin:" + env.get("PATH", "")

            p = subprocess.Popen(
                ["bash", str(run_sh)],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                cwd=str(design_dir), env=env,
            )
            try:
                out_bytes, _ = p.communicate(timeout=300)
                output = out_bytes.decode("utf-8", errors="replace")[-1500:]
            except subprocess.TimeoutExpired:
                p.kill()
                p.communicate()
                return "fail_timeout", "Timed out (300s)"

            if lang == "systemverilog":
                tb_lines = [l for l in output.split("\n") if "[TB_REAL]" in l]
                if tb_lines:
                    last_tb = tb_lines[-1]
                    if "PASS" in last_tb and "FAIL" not in last_tb:
                        return "pass", ""
                    elif "FAIL" in last_tb:
                        return "fail_run", output[-500:]
                if "Error" in output or p.returncode != 0:
                    return "fail_build", output[-500:]
                return "fail_run", output[-500:]
            else:
                if p.returncode == 0:
                    return "pass", ""
                else:
                    low = output.lower()
                    if "compil" in low or "[error]" in low or "error:" in low:
                        return "fail_build", output[-500:]
                    else:
                        return "fail_run", output[-500:]

        except subprocess.TimeoutExpired:
            return "fail_timeout", "Timed out (300s)"

    finally:
        with open(str(write_file), "w") as f:
            f.write(original_content)
        # Clean patched files
        for pf in design_dir.glob("_patched_*"):
            pf.unlink()


# ============================================================
# Extract clean code from LLM response
# ============================================================
def extract_code(response: str) -> str:
    """Extract code from LLM response, stripping markdown fences if present."""
    if not response:
        return ""

    # Remove <think>...</think> blocks
    response = re.sub(r'<think>.*?</think>', '', response, flags=re.DOTALL)

    # Try to extract from markdown code fences
    patterns = [
        r'```(?:scala|chisel|verilog|systemverilog|sv|vhdl|c|cpp|c\+\+|h)?\s*\n(.*?)```',
        r'```\s*\n(.*?)```',
    ]
    for pat in patterns:
        match = re.search(pat, response, re.DOTALL)
        if match:
            return match.group(1).strip()

    # If no fences, return as-is (trimmed)
    return response.strip()


# ============================================================
# Agentic Loop
# ============================================================
def agentic_loop(lang: str, model_name: str, max_rounds: int,
                 output_dir: Path) -> Dict:
    """
    Run the agentic compile-fix loop for one language + model.

    Round 0: Use existing single-shot results
    Round 1..N: For failed cases, call LLM with error feedback, re-verify
    """
    print(f"\n{'='*70}")
    print(f"  Agentic Compile-Fix: {lang} / {model_name} / max_rounds={max_rounds}")
    print(f"{'='*70}")

    model_fn = MODEL_FN.get(model_name)
    if not model_fn:
        print(f"  ERROR: Unknown model {model_name}")
        return {}

    # Load Round 0 results
    round0 = load_round0_results(lang, model_name)
    if not round0:
        return {}

    # Load candidates for context
    candidates = load_candidates(lang)

    # Initialize tracking
    # Each item: {round0_result, current_code, current_status, history: [{round, code, status, error}]}
    items = []
    for r0 in round0:
        item = {
            "local_folder": r0["local_folder"],
            "ground_truth": r0.get("ground_truth", ""),
            "current_code": r0["generated_code"],
            "current_status": r0["status"],
            "current_error": r0.get("error", ""),
            "em_score": r0.get("em_score", 0),
            "history": [{
                "round": 0,
                "code": r0["generated_code"],
                "status": r0["status"],
                "error": r0.get("error", ""),
            }],
        }
        items.append(item)

    # Stats per round
    round_stats = []
    pass_count = sum(1 for it in items if it["current_status"] == "pass")
    total = len(items)
    print(f"\n  Round 0 (single-shot): {pass_count}/{total} pass ({pass_count/total*100:.1f}%)")
    round_stats.append({"round": 0, "pass": pass_count, "total": total,
                        "rate": pass_count/total*100})

    # Agentic rounds
    for rnd in range(1, max_rounds + 1):
        failed_items = [it for it in items if it["current_status"] != "pass"]

        if not failed_items:
            print(f"\n  Round {rnd}: All passed! Stopping early.")
            break

        print(f"\n  Round {rnd}: Attempting to fix {len(failed_items)} failed cases...")
        fixed_this_round = 0

        for idx, item in enumerate(failed_items):
            folder = item["local_folder"]
            cand = candidates.get(folder)

            if not cand:
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: SKIP (no candidate)")
                continue

            # Build fix prompt
            prompt = FIX_PROMPT_TEMPLATE.format(
                lang=lang.replace("systemverilog", "SystemVerilog").replace("hls", "HLS C/C++"),
                left_context=cand.get("left_context", "")[-1500:],  # Last 1500 chars
                right_context=cand.get("right_context", "")[:500],   # First 500 chars
                failed_code=item["current_code"][:500],
                error_message=item["current_error"][-500:],
            )

            # Call LLM
            try:
                raw_response = model_fn(SYSTEM_PROMPT + "\n\n" + prompt)
                new_code = extract_code(raw_response)
            except Exception as e:
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: API ERROR ({e})")
                continue

            if not new_code or new_code == item["current_code"]:
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: No new code generated")
                continue

            # Re-verify
            status, error = run_verification(lang, folder, new_code, candidates)

            # Update item
            item["current_code"] = new_code
            item["current_status"] = status
            item["current_error"] = error
            item["history"].append({
                "round": rnd,
                "code": new_code[:200],  # Truncate for storage
                "status": status,
                "error": error[-200:] if error else "",
            })

            if status == "pass":
                fixed_this_round += 1
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: FIXED!")
            else:
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: Still {status}")

            time.sleep(0.3)  # Rate limit

        pass_count = sum(1 for it in items if it["current_status"] == "pass")
        print(f"\n  Round {rnd} summary: {pass_count}/{total} pass ({pass_count/total*100:.1f}%) "
              f"[+{fixed_this_round} fixed this round]")
        round_stats.append({"round": rnd, "pass": pass_count, "total": total,
                            "rate": pass_count/total*100, "fixed": fixed_this_round})

    # Compute EM / ES metrics for the final generated code
    em_scores = []
    es_scores = []
    for item in items:
        gt = item.get("ground_truth", "")
        code = item.get("current_code", "")
        if gt and code:
            em = evaluate_em(code, gt, lang)
            es = evaluate_es(code, gt, lang)
            em_scores.append(em)
            es_scores.append(es)
            item["final_em"] = em
            item["final_es"] = es

    avg_em = sum(em_scores) / len(em_scores) if em_scores else 0.0
    avg_es = sum(es_scores) / len(es_scores) if es_scores else 0.0

    # Save detailed results
    output_file = output_dir / f"agentic_{model_name}_{lang}.jsonl"
    with open(output_file, "w") as f:
        for item in items:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")

    # Save summary
    summary = {
        "lang": lang,
        "model": model_name,
        "max_rounds": max_rounds,
        "total": total,
        "round_stats": round_stats,
        "final_pass": pass_count,
        "final_rate": pass_count / total * 100,
        "improvement": round_stats[-1]["rate"] - round_stats[0]["rate"],
        "avg_em": avg_em,
        "avg_es": avg_es,
    }

    summary_file = output_dir / f"agentic_{model_name}_{lang}_summary.json"
    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2)

    # Print final summary
    print("\n  " + "-"*50)
    print("  Final Results: %s / %s" % (lang, model_name))
    print("  " + "-"*50)
    for rs in round_stats:
        marker = " <-" if rs["round"] == 0 else ""
        fixed_str = f" (+{rs.get('fixed', 0)} fixed)" if rs.get("fixed") else ""
        print(f"    Round {rs['round']}: {rs['pass']}/{rs['total']} = {rs['rate']:.1f}%{fixed_str}{marker}")
    print(f"    Improvement: +{summary['improvement']:.1f}pp")
    print(f"    EM: {avg_em:.4f}  ES: {avg_es:.4f}")
    print(f"  Results saved to {output_file.name}")

    return summary


# ============================================================
# Main
# ============================================================
def main():
    parser = argparse.ArgumentParser(
        description="Agentic Compile-Fix Workflow for HDL Code Completion"
    )
    parser.add_argument("--lang", type=str, required=True,
                        choices=["chisel", "hls", "systemverilog", "vhdl", "all"],
                        help="Language to evaluate")
    parser.add_argument("--model", type=str, required=True,
                        choices=list(MODEL_FN.keys()),
                        help="Model to use for fix attempts")
    parser.add_argument("--max-rounds", type=int, default=3,
                        help="Maximum number of fix rounds (default: 3)")
    parser.add_argument("--output-dir", type=str, default=None,
                        help="Output directory (default: ./results)")
    args = parser.parse_args()

    output_dir = Path(args.output_dir) if args.output_dir else SCRIPT_DIR / "results"
    output_dir.mkdir(parents=True, exist_ok=True)

    languages = ["chisel", "hls", "systemverilog", "vhdl"] if args.lang == "all" else [args.lang]

    all_summaries = []
    for lang in languages:
        summary = agentic_loop(lang, args.model, args.max_rounds, output_dir)
        if summary:
            all_summaries.append(summary)

    # Print overall summary
    if len(all_summaries) > 1:
        print(f"\n{'='*70}")
        print(f"  Overall Summary: {args.model} / max_rounds={args.max_rounds}")
        print(f"{'='*70}")
        print("  %-15s %10s %10s %8s" % ("Language", "Round 0", "Final", "Delta"))
        print("  " + "-"*45)

        total_r0_pass = 0
        total_final_pass = 0
        total_n = 0

        for s in all_summaries:
            r0 = s["round_stats"][0]["rate"]
            final = s["final_rate"]
            delta = s["improvement"]
            total_r0_pass += s["round_stats"][0]["pass"]
            total_final_pass += s["final_pass"]
            total_n += s["total"]
            print(f"  {s['lang']:<15s} {r0:>9.1f}% {final:>9.1f}% {delta:>+7.1f}pp")

        avg_r0 = total_r0_pass / total_n * 100
        avg_final = total_final_pass / total_n * 100
        print("  " + "-"*45)
        print(f"  {'Average':<15s} {avg_r0:>9.1f}% {avg_final:>9.1f}% {avg_final-avg_r0:>+7.1f}pp")

    # Save overall summary
    overall_path = output_dir / f"agentic_{args.model}_overall.json"
    with open(overall_path, "w") as f:
        json.dump(all_summaries, f, indent=2)
    print(f"\n  Overall summary saved to {overall_path}")


if __name__ == "__main__":
    main()
