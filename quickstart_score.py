#!/usr/bin/env python3
"""Dependency-free, ID-aligned scorer for MHRC-Bench JSONL artifacts."""

import argparse
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path
from metrics import normalize_code, levenshtein


LANGUAGE_ALIASES = {
    "sv": "systemverilog",
    "verilog": "systemverilog",
    "system_verilog": "systemverilog",
    "c": "hls",
    "cpp": "hls",
    "c++": "hls",
    "hls_cpp": "hls",
}
SUPPORTED_LANGUAGES = {"chisel", "hls", "systemverilog", "vhdl"}


def canonical_language(language):
    value = str(language or "").lower().strip()
    return LANGUAGE_ALIASES.get(value, value)






def load_jsonl(path):
    with path.open(encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, 1):
            if not line.strip():
                continue
            try:
                yield line_number, json.loads(line)
            except json.JSONDecodeError as error:
                raise SystemExit(f"{path}:{line_number}: invalid JSON: {error}") from error


def infer_language(record, path, explicit_language):
    language = canonical_language(record.get("language") or explicit_language)
    if not language:
        parent = path.parent.name.lower()
        language = next(
            (candidate for candidate in SUPPORTED_LANGUAGES if parent.startswith(candidate)),
            "",
        )
    if language not in SUPPORTED_LANGUAGES:
        raise SystemExit(
            f"{path}: cannot infer HDL language; add a language field or pass --language"
        )
    return language


def make_item_id(record, language):
    if record.get("item_id"):
        return str(record["item_id"])
    reference = record.get("groundtruth", record.get("ground_truth"))
    required = {
        "task_id": record.get("task_id"),
        "path": record.get("path"),
        "groundtruth": reference,
    }
    missing = [name for name, value in required.items() if value is None]
    if missing:
        raise ValueError(f"cannot derive item_id; missing {', '.join(missing)}")
    payload = (
        f"{language}\0{required['task_id']}\0{required['path']}\0"
        f"{required['groundtruth']}"
    )
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()[:16]


def load_dataset(path, explicit_language):
    dataset = {}
    source_splits = set()
    for line_number, record in load_jsonl(path):
        language = infer_language(record, path, explicit_language)
        reference = record.get("groundtruth", record.get("ground_truth"))
        if reference is None:
            raise SystemExit(f"{path}:{line_number}: missing groundtruth/ground_truth")
        try:
            item_id = make_item_id(record, language)
        except ValueError as error:
            raise SystemExit(f"{path}:{line_number}: {error}") from error
        if item_id in dataset:
            raise SystemExit(f"{path}:{line_number}: duplicate item_id {item_id}")
        dataset[item_id] = {
            "language": language,
            "reference": reference,
            "task_id": record.get("task_id"),
            "path": record.get("path"),
        }
        if record.get("source_split"):
            source_splits.add(str(record["source_split"]))
    if not dataset:
        raise SystemExit(f"{path}: no dataset records")
    print(f"Dataset: {path}")
    print(f"  records={len(dataset)}, unique_item_ids={len(dataset)}")
    if source_splits:
        print(f"  source_split={','.join(sorted(source_splits))}")
    return dataset


def score_predictions(dataset, path, allow_subset):
    seen = set()
    scores = defaultdict(lambda: {"em": [], "es": []})
    model_names = set()
    for line_number, record in load_jsonl(path):
        item_id = str(record.get("item_id", ""))
        if not item_id:
            raise SystemExit(f"{path}:{line_number}: missing item_id")
        if item_id in seen:
            raise SystemExit(f"{path}:{line_number}: duplicate prediction for {item_id}")
        if item_id not in dataset:
            raise SystemExit(f"{path}:{line_number}: item_id {item_id} not found in dataset")
        prediction = record.get("generated_code", record.get("prediction"))
        if prediction is None:
            raise SystemExit(f"{path}:{line_number}: missing generated_code/prediction")
        seen.add(item_id)
        if record.get("model_name"):
            model_names.add(str(record["model_name"]))

        target = dataset[item_id]
        language = target["language"]
        reference = normalize_code(target["reference"], language)
        prediction = normalize_code(prediction, language)
        exact_match = float(prediction == reference)
        denominator = max(1, len(reference), len(prediction))
        edit_similarity = 1.0 - levenshtein(reference, prediction) / denominator
        scores[language]["em"].append(exact_match)
        scores[language]["es"].append(edit_similarity)
        scores["overall"]["em"].append(exact_match)
        scores["overall"]["es"].append(edit_similarity)

    if len(model_names) > 1:
        raise SystemExit("Score one model per prediction file; found multiple model names")
    if not seen:
        raise SystemExit(f"{path}: no prediction records")
    missing = set(dataset).difference(seen)
    if missing and not allow_subset:
        raise SystemExit(
            f"{path}: predictions cover {len(seen)}/{len(dataset)} dataset items; "
            "pass --allow-subset to score a deliberate subset"
        )

    if allow_subset and missing:
        print("SUBSET ONLY: this is not a full-benchmark result.")
    print(f"Predictions: {path}")
    print(
        f"  records={len(seen)}, matched={len(seen)}, missing={len(missing)}, "
        f"models={','.join(sorted(model_names)) or 'unspecified'}"
    )
    for language in sorted(key for key in scores if key != "overall") + ["overall"]:
        values = scores[language]
        print(
            f"  {language:13s} n={len(values['em']):3d} "
            f"EM={100 * sum(values['em']) / len(values['em']):6.2f}% "
            f"ES={100 * sum(values['es']) / len(values['es']):6.2f}%"
        )


    languages = sorted(k for k in scores if k != "overall")
    macro_em = sum(sum(scores[k]["em"]) / len(scores[k]["em"]) for k in languages) / len(languages)
    macro_es = sum(sum(scores[k]["es"]) / len(scores[k]["es"]) for k in languages) / len(languages)
    print(f"  language_macro ({len(languages)} languages): EM={100*macro_em:.2f}% ES={100*macro_es:.2f}%")


def main():
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Validate an MHRC-Bench split and score ID-aligned predictions."
    )
    parser.add_argument(
        "--dataset",
        type=Path,
        required=True,
        help="External evaluation JSONL.",
    )
    parser.add_argument(
        "--predictions",
        type=Path,
        required=True,
        help="Prediction JSONL with item_id and generated_code.",
    )
    parser.add_argument(
        "--language",
        choices=sorted(SUPPORTED_LANGUAGES),
        help="Language of a single-language release split when it has no language field.",
    )
    parser.add_argument(
        "--allow-subset",
        action="store_true",
        help="Allow predictions to cover only a subset of the dataset.",
    )
    parser.add_argument("--require-full-test", action="store_true", help="Require all 1,783 items with the paper's language counts.")
    args = parser.parse_args()

    dataset = load_dataset(args.dataset, args.language)
    if args.require_full_test:
        from collections import Counter
        expected = {"chisel":323, "systemverilog":508, "vhdl":496, "hls":456}
        if Counter(x["language"] for x in dataset.values()) != expected:
            parser.error("Full test split must contain all 1,783 examples with the paper's language counts")
        if args.allow_subset:
            parser.error("--require-full-test cannot be combined with --allow-subset")
    score_predictions(dataset, args.predictions, args.allow_subset)


if __name__ == "__main__":
    main()
