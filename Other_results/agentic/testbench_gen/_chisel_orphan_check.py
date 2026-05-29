#!/usr/bin/env python3
"""Syntax/parse check for the CHISEL orphan cases (missing_tb: isolated, no
sibling references, mostly pure-definition files).

The original _orphan_compile_check.py SKIPPED chisel ("no local sbt/coursier").
This is the chisel branch it was missing. A full chiseltest simulation is
impossible for these files (no behaviour to drive, and a single isolated file
cannot type-check without its cross-file repo deps + the chisel3 classpath).
But a clean PARSE proves the file is syntactically self-consistent valid
Scala/Chisel source -> indirect verification, exactly like `ghdl -a` /
`iverilog -t null` give for the SV/VHDL orphans.

Toolchain: bootstraps a Scala 2.13 compiler classpath via the bundled coursier
launcher (downloaded once into .scala_toolchain/). Runs, per file:
    java -cp <scalac-cp> scala.tools.nsc.Main -usejavacp -Ystop-after:parser <file>
parser-only -> no chisel3 jars or sibling sources needed, no false failures
from missing repo deps.

Writes _compile_check.json into each case dir and a summary jsonl. Local-only,
zero codex usage.
"""
import json, os, re, subprocess, sys, time, urllib.request, gzip, shutil
from concurrent.futures import ProcessPoolExecutor, as_completed
from collections import Counter

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = "/ssd1/zqy/Multi-hdl-language-repo/MHRC-Bench/Other_results"
CH   = ROOT + "/chisel_dataset_testbench/function_verify"
TOOLDIR = os.path.join(BASE, ".scala_toolchain")
CS      = os.path.join(TOOLDIR, "cs")
CP_FILE = os.path.join(TOOLDIR, "scalac_2.13.cp")
SCALA_COMPILER = "org.scala-lang:scala-compiler:2.13.12"
CS_URL = "https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz"
TIMEOUT = 120
WORKERS = int(os.environ.get("CHISEL_CHECK_WORKERS", "16"))

# A chisel Module with a real IO() bundle is in principle simulatable; flag it
# so the summary separates "pure-definition" (the intended target) from
# "module-but-unverified" files that landed in the same orphan bucket.
_MOD = re.compile(r"extends\s+(?:\w+\.)?(?:Raw)?(?:Multi)?(?:IO)?Module\b|extends\s+ImplicitClock\b|extends\s+LazyModule\b")
_IO  = re.compile(r"\bIO\s*\(")

def is_def_only(text):
    return not (_MOD.search(text) and _IO.search(text))

def ensure_toolchain():
    """Download coursier once and resolve the scala-compiler classpath."""
    os.makedirs(TOOLDIR, exist_ok=True)
    if not os.path.exists(CS):
        tmp = CS + ".gz"
        urllib.request.urlretrieve(CS_URL, tmp)
        with gzip.open(tmp, "rb") as fi, open(CS, "wb") as fo:
            shutil.copyfileobj(fi, fo)
        os.remove(tmp)
        os.chmod(CS, 0o755)
    if not os.path.exists(CP_FILE) or not open(CP_FILE).read().strip():
        cp = subprocess.run([CS, "fetch", "-p", SCALA_COMPILER],
                            capture_output=True, text=True, timeout=600)
        if cp.returncode != 0:
            raise RuntimeError("coursier fetch failed: " + cp.stderr[-500:])
        open(CP_FILE, "w").write(cp.stdout.strip())
    cp = open(CP_FILE).read().strip()
    # sanity: every jar must still exist in the coursier cache
    if not all(os.path.exists(p) for p in cp.split(os.pathsep)):
        os.remove(CP_FILE)
        return ensure_toolchain()
    return cp

def dut_file(cd):
    mp = os.path.join(cd, "_meta.json")
    if os.path.exists(mp):
        try:
            m = json.loads(open(mp).read())
            p = os.path.join(cd, m["module_basename"] + (m.get("ext") or ".scala"))
            if os.path.exists(p):
                return p
        except Exception:
            pass
    for f in sorted(os.listdir(cd)):
        if f.endswith(".scala") and "_original" not in f and os.path.isfile(os.path.join(cd, f)):
            return os.path.join(cd, f)
    return None

def parse_check(cp, src, cd):
    cmd = ["java", "-cp", cp, "scala.tools.nsc.Main",
           "-usejavacp", "-Ystop-after:parser", "-nowarn", src]
    try:
        r = subprocess.run(cmd, cwd=cd, capture_output=True, text=True, timeout=TIMEOUT)
        if r.returncode == 0:
            return ("parse_ok", "")
        return ("parse_fail", (r.stderr or r.stdout)[-400:])
    except subprocess.TimeoutExpired:
        return ("timeout", "timeout")

def run(item):
    cp = item["cp"]; d = item["dir"]; cd = os.path.join(CH, d)
    src = dut_file(cd)
    if not src:
        return dict(dir=d, result="no_src")
    t0 = time.time()
    text = open(src, encoding="utf-8", errors="replace").read()
    defonly = is_def_only(text)
    res, err = parse_check(cp, src, cd)
    json.dump({"check": res, "how": "scalac -Ystop-after:parser", "src": os.path.basename(src),
               "def_only": defonly, "err": err[:300]},
              open(os.path.join(cd, "_compile_check.json"), "w"), indent=2)
    return dict(dir=d, result=res, def_only=defonly, sec=round(time.time() - t0, 1))

def load_targets():
    """Cases whose latest _batch_status record is missing_tb (the ~169 orphans).
    Override with a JSON list of {"dir": ...} via $CHISEL_CHECK_JSON."""
    override = os.environ.get("CHISEL_CHECK_JSON")
    if override:
        return [x["dir"] for x in json.load(open(override))]
    latest = {}
    p = os.path.join(CH, "_batch_status.jsonl")
    for line in open(p, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except Exception:
            continue
        d = r.get("dir") or r.get("idx")
        if d is not None:
            latest[d] = r
    return [d for d, r in latest.items() if r.get("status") == "missing_tb"]

def main():
    cp = ensure_toolchain()
    dirs = load_targets()
    items = [{"dir": d, "cp": cp} for d in dirs]
    print(f"[chisel-check] {len(items)} orphan cases, scalac parse-only, {WORKERS} parallel", flush=True)
    log = open(os.path.join(BASE, "_chisel_orphan_status.jsonl"), "w")
    c = Counter(); defc = Counter()
    with ProcessPoolExecutor(max_workers=WORKERS) as ex:
        futs = [ex.submit(run, it) for it in items]
        done = 0
        for f in as_completed(futs):
            r = f.result(); done += 1
            c[r["result"]] += 1
            defc[(r.get("def_only"), r["result"])] += 1
            log.write(json.dumps(r) + "\n"); log.flush()
            print(f"[{done}/{len(items)}] {r['dir']:42s} {r['result']}", flush=True)
    print("\n=== result counts ===", flush=True)
    for k in sorted(c, key=str):
        print(f"  {k}: {c[k]}", flush=True)
    print("=== pure-definition (def_only) vs has-module ===", flush=True)
    for (dof, res), n in sorted(defc.items(), key=str):
        tag = "def-only " if dof else "has-module"
        print(f"  {tag} {res:12s} {n}", flush=True)
    okd = sum(n for (dof, res), n in defc.items() if dof and res == "parse_ok")
    tot_def = sum(n for (dof, res), n in defc.items() if dof)
    print(f"\n[chisel-check] pure-definition files parse-verified: {okd}/{tot_def}", flush=True)

if __name__ == "__main__":
    main()
