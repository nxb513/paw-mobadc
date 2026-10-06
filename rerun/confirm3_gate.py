#!/usr/bin/env python3
"""confirm3_gate.py - the opening condition of CONFIRM3 (docs/REGISTER_FINAL.md sec 6.1), checked BEFORE any 2022 file
is downloaded (workflow confirm3.yml) and again by every MATLAB step (rerun/confirm3_gate.m, the same rule):

  a line starting with "APPROVED" in sec 6.1 with a date yyyy-mm-dd and "commit <hash>" of the runner; that commit an
  ancestor of HEAD; no change since it to core/ experiments/ analysis/ python/ rerun/ baseline1.slx
  CONFIRM3_MANIFEST.json .github/workflows/confirm3.yml; no local change to them.

Exit 0 if met, 1 otherwise (it prints why). Needs the full git history (actions/checkout fetch-depth: 0).
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PATHS = ["core", "experiments", "analysis", "python", "rerun", "baseline1.slx", "CONFIRM3_MANIFEST.json",
         ".github/workflows/confirm3.yml"]


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)


def main():
    txt = (ROOT / "docs" / "REGISTER_FINAL.md").read_text(encoding="utf-8")
    k = txt.find("### 6.1")
    if k < 0:
        print("CONFIRM3 gate: REGISTER_FINAL sec 6.1 not found -> NOT MET")
        return 1
    sec = txt[k:]
    e = sec.find("\n## ")
    if e >= 0:
        sec = sec[:e + 1]
    m = re.search(r"^\**APPROVED[^\n]*?(\d{4}-\d{2}-\d{2})[^\n]*?commit `?([0-9a-f]{7,40})", sec, re.M)
    if not m:
        print("CONFIRM3 gate: no APPROVED line in REGISTER_FINAL sec 6.1 -> NOT MET")
        return 1
    date, c = m.group(1), m.group(2)
    anc = git("merge-base", "--is-ancestor", c, "HEAD").returncode == 0
    same = git("diff", "--quiet", c, "HEAD", "--", *PATHS).returncode == 0
    st = git("status", "--porcelain", "--", *PATHS)
    clean = st.returncode == 0 and not st.stdout.strip()
    ok = anc and same and clean
    yn = lambda b: "yes" if b else "NO"  # noqa: E731
    print(f"CONFIRM3 gate: APPROVED {date}, runner commit {c}: ancestor of HEAD {yn(anc)}, unchanged since "
          f"{yn(same)}, no local change {yn(clean)} -> {'OK' if ok else 'NOT MET'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
