#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Compute cross-file dependencies for SystemVerilog/Verilog tasks in a JSONL dataset.

deps(item) = number of DISTINCT other SV/V files (g != f) in the same repo that f depends on.

Dependency signals (heuristic but reproducible):
A) `include "..." resolved with include search paths (curdir, repo_root, scanned +incdir/-I, basename unique)
B) Repo-wide symbol index:
   - module/interface/program/primitive/checker definitions
   - package definitions (pkg::, import pkg::*)
   - bind target/module references
C) Macro dependency:
   - index: `define MACRO -> file
   - usage: `MACRO, `ifdef MACRO, `ifndef MACRO, `elsif MACRO
D) typedef/struct/enum/union dependency:
   - index: typedef NAME -> file (and best-effort struct/enum/union names)
   - usage: type-token at start of decl lines, or common "TYPE var/inst" patterns

Assumptions:
- item["file"] like RepoName/path/to/file.sv
- repos under --repo-base/RepoName
"""

import argparse
import json
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, Set, List, Tuple, Optional

SV_EXTS = (".sv", ".svh", ".v", ".vh")

# ---------- comment stripping ----------
RE_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
RE_LINE_COMMENT = re.compile(r"//.*?$", re.M)

def strip_comments(s: str) -> str:
    s = RE_BLOCK_COMMENT.sub(" ", s)
    s = RE_LINE_COMMENT.sub(" ", s)
    return s

# ---------- includes ----------
RE_INCLUDE = re.compile(r'^\s*`include\s+"([^"]+)"', re.M)

# ---------- incdir / -I scanning ----------
RE_INCDIR = re.compile(r"\+incdir\+([^\s+]+)")
RE_I1 = re.compile(r"(?:^|\s)-I\s*([^\s]+)")
RE_I2 = re.compile(r"(?:^|\s)-I([^\s]+)")

# ---------- defs ----------
RE_DEF = re.compile(
    r'^\s*(module|interface|program|primitive|checker|package)\s+([a-zA-Z_]\w*)\b',
    re.M
)

# ---------- package refs ----------
RE_PKG_SCOPE = re.compile(r'\b([a-zA-Z_]\w*)\s*::\s*([a-zA-Z_]\w*)\b')
RE_IMPORT = re.compile(r'^\s*import\s+([a-zA-Z_]\w*)\s*::\s*(\*|[a-zA-Z_]\w*)\s*;', re.M)

# ---------- instantiation (heuristic) ----------
RE_INSTANTIATE = re.compile(r'(?m)^\s*([a-zA-Z_]\w*)\s*(?:#\s*\([^;]*\)\s*)?([a-zA-Z_]\w*)\s*\(')

SV_KEYWORDS = {
    "if","for","while","case","unique","priority","begin","end","always","always_ff","always_comb","always_latch",
    "assign","logic","wire","reg","bit","byte","shortint","int","longint","integer","time",
    "signed","unsigned","input","output","inout","ref","const","var","genvar","parameter","localparam",
    "function","task","typedef","struct","union","enum","class","covergroup","property","sequence","clocking",
    "assert","assume","cover","disable","default","return","break","continue","do","foreach","generate","endgenerate",
    "package","endpackage","module","endmodule","interface","endinterface","program","endprogram","primitive","endprimitive",
    "checker","endchecker","import","export","bind"
}

BUILTIN_TYPES = {"wire","logic","reg","bit","int","integer","time","byte","shortint","longint"}

# ---------- macro define / usage ----------
RE_DEFINE = re.compile(r'^\s*`define\s+([A-Za-z_]\w*)\b', re.M)
RE_TICK_ID = re.compile(r'`([A-Za-z_]\w*)')  # includes include/define/ifdef...
MACRO_CONTROL = {"include","define","undef","ifdef","ifndef","elsif","else","endif",
                 "timescale","default_nettype","celldefine","endcelldefine",
                 "resetall","line","pragma","begin_keywords","end_keywords"}

RE_IFDEF = re.compile(r'^\s*`(ifdef|ifndef|elsif)\s+([A-Za-z_]\w*)\b', re.M)

# ---------- typedef / struct / enum / union ----------
RE_TYPEDEF = re.compile(r'^\s*typedef\b[^;]*?\b([A-Za-z_]\w*)\s*;', re.M)
RE_TYPEDEF_SEU = re.compile(r'^\s*typedef\s+(struct|enum|union)\b[^;]*?\b([A-Za-z_]\w*)\s*;', re.M)
# best-effort named struct/enum/union declarations (not typedef)
RE_NAMED_SEU = re.compile(r'^\s*(struct|enum|union)\b[^;{]*?\b([A-Za-z_]\w*)\s*(?:\{|;)', re.M)

# type usage: first token of a declaration line like "TYPE var;" or "TYPE #(…) inst("
RE_DECL_TYPE_TOKEN = re.compile(
    r'(?m)^\s*([A-Za-z_]\w*)\s*(?:#\s*\([^;]*\)\s*)?[A-Za-z_]\w+\s*(?:,|;|\[|=|\(|\{)'
)

# bind: bind Target BindMod ...
RE_BIND = re.compile(r'(?m)^\s*bind\s+([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\b')

# ---------- filesystem helpers ----------
def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""

def infer_repo_root(file_rel: str, repo_base: Path) -> Path:
    first = file_rel.split("/", 1)[0]
    return repo_base / first

def file_abs_from_item(repo_root: Path, file_rel: str) -> Path:
    if file_rel.startswith(repo_root.name + "/"):
        sub = "/".join(file_rel.split("/")[1:])
        return (repo_root / sub).resolve()
    if "/" in file_rel:
        return (repo_root / file_rel.split("/", 1)[1]).resolve()
    return (repo_root / file_rel).resolve()

def is_sv_file(p: Path) -> bool:
    return p.suffix.lower() in SV_EXTS

# ---------- include dir scanning ----------
def scan_incdirs(repo_root: Path) -> List[Path]:
    """
    Scan repo for +incdir/-I flags in common build/list/script files.
    Conservative: only keep dirs that exist.
    """
    candidates = []
    patterns = [
        "Makefile", "makefile", "*.mk", "*.f", "*.flist", "*.vc", "*.vcs",
        "*.tcl", "*.sh", "*.bash", "*.cmd", "*.args", "*.txt"
    ]
    files = []
    for pat in patterns:
        files.extend(repo_root.rglob(pat))

    seen = set()
    for f in files:
        txt = read_text(f)
        if not txt:
            continue
        for m in RE_INCDIR.findall(txt):
            p = m.strip()
            if "${" in p or "$(" in p:
                continue
            seen.add(p)
        for m in RE_I1.findall(txt):
            p = m.strip()
            if "${" in p or "$(" in p:
                continue
            seen.add(p)
        for m in RE_I2.findall(txt):
            p = m.strip()
            if "${" in p or "$(" in p:
                continue
            seen.add(p)

    for p in sorted(seen):
        pp = Path(p)
        if not pp.is_absolute():
            pp = (repo_root / pp).resolve()
        if pp.exists() and pp.is_dir():
            candidates.append(pp)

    return candidates

# ---------- build repo index ----------
def build_repo_index(repo_root: Path, do_scan_incdir: bool, extra_incdirs: List[str]):
    """
    Build:
      symbol_to_file: module/interface/... -> defining file
      pkg_to_file: package -> defining file
      macro_to_file: `define MACRO -> file
      typedef_to_file: typedef/struct/enum/union name -> file
      basename_to_paths: basename -> set(paths)
      incdirs: include search dirs (Path list)
    """
    symbol_to_file: Dict[str, Path] = {}
    pkg_to_file: Dict[str, Path] = {}
    macro_to_file: Dict[str, Path] = {}
    typedef_to_file: Dict[str, Path] = {}
    basename_to_paths: Dict[str, Set[Path]] = defaultdict(set)

    sv_files: List[Path] = []
    for ext in SV_EXTS:
        sv_files.extend(repo_root.rglob(f"*{ext}"))

    for f in sv_files:
        basename_to_paths[f.name].add(f)

        txt = strip_comments(read_text(f))

        # defs: module/interface/package...
        for kind, name in RE_DEF.findall(txt):
            symbol_to_file.setdefault(name, f)
            if kind == "package":
                pkg_to_file.setdefault(name, f)

        # macros
        for mac in RE_DEFINE.findall(txt):
            macro_to_file.setdefault(mac, f)

        # typedef names
        for name in RE_TYPEDEF.findall(txt):
            typedef_to_file.setdefault(name, f)
        for _k, name in RE_TYPEDEF_SEU.findall(txt):
            typedef_to_file.setdefault(name, f)
        for _k, name in RE_NAMED_SEU.findall(txt):
            typedef_to_file.setdefault(name, f)

    # include dirs
    incdirs: List[Path] = []
    incdirs.append(repo_root.resolve())

    if do_scan_incdir:
        incdirs.extend(scan_incdirs(repo_root))

    for p in extra_incdirs:
        pp = Path(p)
        if not pp.is_absolute():
            pp = (repo_root / pp).resolve()
        if pp.exists() and pp.is_dir():
            incdirs.append(pp)

    # de-dup while preserving order
    uniq = []
    seen = set()
    for d in incdirs:
        s = str(d)
        if s not in seen:
            seen.add(s)
            uniq.append(d)
    incdirs = uniq

    return symbol_to_file, pkg_to_file, macro_to_file, typedef_to_file, basename_to_paths, incdirs

# ---------- include resolver ----------
def resolve_include_path(
    inc: str,
    cur_file: Path,
    repo_root: Path,
    basename_to_paths: Dict[str, Set[Path]],
    incdirs: List[Path]
) -> Optional[Path]:
    """
    Resolve `include "..."` using:
      1) cur_file.parent
      2) repo_root
      3) scanned/extra incdirs
      4) basename unique match in repo
    Also try adding common header extensions if missing.
    """
    inc = inc.strip()
    inc_path = Path(inc)
    candidates = []

    # try with original and with suffixes if no suffix
    inc_variants = [inc]
    if inc_path.suffix == "":
        inc_variants.extend([inc + ".svh", inc + ".vh", inc + ".sv", inc + ".v"])

    # (1) relative to current file dir
    for v in inc_variants:
        p = (cur_file.parent / v).resolve()
        if p.exists() and p.is_file() and str(p).startswith(str(repo_root)):
            return p

    # (2)+(3) search repo_root + incdirs
    for base in incdirs:
        for v in inc_variants:
            p = (base / v).resolve()
            if p.exists() and p.is_file() and str(p).startswith(str(repo_root)):
                return p

    # (4) basename unique match
    base = Path(inc).name
    cands = list(basename_to_paths.get(base, []))
    if len(cands) == 1:
        return cands[0]

    # if basename without suffix, try .svh/.vh
    if Path(base).suffix == "":
        for ext in [".svh", ".vh", ".sv", ".v"]:
            c2 = list(basename_to_paths.get(base + ext, []))
            if len(c2) == 1:
                return c2[0]

    return None

# ---------- extract macro usages ----------
def extract_macro_usages(txt: str) -> Set[str]:
    """
    Extract macros used in file, excluding control directives.
    Includes:
      `MACRO
      `ifdef MACRO / `ifndef MACRO / `elsif MACRO
    """
    used: Set[str] = set()

    for _kw, mac in RE_IFDEF.findall(txt):
        used.add(mac)

    for mac in RE_TICK_ID.findall(txt):
        if mac in MACRO_CONTROL:
            continue
        used.add(mac)

    return used

# ---------- extract type-like tokens ----------
def extract_type_tokens(txt: str) -> Set[str]:
    """
    Extract candidate type/module/interface names referenced in file:
      - decl line first token
      - instantiation type token handled elsewhere
    """
    toks: Set[str] = set()
    for t in RE_DECL_TYPE_TOKEN.findall(txt):
        if t in SV_KEYWORDS:
            continue
        if t.lower() in BUILTIN_TYPES:
            continue
        toks.add(t)
    return toks

# ---------- parse dependencies for one file ----------
def deps_for_file(
    file_abs: Path,
    repo_root: Path,
    symbol_to_file: Dict[str, Path],
    pkg_to_file: Dict[str, Path],
    macro_to_file: Dict[str, Path],
    typedef_to_file: Dict[str, Path],
    basename_to_paths: Dict[str, Set[Path]],
    incdirs: List[Path]
) -> Set[Path]:
    txt_raw = read_text(file_abs)
    txt = strip_comments(txt_raw)

    dep_files: Set[Path] = set()

    # A) includes
    for inc in RE_INCLUDE.findall(txt):
        resolved = resolve_include_path(inc, file_abs, repo_root, basename_to_paths, incdirs)
        if resolved and resolved != file_abs:
            dep_files.add(resolved)

    # B) import pkg::*
    for pkg, _what in RE_IMPORT.findall(txt):
        if pkg in pkg_to_file:
            fdef = pkg_to_file[pkg]
            if fdef != file_abs:
                dep_files.add(fdef)

    # C) pkg::name usage
    for pkg, _name in RE_PKG_SCOPE.findall(txt):
        if pkg in pkg_to_file:
            fdef = pkg_to_file[pkg]
            if fdef != file_abs:
                dep_files.add(fdef)

    # D) instantiation: Type inst(...)
    for typ, _inst in RE_INSTANTIATE.findall(txt):
        if typ in SV_KEYWORDS or typ.lower() in BUILTIN_TYPES:
            continue
        if typ in symbol_to_file:
            fdef = symbol_to_file[typ]
            if fdef != file_abs:
                dep_files.add(fdef)
        # also allow typedef names used as interface-like types
        if typ in typedef_to_file:
            fdef = typedef_to_file[typ]
            if fdef != file_abs:
                dep_files.add(fdef)

    # E) bind Target BindMod
    for target, bindmod in RE_BIND.findall(txt):
        if target in symbol_to_file:
            fdef = symbol_to_file[target]
            if fdef != file_abs:
                dep_files.add(fdef)
        if bindmod in symbol_to_file:
            fdef = symbol_to_file[bindmod]
            if fdef != file_abs:
                dep_files.add(fdef)

    # F) macro usage -> macro defining file
    used_macros = extract_macro_usages(txt)
    for mac in used_macros:
        if mac in macro_to_file:
            fdef = macro_to_file[mac]
            if fdef != file_abs:
                dep_files.add(fdef)

    # G) typedef/struct/enum/union usage -> defining file
    type_tokens = extract_type_tokens(txt)
    for tok in type_tokens:
        if tok in typedef_to_file:
            fdef = typedef_to_file[tok]
            if fdef != file_abs:
                dep_files.add(fdef)

    return dep_files

# ---------- main ----------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jsonl", required=True, help="Path to systemverilog_dataset/test.jsonl")
    ap.add_argument("--repo-base", required=True, help="Path to SV repos base, e.g. .../Multi-hdl-language-repo/systemverilog")
    ap.add_argument("--print-top", type=int, default=0, help="Print top-N items with largest deps")
    ap.add_argument("--dump-jsonl", default="", help="Optional output jsonl path with deps per item")
    ap.add_argument("--mode", choices=["per_item", "per_file", "per_repo"], default="per_item",
                    help="Averaging mode: per_item (default), per_file (dedup same file), per_repo (avg of repo avgs)")
    ap.add_argument("--no-scan-incdir", action="store_true",
                    help="Disable scanning repo for +incdir/-I flags (use only repo_root + extra-incdir).")
    ap.add_argument("--extra-incdir", action="append", default=[],
                    help="Add extra include directory (relative to repo_root unless absolute). Can be repeated.")
    args = ap.parse_args()

    jsonl_path = Path(args.jsonl).resolve()
    repo_base = Path(args.repo_base).resolve()

    # Load tasks
    tasks = []
    with jsonl_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            if "file" not in obj:
                continue
            tasks.append(obj)

    # Group by repo
    repo_to_tasks = defaultdict(list)
    for t in tasks:
        repo_root = infer_repo_root(t["file"], repo_base)
        repo_to_tasks[str(repo_root)].append(t)

    item_results = []                  # (repo_root_str, file_abs_str, deps_count)
    per_file_deps: Dict[Path, int] = {}
    per_repo_deps_list = defaultdict(list)

    dump_fp = None
    if args.dump_jsonl:
        dump_fp = Path(args.dump_jsonl).resolve().open("w", encoding="utf-8")

    for repo_root_str, ts in repo_to_tasks.items():
        repo_root = Path(repo_root_str)
        if not repo_root.exists():
            continue

        symbol_to_file, pkg_to_file, macro_to_file, typedef_to_file, basename_to_paths, incdirs = build_repo_index(
            repo_root,
            do_scan_incdir=(not args.no_scan_incdir),
            extra_incdirs=args.extra_incdir
        )

        for t in ts:
            file_rel = t["file"]
            file_abs = file_abs_from_item(repo_root, file_rel)

            if file_abs in per_file_deps:
                deps_count = per_file_deps[file_abs]
            else:
                dep_files = deps_for_file(
                    file_abs, repo_root,
                    symbol_to_file, pkg_to_file, macro_to_file, typedef_to_file,
                    basename_to_paths, incdirs
                )
                dep_files.discard(file_abs)
                deps_count = len(dep_files)
                per_file_deps[file_abs] = deps_count

            item_results.append((repo_root_str, str(file_abs), deps_count))
            per_repo_deps_list[repo_root_str].append(deps_count)

            if dump_fp is not None:
                out = dict(t)
                out["cross_file_deps"] = deps_count
                dump_fp.write(json.dumps(out, ensure_ascii=False) + "\n")

    if dump_fp is not None:
        dump_fp.close()

    if not item_results:
        print("No results computed. Check paths.")
        return

    # Averaging
    if args.mode == "per_item":
        avg = sum(r[2] for r in item_results) / len(item_results)
        denom = len(item_results)
    elif args.mode == "per_file":
        vals = list(per_file_deps.values())
        avg = sum(vals) / len(vals)
        denom = len(vals)
    else:  # per_repo
        repo_avgs = []
        for repo_root_str, vals in per_repo_deps_list.items():
            if vals:
                repo_avgs.append(sum(vals) / len(vals))
        avg = sum(repo_avgs) / len(repo_avgs)
        denom = len(repo_avgs)

    print(f"[Mode={args.mode}] Average cross-file dependencies = {avg:.4f}  (N={denom})")

    if args.print_top and args.print_top > 0:
        item_results_sorted = sorted(item_results, key=lambda x: x[2], reverse=True)
        print(f"\nTop-{args.print_top} items by dependencies:")
        for repo_root_str, file_abs, deps in item_results_sorted[:args.print_top]:
            print(f"  deps={deps:4d}  repo={Path(repo_root_str).name}  file={file_abs}")


if __name__ == "__main__":
    main()
