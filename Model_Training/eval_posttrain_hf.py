#!/usr/bin/env python3
"""
Evaluation script (LOCAL LoRA model) for repository blank completion.
Adapted to evaluate models trained via PEFT/LoRA.
"""

import json
import os
import time
import re
import sys
from typing import Dict, List, Tuple, Optional
from tqdm import tqdm
import traceback
import argparse

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel  # Added for LoRA support

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
LIB_DIR = os.path.join(PARENT_DIR, "Model_evaluation/lib_function")
if LIB_DIR not in sys.path:
    sys.path.append(LIB_DIR)

try:
    from exact_match import evaluate_em, evaluate_es
    from codebleu import evaluate_bleu
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure exact_match.py and codebleu.py are in lib_function/ or same directory")
    exit(1)

# ---- Tokenizer + prompt truncation helpers ----

_TOKENIZER_CACHE = {}


from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_io import load_test_data, item_id
def _load_tokenizer(candidate: str):
    """Load a tokenizer, falling back to the slow variant when fast loading is unavailable."""
    try:
        return AutoTokenizer.from_pretrained(candidate, trust_remote_code=True)
    except ValueError as exc:
        if "backend tokenizer" not in str(exc):
            raise
        return AutoTokenizer.from_pretrained(candidate, trust_remote_code=True, use_fast=False)

def get_tokenizer(name: str):
    """Lazy-load and cache tokenizer by name/path."""
    if name not in _TOKENIZER_CACHE:
        _TOKENIZER_CACHE[name] = _load_tokenizer(name)
    return _TOKENIZER_CACHE[name]

def resolve_tokenizer_source(adapter_path: str, base_model_path: str) -> str:
    """
    Prefer tokenizer assets saved alongside the adapter, but fall back to the base model
    when the adapter directory is incomplete.
    """
    tokenizer_files = (
        "tokenizer.json",
        "tokenizer_config.json",
        "vocab.json",
        "merges.txt",
        "sentencepiece.bpe.model",
        "spiece.model",
    )
    if os.path.isdir(adapter_path) and any(os.path.exists(os.path.join(adapter_path, name)) for name in tokenizer_files):
        return adapter_path
    return base_model_path

def ensure_adapter_weights_exist(adapter_path: str) -> None:
    adapter_weight_files = ("adapter_model.safetensors", "adapter_model.bin")
    if any(os.path.exists(os.path.join(adapter_path, name)) for name in adapter_weight_files):
        return
    raise FileNotFoundError(
        f"No LoRA adapter weights found under {adapter_path}. "
        "Expected adapter_model.safetensors or adapter_model.bin."
    )

LINE_PROMPT_PREFIX = """You are a precise code-completion model completing a repository blank completion task. Input: a repository concatenation where each file of the repo is wrapped in `--- FILE: <repo_name>/<rel/path/to/file> (BEGIN) ---
<file content...>
--- FILE: <repo name>/<rel/path/to/file> (END) ---
`. Some lines have been replaced by the exact token `<TARGET>`. Your task: reconstruct **only** the missing code span, using the repository context. Note that for certain large repositories, functions of lesser importance were removed of their implementation, and only the signature/documentation were kept for the sake of simplicity.

OUTPUT: the reconstructed code span (and nothing else)."""


def extract_hls_code(llm_output: str) -> str:
    """Clean model outputs: remove code fences, leading language tags, empty lines."""
    if not isinstance(llm_output, str):
        llm_output = str(llm_output)
    cleaned = re.sub(r"^\s*\w+\s*\n", "", llm_output)
    cleaned = re.sub(r"```[\w]*", "", cleaned)
    lines = [line.rstrip() for line in cleaned.splitlines()]
    lines = [line for line in lines if line.strip() != ""]
    return "\n".join(lines)

def build_truncated_prompt(
    left_context: str,
    right_context: str,
    replacement_token: str,
    max_prompt_tokens: int,
    tokenizer_name: str,
) -> str:
    right_context = ""  # Preceding-context-only protocol.
    tokenizer = get_tokenizer(tokenizer_name)
    prefix_str = LINE_PROMPT_PREFIX + "\n"

    prefix_tokens = tokenizer.encode(prefix_str, add_special_tokens=False)
    left_tokens = tokenizer.encode(left_context or "", add_special_tokens=False)
    right_tokens = tokenizer.encode(right_context or "", add_special_tokens=False)
    repl_tokens = tokenizer.encode(replacement_token, add_special_tokens=False)

    if max_prompt_tokens is None or max_prompt_tokens <= 0:
        combined = prefix_tokens + left_tokens + repl_tokens + right_tokens
        return tokenizer.decode(combined, clean_up_tokenization_spaces=False)

    budget = max_prompt_tokens - len(prefix_tokens)
    if budget <= 0:
        return tokenizer.decode(prefix_tokens[:max_prompt_tokens], clean_up_tokenization_spaces=False)

    core_total = len(left_tokens) + len(repl_tokens) + len(right_tokens)
    if core_total <= budget:
        body_tokens = left_tokens + repl_tokens + right_tokens
    else:
        lr_budget = max(budget - len(repl_tokens), 0)
        left_budget = min(len(left_tokens), lr_budget // 2)
        right_budget = min(len(right_tokens), lr_budget - left_budget)
        extra = lr_budget - (left_budget + right_budget)
        if extra > 0:
            add_left = min(extra, len(left_tokens) - left_budget)
            left_budget += add_left
            right_budget += min(extra - add_left, len(right_tokens) - right_budget)

        body_tokens = left_tokens[-left_budget:] + repl_tokens + right_tokens[:right_budget]

    return tokenizer.decode(prefix_tokens + body_tokens, clean_up_tokenization_spaces=False)

# -----------------------
# Local LoRA Model Wrapper
# -----------------------

class LocalHFModel:
    def __init__(
        self,
        base_model_path: str,
        adapter_path: str,  # Path to LoRA weights
        device: str = "cuda",
        torch_dtype: str = "auto",
        max_new_tokens: int = 64,
        temperature: float = 0.0,
        top_p: float = 1.0,
        do_sample: bool = False,
    ):
        self.max_new_tokens = max_new_tokens
        self.temperature = temperature
        self.top_p = top_p
        self.do_sample = do_sample
        self.device = device if torch.cuda.is_available() else "cpu"
        self.tokenizer_source = resolve_tokenizer_source(adapter_path, base_model_path)

        # Prefer tokenizer files saved with the adapter, but fall back to the base model.
        self.tokenizer = _load_tokenizer(self.tokenizer_source)

        dtype = torch.float16 if torch_dtype == "fp16" else (torch.bfloat16 if torch_dtype == "bf16" else torch.float32)

        # 1. Load Base Model
        print(f"Loading base model from {base_model_path}...")
        model = AutoModelForCausalLM.from_pretrained(
            base_model_path,
            trust_remote_code=True,
            torch_dtype=dtype,
            device_map="auto" if self.device == "cuda" else None
        )

        # 2. Load LoRA Adapters
        print(f"Loading LoRA adapters from {adapter_path}...")
        ensure_adapter_weights_exist(adapter_path)
        self.model = PeftModel.from_pretrained(model, adapter_path)

        if self.tokenizer.pad_token_id is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token

        self.model.eval()

    @torch.inference_mode()
    def __call__(self, prompt: str) -> str:
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.model.device)
        out = self.model.generate(
            **inputs,
            max_new_tokens=self.max_new_tokens,
            do_sample=self.do_sample,
            temperature=self.temperature if self.do_sample else None,
            top_p=self.top_p if self.do_sample else None,
            eos_token_id=self.tokenizer.eos_token_id,
            pad_token_id=self.tokenizer.pad_token_id,
        )
        gen_ids = out[0][inputs["input_ids"].shape[-1]:]
        return self.tokenizer.decode(gen_ids, skip_special_tokens=True)

def evaluate_single_model(
    model_func,
    model_name: str,
    test_data: List[Dict],
    output_dir: str,
    language: str,
    max_prompt_tokens: int,
    tokenizer_name: str,
) -> Tuple[float, float, float]:
    print(f"\nEvaluating {model_name} on {language}...")
    os.makedirs(output_dir, exist_ok=True)
    responses_file = os.path.join(output_dir, f"responses_{model_name}_{language}.jsonl")

    results = []
    em_scores, es_scores, bleu_scores = [], [], []

    with open(responses_file, "w", encoding="utf-8") as resp_f:
        for i, entry in enumerate(tqdm(test_data, desc=f"Processing {model_name}")):
            left_context = entry.get("left_context", "")
            right_context = entry.get("right_context", "")
            ground_truth = entry.get("groundtruth", "")
            repo_name = entry.get("task_id", f"entry_{i}")

            prompt = build_truncated_prompt(
                left_context, right_context, "<TARGET>", max_prompt_tokens, tokenizer_name
            )

            start = time.time()
            model_response = model_func(prompt)
            duration = time.time() - start

            generated_code = extract_hls_code(model_response)

            em_score = evaluate_em(generated_code, ground_truth, lang=language)
            es_score = evaluate_es(generated_code, ground_truth, lang=language)
            bleu_score = evaluate_bleu(generated_code, ground_truth)

            em_scores.append(em_score)
            es_scores.append(es_score)
            bleu_scores.append(bleu_score)

            detailed = {
                "repo_name": repo_name,
                "ground_truth": ground_truth,
                "item_id": item_id(entry, language),
                "path": entry.get("path", ""),
                "generated_code": generated_code,
                "em_score": float(em_score),
                "es_score": float(es_score),
                "bleu_score": float(bleu_score),
                "time_s": float(f"{duration:.2f}"),
            }
            resp_f.write(json.dumps(detailed, ensure_ascii=False) + "\n")

    if len(em_scores) != len(test_data):
        raise RuntimeError(f"Incomplete evaluation: {len(em_scores)}/{len(test_data)} samples")
    avg_em = sum(em_scores) / len(em_scores) if em_scores else 0.0
    avg_es = sum(es_scores) / len(es_scores) if es_scores else 0.0
    avg_bleu = sum(bleu_scores) / len(bleu_scores) if bleu_scores else 0.0
    return avg_em, avg_bleu, avg_es


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-jsonl", required=True, help="External evaluation JSONL.")
    parser.add_argument("--language", type=str, default="vhdl", choices=["hls", "systemverilog", "vhdl", "chisel"])
    parser.add_argument("--output_dir", type=str, required=True)
    parser.add_argument("--max_prompt_tokens", type=int, default=2048)

    # Model Paths
    parser.add_argument("--base_model", type=str, required=True, help="Path to the base pre-trained model")
    parser.add_argument("--adapter_path", type=str, required=True, help="Path to the LoRA output directory")

    # Inference config
    parser.add_argument("--max_new_tokens", type=int, default=64)
    parser.add_argument("--dtype", type=str, default="auto", choices=["auto", "fp16", "bf16"])
    parser.add_argument("--model_tag", type=str, help="Name identifier for the model being evaluated", required=True)
    args = parser.parse_args()

    test_data = load_test_data(args.test_jsonl)

    # Initialize model with adapters
    model_wrapper = LocalHFModel(
        base_model_path=args.base_model,
        adapter_path=args.adapter_path,
        torch_dtype=args.dtype,
        max_new_tokens=args.max_new_tokens,
    )

    avg_em, avg_bleu, avg_es = evaluate_single_model(
        model_func=model_wrapper,
        model_name=args.model_tag,
        test_data=test_data,
        output_dir=args.output_dir,
        language=args.language,
        max_prompt_tokens=args.max_prompt_tokens,
        tokenizer_name=model_wrapper.tokenizer_source,
    )

    print(f"\nFinal Results: EM: {avg_em:.4f}, BLEU: {avg_bleu:.4f}, ES: {avg_es:.4f}")

if __name__ == "__main__":
    main()
