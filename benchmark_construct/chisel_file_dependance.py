#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Compute cross-file dependencies for Chisel/Scala tasks in a JSONL dataset.

Metric (task-level):
For each task item i with file f:
  deps(i) = number of DISTINCT other .scala files (g != f) in the same repo
            that define symbols referenced/needed by f.

We approximate "referenced symbols" using:
  A) Resolvable Scala imports (import a.b.C, a.b.{C,D}, a.b._, a.b.C._)
  B) Same-package symbol usage without import (common in Scala):
        - extends Foo / with Foo
        - new Foo(...)
        - Foo(...) (apply / object constructor style)
        - val x: Foo
        - foo: Foo
        - [Foo] type params (best-effort)
     These are mapped through a repo-wide top-level symbol index:
        FullyQualifiedName = package + top-level class/object/trait -> defining file.

Output:
  - Average over items: avg = sum(deps(item)) / N
  - Optional: dump per-item deps to jsonl
  - Top-N items by deps
"""

import argparse
import json
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, Set, List, Tuple


RE_PACKAGE = re.compile(r'^\s*package\s+([a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)*)\s*$', re.M)
RE_IMPORT_LINE = re.compile(r'^\s*import\s+(.+?)\s*$', re.M)

# top-level defs (coarse)
RE_TOP_DEF = re.compile(
    r'^\s*(?:final\s+|sealed\s+|abstract\s+|private\s+|protected\s+)*'
    r'(class|object|trait)\s+([A-Za-z_]\w*)', re.M
)

# Heuristic symbol usages inside Scala source
RE_EXTENDS_WITH = re.compile(r'^\s*(?:class|object|trait)\s+[A-Za-z_]\w*\s*(?:\[[^\]]+\])?\s*extends\s+([^{\n]+)', re.M)
RE_NEW = re.compile(r'\bnew\s+([A-Z][A-Za-z0-9_]*)\b')
RE_TYPE_ANNOT = re.compile(r':\s*([A-Z][A-Za-z0-9_]*)\b')
RE_GENERIC = re.compile(r'\[\s*([A-Z][A-Za-z0-9_]*)\s*(?:[, \]]|$)')
RE_CALL_CAP = re.compile(r'\b([A-Z][A-Za-z0-9_]*)\s*\(')  # Foo(...)
RE_QUALIFIED = re.compile(r'\b([a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)+)\b')  # a.b.C or a.b.c

# Drop stdlib-ish imports to avoid counting external deps
STD_IMPORT_PREFIX = (
    "scala.", "java.", "javax.", "sun.",
    "chisel3.", "circt.", "firrtl."
)

# Lines we can ignore to reduce false positives
RE_COMMENT_LINE = re.compile(r'^\s*//.*$', re.M)
RE_BLOCK_COMMENT = re.compile(r'/\*.*?\*/', re.S)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def strip_comments(text: str) -> str:
    text = RE_BLOCK_COMMENT.sub(" ", text)
    text = RE_COMMENT_LINE.sub(" ", text)
    return text


def parse_package(text: str) -> str:
    m = RE_PACKAGE.search(text)
    return m.group(1) if m else ""


def parse_top_defs(text: str) -> List[str]:
    return [m.group(2) for m in RE_TOP_DEF.finditer(text)]


def parse_imports(text: str) -> List[str]:
    imports = []
    for m in RE_IMPORT_LINE.finditer(text):
        imports.append(m.group(1).strip().rstrip(";"))
    return imports


def normalize_import_spec(spec: str) -> Tuple[str, List[str], bool]:
    """
    Expand a Scala import spec into (base, names, is_wildcard).
    """
    spec = spec.strip()
    if spec.endswith(";"):
        spec = spec[:-1].strip()

    if spec.endswith("._"):
        base = spec[:-2].strip()
        return base, [], True

    brace_m = re.match(r'^(.+?)\.\{(.+)\}\s*$', spec)
    if brace_m:
        base = brace_m.group(1).strip()
        inner = brace_m.group(2).strip()
        parts = [p.strip() for p in inner.split(",") if p.strip()]
        names = []
        wildcard = False
        for p in parts:
            if p == "_":
                wildcard = True
                continue
            p = p.split("=>", 1)[0].strip()  # rename
            names.append(p)
        return base, names, wildcard

    if "." in spec:
        base, name = spec.rsplit(".", 1)
        return base.strip(), [name.strip()], False

    return "", [spec], False


def is_std_import(base: str) -> bool:
    base = base.strip()
    return any(base.startswith(pref) for pref in STD_IMPORT_PREFIX)


def build_repo_index(repo_root: Path):
    """
    Build:
      fqname_to_file: 'pkg.Name' -> Path
      pkg_to_files: 'pkg' -> set(Path)
      name_to_fq: 'Name' -> set('pkg.Name')  (handle duplicates)
    """
    fqname_to_file: Dict[str, Path] = {}
    pkg_to_files: Dict[str, Set[Path]] = defaultdict(set)
    name_to_fq: Dict[str, Set[str]] = defaultdict(set)

    scala_files = list(repo_root.rglob("*.scala"))
    for f in scala_files:
        text = read_text(f)
        text = strip_comments(text)
        pkg = parse_package(text)
        pkg_to_files[pkg].add(f)

        for name in parse_top_defs(text):
            fq = f"{pkg}.{name}" if pkg else name
            if fq not in fqname_to_file:
                fqname_to_file[fq] = f
            name_to_fq[name].add(fq)

    return fqname_to_file, pkg_to_files, name_to_fq


def resolve_imports_to_files(import_specs, fqname_to_file, pkg_to_files, self_file: Path) -> Set[Path]:
    dep_files: Set[Path] = set()

    for spec in import_specs:
        base, names, wildcard = normalize_import_spec(spec)

        if base and is_std_import(base):
            continue

        if wildcard:
            # Treat base as package
            if base in pkg_to_files:
                for f in pkg_to_files[base]:
                    if f != self_file:
                        dep_files.add(f)
                continue
            # Treat base as fqname
            if base in fqname_to_file:
                fdef = fqname_to_file[base]
                if fdef != self_file:
                    dep_files.add(fdef)
                pkg = base.rsplit(".", 1)[0] if "." in base else ""
                if pkg in pkg_to_files:
                    for f in pkg_to_files[pkg]:
                        if f != self_file:
                            dep_files.add(f)
                continue
            continue

        if base:
            for n in names:
                n = n.split(".", 1)[0].strip()
                fq = f"{base}.{n}"
                if fq in fqname_to_file:
                    fdef = fqname_to_file[fq]
                    if fdef != self_file:
                        dep_files.add(fdef)

    return dep_files


def extract_symbol_usages(text: str) -> Set[str]:
    """
    Extract candidate type/object names used in the file (not definitions),
    best-effort, focusing on capitalized identifiers.
    Returns a set of simple names (e.g., Foo, Bar).
    """
    text = strip_comments(text)

    symbols: Set[str] = set()

    # extends/with clause: may contain "Foo with Bar[...]" etc.
    for m in RE_EXTENDS_WITH.finditer(text):
        clause = m.group(1)
        # pick capitalized tokens
        for tok in re.findall(r'\b([A-Z][A-Za-z0-9_]*)\b', clause):
            symbols.add(tok)

    for m in RE_NEW.finditer(text):
        symbols.add(m.group(1))

    for m in RE_TYPE_ANNOT.finditer(text):
        symbols.add(m.group(1))

    for m in RE_GENERIC.finditer(text):
        symbols.add(m.group(1))

    for m in RE_CALL_CAP.finditer(text):
        symbols.add(m.group(1))

    return symbols


def resolve_symbols_to_files(
    symbols: Set[str],
    file_pkg: str,
    fqname_to_file: Dict[str, Path],
    name_to_fq: Dict[str, Set[str]],
    self_file: Path
) -> Set[Path]:
    """
    Map candidate symbols to defining files using:
      1) same-package match (pkg.Symbol)
      2) if unique in repo, use that
      3) otherwise ignore ambiguous to keep reproducibility conservative
    """
    dep_files: Set[Path] = set()

    for sym in symbols:
        # 1) same package
        if file_pkg:
            fq = f"{file_pkg}.{sym}"
            if fq in fqname_to_file:
                fdef = fqname_to_file[fq]
                if fdef != self_file:
                    dep_files.add(fdef)
                continue

        # 2) unique in repo
        fqs = list(name_to_fq.get(sym, []))
        if len(fqs) == 1:
            fq = fqs[0]
            fdef = fqname_to_file.get(fq)
            if fdef and fdef != self_file:
                dep_files.add(fdef)

        # 3) ambiguous => ignore (stable policy)

    return dep_files


def infer_repo_root(file_rel: str, repo_base: Path) -> Path:
    first = file_rel.split("/", 1)[0]
    return repo_base / first


def file_abs_from_item(repo_root: Path, file_rel: str) -> Path:
    """
    file_rel like: RepoName/src/main/scala/X.scala
    => repo_root is .../RepoName
    => file_abs is .../RepoName/src/main/scala/X.scala
    """
    if file_rel.startswith(repo_root.name + "/"):
        sub = "/".join(file_rel.split("/")[1:])
        return (repo_root / sub).resolve()
    if "/" in file_rel:
        return (repo_root / file_rel.split("/", 1)[1]).resolve()
    return (repo_root / file_rel).resolve()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jsonl", required=True, help="Path to chisel_dataset/test.jsonl")
    ap.add_argument("--repo-base", required=True, help="Path to chisel repos base, e.g. .../Multi-hdl-language-repo/chisel")
    ap.add_argument("--print-top", type=int, default=0, help="Print top-N items with largest deps")
    ap.add_argument("--dump-jsonl", default="", help="Optional output jsonl path with deps per item")
    ap.add_argument("--mode", choices=["per_item", "per_file", "per_repo"], default="per_item",
                    help="Averaging mode: per_item (default), per_file (dedup same file), per_repo (avg of repo avgs)")
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

    # Group tasks by repo
    repo_to_tasks = defaultdict(list)
    for t in tasks:
        repo_root = infer_repo_root(t["file"], repo_base)
        repo_to_tasks[str(repo_root)].append(t)

    # Results
    item_results = []          # (repo_root_str, file_abs_str, deps_count)
    per_file_deps = {}         # file_abs -> deps_count
    per_repo_deps_list = defaultdict(list)

    dump_fp = None
    if args.dump_jsonl:
        dump_fp = Path(args.dump_jsonl).resolve().open("w", encoding="utf-8")

    for repo_root_str, ts in repo_to_tasks.items():
        repo_root = Path(repo_root_str)
        if not repo_root.exists():
            continue

        fqname_to_file, pkg_to_files, name_to_fq = build_repo_index(repo_root)

        for t in ts:
            file_rel = t["file"]
            file_abs = file_abs_from_item(repo_root, file_rel)

            if file_abs in per_file_deps:
                deps_count = per_file_deps[file_abs]
            else:
                text = read_text(file_abs)
                text_nc = strip_comments(text)
                file_pkg = parse_package(text_nc)

                # A) imports -> files
                imps = parse_imports(text_nc)
                dep_files = resolve_imports_to_files(imps, fqname_to_file, pkg_to_files, file_abs)

                # B) symbol usages -> files (same pkg / unique)
                syms = extract_symbol_usages(text_nc)
                dep_files |= resolve_symbols_to_files(syms, file_pkg, fqname_to_file, name_to_fq, file_abs)

                # exclude self
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

    # Optionally print top-N items
    if args.print_top and args.print_top > 0:
        item_results_sorted = sorted(item_results, key=lambda x: x[2], reverse=True)
        print(f"\nTop-{args.print_top} items by dependencies:")
        for repo_root_str, file_abs, deps in item_results_sorted[:args.print_top]:
            print(f"  deps={deps:4d}  repo={Path(repo_root_str).name}  file={file_abs}")


if __name__ == "__main__":
    main()
