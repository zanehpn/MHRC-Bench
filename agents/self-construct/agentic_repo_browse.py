#!/usr/bin/env python3
"""
Agentic Workflow with Repository Browsing for HDL Code Completion.

The agent can:
  1. Browse the original repository to find relevant files
  2. Read related source files for context (imports, interfaces, types)
  3. Generate code completion with rich context
  4. Compile & verify
  5. If failed, read error + browse repo again → fix → re-verify

Usage:
    python3 agentic_repo_browse.py --lang chisel --model gpt5 --max-rounds 3
    python3 agentic_repo_browse.py --lang all --model gpt5 --max-rounds 3
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
import glob
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from collections import defaultdict

# ============================================================
# Paths
# ============================================================
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = Path(os.environ.get("MHRC_EXPERIMENT_ROOT", ".")).resolve()
EVAL_BASE = REPO_ROOT / "Model_evaluation" / "No_RAG" / "function_verified" / "eval_results_fill_in"

sys.path.insert(0, str(SCRIPT_DIR.parent.parent / "Model_evaluation" / "lib_function"))
from api_function import gpt5, gemini2_5, deepseek_v3_2, grok4

MODEL_FN = {
    "gpt5": gpt5,
    "gemini2_5": gemini2_5,
    "deepseek_v3_2": deepseek_v3_2,
    "grok4": grok4,
}

LANG_CONFIG = {
    "chisel": {
        "repo_base": REPO_ROOT / "chisel",
        "verify_dir": REPO_ROOT / "chisel_dataset" / "function_verify",
        "candidates": REPO_ROOT / "chisel_dataset" / "function_verify" / "design_function_verify_candidates_50.jsonl",
        "verified_pattern": "responses_{model}_chisel_verified.jsonl",
        "extensions": [".scala"],
    },
    "hls": {
        "repo_base": REPO_ROOT / "hls",
        "verify_dir": REPO_ROOT / "hls_dataset" / "function_verify",
        "candidates": REPO_ROOT / "hls_dataset" / "function_verify" / "design_function_verify_candidates_50.jsonl",
        "verified_pattern": "responses_{model}_hls_verified.jsonl",
        "extensions": [".c", ".cpp", ".h", ".hpp"],
    },
    "systemverilog": {
        "repo_base": REPO_ROOT / "systemverilog",
        "verify_dir": REPO_ROOT / "systemverilog_dataset" / "function_verify",
        "candidates": REPO_ROOT / "systemverilog_dataset" / "function_verify" / "design_function_verify_candidates_50.jsonl",
        "verified_pattern": "responses_{model}_systemverilog_verified.jsonl",
        "extensions": [".sv", ".v", ".svh", ".vh"],
    },
    "vhdl": {
        "repo_base": REPO_ROOT / "vhdl",
        "verify_dir": REPO_ROOT / "vhdl_dataset" / "function_verify",
        "candidates": REPO_ROOT / "vhdl_dataset" / "function_verify" / "design_function_verify_candidates_50.jsonl",
        "verified_pattern": "responses_{model}_vhdl_verified.jsonl",
        "extensions": [".vhd", ".vhdl"],
    },
}


# ============================================================
# Repository Browsing Tools
# ============================================================
def browse_repo_structure(repo_path: Path, extensions: List[str], max_files: int = 50) -> str:
    """List relevant source files in the repository."""
    if not repo_path.exists():
        return "Repository not found."

    files = []
    for ext in extensions:
        for f in repo_path.rglob(f"*{ext}"):
            # Skip hidden dirs, build dirs
            rel = f.relative_to(repo_path)
            parts = rel.parts
            if any(p.startswith('.') or p in ['target', 'build', 'out', '__pycache__'] for p in parts):
                continue
            files.append(str(rel))

    files.sort()
    if len(files) > max_files:
        files = files[:max_files]
        files.append(f"... and more ({len(files)} files shown)")

    return "\n".join(files)


def read_file_content(file_path: Path, max_chars: int = 3000) -> str:
    """Read a source file, truncated to max_chars."""
    if not file_path.exists():
        return f"File not found: {file_path}"
    try:
        with open(file_path, 'r', errors='ignore') as f:
            content = f.read()
        if len(content) > max_chars:
            content = content[:max_chars] + f"\n... [truncated, total {len(content)} chars]"
        return content
    except Exception as e:
        return f"Error reading file: {e}"


def find_related_files(repo_path: Path, target_file: str, extensions: List[str],
                       snippet: str) -> List[Tuple[str, str]]:
    """
    Find files in the repo that are likely related to the target code.
    Uses: same directory, imported modules, referenced types/classes.
    Returns list of (relative_path, content) tuples.
    """
    target_full = repo_path / target_file
    if not target_full.exists():
        return []

    target_dir = target_full.parent
    related = []

    # 1. Sibling files in same directory
    for ext in extensions:
        for f in target_dir.glob(f"*{ext}"):
            if f.name == target_full.name:
                continue
            rel = str(f.relative_to(repo_path))
            content = read_file_content(f, max_chars=2000)
            related.append((rel, content))
            if len(related) >= 5:
                break
        if len(related) >= 5:
            break

    # 2. Extract imports/includes from the target file and find them
    target_content = read_file_content(target_full, max_chars=5000)

    # Find import/include patterns
    imported = set()
    # Scala/Chisel: import xxx.yyy.ClassName
    for m in re.finditer(r'import\s+([\w.]+)', target_content):
        parts = m.group(1).split('.')
        imported.add(parts[-1])  # Class name
    # C/C++: #include "xxx.h"
    for m in re.finditer(r'#include\s+"([^"]+)"', target_content):
        imported.add(m.group(1))
    # SV: `include "xxx.svh"
    for m in re.finditer(r'`include\s+"([^"]+)"', target_content):
        imported.add(m.group(1))
    # VHDL: use work.xxx
    for m in re.finditer(r'use\s+work\.(\w+)', target_content):
        imported.add(m.group(1))

    # Search for imported files in repo
    for imp in imported:
        if len(related) >= 8:
            break
        for ext in extensions:
            # Search by filename
            matches = list(repo_path.rglob(f"*{imp}*{ext}"))[:2]
            for mf in matches:
                rel = str(mf.relative_to(repo_path))
                if any(rel == r[0] for r in related):
                    continue
                content = read_file_content(mf, max_chars=1500)
                related.append((rel, content))

    return related[:8]


def find_similar_code_in_repo(repo_path: Path, extensions: List[str],
                              keywords: List[str], max_results: int = 3) -> List[Tuple[str, str]]:
    """Search repo for files containing specific keywords (e.g., from error messages)."""
    results = []
    for ext in extensions:
        for f in repo_path.rglob(f"*{ext}"):
            rel = f.relative_to(repo_path)
            if any(p.startswith('.') for p in rel.parts):
                continue
            try:
                content = f.read_text(errors='ignore')
                if any(kw in content for kw in keywords):
                    results.append((str(rel), content[:2000]))
                    if len(results) >= max_results:
                        return results
            except:
                continue
    return results


# ============================================================
# Prompt Templates
# ============================================================
AGENT_SYSTEM = """You are an expert hardware design engineer acting as a code completion agent.
You have access to the full repository and can see related source files.
Generate ONLY the missing code snippet — no markdown fences, no explanations."""

INITIAL_PROMPT = """Complete the missing code in the following {lang} file.

## File: {file_path}

## Repository structure (relevant files):
{repo_structure}

## Related files in the repository:
{related_files}

## Code before the missing part:
```
{left_context}
```

## Code after the missing part:
```
{right_context}
```

Generate ONLY the missing code. No markdown fences, no explanations."""

FIX_PROMPT = """The following {lang} code completion failed. You have access to the repository for reference.

## File: {file_path}

## Related files:
{related_files}

## Code before the missing part:
```
{left_context}
```

## Code after the missing part:
```
{right_context}
```

## Previously generated code (FAILED):
```
{failed_code}
```

## Error message:
```
{error_message}
```

{extra_context}

Generate the corrected code. Output ONLY the replacement code, nothing else."""


# ============================================================
# Verification (reuse from agentic_compile_fix.py)
# ============================================================
def run_verification(lang: str, local_folder: str, generated_code: str,
                     candidates: Dict) -> Tuple[str, str]:
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

    local_file = cand.get("local_file", "")
    if local_file:
        target_file = design_dir / os.path.basename(local_file)
    else:
        target_file = None
        for ext in config["extensions"] + [".v", ".sv", ".vhd", ".cpp", ".c", ".h"]:
            for sf in design_dir.glob(f"*{ext}"):
                if "_original" not in sf.name and "tb" not in sf.name.lower():
                    target_file = sf
                    break
            if target_file:
                break

    if not target_file or not target_file.exists():
        return "skip", f"Source file not found"

    left_context = cand.get("left_context", "")
    right_context = cand.get("right_context", "")
    new_source = left_context + generated_code + "\n" + right_context

    with open(target_file) as f:
        original_content = f.read()

    try:
        with open(target_file, "w") as f:
            f.write(new_source)

        try:
            env = os.environ.copy()
            env["PATH"] = "/tmp/sbt/bin:" + env.get("PATH", "")
            result = subprocess.run(
                ["bash", str(run_sh)],
                capture_output=True, text=True, timeout=300,
                cwd=str(design_dir), env=env,
            )
            output = (result.stdout + result.stderr)[-1500:]

            if result.returncode == 0:
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
        with open(target_file, "w") as f:
            f.write(original_content)


def extract_code(response: str) -> str:
    if not response:
        return ""
    response = re.sub(r'<think>.*?</think>', '', response, flags=re.DOTALL)
    for pat in [r'```(?:scala|chisel|verilog|systemverilog|sv|vhdl|c|cpp|c\+\+|h)?\s*\n(.*?)```',
                r'```\s*\n(.*?)```']:
        match = re.search(pat, response, re.DOTALL)
        if match:
            return match.group(1).strip()
    return response.strip()


# ============================================================
# Load data
# ============================================================
def load_round0_results(lang: str, model: str) -> List[Dict]:
    config = LANG_CONFIG[lang]
    pattern = config["verified_pattern"].format(model=model)
    verified_path = EVAL_BASE / pattern
    if not verified_path.exists():
        for f in EVAL_BASE.glob(f"responses_{model}_{lang}*_verified.jsonl"):
            verified_path = f
            break
    if not verified_path.exists():
        print(f"  WARNING: No verified file for {model}/{lang}")
        return []

    results = []
    with open(verified_path) as f:
        for line in f:
            if line.strip():
                obj = json.loads(line)
                if "local_folder" not in obj or "status" not in obj:
                    continue
                if not obj.get("status"):
                    obj["status"] = "unknown"
                results.append(obj)
    print(f"  Loaded {len(results)} Round-0 results from {verified_path.name}")
    return results


def load_candidates(lang: str) -> Dict[str, Dict]:
    config = LANG_CONFIG[lang]
    cand_path = config["candidates"]
    if not cand_path.exists():
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
# Agentic Loop with Repo Browsing
# ============================================================
def agentic_loop(lang: str, model_name: str, max_rounds: int, output_dir: Path) -> Dict:
    print(f"\n{'='*70}")
    print(f"  Agentic Repo-Browse: {lang} / {model_name} / max_rounds={max_rounds}")
    print(f"{'='*70}")

    model_fn = MODEL_FN.get(model_name)
    if not model_fn:
        print(f"  ERROR: Unknown model {model_name}")
        return {}

    config = LANG_CONFIG[lang]
    repo_base = config["repo_base"]
    extensions = config["extensions"]

    r0_results = load_round0_results(lang, model_name)
    if not r0_results:
        return {}

    candidates = load_candidates(lang)

    # Build items
    items = []
    for r0 in r0_results:
        items.append({
            "local_folder": r0["local_folder"],
            "ground_truth": r0.get("ground_truth", ""),
            "current_code": r0["generated_code"],
            "current_status": r0["status"],
            "current_error": r0.get("error", ""),
            "history": [{"round": 0, "status": r0["status"]}],
        })

    round_stats = []
    pass_count = sum(1 for it in items if it["current_status"] == "pass")
    total = len(items)
    print(f"\n  Round 0 (single-shot): {pass_count}/{total} pass ({pass_count/total*100:.1f}%)")
    round_stats.append({"round": 0, "pass": pass_count, "total": total,
                        "rate": pass_count / total * 100})

    for rnd in range(1, max_rounds + 1):
        failed_items = [it for it in items if it["current_status"] != "pass"]
        if not failed_items:
            print(f"\n  Round {rnd}: All passed!")
            break

        print(f"\n  Round {rnd}: Attempting to fix {len(failed_items)} cases (with repo browsing)...")
        fixed = 0

        for idx, item in enumerate(failed_items):
            folder = item["local_folder"]
            cand = candidates.get(folder)
            if not cand:
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: SKIP (no candidate)")
                continue

            task_id = cand.get("task_id", "")
            file_path = cand.get("path", "")
            repo_path = repo_base / task_id

            # === AGENT TOOL 1: Browse repo structure ===
            repo_struct = browse_repo_structure(repo_path, extensions, max_files=30)

            # === AGENT TOOL 2: Find related files ===
            related = find_related_files(repo_path, file_path, extensions,
                                          cand.get("groundtruth", ""))
            related_str = ""
            for rel_path, rel_content in related[:4]:
                related_str += f"\n### {rel_path}\n```\n{rel_content[:1500]}\n```\n"

            if not related_str:
                related_str = "(no related files found)"

            left_ctx = cand.get("left_context", "")[-2000:]
            right_ctx = cand.get("right_context", "")[:800:]

            if rnd == 1 and item["history"][0]["status"] != "pass":
                # First fix attempt: use rich repo context
                extra_ctx = ""
                # If there's an error, also search repo for relevant patterns
                if item["current_error"]:
                    # Extract key identifiers from error
                    error_keywords = re.findall(r'\b[A-Z]\w+\b', item["current_error"])[:3]
                    if error_keywords:
                        similar = find_similar_code_in_repo(
                            repo_path, extensions, error_keywords, max_results=2)
                        if similar:
                            extra_ctx = "\n## Similar code found in repo:\n"
                            for sp, sc in similar:
                                extra_ctx += f"### {sp}\n```\n{sc[:1000]}\n```\n"

                prompt = FIX_PROMPT.format(
                    lang=lang,
                    file_path=file_path,
                    related_files=related_str,
                    left_context=left_ctx,
                    right_context=right_ctx,
                    failed_code=item["current_code"][:500],
                    error_message=item["current_error"][-500:],
                    extra_context=extra_ctx,
                )
            else:
                # Subsequent rounds
                prompt = FIX_PROMPT.format(
                    lang=lang,
                    file_path=file_path,
                    related_files=related_str,
                    left_context=left_ctx,
                    right_context=right_ctx,
                    failed_code=item["current_code"][:500],
                    error_message=item["current_error"][-500:],
                    extra_context="",
                )

            # === AGENT ACTION: Call LLM ===
            try:
                raw = model_fn(AGENT_SYSTEM + "\n\n" + prompt)
                new_code = extract_code(raw)
            except Exception as e:
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: API ERROR ({e})")
                continue

            if not new_code or new_code == item["current_code"]:
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: No new code")
                continue

            # === AGENT ACTION: Verify ===
            status, error = run_verification(lang, folder, new_code, candidates)

            item["current_code"] = new_code
            item["current_status"] = status
            item["current_error"] = error
            item["history"].append({"round": rnd, "status": status})

            if status == "pass":
                fixed += 1
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: FIXED!")
            else:
                print(f"    [{idx+1}/{len(failed_items)}] {folder}: Still {status}")

            time.sleep(0.3)

        pass_count = sum(1 for it in items if it["current_status"] == "pass")
        print(f"\n  Round {rnd} summary: {pass_count}/{total} pass ({pass_count/total*100:.1f}%) "
              f"[+{fixed} fixed]")
        round_stats.append({"round": rnd, "pass": pass_count, "total": total,
                            "rate": pass_count / total * 100, "fixed": fixed})

    # Save results
    output_file = output_dir / f"agentic_repo_{model_name}_{lang}.jsonl"
    with open(output_file, "w") as f:
        for item in items:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")

    summary = {
        "lang": lang, "model": model_name, "max_rounds": max_rounds,
        "total": total, "round_stats": round_stats,
        "final_pass": pass_count,
        "final_rate": pass_count / total * 100,
        "improvement": round_stats[-1]["rate"] - round_stats[0]["rate"],
    }

    summary_file = output_dir / f"agentic_repo_{model_name}_{lang}_summary.json"
    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2)

    print(f"\n  {'─'*50}")
    print(f"  Final: {lang} / {model_name}")
    print(f"  {'─'*50}")
    for rs in round_stats:
        fx = f" (+{rs.get('fixed',0)} fixed)" if rs.get("fixed") else ""
        print(f"    Round {rs['round']}: {rs['pass']}/{rs['total']} = {rs['rate']:.1f}%{fx}")
    print(f"    Improvement: +{summary['improvement']:.1f}pp")

    return summary


def main():
    parser = argparse.ArgumentParser(description="Agentic Workflow with Repository Browsing")
    parser.add_argument("--lang", required=True, choices=["chisel", "hls", "systemverilog", "vhdl", "all"])
    parser.add_argument("--model", required=True, choices=list(MODEL_FN.keys()))
    parser.add_argument("--max-rounds", type=int, default=3)
    parser.add_argument("--output-dir", type=str, required=True)
    args = parser.parse_args()

    output_dir = Path(args.output_dir) if args.output_dir else SCRIPT_DIR / "results"
    output_dir.mkdir(parents=True, exist_ok=True)

    languages = ["chisel", "hls", "systemverilog", "vhdl"] if args.lang == "all" else [args.lang]

    all_summaries = []
    for lang in languages:
        summary = agentic_loop(lang, args.model, args.max_rounds, output_dir)
        if summary:
            all_summaries.append(summary)

    if len(all_summaries) > 1:
        print(f"\n{'='*70}")
        print(f"  Overall: {args.model}")
        print(f"{'='*70}")
        print(f"  {'Language':<15s} {'Round 0':>10s} {'Final':>10s} {'Δ':>8s}")
        print(f"  {'─'*45}")
        t_r0 = t_final = t_n = 0
        for s in all_summaries:
            r0 = s["round_stats"][0]["rate"]
            final = s["final_rate"]
            t_r0 += s["round_stats"][0]["pass"]
            t_final += s["final_pass"]
            t_n += s["total"]
            print(f"  {s['lang']:<15s} {r0:>9.1f}% {final:>9.1f}% {final-r0:>+7.1f}pp")
        print(f"  {'─'*45}")
        print(f"  {'Average':<15s} {t_r0/t_n*100:>9.1f}% {t_final/t_n*100:>9.1f}% {(t_final-t_r0)/t_n*100:>+7.1f}pp")


if __name__ == "__main__":
    main()
