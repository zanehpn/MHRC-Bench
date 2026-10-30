#!/usr/bin/env python3
"""
Evaluation script for API models (GPT-5, Gemini-2.5-Pro, etc.) using FIM-style prompts.

Instead of the left-to-right prompt (PREFIX + left + <TARGET> + right), this script
uses a Fill-in-the-Middle (FIM) style prompt where left (prefix) and right (suffix)
contexts are clearly separated, and the model is asked to generate only the missing
middle content.

- Supports multiple models configured from api_function.py
- Supports multiple languages: hls, systemverilog, vhdl, chisel
- Resume / checkpoint support
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
    if name not in _TOKENIZER_CACHE:
        _TOKENIZER_CACHE[name] = AutoTokenizer.from_pretrained(name)
    return _TOKENIZER_CACHE[name]


# Import model functions + evaluators
try:
    from api_function import (
        gpt5,
        gemini2_5,
    )
    from exact_match import evaluate_em, evaluate_es
    from codebleu import evaluate_bleu
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure api_function.py, exact_match.py, and codebleu.py are in lib_function/")
    raise SystemExit(1)

SUPPORTED_LANGUAGES = ["hls", "systemverilog", "vhdl", "chisel"]

# FIM-style prompt for chat/instruction-following API models
FIM_PROMPT_PREFIX = """You are a precise code-completion model performing a fill-in-the-middle task. You are given repository code split into two parts:

1. **PREFIX** — the code that comes *before* the missing section
2. **SUFFIX** — the code that comes *after* the missing section

The code is from a repository concatenation where each file is wrapped in `--- FILE: <repo_name>/<rel/path/to/file> (BEGIN) ---` and `--- FILE: <repo_name>/<rel/path/to/file> (END) ---`. Some lines have been removed. Your task: reconstruct **only** the removed line(s) that bridge the PREFIX and SUFFIX, using the repository context. Note that for certain large repositories, functions of lesser importance were removed of their implementation, and only the signature/documentation were kept for the sake of simplicity.

OUTPUT: the reconstructed line(s) (and nothing else). Do NOT include any explanation, code fences, or extra formatting."""


def build_fim_prompt(
    left_context: str,
    right_context: str,
    max_prompt_tokens: int,
    tokenizer_name: str,
) -> str:
    """
    Build a FIM-style prompt for chat API models:
      FIM_PROMPT_PREFIX + \n\nPREFIX:\n + left + \n\nSUFFIX:\n + right

    Token-level truncation: prefix instruction is always kept; left/right are
    symmetrically trimmed around the infill boundary.
    """
    tokenizer = get_tokenizer(tokenizer_name)

    prefix_str = FIM_PROMPT_PREFIX + "\n\nPREFIX:\n"
    suffix_marker = "\n\nSUFFIX:\n"

    left_text = left_context or ""
    right_text = right_context or ""

    prefix_tokens = tokenizer.encode(prefix_str, add_special_tokens=False)
    suffix_marker_tokens = tokenizer.encode(suffix_marker, add_special_tokens=False)
    left_tokens = tokenizer.encode(left_text, add_special_tokens=False)
    right_tokens = tokenizer.encode(right_text, add_special_tokens=False)

    if max_prompt_tokens is None or max_prompt_tokens <= 0:
        combined = prefix_tokens + left_tokens + suffix_marker_tokens + right_tokens
        return tokenizer.decode(combined, clean_up_tokenization_spaces=False)

    fixed_len = len(prefix_tokens) + len(suffix_marker_tokens)
    budget = max_prompt_tokens - fixed_len
    if budget <= 0:
        combined = (prefix_tokens + suffix_marker_tokens)[:max(0, max_prompt_tokens)]
        return tokenizer.decode(combined, clean_up_tokenization_spaces=False)

    core_total = len(left_tokens) + len(right_tokens)
    if core_total <= budget:
        left_tail = left_tokens
        right_head = right_tokens
    else:
        left_budget = min(len(left_tokens), budget // 2)
        right_budget = min(len(right_tokens), budget - left_budget)

        extra = budget - (left_budget + right_budget)
        if extra > 0:
            add_left = min(extra, len(left_tokens) - left_budget)
            left_budget += add_left
            extra -= add_left
            right_budget += min(extra, len(right_tokens) - right_budget)

        left_tail = left_tokens[-left_budget:] if left_budget > 0 else []
        right_head = right_tokens[:right_budget] if right_budget > 0 else []

    combined_tokens = prefix_tokens + left_tail + suffix_marker_tokens + right_head
    return tokenizer.decode(combined_tokens, clean_up_tokenization_spaces=False)




def extract_hls_code(llm_output: str) -> str:
    if not isinstance(llm_output, str):
        llm_output = str(llm_output)
    cleaned = re.sub(r"^\s*\w+\s*\n", "", llm_output)
    cleaned = re.sub(r"```[\w]*", "", cleaned)
    lines = [line.rstrip() for line in cleaned.splitlines()]
    lines = [line for line in lines if line.strip() != ""]
    return "\n".join(lines)


def load_done_keys(responses_file: str) -> set:
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
) -> Tuple[float, float, float]:
    print(f"\nEvaluating {model_name} on {language} (FIM prompt)...")
    os.makedirs(output_dir, exist_ok=True)

    per_model_file = os.path.join(output_dir, f"eval_{model_name}_{language}_{max_prompt_tokens}_fim.jsonl")
    responses_file = os.path.join(output_dir, f"responses_{model_name}_{language}_{max_prompt_tokens}_fim.jsonl")

    done_keys = set()
    if resume:
        done_keys = load_done_keys(responses_file)
        if done_keys:
            print(f"[Resume] {model_name}/{language}: found {len(done_keys)} completed entries in {responses_file}")
        else:
            print(f"[Resume] {model_name}/{language}: no completed entries found, starting fresh.")

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

    with open(responses_file, "a", encoding="utf-8") as resp_f:
        for i, entry in enumerate(tqdm(test_data, desc=f"Processing {model_name}")):
            try:
                if i < len(done_keys):
                    skipped += 1
                    continue

                left_context = entry.get("left_context", "")
                right_context = entry.get("right_context", "")
                ground_truth = entry.get("groundtruth", "")
                repo_name = entry.get("task_id", f"entry_{i}")

                prompt = build_fim_prompt(
                    left_context=left_context,
                    right_context=right_context,
                    max_prompt_tokens=max_prompt_tokens,
                    tokenizer_name=tokenizer_name,
                )

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
                                f"[Retry {attempt+1}/{max_retries}] API error for entry {i} "
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

                # Skip persistent API errors
                is_api_error = isinstance(model_response, str) and "API Error" in model_response
                if is_api_error:
                    print(f"[SKIP] Persistent API error for entry {i} (repo: {repo_name}, model: {model_name})")
                    detailed = {
                        "repo_name": repo_name,
                        "model_name": model_name,
                        "language": language,
                        "prompt_mode": "fim",
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

                generated_code = extract_hls_code(model_response)

                try:
                    em_score = evaluate_em(generated_code, ground_truth, lang=language)
                except Exception:
                    em_score = 0.0
                try:
                    es_score = evaluate_es(generated_code, ground_truth, lang=language)
                except Exception:
                    es_score = 0.0
                try:
                    bleu_score = evaluate_bleu(generated_code, ground_truth)
                except Exception:
                    bleu_score = 0.0

                results.append({
                    "repo_name": repo_name,
                    "model_name": model_name,
                    "language": language,
                    "prompt_mode": "fim",
                    "em_score": float(em_score),
                    "es_score": float(es_score),
                    "bleu_score": float(bleu_score),
                })
                em_scores.append(em_score)
                es_scores.append(es_score)
                bleu_scores.append(bleu_score)

                detailed = {
                    "repo_name": repo_name,
                    "model_name": model_name,
                    "language": language,
                    "prompt_mode": "fim",
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
    parser = argparse.ArgumentParser(
        description="Evaluate API models (GPT-5, Gemini-2.5-Pro) with FIM-style prompts"
    )
    parser.add_argument("--test-jsonl", required=True, help="External evaluation JSONL.")
    parser.add_argument(
        "--language",
        type=str,
        default="vhdl",
        choices=SUPPORTED_LANGUAGES + ["all"],
        help="Target language / dataset. Use 'all' to evaluate every supported language.",
    )
    parser.add_argument(
        "--models",
        type=str,
        default="gpt5,gemini2_5",
        help="Comma-separated list of models. Available: gpt5, gemini2_5",
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
        help="Maximum total tokens for the prompt. Set <=0 to disable truncation.",
    )
    parser.add_argument(
        "--tokenizer_name",
        type=str,
        default="microsoft/unixcoder-base",
        help="Tokenizer name/path used for prompt truncation.",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume from existing responses file and skip completed entries.",
    )

    args = parser.parse_args()

    requested_language = args.language
    languages = SUPPORTED_LANGUAGES if requested_language == "all" else [requested_language]

    all_models: Dict[str, callable] = {
        "gpt5": gpt5,
        "gemini2_5": gemini2_5,
    }

    selected_model_names = [m.strip() for m in args.models.split(",") if m.strip()]
    models: Dict[str, callable] = {}
    for name in selected_model_names:
        if name not in all_models:
            print(f"Warning: unknown model name '{name}' – skipping. Available: {list(all_models.keys())}")
            continue
        models[name] = all_models[name]

    if not models:
        print("No valid models selected. Exiting.")
        return

    output_dir = args.output_dir
    os.makedirs(output_dir, exist_ok=True)

    summary_results: Dict[str, Dict[str, Dict]] = {}

    print("Starting FIM evaluation of selected models...")
    print("=" * 60)

    for language in languages:
        test_file_path = args.test_jsonl.format(language=language)
        test_data = load_test_data(test_file_path)
        if not test_data:
            print(f"No test data loaded for {language}. Skipping.")
            summary_results[language] = {
                "__language__": {"error": "No test data loaded.", "language": language}
            }
            continue

        summary_results[language] = {}
        print(f"\nRunning FIM evaluation for language: {language}")
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
                )

                summary_results[language][model_name] = {
                    "avg_em_score": avg_em,
                    "avg_bleu_score": avg_bleu,
                    "avg_es_score": avg_es,
                    "language": language,
                    "prompt_mode": "fim",
                    "resume": bool(args.resume),
                }

                print(f"\n{model_name} Results on {language} (FIM):")
                print(f"  Average Exact Match Score: {avg_em:.4f}")
                print(f"  Average BLEU Score      : {avg_bleu:.4f}")
                print(f"  Average ES Score        : {avg_es:.4f}")

            except Exception as e:
                print(f"Error evaluating {model_name} on {language}: {e}")
                traceback.print_exc()
                summary_results[language][model_name] = {
                    "avg_em_score": 0.0,
                    "avg_bleu_score": 0.0,
                    "avg_es_score": 0.0,
                    "language": language,
                    "prompt_mode": "fim",
                    "error": str(e),
                }
                raise

    summary_file = os.path.join(
        output_dir,
        f"evaluation_summary_{requested_language}_{args.max_prompt_tokens}_fim.json",
    )
    try:
        with open(summary_file, "w", encoding="utf-8") as f:
            json.dump(summary_results, f, indent=2, ensure_ascii=False)
        print(f"\nSummary results saved to {summary_file}")
    except Exception as e:
        print(f"Error saving summary: {e}")

    print("\n" + "=" * 60)
    print(f"FIM EVALUATION SUMMARY ({requested_language})")
    print("=" * 60)
    for language, language_results in summary_results.items():
        print(f"{language}:")
        for model_name, results in language_results.items():
            if "error" not in results:
                print(f"  {model_name}:")
                print(f"    Avg EM  : {results['avg_em_score']:.4f}")
                print(f"    Avg BLEU: {results['avg_bleu_score']:.4f}")
                print(f"    Avg ES  : {results['avg_es_score']:.4f}")
            else:
                print(f"  {model_name}: FAILED - {results['error']}")
        print()


if __name__ == "__main__":
    main()
