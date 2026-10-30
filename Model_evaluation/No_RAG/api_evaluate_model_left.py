#!/usr/bin/env python3
"""
Evaluation script for various API functions (DeepSeek-R1, GPT-4o, Qwen32B, etc.)
Evaluates generated code against ground truth using exact match, edit similarity,
and BLEU metrics.

- Supports multiple models configured from api_function.py
- Supports multiple languages: hls, systemverilog, vhdl, chisel
- Test file path & output file paths all include language suffix.

NEW:
- Resume / checkpoint support:
  * --resume : continue from existing responses_<model>_<language>.jsonl
  * --resume_key : how to identify a sample uniquely (recommended: task_id_path)
  * Skips already-evaluated samples without re-running.
"""

import json
import os
import time
import re
import sys
import traceback
import argparse
from typing import Dict, List, Tuple, Optional

from tqdm import tqdm
from transformers import AutoTokenizer

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
LIB_DIR = os.path.join(PARENT_DIR, "lib_function")

if LIB_DIR not in sys.path:
    sys.path.append(LIB_DIR)

# ---- Tokenizer + prompt truncation helpers ----
_TOKENIZER_CACHE: Dict[str, AutoTokenizer] = {}



from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from release_io import load_test_data, item_id
def get_tokenizer(name: str):
    """
    Lazy-load and cache tokenizer by name/path.
    """
    if name not in _TOKENIZER_CACHE:
        _TOKENIZER_CACHE[name] = AutoTokenizer.from_pretrained(name)
    return _TOKENIZER_CACHE[name]


# Import model functions + evaluators
try:
    from api_function import (
        deepseek_v3,
        deepseek_v3_2,
        deepseek_R1_mcts,
        gpt5,
        gpt4o,
        Qwen32B,
        claude_sonnet_4_5_thinking,
        gemini2_5,
        grok4,
    )
    from exact_match import evaluate_em, evaluate_es
    from codebleu import evaluate_bleu  # BLEU
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure api_function.py, exact_match.py, and codebleu.py are in the same directory")
    raise SystemExit(1)

LINE_PROMPT_PREFIX = """You are a precise code-completion model completing a repository blank completion task. Input: a repository concatenation where each file of the repo is wrapped in `--- FILE: <repo_name>/<rel/path/to/file> (BEGIN) ---
<file content...>
--- FILE: <repo name>/<rel/path/to/file> (END) ---
`. Some lines have been replaced by the exact token `<TARGET>`. Your task: reconstruct **only** the missing code span(s), using the repository context. Note that for certain large repositories, functions of lesser importance were removed of their implementation, and only the signature/documentation were kept for the sake of simplicity.

OUTPUT: the reconstructed line(s) (and nothing else)."""

# ---- Few-shot examples (one per language, from training sets) ----
FEW_SHOT_EXAMPLES = {
    "systemverilog": {
        "left": "// Code your testbench here\n// or browse Examples\n",
        "gt": "`include \"params_pkg.sv\"",
    },
    "hls": {
        "left": "#pragma once\n#include <cstdint>\n\n// Shorthand aliases\n",
        "gt": "using byte = uint8_t;",
    },
    "vhdl": {
        "left": "library IEEE;\nuse IEEE.STD_LOGIC_1164.ALL;\n\npackage hash_pkg is\n",
        "gt": "  constant key_len : integer := 128;",
    },
    "chisel": {
        "left": "package xiangshan.backend.fu\n\nobject VsetRef{\n  def VLEN: Int = 128\n",
        "gt": "  def XLEN: Int = 64",
    },
}

COT_INSTRUCTION = (
    "Think step by step. First, reason about what the missing code should be based on "
    "the surrounding context (language conventions, imports, variable names, types, etc.). "
    "Then, on a new line, output your final answer prefixed exactly with 'ANSWER: ' followed "
    "by the reconstructed line(s) and nothing else."
)


def build_prompt_mode_prefix(language: str, prompt_mode: str) -> str:
    """Return extra text to prepend to the system prefix based on prompt_mode."""
    if prompt_mode == "zero-shot":
        return ""
    if prompt_mode == "few-shot":
        ex = FEW_SHOT_EXAMPLES.get(language)
        if not ex:
            return ""
        return (
            "\nHere is an example of the task:\n\n"
            "Input:\n"
            f"{ex['left']}<TARGET>\n\n"
            f"Output:\n{ex['gt']}\n\n"
            "Now complete the following:\n"
        )
    if prompt_mode == "chain-of-thought":
        return "\n" + COT_INSTRUCTION + "\n"
    return ""


def extract_cot_answer(llm_output: str) -> str:
    """Extract the final answer from a chain-of-thought response."""
    marker = "ANSWER:"
    idx = llm_output.rfind(marker)
    if idx != -1:
        return llm_output[idx + len(marker):].strip()
    return llm_output




def extract_hls_code(llm_output: str) -> str:
    """
    Cleans LLM-generated code outputs by removing format markers,
    language tags, extra indentation, and empty lines.
    """
    if not isinstance(llm_output, str):
        llm_output = str(llm_output)

    # Remove language tags like "cpp\n" or "vhdl\n" at the beginning
    cleaned = re.sub(r"^\s*\w+\s*\n", "", llm_output)

    # Remove code block markers like ```cpp ```vhdl ``` etc.
    cleaned = re.sub(r"```[\w]*", "", cleaned)

    # Strip trailing whitespace from each line
    lines = [line.rstrip() for line in cleaned.splitlines()]

    # Remove empty lines
    lines = [line for line in lines if line.strip() != ""]

    return "\n".join(lines)


def count_target_lines(ground_truth: str) -> int:
    """
    Count how many lines the target output spans.
    """
    if not isinstance(ground_truth, str):
        ground_truth = str(ground_truth)
    lines = ground_truth.splitlines()
    return len(lines) if lines else 0


def build_truncated_prompt(
    left_context: str,
    replacement_token: str,
    target_lines: int,
    max_prompt_tokens: int,
    tokenizer_name: str,
    prompt_mode: str = "zero-shot",
    language: str = "",
) -> str:
    """
    Token-level truncation using tokenizer:
    prompt = LINE_PROMPT_PREFIX + line-count + left + <TARGET>

    - prefix (LINE_PROMPT_PREFIX) is always kept in full
    - only left context is used; it is cropped from the front to fit
    """
    tokenizer = get_tokenizer(tokenizer_name)

    mode_prefix = build_prompt_mode_prefix(language, prompt_mode)
    line_info = f"Target line count: {target_lines}. Output exactly {target_lines} line(s)."
    prefix_str = LINE_PROMPT_PREFIX + mode_prefix + "\n" + line_info + "\n"
    left_text = left_context or ""

    prefix_tokens = tokenizer.encode(prefix_str, add_special_tokens=False)
    left_tokens = tokenizer.encode(left_text, add_special_tokens=False)
    repl_tokens = tokenizer.encode(replacement_token, add_special_tokens=False)

    if max_prompt_tokens is None or max_prompt_tokens <= 0:
        combined = prefix_tokens + left_tokens + repl_tokens
        return tokenizer.decode(combined, clean_up_tokenization_spaces=False)

    prefix_len = len(prefix_tokens)
    budget = max_prompt_tokens - prefix_len
    if budget <= 0:
        body = repl_tokens[: max(0, max_prompt_tokens - prefix_len)]
        combined = prefix_tokens + body
        return tokenizer.decode(combined, clean_up_tokenization_spaces=False)

    core_total = len(left_tokens) + len(repl_tokens)
    if core_total <= budget:
        body_tokens = left_tokens + repl_tokens
    else:
        # keep <TARGET>, crop left context from the front
        left_budget = max(budget - len(repl_tokens), 0)
        left_tail = left_tokens[-left_budget:] if left_budget > 0 else []
        body_tokens = left_tail + repl_tokens

    combined_tokens = prefix_tokens + body_tokens
    return tokenizer.decode(combined_tokens, clean_up_tokenization_spaces=False)


# =========================
# Resume / checkpoint helpers
# =========================

def make_resume_key(entry: Dict, idx: int, strategy: str) -> str:
    """
    Build a stable key for a test entry.

    strategies:
    - index: use idx
    - repo_name: use task_id if exists else idx
    - task_id_path: task_id + '::' + path (recommended)
    """
    if strategy == "index":
        return str(idx)

    task_id = entry.get("task_id", "") or entry.get("repo_name", "") or ""
    if strategy == "ground_truth":
        ground_truth = entry.get("ground_truth", "") or ""
        return f"{task_id}::{ground_truth}"

    # default: repo_name
    return str(task_id) if task_id else str(idx)


def load_done_keys(responses_file: str, key_field: str = "resume_key") -> set:
    """
    Load completed entry keys from an existing responses JSONL file.
    """
    done = set()
    if not os.path.exists(responses_file):
        return done
    try:
        with open(responses_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    task_id = obj.get("prompt", "") or obj.get("repo_name", "") or ""
                    if task_id is not None:
                        done.add(str(task_id))
                except Exception:
                    continue
    except Exception as e:
        print(f"[WARN] Failed to load done keys from {responses_file}: {e}")
    return done


def evaluate_single_model(
    model_func,
    model_name: str,
    test_data: List[Dict],
    output_dir: str,
    language: str,
    max_prompt_tokens: int,
    tokenizer_name: str,
    resume: bool = False,
    resume_key: str = "task_id_path",
    prompt_mode: str = "zero-shot",
) -> Tuple[float, float, float]:
    """
    Single-pass evaluation for one model:
      - calls model once per entry
      - computes EM, ES, BLEU
      - writes per-entry responses to responses_<model>_<language>.jsonl
      - writes per-model summary to eval_<model>_<language>.jsonl

    Returns:
        (avg_em, avg_bleu, avg_es)
    """
    print(f"\nEvaluating {model_name} on {language} (prompt_mode={prompt_mode})...")
    os.makedirs(output_dir, exist_ok=True)
    mode_tag = f"_{prompt_mode}" if prompt_mode != "zero-shot" else ""
    per_model_file = os.path.join(output_dir, f"eval_{model_name}_{language}_{max_prompt_tokens}{mode_tag}.jsonl")
    responses_file = os.path.join(output_dir, f"responses_{model_name}_{language}_{max_prompt_tokens}{mode_tag}.jsonl")

    done_keys = set()
    if resume:
        done_keys = load_done_keys(responses_file, key_field=resume_key)
        if done_keys:
            print(f"[Resume] {model_name}/{language}: found {len(done_keys)} completed entries in {responses_file}")
        else:
            print(f"[Resume] {model_name}/{language}: no completed entries found, starting fresh.")

    # Start fresh only if not resuming
    if not resume:
        try:
            open(responses_file, "w", encoding="utf-8").close()
        except Exception as e:
            print(f"Warning: cannot initialize responses file {responses_file}: {e}")

    results = []
    em_scores = []
    es_scores = []
    bleu_scores = []
    appended = 0
    skipped = 0

    # append mode is safe for resume
    with open(responses_file, "a", encoding="utf-8") as resp_f:
        for i, entry in enumerate(tqdm(test_data, desc=f"Processing {model_name}")):
            try:
                # Resume skip
                #rk = make_resume_key(entry, i, resume_key)
                #print(f"Resume key for entry {i} (repo: {repo_name}, model: {model_name}): {rk}")
                if i < len(done_keys):
                    skipped += 1
                    print(f"[Resume] Skipping entry {i}")
                    continue

                left_context = entry.get("left_context", "")
                ground_truth = entry.get("groundtruth", "") or entry.get("ground_truth", "")
                repo_name = entry.get("task_id", f"entry_{i}")
                replacement_token = "<TARGET>"
                target_lines = count_target_lines(ground_truth)

                prompt = build_truncated_prompt(
                    left_context=left_context,
                    replacement_token=replacement_token,
                    target_lines=target_lines,
                    max_prompt_tokens=max_prompt_tokens,
                    tokenizer_name=tokenizer_name,
                    prompt_mode=prompt_mode,
                    language=language,
                )
                #print(f"Prompt for entry {i} (repo: {repo_name}, model: {model_name}): {prompt}")
                if not prompt or not ground_truth:
                    print(f"Warning: Missing prompt or ground truth for entry {i} (repo: {repo_name})")
                    continue

                # Model call with retry
                max_retries = 3
                model_response = ""
                start = time.time()
                for attempt in range(max_retries):
                    try:
                        model_response = model_func(prompt)
                        if isinstance(model_response, str) and "API Error" in model_response:
                            print(
                                f"[Retry {attempt+1}/{max_retries}] API error in response for entry {i} "
                                f"(repo: {repo_name}, model: {model_name}): {model_response[:120]}"
                            )
                            if attempt < max_retries - 1:
                                time.sleep(2 ** attempt)
                                continue
                        else:
                            break
                    except Exception as e:
                        print(
                            f"[Retry {attempt+1}/{max_retries}] Exception for entry {i} "
                            f"(repo: {repo_name}, model: {model_name}): {e}"
                        )
                        if attempt < max_retries - 1:
                            time.sleep(2 ** attempt)
                        else:
                            model_response = ""
                duration = time.time() - start

                # Skip entries that still have API errors after retries
                is_api_error = isinstance(model_response, str) and "API Error" in model_response
                if is_api_error:
                    print(f"[SKIP] Persistent API error for entry {i} (repo: {repo_name}, model: {model_name})")
                    detailed = {
                        "repo_name": repo_name,
                        "model_name": model_name,
                        "language": language,
                        "prompt": prompt,
                        "ground_truth": ground_truth,
                        "generated_code": model_response,
                        "em_score": 0.0,
                        "es_score": 0.0,
                        "bleu_score": 0.0,
                        "model_call_time_s": float(f"{duration:.2f}"),
                        "api_error": True,
                    }
                    resp_f.write(json.dumps(detailed, ensure_ascii=False) + "\n")
                    appended += 1
                    continue

                print(f"Model response for entry {i} (repo: {repo_name}, model: {model_name}): {model_response}")

                if prompt_mode == "chain-of-thought":
                    model_response = extract_cot_answer(model_response)
                generated_code = extract_hls_code(model_response)

                # Exact match
                try:
                    em_score = evaluate_em(generated_code, ground_truth, lang=language)
                except Exception as e:
                    print(f"Error in EM for entry {i} (repo: {repo_name}, model: {model_name}): {e}")
                    em_score = 0.0

                # Edit similarity
                try:
                    es_score = evaluate_es(generated_code, ground_truth, lang=language)
                except Exception as e:
                    print(f"Error in ES for entry {i} (repo: {repo_name}, model: {model_name}): {e}")
                    es_score = 0.0

                # BLEU
                try:
                    bleu_score = evaluate_bleu(generated_code, ground_truth)
                except Exception as e:
                    print(f"Error in BLEU for entry {i} (repo: {repo_name}, model: {model_name}): {e}")
                    bleu_score = 0.0

                # Per-model summary record
                per_model_rec = {
                    "repo_name": repo_name,
                    "model_name": model_name,
                    "language": language,
                    "em_score": float(em_score),
                    "es_score": float(es_score),
                    "bleu_score": float(bleu_score),
                }
                results.append(per_model_rec)
                em_scores.append(em_score)
                es_scores.append(es_score)
                bleu_scores.append(bleu_score)

                # Detailed response record
                detailed = {
                    "repo_name": repo_name,
                    "model_name": model_name,
                    "language": language,
                    "prompt": prompt,
                    "ground_truth": ground_truth,
                    "item_id": item_id(entry, language),
                    "path": entry.get("path", ""),
                    "generated_code": generated_code,
                    "em_score": float(em_score),
                    "es_score": float(es_score),
                    "bleu_score": float(bleu_score),
                    "model_call_time_s": float(f"{duration:.2f}"),
                }
                resp_f.write(json.dumps(detailed, ensure_ascii=False) + "\n")
                appended += 1

            except Exception as e:
                print(f"Unexpected error processing entry {i} for {model_name}: {e}")
                traceback.print_exc()
                continue

    # Save per-model summary (eval_<model>_<language>.jsonl) — overwrites is OK
    try:
        with open(per_model_file, "w", encoding="utf-8") as f:
            for r in results:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        print(f"Results for {model_name} saved to {per_model_file}")
    except Exception as e:
        print(f"Error saving per-model results for {model_name}: {e}")

    if len(em_scores) != len(test_data):
        raise RuntimeError(f"Incomplete evaluation: {len(em_scores)}/{len(test_data)} samples")
    avg_em = sum(em_scores) / len(em_scores) if em_scores else 0.0
    avg_es = sum(es_scores) / len(es_scores) if es_scores else 0.0
    avg_bleu = sum(bleu_scores) / len(bleu_scores) if bleu_scores else 0.0

    print(f"[{model_name}/{language}] appended={appended}, skipped={skipped}, responses_file={responses_file}")

    return avg_em, avg_bleu, avg_es




def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-jsonl", required=True, help="External evaluation JSONL.")
    parser.add_argument(
        "--language",
        type=str,
        default="vhdl",
        choices=["hls", "systemverilog", "vhdl", "chisel"],
        help="Target language / dataset.",
    )
    parser.add_argument(
        "--models",
        type=str,
        default="gpt5",
        help=(
            "Comma-separated list of models to evaluate. "
            "Available: deepseek_v3, deepseek_R1_mcts, gpt5, gpt4o, deepseek_v3_2,"
            "Qwen32B, claude_sonnet_4_5_thinking, gemini2_5, grok4"
        ),
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        required=True,
        help="Directory to store evaluation outputs.",
    )
    parser.add_argument(
        "--max_prompt_tokens",
        type=int,
        default=2048,
        help="Maximum total tokens for the prompt (prefix + left + <TARGET> + right). "
             "Set <=0 to disable truncation.",
    )
    parser.add_argument(
        "--tokenizer_name",
        type=str,
        default="microsoft/unixcoder-base",
        help="Tokenizer name/path used for prompt truncation.",
    )

    # NEW: resume
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume from existing responses_<model>_<language>.jsonl and skip completed entries.",
    )
    parser.add_argument(
        "--resume_key",
        type=str,
        default="ground_truth",
        choices=["repo_name", "index", "ground_truth"],
        help="Key strategy to identify finished entries when resuming. Recommended: ground_truth",
    )
    parser.add_argument(
        "--prompt_mode",
        type=str,
        default="zero-shot",
        choices=["zero-shot", "few-shot", "chain-of-thought"],
        help="Prompt strategy: zero-shot (default), few-shot (prepend example), "
             "chain-of-thought (ask model to reason step by step).",
    )

    args = parser.parse_args()

    language = args.language

    all_models: Dict[str, callable] = {
        "deepseek_v3": deepseek_v3,
        "deepseek_v3_2": deepseek_v3_2,
        "deepseek_R1_mcts": deepseek_R1_mcts,
        "gpt5": gpt5,
        "gpt4o": gpt4o,
        "Qwen32B": Qwen32B,
        "claude_sonnet_4_5_thinking": claude_sonnet_4_5_thinking,
        "gemini2_5": gemini2_5,
        "grok4": grok4,
    }

    selected_model_names = [m.strip() for m in args.models.split(",") if m.strip()]
    models: Dict[str, callable] = {}
    for name in selected_model_names:
        if name not in all_models:
            print(f"Warning: unknown model name '{name}' – skipping.")
            continue
        models[name] = all_models[name]

    if not models:
        print("No valid models selected. Exiting.")
        return

    test_file_path = args.test_jsonl.format(language=language)
    output_dir = f"{args.output_dir}"

    test_data = load_test_data(test_file_path)
    if not test_data:
        print("No test data loaded. Exiting.")
        return

    summary_results: Dict[str, Dict] = {}
    os.makedirs(output_dir, exist_ok=True)

    print("Starting evaluation of selected models...")
    print("=" * 60)

    for model_name, model_func in models.items():
        try:
            avg_em, avg_bleu, avg_es = evaluate_single_model(
                model_func=model_func,
                model_name=model_name,
                test_data=test_data,
                output_dir=output_dir,
                language=language,
                max_prompt_tokens=args.max_prompt_tokens,
                tokenizer_name=args.tokenizer_name,
                resume=args.resume,
                resume_key=args.resume_key,
                prompt_mode=args.prompt_mode,
            )

            summary_results[model_name] = {
                "avg_em_score": avg_em,
                "avg_bleu_score": avg_bleu,
                "avg_es_score": avg_es,
                "language": language,
                "prompt_mode": args.prompt_mode,
                "resume": bool(args.resume),
                "resume_key": args.resume_key,
            }

            print(f"\n{model_name} Results on {language}:")
            print(f"  Average Exact Match Score: {avg_em:.4f}")
            print(f"  Average BLEU Score      : {avg_bleu:.4f}")
            print(f"  Average ES Score        : {avg_es:.4f}")

        except Exception as e:
            print(f"Error evaluating {model_name}: {e}")
            traceback.print_exc()
            summary_results[model_name] = {
                "avg_em_score": 0.0,
                "avg_bleu_score": 0.0,
                "avg_es_score": 0.0,
                "language": language,
                "resume": bool(args.resume),
                "resume_key": args.resume_key,
                "error": str(e),
            }
            raise

    # Save summary (evaluation_summary_<language>.json)
    summary_file = os.path.join(output_dir, f"evaluation_summary_{model_name}_{language}_{args.max_prompt_tokens}.json")
    try:
        with open(summary_file, "w", encoding="utf-8") as f:
            json.dump(summary_results, f, indent=2, ensure_ascii=False)
        print(f"\nSummary results saved to {summary_file}")
    except Exception as e:
        print(f"Error saving summary: {e}")

    print("\n" + "=" * 60)
    print(f"EVALUATION SUMMARY ({language})")
    print("=" * 60)
    for model_name, results in summary_results.items():
        if "error" not in results:
            print(f"{model_name}:")
            print(f"  Avg EM  : {results['avg_em_score']:.4f}")
            print(f"  Avg BLEU: {results['avg_bleu_score']:.4f}")
            print(f"  Avg ES  : {results['avg_es_score']:.4f}")
        else:
            print(f"{model_name}: FAILED - {results['error']}")
        print()


if __name__ == "__main__":
    main()
