import os
import copy
import signal
from tqdm import tqdm
import networkx as nx
from utils.ccg import create_graph
from utils.slicing import Slicing
from utils.utils import load_jsonl, make_needed_dir, graph_to_json, CONSTANTS, dump_jsonl, CodexTokenizer

# --- Timeout Setup ---
class TimeoutException(Exception):
    pass

def timeout_handler(signum, frame):
    raise TimeoutException

# Register the signal handler
signal.signal(signal.SIGALRM, timeout_handler)

def last_n_context_lines_graph(graph: nx.MultiDiGraph):
    max_line = 0
    last_node_id = 0
    slicer = Slicing()
    # Find the last node in the graph (the one closest to the 'hole')
    for v in graph.nodes:
        if graph.nodes[v]['startRow'] > max_line:
            max_line = graph.nodes[v]['startRow']
            last_node_id = v
    return slicer.forward_dependency_slicing(last_node_id, graph, contain_node=True)


def build_query_subgraph(task_name):
    input_file = os.path.join(CONSTANTS.dataset_dir, task_name)
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found.")
        return

    test_cases = load_jsonl(input_file)
    graph_test_cases = []
    tokenizer = CodexTokenizer()
    
    print(f"Processing {task_name}...")
    with tqdm(total=len(test_cases)) as pbar:
        for case in test_cases:
            case_path = os.path.join(*case['metadata']['fpath_tuple'])
            line_no = case['metadata']['line_no']
            case_id = case['metadata']['task_id'].split('/')[0]
            
            if case_id not in CONSTANTS.repos:
                pbar.update(1)
                continue

            try:
                # --- START TIMEOUT ---
                signal.alarm(30) # 30 seconds limit
                
                full_repo_path = os.path.join(CONSTANTS.repo_base_dir, case_path)
                with open(full_repo_path, 'r') as f:
                    src_lines = f.readlines()
                
                query_context = src_lines[:line_no]
                
                # These two calls are where the code usually hangs
                ccg = create_graph(query_context, case_id)
                if ccg is None:
                    raise Exception("CCG generation returned None")
                    
                query_ctx, query_line_list, query_graph = last_n_context_lines_graph(ccg)
                
                # Build result object
                graph_case = dict()
                graph_case['query_forward_graph'] = graph_to_json(query_graph)
                graph_case['query_forward_context'] = query_ctx
                graph_case['query_forward_encoding'] = tokenizer.tokenize(query_ctx)
                
                context_lines = case['prompt'].splitlines(keepends=True)
                graph_case['context'] = context_lines
                #graph_case['right_context'] = case['metadata'].get('right_context', '')
                graph_case['metadata'] = copy.deepcopy(case['metadata'])
                graph_case['metadata']['forward_context_line_list'] = query_line_list
                
                graph_test_cases.append(copy.deepcopy(graph_case))

            except TimeoutException:
                pbar.set_description(f"Skipping (Timeout): {case['metadata']['task_id']}")
            except Exception as e:
                pbar.set_description(f"Skipping (Error): {case['metadata']['task_id']}")
                print(f"FAILED on {case['metadata']['task_id']}: {type(e).__name__}: {e}")

            finally:
                # --- RESET TIMEOUT ---
                signal.alarm(0)
                pbar.update(1)

    save_path = os.path.join(CONSTANTS.query_graph_save_dir, task_name)
    make_needed_dir(save_path)
    dump_jsonl(graph_test_cases, save_path)
    print(f"\nDone. Saved {len(graph_test_cases)} cases to {save_path}")
    return


if __name__ == "__main__":
    # Ensure this matches your file name
    tasks_name = ["scala.test.jsonl"]
    for task_name in tasks_name:
        build_query_subgraph(task_name)