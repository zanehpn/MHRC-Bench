import re
from typing import List
from difflib import SequenceMatcher
import editdistance

try:
    import Levenshtein  # pip install python-Levenshtein
    _HAS_LEV = True
except Exception:
    _HAS_LEV = False

def normalize_code(code: str, lang: str = "") -> str:
    c = code if isinstance(code, str) else str(code)

    # NOTE: regex comment stripping is unsafe inside strings; keep minimal.
    # Use language guard if you must.
    if lang.lower() in {"c", "cpp", "hls", "systemverilog", "verilog"}:
        c = re.sub(r"/\*[\s\S]*?\*/", "", c)
        c = re.sub(r"//.*", "", c)
    elif lang.lower() in {"vhdl"}:
        # VHDL "--" comment stripping can break "a - -1" style; be cautious.
        c = re.sub(r"--.*", "", c)

    lines = [ln.strip() for ln in c.splitlines()]
    lines = [ln for ln in lines if ln.strip() != ""]
    lines = [re.sub(r"\s+", " ", ln) for ln in lines]
    return "\n".join(lines)

def evaluate_em(prediction: str, reference: str, lang: str = "") -> float:
    return 1.0 if normalize_code(prediction, lang) == normalize_code(reference, lang) else 0.0

def _edit_sim_0_1(a: str, b: str) -> float:
    if a == b:
        return 1.0
    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0

    if _HAS_LEV:
        d = Levenshtein.distance(a, b)
        return 1.0 - (d / max(len(a), len(b)))
    else:
        # fallback: not true edit distance, but gives 0~1 similarity
        return SequenceMatcher(None, a, b).ratio()

# old es
# def evaluate_es(predictions: List[str], references: List[str], lang: str = "") -> float:
#     n = min(len(predictions), len(references))
#     if n == 0:
#         return 0.0
#     s = 0.0
#     for pred, ref in zip(predictions[:n], references[:n]):
#         pred_norm = normalize_code(pred, lang)
#         ref_norm = normalize_code(ref, lang)
#         s += _edit_sim_0_1(pred_norm, ref_norm)
#     return s / n


def evaluate_es(predictions, target, lang: str = ""):
    target_str = normalize_code(target, lang)
    ES_scores = []
    prediction_str = normalize_code(predictions, lang)
        # if len(target_lines) == 0 or len(prediction_lines) == 0:
        #     count = count + 1
            #print("Warning: Empty target or prediction for ES computation.")
    ES_scores= 1 - (editdistance.eval(target_str, prediction_str) / max(1, len(target_str), len(prediction_str)))
        
    #print("count:", count)
    return ES_scores