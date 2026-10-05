#!/usr/bin/env python3
"""
model_at_commit.py -- READ ONLY. For each result file of the paper, the baseline1.slx committed at the git revision
stored in that file: the model commit, its MD5 and the P2 wiring fingerprint recorded for it.

    python tools/model_at_commit.py E:\\provenance.tsv      # the TSV written by verification/results_provenance.m

Prints a Markdown table (file | written | git | model commit | model MD5 | fingerprint recorded) for REGISTER_P2.
Limits, printed with the table: a runner stores the commit of its LAST save; the model on disk at run time is
assumed to be the committed one (a model rebuilt but not yet committed would not show here); fingerprints are the
ones written in the commit messages / REGISTER_P2 when the model was committed (none was recorded for f4c88bc).
"""

import csv
import hashlib
import re
import subprocess
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
FP_RECORDED = {   # model MD5 -> fingerprint, as written when the model was committed
    "B27EA7C8FB6544E0CE68E8B765BAAAD3": "c965867910b8eaf9... (REGISTER_P2 sec 50)",
}


def git(*a, binary=False):
    r = subprocess.run(["git", *a], cwd=ROOT, capture_output=True, check=False)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace").strip()


def model_at(rev):
    c = git("log", "-1", "--format=%h|%ad|%s", "--date=format:%Y-%m-%d %H:%M", rev, "--", "baseline1.slx")
    if not c:
        return None
    h, date, subj = c.split("|", 2)
    md5 = hashlib.md5(git("show", f"{h}:baseline1.slx", binary=True)).hexdigest().upper()
    fp = FP_RECORDED.get(md5)
    if not fp:
        m = re.search(r"fingerprint ([0-9a-f]{8})", subj)
        fp = f"{m.group(1)}... (commit message)" if m else "not recorded"
    return h, date, md5, fp


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8-sig"), delimiter="\t"))
    print("| result file | written | git stored | model commit (date) | model MD5 | fingerprint recorded |")
    print("|---|---|---|---|---|---|")
    for r in rows:
        revs = r["git"].split() or ["?"]
        for g in revs:
            m = model_at(g) if g != "?" else None
            if m is None:
                print(f"| `{r['file']}` | {r['written']} | {g} | (revision not found) | | |")
            else:
                print(f"| `{r['file']}` | {r['written']} | {g} | {m[0]} ({m[1]}) | {m[2][:8]} | {m[3]} |")


if __name__ == "__main__":
    main()
