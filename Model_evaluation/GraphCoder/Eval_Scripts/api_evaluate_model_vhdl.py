#!/usr/bin/env python3
"""
Repofuse response generator:
- Input JSONL entries: {"task_id": ..., "prompt": ..., "ground_truth": ...}
  where prompt contains markers like <FILE:relative/path/to/file>
- Calls LLM once per entry
- Writes output JSONL lines:
  {"task_id": ..., "file_path": ..., "response": ..., "ground_truth": ...}
  to <output_jsonl>.<model_name>.jsonl

Enhancements:
1) Progress bar via tqdm
2) Runs a small unit API test before processing the dataset to confirm each API works
3) Runs multiple models sequentially
"""

import json
import re
import sys
import time
import traceback
from typing import Callable, Dict, List, Tuple

from tqdm import tqdm

# Import model functions
try:
    from api_function import gpt5, deepseek_v3, grok4, gemini2_5
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure api_function.py is in the same directory and exports: deepseek_v3, grok4, gemini2_5.")
    sys.exit(1)

FILE_MARKER_RE = re.compile(r"<FILE:([^>]+)>")


def load_jsonl(path: str) -> List[Dict]:
    items: List[Dict] = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line_no, line in enumerate(f, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    items.append(json.loads(line))
                except json.JSONDecodeError as je:
                    print(f"[WARN] Skipping invalid JSON on line {line_no}: {je}")
        print(f"Loaded {len(items)} entries from {path}")
    except Exception as e:
        print(f"[ERROR] Failed to read {path}: {e}")
    return items


def extract_file_paths(prompt: str) -> List[str]:
    """Returns a list of relative file paths found in <FILE:...> markers."""
    if not prompt:
        return []
    return [m.strip() for m in FILE_MARKER_RE.findall(prompt) if m.strip()]


def safe_llm_call(model_func: Callable[[str], str], prompt: str, task_id: str, model_name: str) -> str:
    """
    Calls the model and returns response as a string (or "" on failure).
    """
    start = time.time()
    try:
        resp = model_func(prompt)
        if resp is None:
            resp = ""
        elif not isinstance(resp, str):
            resp = str(resp)
        dur = time.time() - start
        print(f"[LLM] model={model_name} task={task_id} took {dur:.2f}s")
        return resp
    except Exception as e:
        dur = time.time() - start
        print(f"[ERROR] LLM call failed model={model_name} task={task_id} after {dur:.2f}s: {e}")
        traceback.print_exc()
        return ""


def run_unit_api_test(model_func: Callable[[str], str], model_name: str) -> bool:
    """
    Runs a lightweight sanity-check call to confirm the API is working before
    processing the dataset.

    Returns True if it looks OK, else False.
    """
    test_prompt = "Reply with exactly: OK"
    print(f"Running unit API test for {model_name}...")
    resp = safe_llm_call(model_func, test_prompt, task_id="UNIT_TEST", model_name=model_name)
    resp_norm = (resp or "").strip()

    # Accept a couple of common variants, but be strict enough to catch failures.
    if resp_norm == "OK" or resp_norm.startswith("OK"):
        print(f"[UNIT_TEST] {model_name} PASS (response: {resp_norm[:80]!r})")
        return True

    print(f"[UNIT_TEST] {model_name} FAIL (response: {resp_norm[:200]!r})")
    print(f"Refusing to run on the dataset because the API test for {model_name} did not pass.")
    return False


def process_model(
    model_name: str,
    model_func: Callable[[str], str],
    data: List[Dict],
    output_base: str,
) -> Tuple[str, int]:
    """
    Processes the dataset for a single model and writes to output_base.<model_name>.jsonl.
    Returns (output_path, written_lines).
    """
    output_path = f"{output_base}_{model_name}.jsonl"

    # Start fresh
    try:
        open(output_path, "w", encoding="utf-8").close()
    except Exception as e:
        print(f"[WARN] Could not truncate output file {output_path}: {e}")

    written = 0
    with open(output_path, "a", encoding="utf-8") as out_f:
        for i, entry in enumerate(tqdm(data, desc=f"Processing ({model_name})", unit="entry")):
            task_id = entry.get("task_id", f"entry_{i}")
            prompt = entry.get("prompt", "")
            ground_truth = entry.get("ground_truth", entry.get("groundtruth", ""))  # fallback

            if not prompt:
                tqdm.write(f"[WARN] Missing prompt for {task_id}; skipping.")
                continue

            file_paths = extract_file_paths(prompt)
            if not file_paths:
                file_paths = [""]  # still write one record even if missing marker

            response = safe_llm_call(model_func, prompt, task_id, model_name=model_name)

            # Write one record per file_path marker found
            for fp in file_paths:
                rec = {
                    "task_id": task_id,
                    "file_path": fp,
                    "response": response,
                    "ground_truth": ground_truth,
                    "model": model_name,  # optional but handy
                }
                out_f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                written += 1

    return output_path, written


def main():
    input_jsonl = "/home/zqy/LLM4CHIP/Multi-hdl-language-repo/Model_evaluation/GraphCoder/api_input/vhdl_fim.coarse2fine.10.0.prompts.fim.jsonl"
    output_jsonl = "graphcoder_vhdl_fim.jsonl"

    # Models to run sequentially (name, function)
    models: List[Tuple[str, Callable[[str], str]]] = [
        ("gpt5", gpt5),
        ("deepseek_v3", deepseek_v3),   
        ("gemini_2.5", gemini2_5),
        ("grok4", grok4),
    ]

    data = load_jsonl(input_jsonl)
    if not data:
        print("No input loaded; exiting.")
        return

    # Run each model sequentially
    for model_name, model_func in models:
        if not run_unit_api_test(model_func, model_name=model_name):
            # Stop immediately (or change to `continue` if you prefer skipping failing models)
            sys.exit(2)

        out_path, written = process_model(model_name, model_func, data, output_base=output_jsonl)
        print(f"[DONE] model={model_name} wrote {written} lines to {out_path}")

    print("All models complete.")


if __name__ == "__main__":
    main()
