#!/usr/bin/env python3
"""Run one repository test command per prediction using an external harness manifest."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from collections import Counter
from quickstart_score import load_dataset, load_jsonl

EXPECTED_COUNTS = {"chisel": 323, "systemverilog": 508, "vhdl": 496, "hls": 456}


def index_records(path):
    records = {}
    for number, record in load_jsonl(path):
        key = record.get("item_id")
        if not key or key in records:
            raise ValueError(f"{path}:{number}: missing or duplicate item_id")
        records[key] = record
    return records


def run_one(harness, prediction, reference, repo_root, timeout):
    repo = (repo_root / harness["repository"]).resolve()
    if not repo.is_relative_to(repo_root.resolve()) or not repo.is_dir():
        raise ValueError("Repository must exist under --repo-root")
    command = harness.get("command")
    if not isinstance(command, list) or not command or not all(isinstance(x,str) for x in command):
        raise ValueError("Each harness requires an argv list for command")
    with tempfile.TemporaryDirectory(prefix="mhrc-functional-") as directory:
        work = Path(directory) / "repository"
        shutil.copytree(repo, work, ignore=shutil.ignore_patterns(".git"))
        target = (work / harness["target_file"]).resolve()
        if not target.is_relative_to(work.resolve()):
            raise ValueError("target_file must be inside the repository")
        content = target.read_bytes()
        start, end = harness["start_byte"], harness["end_byte"]
        if not isinstance(start,int) or not isinstance(end,int) or not (0 <= start <= end <= len(content)):
            raise ValueError("Invalid completion byte offsets")
        if content[start:end] != reference.encode("utf-8"):
            raise ValueError("Target span differs from dataset ground truth")
        target.write_bytes(content[:start] + prediction.encode("utf-8") + content[end:])
        try:
            completed = subprocess.run(command, cwd=work, capture_output=True, text=True,
                                       timeout=timeout, errors="replace")
        except subprocess.TimeoutExpired:
            return {"passed": False, "status": "timeout"}
        return {"passed": completed.returncode == 0, "status": "completed",
                "returncode": completed.returncode,
                "stdout": completed.stdout, "stderr": completed.stderr}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", required=True, type=Path)
    parser.add_argument("--predictions", required=True, type=Path)
    parser.add_argument("--harnesses", required=True, type=Path)
    parser.add_argument("--repo-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--language", choices=sorted(EXPECTED_COUNTS))
    parser.add_argument("--timeout", type=float, default=300)
    parser.add_argument("--require-full-test", action="store_true")
    args = parser.parse_args()
    dataset = load_dataset(args.dataset, args.language)
    predictions, harnesses = index_records(args.predictions), index_records(args.harnesses)
    if set(dataset) != set(predictions) or set(dataset) != set(harnesses):
        parser.error("Dataset, predictions, and harnesses must have identical item_id coverage")
    counts = Counter(x["language"] for x in dataset.values())
    if args.require_full_test and counts != EXPECTED_COUNTS:
        parser.error(f"Full test split requires {EXPECTED_COUNTS}; found {dict(counts)}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    passed = Counter()
    with args.output.open("x", encoding="utf-8") as stream:
        for key, item in dataset.items():
            prediction = predictions[key].get("generated_code", predictions[key].get("prediction"))
            if not isinstance(prediction,str): raise ValueError(f"{key}: missing generated_code")
            result = run_one(harnesses[key], prediction, item["reference"], args.repo_root, args.timeout)
            passed[item["language"]] += result["passed"]
            stream.write(json.dumps({"item_id": key, "language": item["language"], **result}) + "\n")
            stream.flush()
    for language in sorted(counts):
        print(f"{language}: {passed[language]}/{counts[language]} pass@1={100*passed[language]/counts[language]:.2f}%")
    print(f"Micro pass@1: {100*sum(passed.values())/sum(counts.values()):.2f}%")
    print(f"Language-macro pass@1: {100*sum(passed[k]/counts[k] for k in counts)/len(counts):.2f}%")


if __name__ == "__main__":
    main()
