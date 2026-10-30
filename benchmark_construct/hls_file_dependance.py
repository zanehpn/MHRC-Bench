#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Compute cross-file dependencies for HLS C/C++ tasks in a JSONL dataset.

deps(item) = number of DISTINCT other C/C++ files (g != f) in the same repo
             that f depends on.

Heuristic dependency signals (reproducible):
A) Preprocessor includes:
   - Parse #include "x" / #include <x> (best-effort)
   - Resolve using include search paths:
       * current file dir
       * repo_root
       * scanned -I / -isystem / -iquote / include_directories() / target_include_directories()
       * basename unique match
   - Optional transitive closure following headers: enabled by default.

B) Macro dependency:
   - Index: #define MACRO -> defining file
   - Usage: MACRO tokens in file (excluding C keywords) -> if definable uniquely, count that file.

C) typedef/struct/enum/union/class dependency:
   - Index: typedef NAME; / struct NAME / enum NAME / union NAME / class NAME -> defining file
   - Usage: type-like identifiers in file -> if definable uniquely, count that file.

Assumptions:
- item["file"] like RepoName/path/to/file.cpp (same dataset style)
- repos under --repo-base/RepoName
"""

import argparse
import json
import re
from pathlib import Path
from collections import defaultdict, deque
from typing import Dict, Set, List, Optional, Tuple

C_EXTS = (".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx")

# ---------- strip comments (C/C++) ----------
RE_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
RE_LINE_COMMENT = re.compile(r"//.*?$", re.M)

def strip_comments(s: str) -> str:
    s = RE_BLOCK_COMMENT.sub(" ", s)
    s = RE_LINE_COMMENT.sub(" ", s)
    return s

# ---------- includes ----------
RE_INCLUDE = re.compile(r'^\s*#\s*include\s*([<"])([^>"]+)[>"]', re.M)
# optional forced include flags (from build scripts)
RE_FORCE_INCLUDE = re.compile(r"(?:^|\s)-(?:include)\s+([^\s]+)")

# ---------- include path scanning ----------
RE_I = re.compile(r"(?:^|\s)-I\s*([^\s]+)")
RE_ISYSTEM = re.compile(r"(?:^|\s)-isystem\s*([^\s]+)")
RE_IQUOTE = re.compile(r"(?:^|\s)-iquote\s*([^\s]+)")

# CMake patterns (best-effort)
RE_CMAKE_INCLUDE_DIRS = re.compile(r"\binclude_directories\s*\(([^)]+)\)", re.I)
RE_CMAKE_TARGET_INCLUDE = re.compile(r"\btarget_include_directories\s*\(\s*([^\s]+)\s+([^)]+)\)", re.I)

# ---------- macro define / usage ----------
RE_DEFINE = re.compile(r'^\s*#\s*define\s+([A-Za-z_]\w*)\b', re.M)
RE_ID = re.compile(r'\b([A-Za-z_]\w*)\b')

C_KEYWORDS = {
    "auto","break","case","char","const","continue","default","do","double","else","enum","extern",
    "float","for","goto","if","inline","int","long","register","restrict","return","short","signed",
    "sizeof","static","struct","switch","typedef","union","unsigned","void","volatile","while",
    # C++
    "alignas","alignof","and","and_eq","asm","atomic_cancel","atomic_commit","atomic_noexcept",
    "bitand","bitor","bool","catch","char8_t","char16_t","char32_t","class","co_await","co_return",
    "co_yield","compl","concept","consteval","constexpr","constinit","const_cast","decltype","delete",
    "dynamic_cast","explicit","export","false","friend","mutable","namespace","new","noexcept","not",
    "not_eq","nullptr","operator","or","or_eq","private","protected","public","reflexpr","reinterpret_cast",
    "requires","static_assert","static_cast","template","this","thread_local","throw","true","try",
    "typeid","typename","using","virtual","wchar_t","xor","xor_eq",
}

# ---------- typedef / struct / enum / union / class definitions ----------
RE_TYPEDEF_NAME = re.compile(r'^\s*typedef\b[^;]*?\b([A-Za-z_]\w*)\s*;', re.M)
RE_SEU_CLASS_NAME = re.compile(r'^\s*(struct|enum|union|class)\s+([A-Za-z_]\w*)\b', re.M)

# crude type usage: capitalized or underscore? (HLS code often uses ap_uint, hls::stream etc.)
# We'll include identifiers that look like types (either CamelCase or contain underscores and digits)
RE_TYPELIKE = re.compile(r'\b([A-Za-z_]\w*)\b')

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

def is_c_file(p: Path) -> bool:
    return p.suffix.lower() in C_EXTS

# ---------- scan include dirs ----------
def scan_incdirs(repo_root: Path) -> List[Path]:
    """
    Scan repo for -I/-isystem/-iquote and CMake include_directories()/target_include_directories().
    Keep only existing dirs; resolve relative to repo_root.
    """
    patterns = [
        "Makefile", "makefile", "*.mk", "*.cmake", "CMakeLists.txt",
        "*.sh", "*.bash", "*.cmd", "*.txt", "*.args", "*.json", "*.yml", "*.yaml"
    ]
    files = []
    for pat in patterns:
        files.extend(repo_root.rglob(pat))

    seen = set()

    def add_path(p: str):
        p = p.strip().strip('"').strip("'")
        if "\x00" in p:
            return
        if any(ord(ch) < 32 for ch in p):
            return
        if len(p) > 4096:
            return
        if "${" in p or "$(" in p:
            return
        seen.add(p)


    for f in files:
        txt = read_text(f)
        if not txt:
            continue

        for m in RE_I.findall(txt):
            add_path(m)
        for m in RE_ISYSTEM.findall(txt):
            add_path(m)
        for m in RE_IQUOTE.findall(txt):
            add_path(m)

        for m in RE_CMAKE_INCLUDE_DIRS.findall(txt):
            blob = m
            # split by whitespace, remove keywords like SYSTEM/BEFORE if present
            for tok in re.split(r"[\s\n]+", blob):
                tok = tok.strip()
                if not tok or tok.upper() in {"SYSTEM","BEFORE"}:
                    continue
                add_path(tok)

        for _tgt, blob in RE_CMAKE_TARGET_INCLUDE.findall(txt):
            # blob may contain PRIVATE/PUBLIC/INTERFACE and dirs
            for tok in re.split(r"[\s\n]+", blob):
                tok = tok.strip()
                if not tok or tok.upper() in {"PRIVATE","PUBLIC","INTERFACE","SYSTEM","BEFORE"}:
                    continue
                add_path(tok)

    incdirs: List[Path] = []
    incdirs.append(repo_root.resolve())

    for p in sorted(seen):
        pp = Path(p)
        if not pp.is_absolute():
            pp = (repo_root / pp).resolve()
        if pp.exists() and pp.is_dir():
            incdirs.append(pp)

    # de-dup while preserving order
    uniq = []
    sset = set()
    for d in incdirs:
        s = str(d)
        if s not in sset:
            sset.add(s)
            uniq.append(d)
    return uniq

# ---------- build repo index ----------
def build_repo_index(repo_root: Path, do_scan_incdir: bool, extra_incdirs: List[str]):
    """
    Build:
      macro_to_files: macro -> set(files)
      type_to_files: typedef/struct/enum/union/class name -> set(files)
      basename_to_paths: basename -> set(paths) (for include resolution)
      incdirs: include search dirs
    """
    macro_to_files: Dict[str, Set[Path]] = defaultdict(set)
    type_to_files: Dict[str, Set[Path]] = defaultdict(set)
    basename_to_paths: Dict[str, Set[Path]] = defaultdict(set)

    c_files: List[Path] = []
    for ext in C_EXTS:
        c_files.extend(repo_root.rglob(f"*{ext}"))

    for f in c_files:
        basename_to_paths[f.name].add(f)
        txt = strip_comments(read_text(f))

        for mac in RE_DEFINE.findall(txt):
            macro_to_files[mac].add(f)

        for name in RE_TYPEDEF_NAME.findall(txt):
            type_to_files[name].add(f)

        for _k, name in RE_SEU_CLASS_NAME.findall(txt):
            type_to_files[name].add(f)

    incdirs = [repo_root.resolve()]
    if do_scan_incdir:
        incdirs = scan_incdirs(repo_root)

    for p in extra_incdirs:
        pp = Path(p)
        if not pp.is_absolute():
            pp = (repo_root / pp).resolve()
        if pp.exists() and pp.is_dir():
            incdirs.append(pp)

    # de-dup preserve order
    uniq = []
    seen = set()
    for d in incdirs:
        s = str(d)
        if s not in seen:
            seen.add(s)
            uniq.append(d)
    incdirs = uniq

    return macro_to_files, type_to_files, basename_to_paths, incdirs

# ---------- include resolver ----------
def resolve_include(
    inc: str,
    is_angle: bool,
    cur_file: Path,
    repo_root: Path,
    basename_to_paths: Dict[str, Set[Path]],
    incdirs: List[Path]
) -> Optional[Path]:
    """
    Resolve include file path. For "..." includes, try curdir first.
    Then search incdirs (repo_root + scanned).
    Finally try basename unique match.
    """
    inc = inc.strip()
    inc_path = Path(inc)

    variants = [inc]
    if inc_path.suffix == "":
        variants.extend([inc + ".h", inc + ".hpp", inc + ".hh", inc + ".hxx"])

    # quoted include: try local dir first
    if not is_angle:
        for v in variants:
            p = (cur_file.parent / v).resolve()
            if p.exists() and p.is_file() and str(p).startswith(str(repo_root)):
                return p

    # search include dirs
    for d in incdirs:
        for v in variants:
            p = (d / v).resolve()
            if p.exists() and p.is_file() and str(p).startswith(str(repo_root)):
                return p

    # basename unique
    base = Path(inc).name
    cands = list(basename_to_paths.get(base, []))
    if len(cands) == 1:
        return cands[0]
    if Path(base).suffix == "":
        for ext in [".h", ".hpp", ".hh", ".hxx"]:
            c2 = list(basename_to_paths.get(base + ext, []))
            if len(c2) == 1:
                return c2[0]

    return None

# ---------- extract macro usages ----------
def extract_macro_usages(txt: str) -> Set[str]:
    """
    Extract identifiers that look like macro usage.
    Heuristic: uppercase-ish tokens or tokens used in #if/#ifdef lines.
    We'll simply collect all identifiers and filter by not keyword,
    then intersect with known macro index during resolution.
    """
    ids = set(RE_ID.findall(txt))
    return {x for x in ids if x not in C_KEYWORDS}

# ---------- extract type usages ----------
def extract_type_usages(txt: str) -> Set[str]:
    """
    Extract identifiers that may be types. We'll take all identifiers
    (excluding keywords), then intersect with type index during resolution.
    """
    ids = set(RE_TYPELIKE.findall(txt))
    return {x for x in ids if x not in C_KEYWORDS}

# ---------- file deps computation ----------
def deps_for_file(
    file_abs: Path,
    repo_root: Path,
    macro_to_files: Dict[str, Set[Path]],
    type_to_files: Dict[str, Set[Path]],
    basename_to_paths: Dict[str, Set[Path]],
    incdirs: List[Path],
    include_closure: bool = True
) -> Set[Path]:
    """
    Compute deps for one file.
    If include_closure=True, follow includes transitively (within repo) and count all reached files.
    """
    dep_files: Set[Path] = set()

    # BFS over includes if closure enabled
    visited: Set[Path] = set()
    q = deque([file_abs])

    while q:
        cur = q.popleft()
        if cur in visited:
            continue
        visited.add(cur)

        txt_raw = read_text(cur)
        txt = strip_comments(txt_raw)

        # includes
        for delim, inc in RE_INCLUDE.findall(txt):
            is_angle = (delim == "<")
            resolved = resolve_include(inc, is_angle, cur, repo_root, basename_to_paths, incdirs)
            if resolved and resolved != file_abs:
                dep_files.add(resolved)
                if include_closure:
                    # only follow headers-ish and any c/cpp inside repo if included
                    q.append(resolved)

        # forced includes from build flags (rare to be inside source, but handle)
        for inc in RE_FORCE_INCLUDE.findall(txt_raw):
            resolved = resolve_include(inc, False, cur, repo_root, basename_to_paths, incdirs)
            if resolved and resolved != file_abs:
                dep_files.add(resolved)
                if include_closure:
                    q.append(resolved)

        # macro usages -> defining file(s)
        used_macros = extract_macro_usages(txt)
        for mac in used_macros:
            if mac in macro_to_files:
                defs = list(macro_to_files[mac])
                if len(defs) == 1:
                    fdef = defs[0]
                    if fdef != file_abs:
                        dep_files.add(fdef)
                        if include_closure:
                            q.append(fdef)

        # type usages -> defining file(s)
        used_types = extract_type_usages(txt)
        for ty in used_types:
            if ty in type_to_files:
                defs = list(type_to_files[ty])
                if len(defs) == 1:
                    fdef = defs[0]
                    if fdef != file_abs:
                        dep_files.add(fdef)
                        if include_closure:
                            q.append(fdef)

        if not include_closure:
            # only process the entry file once
            break

    dep_files.discard(file_abs)
    return dep_files

# ---------- main ----------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jsonl", required=True, help="Path to hls_dataset/test.jsonl (items must contain 'file')")
    ap.add_argument("--repo-base", required=True, help="Path to HLS C/C++ repos base, e.g. .../Multi-hdl-language-repo/hls")
    ap.add_argument("--print-top", type=int, default=0, help="Print top-N items with largest deps")
    ap.add_argument("--dump-jsonl", default="", help="Optional output jsonl path with deps per item")
    ap.add_argument("--mode", choices=["per_item", "per_file", "per_repo"], default="per_item",
                    help="Averaging mode: per_item (default), per_file (dedup same file), per_repo (avg of repo avgs)")
    ap.add_argument("--no-scan-incdir", action="store_true",
                    help="Disable scanning repo for -I/-isystem/-iquote/CMake include dirs.")
    ap.add_argument("--extra-incdir", action="append", default=[],
                    help="Add extra include directory (relative to repo_root unless absolute). Can be repeated.")
    ap.add_argument("--no-include-closure", action="store_true",
                    help="Disable transitive include closure; only count direct dependencies from the file itself.")
    args = ap.parse_args()

    jsonl_path = Path(args.jsonl).resolve()
    repo_base = Path(args.repo_base).resolve()

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

    repo_to_tasks = defaultdict(list)
    for t in tasks:
        repo_root = infer_repo_root(t["file"], repo_base)
        repo_to_tasks[str(repo_root)].append(t)

    item_results = []  # (repo_root_str, file_abs_str, deps_count)
    per_file_deps: Dict[Path, int] = {}
    per_repo_deps_list = defaultdict(list)

    dump_fp = None
    if args.dump_jsonl:
        dump_fp = Path(args.dump_jsonl).resolve().open("w", encoding="utf-8")

    for repo_root_str, ts in repo_to_tasks.items():
        repo_root = Path(repo_root_str)
        if not repo_root.exists():
            continue

        macro_to_files, type_to_files, basename_to_paths, incdirs = build_repo_index(
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
                    macro_to_files, type_to_files,
                    basename_to_paths, incdirs,
                    include_closure=(not args.no_include_closure)
                )
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

    if args.mode == "per_item":
        avg = sum(r[2] for r in item_results) / len(item_results)
        denom = len(item_results)
    elif args.mode == "per_file":
        vals = list(per_file_deps.values())
        avg = sum(vals) / len(vals)
        denom = len(vals)
    else:
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
