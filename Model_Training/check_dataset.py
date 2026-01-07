#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check whether TEST instances' (left + groundtruth + right) appear in TRAIN instances'
(left + groundtruth + right), and optionally FILTER OUT matched TEST instances.

Default behavior:
- Exact match by hashing normalized full text (fast, memory-friendly).
- Optional: ignore whitespace differences (normalize whitespace).
- Reports how many test instances are seen in train (potential leakage).

New outputs:
- --report-matched: write matched TEST lines (potential leakage) with matched_train_meta
- --filtered-test:  write TEST lines that do NOT appear in TRAIN (clean test set)

Example:
  python3 check_fullctx_leak.py \
    --test /path/to/test_content.jsonl \
    --train /path/to/train_content.jsonl \
    --normalize-ws \
    --report-matched /tmp/matched.jsonl \
    --filtered-test /tmp/test_filtered.jsonl
"""

import argparse
import json
import hashlib
import re
from typing import Any, Dict


def safe_str(x: Any) -> str:
    if x is None:
        return ""
    if isinstance(x, str):
        return x
    return str(x)


def normalize_text(s: str, normalize_ws: bool) -> str:
    """
    If normalize_ws=True:
      - unify line endings
      - collapse all whitespace runs to single space
      - strip
    Otherwise:
      - only normalize line endings
    """
    s = (s or "").replace("\r\n", "\n").replace("\r", "\n")
    if normalize_ws:
        s = re.sub(r"\s+", " ", s).strip()
    return s


def make_full_ctx(obj: Dict[str, Any], normalize_ws: bool) -> str:
    left = safe_str(obj.get("left_context"))
    gt = safe_str(obj.get("groundtruth"))  # NOTE: field name is "groundtruth"
    right = safe_str(obj.get("right_context"))
    full = left + gt + right
    return normalize_text(full, normalize_ws)


def hash_text(s: str) -> str:
    return hashlib.sha1(s.encode("utf-8", errors="ignore")).hexdigest()


def iter_jsonl(path: str):
    with open(path, "r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            line = line.rstrip("\n")
            if not line.strip():
                continue
            try:
                yield line_no, json.loads(line)
            except Exception:
                yield line_no, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test", required=True, help="Path to TEST jsonl")
    ap.add_argument("--train", required=True, help="Path to TRAIN jsonl")
    ap.add_argument(
        "--normalize-ws",
        action="store_true",
        help="If set, ignore whitespace differences by collapsing all whitespace.",
    )
    ap.add_argument(
        "--max-train",
        type=int,
        default=0,
        help="If >0, only read first N non-empty TRAIN lines (debug/speed).",
    )
    ap.add_argument(
        "--report-matched",
        default="",
        help="If set, write matched TEST lines (with matched_train_meta) to this jsonl path.",
    )
    ap.add_argument(
        "--filtered-test",
        default="",
        help="If set, write TEST lines that do NOT appear in TRAIN to this jsonl path (clean test).",
    )
    args = ap.parse_args()

    # 1) Build TRAIN hash set
    train_hashes = set()
    train_bad = 0
    train_missing = 0
    train_total = 0

    # store first occurrence meta: hash -> (task_id, path, lineno)
    train_meta = {}

    for line_no, obj in iter_jsonl(args.train):
        if obj is None:
            train_bad += 1
            continue

        train_total += 1
        if args.max_train and train_total > args.max_train:
            break

        if "left_context" not in obj or "right_context" not in obj or "groundtruth" not in obj:
            train_missing += 1
            continue

        full = make_full_ctx(obj, args.normalize_ws)
        if full == "":
            continue

        h = hash_text(full)
        train_hashes.add(h)
        if h not in train_meta:
            train_meta[h] = {
                "train_task_id": obj.get("task_id", ""),
                "train_path": obj.get("path", ""),
                "train_lineno": line_no,
            }

    print("=== TRAIN index built ===")
    print(f"Train file: {args.train}")
    print(f"Train lines read: {train_total}")
    print(f"Train bad json: {train_bad}")
    print(f"Train missing fields: {train_missing}")
    print(f"Unique train full_ctx hashes: {len(train_hashes)}")
    print()

    # 2) Scan TEST and count matches + optionally write outputs
    test_total = 0
    test_bad = 0
    test_missing = 0
    test_empty = 0
    test_matched = 0
    test_kept = 0

    out_matched = open(args.report_matched, "w", encoding="utf-8") if args.report_matched else None
    out_filtered = open(args.filtered_test, "w", encoding="utf-8") if args.filtered_test else None

    try:
        for line_no, obj in iter_jsonl(args.test):
            if obj is None:
                test_bad += 1
                continue

            test_total += 1
            if "left_context" not in obj or "right_context" not in obj or "groundtruth" not in obj:
                test_missing += 1
                continue

            full = make_full_ctx(obj, args.normalize_ws)
            if full == "":
                test_empty += 1
                continue

            h = hash_text(full)
            if h in train_hashes:
                # matched => leakage candidate, FILTER OUT from clean test
                test_matched += 1
                if out_matched:
                    obj2 = dict(obj)
                    obj2["matched_train_meta"] = train_meta.get(h, {})
                    obj2["test_lineno"] = line_no
                    out_matched.write(json.dumps(obj2, ensure_ascii=False) + "\n")
            else:
                # not matched => keep
                test_kept += 1
                if out_filtered:
                    out_filtered.write(json.dumps(obj, ensure_ascii=False) + "\n")
    finally:
        if out_matched:
            out_matched.close()
        if out_filtered:
            out_filtered.close()

    # 3) Report
    denom = max(1, (test_total - test_bad - test_missing - test_empty))
    ratio = test_matched / denom * 100.0

    print("=== TEST vs TRAIN full-context match ===")
    print(f"Test file: {args.test}")
    print(f"Test lines read: {test_total}")
    print(f"Test bad json: {test_bad}")
    print(f"Test missing fields: {test_missing}")
    print(f"Test empty full_ctx: {test_empty}")
    print(f"Matched test full_ctx in train: {test_matched}")
    print(f"Match ratio: {ratio:.4f}%  (denom={denom})")
    print(f"Kept test instances (not in train): {test_kept}")

    if args.report_matched:
        print(f"Matched details written to: {args.report_matched}")
    if args.filtered_test:
        print(f"Filtered TEST written to: {args.filtered_test}")


if __name__ == "__main__":
    main()
