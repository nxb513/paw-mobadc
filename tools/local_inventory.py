#!/usr/bin/env python3
"""
local_inventory.py -- READ ONLY. What lies in the working folder that git does not track, grouped and classified,
so that old material can be moved out by an approved plan. Nothing is moved or deleted here.

    python tools/local_inventory.py                       # summary by group
    python tools/local_inventory.py --out ..\\inv.tsv     # also every file: class, group, bytes, modified, path

Classes (first match wins):
  PAPER   a result file the paper is built from (tools/data_manifest.py list), the wind segments of the P2 sets
          (wind_real_t150_i*, wind_expl_t150_i*, wind_conf2/ and their batch lists), the frozen predictor
  RESULTS anything else under results/ - never deleted (CLAUDE.md rule 7)
  SOURCE  refs/ (publisher PDFs), m5/ (raw NREL M5 data)
  CACHE   rebuilt by MATLAB/Python: slprj/, *.slxc, *.asv, *.autosave, __pycache__/, *.pyc
  NAMED   its file name appears in a tracked file (code or docs) - decide case by case
  OTHER   not named anywhere in the repository - candidate to move out
"""

import collections
import datetime
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import data_manifest  # noqa: E402

CACHE_DIRS = {"slprj", "__pycache__"}
CACHE_EXT = {".slxc", ".asv", ".autosave", ".pyc"}
PAPER_RE = [r"wind_real_t150_i\d+\.mat$", r"wind_expl_t150_i\d+\.mat$", r"wind_(expl|conf2)_t150_batch\.json$",
            r"^wind_conf2/", r"^w4_frozen_20hz_t150_train2345_s0\.(pt|json)$"]


def git(*a):
    return subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", check=True).stdout.splitlines()


def tracked_text():
    parts = []
    for f in git("ls-files"):
        p = ROOT / f
        if p.suffix.lower() in {".m", ".py", ".md", ".txt", ".json", ".yml", ".csv"} and p.is_file():
            parts.append(p.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(parts)


def group(rel):
    parts = rel.split("/")
    if len(parts) > 1:
        return parts[0] + "/" + ("" if len(parts) == 2 else parts[1] + "/")
    return re.sub(r"\d+", "#", parts[0])


def classify(rel, paper, text):
    parts = rel.split("/")
    name = parts[-1]
    if rel in paper or any(re.search(r, rel) for r in PAPER_RE):
        return "PAPER"
    if parts[0] == "results":
        return "RESULTS"
    if parts[0] in ("refs", "m5"):
        return "SOURCE"
    if CACHE_DIRS & set(parts[:-1]) or pathlib.PurePath(name).suffix.lower() in CACHE_EXT:
        return "CACHE"
    if name in text:
        return "NAMED"
    return "OTHER"


def main():
    files = sorted(set(git("ls-files", "--others", "--exclude-standard"))
                   | set(git("ls-files", "--others", "--ignored", "--exclude-standard")))
    paper = {"results/" + f for f in data_manifest.files()}
    text = tracked_text()
    rows, agg = [], collections.OrderedDict()
    for rel in files:
        p = ROOT / rel
        if not p.is_file():
            continue
        st = p.stat()
        c = classify(rel, paper, text)
        g = group(rel)
        rows.append((c, g, st.st_size, datetime.date.fromtimestamp(st.st_mtime).isoformat(), rel))
        a = agg.setdefault((c, g), [0, 0, "9999", "0000"])
        a[0] += 1
        a[1] += st.st_size
        a[2] = min(a[2], rows[-1][3])
        a[3] = max(a[3], rows[-1][3])
    order = ["PAPER", "RESULTS", "SOURCE", "CACHE", "NAMED", "OTHER"]
    print(f"untracked files under {ROOT}: {len(rows)}, {sum(r[2] for r in rows) / 1e9:.2f} GB\n")
    print(f"{'class':8} {'files':>6} {'MB':>10}  {'dates':23}  group")
    for c in order:
        for (cc, g), (n, b, d0, d1) in sorted(agg.items(), key=lambda kv: kv[0][1]):
            if cc == c:
                print(f"{c:8} {n:>6} {b / 1e6:>10.1f}  {d0} .. {d1}  {g}")
    tot = collections.Counter()
    for r in rows:
        tot[r[0]] += r[2]
    print("\n" + "  ".join(f"{c} {tot[c] / 1e9:.2f} GB" for c in order))
    paper_missing = sorted(paper - set(files))
    if paper_missing:
        print(f"\nresult files the paper reads that are NOT in this folder ({len(paper_missing)}):")
        print("  " + "\n  ".join(paper_missing))
    if "--out" in sys.argv:
        out = pathlib.Path(sys.argv[sys.argv.index("--out") + 1])
        out.write_text("class\tgroup\tbytes\tmodified\tpath\n"
                       + "\n".join("\t".join(map(str, r)) for r in rows) + "\n", encoding="utf-8")
        print(f"\nwrote {out}: {len(rows)} rows")


if __name__ == "__main__":
    main()
