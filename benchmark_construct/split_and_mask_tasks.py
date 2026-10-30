#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Split Chisel (Scala) completion tasks JSONL into train/valid/test with caps,
and optionally mask a task's target span in the original source file.

Split policy (top-level folder disjoint):
- Group tasks by top-level folder (first path component).
- Sort folders by #tasks ascending (rare folders first).
- Assign whole folders to TEST until reaching test_target (may exceed slightly).
- Then assign whole folders to VALID until reaching valid_target (may exceed slightly).
- Remaining folders go to TRAIN.
- Caps: valid<=100, test<=500 (targets are capped; but once a folder is added, it may exceed slightly).

Mask:
- replace the specified target span in the source file with a single line: "<TARGET>\n"
- span determined by (cursor_line, target_nlines)
"""

import argparse
import json
from collections import defaultdict, Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple, Iterable, Optional


@dataclass
class Task:
    obj: dict
    idx: int  # original jsonl line index (0-based)

    @property
    def rel_file(self) -> str:
        return self.obj["file"]

    @property
    def folder_key(self) -> str:
        """
        Top-level folder (first path component)
        e.g. "XiangShan/src/main/scala/..." -> "XiangShan"
        """
        p = Path(self.rel_file)
        parts = p.parts
        if not parts:
            return "__EMPTY__"
        return parts[0]

    @property
    def cursor_line(self) -> int:
        return int(self.obj["cursor_line"])

    @property
    def target_nlines(self) -> int:
        return int(self.obj["target_nlines"])


# -----------------------------
# IO
# -----------------------------
def read_jsonl(path: Path) -> List[Task]:
    tasks: List[Task] = []
    with path.open("r", encoding="utf-8") as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                raise RuntimeError(f"Bad JSON at line {i+1} in {path}: {e}") from e

            need = {"file", "cursor_line", "target_nlines", "target"}
            if not need.issubset(obj.keys()):
                raise RuntimeError(f"Missing required keys at line {i+1}: need={need}, got={set(obj.keys())}")

            tasks.append(Task(obj=obj, idx=i))
    return tasks


def write_jsonl(path: Path, tasks: Iterable[Task]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for t in tasks:
            f.write(json.dumps(t.obj, ensure_ascii=False) + "\n")


# -----------------------------
# Split logic (whole-folder, rare-first)
# -----------------------------
def split_tasks_whole_folders_rare_first(
    tasks: List[Task],
    test_ratio: float,
    valid_ratio: float,
    test_cap: int,
    valid_cap: int,
) -> Tuple[List[Task], List[Task], List[Task]]:
    """
    Whole-folder split (TOP-LEVEL folder disjoint):
      - Sort folders by #tasks ascending (rare folders first)
      - Put whole folders into TEST until reaching test_target (may exceed slightly)
      - Then put whole folders into VALID until reaching valid_target (may exceed slightly)
      - Remaining folders go to TRAIN
    """
    n = len(tasks)
    test_target = min(test_cap, int(round(n * test_ratio)))
    valid_target = min(valid_cap, int(round(n * valid_ratio)))

    folder_to_tasks: Dict[str, List[Task]] = defaultdict(list)
    for t in tasks:
        folder_to_tasks[t.folder_key].append(t)

    # folders sorted by size ascending (rare first)
    folders = list(folder_to_tasks.keys())
    folders.sort(key=lambda f: (len(folder_to_tasks[f]), f))

    test: List[Task] = []
    valid: List[Task] = []
    train: List[Task] = []

    test_folders = set()
    valid_folders = set()

    # 1) assign to TEST
    for fol in folders:
        if len(test) >= test_target:
            break
        test.extend(folder_to_tasks[fol])
        test_folders.add(fol)

    # 2) assign to VALID from remaining rare folders
    for fol in folders:
        if fol in test_folders:
            continue
        if len(valid) >= valid_target:
            break
        valid.extend(folder_to_tasks[fol])
        valid_folders.add(fol)

    # 3) remaining to TRAIN
    for fol in folders:
        if fol in test_folders or fol in valid_folders:
            continue
        train.extend(folder_to_tasks[fol])

    # sanity: folder disjoint
    def folders_of(ts: List[Task]) -> set:
        return {t.folder_key for t in ts}

    assert folders_of(test).isdisjoint(folders_of(valid))
    assert folders_of(test).isdisjoint(folders_of(train))
    assert folders_of(valid).isdisjoint(folders_of(train))

    return train, valid, test


# -----------------------------
# Masking
# -----------------------------
def mask_target_in_file(root, task, dry_run=False, marker="<TARGET>"):
    """Mask the verified CST byte span, retaining surrounding characters on the same line."""
    source = (root / task.rel_file).resolve()
    if not source.is_relative_to(root.resolve()):
        raise ValueError("Task source must remain inside the supplied root")
    if "start_byte" not in task.obj or "end_byte" not in task.obj:
        raise ValueError("Regenerate task with CST byte offsets before masking")
    data = source.read_bytes()
    start, end = task.obj["start_byte"], task.obj["end_byte"]
    if data[start:end].decode("utf-8") != task.obj["target"]:
        raise ValueError("Target does not match the original source span")
    if dry_run:
        print(f"Would mask {source}:{start}-{end}")
    else:
        source.write_bytes(data[:start] + marker.encode("utf-8") + data[end:])


# -----------------------------
# CLI
# -----------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jsonl", required=True, help="Input tasks jsonl, e.g. chisel_tasks_ts.jsonl")
    ap.add_argument("--root", required=True, help="Root directory of source files")

    ap.add_argument("--out-dir", default="splits", help="Output directory for split jsonl files")

    ap.add_argument("--test-ratio", type=float, default=0.1)
    ap.add_argument("--valid-ratio", type=float, default=0.1)
    ap.add_argument("--test-cap", type=int, default=500)
    ap.add_argument("--valid-cap", type=int, default=100)

    # masking options
    ap.add_argument("--mask-one", action="store_true", help="Mask one task into its source file (replace span with <TARGET>)")
    ap.add_argument("--mask-index", type=int, default=-1, help="Which task index (0-based line index in jsonl) to mask")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--marker", default="<TARGET>\n")

    args = ap.parse_args()

    jsonl_path = Path(args.jsonl).resolve()
    root = Path(args.root).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    tasks = read_jsonl(jsonl_path)
    print(f"Loaded {len(tasks)} tasks from {jsonl_path}")

    train, valid, test = split_tasks_whole_folders_rare_first(
        tasks=tasks,
        test_ratio=args.test_ratio,
        valid_ratio=args.valid_ratio,
        test_cap=args.test_cap,
        valid_cap=args.valid_cap,
    )

    # Write splits
    write_jsonl(out_dir / "train.jsonl", train)
    write_jsonl(out_dir / "valid.jsonl", valid)
    write_jsonl(out_dir / "test.jsonl", test)

    # Stats
    def folder_stats(name: str, lst: List[Task]) -> None:
        c = Counter([t.folder_key for t in lst])
        sizes = sorted(c.values())
        print(f"{name}: {len(lst)} tasks, {len(c)} folders")
        if sizes:
            print(f"  folder size min/median/max = {sizes[0]}/{sizes[len(sizes)//2]}/{sizes[-1]}")

    folder_stats("TRAIN", train)
    folder_stats("VALID", valid)
    folder_stats("TEST ", test)

    train_f = {t.folder_key for t in train}
    valid_f = {t.folder_key for t in valid}
    test_f = {t.folder_key for t in test}
    print("folders disjoint:", train_f.isdisjoint(valid_f) and train_f.isdisjoint(test_f) and valid_f.isdisjoint(test_f))

    # Optional masking
    if args.mask_one:
        if args.mask_index < 0:
            raise ValueError("--mask-one requires --mask-index >= 0 (0-based jsonl line index)")
        found: Optional[Task] = None
        for t in tasks:
            if t.idx == args.mask_index:
                found = t
                break
        if found is None:
            raise ValueError(f"Cannot find task with idx={args.mask_index} in {jsonl_path}")

        mask_target_in_file(
            root=root,
            task=found,
            dry_run=args.dry_run,
            marker=args.marker,
        )


if __name__ == "__main__":
    main()
