"""Legacy token-BLEU helper. The paper reports EM and ES, not BLEU/CodeBLEU."""
import re
from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction


def code_tokenize(code):
    return re.findall(r"[A-Za-z_][A-Za-z_0-9]*|\d+|[^\s]", code)


def evaluate_bleu(prediction, reference):
    return sentence_bleu([code_tokenize(reference)], code_tokenize(prediction),
                         smoothing_function=SmoothingFunction().method1)
