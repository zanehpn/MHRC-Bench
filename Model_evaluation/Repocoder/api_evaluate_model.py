#!/usr/bin/env python3
"""
Evaluation script for various API functions (DeepSeek-R1, GPT-4o, Qwen32B, etc.)
Evaluates generated code against ground truth using exact match, edit similarity,
and BLEU metrics.

- Supports multiple models configured from api_function.py
- Supports multiple languages: hls, systemverilog, vhdl, chisel
- Test file path & output file paths all include language suffix.
"""

import json
import os
import time
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

LINE_PROMPT_PREFIX = """You are a precise code-completion model completing a repository blank completion task. Input: a repository concatenation where each file of the repo is wrapped in `--- FILE: <repo_name>/<rel/path/to/file> (BEGIN) ---
<file content...>
--- FILE: <repo name>/<rel/path/to/file> (END) ---
`. Some lines have been replaced by the exact token `<TARGET>`. Your task: reconstruct **only** the replaced line, using the repository context. Note that for certain large repositories, functions of lesser importance were removed of their implementation, and only the signature/documentation were kept for the sake of simplicity.


OUTPUT: the reconstructed line(and nothing else)."""


def load_test_data(file_path: str) -> List[Dict]:
    """
    Loads test data from a .jsonl file (one JSON object per line).
    Includes error handling for individual malformed lines.
    """
    test_data = []
    print(f"Reading test data from {file_path}...")
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    test_data.append(json.loads(line))
                except json.JSONDecodeError as e:
                    print(f"Warning: Skipped malformed JSON on line {line_num}: {e}")

        print(f"Successfully loaded {len(test_data)} test entries from {file_path}")
        return test_data
    except Exception as e:
        print(f"Critical error opening/reading file: {e}")
        return []


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


def evaluate_single_model(
    model_func,
    model_name: str,
    test_data: List[Dict],
    output_dir: str,
    language: str,
    max_tokens: int,
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

    # Start fresh for this model
    try:
        open(responses_file, "w", encoding="utf-8").close()
    except Exception as e:
        print(f"Warning: cannot initialize responses file {responses_file}: {e}")

    results = []
    em_scores = []
    es_scores = []
    bleu_scores = []
    appended = 0

    with open(responses_file, "a", encoding="utf-8") as resp_f:
        for i, entry in enumerate(tqdm(test_data, desc=f"Processing {model_name}")):
            try:

                ground_truth = entry.get("groundtruth", "")
                repo_name = entry.get("task_id", f"entry_{i}")
                prompt_pre = entry.get("prompt", "")
                prompt_prefix = LINE_PROMPT_PREFIX
                prompt = f"{prompt_prefix}\n{prompt_pre}\n"

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
                    em_score = evaluate_em(generated_code, ground_truth)
                except Exception as e:
                    print(
                        f"Error in EM for entry {i} (repo: {repo_name}, model: {model_name}): {e}"
                    )
                    em_score = 0.0

                # Edit similarity
                try:
                    es_score = evaluate_es(generated_code, ground_truth)
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
                    "repo_name": repo_name,
                    "model_name": model_name,
                    "language": language,
                    "prompt": prompt,
                    "ground_truth": ground_truth,
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

    # Save per-model summary (eval_<model>_<language>.jsonl)
    try:
        with open(per_model_file, "w", encoding="utf-8") as f:
            for r in results:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        print(f"Results for {model_name} saved to {per_model_file}")
    except Exception as e:
        print(f"Error saving per-model results for {model_name}: {e}")

    avg_em = sum(em_scores) / len(em_scores) if em_scores else 0.0
    avg_es = sum(es_scores) / len(es_scores) if es_scores else 0.0
    avg_bleu = sum(bleu_scores) / len(bleu_scores) if bleu_scores else 0.0

    print(
        f"Appended {appended} detailed responses for {model_name} "
        f"to {responses_file}"
    )

    return avg_em, avg_bleu, avg_es


def get_test_file_for_language(language: str, max_tokens) -> str:
    """
    Map language to test_content.jsonl path.
    """
    base = CURRENT_DIR
    if language == "hls":
        return os.path.join(base, f"test_repocoder_hls_{max_tokens}.jsonl")
    elif language == "vhdl":
        return os.path.join(base, f"test_repocoder_vhdl_{max_tokens}.jsonl")
    elif language == "systemverilog":
        return os.path.join(base, f"test_repocoder_systemverilog_{max_tokens}.jsonl")
    elif language == "chisel":
        return os.path.join(base, f"test_repocoder_chisel_{max_tokens}.jsonl")
    else:
        raise ValueError(f"Unsupported language: {language}")


def main():
    parser = argparse.ArgumentParser()
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
            "Available: deepseek_v3, deepseek_R1_mcts, gpt5, gpt4o, "
            "Qwen32B, claude_sonnet_4_5_thinking, gemini2_5, grok4"
        ),
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default="eval_results",
        help="Directory to store evaluation outputs.",
    )

    parser.add_argument(
        "--max_tokens",
        type=int,
        default=2048    )    

    args = parser.parse_args()

    language = args.language
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

    test_file_path = get_test_file_for_language(language,max_tokens)
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
                max_tokens=max_tokens,
            )

            summary_results[model_name] = {
                "avg_em_score": avg_em,
                "avg_bleu_score": avg_bleu,
                "avg_es_score": avg_es,
                "language": language,
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
                "error": str(e),
            }

    # Save summary (evaluation_summary_<language>.json)
    summary_file = os.path.join(output_dir, f"evaluation_summary_{language}_{model_name}_{max_tokens}.json")
    try:
        with open(summary_file, "w", encoding="utf-8") as f:
            json.dump(summary_results, f, indent=2, ensure_ascii=False)
        print(f"\nSummary results saved to {summary_file}")
    except Exception as e:
        print(f"Error saving summary: {e}")

    # Print final summary
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
