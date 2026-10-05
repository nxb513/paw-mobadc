#!/usr/bin/env python3
"""
generate_wind_dataset.py -- generate W1's Wind Dataset.

    python3 python/verify_wind_dataset.py          # RUN THIS FIRST
    python3 python/generate_wind_dataset.py --smoke
    python3 python/generate_wind_dataset.py --out dataset

===========================================================================
VERIFY FIRST
===========================================================================
This script calls verify_wind_dataset.py itself and REFUSES to generate if any
check fails. Generating several GB from an unverified generator is the surest
way to lose a week: every layer downstream (force, ESO, predictor, controller)
will run perfectly on wrong data, and not one of them is capable of raising an
alarm.

Skip it with --no-verify only when it has been run by hand - and only then.

===========================================================================
SIZE
===========================================================================
    200 s * 200 Hz * 3 axes * 4 bytes = 480 KB per array

The composite type has 4 series arrays (wind, turb, gust, periodic) -> ~1.9 MB
per seed before compression. 6 types * 300 seeds can reach several GB.

Before increasing the duration or the seed count, reduce fs. The wind's
spectral content lies below ~2 Hz (Dryden at L=20, V=5 has its corner at
0.04 Hz). fs = 200 Hz oversamples by about 50x. If Simulink needs to run
faster, interpolate at read time - far cheaper than storing it. fs = 50 Hz is
already enough and cuts the size to a quarter.

This is also why the dataset is sized by SEED COUNT and not by sample count:
raising fs makes the files bigger without adding one bit of information.
"""

import argparse
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from wind.dataset import SPLITS, build, estimate_size  # noqa: E402
from wind.generators import WIND_TYPES  # noqa: E402


def human(n):
    for u in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f} {u}"
        n /= 1024
    return f"{n:.1f} TB"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="dataset")
    ap.add_argument("--duration", type=float, default=200.0)
    ap.add_argument("--fs", type=float, default=200.0)
    ap.add_argument("--types", default="1,2,3,4,5,6")
    ap.add_argument("--seeds", default="1-300",
                    help="seed ranges, e.g. '1-300', '1-5', or "
                         "'1-8,201-204,251-254'")
    ap.add_argument("--smoke", action="store_true",
                    help="a few seeds per type, to smoke-test the write/read "
                         "path")
    ap.add_argument("--no-verify", action="store_true")
    ap.add_argument("--yes", action="store_true")
    a = ap.parse_args()

    if not a.no_verify:
        print("Running verify_wind_dataset.py ...")
        r = subprocess.run([sys.executable, str(HERE / "verify_wind_dataset.py")],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print(r.stdout[-2500:])
            print("\nThe generator has not passed verification. NOT generating.")
            return 1
        print("  all checks passed.\n")

    types = [int(x) for x in a.types.split(",")]
    if a.smoke:
        seeds = [1, 2, 201, 251]
        a.duration = min(a.duration, 60.0)
    else:
        seeds = []
        for part in a.seeds.split(","):
            lo, hi = (int(x) for x in part.split("-")) if "-" in part \
                else (int(part), int(part))
            seeds += list(range(lo, hi + 1))

    size = estimate_size(len(types), len(seeds), a.duration, a.fs)
    print(f"Will generate {len(types)} types x {len(seeds)} seeds x "
          f"{a.duration:.0f} s @ {a.fs:.0f} Hz")
    print(f"Estimated before compression: {human(size)}   -> {a.out}/")
    for name, (l, h) in SPLITS.items():
        k = sum(1 for s in seeds if l <= s <= h)
        if k:
            print(f"   {name:<5s} {k:4d} seeds  (range {l}-{h})")
    if size > 2 << 30 and not a.yes:
        print("\nOver 2 GB. Re-run with --yes if that is really intended, or "
              "lower --fs.")
        return 1
    print()

    meta = build(pathlib.Path(a.out), types, seeds, a.duration, a.fs)
    print(f"\nDone: {meta['n_runs']} runs, code_hash {meta['code_hash']}")
    print(f"metadata: {a.out}/metadata.json")
    print("\nNote: the dataset is NOT committed (see .gitignore). Regenerate it")
    print("with this same command - the seeds are deterministic, so the result")
    print("matches exactly.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
