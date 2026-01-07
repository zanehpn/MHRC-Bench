import os
import json
import signal
from tqdm import tqdm
from networkx.readwrite import json_graph
from utils.utils import CONSTANTS, CodexTokenizer
from utils.slicing import Slicing
from utils.ccg import create_graph
from utils.utils import iterate_repository_file, make_needed_dir, set_default, dump_jsonl, graph_to_json

# Custom Exception for Timeout
class TimeoutException(Exception):
    pass

def timeout_handler(signum, frame):
    raise TimeoutException

class GraphDatabaseBuilder:

    def __init__(self, repo_base_dir=CONSTANTS.repo_base_dir,
                 graph_database_save_dir=CONSTANTS.graph_database_save_dir,
                 file_timeout=20): # Default 60 seconds per file
        self.repo_base_dir = repo_base_dir
        self.graph_database_save_dir = graph_database_save_dir
        self.file_timeout = file_timeout
        return

    def build_full_graph_database(self, repo_name):
        code_files = iterate_repository_file(self.repo_base_dir, repo_name)
        file_num = 0
        make_needed_dir(os.path.join(self.graph_database_save_dir, repo_name))
        
        # Register the signal handler
        signal.signal(signal.SIGALRM, timeout_handler)

        with tqdm(total=len(code_files)) as pbar:
            for file in code_files:
                pbar.set_description(f"Processing {os.path.basename(file)}")
                try:
                    signal.alarm(self.file_timeout) # Start timer
                    
                    with open(file, 'r') as f:
                        src_lines = f.readlines()
                    ccg = create_graph(src_lines, repo_name)
                    if ccg is None:
                        pbar.update(1)
                        continue
                    
                    save_path = os.path.join(self.graph_database_save_dir, repo_name, f"{file_num}.json")
                    file_num += 1
                    make_needed_dir(save_path)
                    with open(save_path, 'w') as f:
                        # Fixed typo: changed pdg to ccg
                        f.write(json.dumps(json_graph.node_link_data(ccg), default=set_default))
                
                except TimeoutException:
                    print(f"\n[Timeout] Skipping {file} - took longer than {self.file_timeout}s")
                except Exception as e:
                    print(f"\n[Error] Failed to process {file}: {e}")
                finally:
                    signal.alarm(0) # Reset timer
                    pbar.update(1)
        return

    def build_slicing_graph_database(self, repo_name):
        slicer = Slicing()
        repo_dict = []
        code_files = iterate_repository_file(self.repo_base_dir, repo_name)
        repo_base_dir_len = len(self.repo_base_dir.split('/'))
        tokenizer = CodexTokenizer()

        # Register the signal handler
        signal.signal(signal.SIGALRM, timeout_handler)

        with tqdm(total=len(code_files)) as pbar:
            for file in code_files:
                pbar.set_description(f"Slicing {os.path.basename(file)}")
                
                try:
                    signal.alarm(self.file_timeout) # Start timer
                    
                    with open(file, 'r') as f:
                        src_lines = f.readlines()
                    
                    ccg = create_graph(src_lines, repo_name)
                    if ccg is None:
                        pbar.update(1)
                        continue

                    for v in ccg.nodes:
                        curr_dict = dict()
                        forward_context, forward_line, forward_graph = slicer.forward_dependency_slicing(v, ccg,
                                                                                                         contain_node=False)
                        curr_dict['key_forward_graph'] = graph_to_json(forward_graph)
                        curr_dict['key_forward_context'] = forward_context
                        curr_dict['key_forward_encoding'] = tokenizer.tokenize(forward_context)
                        curr_dict['statement'] = "".join(ccg.nodes[v]['sourceLines'])
                        statement_line_row = ccg.nodes[v]['startRow']
                        start_line_row = max(0, statement_line_row-11)
                        end_line_row = min(statement_line_row+10, len(src_lines))
                        curr_dict['val'] = "".join(src_lines[start_line_row:end_line_row])
                        curr_dict['fpath_tuple'] = file.split('/')[repo_base_dir_len:]
                        
                        max_forward_line = 0
                        if len(forward_line) != 0:
                            max_forward_line = max(forward_line)
                        curr_dict['max_line_no'] = max(max_forward_line, end_line_row)
                        repo_dict.append(curr_dict.copy())
                
                except TimeoutException:
                    print(f"\n[Timeout] Skipping {file} - Slicing took longer than {self.file_timeout}s")
                except Exception as e:
                    print(f"\n[Error] Failed to process {file}: {e}")
                finally:
                    signal.alarm(0) # Reset timer
                    pbar.update(1)

        save_name = os.path.join(self.graph_database_save_dir, f"{repo_name}.jsonl")
        make_needed_dir(save_name)
        dump_jsonl(repo_dict, save_name)
        return


if __name__ == '__main__':
    # You can adjust the timeout here (e.g., 30 or 120 seconds)
    graph_db_builder = GraphDatabaseBuilder(file_timeout=60)
    for repo in CONSTANTS.repos:
        print(f'Processing repo {repo}')
        graph_db_builder.build_slicing_graph_database(repo)