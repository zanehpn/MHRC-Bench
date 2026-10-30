#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import argparse
from dataclasses import dataclass
from typing import Dict, List, Optional

import torch
from torch.utils.data import Dataset

from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling,
)

from peft import LoraConfig, get_peft_model, TaskType

LINE_PROMPT_PREFIX = """You are a precise code-completion model completing a repository blank completion task. Input: a repository concatenation where each file of the repo is wrapped in `--- FILE: <repo_name>/<rel/path/to/file> (BEGIN) ---
<file content...>
--- FILE: <repo name>/<rel/path/to/file> (END) ---
`. Some lines have been replaced by the exact token `<TARGET>`. Your task: reconstruct **only** the missing code span, using the repository context. Note that for certain large repositories, functions of lesser importance were removed of their implementation, and only the signature/documentation were kept for the sake of simplicity.

OUTPUT: the reconstructed code span (and nothing else)."""

def read_jsonl(path: str) -> List[Dict]:
    out = []
    with open(path, "r", encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except Exception as e:
                print(f"[WARN] skip line {i}: {e}")
    return out


def build_truncated_prompt(tokenizer, left: str, right: str, max_prompt_tokens: int) -> str:
    """
    训练时同样需要截断：prefix + left + <TARGET> + right
    以 <TARGET> 为中心裁剪 left/right（token级）
    """
    right = ""  # Preceding-context-only protocol.
    prefix = LINE_PROMPT_PREFIX + "\n"
    replacement = "<TARGET>"

    prefix_ids = tokenizer.encode(prefix, add_special_tokens=False)
    left_ids = tokenizer.encode(left or "", add_special_tokens=False)
    repl_ids = tokenizer.encode(replacement, add_special_tokens=False)
    right_ids = tokenizer.encode(right or "", add_special_tokens=False)

    if max_prompt_tokens is None or max_prompt_tokens <= 0:
        ids = prefix_ids + left_ids + repl_ids + right_ids
        return tokenizer.decode(ids, clean_up_tokenization_spaces=False)

    budget = max_prompt_tokens - len(prefix_ids)
    if budget <= 0:
        ids = prefix_ids[:max_prompt_tokens]
        return tokenizer.decode(ids, clean_up_tokenization_spaces=False)

    core_total = len(left_ids) + len(repl_ids) + len(right_ids)
    if core_total <= budget:
        body = left_ids + repl_ids + right_ids
    else:
        lr_budget = max(budget - len(repl_ids), 0)
        left_budget = min(len(left_ids), lr_budget // 2)
        right_budget = min(len(right_ids), lr_budget - left_budget)
        extra = lr_budget - (left_budget + right_budget)
        if extra > 0:
            add_left = min(extra, len(left_ids) - left_budget)
            left_budget += add_left
            extra -= add_left
            right_budget += min(extra, len(right_ids) - right_budget)

        left_tail = left_ids[-left_budget:] if left_budget > 0 else []
        right_head = right_ids[:right_budget] if right_budget > 0 else []
        body = left_tail + repl_ids + right_head

    ids = prefix_ids + body
    return tokenizer.decode(ids, clean_up_tokenization_spaces=False)


class RepoBlankDataset(Dataset):
    """
    关键点：labels 只对 groundtruth 这部分计算loss，其余 token = -100
    """
    def __init__(
        self,
        data: List[Dict],
        tokenizer,
        max_prompt_tokens: int,
        max_answer_tokens: int,
    ):
        self.data = data
        self.tok = tokenizer
        self.max_prompt_tokens = max_prompt_tokens
        self.max_answer_tokens = max_answer_tokens

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx: int) -> Dict[str, torch.Tensor]:
        ex = self.data[idx]
        left = ex.get("left_context", "")
        right = ex.get("right_context", "")
        gt = ex.get("groundtruth", "")

        prompt = build_truncated_prompt(
            tokenizer=self.tok,
            left=left,
            right=right,
            max_prompt_tokens=self.max_prompt_tokens,
        )

        # 训练目标：只输出“那一行”
        # 建议 groundtruth 末尾加 '\n' 让模型学会行结束（可选）
        answer = gt.rstrip("\n") + "\n"
        # 也可以加 eos 更稳定
        if self.tok.eos_token:
            answer = answer + self.tok.eos_token

        prompt_ids = self.tok(prompt, add_special_tokens=False).input_ids
        ans_ids = self.tok(answer, add_special_tokens=False).input_ids

        # 控制 answer 最长
        if self.max_answer_tokens and len(ans_ids) > self.max_answer_tokens:
            ans_ids = ans_ids[: self.max_answer_tokens]

        input_ids = prompt_ids + ans_ids
        attention_mask = [1] * len(input_ids)

        # labels：prompt 部分全部 -100，answer 部分为真实 token
        labels = [-100] * len(prompt_ids) + ans_ids

        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "attention_mask": torch.tensor(attention_mask, dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long),
        }


@dataclass
class PadToMaxLenCollator:
    tokenizer: AutoTokenizer
    pad_to_multiple_of: Optional[int] = 8

    def __call__(self, features: List[Dict[str, torch.Tensor]]) -> Dict[str, torch.Tensor]:
        # 手动 padding：因为 labels 有 -100，需要对齐
        max_len = max(f["input_ids"].shape[0] for f in features)
        if self.pad_to_multiple_of:
            m = self.pad_to_multiple_of
            max_len = ((max_len + m - 1) // m) * m

        pad_id = self.tokenizer.pad_token_id
        if pad_id is None:
            # deepseek-coder base 可能没有 pad_token，通常用 eos 代替
            pad_id = self.tokenizer.eos_token_id

        batch = {}
        for k in ["input_ids", "attention_mask", "labels"]:
            padded = []
            for f in features:
                x = f[k]
                pad_len = max_len - x.shape[0]
                if pad_len <= 0:
                    padded.append(x)
                    continue
                if k == "input_ids":
                    pad = torch.full((pad_len,), pad_id, dtype=torch.long)
                elif k == "attention_mask":
                    pad = torch.zeros((pad_len,), dtype=torch.long)
                else:  # labels
                    pad = torch.full((pad_len,), -100, dtype=torch.long)
                padded.append(torch.cat([x, pad], dim=0))
            batch[k] = torch.stack(padded, dim=0)
        return batch


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--train-jsonl", required=True)
    ap.add_argument("--eval-jsonl", default=None)

    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)

    ap.add_argument("--max-prompt-tokens", type=int, default=2048)
    ap.add_argument("--max-answer-tokens", type=int, default=64)

    ap.add_argument("--epochs", type=int, default=1)
    ap.add_argument("--lr", type=float, default=2e-4)

    ap.add_argument("--per-device-train-batch", type=int, default=1)
    ap.add_argument("--grad-accum", type=int, default=16)
    ap.add_argument("--fp16", action="store_true")
    ap.add_argument("--bf16", action="store_true")

    # LoRA
    ap.add_argument("--lora-r", type=int, default=16)
    ap.add_argument("--lora-alpha", type=int, default=32)
    ap.add_argument("--lora-dropout", type=float, default=0.05)

    args = ap.parse_args()

    tokenizer = AutoTokenizer.from_pretrained(args.model, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token  # 常用做法

    model = AutoModelForCausalLM.from_pretrained(
        args.model,
        trust_remote_code=True,
        torch_dtype=torch.bfloat16 if args.bf16 else (torch.float16 if args.fp16 else None),
        device_map="auto",
    )

    # LoRA 配置：对 CausalLM 常用 target_modules
    # deepseek-coder 系列一般是 LLaMA-like：q_proj/k_proj/v_proj/o_proj + up/down/gate_proj
    lora = LoraConfig(
        task_type=TaskType.CAUSAL_LM,
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        target_modules="all-linear",
    )
    model = get_peft_model(model, lora)
    model.print_trainable_parameters()

    train_data = read_jsonl(args.train_jsonl)
    train_ds = RepoBlankDataset(
        data=train_data,
        tokenizer=tokenizer,
        max_prompt_tokens=args.max_prompt_tokens,
        max_answer_tokens=args.max_answer_tokens,
    )

    eval_ds = None
    if args.eval_jsonl:
        eval_data = read_jsonl(args.eval_jsonl)
        eval_ds = RepoBlankDataset(
            data=eval_data,
            tokenizer=tokenizer,
            max_prompt_tokens=args.max_prompt_tokens,
            max_answer_tokens=args.max_answer_tokens,
        )

    collator = PadToMaxLenCollator(tokenizer=tokenizer)

    targs = TrainingArguments(
        output_dir=args.out,
        num_train_epochs=args.epochs,
        learning_rate=args.lr,
        per_device_train_batch_size=args.per_device_train_batch,
        gradient_accumulation_steps=args.grad_accum,
        logging_steps=20,
        save_steps=500,
        save_total_limit=2,
        eval_strategy="steps" if eval_ds is not None else "no",
        eval_steps=500 if eval_ds is not None else None,
        report_to="none",
        fp16=args.fp16,
        bf16=args.bf16,
        optim="adamw_torch",
        lr_scheduler_type="cosine",
        warmup_ratio=0.03,
    )

    trainer = Trainer(
        model=model,
        args=targs,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        data_collator=collator,
    )

    trainer.train()
    trainer.save_model(args.out)
    tokenizer.save_pretrained(args.out)
    print("Done. Saved to:", args.out)


if __name__ == "__main__":
    main()
