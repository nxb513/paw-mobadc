#!/usr/bin/env python3
"""
data_manifest.py -- the result files the paper is built from: size and SHA-256 in data/SHA256SUMS.txt.

    python3 tools/data_manifest.py --list     # the files the generators read (no hashing)
    python3 tools/data_manifest.py --write    # hash results/<file> for each, write data/SHA256SUMS.txt (all must exist)
    python3 tools/data_manifest.py --check    # re-hash a local results/ and compare; without results/ it says so and passes

The .mat files are not in git (.gitignore); they go to Zenodo at submission. This file is how a copy is checked
against the one that produced the paper. The list is read from the generators themselves - analysis/make_results_p2.m,
analysis/make_p2_tables.m, figures/p2/make_p2_figures.m - so it cannot drift from what they open.
"""

import hashlib
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "results"
OUT = ROOT / "data" / "SHA256SUMS.txt"
GEN = ["analysis/make_results_p2.m", "analysis/make_p2_tables.m", "figures/p2/make_p2_figures.m"]


def files():
    found = set()
    for g in GEN:
        t = (ROOT / g).read_text(encoding="utf-8")
        found |= set(re.findall(r"'(gd\d+/[A-Za-z0-9_.+-]+\.mat)'", t))
        found |= {f"{a}/{b}" for a, b in re.findall(r"'(gd\d+)',\s*'([A-Za-z0-9_.+-]+\.mat)'", t)}
        found |= {f"gd7/{n}.mat" for n in re.findall(r"'[^']*',\s*'(N[0-9][A-Za-z0-9-]*)',\s*'(?:NEGATIVE|POST-HOC)'", t)}
        if "D2d" in t:
            found |= {"gd6/d2_p2.mat", "gd10/D2.mat"}
    return sorted(found)


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main():
    fl = files()
    if "--list" in sys.argv or len(sys.argv) == 1:
        print("\n".join(fl))
        print(f"{len(fl)} file(s)")
        return
    if "--write" in sys.argv:
        miss = [f for f in fl if not (RES / f).exists()]
        if miss:
            print("missing in results/:\n  " + "\n  ".join(miss))
            sys.exit(1)
        OUT.parent.mkdir(exist_ok=True)
        lines = ["# SHA-256, bytes, path - the result files of the paper (written by tools/data_manifest.py --write)"]
        lines += [f"{sha(RES / f)}  {(RES / f).stat().st_size:>10}  results/{f}" for f in fl]
        OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"wrote {OUT.relative_to(ROOT)}: {len(fl)} file(s)")
        return
    if "--check" in sys.argv:
        print("  DATA_MANIFEST - result files against data/SHA256SUMS.txt")
        if not OUT.exists():
            print("  FAIL: data/SHA256SUMS.txt not found - run --write on the machine that holds results/")
            sys.exit(1)
        rec = {}
        for ln in OUT.read_text(encoding="utf-8").splitlines():
            if ln.startswith("#") or not ln.strip():
                continue
            h, n, p = ln.split(None, 2)
            rec[p.replace("results/", "", 1)] = (h, int(n))
        bad = [f"{f}: read by the generators but not listed" for f in fl if f not in rec]
        if not RES.exists():
            print(f"  note: no results/ here - list checked only ({len(rec)} file(s) recorded)")
        else:
            for f, (h, n) in rec.items():
                p = RES / f
                if not p.exists():
                    bad.append(f"{f}: missing")
                elif p.stat().st_size != n or sha(p) != h:
                    bad.append(f"{f}: size or SHA-256 differs")
        for b in bad:
            print("  FAIL: " + b)
        print("  " + ("PASS" if not bad else f"{len(bad)} problem(s)"))
        sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
