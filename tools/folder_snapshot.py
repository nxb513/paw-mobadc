#!/usr/bin/env python3
"""
folder_snapshot.py -- size and SHA-256 of EVERY file under a folder, to check a copy to another machine.

    python tools/folder_snapshot.py --write SNAP.txt  [ROOT]   # on the old machine, before copying
    python tools/folder_snapshot.py --check SNAP.txt  [ROOT]   # on the new machine, after copying

ROOT defaults to the repository root. It is also used for the raw wind folders outside the repository
(e.g. E:\\m5_explore). Paths in SNAP.txt are relative to ROOT, so the copy may sit at another drive or folder.
Write SNAP.txt OUTSIDE the folder being hashed. Skipped (rebuilt by MATLAB/Python, never needed): slprj/, *.slxc,
__pycache__/, *.asv, *.autosave. The .git folder IS hashed: the repository history, local tags and unpushed commits
travel with the copy.

--check prints every file that is missing, extra or different, and exits 1 if any.
"""

import hashlib
import os
import pathlib
import sys

SKIP_DIRS = {"slprj", "__pycache__"}
SKIP_EXT = {".slxc", ".asv", ".autosave"}


def walk(root):
    for d, dirs, fs in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for f in sorted(fs):
            p = pathlib.Path(d) / f
            if p.suffix.lower() in SKIP_EXT:
                continue
            yield p.relative_to(root).as_posix(), p


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main():
    a = sys.argv[1:]
    if len(a) < 2 or a[0] not in ("--write", "--check"):
        print(__doc__)
        sys.exit(2)
    snap = pathlib.Path(a[1]).resolve()
    root = pathlib.Path(a[2]).resolve() if len(a) > 2 else pathlib.Path(__file__).resolve().parent.parent
    if a[0] == "--write":
        if root in snap.parents:
            print(f"write {snap.name} outside {root}: it would hash itself")
            sys.exit(2)
        n, lines = 0, [f"# folder_snapshot of {root}: SHA-256, bytes, relative path"]
        for rel, p in walk(root):
            lines.append(f"{sha(p)}  {p.stat().st_size:>12}  {rel}")
            n += 1
            if n % 500 == 0:
                print(f"  {n} files...", flush=True)
        snap.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"wrote {snap}: {n} file(s) under {root}")
        return
    rec = {}
    for ln in snap.read_text(encoding="utf-8").splitlines():
        if ln.startswith("#") or not ln.strip():
            continue
        h, size, rel = ln.split(None, 2)
        rec[rel] = (h, int(size))
    seen, bad = set(), []
    for rel, p in walk(root):
        seen.add(rel)
        if rel not in rec:
            bad.append(f"EXTRA    {rel}")
        elif p.stat().st_size != rec[rel][1] or sha(p) != rec[rel][0]:
            bad.append(f"DIFFERS  {rel}")
    bad += [f"MISSING  {rel}" for rel in rec if rel not in seen]
    for b in bad:
        print("  " + b)
    print(f"{len(rec)} file(s) recorded, {len(seen)} found under {root}: "
          + ("PASS - every file equal byte for byte" if not bad else f"{len(bad)} problem(s)"))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
