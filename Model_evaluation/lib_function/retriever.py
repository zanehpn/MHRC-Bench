import torch.nn as nn
import torch
from transformers import AutoTokenizer, AutoModel
from torch.utils.data import DataLoader, Dataset
from tqdm import tqdm
from bm25 import TaskSpecificBM25
import random
import os
import pandas as pd


class Example(object):
    def __init__(self, task_id, file_path, left_context, right_context, related_files, target_code):
        """
        Represents an example used for constructing a dataset.
        :param task_id: Task ID.
        :param file_path: File path.
        :param left_context: The context to the left of the target code.
        :param right_context: The context to the right of the target code.
        :param related_files: A list of related files, each containing a path and text.
        :param target_code: The target code snippet.
        """
        self.task_id = task_id
        self.file_path = file_path
        self.left_context = left_context
        self.right_context = right_context
        self.related_files = related_files
        self.target_code = target_code

    def __str__(self):
        return (f"[Example]:\n"
                f"[Task ID]:\n{self.task_id}\n"
                f"[Path]:\n{self.file_path}\n"
                f"[Left Context]:\n{self.left_context}\n"
                f"[Target Code]:\n{self.target_code}\n"
                f"[Right Context]:\n{self.right_context}\n"
                f"[Related Files]:\n{len(self.related_files)} files\n"
        )

class CodeBlock(object):
    def __init__(self, file_path, description, code_content, _type):
        """
        Represents a block of code.
        :param file_path: The path to the code file.
        :param description: The description of the code block.
        :param code_content: The content of the code block.
        """
        self.file_path = file_path
        self.code_content = code_content
        self.description = description
        self._type = _type
    def __str__(self):

        comment_label = "//"
        crossfile_context = "\n".join([f"{comment_label} {cl}" for cl in  self.description.strip().split('\n') if cl]) + "\n"
        crossfile_context += "\n".join([f"{comment_label} {cl}" for cl in  self.code_content.split('\n') if cl])
        return crossfile_context.strip()

def tokenize(text, tokenizer, max_length, is_query, extracted_import=''):
    """
    Converts text to a list of token ids.
    :param text: The text to be converted
    :param tokenizer: The tokenizer to use
    :param max_length: The maximum input length
    :param is_query: A flag indicating whether the text is a query
    :return: A list of token ids
    """
    if extracted_import:
        # import_tokens = tokenizer.tokenize(extracted_import)[-127:] + [tokenizer.sep_token]
        import_tokens = []
    else:
        import_tokens = []

    tokens = tokenizer.tokenize(text)
    if is_query:
        tokens = tokens[-(max_length - len(import_tokens)) + 4:]
    else:
        tokens = tokens[:(max_length - len(import_tokens)) - 4]
    tokens = [tokenizer.cls_token, "<encoder-only>", tokenizer.sep_token] + import_tokens + tokens + [tokenizer.sep_token]
    tokens_id = tokenizer.convert_tokens_to_ids(tokens)
    padding_length = max_length - len(tokens_id)
    tokens_id += [tokenizer.pad_token_id] * padding_length

    return tokens_id


class CustomDataset(Dataset):
    """
    Custom dataset class for handling code blocks and queries.
    :param max_length: The maximum input length
    :param tokenizer: The tokenizer used
    :param examples: The samples in the dataset
    :param is_query: A flag indicating whether it is a query
    """
    def __init__(self, max_length, tokenizer, examples, query=False, extracted_imports=None):
        self.max_length = max_length
        self.tokenizer = tokenizer
        self.examples = examples
        self.query = query
        self.extracted_imports = extracted_imports

    def __len__(self):
        return len(self.examples)

    def __getitem__(self, idx):
        text = str(self.examples[idx])
        extracted_import = str(self.extracted_imports[idx]) if self.extracted_imports else ''
        tokens_id = tokenize(text, self.tokenizer, self.max_length, self.query, extracted_import)
        return torch.tensor(tokens_id, dtype=torch.long)

def construct_dataset(raw_data, num_samples):
    """
    Builds a dataset.
    :param raw_data: Raw data.
    :param num_samples: The number of samples to generate.
    :return: The list of constructed samples.
    """
    examples = []
    data_index = 0
    print(f"[construct] raw_data_len={len(raw_data)} target_num_samples={num_samples}")
    # limit number of verbose prints early to avoid flooding logs
    verbose_print_limit = 10
    while len(examples) < num_samples:
        example = raw_data[data_index % len(raw_data)]
        if data_index < 5:
            print(f"[construct] data_index={data_index}")
        data_index += 1
        selected_file = random.choice(example[1:])
        related_files = [
            CodeBlock(x[0], f"file path: {x[0]}\nlines: {0}-{len(x[1].splitlines())}", x[1], '')
            for x in example if x[0] != selected_file[0]
        ]
        path = selected_file[0]
        selected_file_content = selected_file[1].split(" ")
        try_count = 0

        while try_count < 10:
            end_line_number = int(len(selected_file_content) * random.uniform(0.2, 0.8))
            left_context = " ".join(selected_file_content[:end_line_number])
            target_length = random.randint(32, 64)
            target = " ".join(selected_file_content[end_line_number:end_line_number + target_length])
            right_context = " ".join(selected_file_content[end_line_number + target_length:])
            if len(left_context.split()) > 80 and len(target.split()) > 8:
                ex = Example(len(examples), path, left_context, right_context, related_files, target)
                examples.append(ex)
                # print a few example summaries to inspect format
                if len(examples) <= verbose_print_limit:
                    print(f"[construct] appended example_idx={len(examples)-1} path={path}")
                    print(f"  left_words={len(left_context.split())}, target_words={len(target.split())}, related_files={len(related_files)}")
                    print(f"  target_preview={repr(target[:200])}")
                break
            try_count += 1
            if try_count == 9 and len(left_context.split()) <= 80:
                # last attempt logging to help debug data sparsity
                print(f"[construct] warn: failed to create example after 10 tries for path={path} (left_words={len(left_context.split())}, target_words={len(target.split())})")
        # safety: avoid infinite loop if raw_data shorter than num_samples
        if data_index > len(raw_data) * 10 and len(examples) == 0:
            print("[construct] error: cannot construct any examples from raw_data. Exiting early.")
            break

    print(f"[construct] finished building examples count={len(examples)}")
    if examples:
        e0 = examples[0]
        print(f"[construct] example[0] fields: idx={e0.idx if hasattr(e0,'idx') else 'N/A'}, path={e0.path if hasattr(e0,'path') else 'N/A'}")
    return examples

class Retriever(nn.Module):
    """
    Retriever model, used to compute sentence embeddings and retrieve similar code blocks.
    :param args: A namespace containing configuration parameters
    """
    def __init__(self, args):
        super(Retriever, self).__init__()
        path = args.retriever_model_path
        self.tokenizer = AutoTokenizer.from_pretrained(path)
        self.args = args
        self.model = AutoModel.from_pretrained(path)
        self.model = torch.nn.DataParallel(self.model).cuda()
        self.model.eval()

        max_len = getattr(self.model.module.config, "max_position_embeddings", 512)
        usable_len = max_len - 4

        total = self.args.retriever_query_context_length + self.args.retriever_candidate_context_length
        if total > usable_len:
            scale = usable_len / float(total)
            new_query = int(self.args.retriever_query_context_length * scale)
            new_cand = usable_len - new_query
            print(
                f"[Retriever] Warning: requested (query+candidate)={total} > model usable_len={usable_len}. "
                f"Rescaling to query={new_query}, candidate={new_cand}."
            )
            self.args.retriever_query_context_length = new_query
            self.args.retriever_candidate_context_length = new_cand

    def forward(self, source_ids):
        """
        Forward propagation function, used to generate the embedding representation of the input.
        :param input_ids: The sequence of input IDs
        :return: The embedding representation
        """
        mask = source_ids.ne(self.tokenizer.pad_token_id)
        token_embeddings = self.model(source_ids, attention_mask=mask)[0]
        sentence_embeddings = (token_embeddings * mask.unsqueeze(-1)).sum(1) / mask.sum(-1).unsqueeze(-1)
        sentence_embeddings = torch.nn.functional.normalize(sentence_embeddings, p=2, dim=1)
        return sentence_embeddings

    def retrieve(self, queries, candidate_codeblocks, topk, extracted_imports=None):
        """
        Retrieval function, used to retrieve the most relevant code blocks from a list of candidate code blocks for each query.
        :param queries: A list of queries
        :param candidate_codeblocks: A list of candidate code blocks
        :param topk: The number of top-k code blocks to return for each query
        :return: A list of top-k code blocks for each query
        """
        query_dataset = CustomDataset(self.args.retriever_query_context_length, self.tokenizer, queries, query=True, extracted_imports=extracted_imports)
        query_dataloader = DataLoader(query_dataset, batch_size=self.args.retriever_batch_size, shuffle=False, num_workers=self.args.num_workers)
        candidate_numbers = [len(x) for x in candidate_codeblocks]
        candidate_codeblocks = [x for y in candidate_codeblocks for x in y]
        code_dataset = CustomDataset(self.args.retriever_candidate_context_length, self.tokenizer, candidate_codeblocks, query=False)
        code_dataloader = DataLoader(code_dataset, batch_size=self.args.retriever_batch_size, shuffle=False, num_workers=self.args.num_workers)
        code_dataloader = tqdm(code_dataloader, desc="Encoding Code Blocks") if self.args.enable_tqdm else code_dataloader
        query_embeddings = []
        code_embeddings = []
        with torch.no_grad():
            for batch in query_dataloader:
                batch = batch.cuda()
                query_embeddings.append(self.forward(batch))
            for batch in code_dataloader:
                batch = batch.cuda()
                code_embeddings.append(self.forward(batch))
        query_embeddings = torch.cat(query_embeddings, dim=0)
        code_embeddings = torch.cat(code_embeddings, dim=0)

        scores = torch.mm(query_embeddings, code_embeddings.t())
        scores = scores.cpu().numpy()

        topk_codeblocks = []  # Stores top-k codeblocks for each query
        start_idx = 0
        for i, num_candidates in enumerate(candidate_numbers):
            if num_candidates == 0:
                topk_codeblocks.append([])  # If there are no candidates for this query, add an empty list
                continue
            query_scores = scores[i][start_idx:start_idx+num_candidates]  # Get scores for the current query
            topk_indices_query = query_scores.argsort()[-topk:][::-1]  # Get indices of top-k codeblocks
            topk_codeblocks_query = [candidate_codeblocks[start_idx + idx] for idx in topk_indices_query]

            if len(topk_codeblocks_query) < topk:
                topk_codeblocks_query += [CodeBlock("","Don't need cross file context to completion", "", '')] * (topk - len(topk_codeblocks_query))
            topk_codeblocks.append(topk_codeblocks_query)
            start_idx += num_candidates
        return topk_codeblocks

# Retrieves code blocks based on different inference types.
def retrieve_codeblocks(args, examples, bm25, retriever, dataset_name, is_training=False, inference_type=None):
    """
    Retrieves code blocks based on different inference types.
    :param args: An argument object containing configuration parameters.
    :param examples: Examples used for retrieval.
    :param bm25: An instance of the BM25 model.
    :param retriever: An instance of the retriever.
    :param dataset_name: The name of the dataset.
    :param is_training: Whether it is in training mode.
    :return: A list of retrieved code blocks.
    """
    if inference_type is None:
        inference_type = args.inference_type
    if inference_type == "baseline":
        return None, [[] for _ in range(len(examples))]
    queries = []
    bm25_topk, unixcoder_topk, context_len = 5, 5, 20
    if inference_type in ["bm25", "repocoder", "rl_coder"]:
        if dataset_name not in bm25:
            bm25[dataset_name] = TaskSpecificBM25(examples, args)

        if inference_type == "repocoder":
            bm25_topk = 50
        elif inference_type == "rl_coder":
            bm25_topk = args.sample_number * 10
            unixcoder_topk = args.sample_number
        replacement_token = "<TARGET>"
        for example in examples:
            queries.append(f"{example.left_context}\n{replacement_token}\n{example.right_context}\n")

        candidate_codeblocks = bm25[dataset_name].query([x.task_id for x in examples], queries, topk=bm25_topk)

        if inference_type == "bm25":
            return queries, candidate_codeblocks
        elif inference_type == "repocoder":
            return queries, retriever.retrieve(queries, candidate_codeblocks, topk=unixcoder_topk)
        elif inference_type == "rl_coder":
            if is_training:
                if args.disable_stop_block:
                    candidate_codeblocks = retriever.retrieve(queries, candidate_codeblocks, topk=unixcoder_topk)
                else:
                    candidate_codeblocks = retriever.retrieve(queries, candidate_codeblocks, topk=unixcoder_topk-1)

                    candidate_codeblocks = [x + [CodeBlock("", "Don't need cross file context for completion", "",'')] for x,y in zip(candidate_codeblocks, examples)]
            else:
                if not args.disable_stop_block:
                    candidate_codeblocks = [x + [CodeBlock("", "Don't need cross file context for completion", "",'')] for x,y in zip(candidate_codeblocks, examples)]

                candidate_codeblocks = retriever.retrieve(queries,  candidate_codeblocks, topk=unixcoder_topk)

            return queries, candidate_codeblocks

    raise ValueError("Unsupported inference type: {}".format(args.inference_type))

def load_test_dataset(args):
    """
    Loads a dataset from a JSONL file and constructs Example objects.

    crossfile_list 不再从 jsonl 中读取，而是从
    <repo-root>/hls/<task_id>
    目录下扫描 {".c", ".cpp", ".cc", ".h", ".hpp"} 文件作为 cross-file context。
    """
    jsonl_path = ""
    if args.language == "hls":
        HLS_TASK_ROOT = os.path.join(args.repo_root, "hls")
        jsonl_path = args.test_jsonl
        HLS_CODE_EXTS = {".c", ".cpp", ".cc", ".h", ".hpp"}
    elif args.language == "vhdl":
        HLS_TASK_ROOT = os.path.join(args.repo_root, "vhdl")
        HLS_CODE_EXTS = {".vhd", ".vhdl"}
        jsonl_path = args.test_jsonl
    elif args.language == "systemverilog":
        HLS_TASK_ROOT = os.path.join(args.repo_root, "systemverilog")
        HLS_CODE_EXTS = {".sv", ".svh", ".v",".vh"}
        jsonl_path = args.test_jsonl
    elif args.language == "chisel":
        HLS_TASK_ROOT = os.path.join(args.repo_root, "chisel")
        HLS_CODE_EXTS = {".scala"}
        jsonl_path = args.test_jsonl
    else:
        raise ValueError(f"Unsupported language: {args.language}")
    data_frame = pd.read_json(jsonl_path, lines=True)
    if getattr(args, "debug", False):
        data_frame = data_frame.sample(100)

    dataset = []
    for _, row in data_frame.iterrows():
        task_id = row.get("task_id", "")
        file_path = row.get("path", "")
        left_context = row.get("left_context", "")
        right_context = row.get("right_context", "")
        groundtruth = row.get("groundtruth", "")

        cross_files = []
        task_dir = os.path.join(HLS_TASK_ROOT, str(task_id))

        if os.path.isdir(task_dir):
            for root, _, files in os.walk(task_dir):
                for fname in files:
                    ext = os.path.splitext(fname)[1].lower()
                    if ext not in HLS_CODE_EXTS:
                        continue

                    fpath = os.path.join(root, fname)
                    try:
                        with open(fpath, "r", encoding="utf-8", errors="ignore") as fin:
                            content = fin.read()
                    except Exception as e:
                        print(f"[load_test_dataset] warn: failed to read {fpath}: {e}")
                        continue

                    relpath = os.path.relpath(fpath, HLS_TASK_ROOT)

                    header = f"file path: {relpath}\nlines: {0}-{len(content.splitlines())}"
                    cross_files.append(CodeBlock(relpath, header, content, ''))
        else:
            print(f"[load_test_dataset] warn: task directory not found for task_id={task_id}: {task_dir}")

        if not cross_files:
            cross_files = [CodeBlock(
                "",
                "Don't need cross file context for completion",
                "",
                ''
            )]

        dataset.append(Example(task_id, file_path, left_context, right_context, cross_files, groundtruth))

    return dataset


if __name__ == "__main__":
    import argparse
    import json
    import sys

    def parse_args():
        p = argparse.ArgumentParser()
        p.add_argument("--repo-root", required=True)
        p.add_argument("--output", required=True)
        p.add_argument("--test-jsonl", required=True)
        p.add_argument("--train-jsonl")
        p.add_argument(
            "--inference_type",
            type=str,
            default="bm25",
            choices=["baseline", "bm25", "repocoder", "rl_coder"],
        )
        p.add_argument("--debug", action="store_true")
        p.add_argument("--sample_number", type=int, default=10)
        p.add_argument(
            "--language",
            type=str,
            default="hls",
            choices=["hls", "vhdl", "systemverilog", "chisel"],
        )
        # p.add_argument("--retriever_model_path", default="nov3630/RLRetriever", type=str, help="Retriever model path")
        p.add_argument(
            "--retriever_model_path",
            default="microsoft/unixcoder-base",
            type=str,
            help="Retriever model path",
        )
        p.add_argument("--disable_stop_block", action="store_true")

        p.add_argument(
            "--retriever_query_context_length",
            type=int,
            default=256,
            help="Max tokens for query (left/right context + <TARGET>)",
        )
        p.add_argument(
            "--retriever_total_context_length",
            type=int,
            default=2048,
            help="Total max tokens for query + candidate. "
                "candidate_length will be total - query_length.",
        )
        p.add_argument("--retriever_num_workers", type=int, default=2)
        p.add_argument("--retriever_batch_size", type=int, default=8)
        p.add_argument("--num_workers", type=int, default=14)
        p.add_argument("--enable_tqdm", action="store_true")
        p.add_argument(
            "--enable_fixed_block",
            action="store_true",
            help="Use fixed length blocks when building candidates",
        )
        p.add_argument("--max_examples", type=int, default=10)

        args = p.parse_args()

        if args.retriever_query_context_length >= args.retriever_total_context_length:
            raise ValueError(
                f"retriever_query_context_length ({args.retriever_query_context_length}) "
                f"must be < retriever_total_context_length ({args.retriever_total_context_length})"
            )

        args.retriever_candidate_context_length = (
            args.retriever_total_context_length - args.retriever_query_context_length
        )

        print(
            f"[config] total_context_length={args.retriever_total_context_length}, "
            f"query_context_length={args.retriever_query_context_length}, "
            f"candidate_context_length={args.retriever_candidate_context_length}"
        )

        return args


    args = parse_args()
    bm25 = {}
    retriever_RLCoder = Retriever(args)
    print("Loading dataset...")
    eval_raw_data = load_test_dataset(args)  # uses your load_test_dataset implementation
    dataset_name = f"eval_{args.inference_type}"
    is_training = False  # change to True if you are in training mode

    print("Calling retrieve_codeblocks(...) with:")
    print(f"  inference_type={args.inference_type}, dataset_name={dataset_name}, is_training={is_training}")
    try:
        queries, retrieved_codeblocks = retrieve_codeblocks(
            args,
            eval_raw_data,
            bm25,
            retriever_RLCoder,
            dataset_name,
            is_training=is_training,
            inference_type=args.inference_type
        )
    except Exception as e:
        print("Error while running retrieve_codeblocks:", file=sys.stderr)
        raise

    # ---- Print a short summary of results ----
    print("\nRetrieval finished.")
    if queries is None:
        print("queries is None (baseline).")
    else:
        print(f"Number of queries: {len(queries)}")
        # Print first 3 queries and their retrieved candidates
        for i in range(min(3, len(queries))):
            print(f"\n=== Example {i} ===")
            q = queries[i]
            print("QUERY (truncated):")
            print(q[:400].replace("\n", "\\n"))
            cands = retrieved_codeblocks[i] if (retrieved_codeblocks and i < len(retrieved_codeblocks)) else []
            print(f"Retrieved {len(cands)} candidates:")
            for j, cb in enumerate(cands[:5]):
                # cb could be CodeBlock or tuple; pretty-print both cases
                if hasattr(cb, "file_path") or hasattr(cb, "path"):
                    path = getattr(cb, "file_path", None) or getattr(cb, "path", None)
                    text_content = getattr(cb, "code_content", "") or ""
                    text_len = len(getattr(cb, "code_content", "") or "")
                    print(f"  [{j}] CodeBlock path={path} text_len={text_len}, {text_content}")
                else:
                    print(f"  [{j}] {repr(cb)}")

    # Optionally, write retrieval results to a JSONL for downstream usage
    out_path = args.output
    try:
        with open(out_path, "w", encoding="utf-8") as fout:
            for q, cands in zip(queries or [], retrieved_codeblocks or []):
                serial = []
                for c in cands:
                    if hasattr(c, "file_path") or hasattr(c, "path"):
                        serial.append({
                            "path": getattr(c, "file_path", None) or getattr(c, "path", None),
                            "content": getattr(c, "code_content", "") or ""
                        })
                    else:
                        serial.append({"raw": str(c)})
                fout.write(json.dumps({"query": q, "candidates": serial}, ensure_ascii=False) + "\n")
        print(f"Wrote retrieval results to {out_path}")
    except Exception as e:
        print("Warning: failed to write output file:", e, file=sys.stderr)

