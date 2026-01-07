import json
import statistics
from Levenshtein import distance as levenshtein_distance
from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction

def evaluate_em(prediction: str, reference: str) -> float:
    """
    Evaluate exact match between prediction and reference.
    Strips leading/trailing whitespaces and newlines before comparison.
    """
    pred_clean = prediction.strip()
    ref_clean = reference.strip()
    return 1.0 if pred_clean == ref_clean else 0.0

def calculate_metrics(input_file):
    em_scores = []
    lev_distances = []
    bleu_scores = []
    
    # Smoothing for BLEU (essential for sentence-level evaluation)
    smoothie = SmoothingFunction().method1

    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    print(f"Warning: Skipping invalid JSON on line {line_num}")
                    continue
                
                # Extract fields (defaulting to empty string if missing)
                response = str(data.get("response", ""))
                ground_truth = str(data.get("ground_truth", ""))

                # Apply stripping for consistency across all metrics
                # This aligns the character-based metrics with your EM rule
                resp_clean = response.strip()
                gt_clean = ground_truth.strip()

                # 1. Exact Match (using your logic)
                em = evaluate_em(response, ground_truth)
                em_scores.append(em)

                # 2. Levenshtein Distance (on cleaned strings)
                lev = levenshtein_distance(resp_clean, gt_clean)
                normalized_lev = lev / max(len(gt_clean), 1)  # Avoid division by zero
                lev_distances.append(normalized_lev)

                # 3. BLEU Score
                # Tokenization: simple whitespace split
                reference_tokens = [gt_clean.split()]
                candidate_tokens = resp_clean.split()
                
                # Corner case: Both are empty after stripping
                if not gt_clean and not resp_clean:
                    bleu = 1.0
                elif not gt_clean or not resp_clean:
                    bleu = 0.0
                else:
                    bleu = sentence_bleu(reference_tokens, candidate_tokens, smoothing_function=smoothie)
                bleu_scores.append(bleu)

        if not em_scores:
            print("No data processed.")
            return

        # Results calculation
        avg_em = sum(em_scores) / len(em_scores)
        avg_lev = statistics.mean(lev_distances)
        avg_bleu = statistics.mean(bleu_scores)

        print("=" * 40)
        print(f"Results for: {input_file}")
        print("-" * 40)
        print(f"Total Samples:      {len(em_scores)}")
        print(f"Exact Match Rate:   {avg_em:.4%}")
        print(f"Avg Levenshtein:    {avg_lev:.2f}")
        print(f"Avg BLEU Score:     {avg_bleu:.4f}")
        print("=" * 40)

    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")

if __name__ == "__main__":
    calculate_metrics('graphcoder_hls_resp_gpt5.jsonl')
    calculate_metrics('graphcoder_hls_resp_gemini_2.5.jsonl')
    calculate_metrics('graphcoder_hls_resp_grok4.jsonl')

    calculate_metrics('graphcoder_scala_resp_deepseek_v3.jsonl')
    calculate_metrics('graphcoder_scala_resp_gemini_2.5.jsonl')
    calculate_metrics('graphcoder_scala_resp_grok4.jsonl')

    calculate_metrics('graphcoder_verilog_resp_deepseek_v3.jsonl')
    calculate_metrics('graphcoder_verilog_resp_gemini_2.5.jsonl')
    calculate_metrics('graphcoder_verilog_resp_grok4.jsonl')

    calculate_metrics('graphcoder_vhdl_resp_deepseek_v3.jsonl')
    calculate_metrics('graphcoder_vhdl_resp_gemini_2.5.jsonl')
    calculate_metrics('graphcoder_vhdl_resp_grok4.jsonl')

