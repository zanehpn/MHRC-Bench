import json
import statistics
import re
import os
import sys

# Try to import tqdm for progress bars; fallback to basic prints if not installed
try:
    from tqdm import tqdm
except ImportError:
    # Minimal fallback if tqdm is missing
    def tqdm(iterable, **kwargs):
        return iterable

# Setup Library Path
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
LIB_DIR = os.path.join(CURRENT_DIR, "..", "..", "lib_function")
if LIB_DIR not in sys.path:
    sys.path.append(LIB_DIR)

try:
    from exact_match import evaluate_em, evaluate_es
    from codebleu import evaluate_bleu
except ImportError as e:
    print(f"Import error: {e}")
    exit(1)

def get_language_from_filename(filename: str) -> str:
    fname = filename.lower()
    if 'hls' in fname: return 'hls'
    if 'vhdl' in fname: return 'vhdl'
    if 'verilog' in fname or 'sv' in fname: return 'verilog'
    if 'scala' in fname or 'chisel' in fname: return 'cpp'
    return ""

def extract_hls_code(llm_output: str) -> str:
    if not isinstance(llm_output, str):
        llm_output = str(llm_output)
    cleaned = re.sub(r"```[\w]*", "", llm_output)
    cleaned = cleaned.replace("```", "")
    return cleaned.strip()

def count_lines(filename):
    """Count lines to initialize progress bar total."""
    with open(filename, 'rb') as f:
        return sum(1 for _ in f)

def calculate_metrics(input_file, file_idx, total_files):
    em_scores = []
    es_scores = []
    bleu_scores = []
    
    lang = get_language_from_filename(input_file)

    if not os.path.exists(input_file):
        print(f"\n[{file_idx}/{total_files}] Skip: {input_file} (Not Found)")
        return

    total_lines = count_lines(input_file)
    
    # Progress indication for the current file
    print(f"\n[{file_idx}/{total_files}] Processing: {input_file}")
    
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            # Wrap the file iterator with tqdm
            for line in tqdm(f, total=total_lines, desc="   Evaluating", unit="samples", leave=False):
                line = line.strip()
                if not line:
                    continue
                
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    continue
                
                response = extract_hls_code(data.get("response", ""))
                ground_truth = extract_hls_code(data.get("ground_truth", ""))

                # 1. Exact Match (Normalized)
                em_scores.append(evaluate_em(response, ground_truth, lang=lang))

                # 2. Edit Similarity (Normalized 0-1)
                es_scores.append(evaluate_es(response, ground_truth, lang=lang))

                # 3. BLEU Score
                bleu_scores.append(evaluate_bleu(response, ground_truth))

        if not em_scores:
            print(f"   No valid samples found in {input_file}.")
            return

        # Calculate averages
        avg_em = sum(em_scores) / len(em_scores)
        avg_es = sum(es_scores) / len(es_scores)
        avg_bleu = sum(bleu_scores) / len(bleu_scores)

        # Print Final Results for this file
        print("-" * 40)
        print(f"Results for: {input_file}")
        print(f"Total Samples:      {len(em_scores)}")
        print(f"Exact Match (EM):   {avg_em:.2%}")
        print(f"Edit Similarity(ES): {avg_es:.2%}")
        print(f"BLEU Score:         {avg_bleu:.4f}")
        print("-" * 40)

    except Exception as e:
        print(f"   Error processing {input_file}: {e}")

if __name__ == "__main__":
    files = [
        'graphcoder_hls_fim.jsonl_gpt5.jsonl',
        'graphcoder_hls_fim.jsonl_deepseek_v3.jsonl',
        'graphcoder_hls_fim.jsonl_gemini_2.5.jsonl',
        'graphcoder_hls_fim.jsonl_grok4.jsonl',

        'graphcoder_scala_fim.jsonl_gpt5.jsonl',
        'graphcoder_scala_fim.jsonl_deepseek_v3.jsonl',
        'graphcoder_scala_fim.jsonl_gemini_2.5.jsonl',
        'graphcoder_scala_fim.jsonl_grok4.jsonl',

        'graphcoder_verilog_fim.jsonl_gpt5.jsonl',
        'graphcoder_verilog_fim.jsonl_deepseek_v3.jsonl',
        'graphcoder_verilog_fim.jsonl_gemini_2.5.jsonl',
        'graphcoder_verilog_fim.jsonl_grok4.jsonl',

        'graphcoder_vhdl_fim.jsonl_gpt5.jsonl',
        'graphcoder_vhdl_fim.jsonl_deepseek_v3.jsonl',
        'graphcoder_vhdl_fim.jsonl_gemini_2.5.jsonl',
        'graphcoder_vhdl_fim.jsonl_grok4.jsonl'
    ]
    
    total_files = len(files)
    print(f"Starting evaluation of {total_files} files...")
    
    for idx, f in enumerate(files, 1):
        calculate_metrics(f, idx, total_files)
    
    print("\nAll evaluations complete.")
