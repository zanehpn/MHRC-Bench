#!/usr/bin/env python3

import os
import requests
import time
import argparse
import subprocess
import json

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
if not GITHUB_TOKEN:
    raise SystemExit("Please set GITHUB_TOKEN")

HEADERS = {
    "Authorization": f"token {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json",
}

SEARCH_URL = "https://api.github.com/search/repositories"


# -----------------------------
# Language -> default extensions
# -----------------------------
LANG_EXTS = {
    # RTL
    "verilog": [".v", ".vh"],
    "systemverilog": [".sv"],

    # VHDL
    "vhdl": [".vhd", ".vhdl"],

    # Chisel (Scala-based HDL)
    "chisel": [".scala"],

    # HLS C/C++
    "hls": [".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx"],
    "c": [".c", ".h"],
    "cpp": [".cc", ".cpp", ".cxx", ".hh", ".hpp", ".hxx"],
}


def normalize_exts(exts):
    out = []
    for e in exts:
        e = e.strip().lower()
        if not e:
            continue
        if not e.startswith("."):
            e = "." + e
        out.append(e)
    return sorted(set(out))


# -----------------------------
# GitHub Search
# -----------------------------
def search_repos(query, per_page=30, max_pages=10):
    repos = []
    for page in range(1, max_pages + 1):
        params = {"q": query, "per_page": per_page, "page": page}
        r = requests.get(SEARCH_URL, headers=HEADERS, params=params)
        if r.status_code != 200:
            print("Search API error:", r.status_code, r.text)
            break

        data = r.json()
        items = data.get("items", [])
        repos.extend(items)

        if "next" not in r.links:
            break

        time.sleep(1)
    return repos


# -----------------------------
# Shallow clone
# -----------------------------
def clone_repo(clone_url, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    repo_name = clone_url.split("/")[-1].replace(".git", "")
    target = os.path.join(dest_dir, repo_name)

    if os.path.exists(target):
        print("Already exists, skip:", repo_name)
        return target

    cmd = ["git", "clone", "--depth", "1", clone_url, target]
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return target


# -----------------------------
# Count files by extension
# -----------------------------
def count_files_by_ext(repo_dir, exts):
    exts = set(normalize_exts(exts))
    cnt = 0
    for root, dirs, files in os.walk(repo_dir):
        if ".git" in dirs:
            dirs.remove(".git")
        for f in files:
            _, ext = os.path.splitext(f)
            if ext.lower() in exts:
                cnt += 1
    return cnt


# -----------------------------
# Build query by language
# -----------------------------
def build_github_query(lang: str, min_stars: int, created_after: str) -> str:
    """
    Note: GitHub search "language:" values are GitHub Linguist languages.
    For Chisel, most repos will be detected as Scala.
    """
    lang = lang.lower()
    if lang in ("verilog"):
        gh_lang = "Verilog"  # GitHub language label
    if lang in ("systemverilog"):
        gh_lang = "SystemVerilog"
    elif lang == "vhdl":
        gh_lang = "VHDL"
    elif lang == "chisel":
        gh_lang = "Scala"
    elif lang in ("hls", "c", "cpp"):
        # HLS projects may be labeled as C or C++ (or not at all). Pick C++ as default.
        gh_lang = "C++"
    else:
        raise ValueError(f"Unsupported --lang: {lang}")
    if lang == "chisel":
        return f"chisel language:{gh_lang} stars:>={min_stars} created:>{created_after} topic:chisel"
    elif lang == "hls":
        return f"High level synthesis language:{gh_lang} stars:>={min_stars} created:>{created_after}"
    else:
        return f"language:{gh_lang} stars:>={min_stars} created:>{created_after}"


# -----------------------------
# Main
# -----------------------------
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", required=True,
                        choices=["verilog", "systemverilog", "vhdl", "chisel", "hls", "c", "cpp"],
                        help="Language family used to set default extensions and GitHub search language.")
    parser.add_argument("--min-stars", type=int, default=5)
    parser.add_argument("--created-after", type=str, default="2000-01-01")
    parser.add_argument("--min-files", type=int, default=10)
    parser.add_argument("--max-files", type=int, default=50)
    parser.add_argument("--dest", default="./repos")
    parser.add_argument("--max-pages", type=int, default=10)

    # Optional override: if user passes --ext, it overrides LANG_EXTS[lang]
    parser.add_argument("--ext", action="append", default=None,
                        help="Override file extensions to count (repeatable): --ext .v --ext .sv")

    args = parser.parse_args()

    lang = args.lang.lower()
    default_exts = LANG_EXTS.get(lang)
    if not default_exts:
        raise SystemExit(f"No default extensions for lang={args.lang}")

    exts = normalize_exts(args.ext) if args.ext else normalize_exts(default_exts)

    query = build_github_query(args.lang, args.min_stars, args.created_after)
    print("GitHub query:", query)
    print("Counting extensions:", exts)

    repos = search_repos(query, per_page=30, max_pages=args.max_pages)
    print("Candidate repos:", len(repos))

    kept = 0
    os.makedirs(args.dest, exist_ok=True)

    for r in repos:
        name = r["full_name"]
        print(f"\nChecking {name} ...")

        try:
            repo_dir = clone_repo(r["clone_url"], args.dest)
        except Exception as e:
            print("  clone failed:", e)
            continue

        file_cnt = count_files_by_ext(repo_dir, exts)
        print(f"  matched file count = {file_cnt}")

        if args.min_files <= file_cnt <= args.max_files:
            print("  ✔ keep")
            kept += 1
        else:
            print("  ✘ remove (outside range)")
            subprocess.call(["rm", "-rf", repo_dir])

        time.sleep(0.5)

    print(f"\n✅ Done. Kept {kept} repos in {args.dest}")


if __name__ == "__main__":
    main()
