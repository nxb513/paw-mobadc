#!/usr/bin/env python3
"""Count and FIX the confirmation set, from DAYS that were never used.

    # step 1 - COUNT only, fix nothing. Run this BEFORE spending 8 machine hours.
    python3 python/make_confirm_manifest.py --real-dir E:\\windataset\\m5 \\
            --used-days used_days.txt --count-only

    # step 2 - fix the manifest (only after the protocol has been locked)
    python3 python/make_confirm_manifest.py --real-dir E:\\windataset\\m5 \\
            --used-days used_days.txt --out CONFIRM_MANIFEST.json

======================================================================
WHY THIS FILE EXISTS, AND WHY IT RUNS FIRST RATHER THAN LAST
======================================================================
A held-out set was scored on 2026-09-05 and ITS RESULT WAS SEEN. So that set is
no longer EPISTEMICALLY independent of any decision taken afterwards, even
though its data is still perfectly valid.

The split is by DAY (real_loader.split_of), and that scoring consumed 30
segments drawn from a subset of days. The REMAINING days on the held-out side
were never touched. Drawing the confirmation set from exactly those days is the
cleanest way out: the day is the unit of the split, so "never used" at day level
is a real property and not a bookkeeping trick.

But if there are not enough clean days left the whole plan collapses, and that
has to be known BEFORE running 8 hours of Simulink rather than after. That is
what --count-only is for.

======================================================================
THE SELECTION RULE - FIXED IN SOURCE, NOT A PARAMETER
======================================================================
The rule is: TAKE EVERY qualifying day. Choose nothing.

Choosing no days at all is the only way to leave no degree of freedom that could
accidentally select on the result. "Take the first N days chronologically"
sounds objective but is seasonally biased; "take a random sample" leaves a seed
that can be adjusted.

Only if the segment count exceeds --cap does anything have to be dropped, and
then pick_indices does it - an EXISTING function, deterministic, balanced across
measurement heights, blind to results.

NOTE: the cap is NOT applied here. pick_indices works on SEGMENT metadata
(height, offset) that the manifest does not have - the manifest knows only
FILES. So the cap is applied at EXPORT time, in export_wind_sim. An earlier
version of this docstring promised that "the seed and the cap are both recorded
in the manifest": wrong on both counts. pick_indices HAS no seed (it is fully
deterministic), and the cap is RECORDED rather than applied.

There is a consequence that has to be closed elsewhere: the manifest hashes 128
source files, while the set that gets scored is the ~30 SEGMENTS cut from them.
The manifest pins no individual segment. So run_confirm_once and
check_confirm_manifest must verify that each segment's 'real_file' IS in the
manifest's file list - checking at DAY level, as an earlier version did, is far
too loose.

======================================================================
WHAT IS NOT ALLOWED
======================================================================
  - opening per-file results and then choosing files
  - doing a trial run and then changing the days
  - re-running with a different --cap until the number looks good
The manifest carries a SHA-256 of the file list. Change the list and the hash
changes, and run_confirm_once refuses to run.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from wind.real_loader import day_of, list_files  # noqa: E402


def read_used_days(spec: str) -> set[str]:
    """Days ALREADY consumed, from a one-day-per-line file or a comma list.

    Accepts both 'MM_DD_YYYY' (the M5 filename form) and 'YYYY-MM-DD' (the
    form day_of returns), because the MATLAB side emits the first.
    """
    p = pathlib.Path(spec)
    raw = p.read_text().split() if p.exists() else spec.split(",")
    out = set()
    for tok in raw:
        tok = tok.strip().strip(",'\"")
        if not tok:
            continue
        if len(tok) == 10 and tok[2] == "_" and tok[5] == "_":
            mo, d, y = tok.split("_")
            tok = f"{y}-{mo}-{d}"
        out.add(tok)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--real-dir", required=True)
    ap.add_argument("--used-days", required=True,
                    help="a file or a comma list: days already scored earlier.")
    ap.add_argument("--cap", type=int, default=30,
                    help="maximum number of segments; only trims if exceeded; default 30 "
                         "to match the sample size of the development table.")
    ap.add_argument("--count-only", action="store_true",
                    help="count only, write NO manifest. Run this step first.")
    ap.add_argument("--out", default="CONFIRM_MANIFEST.json")
    a = ap.parse_args()

    used = read_used_days(a.used_days)
    paths = list_files(a.real_dir, "heldout")
    if not paths:
        print(f"no held-out file found in {a.real_dir}", file=sys.stderr)
        return 2

    by_day: dict[str, list[pathlib.Path]] = {}
    for p in paths:
        by_day.setdefault(day_of(p), []).append(p)

    all_days = sorted(by_day)
    burned = sorted(d for d in all_days if d in used)
    fresh = sorted(d for d in all_days if d not in used)
    unknown = sorted(used - set(all_days))

    print(f"directory      {a.real_dir}")
    print(f"held-out side  {len(paths)} files / {len(all_days)} days")
    print(f"  already used {len(burned):3d} days  {burned}")
    print(f"  STILL CLEAN  {len(fresh):3d} days  {fresh}")
    if unknown:
        # used_days is the UNION over EVERY table, development tables included.
        # So most 'unknown' entries are DEVELOPMENT days, and that is NORMAL,
        # not a symptom. An earlier version printed "wrong list or the split
        # changed" here, which - once the development tables were unioned in -
        # would have been WRONG on every run.
        #
        # The real symptom is elsewhere: a day that is BOTH in used_days AND on the
        # held out (the 'burned' variable). Those are days already scored that
        # are nevertheless still candidates.
        print(f"  {len(unknown)} day(s) in --used-days are not on the "
              f"held out (mostly DEV days - as expected)")
    if burned:
        print(f"  ! {len(burned)} day(s) are BOTH already scored AND held out - "
              f"excluded from the confirmation set: {burned}")

    n_fresh_files = sum(len(by_day[d]) for d in fresh)
    print(f"  files from clean days: {n_fresh_files}")

    # Threshold: below 3 days this is no longer an independent set, just one
    # weather day cut into pieces - every segment correlates with every other
    # and the segment count stops being a real sample size.
    if len(fresh) < 3:
        print("\n  *** NOT ENOUGH CLEAN DAYS (< 3). ***")
        print("  Fallback: re-score the same 30 segments at Test 4 and declare it")
        print("  plainly as a 'reevaluation under a new operating condition'.")
        print("  It may NOT be called a blind test.")
        return 1 if not a.count_only else 0

    if a.count_only:
        print("\n  Enough clean days. Re-run WITHOUT --count-only to fix"
              " manifest.")
        # An earlier version said "only after the protocol has been locked on
        # development". That is the WRONG ORDER: protocol_lock('write') reads the
        # manifest in order to hash it, so the manifest must exist FIRST. The
        # correct order is:
        print("  Order: manifest -> check_confirm_manifest -> "
              "protocol_lock('write') -> export segments -> score.")
        print("  (protocol_lock reads and hashes the manifest, so it must exist FIRST.)")
        return 0

    fresh_paths = sorted((p for d in fresh for p in by_day[d]), key=lambda q: q.name)
    files = [p.name for p in fresh_paths]
    h = hashlib.sha256("\n".join(files).encode()).hexdigest()

    # HASH THE CONTENTS, not just the names.
    #
    # sha256_files hashes only the LIST OF NAMES. Re-exporting those same files
    # with a different parameter - a different horizon, different sensor noise, a
    # different window - keeps the names identical, so that hash does NOT change
    # and run_confirm_once would still run. A hash that cannot catch the change
    # it exists to catch is not a hash.
    hc = hashlib.sha256()
    for p in fresh_paths:
        hc.update(p.name.encode())
        hc.update(hashlib.sha256(p.read_bytes()).digest())
    h_content = hc.hexdigest()

    # THE SPLIT RULE. "heldout" only means anything if split_of is unchanged.
    # Change the split rule and the whole "days never used" argument collapses,
    # with nothing to announce it.
    try:
        sp = pathlib.Path(__file__).resolve().parent / "wind" / "real_loader.py"
        h_split = hashlib.sha256(sp.read_bytes()).hexdigest()
    except OSError:
        h_split = "COULD NOT READ real_loader.py"

    man = {
        "created_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "purpose": ("independent confirmation set - previously unused days. "
                    "NOT a first blind test: a held-out evaluation at the "
                    "Test 2 operating condition was already performed and "
                    "observed on 2026-09-05."),
        "operating_condition": "Test 4",
        "selection_rule": ("all heldout days not present in used_days; no "
                           "per-file selection; this manifest lists ALL files "
                           "from clean days and does NOT apply the cap"),
        "cap_applied_at": ("export_wind_sim.pick_indices - deterministic, "
                           "height-balanced, NO random seed. Manifest lists "
                           "source files; the scored set is the segments "
                           "exported from them, each carrying real_file."),
        "used_days_excluded": burned,
        "days": fresh,
        "n_days": len(fresh),
        "n_files": len(files),
        "files": files,
        "sha256_files": h,
        "sha256_content": h_content,
        "sha256_split_rule": h_split,
        "n_files_by_day": {d: len(by_day[d]) for d in fresh},
        "cap_segments": a.cap,
        "note_scope": ("This manifest proves WHICH DATA was used. WHAT WAS RUN "
                       "(payload_model, K, theta_DC, pool_rule, metric) is "
                       "proved by PROTOCOL_LOCK.md. The two must agree but must "
                       "NOT be merged: merged, a configuration change would "
                       "alter the data hash, and vice versa."),
    }
    pathlib.Path(a.out).write_text(json.dumps(man, indent=2))
    print(f"\n  wrote {a.out}")
    print(f"  sha256 of the file list   : {h}")
    print(f"  sha256 of file CONTENTS   : {h_content}")
    print(f"  sha256 of the split rule  : {h_split[:16]}...")
    print("  COMMIT this file BEFORE exporting segments and before scoring.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
