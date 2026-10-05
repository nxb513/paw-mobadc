#!/usr/bin/env python3
"""
plan_real_download.py -- choose IN ADVANCE which measured-wind files to
download, by a deterministic rule, then print the URLs and a download script.

    python3 python/plan_real_download.py                    # print the plan
    python3 python/plan_real_download.py --write get_m5     # + emit .sh/.ps1
    python3 python/plan_real_download.py --split dev        # the control split

===========================================================================
WHY THE CHOICE OF FILES BELONGS IN CODE AND NOT IN SOMEONE'S HEAD
===========================================================================
The 'heldout' set is the only thing left with which to measure zero-shot
performance. If someone sits and picks "the days that look usable" by hand,
that measurement means nothing: the choice is itself a form of looking at the
data first.

So the selection rule is fixed here, BEFORE anything is downloaded, and it uses
only three quantities that have NOTHING to do with the wind:

  1. split_of(day) == the split being taken   (SHA-256 hash of the date string)
  2. the day EXISTS in the archive            (March 2024 does not)
  3. the day is near a calendar anchor fixed in advance  (default 5, 15, 25)

and the hours are a fixed set (default 02, 08, 14, 20) covering the diurnal
cycle: thermally stable at night, strong convection in the afternoon. No U, no
I, no wind statistic of any kind is looked at before choosing.

Changing any parameter here - anchors, hours, number of days - AFTER seeing a
zero-shot result is exactly how a locked set leaks with nobody noticing. If one
must be changed, say that it was changed, and why.

===========================================================================
THE ARCHIVE - CHECKED BY MEASUREMENT, NOT ASSUMED
===========================================================================
The first 152 days of 2024 were probed with HEAD on each day's 00:00 file:

    121/152 days HAVE data
    MISSING: 03-03 .. 03-31 (ALL OF MARCH), plus 04-08 and 05-15

So the rule has to filter on real existence rather than on the calendar. That
is why this script PROBES THE SERVER instead of guessing; --no-probe is only
for looking at the plan with no network.
"""

import argparse
import calendar
import pathlib
import sys
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from wind.real_loader import CHARACTERISATION_DAYS, split_of  # noqa: E402

BASE = "https://wind.nlr.gov/MetData/135mData/M5Twr/20Hz/mat"

# Domain note: *.nrel.gov no longer resolves; *.nlr.gov serves the same content.

ANCHORS = (5, 15, 25)           # calendar anchors within a month
HOURS = (2, 8, 14, 20)          # hours of day - covering the diurnal cycle
MONTHS = (1, 2, 4, 5)           # March 2024 has no data


def fname(y, m, d, hh):
    return f"{m:02d}_{d:02d}_{y}_{hh:02d}_00_00_000.mat"


def url_of(y, m, d, hh):
    return f"{BASE}/{y}/{m:02d}/{d:02d}/{fname(y, m, d, hh)}"


def exists(u, timeout=40):
    req = urllib.request.Request(u, method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status == 200
    except Exception:
        return False


def pick_days(y, months, anchors, split, probe=True, verbose=True):
    """For each anchor, the nearest day that is BOTH in the split AND on the
    server.

    Walks outwards from the anchor until a day meets both conditions.
    Deterministic: ties go to the earlier day.
    """
    out = []
    for m in months:
        n = calendar.monthrange(y, m)[1]
        for a in anchors:
            order = sorted(range(1, n + 1), key=lambda d: (abs(d - a), d))
            for d in order:
                if (m, d) in out:
                    continue
                if split_of(fname(y, m, d, 0)) != split:
                    continue
                if probe and not exists(url_of(y, m, d, HOURS[0])):
                    if verbose:
                        print(f"    (skipping 2024-{m:02d}-{d:02d}: not on "
                              f"the server)")
                    continue
                out.append((m, d))
                break
    return out


def all_days(y, months, split, probe=True, hour=None, workers=12):
    """EVERY day that is in the split AND on the server.

    No anchors, which means NO selection parameter at all. That is the cleanest
    rule available: the set is "everything that exists on this side of the
    hash". It cannot be accused of picking pretty days, because there is
    nothing to pick.

    It is also right for statistical width: the error on the final table is
    bounded by the number of independent DAYS, not by the number of segments.
    Four files from one day share a single weather pattern - which is exactly
    why the split is by day (section 1b).
    """
    from concurrent.futures import ThreadPoolExecutor
    cand = [(m, d) for m in months
            for d in range(1, calendar.monthrange(y, m)[1] + 1)
            if split_of(fname(y, m, d, 0)) == split]
    if not probe:
        return cand
    h = HOURS[0] if hour is None else hour
    with ThreadPoolExecutor(workers) as ex:
        ok = list(ex.map(lambda t: exists(url_of(y, t[0], t[1], h)), cand))
    return [c for c, k in zip(cand, ok) if k]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--year", type=int, default=2024)
    ap.add_argument("--split", default="heldout",
                    choices=("heldout", "dev"))
    ap.add_argument("--months", default=",".join(map(str, MONTHS)))
    ap.add_argument("--anchors", default=",".join(map(str, ANCHORS)))
    ap.add_argument("--hours", default=",".join(map(str, HOURS)))
    ap.add_argument("--all-days", action="store_true",
                    help="take EVERY day in the split (ignores --anchors). The "
                         "cleanest rule: no selection parameter at all.")
    ap.add_argument("--exclude-used", action="store_true",
                    help="drop days listed in used_days.txt, "
                         "CONFIRM_MANIFEST.json and CONFIRM2_MANIFEST.json "
                         "(repo root) and the W5 CHARACTERISATION_DAYS (D23, 2026-10-03). Removes days only, "
                         "never adds any; uses no wind statistic.")
    ap.add_argument("--no-probe", action="store_true",
                    help="do not ask the server - only for viewing the plan "
                         "with no network")
    ap.add_argument("--write", metavar="NAME",
                    help="emit NAME.txt, NAME.sh, NAME.ps1")
    ap.add_argument("--dest", metavar="DIR",
                    help="download destination. It MUST be the directory that "
                         "already holds the .mat files: list_files() globs ONE "
                         "directory and then splits dev/heldout by hash, so two "
                         "separate directories break it. Default = the --write "
                         "NAME, i.e. a new directory.")
    a = ap.parse_args()

    months = tuple(int(x) for x in a.months.split(","))
    anchors = tuple(int(x) for x in a.anchors.split(","))
    hours = tuple(int(x) for x in a.hours.split(","))

    print("=" * 74)
    print(f"M5 DOWNLOAD PLAN - split = {a.split}, year {a.year}")
    print("=" * 74)
    print(f"  months {months}   "
          f"{'EVERY day (--all-days)' if a.all_days else f'anchors {anchors}'}"
          f"   hours {hours}")
    print(f"  probe the server: {'NO (--no-probe)' if a.no_probe else 'yes'}\n")

    if a.all_days:
        days = all_days(a.year, months, a.split, probe=not a.no_probe)
    else:
        days = pick_days(a.year, months, anchors, a.split,
                         probe=not a.no_probe)

    if a.exclude_used:
        import json
        root = HERE.parent
        used = {ln.strip() for ln in (root / "used_days.txt").read_text().splitlines()
                if ln.strip()}                                   # MM_DD_YYYY
        conf = set(json.loads((root / "CONFIRM_MANIFEST.json").read_text())["days"])
        c2 = root / "CONFIRM2_MANIFEST.json"
        if c2.exists():   # confirm-2 (REGISTER_ROBUST sec 24.6) - locked, never in exploration
            conf |= set(json.loads(c2.read_text())["days"])
        before = len(days)
        days = [(m, d) for m, d in days
                if f"{m:02d}_{d:02d}_{a.year}" not in used
                and f"{a.year}-{m:02d}-{d:02d}" not in conf
                and f"{a.year}-{m:02d}-{d:02d}" not in CHARACTERISATION_DAYS]   # D23
        print(f"  --exclude-used: {before} -> {len(days)} days "
              f"(used_days.txt / CONFIRM_MANIFEST.json / CONFIRM2_MANIFEST.json / "
              f"CHARACTERISATION_DAYS removed)\n")

    urls = [url_of(a.year, m, d, h) for m, d in days for h in hours]

    # Safety checks: no day in the plan may fall on the wrong side of the
    # split, and a heldout plan may not touch a characterisation day.
    bad = [(m, d) for m, d in days
           if split_of(fname(a.year, m, d, 0)) != a.split]
    if bad:
        raise SystemExit(f"ERROR: days on the wrong split in the plan: {bad}")
    if a.split == "heldout":
        leak = [f"{a.year}-{m:02d}-{d:02d}" for m, d in days
                if f"{a.year}-{m:02d}-{d:02d}" in CHARACTERISATION_DAYS]
        if leak:
            raise SystemExit(
                f"ERROR: characterisation days leaked into heldout: {leak}")

    mb = 3.0 * len(urls)
    print(f"  {len(days)} days x {len(hours)} hours = {len(urls)} files "
          f"(~{mb:.0f} MB{f' = {mb / 1024:.2f} GB' if mb > 1024 else ''})\n")
    if len(days) <= 16:
        for m, d in days:
            print(f"    {a.year}-{m:02d}-{d:02d}   " +
                  "  ".join(f"{h:02d}:00" for h in hours))
    else:                       # too many to list: summarise by month
        for m in months:
            dd = [d for mm, d in days if mm == m]
            print(f"    month {m:02d} ({len(dd):2d} days): "
                  + " ".join(f"{d:02d}" for d in dd))
        print(f"    each day x {len(hours)} hours: "
              + " ".join(f"{h:02d}:00" for h in hours))

    # Segment estimate: 600 s / 200 s = 3 segments, x 3 heights, x ~65%
    # through QC (measured in a pilot check: 140 segments from 24 files across
    # 3 heights = 216 candidates).
    print(f"\n  Estimate: {len(urls)} files x 3 segments x 3 heights x 65% "
          f"through QC = ~{int(len(urls) * 9 * 0.65)} segments")

    if not a.write:
        print("\n  (add --write get_m5 to emit the download scripts)")
        return

    dest = a.dest or a.write

    txt = pathlib.Path(f"{a.write}.txt")
    # --write may point into a directory that does not exist yet (e.g. a new --dest):
    # create it, instead of failing after the plan was printed (2026-09-25, Windows)
    txt.parent.mkdir(parents=True, exist_ok=True)
    txt.write_text("\n".join(urls) + "\n")

    sh = pathlib.Path(f"{a.write}.sh")
    sh.write_text(
        "#!/bin/sh\n"
        f"# {len(urls)} M5 files, split = {a.split}. Generated by "
        "plan_real_download.py\n"
        f"mkdir -p '{dest}'\n"
        f"cd '{dest}' || exit 1\n"
        # -C - so a re-run resumes instead of starting over; -f so a 404 does
        # not leave a junk file behind.
        + "".join(f"curl -fsS -O -C - '{u}'\n" for u in urls))
    sh.chmod(0o755)

    # Windows: skip files already downloaded, so a run can resume after the
    # network drops.
    ps1 = pathlib.Path(f"{a.write}.ps1")
    ps1.write_text(
        f"# {len(urls)} M5 files, split = {a.split}. "
        "Generated by plan_real_download.py\r\n"
        f"$dest = '{dest}'\r\n"
        "New-Item -ItemType Directory -Force -Path $dest | Out-Null\r\n"
        "$ProgressPreference = 'SilentlyContinue'\r\n"
        "$n = 0\r\n"
        + "".join(
            f"$f = Join-Path $dest '{u.rsplit('/', 1)[1]}'\r\n"
            "if (Test-Path $f) { $n++ } else { "
            f"Invoke-WebRequest -Uri '{u}' -OutFile $f; $n++ }}\r\n"
            f"Write-Host \"$n/{len(urls)}\" -NoNewline; "
            "Write-Host \"`r\" -NoNewline\r\n"
            for u in urls)
        + "Write-Host \"\"\r\n"
        f"$c = (Get-ChildItem $dest -Filter *.mat).Count\r\n"
        "Write-Host \"$dest now holds $c .mat files\"\r\n")

    print(f"\n  Wrote: {txt}, {sh}, {ps1}   -> downloading into: {dest}/")
    if not a.dest:
        print("  ! --dest was NOT set, so the files will land in a NEW directory "
              f"'{dest}'.")
        print("    list_files() globs ONE directory and then splits dev/heldout")
        print("    by hash, so new files must sit WITH the existing .mat files.")
        print("    Re-run with --dest <data directory>, or move them afterwards.")
    print(f"  Windows:  powershell -ExecutionPolicy Bypass -File {ps1}")
    print(f"  Linux:    ./{sh}")


if __name__ == "__main__":
    main()
