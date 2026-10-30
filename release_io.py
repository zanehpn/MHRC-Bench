"""Input validation and sample identity shared by all inference entry points."""
import hashlib
import json
from pathlib import Path


def item_id(record, language):
    if record.get("item_id"):
        return str(record["item_id"])
    target = record.get("groundtruth", record.get("ground_truth"))
    if target is None:
        raise ValueError("Missing groundtruth/ground_truth")
    # Original retrieval prompts sometimes omit path; their own manifest IDs remain stable.
    payload = f"{language}\0{record.get('task_id', '')}\0{record.get('path', '')}\0{target}"
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()[:16]


def load_test_data(path):
    records = []
    with Path(path).open(encoding="utf-8") as stream:
        for number, line in enumerate(stream, 1):
            if not line.strip(): continue
            record = json.loads(line)
            if not isinstance(record, dict):
                raise ValueError(f"{path}:{number}: expected a JSON object")
            target = record.get("groundtruth", record.get("ground_truth"))
            if not isinstance(target, str) or not target.strip():
                raise ValueError(f"{path}:{number}: missing or empty completion target")
            record = dict(record)
            record["groundtruth"] = target
            records.append(record)
    if not records:
        raise ValueError(f"{path}: no records")
    return records

_TOKENIZERS = {}


def validate_prompt_budget(prompt, tokenizer_name, max_tokens):
    """Check the complete retrieval prompt, including instruction tokens."""
    if tokenizer_name not in _TOKENIZERS:
        from transformers import AutoTokenizer
        _TOKENIZERS[tokenizer_name] = AutoTokenizer.from_pretrained(tokenizer_name)
    count = len(_TOKENIZERS[tokenizer_name].encode(prompt, add_special_tokens=False))
    if count > max_tokens:
        raise ValueError(f"Prompt contains {count} tokens, exceeding budget {max_tokens}; rebuild retrieval input with room for instructions")
