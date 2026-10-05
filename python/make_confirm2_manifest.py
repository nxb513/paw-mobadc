#!/usr/bin/env python3
"""
make_confirm2_manifest.py -- split the NEW dev days (not in used_days.txt or
CONFIRM_MANIFEST.json) into exploration and a locked confirm-2 set, by a rule
fixed in docs/REGISTER_ROBUST.md sec 24.6 BEFORE any of those days is
downloaded:

    h(day) = SHA-256("CONFIRM2|" + day), day as YYYY-MM-DD
    sort the new dev days by h ascending; the first N_CONFIRM2 are confirm-2.

No wind statistic is read or known. Run offline:

    python3 python/make_confirm2_manifest.py            # print the split
    python3 python/make_confirm2_manifest.py --write    # write CONFIRM2_MANIFEST.json

Refuses to overwrite an existing manifest whose day list differs.

2026-10-03 (REGISTER_P2 sec 60.12, DEVIATION D23 - for future manifests, not applied
backwards): the W5 CHARACTERISATION_DAYS (inspected segment by segment to set QC, the
height band and the T_c grid) are now excluded from the new dev days too. The existing
CONFIRM2_MANIFEST.json was made by the earlier rule (it holds two of those days, which
CONFIRM2 removed by rule before any run); this script will not overwrite it.
"""

import argparse
import hashlib
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

from plan_real_download import MONTHS, all_days  # noqa: E402
from wind.real_loader import CHARACTERISATION_DAYS  # noqa: E402

RULE = ('h(day) = SHA-256("CONFIRM2|" + day), day as YYYY-MM-DD; new dev days '
        '(dev split, months 1,2,4,5 of 2024, minus used_days.txt and '
        'CONFIRM_MANIFEST.json) sorted by h ascending; the first 16 are confirm-2')
N_CONFIRM2 = 16
YEAR = 2024


def new_dev_days():
    used = {ln.strip() for ln in (ROOT / "used_days.txt").read_text().splitlines()
            if ln.strip()}
    conf = set(json.loads((ROOT / "CONFIRM_MANIFEST.json").read_text())["days"])
    days = all_days(YEAR, MONTHS, "dev", probe=False)
    return [f"{YEAR}-{m:02d}-{d:02d}" for m, d in days
            if f"{m:02d}_{d:02d}_{YEAR}" not in used
            and f"{YEAR}-{m:02d}-{d:02d}" not in conf
            and f"{YEAR}-{m:02d}-{d:02d}" not in CHARACTERISATION_DAYS]   # D23 (2026-10-03)


def h(day):
    return hashlib.sha256(f"CONFIRM2|{day}".encode()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    new = new_dev_days()
    ranked = sorted(new, key=h)
    confirm2 = sorted(ranked[:N_CONFIRM2])
    explore = sorted(ranked[N_CONFIRM2:])
    print(f"new dev days: {len(new)} -> confirm-2 {len(confirm2)}, exploration {len(explore)}")
    print("confirm-2  :", " ".join(confirm2))
    print("exploration:", " ".join(explore))

    man = {
        "purpose": "confirm-2: locked set, run ONCE for the new claims only "
                   "(docs/REGISTER_ROBUST.md sec 24.6)",
        "rule": RULE,
        "sha256_rule": hashlib.sha256(RULE.encode()).hexdigest(),
        "n_new_dev_days": len(new),
        "days": confirm2,
        "n_days": len(confirm2),
        "sha256_days": hashlib.sha256("\n".join(confirm2).encode()).hexdigest(),
        "exploration_days": explore,
    }
    if not a.write:
        print("\n(add --write to create CONFIRM2_MANIFEST.json)")
        return
    out = ROOT / "CONFIRM2_MANIFEST.json"
    if out.exists():
        old = json.loads(out.read_text())
        if old.get("days") != confirm2:
            raise SystemExit("ERROR: CONFIRM2_MANIFEST.json exists with a DIFFERENT day list - not overwritten.")
        print("CONFIRM2_MANIFEST.json already exists with the same days - unchanged.")
        return
    out.write_text(json.dumps(man, indent=2) + "\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
