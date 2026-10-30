#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Tree-sitter based VHDL completion target extractor.

Route A version:
- Allow larger structural blocks (entity / architecture / process / case / ...),
  but crop an internal 1–N-line span as completion target.

- Parse VHDL files with CST (tree-sitter)
- Extract syntactically complete structural nodes
- For each node, choose a short span (1–max-span-lines) inside it
- Sample ONE target per file
- Output JSONL tasks
- Additionally, tag each target with a hardware semantic category
  (Design Structure / Declaration and Definition / Storage Block /
   Computation Expression / Control or Data Flow / Interface /
   Synthesis and Optimization Hints)

Extra:
- Enforce that the chosen target span is "meaningful" (not only blanks / comments / prints).
"""

import argparse
import json
import os
import random
import re
from pathlib import Path
from typing import List, Tuple, Optional

from tree_sitter import Language, Parser

# ----------------------------------------------------------------------
# VHDL specific configuration
# ----------------------------------------------------------------------

VHDL_EXTS = {".vhd", ".vhdl", ".vho"}

# 这里的 node_type 名称需要和你使用的 tree-sitter-vhdl 语法保持一致；
# 不完全匹配也没关系，最多就是匹不到那么多节点，可以根据实际树结构再微调。
TARGET_NODE_TYPES = {
    "design_file",
    "library_unit",
    "entity_declaration",
    "architecture_body",
    "package_declaration",
    "package_body",
    "process_statement",
    "concurrent_signal_assignment_statement",
    "signal_assignment_statement",
    "variable_assignment_statement",
    "if_statement",
    "case_statement",
    "selected_signal_assignment",
    "component_declaration",
    "component_instantiation_statement",
    "signal_declaration",
    "variable_declaration",
    "constant_declaration",
    "subtype_declaration",
    "type_declaration",
    "function_body",
    "procedure_body",
    "block_statement",
}

# ----------------------------------------------------------------------
# Keyword-based patterns（完全基于关键词做语义分类）
# ----------------------------------------------------------------------
CATEGORY_PATTERNS: dict[str, list[str]] = {
    # 设计层次结构：entity / architecture / package / generate / component / block
    "Design Structure": [
        r"\bentity\b",
        r"\barchitecture\b",
        r"\bpackage\b",
        r"\bend\s+entity\b",
        r"\bend\s+architecture\b",
        r"\bend\s+package\b",
        r"\bgenerate\b",
        r"\bend\s+generate\b",
        r"\bcomponent\b",
        r"\bblock\b",
        r"\bend\s+block\b",
        # 实例：u_xxx : entity work.xxx port map ( ... )
        r"\b[A-Za-z_][A-Za-z0-9_]*\s*:\s*(entity|component)\b",
    ],

    # 变量/端口/参数等声明
    "Declaration and Definition": [
        r"\bsignal\b",
        r"\bvariable\b",
        r"\bconstant\b",
        r"\btype\b",
        r"\bsubtype\b",
        r"\bgeneric\b",
        r"\bport\b",
        r"\buse\b",
        r"\blibrary\b",
        r"\bpackage\b",
    ],

    # 寄存器、时序逻辑、存储（process + rising_edge/falling_edge/clock）
    "Storage Block": [
        r"\bprocess\b",
        r"\brising_edge\s*\(",
        r"\bfalling_edge\s*\(",
        r"\bclock\b",
        r"\breset\b",
        r"<=",                                # 信号赋值，时序/组合都可能，这里偏向存储块
        r"\bmem\b",
        r"\bram\b",
        r"\brom\b",
        r"\bfifo\b",
    ],

    # 组合逻辑、算术、位运算
    "Computation Expression": [
        r":=",                                 # 变量赋值
        r"<=",                                 # 信号赋值
        r"[+\-*/]",                            # 算术
        r"\band\b|\bor\b|\bxor\b|\bnot\b",     # 逻辑/位运算
        r"\bsll\b|\bsrl\b|\bsla\b|\bsra\b",    # 移位
        r"\([^)]+\s+(downto|to)\s+[^)]+\)",    # bit-slice (N downto 0)
    ],

    # 控制流 / 数据流
    "Control or Data Flow": [
        r"\bprocess\b",
        r"\bif\b",
        r"\belsif\b",
        r"\belse\b",
        r"\bcase\b",
        r"\bwhen\b",
        r"\bloop\b",
        r"\bfor\b",
        r"\bwhile\b",
        r"\bstate\b",
        r"\bnext_state\b",
        r"\bexit\b",
        r"\breturn\b",
    ],

    # 接口、端口、ready/valid、总线
    "Interface": [
        r":\s*(in|out|inout|buffer)\b",
        r"\bport\b",
        r"\bgeneric\b",
        r"\bready\b",
        r"\bvalid\b",
        r"\breq\b",
        r"\bresp\b",
        r"\baxi\b",
        r"\bapb\b",
    ],

    # 约束 / 综合属性
    "Synthesis and Optimization Hints": [
        r"\battribute\b",
        r"\bsyn_keep\b",
        r"\bkeep_hierarchy\b",
        r"\bdont_touch\b",
        r"\bmark_debug\b",
    ],

    # 打印 / 调试
    "Print / Debug": [
        r"\breport\b",
        r"\bassert\b",
        r"textio",
        r"\bwrite\s*\(",
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

# 端口 / 声明行优先（注意 snippet 已经 lower 过）
DECL_LINE_RE = re.compile(r"^\s*(signal|variable|constant)\b")
# 端口行：某标识符后跟冒号 + in/out/inout/buffer
PORT_LINE_RE = re.compile(r":\s*(in|out|inout|buffer)\b")


def classify_snippet(snippet: str, node_type: str = "") -> Tuple[str, Optional[str]]:
    """
    完全基于文本关键词做分类：
    0) 行级硬规则：端口行 / 声明行优先
    1) 全文本打分 + 类别优先级
    """
    text = snippet.lower()

    # ---------- 0) 行级硬规则：端口 / 声明 行优先 ----------
    lines = text.splitlines()
    for line in lines:
        m_port = PORT_LINE_RE.search(line)
        if m_port:
            return "Interface", m_port.group(1)

    for line in lines:
        m_decl = DECL_LINE_RE.search(line)
        if m_decl:
            return "Declaration and Definition", m_decl.group(1)

    # ---------- 1) 常规打分 ----------
    scores: dict[str, int] = {cat: 0 for cat in CATEGORY_PATTERNS}
    first_match: dict[str, Optional[str]] = {cat: None for cat in CATEGORY_PATTERNS}

    for cat, patterns in _COMPILED_PATTERNS.items():
        for pat in patterns:
            for m in pat.finditer(text):
                scores[cat] += 1
                if first_match[cat] is None:
                    first_match[cat] = m.group(0)

    if all(v == 0 for v in scores.values()):
        # 没有任何关键词命中时，默认归到控制/数据流
        return "Control or Data Flow", None

    max_score = max(scores.values())
    candidate_cats = [cat for cat, s in scores.items() if s == max_score and s > 0]

    if len(candidate_cats) == 1:
        best_cat = candidate_cats[0]
    else:
        # 平票时按优先级表选
        best_cat = min(
            candidate_cats,
            key=lambda c: CATEGORY_PRIORITY.index(c) if c in CATEGORY_PRIORITY else 999,
        )

    # ---------- node_type 强行修正（基于语法结构） ----------
    if node_type in ("entity_declaration", "architecture_body", "package_declaration", "package_body", "block_statement"):
        best_cat = "Design Structure"
    if node_type in ("signal_declaration", "variable_declaration", "constant_declaration",
                     "type_declaration", "subtype_declaration"):
        best_cat = "Declaration and Definition"
    if node_type in ("process_statement",):
        # 过程既可以是控制/数据流，也可以是存储块；如果看起来像时序逻辑，通常已经被 Storage Block 捕获
        # 这里不强制覆盖 Storage Block，只在原来不是存储块时偏向控制流
        if best_cat not in ("Storage Block", "Declaration and Definition", "Interface"):
            best_cat = "Control or Data Flow"

    return best_cat, first_match.get(best_cat)


# ---------- 过滤“无意义 target”的函数 ----------
def is_meaningful_target(target: str) -> bool:
    """
    返回 True 表示这个 span 至少有一行是“有意义的代码”，
    而不是只有空行 / 注释 / 纯打印 / 单独结构关键字。
    """
    for line in target.splitlines():
        s = line.strip().lower()
        if not s:
            # 空行
            continue
        if s.startswith("--"):
            # 单行注释
            continue
        if s.startswith("/*") or s.startswith("*"):
            # 兼容万一有 C 风格注释
            continue
        if re.match(r"^report\b", s) or re.match(r"^assert\b", s):
            # 纯打印/断言
            continue
        if s in {
            ";",
            "begin",
            "end",
            "end entity;",
            "end architecture;",
            "end process;",
            "end case;",
            "end block;",
        }:
            # 只有结构关键字 / 分号
            continue

        # 有字母数字，且不只是上面这些“无聊行”，认为是有意义的
        if re.search(r"[A-Za-z0-9]", s):
            return True

    return False


# ------------------------------------------------
# Utils
# ------------------------------------------------
def find_vhdl_files(repo: Path) -> List[Path]:
    out = []
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in {"vendor", "vendors", "third_party", "third-party", "node_modules", ".git", "dependencies"}]
        dirs[:] = [d for d in dirs if d not in [".git", "build", "out", "dist", "target"]]
        for f in files:
            p = Path(root) / f
            if p.suffix.lower() in VHDL_EXTS:
                out.append(p)
    return sorted(out)


def norm_rel(repo: Path, p: Path) -> str:
    try:
        return str(p.relative_to(repo)).replace("\\", "/")
    except Exception:
        return str(p).replace("\\", "/")


def extract_span_within_node(code, node, rng, max_span_lines, min_span_lines=1):
    """Select the exact source span of a syntactic node, without extending to full lines."""
    target = code[node.start_byte:node.end_byte].decode("utf-8")
    count = len(target.splitlines())
    if not min_span_lines <= count <= max_span_lines:
        return "", "", node.start_point[0] + 1, 0
    return code[:node.start_byte].decode("utf-8"), target, node.start_point[0] + 1, count


def extract_node_code(code: bytes, node) -> str:
    lines = code.decode(errors="ignore").splitlines(keepends=True)
    s_line = node.start_point[0]
    e_line = node.end_point[0]
    return "".join(lines[s_line:e_line + 1])


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
    """
    返回:
      depth: int, root 为 0，子节点依次 +1
      path:  List[str], 从 root 到该 node 的 type 列表
    """
    path = []
    cur = node
    while cur is not None:
        path.append(cur.type)
        cur = cur.parent
    path.reverse()          # [root_type, ..., node_type]
    depth = len(path) - 1   # root 深度 = 0
    return depth, path


# ------------------------------------------------
# Main
# ------------------------------------------------

def run_vhdl_extractor(
    repo: str,
    out: str = "vhdl_tasks_ts.jsonl",
    seed: int = 42,
    max_block_lines: int = 40,
    min_span_lines: int = 1,
    max_span_lines: int = 5,
    multi_min_lines: int = 2,
    multi_ratio: float = 0.4,
    prefer: str = "process_statement,case_statement,entity_declaration,architecture_body",
    max_tries_per_file: int = 8,
    lang_so: str = "../tree-sitter-vhdl/build/vhdl.so",
    verbose_skip: bool = False,   # ✅ 新增：是否打印跳过原因
):
    rng = random.Random(seed)
    repo_path = Path(repo).resolve()

    lang_so_path = os.path.abspath(lang_so)
    if not os.path.exists(lang_so_path):
        raise RuntimeError(f"Cannot find language library: {lang_so_path}")

    LANG = Language(lang_so_path, "vhdl")
    parser = Parser()
    parser.set_language(LANG)

    prefer_types = [x.strip() for x in prefer.split(",") if x.strip()]

    vhdl_files = find_vhdl_files(repo_path)
    print(f"Found {len(vhdl_files)} VHDL files")

    out_path = Path(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    total_count = 0
    multi_count = 0
    written = 0
    skipped_read = 0          # ✅ 新增：读文件失败计数

    def nlines(n):
        return n.end_point[0] - n.start_point[0] + 1

    with out_path.open("w", encoding="utf-8") as w:
        for fp in vhdl_files:
            try:
                if not fp.exists():
                    skipped_read += 1
                    if verbose_skip:
                        print("[SKIP missing]", repr(str(fp)))
                    continue

                code = fp.read_bytes()
            except (FileNotFoundError, PermissionError, OSError) as e:
                skipped_read += 1
                if verbose_skip:
                    print("[SKIP read_error]", repr(str(fp)), "err=", repr(e))
                continue

            tree = parser.parse(code)
            root = tree.root_node

            nodes = []
            collect_nodes(root, nodes)

            nodes = [n for n in nodes if 1 <= nlines(n) <= min(max_block_lines, max_span_lines)]
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

                chosen_rec = {
                    "file": norm_rel(repo_path, fp),
                    "target_type": chosen.type,
                    "cursor_line": cursor_line,
                    "target_nlines": tlines,
                    "start_byte": chosen.start_byte,
                    "end_byte": chosen.end_byte,
                    "node_depth": node_depth,
                    "node_path": node_path,
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
    if skipped_read:
        print(f"⚠ Skipped {skipped_read} files due to missing/read errors")
    if total_count > 0:
        print(f"Multi-line targets: {multi_count}/{total_count} ({multi_count / total_count:.3f})")

    return written, total_count, multi_count

def main():
    """
    命令行入口，参数解析后调用 run_vhdl_extractor。
    """
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", default="vhdl_tasks_ts.jsonl")
    ap.add_argument("--seed", type=int, default=42)

    ap.add_argument(
        "--max-block-lines",
        type=int,
        default=300,
        help="max lines of a structural node (block-level)",
    )
    ap.add_argument(
        "--min-span-lines",
        type=int,
        default=1,
        help="minimum lines of completion span",
    )
    ap.add_argument(
        "--max-span-lines",
        type=int,
        default=5,
        help="maximum lines of completion span",
    )
    ap.add_argument(
        "--multi-min-lines",
        type=int,
        default=2,
        help="lines >= this are treated as multi-line targets",
    )
    ap.add_argument(
        "--multi-ratio",
        type=float,
        default=0.4,
        help="desired fraction of multi-line targets (approximate)",
    )
    ap.add_argument(
        "--prefer",
        default="process_statement,case_statement,entity_declaration,architecture_body",
        help="Preferred node types (comma-separated)",
    )
    ap.add_argument(
        "--max-tries-per-file",
        type=int,
        default=8,
        help="max attempts per file to find a meaningful target",
    )
    ap.add_argument(
        "--lang-so",
        type=str,
        default="../tree-sitter-vhdl/build/vhdl.so",
        help="path to tree-sitter VHDL shared library",
    )

    args = ap.parse_args()

    run_vhdl_extractor(
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
    )


if __name__ == "__main__":
    main()
