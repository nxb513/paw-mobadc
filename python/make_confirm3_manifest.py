#!/usr/bin/env python3
"""
make_confirm3_manifest.py -- write CONFIRM3_MANIFEST.json from rerun/m5_conf3_urls.txt (docs/REGISTER_FINAL.md
sec 6): the 58 heldout-split days of 2022 (months 1, 2, 4, 5, hours 02/08/14/20), fixed on 2026-10-05 by
`plan_real_download.py --year 2022 --split heldout --all-days` before any 2022 file was downloaded.

No wind file is read; only the file names of the URL list. Checks before writing: every day on the heldout side of
`split_of`, none a W5 characterisation day, none of 2024, and the two SHA-256 registered in REGISTER_FINAL sec 6
(sorted file names, sorted days; each joined by newlines) - the script stops if either differs.

    python python/make_confirm3_manifest.py            # print and check
    python python/make_confirm3_manifest.py --write    # write CONFIRM3_MANIFEST.json (refuses a different one)

The export reads it with `--only-days CONFIRM3_MANIFEST.json` (keys "days" and "sha256_files": the file-list hash of
the download directory must match); core/p2_segset.m reads it for the CONFIRM3 sets.
"""

import argparse
import hashlib
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

from wind.real_loader import CHARACTERISATION_DAYS, day_of, split_of  # noqa: E402

URLS = ROOT / "rerun" / "m5_conf3_urls.txt"
OUT = ROOT / "CONFIRM3_MANIFEST.json"
FILES_SHA = "d1632369ebf029ebe038316434bae11d2cc054a6b815749e8d713cf94566f797"   # REGISTER_FINAL sec 6
DAYS_SHA = "b992cc090383b0ef433b7dc8a45b8eff680d4abee17283b55b461cb5057b654e"    # REGISTER_FINAL sec 6
N_DAYS = 58
RULE = ("NREL M5, 2022, months 1, 2, 4, 5, hours 02/08/14/20, every day on the heldout side of split_of "
        "(python/wind/real_loader.py, SHA-256 of the date); plan_real_download.py --year 2022 --split heldout "
        "--all-days, run 2026-10-05 before any 2022 file was downloaded")


def sha(lines):
    return hashlib.sha256("\n".join(lines).encode()).hexdigest()


def build():
    urls = [ln.strip() for ln in URLS.read_text().splitlines() if ln.strip()]
    names = sorted(u.rsplit("/", 1)[-1] for u in urls)
    assert len(set(names)) == len(names), "a file is listed twice"
    days = sorted({day_of(pathlib.Path(n)) for n in names})
    bad = [n for n in names if split_of(pathlib.Path(n)) != "heldout"]
    assert not bad, f"not on the heldout side: {bad[:3]}"
    assert not set(days) & set(CHARACTERISATION_DAYS), "a characterisation day is listed"
    assert all(d.startswith("2022-") for d in days), "a day outside 2022 is listed"
    fs, ds = sha(names), sha(days)
    assert fs == FILES_SHA, f"file-list SHA-256 {fs}, registered {FILES_SHA} - STOP"
    assert ds == DAYS_SHA, f"day-list SHA-256 {ds}, registered {DAYS_SHA} - STOP"
    assert len(days) == N_DAYS, f"{len(days)} days, registered {N_DAYS}"
    return {
        "purpose": "CONFIRM3: held-out set of the final run, run ONCE (docs/REGISTER_FINAL.md sec 6)",
        "rule": RULE,
        "days": days,
        "n_days": len(days),
        "sha256_days": ds,
        "files": names,
        "n_files": len(names),
        "sha256_files": fs,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()
    man = build()
    print(f"CONFIRM3: {man['n_days']} days ({man['days'][0]} .. {man['days'][-1]}), {man['n_files']} files; "
          f"both SHA-256 = REGISTER_FINAL sec 6")
    if not a.write:
        print("(add --write to create CONFIRM3_MANIFEST.json)")
        return
    if OUT.exists():
        old = json.loads(OUT.read_text())
        if old.get("days") != man["days"] or old.get("sha256_files") != man["sha256_files"]:
            raise SystemExit("ERROR: CONFIRM3_MANIFEST.json exists with DIFFERENT days or files - not overwritten.")
        print("CONFIRM3_MANIFEST.json already exists with the same days and files - unchanged.")
        return
    OUT.write_text(json.dumps(man, indent=2) + "\n", newline="\n")
    print(f"wrote {OUT.name}")


if __name__ == "__main__":
    main()
