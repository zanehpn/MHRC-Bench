"""Shared implementation of the paper's EM and ES metrics."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from metrics import evaluate_em, evaluate_es, normalize_code
