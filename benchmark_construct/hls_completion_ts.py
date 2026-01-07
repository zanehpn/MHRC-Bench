#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Tree-sitter based HLS C/C++ completion target extractor (Route A).

- Parse C/C++ (HLS-style) with CST (tree-sitter)
- Extract syntactically complete structural nodes
- Crop an internal 1–N-line span as completion target
- Sample ONE target per file
- Output JSONL tasks
- (Optional) tag with hardware semantic category (keyword-based)
- Filter meaningless spans (blank/comments/only braces/only pragmas etc.)
"""

import argparse
import json
import os
import random
import re
from pathlib import Path
from typing import List, Tuple, Optional

from tree_sitter import Language, Parser

C_EXTS = {".c", ".h"}
CPP_EXTS = {".cc", ".cpp", ".cxx", ".hpp", ".hh", ".hxx"}

# ----------------------------------------------------------------------
# HLS-oriented target nodes (works for both tree-sitter-c and tree-sitter-cpp)
# Some node types differ slightly between grammars; we include a superset.
# ----------------------------------------------------------------------
TARGET_NODE_TYPES = {
    # top-level
    "function_definition",
    "declaration",
    "preproc_def",
    "preproc_include",
    "preproc_if",
    "preproc_ifdef",
    "preproc_endif",

    # blocks / control
    "compound_statement",
    "if_statement",
    "for_statement",
    "while_statement",
    "do_statement",
    "switch_statement",
    "case_statement",
    "return_statement",
    "break_statement",
    "continue_statement",

    # expressions / assignments
    "expression_statement",
    "assignment_expression",
    "binary_expression",
    "unary_expression",
    "call_expression",
    "conditional_expression",
    "update_expression",

    # declarations / types
    "init_declarator",
    "parameter_declaration",
    "type_definition",
    "struct_specifier",
    "enum_specifier",
    "typedef_declaration",
    "field_declaration",
}

# ----------------------------------------------------------------------
# Keyword-based patterns for semantic categories (HLS focused)
# ----------------------------------------------------------------------
CATEGORY_PATTERNS: dict[str, list[str]] = {
    # Design structure (top-level functions/kernels, templates, namespaces)
    "Design Structure": [
        r"\bextern\s+\"C\"\b",
        r"\bnamespace\b",
        r"\btemplate\s*<",
        r"\bclass\b|\bstruct\b",
        r"\bvoid\s+\w+\s*\(",
        r"\bint\s+\w+\s*\(",
    ],

    # Declaration/Definition (types, arrays, pointers, typedef, struct fields)
    "Declaration and Definition": [
        r"\btypedef\b",
        r"\bstruct\b",
        r"\benum\b",
        r"\bstatic\b",
        r"\bconst\b",
        r"\bvolatile\b",
        r"\brestrict\b",
        r"\b(ap_int|ap_uint|ap_fixed|ap_ufixed)\b",
        r"\bhls::\w+\b",          # hls::stream, hls::vector, etc.
    ],

    # Storage (on-chip buffers, arrays, streams, memories)
    "Storage Block": [
        r"\bhls::stream\s*<",
        r"\bstream\b",
        r"\bstatic\b",
        r"\bap_uint\b|\bap_int\b|\bap_fixed\b",
        r"\bBRAM\b|\bURAM\b|\bRAM\b",
        r"\barray\b",
        r"\bbuffer\b",
        r"\bmem\b",
    ],

    # Computation (arith, bit ops, intrinsics, reduce, MAC, etc.)
    "Computation Expression": [
        r"[+\-*/%]",
        r"<<|>>",
        r"&|\||\^|~",
        r"\bmax\b|\bmin\b",
        r"\bfma\b|\bmul\b|\badd\b",
        r"\babs\b",
        r"\bpopcount\b",
        r"\baie::\w+\b",          # if you have AIE style code in C++
    ],

    # Control/Data flow (loops, branches, pragmas that affect control)
    "Control or Data Flow": [
        r"\bfor\s*\(",
        r"\bwhile\s*\(",
        r"\bif\s*\(",
        r"\bswitch\s*\(",
        r"\bcase\b",
        r"\bcontinue\b|\bbreak\b|\breturn\b",
    ],

    # Interface (AXI, m_axi, s_axilite, ports, bundles)
    "Interface": [
        r"#\s*pragma\s+HLS\s+INTERFACE\b",
        r"\bm_axi\b|\bs_axilite\b|\baxis\b|\bap_none\b|\bap_vld\b|\bap_ack\b",
        r"\bAXI\b|\bAXIS\b",
        r"\bvolatile\b\s+\w+\s*\*",
        r"\bconst\b\s+\w+\s*\*",
    ],

    # Synthesis/Optimization hints (HLS pragmas)
    "Synthesis and Optimization Hints": [
        r"#\s*pragma\s+HLS\b",
        r"\bPIPELINE\b",
        r"\bUNROLL\b",
        r"\bDATAFLOW\b",
        r"\bARRAY_PARTITION\b",
        r"\bARRAY_RESHAPE\b",
        r"\bRESOURCE\b",
        r"\bINLINE\b",
        r"\bLATENCY\b",
        r"\bBIND_STORAGE\b",
        r"\bBIND_OP\b",
    ],

    # Print / Debug (C printf etc.)
    "Print / Debug": [
        r"\bprintf\s*\(",
        r"\bfprintf\s*\(",
        r"\bstd::cout\b",
        r"\bstd::cerr\b",
    ],
}

_COMPILED_PATTERNS: dict[str, list[re.Pattern]] = {
    cat: [re.compile(pat) for pat in pats]
    for cat, pats in CATEGORY_PATTERNS.items()
}

CATEGORY_PRIORITY = [
    "Design Structure",
    "Synthesis and Optimization Hints",
    "Interface",
    "Declaration and Definition",
    "Control or Data Flow",
    "Storage Block",
    "Computation Expression",
]

# line-level hard rules
PRAGMA_LINE_RE = re.compile(r"^\s*#\s*pragma\s+HLS\b")
DECL_LINE_RE = re.compile(r"^\s*(typedef|struct|enum|static|const|volatile)\b")
FOR_LINE_RE = re.compile(r"^\s*for\s*\(")


def classify_snippet(snippet: str, node_type: str = "") -> Tuple[str, Optional[str]]:
    """
    Keyword-based classification:
    0) line-level rules
    1) scoring + priority
    """
    text = snippet

    # 0) line-level
    for line in text.splitlines():
        if PRAGMA_LINE_RE.search(line):
            # interface pragma is stronger than general pragma
            if re.search(r"\bINTERFACE\b", line):
                return "Interface", "pragma HLS INTERFACE"
            return "Synthesis and Optimization Hints", "pragma HLS"
        if FOR_LINE_RE.search(line):
            return "Control or Data Flow", "for"
        if DECL_LINE_RE.search(line):
            m = DECL_LINE_RE.search(line)
            return "Declaration and Definition", m.group(1) if m else None

    # 1) scoring
    scores: dict[str, int] = {cat: 0 for cat in CATEGORY_PATTERNS}
    first_match: dict[str, Optional[str]] = {cat: None for cat in CATEGORY_PATTERNS}

    for cat, patterns in _COMPILED_PATTERNS.items():
        for pat in patterns:
            for m in pat.finditer(text):
                scores[cat] += 1
                if first_match[cat] is None:
                    first_match[cat] = m.group(0)

    if all(v == 0 for v in scores.values()):
        return "Control or Data Flow", None

    max_score = max(scores.values())
    candidate_cats = [cat for cat, s in scores.items() if s == max_score and s > 0]

    if len(candidate_cats) == 1:
        best_cat = candidate_cats[0]
    else:
        best_cat = min(
            candidate_cats,
            key=lambda c: CATEGORY_PRIORITY.index(c) if c in CATEGORY_PRIORITY else 999,
        )

    # node_type hinting
    if node_type == "function_definition":
        best_cat = "Design Structure"
    if node_type in ("for_statement", "while_statement", "if_statement", "switch_statement"):
        best_cat = "Control or Data Flow"

    return best_cat, first_match.get(best_cat)


def is_meaningful_target(target: str) -> bool:
    """
    Filter meaningless spans:
    - blank lines
    - comments only
    - only braces/semicolons
    - only HLS pragmas / includes
    - only prints
    """
    has_nontrivial = False
    for line in target.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("//"):
            continue
        if s.startswith("/*") or s.startswith("*") or s.endswith("*/"):
            continue

        # only structural tokens
        if s in {"{", "}", ";"}:
            continue

        # only preprocessor noise
        if s.startswith("#include") or s.startswith("#define") or s.startswith("#if") or s.startswith("#endif"):
            continue

        # only pragmas
        if PRAGMA_LINE_RE.match(s):
            # pragmas alone are often not a useful completion target
            continue

        # prints only
        if re.match(r"^\s*(printf|fprintf)\s*\(", s) or "std::cout" in s:
            continue

        # if contains alnum or operators, count as meaningful
        if re.search(r"[A-Za-z0-9]", s):
            has_nontrivial = True
            break

    return has_nontrivial


# ------------------------------------------------
# Utils
# ------------------------------------------------
def find_hls_files(repo: Path, lang: str) -> List[Path]:
    exts = C_EXTS if lang == "c" else CPP_EXTS
    out: List[Path] = []
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in [".git", "build", "out", "dist", "target", ".idea", ".vscode"]]
        for f in files:
            p = Path(root) / f
            if p.suffix.lower() in exts:
                out.append(p)
    return sorted(out)


def norm_rel(repo: Path, p: Path) -> str:
    try:
        return str(p.relative_to(repo)).replace("\\", "/")
    except Exception:
        return str(p).replace("\\", "/")


def extract_span_within_node(
    code: bytes,
    node,
    rng: random.Random,
    max_span_lines: int,
    min_span_lines: int = 1,
):
    lines = code.decode(errors="ignore").splitlines(keepends=True)
    node_start = node.start_point[0]
    node_end = node.end_point[0]
    node_nlines = node_end - node_start + 1

    if min_span_lines > max_span_lines:
        min_span_lines = max_span_lines

    if node_nlines <= max_span_lines:
        start_line = node_start
        end_line = node_end
    else:
        span_len = rng.randint(min_span_lines, max_span_lines)
        start_min = node_start
        start_max = node_end - span_len + 1
        if start_max < start_min:
            start_max = start_min
        start_line = rng.randint(start_min, start_max)
        end_line = start_line + span_len - 1
        if end_line > node_end:
            end_line = node_end

    prefix = "".join(lines[:start_line])
    target = "".join(lines[start_line:end_line + 1])
    cursor_line = start_line + 1
    target_lines = end_line - start_line + 1
    return prefix, target, cursor_line, target_lines


def collect_nodes(root, out):
    stack = [root]
    while stack:
        node = stack.pop()
        if node.type in TARGET_NODE_TYPES:
            out.append(node)
        children = node.named_children  
        if children:
            stack.extend(reversed(children))


def get_node_hierarchy(node):
    path = []
    cur = node
    while cur is not None:
        path.append(cur.type)
        cur = cur.parent
    path.reverse()
    depth = len(path) - 1
    return depth, path

import ctypes
from tree_sitter import Language, Parser

def load_ts_language_from_so(so_path: str, lang: str) -> Language:
    """
    tree_sitter>=0.25: Language() expects a TSLanguage* pointer (int),
    so we load the shared library and call tree_sitter_<lang>() to get it.
    """
    lib = ctypes.CDLL(so_path)

    # expected exported symbol name
    sym = f"tree_sitter_{lang}"
    if not hasattr(lib, sym):
        raise RuntimeError(
            f"Cannot find symbol {sym} in {so_path}. "
            f"Try: nm -D {so_path} | grep tree_sitter"
        )

    fn = getattr(lib, sym)
    fn.restype = ctypes.c_void_p
    ptr = fn()
    if not ptr:
        raise RuntimeError(f"{sym}() returned NULL for {so_path}")

    return Language(ptr)
# ------------------------------------------------
# Main
# ------------------------------------------------
def run_hls_extractor(
    repo: str,
    out: str = "hls_tasks_ts.jsonl",
    seed: int = 42,
    max_block_lines: int = 300,
    min_span_lines: int = 1,
    max_span_lines: int = 5,
    multi_min_lines: int = 2,
    multi_ratio: float = 0.4,
    prefer: str = "function_definition,for_statement,if_statement,switch_statement,compound_statement,declaration",
    max_tries_per_file: int = 8,
    lang: str = "cpp",   # "c" or "cpp"
    lang_so: str = "",
):
    """
    Returns:
        written, total_count, multi_count
    """
    if lang not in ("c", "cpp"):
        raise ValueError("lang must be 'c' or 'cpp'")

    rng = random.Random(seed)
    repo_path = Path(repo).resolve()

    if not lang_so:
        lang_so = "../tree-sitter-c/build/c.so" if lang == "c" else "../tree-sitter-cpp/build/cpp.so"

    lang_so_path = os.path.abspath(lang_so)
    if not os.path.exists(lang_so_path):
        raise RuntimeError(f"Cannot find language library: {lang_so_path}")

    # ---- use it ----
    LANG = load_ts_language_from_so(lang_so_path, lang)  # lang is "c" or "cpp"
    parser = Parser()
    parser.language = LANG


    prefer_types = [x.strip() for x in prefer.split(",") if x.strip()]

    files = find_hls_files(repo_path, lang=lang)
    print(f"Found {len(files)} {lang.upper()} files")

    out_path = Path(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    total_count = 0
    multi_count = 0
    written = 0

    def nlines(n):
        return n.end_point[0] - n.start_point[0] + 1

    with out_path.open("w", encoding="utf-8") as w:
        for fp in files:
            code = fp.read_bytes()
            tree = parser.parse(code)
            root = tree.root_node

            nodes = []
            collect_nodes(root, nodes)

            nodes = [n for n in nodes if 1 <= nlines(n) <= max_block_lines]
            if not nodes:
                continue

            preferred = [n for n in nodes if n.type in prefer_types]
            base_pool = preferred if preferred else nodes
            if not base_pool:
                continue

            short_nodes = [n for n in base_pool if nlines(n) < multi_min_lines]
            multi_nodes = [n for n in base_pool if nlines(n) >= multi_min_lines]

            chosen_rec = None
            for _ in range(max_tries_per_file):
                cur_ratio = (multi_count / total_count) if total_count > 0 else 0.0
                need_multi = cur_ratio < multi_ratio

                if need_multi and multi_nodes:
                    pool = multi_nodes
                    span_min = max(min_span_lines, multi_min_lines)
                else:
                    pool = short_nodes if short_nodes else multi_nodes
                    span_min = min_span_lines

                if not pool:
                    break

                chosen = rng.choice(pool)

                prefix, target, cursor_line, tlines = extract_span_within_node(
                    code, chosen, rng,
                    max_span_lines=max_span_lines,
                    min_span_lines=span_min,
                )

                if not is_meaningful_target(target):
                    continue

                node_depth, node_path = get_node_hierarchy(chosen)

                # optional classification
                # cat, kw = classify_snippet(target, chosen.type)

                chosen_rec = {
                    "file": norm_rel(repo_path, fp),
                    "target_type": chosen.type,
                    "cursor_line": cursor_line,
                    "target_nlines": tlines,
                    "node_depth": node_depth,
                    "node_path": node_path,
                    # "semantic_category": cat,
                    # "semantic_keyword": kw,
                    # "prefix": prefix,
                    "target": target,
                }

                total_count += 1
                if tlines >= multi_min_lines:
                    multi_count += 1
                break

            if chosen_rec is None:
                continue

            w.write(json.dumps(chosen_rec, ensure_ascii=False) + "\n")
            written += 1

    print(f"✔ Wrote {written} tasks to {out_path}")
    if total_count > 0:
        print(f"Multi-line targets: {multi_count}/{total_count} ({multi_count / total_count:.3f})")

    return written, total_count, multi_count


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", default="hls_tasks_ts.jsonl")
    ap.add_argument("--seed", type=int, default=42)

    ap.add_argument("--lang", choices=["c", "cpp"], default="cpp", help="parse language: c or cpp")
    ap.add_argument("--lang-so", default="", help="path to tree-sitter .so for c/cpp")

    ap.add_argument("--max-block-lines", type=int, default=300)
    ap.add_argument("--min-span-lines", type=int, default=1)
    ap.add_argument("--max-span-lines", type=int, default=5)

    ap.add_argument("--multi-min-lines", type=int, default=2)
    ap.add_argument("--multi-ratio", type=float, default=0.4)

    ap.add_argument(
        "--prefer",
        default="function_definition,for_statement,if_statement,switch_statement,compound_statement,declaration",
    )
    ap.add_argument("--max-tries-per-file", type=int, default=8)

    args = ap.parse_args()

    run_hls_extractor(
        repo=args.repo,
        out=args.out,
        seed=args.seed,
        max_block_lines=args.max_block_lines,
        min_span_lines=args.min_span_lines,
        max_span_lines=args.max_span_lines,
        multi_min_lines=args.multi_min_lines,
        multi_ratio=args.multi_ratio,
        prefer=args.prefer,
        max_tries_per_file=args.max_tries_per_file,
        lang=args.lang,
        lang_so=args.lang_so,
    )


if __name__ == "__main__":
    main()
