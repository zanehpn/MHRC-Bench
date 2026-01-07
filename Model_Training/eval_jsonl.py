#!/usr/bin/env python3
"""
Evaluation script for reading existing .jsonl results and calculating metrics.
Modified to read existing evaluation results instead of generating new ones.

Now also supports CodeBLEU:
- Uses existing codebleu_score field if present (default mode)
- Or recomputes CodeBLEU from ground_truth/generated_code (when --recalculate is set)
"""

import json
import os
import sys
from typing import Dict, List, Tuple
from tqdm import tqdm
import argparse

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
LIB_DIR = os.path.join(PARENT_DIR, "Model_evaluation/lib_function")
if LIB_DIR not in sys.path:
    sys.path.append(LIB_DIR)

try:
    from exact_match import evaluate_em, evaluate_es
    from codebleu import evaluate_bleu

    # ---- CodeBLEU language-specific entry points ----
    # You should provide these in Model_evaluation/lib_function/codebleu.py
    from codebleu import (
        evaluate_codebleu_chisel,
        evaluate_codebleu_systemverilog,
        evaluate_codebleu_vhdl,
        evaluate_codebleu_hls,
    )
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure exact_match.py and codebleu.py are in lib_function/ or same directory")
    exit(1)


def load_existing_results(file_path: str) -> List[Dict]:
    """Load existing evaluation results from a .jsonl file."""
    results = []
    print(f"Reading existing results from {file_path}...")
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    results.append(json.loads(line))
                except json.JSONDecodeError as e:
                    print(f"Warning: Skipped malformed JSON on line {line_num}: {e}")
        print(f"Successfully loaded {len(results)} results from {file_path}")
        return results
    except Exception as e:
        print(f"Critical error opening/reading file: {e}")
        return []


def _safe_float(x, default: float = 0.0) -> float:
    try:
        return float(x)
    except Exception:
        return default


def _infer_language_from_result(result: Dict, fallback: str = "") -> str:
    # common fields: "language", or filename pattern, etc.
    lang = (result.get("language") or fallback or "").lower().strip()
    # normalize aliases
    if lang in ("sv", "verilog", "system_verilog"):
        return "systemverilog"
    if lang in ("c", "cpp", "c++", "hls_cpp"):
        return "hls"
    return lang


def _call_em(pred: str, ref: str, lang: str) -> float:
    # support both signatures: (pred, ref, lang) or (pred, ref)
    try:
        return float(evaluate_em(pred, ref, lang))
    except TypeError:
        return float(evaluate_em(pred, ref))


def _call_es(pred: str, ref: str, lang: str) -> float:
    # support both signatures: ([ref],[pred],lang) or (pred,ref,lang) or (pred,ref)
    try:
        return float(evaluate_es([ref], [pred], lang))
    except TypeError:
        try:
            return float(evaluate_es(pred, ref, lang))
        except TypeError:
            return float(evaluate_es(pred, ref))


def _call_codebleu(pred: str, ref: str, lang: str) -> float:
    """
    Calls language-specific CodeBLEU.
    Accepts either:
      - float return
      - or an object with attribute 'codebleu'
      - or dict with key 'codebleu'
    """
    lang = _infer_language_from_result({"language": lang})
    if lang == "chisel":
        out = evaluate_codebleu_chisel(pred, ref)
    elif lang == "systemverilog":
        out = evaluate_codebleu_systemverilog(pred, ref)
    elif lang == "vhdl":
        out = evaluate_codebleu_vhdl(pred, ref)
    elif lang == "hls":
        out = evaluate_codebleu_hls(pred, ref)
    else:
        # unknown language => fallback 0
        return 0.0

    # normalize return
    if isinstance(out, (int, float)):
        return float(out)
    if isinstance(out, dict):
        return _safe_float(out.get("codebleu", 0.0))
    if hasattr(out, "codebleu"):
        return _safe_float(getattr(out, "codebleu"))
    return 0.0


def calculate_metrics_from_results(
    results: List[Dict],
    recalculate: bool = False,
    language_hint: str = ""
) -> Tuple[float, float, float, float]:
    """
    Calculate average metrics from existing results.

    Returns:
      avg_em, avg_bleu, avg_es, avg_codebleu
    """
    em_scores, es_scores, bleu_scores, codebleu_scores = [], [], [], []

    for i, result in enumerate(tqdm(results, desc="Calculating metrics")):
        if recalculate:
            ground_truth = result.get("ground_truth", "")
            generated_code = result.get("generated_code", "")

            lang = _infer_language_from_result(result, fallback=language_hint)

            if ground_truth and generated_code:
                em_score = _call_em(generated_code, ground_truth, lang)
                es_score = _call_es(generated_code, ground_truth, lang)
                bleu_score = _safe_float(evaluate_bleu(generated_code, ground_truth), 0.0)
                codebleu_score = _call_codebleu(generated_code, ground_truth, lang)
            else:
                print(f"Warning: Missing ground_truth or generated_code in result {i}")
                em_score = 0.0
                es_score = 0.0
                bleu_score = 0.0
                codebleu_score = 0.0
        else:
            em_score = _safe_float(result.get("em_score", 0.0), 0.0)
            es_score = _safe_float(result.get("es_score", 0.0), 0.0)
            bleu_score = _safe_float(result.get("bleu_score", 0.0), 0.0)
            codebleu_score = _safe_float(result.get("codebleu_score", 0.0), 0.0)

        em_scores.append(em_score)
        es_scores.append(es_score)
        bleu_scores.append(bleu_score)
        codebleu_scores.append(codebleu_score)

    avg_em = sum(em_scores) / len(em_scores) if em_scores else 0.0
    avg_es = sum(es_scores) / len(es_scores) if es_scores else 0.0
    avg_bleu = sum(bleu_scores) / len(bleu_scores) if bleu_scores else 0.0
    avg_codebleu = sum(codebleu_scores) / len(codebleu_scores) if codebleu_scores else 0.0

    return avg_em, avg_bleu, avg_es, avg_codebleu


def find_result_files(results_dir: str, model_pattern: str = None, language: str = None) -> List[str]:
    """Find .jsonl result files matching criteria."""
    import glob

    pattern = "responses_*.jsonl"
    if model_pattern and language:
        pattern = f"responses_*{model_pattern}*_{language}.jsonl"
    elif model_pattern:
        pattern = f"responses_*{model_pattern}*.jsonl"
    elif language:
        pattern = f"responses_*_{language}.jsonl"

    search_path = os.path.join(results_dir, pattern)
    files = glob.glob(search_path)
    return sorted(files)


def evaluate_single_file(
    file_path: str,
    recalculate: bool = False,
    language_hint: str = ""
) -> Tuple[float, float, float, float]:
    """Evaluate a single result file."""
    filename = os.path.basename(file_path)
    print(f"\nEvaluating {filename}...")

    results = load_existing_results(file_path)
    if not results:
        print(f"No results found in {file_path}")
        return 0.0, 0.0, 0.0, 0.0

    avg_em, avg_bleu, avg_es, avg_codebleu = calculate_metrics_from_results(
        results, recalculate, language_hint=language_hint
    )

    print(f"Results for {filename}:")
    print(f"  EM       : {avg_em:.4f}")
    print(f"  BLEU     : {avg_bleu:.4f}")
    print(f"  ES       : {avg_es:.4f}")
    print(f"  CodeBLEU : {avg_codebleu:.4f}")
    print(f"  Samples  : {len(results)}")

    return avg_em, avg_bleu, avg_es, avg_codebleu


def main():
    parser = argparse.ArgumentParser(description="Evaluate existing .jsonl result files")

    # File selection arguments
    parser.add_argument("--results_dir", type=str, default="eval_results_prompts",
                        help="Directory containing .jsonl result files")
    parser.add_argument("--file", type=str,
                        help="Specific .jsonl file to evaluate (overrides pattern search)")
    parser.add_argument("--model_pattern", type=str,
                        help="Pattern to match in model names (e.g., 'qwen2.5-coder-3b-lora')")
    parser.add_argument("--language", type=str, choices=["hls", "systemverilog", "vhdl", "chisel"],
                        help="Filter by language (also used as hint when --recalculate)")

    # Evaluation mode
    parser.add_argument("--recalculate", action="store_true",
                        help="Recalculate metrics from ground_truth/generated_code instead of using stored scores")

    # Output options
    parser.add_argument("--summary_file", type=str,
                        help="Save summary to CSV file")

    args = parser.parse_args()

    # Find files to evaluate
    if args.file:
        files_to_evaluate = [args.file]
    else:
        files_to_evaluate = find_result_files(args.results_dir, args.model_pattern, args.language)

    if not files_to_evaluate:
        print(f"No result files found in {args.results_dir}")
        if args.model_pattern:
            print(f"with model pattern: {args.model_pattern}")
        if args.language:
            print(f"for language: {args.language}")
        return

    print(f"Found {len(files_to_evaluate)} result file(s) to evaluate:")
    for f in files_to_evaluate:
        print(f"  - {os.path.basename(f)}")

    # Evaluate each file
    all_results = []
    for file_path in files_to_evaluate:
        filename = os.path.basename(file_path)
        avg_em, avg_bleu, avg_es, avg_codebleu = evaluate_single_file(
            file_path, args.recalculate, language_hint=(args.language or "")
        )

        all_results.append({
            "filename": filename,
            "em": avg_em,
            "bleu": avg_bleu,
            "es": avg_es,
            "codebleu": avg_codebleu,
            "file_path": file_path
        })

    # Print summary
    print("\n" + "=" * 60)
    print("SUMMARY OF ALL EVALUATIONS:")
    print("=" * 60)
    for result in all_results:
        print(
            f"{result['filename']}: "
            f"EM={result['em']:.4f}, BLEU={result['bleu']:.4f}, ES={result['es']:.4f}, CodeBLEU={result['codebleu']:.4f}"
        )

    # Save summary if requested
    if args.summary_file:
        import csv
        with open(args.summary_file, 'w', newline='', encoding="utf-8") as csvfile:
            fieldnames = ['filename', 'em', 'bleu', 'es', 'codebleu', 'file_path']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for result in all_results:
                writer.writerow(result)
        print(f"\nSummary saved to {args.summary_file}")


if __name__ == "__main__":
    main()
