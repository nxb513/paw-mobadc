#!/usr/bin/env python3
"""
local_tidy.py -- tidy the files git does not track, by the plan the user approved (2026-10-04). Dry run by default.

    python tools/local_tidy.py                    # DRY RUN: what would happen, nothing touched
    python tools/local_tidy.py --apply            # do it; journal in ..\\windataset_archive\\tidy_journal.tsv
    python tools/local_tidy.py --undo             # move every archived / logged file back (caches are not restored)

Actions (first match wins; classes from tools/local_inventory.py):
  KEEP     stays where it is: class PAPER / RESULTS / SOURCE; the folders results/ m5/ refs/ data/ logs/ wind_conf2/
           wind_sn010/ wind_e0check/; the files kept code reads (KEEP_FILES); any untracked non-cache file inside
           a folder git tracks (core/, tools/, docs/, ...) - a new script is never moved
  CACHE    deleted - rebuilt by MATLAB/Python (slprj/, *.slxc, *.asv, __pycache__/, *.pyc); *.autosave is archived
  LOG      moved to logs/ (git-ignored): run logs cited by docs/REGISTER_P2.md stay next to the repository
  ARCHIVE  moved to ..\\windataset_archive\\<same relative path>: the v1 study, old checkpoints, the synthetic
           training set, old figures - kept outside the repository, not deleted
Run with MATLAB closed (no batch running). Afterwards: data_manifest --check, check_all, verify_p2_repro.
"""

import os
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import data_manifest  # noqa: E402
import local_inventory as inv  # noqa: E402

ARCHIVE = ROOT.parent / (ROOT.name + "_archive")
JOURNAL = ARCHIVE / "tidy_journal.tsv"
KEEP_DIRS = ("results/", "m5/", "refs/", "data/", "logs/", "wind_conf2/", "wind_sn010/", "wind_e0check/")
KEEP_FILES = [
    r"wind_real_t150\.mat",            # build_wind_predictor, build_pa_mobadc, verify_* (single-series checks)
    r"wind_sim_t150\.mat",             # wind_sim_load, build_wind_series, verify_wind_force
    r"dev_t4\.mat", r"heldout_final\.mat",                   # core/dump_used_days, check_confirm_manifest:
    r"wind_conf_t150_i\d+\.mat", r"wind_conf_t150_batch\.json",  # provenance of the CONFIRM2 day split (D23)
]
LOG_RE = r"(_log\.txt|\.log)$"


def action(rel, cls, src_dirs):
    if cls in ("PAPER", "RESULTS", "SOURCE") or rel.startswith(KEEP_DIRS):
        return "KEEP"
    if "/" in rel and rel.split("/")[0] in src_dirs and cls != "CACHE":
        return "KEEP"                  # an untracked file inside a source folder (a new script?) - never moved
    if "/" not in rel and any(re.fullmatch(r, rel) for r in KEEP_FILES):
        return "KEEP"
    if rel.endswith(".autosave"):
        return "ARCHIVE"               # may hold unsaved model edits: kept, never deleted
    if cls == "CACHE":
        return "CACHE"
    if "/" not in rel and re.search(LOG_RE, rel):
        return "LOG"
    return "ARCHIVE"


def plan():
    files = sorted(set(inv.git("ls-files", "--others", "--exclude-standard"))
                   | set(inv.git("ls-files", "--others", "--ignored", "--exclude-standard")))
    paper = {"results/" + f for f in data_manifest.files()}
    text = inv.tracked_text()
    src_dirs = {f.split("/")[0] for f in inv.git("ls-files") if "/" in f}
    out = []
    for rel in files:
        p = ROOT / rel
        if p.is_file():
            out.append((action(rel, inv.classify(rel, paper, text), src_dirs), rel, p.stat().st_size))
    moved = {r for a, r, _ in out if a in ("ARCHIVE", "LOG", "CACHE")}
    assert not (paper & moved), "a result file of the paper is in the move list - stop"
    return out


def dest(a, rel):
    return ARCHIVE / rel if a == "ARCHIVE" else ROOT / "logs" / rel


def main():
    if "--undo" in sys.argv:
        rows = [ln.split("\t") for ln in JOURNAL.read_text(encoding="utf-8").splitlines()[1:]]
        n = 0
        for a, src, dst in rows:
            if a in ("ARCHIVE", "LOG") and pathlib.Path(dst).exists():
                pathlib.Path(src).parent.mkdir(parents=True, exist_ok=True)
                shutil.move(dst, src)
                n += 1
        JOURNAL.rename(JOURNAL.with_name("tidy_journal_undone.tsv"))
        print(f"moved back {n} file(s); caches are rebuilt by MATLAB/Python")
        return
    rows = plan()
    by = {}
    for a, rel, b in rows:
        g = inv.group(rel)
        x = by.setdefault((a, g), [0, 0])
        x[0] += 1
        x[1] += b
    print(f"{'action':8} {'files':>6} {'MB':>9}  group")
    for a in ("KEEP", "CACHE", "LOG", "ARCHIVE"):
        for (aa, g), (n, b) in sorted(by.items()):
            if aa == a:
                print(f"{a:8} {n:>6} {b / 1e6:>9.1f}  {g}")
    tot = {a: sum(b for aa, _, b in rows if aa == a) for a in ("KEEP", "CACHE", "LOG", "ARCHIVE")}
    print("\n" + "  ".join(f"{a} {v / 1e9:.2f} GB" for a, v in tot.items()) + f"   archive: {ARCHIVE}")
    if "--apply" not in sys.argv:
        print("\nDRY RUN - nothing touched. Re-run with --apply after the plan is approved.")
        return
    ARCHIVE.mkdir(exist_ok=True)
    if JOURNAL.exists():
        print(f"{JOURNAL} exists - a tidy was already applied; --undo it first or move the journal away")
        sys.exit(1)
    jl = ["action\tfrom\tto"]
    for a, rel, _ in rows:
        src = ROOT / rel
        if a == "KEEP":
            continue
        if a == "CACHE":
            src.unlink()
            jl.append(f"CACHE\t{src}\t-")
            continue
        d = dest(a, rel)
        if d.exists():
            print(f"  skip (already at destination): {rel}")
            continue
        d.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(d))
        jl.append(f"{a}\t{src}\t{d}")
    JOURNAL.write_text("\n".join(jl) + "\n", encoding="utf-8")
    for dp, dirs, fs in os.walk(ROOT, topdown=False):       # folders emptied by the move
        p = pathlib.Path(dp)
        if p != ROOT and ".git" not in p.parts and not any(p.iterdir()) and not inv.git("ls-files", str(p)):
            p.rmdir()
    print(f"\ndone: journal {JOURNAL} ({len(jl) - 1} entries). Now: data_manifest --check, check_all, verify_p2_repro")


if __name__ == "__main__":
    main()
