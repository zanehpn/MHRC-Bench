import json
import os

def process_case_studies():
    # Base directory for the files
    base_dir = "/home/zqy/LLM4CHIP/Multi-hdl-language-repo/Model_training"
    
    # Define the languages to process
    languages = ["chisel", "hls", "systemverilog", "vhdl"]
    
    # Ensure the output directory exists
    output_dir = os.path.join(base_dir, "case_studies")
    os.makedirs(output_dir, exist_ok=True)

    print(f"{'Language':<15} | {'Improved Cases (EM 0 -> 1)':<25}")
    print("-" * 45)

    for lang in languages:
        # Construct file paths
        post_train_path = os.path.join(base_dir, "eval_results_posttrain", f"responses_qwen_coder_7b_base_lora_{lang}.jsonl")
        pre_train_path = os.path.join(base_dir, "eval_results_pretrain", f"responses__qwen_7b_{lang}.jsonl")
        output_path = os.path.join(output_dir, f"{lang}.jsonl")

        count = 0

        try:
            with open(post_train_path, 'r') as f_post, \
                 open(pre_train_path, 'r') as f_pre, \
                 open(output_path, 'w') as f_out:

                # Iterate through both files simultaneously
                for line_post, line_pre in zip(f_post, f_pre):
                    try:
                        data_post = json.loads(line_post)
                        data_pre = json.loads(line_pre)

                        # Extract EM scores
                        em_post = float(data_post.get("em_score", 0))
                        em_pre = float(data_pre.get("em_score", 0))

                        # Check condition: Pre-train EM is 0, Post-train EM is 1
                        if em_pre == 0.0 and em_post == 1.0:
                            
                            # Construct the specific output dictionary
                            case_study = {
                                "repo_name": data_post.get("repo_name"),
                                "pre_training": data_pre.get("generated_code"),  # The code generated before training
                                "post_training": data_post.get("generated_code"), # The code generated after training
                                "ground_truth": data_post.get("ground_truth"),
                                "prompt": data_pre.get("prompt") # Taking prompt from pre-train file (as indicated in your example)
                            }
                            
                            f_out.write(json.dumps(case_study) + "\n")
                            count += 1

                    except json.JSONDecodeError:
                        continue

            print(f"{lang:<15} | {count:<25}")

        except FileNotFoundError as e:
            print(f"Error processing {lang}: File not found - {e}")
        except Exception as e:
            print(f"Error processing {lang}: {e}")

if __name__ == "__main__":
    process_case_studies()