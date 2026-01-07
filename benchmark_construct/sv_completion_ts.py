#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Tree-sitter based SystemVerilog/Verilog completion target extractor.

Route A version:
- Allow larger structural blocks (module / always / case / ...),
  but crop an internal 1–N-line span as completion target.

- Parse SV/V files with CST (tree-sitter)
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

SV_EXTS = {".sv", ".svh", ".v", ".vh"}

TARGET_NODE_TYPES = {
    "module_declaration",
    "interface_declaration",
    "package_declaration",
    "always_ff_construct",
    "always_comb_construct",
    "always_construct",
    "case_statement",
    "continuous_assign",
    "class_property",
    "variable_decl_assignment",
    "function_declaration",
    "function_statement",
    "blocking_assignment",
    "operator_assignment",
    "class_item"
    "statement_item",
    "primary_literal",
    "simple_identifier",
    "extends",
    "packed_dimension",
    "include_compiler_directive",
    "port_identifier",
    "expression",
    "data_type",
    "casting_type",
    "primary",
    "virtual"
}

# ----------------------------------------------------------------------
# Keyword-based patterns（完全基于关键词做语义分类）
# ----------------------------------------------------------------------
CATEGORY_PATTERNS: dict[str, list[str]] = {
    # 设计层次结构：模块/包/接口/生成块
    "Design Structure": [
        r"\bmodule\b",
        r"\bendmodule\b",
        r"\bpackage\b",
        r"\bendpackage\b",
        r"\binterface\b",
        r"\bendinterface\b",
        r"\bgenerate\b",
        r"\bendgenerate\b",
        # 常见实例命名风格（u_xxx / inst_xxx），粗略识别层次实例
        r"\b[A-Za-z_][A-Za-z0-9_]*\s+[A-Za-z0-9_]*\s*\(",
    ],

    # 变量/端口/参数等声明
    "Declaration and Definition": [
        r"\bwire\b",
        r"\breg\b",
        r"\blogic\b",
        r"\bparameter\b",
        r"\blocalparam\b",
        r"\btypedef\b",
        r"\bgenvar\b",
        r"\bimport\b"
    ],

    # 寄存器、时序逻辑、存储
    "Storage Block": [
        r"\balways_ff\b",
        r"\balways\s*@\s*\(.*posedge",
        r"\balways\s*@\s*\(.*negedge",
        r"<=",                                # 不用 \b，匹配非阻塞赋值
        r"\b[A-Za-z_][A-Za-z0-9_]*\s*<=\s*",
        r"\bmem\b",
        r"\bram\b",
        r"\brom\b",
        r"\bfifo\b",
    ],

    # 组合逻辑、算术、位运算
    "Computation Expression": [
        r"\bassign\b",
        r"\b[A-Za-z_][A-Za-z0-9_]*\s*=\s*[^=]",   # 简单阻塞赋值
        r"[+\-*/]",                               # 算术
        r"&|\||\^|~",                             # 位运算
        r"<<|>>",                                 # 移位
        r"\[[0-9]+\s*:[0-9]+\]",                  # bit-slice [hi:lo]
    ],

    # 控制流 / 数据流
    "Control or Data Flow": [
        r"\balways\b",
        r"\bdefault\b",
        r"\bif\s*\(",
        r"\belse\b",
        r"\bcase\b",
        r"\bfor\s*\(",
        r"\bforever\b",
        r"\brepeat\s*\(",
        r"\bendproperty\b",
        r"\bwhile\s*\(",
        r"\bstate\b",
        r"\bnext_state\b",
        r"\bendfunction\b"
    ],

    # 接口、端口、ready/valid
    "Interface": [
        r"\binput\b",
        r"\boutput\b",
        r"\binout\b",
        r"\bmodport\b",
        r"\bready\b",
        r"\bvalid\b",
        r"\breq\b",
        r"\bresp\b",
        r"\baxi\b",
        r"\bapb\b",
    ],

    # 约束 / 综合属性
    "Synthesis and Optimization Hints": [
        r"\(\*\s*.*\*\)",          
        r"\bfull_case\b",
        r"\bparallel_case\b",
        r"\bsyn_keep\b",
        r"\bkeep_hierarchy\b",
        r"\bmark_debug\b",
    ],

    "Print / Debug": [
        r"\$display\b",
        r"\$write\b",
        r"\$fwrite\b",
        r"\$monitor\b",
        r"\$strobe\b",
        r"\buvm_info\b",
        r"\buvm_warning\b",
        r"\buvm_error\b",
        r"\buvm_fatal\b",
        r"\buvm_report_\w+\b",  
        r"\buvm_print\b",
        r"`uvm_info\b",
        r"`uvm_warning\b",
        r"`uvm_error\b",
        r"`uvm_fatal\b",
        r"`uvm_report_\w+\b",
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

# 端口 / 声明行优先
DECL_LINE_RE = re.compile(r"^\s*(wire|reg|logic)\b")
PORT_LINE_RE = re.compile(r"^\s*(input|output|inout)\b")


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

    if node_type == "module_declaration":
        best_cat = "Design Structure"
    if node_type == "extends" or "packed_dimension" or "include_compiler_directive":
        best_cat = "Declaration and Definition"
    if node_type == "module_declaration" or node_type == "port_identifier":
        best_cat = "Interface"

    return best_cat, first_match.get(best_cat)


# ---------- 新增：过滤“无意义 target”的函数 ----------
def is_meaningful_target(target: str) -> bool:
    """
    返回 True 表示这个 span 至少有一行是“有意义的代码”，
    而不是只有空行 / 注释 / 纯打印 / 单独结构关键字。
    """
    for line in target.splitlines():
        s = line.strip()
        if not s:
            # 空行
            continue
        if s.startswith("//"):
            # 单行注释
            continue
        if s.startswith("/*") or s.startswith("*"):
            # 块注释行
            continue
        if re.match(r"^\$display\b", s) or re.match(r"^\$(write|fdisplay|fwrite)\b", s):
            # 纯打印
            continue
        if s in {";", "begin", "end", "endmodule", "endcase", "endfunction", "endtask"}:
            # 只有结构关键字 / 分号
            continue

        # 有字母数字，且不只是上面这些“无聊行”，认为是有意义的
        if re.search(r"[A-Za-z0-9]", s):
            return True

    return False


# ------------------------------------------------
# Utils
# ------------------------------------------------
def find_sv_files(repo: Path) -> List[Path]:
    out = []
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in [".git", "build", "out", "dist", "target"]]
        for f in files:
            p = Path(root) / f
            if p.suffix.lower() in SV_EXTS:
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
    cursor_line = start_line + 1          # 1-based
    target_lines = end_line - start_line + 1

    return prefix, target, cursor_line, target_lines


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
def run_sv_extractor(
    repo: str,
    out: str = "sv_tasks_ts.jsonl",
    seed: int = 42,
    max_block_lines: int = 40,
    min_span_lines: int = 1,
    max_span_lines: int = 5,
    multi_min_lines: int = 2,
    multi_ratio: float = 0.4,
    prefer: str = "always_ff_construct,always_comb_construct,case_statement,module_declaration",
    max_tries_per_file: int = 8,
    lang_so: str = "../tree-sitter-verilog/build/sv.so",
    verbose_skip: bool = False,   # ✅ 新增：是否打印跳过原因
):
    rng = random.Random(seed)
    repo_path = Path(repo).resolve()

    lang_so_path = os.path.abspath(lang_so)
    if not os.path.exists(lang_so_path):
        raise RuntimeError(f"Cannot find language library: {lang_so_path}")

    LANG = Language(lang_so_path, "verilog")
    parser = Parser()
    parser.set_language(LANG)

    prefer_types = [x.strip() for x in prefer.split(",") if x.strip()]

    sv_files = find_sv_files(repo_path)
    print(f"Found {len(sv_files)} SV files")

    out_path = Path(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    total_count = 0
    multi_count = 0
    written = 0
    skipped_read = 0          # ✅ 新增：读文件失败计数

    def nlines(n):
        return n.end_point[0] - n.start_point[0] + 1

    with out_path.open("w", encoding="utf-8") as w:
        for fp in sv_files:
            # ✅ 新增：文件可能是断链 symlink / 被删 / 权限问题，必须 try/except
            try:
                # 这句可选：快速过滤断链/不存在
                # 注意：对 dangling symlink，exists() 也会 False
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

                chosen_rec = {
                    "file": norm_rel(repo_path, fp),
                    "target_type": chosen.type,
                    "cursor_line": cursor_line,
                    "target_nlines": tlines,
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
    保留一个命令行入口，参数解析后调用 run_sv_extractor。
    """
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", default="sv_tasks_ts.jsonl")
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
        default="always_ff_construct,always_comb_construct,case_statement,module_declaration",
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
        default="../tree-sitter-verilog/build/sv.so",
        help="path to tree-sitter verilog shared library",
    )

    args = ap.parse_args()

    run_sv_extractor(
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

