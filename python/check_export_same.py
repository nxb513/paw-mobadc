#!/usr/bin/env python3
"""
check_export_same.py -- REGISTER_P2 sec 60.6 (E0): is today's export pipeline the dev one?

    python python/check_export_same.py wind_e0check .

Every wind_*_t150_i*.mat in the first directory (re-exported with the current code, e.g.
`export_wind_sim.py ... --only-index 0,215,440 --check-against . --out wind_e0check/wind_expl_t150.mat`)
is compared with the file of the same name in the second directory (the dev export): the same
variables, and every variable equal BIT FOR BIT (same shape, same dtype, same values; strings
equal). No tolerance. Exit code 0 only if at least 3 files were compared and all are identical.
Reads dev files only - never a CONFIRM2 file.
"""

import pathlib
import sys

import numpy as np
from scipy.io import loadmat

SKIP = {"__header__", "__version__", "__globals__"}


def same(a, b):
    a, b = np.asarray(a), np.asarray(b)
    if a.shape != b.shape or a.dtype != b.dtype:
        return False
    if a.dtype.kind in "biufc":
        return a.tobytes() == b.tobytes()               # bit for bit (NaN, -0 too), C order
    return bool(np.array_equal(a, b))


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    new, ref = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    files = sorted(p for p in new.glob("wind_*_t150_i*.mat") if not p.name.startswith("wind_conf"))
    bad, n = 0, 0
    for p in files:
        q = ref / p.name
        if not q.is_file():
            print(f"  {p.name}: no dev file {q}")
            bad += 1
            continue
        A, B = loadmat(str(p)), loadmat(str(q))
        ka, kb = set(A) - SKIP, set(B) - SKIP
        diff = sorted(k for k in ka & kb if not same(A[k], B[k]))
        miss = sorted(ka ^ kb)
        n += 1
        if diff or miss:
            bad += 1
            print(f"  {p.name}: DIFFERS - values {diff}, variables only on one side {miss}")
        else:
            print(f"  {p.name}: {len(ka)} variables identical bit for bit")
    ok = n >= 3 and bad == 0
    print(f"\nE0: {n} file(s) compared, {bad} differing -> {'PASS' if ok else 'FAIL'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
