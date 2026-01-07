#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Tree-sitter based Scala/Chisel completion target extractor.

Route A version (same spirit as your SV extractor):
- Allow larger structural blocks (class/object/def/if/match/block/...),
  but crop an internal 1–N-line span as completion target.
- Parse Scala files with CST (tree-sitter-scala)
- Extract syntactically complete structural nodes
- For each node, choose a short span (1–max-span-lines) inside it
- Sample ONE target per file
- Output JSONL tasks
- Additionally, tag each target with a hardware semantic category
  (Design Structure / Declaration and Definition / Storage Block /
   Computation Expression / Control or Data Flow / Interface /
   Synthesis and Optimization Hints)
Extra:
- Enforce that the chosen target span is "meaningful" (not only blanks / comments / trivial).
"""

import argparse
import json
import os
import random
import re
from pathlib import Path
from typing import List, Tuple, Optional

from tree_sitter import Language, Parser

SCALA_EXTS = {".scala"}

# -----------------------------------------------
# Target node types (Scala CST) — may need tiny tuning
# -----------------------------------------------
TARGET_NODE_TYPES = {
    # top-level / structural
    "source_file",
    "package_clause",
    "import_clause",
    "class_definition",
    "object_definition",
    "trait_definition",
    "template_body",          # body of class/object/trait
    "block",                  # {...}
    "function_definition",    # def foo = ...
    "method_definition",      # some scala grammars call it this
    "val_definition",
    "var_definition",
    "assignment_expression",
    "call_expression",

    # control flow
    "if_expression",
    "match_expression",
    "for_expression",
    "while_expression",
    "try_expression",

    # expressions
    "infix_expression",
    "prefix_expression",
    "binary_expression",
    "postfix_expression",
    "parenthesized_expression",
    "identifier",
    "string_literal",
    "integer_literal",
    "floating_point_literal",
}

# ----------------------------------------------------------------------
# Keyword-based patterns（完全基于关键词做语义分类，面向 Chisel/Scala）
# ----------------------------------------------------------------------
CATEGORY_PATTERNS: dict[str, list[str]] = {
    # 设计层次结构：Module / Bundle / LazyModule / object/class/trait
    "Design Structure": [
        r"\bclass\b",
        r"\bobject\b",
        r"\btrait\b",
        r"\bextends\b",
        r"\bwith\b",
        r"\bModule\b",
        r"\bRawModule\b",
        r"\bMultiIOModule\b",
        r"\bBundle\b",
        r"\bLazyModule\b",
        r"\bLazyModuleImp\b",
        r"\bnew\s+Module\b",
        r"\bnew\s+Bundle\b",
    ],

    # 声明/定义：val/var/def/type/package/import/implicit/override
    "Declaration and Definition": [
        r"\bval\b",
        r"\bvar\b",
        r"\bdef\b",
        r"\btype\b",
        r"\bpackage\b",
        r"\bimport\b",
        r"\bimplicit\b",
        r"\boverride\b",
        r"\bprivate\b|\bprotected\b|\bfinal\b|\bsealed\b",
    ],

    # 存储/时序：Reg / RegInit / ShiftRegister / Mem / SyncReadMem
    "Storage Block": [
        r"\bRegInit\b",
        r"\bReg\b",
        r"\bVecInit\b",          # often used with regs
        r"\bMem\b",
        r"\bSyncReadMem\b",
        r"\bSyncReadMem\b",
        r"\bShiftRegister\b",
        r"\bclock\b",
        r"\breset\b",
    ],

    # 计算表达式：:=, =, + - * /, bit ops, Cat, Mux, PriorityMux, etc.
    "Computation Expression": [
        r":=",
        r"(?<![=!<>])=(?!=)",     # plain '=' but avoid '==' / '!=' / '>=' etc.
        r"[+\-*/%]",
        r"<<|>>|>>>",
        r"&|\||\^|~",
        r"\bCat\b",
        r"\bMux\b",
        r"\bMux1H\b",
        r"\bPriorityMux\b",
        r"\bPopCount\b",
        r"\bFill\b",
        r"\bReverse\b",
        r"\bUInt\b|\bSInt\b|\bBool\b",
    ],

    # 控制/数据流：when/switch/is/for/while/match/if/else/try/catch
    "Control or Data Flow": [
        r"\bwhen\b",
        r"\belsewhen\b",
        r"\botherwise\b",
        r"\bswitch\b",
        r"\bis\b",
        r"\bif\b",
        r"\belse\b",
        r"\bmatch\b",
        r"\bfor\b",
        r"\bwhile\b",
        r"\btry\b",
        r"\bcatch\b",
        r"\breturn\b",
    ],

    # 接口：IO / Input / Output / Flipped / Decoupled / Valid / Ready
    "Interface": [
        r"\bIO\b",
        r"\bInput\b",
        r"\bOutput\b",
        r"\bFlipped\b",
        r"\bDecoupled\b",
        r"\bDecoupledIO\b",
        r"\bValid\b",
        r"\bready\b",
        r"\bvalid\b",
        r"\bbits\b",
        r"\bBundle\b",
        r"\bVec\b",
    ],

    # 综合/优化提示：dontTouch / annotate / chisel3.experimental / @...
    "Synthesis and Optimization Hints": [
        r"\bdontTouch\b",
        r"\bchisel3\.experimental\b",
        r"\bannotate\b",
        r"\bChiselAnnotation\b",
        r"@\w+",                 # Scala annotations
    ],

    # 调试打印：printf / println / assert
    "Print / Debug": [
        r"\bprintf\b",
        r"\bprintln\b",
        r"\bassert\b",
        r"\blogger\b",
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

# 行级优先：接口 IO 行 / 声明行
DECL_LINE_RE = re.compile(r"^\s*(val|var|def|type)\b")
PORT_LINE_RE = re.compile(r"^\s*val\s+io\s*=\s*IO\b|\bIO\s*\(")


def classify_snippet(snippet: str, node_type: str = "") -> Tuple[str, Optional[str]]:
    """
    纯关键词分类：
    0) 行级硬规则：IO 行 / val/var/def 行优先
    1) 全文本打分 + 类别优先级
    """
    text = snippet

    # 0) line-level
    lines = text.splitlines()
    for line in lines:
        if PORT_LINE_RE.search(line):
            return "Interface", "IO"

    for line in lines:
        m_decl = DECL_LINE_RE.search(line)
        if m_decl:
            return "Declaration and Definition", m_decl.group(1)

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

    # node_type hints (optional)
    if node_type in ("class_definition", "object_definition", "trait_definition"):
        best_cat = "Design Structure"
    if node_type in ("val_definition", "var_definition", "function_definition", "method_definition"):
        # 可能是声明，也可能是接口/存储等，这里不强制覆盖
        pass

    return best_cat, first_match.get(best_cat)


def is_meaningful_target(target: str) -> bool:
    """
    True: span 至少包含一行“像代码”的东西，
    过滤：空行、注释、只有括号/花括号、只有 import/package、纯打印
    """
    for line in target.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("//"):
            continue
        if s.startswith("/*") or s.startswith("*"):
            continue

        # trivial tokens
        if s in {"{", "}", "(", ")", ";"}:
            continue

        # trivial directives
        if re.match(r"^\s*(package|import)\b", s):
            continue

        # pure debug
        if re.match(r"^\s*(println|printf)\b", s):
            continue

        # “像代码”：含字母数字 或者 关键符号 := 等
        if re.search(r"[A-Za-z0-9]", s) or ":=" in s:
            return True

    return False


# ------------------------------------------------
# Utils
# ------------------------------------------------
def find_scala_files(repo: Path) -> List[Path]:
    out = []
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in [".git", "target", "out", "build", "dist"]]
        for f in files:
            p = Path(root) / f
            if p.suffix.lower() in SCALA_EXTS:
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
    """
    在给定 node 内部选择一个连续的行区间作为 completion target。
    """
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
    cursor_line = start_line + 1  # 1-based
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


# ------------------------------------------------
# Main
# ------------------------------------------------
def run_chisel_extractor(
    repo: str,
    out: str = "chisel_tasks_ts.jsonl",
    seed: int = 42,
    max_block_lines: int = 300,
    min_span_lines: int = 1,
    max_span_lines: int = 5,
    multi_min_lines: int = 2,
    multi_ratio: float = 0.4,
    prefer: str = "class_definition,object_definition,function_definition,method_definition,if_expression,match_expression,block",
    max_tries_per_file: int = 8,
    lang_so: str = "../tree-sitter-scala/build/scala.so",
    debug_dump_sexp: bool = False,
):
    """
    返回:
        written, total_count, multi_count
    """
    rng = random.Random(seed)
    repo_path = Path(repo).resolve()

    lang_so_path = os.path.abspath(lang_so)
    if not os.path.exists(lang_so_path):
        raise RuntimeError(f"Cannot find language library: {lang_so_path}")

    LANG = Language(lang_so_path, "scala")
    parser = Parser()
    parser.set_language(LANG)

    prefer_types = [x.strip() for x in prefer.split(",") if x.strip()]

    scala_files = find_scala_files(repo_path)
    print(f"Found {len(scala_files)} Scala files")

    out_path = Path(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    total_count = 0
    multi_count = 0
    written = 0

    def nlines(n):
        return n.end_point[0] - n.start_point[0] + 1

    with out_path.open("w", encoding="utf-8") as w:
        for fp in scala_files:
            code = fp.read_bytes()
            tree = parser.parse(code)
            root = tree.root_node

            if debug_dump_sexp:
                # 只建议对少数文件打开，用来对齐 node.type 名称
                print("====", norm_rel(repo_path, fp), "====")
                print(root.sexp())

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
                    code,
                    chosen,
                    rng,
                    max_span_lines=max_span_lines,
                    min_span_lines=span_min,
                )

                if not is_meaningful_target(target):
                    continue

                node_depth, node_path = get_node_hierarchy(chosen)

                # 可选语义分类
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
    ap.add_argument("--out", default="chisel_tasks_ts.jsonl")
    ap.add_argument("--seed", type=int, default=42)

    ap.add_argument("--max-block-lines", type=int, default=300)
    ap.add_argument("--min-span-lines", type=int, default=1)
    ap.add_argument("--max-span-lines", type=int, default=5)

    ap.add_argument("--multi-min-lines", type=int, default=2)
    ap.add_argument("--multi-ratio", type=float, default=0.4)

    ap.add_argument(
        "--prefer",
        default="class_definition,object_definition,function_definition,method_definition,if_expression,match_expression,block",
    )
    ap.add_argument("--max-tries-per-file", type=int, default=8)

    ap.add_argument(
        "--lang-so",
        type=str,
        default="../tree-sitter-scala/build/scala.so",
        help="path to tree-sitter scala shared library",
    )

    ap.add_argument(
        "--debug-dump-sexp",
        action="store_true",
        help="print root.sexp() for each file (use sparingly)",
    )

    args = ap.parse_args()

    run_chisel_extractor(
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
        lang_so=args.lang_so,
        debug_dump_sexp=args.debug_dump_sexp,
    )


if __name__ == "__main__":
    main()
