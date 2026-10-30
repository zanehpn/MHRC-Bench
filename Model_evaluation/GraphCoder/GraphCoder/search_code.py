import signal
from concurrent.futures import ThreadPoolExecutor
import os
from utils.utils import CONSTANTS, dump_jsonl, json_to_graph, CodexTokenizer, load_jsonl, make_needed_dir
import copy
import networkx as nx
import queue
import Levenshtein
import argparse
import time
from utils.metrics import hit
from functools import partial
from build_query_graph import build_query_subgraph

# --- Timeout Configuration ---
class TimeoutException(Exception):
    pass

def timeout_handler(signum, frame):
    raise TimeoutException

# Register signal for Unix-based systems
signal.signal(signal.SIGALRM, timeout_handler)

class SimilarityScore:
    @staticmethod
    def text_edit_similarity(str1: str, str2: str):
        return 1 - Levenshtein.distance(str1, str2) / max(len(str1), len(str2))

    @staticmethod
    def text_jaccard_similarity(list1, list2):
        set1 = set(list1)
        set2 = set(list2)
        if not set1 and not set2: return 0
        intersection = len(set1.intersection(set2))
        union = len(set1.union(set2))
        return float(intersection) / union

    @staticmethod
    def subgraph_edit_similarity(query_graph: nx.MultiDiGraph, graph: nx.MultiDiGraph, gamma=0.1):
        try:
            query_root = max(query_graph.nodes)
            root = max(graph.nodes)
            tokenizer = CodexTokenizer()
            query_graph_node_embedding = tokenizer.tokenize("".join(query_graph.nodes[query_root]['sourceLines']))
            graph_node_embedding = tokenizer.tokenize("".join(graph.nodes[root]['sourceLines']))
            node_sim = SimilarityScore.text_jaccard_similarity(query_graph_node_embedding, graph_node_embedding)

            node_match = dict()
            match_queue = queue.Queue()
            match_queue.put((query_root, root, 0))
            node_match[query_root] = (root, 0)

            query_graph_visited = {query_root}
            graph_visited = {root}
            graph_nodes = set(graph.nodes)

            while not match_queue.empty():
                v, u, hop = match_queue.get()
                v_neighbors = (set(query_graph.neighbors(v)) | set(query_graph.predecessors(v))) - set(query_graph_visited)
                u_neighbors = graph_nodes - set(graph_visited)

                sim_score = []
                for vn in v_neighbors:
                    for un in u_neighbors:
                        q_emb = tokenizer.tokenize("".join(query_graph.nodes[vn]['sourceLines']))
                        g_emb = tokenizer.tokenize("".join(graph.nodes[un]['sourceLines']))
                        sim = SimilarityScore.text_jaccard_similarity(q_emb, g_emb)
                        sim_score.append((sim, vn, un))

                sim_score.sort(key=lambda x: -x[0])
                for sim, vn, un in sim_score:
                    if vn not in query_graph_visited and un not in graph_visited:
                        match_queue.put((vn, un, hop + 1))
                        node_match[vn] = (un, hop + 1)
                        query_graph_visited.add(vn)
                        graph_visited.add(un)
                        v_neighbors.remove(vn)
                        u_neighbors.remove(un)
                        node_sim += (gamma ** (hop + 1)) * sim
                    if len(v_neighbors) == 0 or len(u_neighbors) == 0:
                        break
                if len(v_neighbors) != 0:
                    for vn in v_neighbors:
                        node_match[vn] = None
                        query_graph_visited.add(vn)

            edge_sim = 0
            for v_query, u_query, t in query_graph.edges:
                if node_match.get(v_query) and node_match.get(u_query):
                    v, hop_v = node_match[v_query]
                    u, _ = node_match[u_query]
                    if graph.has_edge(v, u, t):
                        edge_sim += (gamma ** hop_v)

            return node_sim + edge_sim
        except Exception:
            return 0

class CodeSearchWorker:
    def __init__(self, query_cases, output_path, mode, gamma=None, max_top_k=CONSTANTS.max_search_top_k, timeout=30):
        self.query_cases = query_cases
        self.output_path = output_path
        self.max_top_k = max_top_k
        self.mode = mode
        self.gamma = gamma
        self.timeout = timeout
        self.remove_threshold = 0

    @staticmethod
    def _is_context_after_hole(query_case, repo_case):
        hole_fpath_str = "/".join(query_case['metadata']['fpath_tuple'])
        repo_fpath_str = "/".join(repo_case['fpath_tuple'])
        if hole_fpath_str != repo_fpath_str:
            return False
        # Safety check for missing forward_context_line_list
        q_lines = query_case['metadata'].get('forward_context_line_list', [])
        if not q_lines: return False
        return repo_case['max_line_no'] >= max(q_lines)

    def _text_jaccard_similarity_wrapper(self, query_case, repo_case):
        if self._is_context_after_hole(query_case, repo_case): return repo_case, 0
        sim = SimilarityScore.text_jaccard_similarity(query_case['query_forward_encoding'], repo_case['key_forward_encoding'])
        return repo_case, sim

    def _graph_node_prior_similarity_wrapper(self, query_case, repo_case):
        if self._is_context_after_hole(query_case, repo_case): return repo_case, 0
        query_graph = json_to_graph(query_case['query_forward_graph'])
        repo_graph = json_to_graph(repo_case['key_forward_graph'])
        if len(repo_graph.nodes) == 0: return repo_case, 0
        sim = SimilarityScore.subgraph_edit_similarity(query_graph, repo_graph, gamma=self.gamma)
        return repo_case, sim

    def _find_top_k_context(self, query_case, phase="one"):
        repo_name = query_case['metadata']['task_id'].split('/')[0]
        repo_path = os.path.join(CONSTANTS.graph_database_save_dir, f"{repo_name}.jsonl")
        if not os.path.exists(repo_path):
            return query_case

        repo_cases = load_jsonl(repo_path)
        start_t = time.time()

        with ThreadPoolExecutor(max_workers=32) as executor:
            if phase == "one":
                mode_fn = self._text_jaccard_similarity_wrapper if self.mode == 'coarse' else self._graph_node_prior_similarity_wrapper
                results = list(executor.map(partial(mode_fn, query_case), repo_cases))
            else:
                # Phase 2 of coarse2fine
                results_p1 = list(executor.map(partial(self._text_jaccard_similarity_wrapper, query_case), repo_cases))
                top_p1 = sorted(results_p1, key=lambda x: x[1])[-self.max_top_k:]
                results = list(executor.map(partial(self._graph_node_prior_similarity_wrapper, query_case), [c for c, s in top_p1]))

        filtered = []
        for rc, sim in results:
            filtered.append((rc['val'], rc['statement'], rc['key_forward_context'], rc['fpath_tuple'], sim))

        query_case['top_k_context'] = sorted(filtered, key=lambda x: x[-1])[-self.max_top_k:]
        duration = time.time() - start_t
        query_case['text_runtime'] = duration if self.mode == 'coarse' else 0
        query_case['graph_runtime'] = duration if self.mode != 'coarse' else 0
        return query_case

    def run(self):
            results = []
            for query_case in self.query_cases:
                case_id = query_case['metadata']['task_id']
                try:
                    signal.alarm(self.timeout)
                    if self.mode in ['coarse', 'fine']:
                        res = self._find_top_k_context(query_case, "one")
                    else:
                        res = self._find_top_k_context(query_case, "two")
                    results.append(res)
                    print(f'case {case_id} finished')
                except TimeoutException:
                    print(f'case {case_id} TIMEOUT - skipping search')
                    # --- FIX: Ensure the key exists even on timeout ---
                    query_case['top_k_context'] = []
                    query_case['text_runtime'] = 0
                    query_case['graph_runtime'] = 0
                    results.append(query_case)
                except Exception as e:
                    print(f'case {case_id} ERROR: {e}')
                    query_case['top_k_context'] = []
                    results.append(query_case)
                finally:
                    signal.alarm(0)
            dump_jsonl(results, self.output_path)

if __name__ == '__main__':
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--query_cases', default="api_level", type=str)
    args_parser.add_argument('--mode', type=str, default='coarse2fine')
    args_parser.add_argument('--gamma', default=0.1, type=float)
    args = args_parser.parse_args()

    # Apply timeout to the pre-processing step (the likely source of your hang)
    print(f"Building query subgraphs for {args.query_cases}...")
    try:
        # Note: If build_query_subgraph hangs internally on a file,
        # this alarm might trigger. You may need to edit build_query_graph.py
        # similarly if it has its own internal loop.
        signal.alarm(300) # Give the whole builder 5 mins
        build_query_subgraph(f"{args.query_cases}.test.jsonl")
        signal.alarm(0)
    except TimeoutException:
        print("Warning: build_query_subgraph timed out or was partially completed.")

    query_path = os.path.join(CONSTANTS.query_graph_save_dir, f"{args.query_cases}.test.jsonl")
    if not os.path.exists(query_path):
        print(f"Error: Query file {query_path} not found.")
        exit(1)

    query_cases = load_jsonl(query_path)
    save_path = os.path.join(f"./search_results/{args.query_cases}.{args.mode}.{args.gamma*100}.search_res.fim.jsonl")
    make_needed_dir(save_path)

    searcher = CodeSearchWorker(query_cases, save_path, args.mode, gamma=args.gamma)
    searcher.run()

    # Metrics calculation
    search_cases = load_jsonl(save_path)
    hit1, hit5, hit10 = hit(search_cases, hits=[1, 5, 10])
    print(f"\nResults saved to: {save_path}")
    print(f'Hit@1: {hit1:.4f} | Hit@5: {hit5:.4f} | Hit@10: {hit10:.4f}')
