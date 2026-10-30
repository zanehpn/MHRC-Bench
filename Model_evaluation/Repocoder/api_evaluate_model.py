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
  * --resume_key : how to identify a sample uniquely
  * Skips already-evaluated samples without re-running and preserves prior scores.
"""

import json
import os
import time
import hashlib
import re, sys
from typing import Dict, List, Tuple
from tqdm import tqdm
import traceback
import argparse
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))

PARENT_DIR = os.path.dirname(CURRENT_DIR)

LIB_DIR = os.path.join(PARENT_DIR, "lib_function")

if LIB_DIR not in sys.path:
    sys.path.append(LIB_DIR)
try:
    from api_function import (
        deepseek_v3,
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
    exit(1)

SUPPORTED_LANGUAGES = ["hls", "systemverilog", "vhdl", "chisel"]

LINE_PROMPT_PREFIX = """You are a precise code-completion model completing a repository blank completion task. Input: a repository concatenation where each file of the repo is wrapped in `--- FILE: <repo_name>/<rel/path/to/file> (BEGIN) ---
<file content...>
--- FILE: <repo name>/<rel/path/to/file> (END) ---
`. Some lines have been replaced by the exact token `<TARGET>`. Your task: reconstruct **only** the missing code span, using the repository context. Note that for certain large repositories, functions of lesser importance were removed of their implementation, and only the signature/documentation were kept for the sake of simplicity.

OUTPUT: the reconstructed code span (and nothing else)."""





from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from release_io import load_test_data, item_id, validate_prompt_budget
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

    # Join back
    return "\n".join(lines)


def _hash_resume_key(*parts: str) -> str:
    raw = "\0".join(str(part) for part in parts)
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()


def make_resume_key(entry: Dict, idx: int, strategy: str) -> str:
    """
    Build a stable key for a test entry.

    strategies:
    - index: use dataset index
    - repo_name: use task_id if exists else idx
    - ground_truth: repo_name + ground truth
    - prompt: repo_name + full prompt body
    """
    repo_name = entry.get("task_id", "") or entry.get("repo_name", "") or f"entry_{idx}"

    if strategy == "index":
        return _hash_resume_key(strategy, idx)
    if strategy == "ground_truth":
        return _hash_resume_key(strategy, repo_name, entry.get("groundtruth", "") or "")
    if strategy == "prompt":
        return _hash_resume_key(strategy, repo_name, entry.get("prompt", "") or "")

    return _hash_resume_key(strategy, repo_name)


def make_resume_key_from_response(response: Dict, fallback_idx: int, strategy: str) -> str:
    """
    Reconstruct a resume key from a stored detailed response record.
    """
    stored_strategy = response.get("resume_key_strategy")
    stored_key = response.get("resume_key")
    if stored_key and stored_strategy == strategy:
        return str(stored_key)

    repo_name = response.get("repo_name", "") or f"entry_{fallback_idx}"
    entry_index = response.get("entry_index", fallback_idx)

    if strategy == "index":
        return _hash_resume_key(strategy, entry_index)
    if strategy == "ground_truth":
        return _hash_resume_key(strategy, repo_name, response.get("ground_truth", "") or "")
    if strategy == "prompt":
        return _hash_resume_key(strategy, repo_name, response.get("prompt", "") or "")

    return _hash_resume_key(strategy, repo_name)


def load_existing_state(
    responses_file: str,
    resume_key: str,
) -> Tuple[set, List[Dict], List[float], List[float], List[float]]:
    """
    Load completed entry keys and prior metrics from an existing responses JSONL file.
    Duplicate resume keys are ignored after the first occurrence.
    """
    done_keys = set()
    results = []
    em_scores = []
    es_scores = []
    bleu_scores = []

    if not os.path.exists(responses_file):
        return done_keys, results, em_scores, es_scores, bleu_scores

    try:
        with open(responses_file, "r", encoding="utf-8") as f:
            for line_idx, line in enumerate(f):
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    key = make_resume_key_from_response(obj, line_idx, resume_key)
                    if key in done_keys:
                        continue

                    done_keys.add(key)
                    em_score = float(obj.get("em_score", 0.0))
                    es_score = float(obj.get("es_score", 0.0))
                    bleu_score = float(obj.get("bleu_score", 0.0))

                    results.append(
                        {
                            "repo_name": obj.get("repo_name", f"entry_{line_idx}"),
                            "model_name": obj.get("model_name", ""),
                            "language": obj.get("language", ""),
                            "em_score": em_score,
                            "es_score": es_score,
                            "bleu_score": bleu_score,
                        }
                    )
                    em_scores.append(em_score)
                    es_scores.append(es_score)
                    bleu_scores.append(bleu_score)
                except Exception:
                    continue
    except Exception as e:
        print(f"[WARN] Failed to load resume state from {responses_file}: {e}")

    return done_keys, results, em_scores, es_scores, bleu_scores


def evaluate_single_model(
    model_func,
    model_name: str,
    test_data: List[Dict],
    output_dir: str,
    language: str,
    max_tokens: int,
    resume: bool = False,
    resume_key: str = "prompt",
    tokenizer_name: str = "microsoft/unixcoder-base",
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
    print(f"\nEvaluating {model_name} on {language}...")
    os.makedirs(output_dir, exist_ok=True)
    per_model_file = os.path.join(output_dir, f"eval_{model_name}_{language}_{max_tokens}.jsonl")
    responses_file = os.path.join(output_dir, f"responses_{model_name}_{language}_{max_tokens}.jsonl")

    results = []
    em_scores = []
    es_scores = []
    bleu_scores = []
    done_keys = set()
    appended = 0
    skipped = 0
    restored = 0

    if resume:
        done_keys, results, em_scores, es_scores, bleu_scores = load_existing_state(
            responses_file=responses_file,
            resume_key=resume_key,
        )
        restored = len(done_keys)
        if restored:
            print(
                f"[Resume] {model_name}/{language}: restored {restored} completed entries from {responses_file}"
            )
        else:
            print(f"[Resume] {model_name}/{language}: no completed entries found, starting fresh.")
    else:
        try:
            open(responses_file, "w", encoding="utf-8").close()
        except Exception as e:
            print(f"Warning: cannot initialize responses file {responses_file}: {e}")

    with open(responses_file, "a", encoding="utf-8") as resp_f:
        for i, entry in enumerate(tqdm(test_data, desc=f"Processing {model_name}")):
            try:
                entry_resume_key = make_resume_key(entry, i, resume_key)
                if entry_resume_key in done_keys:
                    skipped += 1
                    continue

                ground_truth = entry.get("groundtruth", "")
                repo_name = entry.get("task_id", f"entry_{i}")
                prompt_pre = entry.get("prompt", "")
                prompt_prefix = LINE_PROMPT_PREFIX
                prompt = f"{prompt_prefix}\n{prompt_pre}\n"
                validate_prompt_budget(prompt, tokenizer_name, max_tokens)

                if not prompt or not ground_truth:
                    print(
                        f"Warning: Missing prompt or ground truth for entry {i} (repo: {repo_name})"
                    )
                    continue

                # Model call
                start = time.time()
                try:
                    model_response = model_func(prompt)
                except Exception as e:
                    print(
                        f"Error generating response for entry {i} "
                        f"(repo: {repo_name}, model: {model_name}): {e}"
                    )
                    model_response = ""
                duration = time.time() - start

                generated_code = extract_hls_code(model_response)

                # Exact match
                try:
                    em_score = evaluate_em(generated_code, ground_truth, lang=language)
                except Exception as e:
                    print(
                        f"Error in EM for entry {i} (repo: {repo_name}, model: {model_name}): {e}"
                    )
                    em_score = 0.0

                # Edit similarity
                try:
                    es_score = evaluate_es(generated_code, ground_truth, lang=language)
                except Exception as e:
                    print(
                        f"Error in ES for entry {i} (repo: {repo_name}, model: {model_name}): {e}"
                    )
                    es_score = 0.0

                # BLEU
                try:
                    bleu_score = evaluate_bleu(generated_code, ground_truth)
                except Exception as e:
                    print(
                        f"Error in BLEU for entry {i} (repo: {repo_name}, model: {model_name}): {e}"
                    )
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
                    "entry_index": i,
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
                    "resume_key": entry_resume_key,
                    "resume_key_strategy": resume_key,
                }
                resp_f.write(json.dumps(detailed, ensure_ascii=False) + "\n")
                done_keys.add(entry_resume_key)
                appended += 1

            except Exception as e:
                print(f"Unexpected error processing entry {i} for {model_name}: {e}")
                traceback.print_exc()
                continue

    # Save per-model summary (eval_<model>_<language>.jsonl)
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

    print(
        f"[{model_name}/{language}] restored={restored}, appended={appended}, "
        f"skipped={skipped}, responses_file={responses_file}"
    )

    return avg_em, avg_bleu, avg_es




def main():
    parser = argparse.ArgumentParser()
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
        default="gpt5",
        help=(
            "Comma-separated list of models to evaluate. "
            "Available: deepseek_v3, deepseek_R1_mcts, gpt5, gpt4o, "
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
        "--max_tokens",
        type=int,
        default=2048    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume from an existing responses_<model>_<language>_<max_tokens>.jsonl file.",
    )
    parser.add_argument(
        "--resume_key",
        type=str,
        default="prompt",
        choices=["repo_name", "index", "ground_truth", "prompt"],
        help="Strategy used to identify finished entries when resuming.",
    )

    parser.add_argument("--tokenizer_name", default="microsoft/unixcoder-base")
    args = parser.parse_args()

    requested_language = args.language
    languages = SUPPORTED_LANGUAGES if requested_language == "all" else [requested_language]
    max_tokens = args.max_tokens

    # Map name -> function from api_function
    all_models: Dict[str, callable] = {
        "deepseek_v3": deepseek_v3,
        "deepseek_R1_mcts": deepseek_R1_mcts,
        "gpt5": gpt5,
        "gpt4o": gpt4o,
        "Qwen32B": Qwen32B,
        "claude_sonnet_4_5_thinking": claude_sonnet_4_5_thinking,
        "gemini2_5": gemini2_5,
        "grok4": grok4,
    }

    # Parse the selected models
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

    output_dir = f"{args.output_dir}"
    os.makedirs(output_dir, exist_ok=True)
    summary_results: Dict[str, Dict[str, Dict]] = {}

    print("Starting evaluation of selected models...")
    print("=" * 60)

    for language in languages:
        test_file_path = args.test_jsonl.format(language=language)
        test_data = load_test_data(test_file_path)
        if not test_data:
            print(f"No test data loaded for {language}. Skipping.")
            summary_results[language] = {
                "__language__": {
                    "avg_em_score": 0.0,
                    "avg_bleu_score": 0.0,
                    "avg_es_score": 0.0,
                    "language": language,
                    "error": "No test data loaded.",
                }
            }
            continue

        summary_results[language] = {}
        print(f"\nRunning evaluation for language: {language}")
        print("=" * 60)

        for model_name, model_func in models.items():
            try:
                avg_em, avg_bleu, avg_es = evaluate_single_model(
                    model_func=model_func,
                    model_name=model_name,
                    test_data=test_data,
                    output_dir=output_dir,
                    language=language,
                    max_tokens=max_tokens,
                tokenizer_name=args.tokenizer_name,
                    resume=args.resume,
                    resume_key=args.resume_key,
                )

                summary_results[language][model_name] = {
                    "avg_em_score": avg_em,
                    "avg_bleu_score": avg_bleu,
                    "avg_es_score": avg_es,
                    "language": language,
                    "resume": bool(args.resume),
                    "resume_key": args.resume_key,
                }

                print(f"\n{model_name} Results on {language}:")
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
                    "resume": bool(args.resume),
                    "resume_key": args.resume_key,
                    "error": str(e),
                }
                raise

    summary_file = os.path.join(
        output_dir,
        f"evaluation_summary_{requested_language}_{max_tokens}.json",
    )
    try:
        with open(summary_file, "w", encoding="utf-8") as f:
            json.dump(summary_results, f, indent=2, ensure_ascii=False)
        print(f"\nSummary results saved to {summary_file}")
    except Exception as e:
        print(f"Error saving summary: {e}")

    # Print final summary
    print("\n" + "=" * 60)
    print(f"EVALUATION SUMMARY ({requested_language})")
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
