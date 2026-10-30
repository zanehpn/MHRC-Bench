#!/usr/bin/env python3
"""
Run aider agent for HDL code completion (<TARGET> fill-in) across
multiple languages and models (gpt-5, gemini-2.5-pro).

For each task the agent:
  1. Reads the file containing the <TARGET> placeholder
  2. Browses the surrounding repository for context (imports, related files)
  3. Asks aider to replace <TARGET> with the correct code
  4. Extracts the generated completion and saves it

Usage:
    python3 run_aider_completion.py --lang chisel --model gpt-5
    python3 run_aider_completion.py --lang all --model all
    python3 run_aider_completion.py --lang chisel --model gpt-5 --start-idx 10 --end-idx 20
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# ============================================================
# Configuration
# ============================================================
BASE_DIR = Path(os.environ.get("PROJECT_ROOT", ".")).resolve()
OUTPUT_ROOT = BASE_DIR / "Model_evaluation" / "agentic_workflow"

API_KEY = os.environ.get("OPENAI_API_KEY", "")
API_BASE = os.environ.get("OPENAI_API_BASE", "https://api.openai.com/v1")

MODELS = {
    "gpt-5": "gpt-5",
    "gemini-2.5-pro": "gemini-2.5-pro",
}

# Model-specific API config overrides (default uses API_KEY + API_BASE)
# Example for local models:
#   "local-model": {"api_key": "dummy", "api_base": "http://localhost:8001/v1",
#                    "metadata_file": "path/to/metadata.json", "edit_format": "diff"}
MODEL_API_OVERRIDE = {}

LANG_CONFIG = {
    "chisel": {
        "jsonl": BASE_DIR / "chisel_dataset" / "test_no_target.jsonl",
        "repo": BASE_DIR / "chisel",
        "extensions": [".scala"],
    },
    "hls": {
        "jsonl": BASE_DIR / "hls_dataset" / "test_no_target.jsonl",
        "repo": BASE_DIR / "hls",
        "extensions": [".c", ".cpp", ".h", ".hpp"],
    },
    "systemverilog": {
        "jsonl": BASE_DIR / "systemverilog_dataset" / "test_no_target.jsonl",
        "repo": BASE_DIR / "systemverilog",
        "extensions": [".sv", ".v", ".svh", ".vh"],
    },
    "vhdl": {
        "jsonl": BASE_DIR / "vhdl_dataset" / "test_no_target.jsonl",
        "repo": BASE_DIR / "vhdl",
        "extensions": [".vhd", ".vhdl"],
    },
}

TARGET_MARKER = "<TARGET>"


# ============================================================
# Utility
# ============================================================
def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def write_text(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def run_cmd(cmd, *, cwd=None, env=None, timeout=None, check=False):
    proc = subprocess.run(
        cmd, cwd=cwd, env=env,
        capture_output=True, text=True, timeout=timeout,
    )
    if check and proc.returncode != 0:
        raise RuntimeError(
            f"Command failed rc={proc.returncode}: {' '.join(cmd)}\n"
            f"stderr: {proc.stderr[-2000:]}"
        )
    return proc


# ============================================================
# Context extraction helpers
# ============================================================
def get_file_context(file_path: Path, cursor_line: int, context_lines: int = 50) -> Tuple[str, str]:
    """Read the file and return (lines_before_TARGET, lines_after_TARGET)."""
    if not file_path.exists():
        return "", ""
    lines = file_path.read_text(errors="replace").splitlines(keepends=True)
    # Find the <TARGET> line
    target_idx = None
    for i, line in enumerate(lines):
        if TARGET_MARKER in line:
            target_idx = i
            break
    if target_idx is None:
        # Fallback: use cursor_line
        target_idx = cursor_line - 1

    start = max(0, target_idx - context_lines)
    end = min(len(lines), target_idx + 1 + context_lines)

    before = "".join(lines[start:target_idx])
    after = "".join(lines[target_idx + 1:end])
    return before, after


def find_related_files(repo_path: Path, target_file: str,
                       extensions: List[str]) -> List[str]:
    """Find files related to the target: siblings + imported files."""
    full_path = repo_path / target_file
    if not full_path.exists():
        return []

    related = []
    target_dir = full_path.parent

    # 1. Sibling files in same directory
    for ext in extensions:
        for f in target_dir.glob(f"*{ext}"):
            if f.name == full_path.name:
                continue
            rel = str(f.relative_to(repo_path))
            if rel not in related:
                related.append(rel)
            if len(related) >= 5:
                break
        if len(related) >= 5:
            break

    # 2. Parse imports from target file
    content = full_path.read_text(errors="replace")
    imported = set()
    # Scala/Chisel imports
    for m in re.finditer(r'import\s+([\w.]+)', content):
        parts = m.group(1).split('.')
        imported.add(parts[-1])
    # C/C++ includes
    for m in re.finditer(r'#include\s+"([^"]+)"', content):
        imported.add(Path(m.group(1)).stem)
    # SV includes
    for m in re.finditer(r'`include\s+"([^"]+)"', content):
        imported.add(Path(m.group(1)).stem)
    # VHDL use
    for m in re.finditer(r'use\s+work\.(\w+)', content):
        imported.add(m.group(1))

    for imp in imported:
        if len(related) >= 10:
            break
        # Skip empty, wildcard, or single-char imports (e.g. Scala's "_")
        if not imp or len(imp) <= 1:
            continue
        for ext in extensions:
            for mf in repo_path.rglob(f"*{imp}*{ext}"):
                rel = str(mf.relative_to(repo_path))
                if rel not in related and rel != target_file:
                    related.append(rel)
                if len(related) >= 10:
                    break

    return related[:10]


def build_read_only_context(repo_path: Path, related_files: List[str],
                            max_chars_per_file: int = 2000) -> str:
    """Build a text summary of related files for the prompt."""
    parts = []
    for rf in related_files[:5]:
        full = repo_path / rf
        if not full.exists():
            continue
        content = full.read_text(errors="replace")
        if len(content) > max_chars_per_file:
            content = content[:max_chars_per_file] + "\n... [truncated]"
        parts.append(f"### {rf}\n```\n{content}\n```")
    return "\n\n".join(parts) if parts else "(no related files found)"


# ============================================================
# Aider invocation
# ============================================================
def make_aider_prompt(lang: str, file_path: str, before_ctx: str,
                      after_ctx: str, related_ctx: str,
                      target_nlines: int, target_type: str,
                      ctx_before_limit: int = 2000,
                      ctx_after_limit: int = 1000) -> str:
    return textwrap.dedent(f"""\
        You are completing missing code in a {lang} hardware design file.

        The file `{file_path}` contains a placeholder `<TARGET>` that must be replaced
        with the correct code.

        ## Task
        Replace the line containing `<TARGET>` with the correct {target_type} code
        ({target_nlines} line(s) expected).

        ## Context before <TARGET>:
        ```
        {before_ctx[-ctx_before_limit:]}
        ```

        ## Context after <TARGET>:
        ```
        {after_ctx[:ctx_after_limit]}
        ```

        ## Related files in the repository (read-only reference):
        {related_ctx}

        ## Instructions
        - Replace `<TARGET>` with the correct code that fits the surrounding context.
        - Use the related files for understanding types, interfaces, and patterns.
        - The replacement should be syntactically and semantically correct.
        - Do NOT add any extra comments or explanations in the code.
        - Make minimal changes — only replace the <TARGET> line(s).
    """)


def call_api_directly(model_id: str, model_name: str, prompt: str,
                      task_dir: str) -> str:
    """Call local vLLM API directly for small-context models."""
    import requests as _requests

    override = MODEL_API_OVERRIDE.get(model_name, {})
    api_key = override.get("api_key", API_KEY)
    api_base = override.get("api_base", API_BASE)

    url = f"{api_base}/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    # For base/fine-tuned models: use a concise prompt to avoid echo
    concise_prompt = (
        "Complete the missing code marked as <TARGET>. "
        "Output ONLY the replacement code, nothing else.\n\n" + prompt
    )
    payload = {
        "model": model_id,
        "messages": [
            {"role": "user", "content": concise_prompt},
        ],
        "max_tokens": 512,
        "temperature": 0.2,
    }

    try:
        resp = _requests.post(url, headers=headers, json=payload, timeout=120)
        resp.raise_for_status()
        raw = resp.json()["choices"][0]["message"]["content"]
        write_text(os.path.join(task_dir, "api_response.txt"), raw)
        # Clean up: strip markdown fences if present
        code = re.sub(r'<think>.*?</think>', '', raw, flags=re.DOTALL)
        for pat in [r'```(?:\w+)?\s*\n(.*?)```', r'```\s*\n(.*?)```']:
            match = re.search(pat, code, re.DOTALL)
            if match:
                return match.group(1).strip()
        return code.strip()
    except Exception as e:
        write_text(os.path.join(task_dir, "api_error.txt"), str(e))
        return ""


def run_aider_once(
    work_dir: str,
    target_file: str,
    read_files: List[str],
    prompt_path: str,
    log_dir: str,
    model: str,
) -> Dict:
    """Run aider once on a single file.

    Sandboxing:
      - cwd is set to work_dir (isolated temp copy, no ground-truth files)
      - --no-git prevents access to any git history
      - --no-suggest-shell-commands prevents LLM from running arbitrary shell
      - --map-tokens 0 prevents repo-map scanning outside work_dir
      - Only files explicitly copied into work_dir are accessible
    """
    override = MODEL_API_OVERRIDE.get(model, {})
    api_key = override.get("api_key", API_KEY)
    api_base = override.get("api_base", API_BASE)

    env = os.environ.copy()
    env["OPENAI_API_KEY"] = api_key
    env["OPENAI_API_BASE"] = api_base

    cmd = [
        "aider",
        "--model", f"openai/{model}",
        "--openai-api-key", api_key,
        "--openai-api-base", api_base,
        "--yes-always",
        "--no-auto-commits",
        "--no-dirty-commits",
        "--no-check-update",
        "--no-show-model-warnings",
        "--no-pretty",
        "--no-stream",
        "--no-detect-urls",
        "--no-git",
        "--no-suggest-shell-commands",
        "--map-tokens", "0",
        "--message-file", prompt_path,
    ]

    # For local/small models, use diff edit format (easier than whole-file)
    edit_format = override.get("edit_format")
    if edit_format:
        cmd.extend(["--edit-format", edit_format])

    # Add model metadata file if specified (for custom/local models)
    metadata_file = override.get("metadata_file")
    if metadata_file:
        cmd.extend(["--model-metadata-file", metadata_file])

    # Add read-only files
    for rf in read_files[:5]:
        cmd.extend(["--read", rf])

    # The target file aider can edit
    cmd.append(target_file)

    log_path = os.path.join(log_dir, "aider_command.log")
    try:
        proc = run_cmd(cmd, cwd=work_dir, env=env, timeout=300)
        write_text(
            log_path,
            f"$ {' '.join(cmd)}\n\n[stdout]\n{proc.stdout[-4000:]}\n\n"
            f"[stderr]\n{proc.stderr[-4000:]}\n",
        )
        return {
            "returncode": proc.returncode,
            "stdout_tail": proc.stdout[-2000:],
            "stderr_tail": proc.stderr[-2000:],
        }
    except subprocess.TimeoutExpired:
        write_text(log_path, "TIMEOUT after 300s\n")
        return {"returncode": -1, "stdout_tail": "", "stderr_tail": "TIMEOUT"}
    except Exception as e:
        write_text(log_path, f"EXCEPTION: {e}\n")
        return {"returncode": -1, "stdout_tail": "", "stderr_tail": str(e)}


# ============================================================
# Extract completion from the edited file
# ============================================================
def extract_completion(original_lines: List[str], edited_lines: List[str],
                       target_line_idx: int) -> str:
    """
    Compare original (with <TARGET>) and edited file to extract the generated code.
    """
    # If file still has <TARGET>, aider failed to edit
    edited_text = "".join(edited_lines)
    if TARGET_MARKER in edited_text:
        return ""

    # Find what replaced the <TARGET> line
    # The original file had <TARGET> at target_line_idx.
    # Everything before and after should be mostly the same.
    # Extract the difference.
    before_original = original_lines[:target_line_idx]
    after_original = original_lines[target_line_idx + 1:]

    # Find where the "after" part starts in the edited file
    # Match from the end backwards
    after_text = "".join(after_original).strip()

    # Simple approach: find the first line after target_line_idx that matches
    # the first line of after_original
    if after_original:
        first_after = after_original[0].strip()
        match_idx = None
        for i in range(target_line_idx, len(edited_lines)):
            if edited_lines[i].strip() == first_after:
                match_idx = i
                break
        if match_idx is not None:
            completion_lines = edited_lines[target_line_idx:match_idx]
            return "".join(completion_lines)

    # Fallback: compare line counts
    diff = len(edited_lines) - len(original_lines)
    n_new = 1 + diff  # original had 1 TARGET line
    if n_new > 0:
        completion_lines = edited_lines[target_line_idx:target_line_idx + n_new]
        return "".join(completion_lines)

    return ""


# ============================================================
# Main processing loop
# ============================================================
def process_task(
    task: Dict,
    lang: str,
    model_name: str,
    model_id: str,
    config: Dict,
    task_dir: str,
) -> Dict:
    """Process a single completion task."""
    repo_path = config["repo"]
    file_rel = task["file"]
    cursor_line = task["cursor_line"]
    target_nlines = task["target_nlines"]
    target_type = task["target_type"]

    source_file = repo_path / file_rel
    if not source_file.exists():
        return {
            "file": file_rel,
            "status": "skip",
            "error": f"File not found: {source_file}",
            "generated": "",
        }

    ensure_dir(task_dir)

    # Read original file (contains <TARGET>)
    original_text = source_file.read_text(errors="replace")
    original_lines = original_text.splitlines(keepends=True)

    # Find <TARGET> line index
    target_idx = None
    for i, line in enumerate(original_lines):
        if TARGET_MARKER in line:
            target_idx = i
            break
    if target_idx is None:
        return {
            "file": file_rel,
            "status": "skip",
            "error": "No <TARGET> marker found in file",
            "generated": "",
        }

    # Get context
    before_ctx, after_ctx = get_file_context(source_file, cursor_line)
    related_files = find_related_files(repo_path, file_rel, config["extensions"])
    related_ctx = build_read_only_context(repo_path, related_files)

    # Create temp work directory with the target file
    work_dir = os.path.join(task_dir, "work")
    ensure_dir(work_dir)

    # Copy target file preserving directory structure
    work_file = os.path.join(work_dir, file_rel)
    ensure_dir(os.path.dirname(work_file))
    shutil.copy2(str(source_file), work_file)

    # For smaller-context models (e.g. hdl-lora 32K), reduce context to fit
    is_small_ctx = model_name in ("hdl-lora",)
    max_read_files = 2 if is_small_ctx else 5
    ctx_before_limit = 1200 if is_small_ctx else 2000
    ctx_after_limit = 600 if is_small_ctx else 1000

    # Copy related files as read-only references
    read_file_paths = []
    for rf in related_files[:max_read_files]:
        src = repo_path / rf
        if src.exists():
            dst = os.path.join(work_dir, rf)
            ensure_dir(os.path.dirname(dst))
            shutil.copy2(str(src), dst)
            read_file_paths.append(rf)

    # Build prompt
    prompt = make_aider_prompt(
        lang=lang,
        file_path=file_rel,
        before_ctx=before_ctx,
        after_ctx=after_ctx,
        related_ctx=related_ctx if not is_small_ctx else "(skipped for context limit)",
        target_nlines=target_nlines,
        target_type=target_type,
        ctx_before_limit=ctx_before_limit,
        ctx_after_limit=ctx_after_limit,
    )
    prompt_path = os.path.join(task_dir, "prompt.txt")
    write_text(prompt_path, prompt)

    if False:
        # Reserved: direct API fallback (disabled — all models use aider agent)
        completion = call_api_directly(model_id, model_name, prompt, task_dir)
    else:
        # Run aider
        aider_result = run_aider_once(
            work_dir=work_dir,
            target_file=file_rel,
            read_files=read_file_paths,
            prompt_path=prompt_path,
            log_dir=task_dir,
            model=model_id,
        )

        # Extract completion
        edited_file = os.path.join(work_dir, file_rel)
        if os.path.exists(edited_file):
            edited_text = read_text(edited_file)
            edited_lines = edited_text.splitlines(keepends=True)
            completion = extract_completion(original_lines, edited_lines, target_idx)
        else:
            completion = ""

    # Clean up work directory to save space
    shutil.rmtree(work_dir, ignore_errors=True)

    return {
        "file": file_rel,
        "cursor_line": cursor_line,
        "target_nlines": target_nlines,
        "target_type": target_type,
        "status": "done" if completion else "empty",
        "generated": completion,
    }


def run_language_model(lang: str, model_name: str, model_id: str,
                       start_idx: int, end_idx: Optional[int],
                       output_dir: Path) -> Dict:
    """Run all tasks for a given language + model combination."""
    config = LANG_CONFIG[lang]
    jsonl_path = config["jsonl"]

    print(f"\n{'='*70}")
    print(f"  Language: {lang} | Model: {model_name}")
    print(f"  JSONL: {jsonl_path}")
    print(f"  Repo:  {config['repo']}")
    print(f"{'='*70}")

    # Load tasks
    tasks = []
    with open(jsonl_path) as f:
        for line in f:
            if line.strip():
                tasks.append(json.loads(line))

    if end_idx is None:
        end_idx = len(tasks)
    tasks = tasks[start_idx:end_idx]
    print(f"  Processing tasks [{start_idx}:{end_idx}], total: {len(tasks)}")

    # Output paths
    lang_model_dir = output_dir / lang / model_name
    ensure_dir(str(lang_model_dir))

    results_file = lang_model_dir / "results.jsonl"
    # Load existing results to support resume
    existing = set()
    if results_file.exists():
        with open(results_file) as f:
            for line in f:
                if line.strip():
                    obj = json.loads(line)
                    existing.add(obj.get("file", ""))
        print(f"  Resuming: {len(existing)} tasks already completed")

    stats = {"done": 0, "empty": 0, "skip": 0, "total": len(tasks)}

    for idx, task in enumerate(tasks):
        file_rel = task["file"]
        global_idx = start_idx + idx

        if file_rel in existing:
            stats["done"] += 1
            continue

        task_dir = str(lang_model_dir / "tasks" / f"task_{global_idx:04d}")

        print(f"  [{idx+1}/{len(tasks)}] {file_rel} ...", end=" ", flush=True)
        try:
            result = process_task(
                task=task,
                lang=lang,
                model_name=model_name,
                model_id=model_id,
                config=config,
                task_dir=task_dir,
            )
        except Exception as e:
            result = {
                "file": file_rel,
                "status": "error",
                "error": str(e),
                "generated": "",
            }

        # Append result
        with open(results_file, "a") as f:
            f.write(json.dumps(result, ensure_ascii=False) + "\n")

        stats[result.get("status", "error")] = stats.get(result.get("status", "error"), 0) + 1
        print(result.get("status", "error"))

        # Rate limit
        time.sleep(0.5)

    # Write summary
    summary = {
        "lang": lang,
        "model": model_name,
        "stats": stats,
        "timestamp": datetime.now().isoformat(),
    }
    write_text(
        str(lang_model_dir / "summary.json"),
        json.dumps(summary, indent=2),
    )
    print(f"\n  Summary: {json.dumps(stats)}")
    print(f"  Results: {results_file}")
    return summary


def main():
    parser = argparse.ArgumentParser(
        description="Run aider agent for HDL code completion (<TARGET> fill-in)"
    )
    parser.add_argument(
        "--lang", required=True,
        choices=list(LANG_CONFIG.keys()) + ["all"],
        help="Language to process",
    )
    parser.add_argument(
        "--model", required=True,
        choices=list(MODELS.keys()) + ["all"],
        help="Model to use",
    )
    parser.add_argument("--start-idx", type=int, default=0, help="Start task index")
    parser.add_argument("--end-idx", type=int, default=None, help="End task index")
    parser.add_argument(
        "--output-dir", type=str,
        required=True,
        help="Output directory",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    ensure_dir(str(output_dir))

    languages = list(LANG_CONFIG.keys()) if args.lang == "all" else [args.lang]
    models = list(MODELS.items()) if args.model == "all" else [(args.model, MODELS[args.model])]

    all_summaries = []
    for lang in languages:
        for model_name, model_id in models:
            summary = run_language_model(
                lang=lang,
                model_name=model_name,
                model_id=model_id,
                start_idx=args.start_idx,
                end_idx=args.end_idx,
                output_dir=output_dir,
            )
            all_summaries.append(summary)

    # Print overall summary
    if len(all_summaries) > 1:
        print(f"\n{'='*70}")
        print(f"  Overall Summary")
        print(f"{'='*70}")
        for s in all_summaries:
            st = s.get("stats", {})
            total = st.get("total", 0)
            done = st.get("done", 0)
            print(f"  {s['lang']:>15s} / {s['model']:<20s}: "
                  f"done={done} total={total}")


if __name__ == "__main__":
    main()
