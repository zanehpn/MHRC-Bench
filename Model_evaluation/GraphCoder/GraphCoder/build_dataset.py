import json
import os
from pathlib import Path

def assemble_dataset(test_content_path, repo_base_dir, output_path):
    dataset = []
    repo_counters = {}

    # 1. Load the test content
    if not os.path.exists(test_content_path):
        print(f"Error: {test_content_path} not found.")
        return

    with open(test_content_path, 'r', encoding='utf-8') as f:
        for line in f:
            if not line.strip():
                continue
            
            data = json.loads(line)
            repo_name = data.get("task_id") # e.g., "hls_tutorial_examples"
            rel_path = data.get("path")     # e.g., "hls_tutorial_examples/example_7/..."
            left_context = data.get("left_context", "")
            right_context = data.get("right_context", "")
            ground_truth = data.get("groundtruth", "")

            # --- FIX 1: Join directly because rel_path already contains the repo folder ---
            full_path = os.path.join(repo_base_dir, rel_path)
            
            if not os.path.exists(full_path):
                print(f"Warning: File not found {full_path}. Skipping.")
                continue

            with open(full_path, 'r', encoding='utf-8') as src_file:
                file_content = src_file.read()

            # 3. Calculate Line Numbers
            context_lines = left_context.splitlines()
            line_no = len(context_lines) 
            
            start_index = file_content.find(left_context)
            if start_index != -1:
                content_before_target = file_content[:start_index + len(left_context)]
                line_no = content_before_target.count('\n')
                context_start_lineno = file_content[:start_index].count('\n')
            else:
                context_start_lineno = 0
                line_no = len(context_lines)

            # 4. Generate Task ID
            count = repo_counters.get(repo_name, 0)
            formatted_task_id = f"{repo_name}/{count}"
            repo_counters[repo_name] = count + 1

            # --- FIX 2: Build fpath_tuple without duplicating repo_name ---
            # Since rel_path is "hls_tutorial_examples/path/to/file", 
            # Path(rel_path).parts already starts with "hls_tutorial_examples"
            fpath_parts = list(Path(rel_path).parts)

            # 6. Assemble the entry
            entry = {
                "prompt": left_context,
                "metadata": {
                    "task_id": formatted_task_id,
                    "ground_truth": ground_truth,
                    "fpath_tuple": fpath_parts,
                    "context_start_lineno": context_start_lineno,
                    "line_no": line_no,
                    "right_context": right_context
                }
            }
            dataset.append(entry)

    # 7. Write to graphcoder.jsonl
    with open(output_path, 'w', encoding='utf-8') as out_f:
        for item in dataset:
            out_f.write(json.dumps(item) + '\n')
    
    print(f"Successfully assembled {len(dataset)} entries into {output_path}")

if __name__ == "__main__":
    _repo_root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..")
    TEST_CONTENT_CHISEL = os.path.join(_repo_root, 'chisel_dataset', 'test_content.jsonl')
    REPO_DIR_CHISEL = os.path.join(_repo_root, 'chisel')
    OUTPUT_FILE_CHISEL = 'graphcoder_chisel_fim.jsonl'

    TEST_CONTENT_HLS = os.path.join(_repo_root, 'hls_dataset', 'test_content.jsonl')
    REPO_DIR_HLS = os.path.join(_repo_root, 'hls')
    OUTPUT_FILE_HLS = 'graphcoder_hls_fim.jsonl'

    TEST_CONTENT_VERILOG = os.path.join(_repo_root, 'systemverilog_dataset', 'test_content.jsonl')
    REPO_DIR_VERILOG = os.path.join(_repo_root, 'systemverilog')
    OUTPUT_FILE_VERILOG = 'graphcoder_verilog_fim.jsonl'

    TEST_CONTENT_VHDL = os.path.join(_repo_root, 'vhdl_dataset', 'test_content.jsonl')
    REPO_DIR_VHDL = os.path.join(_repo_root, 'vhdl')
    OUTPUT_FILE_VHDL = 'graphcoder_vhdl_fim.jsonl'

    #assemble_dataset(TEST_CONTENT_CHISEL, REPO_DIR_CHISEL, OUTPUT_FILE_CHISEL)
    assemble_dataset(TEST_CONTENT_HLS, REPO_DIR_HLS, OUTPUT_FILE_HLS)
    #assemble_dataset(TEST_CONTENT_VERILOG, REPO_DIR_VERILOG, OUTPUT_FILE_VERILOG)
    #assemble_dataset(TEST_CONTENT_VHDL, REPO_DIR_VHDL, OUTPUT_FILE_VHDL)