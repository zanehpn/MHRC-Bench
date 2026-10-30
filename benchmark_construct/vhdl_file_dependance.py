#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Compute cross-file dependencies for VHDL tasks in a JSONL dataset.

deps(item) = number of DISTINCT other VHDL files (g != f) in the same repo
             that f depends on.

Heuristic dependency signals (reproducible):
A) library/use/context
   - use lib.pkg.all; / use lib.pkg.sym;
   - context lib.ctx;
   Resolve to repo-internal units via a repo-wide index:
     package / package body / entity / configuration / context

B) Instantiation
   - label: entity lib.ent(arch) port map ...
   - label: ent port map ...   (component instantiation)

C) Token-based references (unique/ambiguous policy controlled)
   - entity Foo / component Foo / package Bar tokens in the file
   - architecture ... of <entity>
   - configuration <cfg> of <entity>

D) Optional aggressive tokens (enable with --aggressive-tokens):
   - work.<name> / lib.<name> references (only if lib in internal libs)
   - <name>'range / <name>'length / <name>'left / ...  (whitelist)
   - <name>_t / <name>_type suffix patterns

Ambiguity handling:
  --ambiguity-policy ignore : only count repo-internal matches when name resolves uniquely (most conservative)
  --ambiguity-policy first  : if multiple files define same name, pick lexicographically first file (stable)
  --ambiguity-policy all    : if multiple files define same name, count ALL those files (largest deps; good for coupling metric)

Assumptions:
- item["file"] like RepoName/path/to/file.vhd
- repos under --repo-base/RepoName
"""

import argparse
import json
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, Set, List, Tuple, Optional

VHDL_EXTS = (".vhd", ".vhdl")

# ---------- comment stripping ----------
# VHDL single-line comments start with --
RE_LINE_COMMENT = re.compile(r"--.*?$", re.M)

def strip_comments(s: str) -> str:
    return RE_LINE_COMMENT.sub(" ", s)

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

def _lower(s: str) -> str:
    return (s or "").strip().lower()

# ---------- VHDL regex ----------
# use lib.pkg.all;   use lib.pkg.sym;
RE_USE = re.compile(r'(?im)^\s*use\s+([a-zA-Z_]\w*)\.\s*([a-zA-Z_]\w*)\.\s*(all|[a-zA-Z_]\w*)\s*;', re.M)
# context lib.ctx;
RE_CONTEXT_REF = re.compile(r'(?im)^\s*context\s+([a-zA-Z_]\w*)\.\s*([a-zA-Z_]\w*)\s*;', re.M)

# definitions
RE_ENTITY_DEF = re.compile(r'(?im)^\s*entity\s+([a-zA-Z_]\w*)\s+is\b', re.M)
RE_PACKAGE_DEF = re.compile(r'(?im)^\s*package\s+(?!body\b)([a-zA-Z_]\w*)\s+is\b', re.M)
RE_PACKAGE_BODY_DEF = re.compile(r'(?im)^\s*package\s+body\s+([a-zA-Z_]\w*)\s+is\b', re.M)
RE_CONTEXT_DEF = re.compile(r'(?im)^\s*context\s+([a-zA-Z_]\w*)\s+is\b', re.M)
RE_CONFIGURATION_DEF = re.compile(r'(?im)^\s*configuration\s+([a-zA-Z_]\w*)\s+of\s+([a-zA-Z_]\w*)\s+is\b', re.M)
RE_ARCH_DEF = re.compile(r'(?im)^\s*architecture\s+([a-zA-Z_]\w*)\s+of\s+([a-zA-Z_]\w*)\s+is\b', re.M)

# instantiation
# u0: entity work.foo(rtl) port map ...
RE_ENTITY_INST = re.compile(r'(?im)^\s*\w+\s*:\s*entity\s+([a-zA-Z_]\w*)\.\s*([a-zA-Z_]\w*)', re.M)
# component instantiation: u0: Foo port map ...
RE_COMP_INST = re.compile(r'(?im)^\s*\w+\s*:\s*([a-zA-Z_]\w*)\s*(?:generic\s+map|port\s+map|\()', re.M)

# ---------- token-based fallback extraction ----------
RE_ENTITY_TOKEN = re.compile(r'(?im)\bentity\s+([a-zA-Z_]\w*)\b')
RE_COMPONENT_TOKEN = re.compile(r'(?im)\bcomponent\s+([a-zA-Z_]\w*)\b')
RE_PACKAGE_TOKEN = re.compile(r'(?im)\bpackage\s+(?:body\s+)?([a-zA-Z_]\w*)\b')
RE_ARCH_OF_ENTITY = re.compile(r'(?im)\barchitecture\s+[a-zA-Z_]\w*\s+of\s+([a-zA-Z_]\w*)\b')
RE_CFG_OF_ENTITY = re.compile(r'(?im)\bconfiguration\s+([a-zA-Z_]\w*)\s+of\s+([a-zA-Z_]\w*)\b')

# ---------- aggressive token regex ----------
# work.foo / mylib.foo / work.foo.all / work.foo.bar
RE_LIB_DOT_NAME = re.compile(r'(?i)\b([a-zA-Z_]\w*)\s*\.\s*([a-zA-Z_]\w*)\b')
# name'range / name'length / ...
RE_ATTR = re.compile(r"(?i)\b([a-zA-Z_]\w*)\s*'\s*([a-zA-Z_]\w*)\b")
# name_t / name_type
RE_SUFFIX_T = re.compile(r"(?i)\b([a-zA-Z_]\w*)_(t|type)\b")

# keywords to avoid false positives
VHDL_KEYWORDS = {
    "process","block","generate","if","for","while","case","when","with","select",
    "port","generic","map","entity","architecture","configuration","package","body","context",
    "signal","variable","constant","type","subtype","record","array","procedure","function",
    "begin","end","is","of","all","others","work","library","use","component",
    "in","out","inout","buffer","linkage","downto","to","range","mod","rem","and","or","xor",
    "not","nor","nand","xnor","null","loop","exit","next","return","assert","report","severity",
    "wait","until","then","elsif","else","open","after","transport","reject","on"
}

# attributes worth considering (others ignored to avoid noise)
VHDL_ATTR_WHITELIST = {
    "range","length","left","right","high","low","ascending","descending","event","stable","quiet","delayed"
}

# ---------- build repo index ----------
def build_repo_index(repo_root: Path):
    """
    Build indices mapping unit name -> set(files)
    """
    entity_to_files: Dict[str, Set[Path]] = defaultdict(set)
    package_to_files: Dict[str, Set[Path]] = defaultdict(set)
    context_to_files: Dict[str, Set[Path]] = defaultdict(set)
    configuration_to_files: Dict[str, Set[Path]] = defaultdict(set)

    vhdl_files: List[Path] = []
    for ext in VHDL_EXTS:
        vhdl_files.extend(repo_root.rglob(f"*{ext}"))

    for f in vhdl_files:
        txt = strip_comments(read_text(f))

        for ent in RE_ENTITY_DEF.findall(txt):
            entity_to_files[_lower(ent)].add(f)

        for pkg in RE_PACKAGE_DEF.findall(txt):
            package_to_files[_lower(pkg)].add(f)

        for pkgb in RE_PACKAGE_BODY_DEF.findall(txt):
            package_to_files[_lower(pkgb)].add(f)

        for ctx in RE_CONTEXT_DEF.findall(txt):
            context_to_files[_lower(ctx)].add(f)

        for cfg, _ent in RE_CONFIGURATION_DEF.findall(txt):
            configuration_to_files[_lower(cfg)].add(f)

        # architectures are tied to entity; not separately indexed here

    return entity_to_files, package_to_files, context_to_files, configuration_to_files

# ---------- ambiguity policy helpers ----------
def pick_files(files: Set[Path], policy: str) -> Set[Path]:
    """
    policy:
      ignore: return empty if ambiguous (>1)
      first : pick lexicographically first (stable)
      all   : return all candidates
    """
    if not files:
        return set()
    if len(files) == 1:
        return set(files)
    if policy == "ignore":
        return set()
    files_sorted = sorted(files, key=lambda p: str(p))
    if policy == "first":
        return {files_sorted[0]}
    # all
    return set(files_sorted)

def resolve_any_unit(
    name_l: str,
    entity_to_files: Dict[str, Set[Path]],
    package_to_files: Dict[str, Set[Path]],
    context_to_files: Dict[str, Set[Path]],
    configuration_to_files: Dict[str, Set[Path]],
    policy: str
) -> Set[Path]:
    """
    Resolve a token name to repo-internal files per ambiguity policy.
    Prefer package/entity/context/config order.
    """
    if not name_l or name_l in VHDL_KEYWORDS:
        return set()

    out = pick_files(package_to_files.get(name_l, set()), policy)
    if out:
        return out
    out = pick_files(entity_to_files.get(name_l, set()), policy)
    if out:
        return out
    out = pick_files(context_to_files.get(name_l, set()), policy)
    if out:
        return out
    out = pick_files(configuration_to_files.get(name_l, set()), policy)
    return out

# ---------- token extraction ----------
def extract_reference_tokens(txt: str) -> Tuple[Set[str], Set[str], Set[str], Set[str]]:
    ent: Set[str] = set()
    comp: Set[str] = set()
    pkg: Set[str] = set()
    cfg: Set[str] = set()

    for x in RE_ENTITY_TOKEN.findall(txt):
        xl = _lower(x)
        if xl and xl not in VHDL_KEYWORDS:
            ent.add(xl)

    for x in RE_COMPONENT_TOKEN.findall(txt):
        xl = _lower(x)
        if xl and xl not in VHDL_KEYWORDS:
            comp.add(xl)

    for x in RE_PACKAGE_TOKEN.findall(txt):
        xl = _lower(x)
        if xl and xl not in VHDL_KEYWORDS:
            pkg.add(xl)

    for x in RE_ARCH_OF_ENTITY.findall(txt):
        xl = _lower(x)
        if xl and xl not in VHDL_KEYWORDS:
            ent.add(xl)

    for c, e in RE_CFG_OF_ENTITY.findall(txt):
        cl = _lower(c)
        el = _lower(e)
        if cl and cl not in VHDL_KEYWORDS:
            cfg.add(cl)
        if el and el not in VHDL_KEYWORDS:
            ent.add(el)

    return ent, comp, pkg, cfg

def extract_aggressive_tokens(txt: str, internal_libs: Set[str]) -> Set[str]:
    """
    Aggressive tokens that might imply unit dependencies.
    Returns lower-case candidate names.
    """
    cands: Set[str] = set()

    # lib.name patterns (only keep if lib is internal)
    for lib, name in RE_LIB_DOT_NAME.findall(txt):
        lib_l = _lower(lib)
        name_l = _lower(name)
        if lib_l in internal_libs and name_l and name_l not in VHDL_KEYWORDS:
            cands.add(name_l)

    # attribute patterns: name'range, name'length ...
    for base, attr in RE_ATTR.findall(txt):
        base_l = _lower(base)
        attr_l = _lower(attr)
        if attr_l in VHDL_ATTR_WHITELIST and base_l and base_l not in VHDL_KEYWORDS:
            cands.add(base_l)

    # suffix patterns: foo_t / foo_type
    for base, _suf in RE_SUFFIX_T.findall(txt):
        base_l = _lower(base)
        if base_l and base_l not in VHDL_KEYWORDS:
            # try base and common full forms
            cands.add(base_l)
            cands.add(f"{base_l}_t")
            cands.add(f"{base_l}_type")

    return cands

# ---------- deps for one file ----------
def deps_for_file(
    file_abs: Path,
    repo_root: Path,
    entity_to_files: Dict[str, Set[Path]],
    package_to_files: Dict[str, Set[Path]],
    context_to_files: Dict[str, Set[Path]],
    configuration_to_files: Dict[str, Set[Path]],
    internal_libs: Set[str],
    aggressive_tokens: bool,
    ambiguity_policy: str,
) -> Set[Path]:
    txt = strip_comments(read_text(file_abs))
    dep_files: Set[Path] = set()

    def add_all(files: Set[Path]):
        for f in files:
            if f != file_abs:
                dep_files.add(f)

    # A) use lib.pkg.*
    for lib, pkg, _what in RE_USE.findall(txt):
        lib_l = _lower(lib)
        pkg_l = _lower(pkg)
        if lib_l in internal_libs:
            add_all(pick_files(package_to_files.get(pkg_l, set()), ambiguity_policy))

    # B) context lib.ctx
    for lib, ctx in RE_CONTEXT_REF.findall(txt):
        lib_l = _lower(lib)
        ctx_l = _lower(ctx)
        if lib_l in internal_libs:
            add_all(pick_files(context_to_files.get(ctx_l, set()), ambiguity_policy))

    # C) entity instantiation: entity lib.ent
    for lib, ent in RE_ENTITY_INST.findall(txt):
        lib_l = _lower(lib)
        ent_l = _lower(ent)
        if lib_l in internal_libs:
            add_all(pick_files(entity_to_files.get(ent_l, set()), ambiguity_policy))

    # D) component instantiation: u0: Foo port map ...
    for comp in RE_COMP_INST.findall(txt):
        cl = _lower(comp)
        if not cl or cl in VHDL_KEYWORDS:
            continue
        add_all(pick_files(entity_to_files.get(cl, set()), ambiguity_policy))

    # E) token-based fallback (controlled by ambiguity_policy)
    ent_toks, comp_toks, pkg_toks, cfg_toks = extract_reference_tokens(txt)

    for name in ent_toks:
        add_all(pick_files(entity_to_files.get(name, set()), ambiguity_policy))

    for name in comp_toks:
        add_all(pick_files(entity_to_files.get(name, set()), ambiguity_policy))

    for name in pkg_toks:
        add_all(pick_files(package_to_files.get(name, set()), ambiguity_policy))

    for name in cfg_toks:
        add_all(pick_files(configuration_to_files.get(name, set()), ambiguity_policy))

    # F) aggressive tokens
    if aggressive_tokens:
        cands = extract_aggressive_tokens(txt, internal_libs=internal_libs)
        for name in cands:
            add_all(resolve_any_unit(
                name,
                entity_to_files, package_to_files, context_to_files, configuration_to_files,
                ambiguity_policy
            ))

    dep_files.discard(file_abs)
    return dep_files

# ---------- main ----------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jsonl", required=True, help="Path to vhdl_dataset/test.jsonl (items must contain 'file')")
    ap.add_argument("--repo-base", required=True, help="Path to VHDL repos base, e.g. .../Multi-hdl-language-repo/vhdl")
    ap.add_argument("--print-top", type=int, default=0, help="Print top-N items with largest deps")
    ap.add_argument("--dump-jsonl", default="", help="Optional output jsonl path with deps per item")
    ap.add_argument("--mode", choices=["per_item", "per_file", "per_repo"], default="per_item",
                    help="Averaging mode: per_item (default), per_file (dedup same file), per_repo (avg of repo avgs)")
    ap.add_argument("--treat-lib-internal", action="append", default=[],
                    help="Mark additional VHDL library as repo-internal (default: only work). Can be repeated.")
    ap.add_argument("--aggressive-tokens", action="store_true",
                    help="Enable aggressive token heuristics: work.<name>, <name>'range, <name>_t, etc.")
    ap.add_argument("--ambiguity-policy", choices=["ignore", "first", "all"], default="ignore",
                    help="How to handle non-unique matches inside repo.")
    args = ap.parse_args()

    jsonl_path = Path(args.jsonl).resolve()
    repo_base = Path(args.repo_base).resolve()

    internal_libs = {"work"}
    for x in args.treat_lib_internal:
        x = (x or "").strip()
        if x:
            internal_libs.add(x.lower())

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

        entity_to_files, package_to_files, context_to_files, configuration_to_files = build_repo_index(repo_root)

        for t in ts:
            file_rel = t["file"]
            file_abs = file_abs_from_item(repo_root, file_rel)

            if file_abs in per_file_deps:
                deps_count = per_file_deps[file_abs]
            else:
                dep_files = deps_for_file(
                    file_abs, repo_root,
                    entity_to_files, package_to_files, context_to_files, configuration_to_files,
                    internal_libs=internal_libs,
                    aggressive_tokens=args.aggressive_tokens,
                    ambiguity_policy=args.ambiguity_policy
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

    # Averaging
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
