import json

def generate_constant_definition(input_jsonl, output_txt):
    unique_repos = []
    
    # 1. Extract unique repository names from the JSONL
    try:
        with open(input_jsonl, 'r', encoding='utf-8') as f:
            for line in f:
                if not line.strip():
                    continue
                data = json.loads(line)
                # task_id is usually "repo_name/index"
                task_id = data.get("metadata", {}).get("task_id", "")
                if "/" in task_id:
                    repo_name = task_id.split('/')[0]
                    if repo_name not in unique_repos:
                        unique_repos.append(repo_name)
    except FileNotFoundError:
        print(f"Error: {input_jsonl} not found.")
        return

    # 2. Build the class definition string
    lines = []
    lines.append("class CONSTANTS:")
    lines.append("    max_hop = 5")
    lines.append("    max_search_top_k = 10")
    lines.append("    max_statement = 20")
    lines.append('    repo_base_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "vhdl")')
    lines.append('    graph_database_save_dir = f"./context_database"')
    lines.append('    query_graph_save_dir = "./graph_based_query"')
    lines.append('    dataset_dir = "./HW_Repo_Bench/vhdl"')
    
    # Format the repos list
    if unique_repos:
        lines.append("    repos = [")
        for i, repo in enumerate(unique_repos):
            comma = "," if i < len(unique_repos) - 1 else ""
            lines.append(f'             "{repo}"{comma}')
        lines.append("             ]")
    else:
        lines.append("    repos = []")

    lines.append("")

    # Format the repos_language dictionary (mapping all to cpp)
    lines.append("    repos_language = {")
    for i, repo in enumerate(unique_repos):
        comma = "," if i < len(unique_repos) - 1 else ""
        lines.append(f'         "{repo}": "scala"{comma}')
    lines.append("    }")

    # 3. Write to CONSTANT_def.txt
    with open(output_txt, 'w', encoding='utf-8') as out_f:
        out_f.write("\n".join(lines))

    print(f"Successfully generated {output_txt} with {len(unique_repos)} repositories.")

if __name__ == "__main__":
    # Ensure these filenames match your environment
    INPUT_FILE = 'graphcoder_chisel.jsonl'
    OUTPUT_FILE = 'CONSTANT_def_scala.txt'

    generate_constant_definition(INPUT_FILE, OUTPUT_FILE)