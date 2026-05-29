#!/usr/bin/env python3
"""Compile/elaboration check for the 102 ORPHAN blocked cases (no sibling refs).
Pure-definition files (package/typedef/param/interface) have no behaviour to
simulate, but if they COMPILE cleanly that proves they are syntactically self-
consistent -> indirect verification. Zero codex usage, all local.
  - systemverilog: iverilog -g2012 -t null <file>   (also try verilator --lint-only)
  - vhdl:          ghdl -a --std=08 <file>
  - chisel:        handled separately by _chisel_orphan_check.py
                   (scalac parse-only via a bootstrapped 2.13 compiler)
Writes _compile_check.json into each case dir and a summary jsonl.
"""
import json, os, subprocess, time
from concurrent.futures import ProcessPoolExecutor, as_completed
from collections import Counter

BASE=os.path.dirname(os.path.abspath(__file__))
ROOT="/ssd1/zqy/Multi-hdl-language-repo/MHRC-Bench/Other_results"
W={"systemverilog":ROOT+"/systemverilog_dataset_testbench/function_verify",
   "vhdl":ROOT+"/vhdl_dataset_testbench/function_verify",
   "chisel":ROOT+"/chisel_dataset_testbench/function_verify"}
EXT={"systemverilog":(".sv",".svh",".v"),"vhdl":(".vhd",".vhdl"),"chisel":(".scala",)}

def dut_file(lang, cd):
    # prefer _meta basename, else any non-_original source
    mp=os.path.join(cd,"_meta.json")
    if os.path.exists(mp):
        try:
            m=json.loads(open(mp).read()); b=m["module_basename"]; e=m.get("ext") or EXT[lang][0]
            p=os.path.join(cd,b+e)
            if os.path.exists(p): return p
        except: pass
    for f in sorted(os.listdir(cd)):
        if f.endswith(tuple(EXT[lang])) and "_original" not in f and os.path.isfile(os.path.join(cd,f)):
            return os.path.join(cd,f)
    return None

def check(lang, src, cd):
    if lang=="systemverilog":
        cmds=[["iverilog","-g2012","-t","null","-o","/dev/null",src],
              ["verilator","--lint-only","-sv","-Wno-lint",src]]
    elif lang=="vhdl":
        cmds=[["ghdl","-a","--std=08","--work=work_chk",src],
              ["ghdl","-a","--std=93","--work=work_chk",src]]
    else:
        return ("skipped","no local chisel compiler","")
    last=""
    for cmd in cmds:
        try:
            r=subprocess.run(cmd,cwd=cd,capture_output=True,text=True,timeout=120)
            if r.returncode==0:
                return ("compile_ok"," ".join(cmd[:2]),"")
            last=(r.stderr or r.stdout)[-400:]
        except subprocess.TimeoutExpired:
            last="timeout"
        except FileNotFoundError as e:
            last=str(e)
    return ("compile_fail","",last)

def run(item):
    lang=item["lang"]; d=item["dir"]; cd=os.path.join(W[lang],d)
    src=dut_file(lang,cd)
    if not src:
        return dict(lang=lang,dir=d,result="no_src")
    t0=time.time()
    res,how,err=check(lang,src,cd)
    json.dump({"check":res,"how":how,"src":os.path.basename(src),"err":err[:300]},
              open(os.path.join(cd,"_compile_check.json"),"w"),indent=2)
    return dict(lang=lang,dir=d,result=res,how=how,sec=round(time.time()-t0,1))

def main():
    items=json.load(open(os.path.join(BASE,"_orphan_blocked.json")))
    print(f"[compile-check] {len(items)} orphan cases, local compilers, 16 parallel",flush=True)
    log=open(os.path.join(BASE,"_orphan_check_status.jsonl"),"w")
    c=Counter(); bylang=Counter()
    with ProcessPoolExecutor(max_workers=16) as ex:
        for f in as_completed([ex.submit(run,it) for it in items]):
            r=f.result(); c[r["result"]]+=1; bylang[(r["lang"],r["result"])]+=1
            log.write(json.dumps(r)+"\n"); log.flush()
    print("=== result counts ===",flush=True)
    for k in sorted(c): print(f"  {k}: {c[k]}",flush=True)
    print("=== by lang ===",flush=True)
    for (lang,res),n in sorted(bylang.items()):
        print(f"  {lang:14s} {res:14s} {n}",flush=True)

if __name__=="__main__":
    main()
