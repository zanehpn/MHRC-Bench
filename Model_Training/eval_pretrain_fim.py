#!/usr/bin/env python3
"""
Evaluation script (LOCAL HF model) for repository blank completion.

- Uses *any* HuggingFace local model passed via --local_model (e.g., Qwen/Qwen2.5-Coder-3B)
- Evaluates generated code against ground truth using exact match, edit similarity, BLEU
- Supports multiple languages: hls, systemverilog, vhdl, chisel
- Keeps your prompt truncation logic
"""

import json
import os
import time
import re
import sys
from typing import Dict, List, Optional, Tuple
from tqdm import tqdm
import traceback
import argparse

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
LIB_DIR = os.path.join(PARENT_DIR, "Model_evaluation/lib_function")
if LIB_DIR not in sys.path:
    sys.path.append(LIB_DIR)

# evaluators
try:
    from exact_match import evaluate_em, evaluate_es
    from codebleu import evaluate_bleu
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure exact_match.py and codebleu.py are in lib_function/ or same directory")
    raise SystemExit(1)

# ---- Tokenizer + prompt truncation helpers ----
_TOKENIZER_CACHE: Dict[str, AutoTokenizer] = {}



from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release_io import load_test_data, item_id
def get_tokenizer(name: str):
    """Lazy-load and cache tokenizer by name/path."""
    if name not in _TOKENIZER_CACHE:
        _TOKENIZER_CACHE[name] = AutoTokenizer.from_pretrained(name, trust_remote_code=True)
    return _TOKENIZER_CACHE[name]


LINE_PROMPT_PREFIX = """You are a precise code-completion model completing a repository blank completion task. Input: a repository concatenation where each file of the repo is wrapped in `--- FILE: <repo_name>/<rel/path/to/file> (BEGIN) ---
<file content...>
--- FILE: <repo name>/<rel/path/to/file> (END) ---
`. Some lines have been replaced by the exact token `<TARGET>`. Your task: reconstruct **only** the missing code span, using the repository context. Note that for certain large repositories, functions of lesser importance were removed of their implementation, and only the signature/documentation were kept for the sake of simplicity.

OUTPUT: the reconstructed code span (and nothing else)."""

COMMON_FIM_TOKEN_SETS: List[Tuple[str, str, str]] = [
    ("<fim_prefix>", "<fim_suffix>", "<fim_middle>"),
    ("<PRE>", "<SUF>", "<MID>"),
    ("<|fim_prefix|>", "<|fim_suffix|>", "<|fim_middle|>"),
    ("<｜fim▁begin｜>", "<｜fim▁hole｜>", "<｜fim▁end｜>"),
]




def extract_hls_code(llm_output: str) -> str:
    """Clean model outputs: remove code fences, leading language tags, empty lines."""
    if not isinstance(llm_output, str):
        llm_output = str(llm_output)

    cleaned = re.sub(r"^\s*\w+\s*\n", "", llm_output)  # remove leading "cpp\n" etc.
    cleaned = re.sub(r"```[\w]*", "", cleaned)         # remove ```cpp
    lines = [line.rstrip() for line in cleaned.splitlines()]
    lines = [line for line in lines if line.strip() != ""]
    return "\n".join(lines)


def _token_exists(tokenizer, token: str) -> bool:
    try:
        vocab = tokenizer.get_vocab()
    except Exception:
        vocab = {}
    return token in vocab


def resolve_fim_tokens(
    tokenizer_name: str,
    fim_prefix_token: Optional[str] = None,
    fim_suffix_token: Optional[str] = None,
    fim_middle_token: Optional[str] = None,
) -> Tuple[str, str, str]:
    if fim_prefix_token and fim_suffix_token and fim_middle_token:
        return fim_prefix_token, fim_suffix_token, fim_middle_token

    tokenizer = get_tokenizer(tokenizer_name)
    for tokens in COMMON_FIM_TOKEN_SETS:
        if all(_token_exists(tokenizer, tok) for tok in tokens):
            return tokens

    raise ValueError(
        "Could not auto-detect FIM tokens for tokenizer "
        f"'{tokenizer_name}'. Pass --fim_prefix_token/--fim_suffix_token/--fim_middle_token explicitly."
    )


def build_truncated_prompt_ids(
    left_context: str,
    right_context: str,
    replacement_token: str,
    max_prompt_tokens: int,
    tokenizer_name: str,
    prompt_mode: str = "fim",
    fim_prefix_token: Optional[str] = None,
    fim_suffix_token: Optional[str] = None,
    fim_middle_token: Optional[str] = None,
) -> List[int]:
    """
    Build either:
      - ltr: PREFIX + left + <TARGET>
      - fim: FIM_PREFIX + left + FIM_SUFFIX + right + FIM_MIDDLE
    and trim left/right symmetrically around the infill site.
    """
    tokenizer = get_tokenizer(tokenizer_name)
    left_text = left_context or ""
    right_text = (right_context or "") if prompt_mode == "fim" else ""
    left_tokens = tokenizer.encode(left_text, add_special_tokens=False)
    right_tokens = tokenizer.encode(right_text, add_special_tokens=False)

    if prompt_mode == "ltr":
        prefix_str = LINE_PROMPT_PREFIX + "\n"
        prefix_tokens = tokenizer.encode(prefix_str, add_special_tokens=False)
        marker_tokens = tokenizer.encode(replacement_token, add_special_tokens=False)
        suffix_tokens: List[int] = []
    elif prompt_mode == "fim":
        prefix_tokens = tokenizer.encode(fim_prefix_token, add_special_tokens=False)
        marker_tokens = tokenizer.encode(fim_suffix_token, add_special_tokens=False)
        suffix_tokens = tokenizer.encode(fim_middle_token, add_special_tokens=False)
    else:
        raise ValueError(f"Unsupported prompt_mode: {prompt_mode}")

    if max_prompt_tokens is None or max_prompt_tokens <= 0:
        return prefix_tokens + left_tokens + marker_tokens + right_tokens + suffix_tokens

    fixed_len = len(prefix_tokens) + len(marker_tokens) + len(suffix_tokens)
    budget = max_prompt_tokens - fixed_len
    if budget <= 0:
        return (prefix_tokens + marker_tokens + suffix_tokens)[: max(0, max_prompt_tokens)]

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

    return prefix_tokens + left_tail + marker_tokens + right_head + suffix_tokens


# -----------------------
# Local HF model wrapper
# -----------------------
class LocalHFModel:
    def __init__(
        self,
        model_name_or_path: str,
        device: str = "cuda",
        torch_dtype: str = "auto",
        max_new_tokens: int = 64,
        temperature: float = 0.0,
        top_p: float = 1.0,
        do_sample: bool = False,
        use_chat_template: bool = False,
        device_map: str = "none",  # "none" or "auto"
    ):
        self.model_name_or_path = model_name_or_path
        self.max_new_tokens = max_new_tokens
        self.temperature = temperature
        self.top_p = top_p
        self.do_sample = do_sample
        self.use_chat_template = use_chat_template

        self.tokenizer = AutoTokenizer.from_pretrained(model_name_or_path, trust_remote_code=True)

        # Some code models have no pad_token; eos is a safe fallback for generation.
        if self.tokenizer.pad_token_id is None and self.tokenizer.eos_token_id is not None:
            self.tokenizer.pad_token = self.tokenizer.eos_token

        # dtype handling
        dtype = None
        if torch_dtype == "fp16":
            dtype = torch.float16
        elif torch_dtype == "bf16":
            dtype = torch.bfloat16
        elif torch_dtype == "auto":
            dtype = None

        # Load model
        load_kwargs = dict(trust_remote_code=True)
        if dtype is not None:
            load_kwargs["torch_dtype"] = dtype

        # If device_map=auto, let HF place layers (useful for larger local models).
        # Otherwise, follow the old behavior and optionally .cuda().
        if device_map == "auto":
            load_kwargs["device_map"] = "auto"
            self.model = AutoModelForCausalLM.from_pretrained(model_name_or_path, **load_kwargs)
            self.device = None  # handled by accelerate / device_map
        else:
            self.model = AutoModelForCausalLM.from_pretrained(model_name_or_path, **load_kwargs)
            if device == "cuda" and torch.cuda.is_available():
                self.model = self.model.cuda()
                self.device = "cuda"
            else:
                self.device = "cpu"

        self.model.eval()

    def _maybe_chatify(self, prompt: str) -> str:
        """
        Optional: wrap prompt with tokenizer chat template (useful for instruct/chat models).
        Disabled by default to preserve original behavior.
        """
        if not self.use_chat_template:
            return prompt

        chat_template = getattr(self.tokenizer, "chat_template", None)
        if not chat_template:
            return prompt

        messages = [{"role": "user", "content": prompt}]
        try:
            rendered = self.tokenizer.apply_chat_template(
                messages,
                tokenize=False,
                add_generation_prompt=True,
            )
            return rendered
        except Exception:
            # If template application fails, fall back to raw prompt.
            return prompt

    @torch.inference_mode()
    def __call__(self, prompt_input) -> str:
        if isinstance(prompt_input, str):
            prompt_input = self._maybe_chatify(prompt_input)

        if self.device is None:
            # device_map="auto" path
            if isinstance(prompt_input, str):
                inputs = self.tokenizer(prompt_input, return_tensors="pt")
            else:
                prompt_ids = list(prompt_input)
                inputs = {
                    "input_ids": torch.tensor([prompt_ids], dtype=torch.long),
                    "attention_mask": torch.ones((1, len(prompt_ids)), dtype=torch.long),
                }
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
        else:
            if isinstance(prompt_input, str):
                inputs = self.tokenizer(prompt_input, return_tensors="pt").to(self.device)
            else:
                prompt_ids = list(prompt_input)
                inputs = {
                    "input_ids": torch.tensor([prompt_ids], dtype=torch.long, device=self.device),
                    "attention_mask": torch.ones((1, len(prompt_ids)), dtype=torch.long, device=self.device),
                }
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

        text = self.tokenizer.decode(gen_ids, skip_special_tokens=True)
        return text


def evaluate_single_model(
    model_func,
    model_name: str,
    test_data: List[Dict],
    output_dir: str,
    language: str,
    max_prompt_tokens: int,
    tokenizer_name: str,
    model_tag: str,
    prompt_mode: str,
    fim_prefix_token: Optional[str],
    fim_suffix_token: Optional[str],
    fim_middle_token: Optional[str],
) -> Tuple[float, float, float]:
    print(f"\nEvaluating {model_name} on {language}...")
    os.makedirs(output_dir, exist_ok=True)

    safe_model_name = re.sub(r"[^A-Za-z0-9._-]+", "_", model_name)
    per_model_file = os.path.join(output_dir, f"eval_{model_tag}_{language}.jsonl")
    responses_file = os.path.join(output_dir, f"responses__{model_tag}_{language}.jsonl")

    open(responses_file, "w", encoding="utf-8").close()

    results = []
    em_scores = []
    es_scores = []
    bleu_scores = []
    appended = 0

    with open(responses_file, "a", encoding="utf-8") as resp_f:
        for i, entry in enumerate(tqdm(test_data, desc=f"Processing {model_name}")):
            try:
                left_context = entry.get("left_context", "")
                right_context = entry.get("right_context", "")
                ground_truth = entry.get("groundtruth", "")
                repo_name = entry.get("task_id", f"entry_{i}")
                replacement_token = "<TARGET>"

                prompt_ids = build_truncated_prompt_ids(
                    left_context=left_context,
                    right_context=right_context,
                    replacement_token=replacement_token,
                    max_prompt_tokens=max_prompt_tokens,
                    tokenizer_name=tokenizer_name,
                    prompt_mode=prompt_mode,
                    fim_prefix_token=fim_prefix_token,
                    fim_suffix_token=fim_suffix_token,
                    fim_middle_token=fim_middle_token,
                )
                if not prompt_ids or not ground_truth:
                    continue
                prompt = get_tokenizer(tokenizer_name).decode(
                    prompt_ids,
                    clean_up_tokenization_spaces=False,
                )
                model_input = prompt_ids if prompt_mode == "fim" else prompt

                start = time.time()
                try:
                    model_response = model_func(model_input)
                except Exception as e:
                    print(f"[ERR] generate failed entry {i} repo={repo_name}: {e}")
                    model_response = ""
                duration = time.time() - start

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
                    "prompt_mode": prompt_mode,
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
                    "prompt_mode": prompt_mode,
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

    with open(per_model_file, "w", encoding="utf-8") as f:
        for r in results:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"Results for {model_name} saved to {per_model_file}")
    print(f"Appended {appended} detailed responses to {responses_file}")

    if len(em_scores) != len(test_data):
        raise RuntimeError(f"Incomplete evaluation: {len(em_scores)}/{len(test_data)} samples")
    avg_em = sum(em_scores) / len(em_scores) if em_scores else 0.0
    avg_es = sum(es_scores) / len(es_scores) if es_scores else 0.0
    avg_bleu = sum(bleu_scores) / len(bleu_scores) if bleu_scores else 0.0
    return avg_em, avg_bleu, avg_es




def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-jsonl", required=True, help="External evaluation JSONL.")
    parser.add_argument(
        "--language",
        type=str,
        default="vhdl",
        choices=["hls", "systemverilog", "vhdl", "chisel"],
    )
    parser.add_argument(
        "--models",
        type=str,
        default="local_hf",
        help=(
            "Comma-separated list of model keys to run. "
            "This script always instantiates the HF model from --local_model, "
            "and registers it under key 'local_hf' and also under the literal model id string."
        ),
    )
    parser.add_argument("--output_dir", type=str, required=True)
    parser.add_argument("--max_prompt_tokens", type=int, default=2048)
    parser.add_argument(
        "--prompt_mode",
        type=str,
        default="fim",
        choices=["fim", "ltr"],
        help="Prompt assembly mode. 'fim' builds infill prompts; 'ltr' keeps the original left-to-right format.",
    )
    parser.add_argument(
        "--tokenizer_name",
        type=str,
        default="auto",
        help=(
            "Tokenizer used for prompt truncation. "
            "Use 'auto' to reuse --local_model's tokenizer (recommended)."
        ),
    )

    # Local HF model options (THIS is the key fix)
    parser.add_argument(
        "--local_model",
        type=str,
        required=True,
        help="Any HuggingFace model id or local path, e.g. Qwen/Qwen2.5-Coder-3B",
    )
    parser.add_argument("--max_new_tokens", type=int, default=64)
    parser.add_argument("--do_sample", action="store_true")
    parser.add_argument("--temperature", type=float, default=0.0)
    parser.add_argument("--top_p", type=float, default=1.0)
    parser.add_argument("--dtype", type=str, default="auto", choices=["auto", "fp16", "bf16"])
    parser.add_argument("--device", type=str, default="cuda", choices=["cuda", "cpu"])
    parser.add_argument("--model_tag", type=str, required=True, help="Name identifier for the model being evaluated")
    parser.add_argument(
        "--use_chat_template",
        action="store_true",
        help="If set and the tokenizer provides a chat template, wrap the prompt as a single user message.",
    )
    parser.add_argument(
        "--device_map",
        type=str,
        default="none",
        choices=["none", "auto"],
        help="Use 'auto' to let HF shard the model across devices (useful for larger models).",
    )
    parser.add_argument("--fim_prefix_token", type=str, default=None, help="Override the FIM prefix token.")
    parser.add_argument("--fim_suffix_token", type=str, default=None, help="Override the FIM suffix token.")
    parser.add_argument("--fim_middle_token", type=str, default=None, help="Override the FIM middle token.")

    args = parser.parse_args()

    language = args.language
    test_file_path = args.test_jsonl.format(language=language)
    output_dir = args.output_dir
    os.makedirs(output_dir, exist_ok=True)

    test_data = load_test_data(test_file_path)
    if not test_data:
        print("No test data loaded. Exiting.")
        return

    # If tokenizer_name is "auto", match truncation tokenizer to the local model.
    tokenizer_name = args.local_model if args.tokenizer_name.strip().lower() == "auto" else args.tokenizer_name

    fim_prefix_token = None
    fim_suffix_token = None
    fim_middle_token = None
    if args.prompt_mode == "fim":
        fim_prefix_token, fim_suffix_token, fim_middle_token = resolve_fim_tokens(
            tokenizer_name=tokenizer_name,
            fim_prefix_token=args.fim_prefix_token,
            fim_suffix_token=args.fim_suffix_token,
            fim_middle_token=args.fim_middle_token,
        )
        print(
            "Using FIM tokens:",
            repr(fim_prefix_token),
            repr(fim_suffix_token),
            repr(fim_middle_token),
        )
        if args.use_chat_template:
            print("Warning: --use_chat_template is enabled with --prompt_mode=fim; most FIM-trained base models expect raw FIM prompts.")

    # init local model once (important)
    local_model = LocalHFModel(
        model_name_or_path=args.local_model,
        device=args.device,
        torch_dtype=args.dtype,
        max_new_tokens=args.max_new_tokens,
        do_sample=args.do_sample,
        temperature=args.temperature,
        top_p=args.top_p,
        use_chat_template=args.use_chat_template,
        device_map=args.device_map,
    )

    # Register under a stable key and also under the literal HF id/path for convenience.
    all_models: Dict[str, callable] = {
        "local_hf": local_model,
        args.local_model: local_model,
    }

    selected_model_names = [m.strip() for m in args.models.split(",") if m.strip()]
    models: Dict[str, callable] = {}
    for name in selected_model_names:
        if name not in all_models:
            print(f"Warning: unknown model key '{name}' – skipping. Available: {list(all_models.keys())}")
            continue
        models[name] = all_models[name]

    if not models:
        print("No valid models selected. Exiting.")
        return

    summary_results: Dict[str, Dict] = {}

    print("Starting evaluation...")
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
                tokenizer_name=tokenizer_name,
                model_tag=args.model_tag,
                prompt_mode=args.prompt_mode,
                fim_prefix_token=fim_prefix_token,
                fim_suffix_token=fim_suffix_token,
                fim_middle_token=fim_middle_token,
            )
            summary_results[model_name] = {
                "avg_em_score": avg_em,
                "avg_bleu_score": avg_bleu,
                "avg_es_score": avg_es,
                "language": language,
                "prompt_mode": args.prompt_mode,
                "local_model": args.local_model,
                "tokenizer_name": tokenizer_name,
                "fim_prefix_token": fim_prefix_token,
                "fim_suffix_token": fim_suffix_token,
                "fim_middle_token": fim_middle_token,
            }
            print(f"\n{model_name} Results on {language}:")
            print(f"  Average EM   : {avg_em:.4f}")
            print(f"  Average BLEU : {avg_bleu:.4f}")
            print(f"  Average ES   : {avg_es:.4f}")

        except Exception as e:
            print(f"Error evaluating {model_name}: {e}")
            traceback.print_exc()
            summary_results[model_name] = {
                "avg_em_score": 0.0,
                "avg_bleu_score": 0.0,
                "avg_es_score": 0.0,
                "language": language,
                "prompt_mode": args.prompt_mode,
                "local_model": args.local_model,
                "tokenizer_name": tokenizer_name,
                "fim_prefix_token": fim_prefix_token,
                "fim_suffix_token": fim_suffix_token,
                "fim_middle_token": fim_middle_token,
                "error": str(e),
            }
            raise

    summary_file = os.path.join(output_dir, f"evaluation_summary_{args.model_tag}_{language}.json")
    with open(summary_file, "w", encoding="utf-8") as f:
        json.dump(summary_results, f, indent=2, ensure_ascii=False)
    print(f"\nSummary results saved to {summary_file}")


if __name__ == "__main__":
    main()
