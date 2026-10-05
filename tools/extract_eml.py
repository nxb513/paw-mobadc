#!/usr/bin/env python3
"""
extract_eml.py -- Pull the MATLAB Function block code out of a .slx file.

A .slx file is a ZIP archive. The code of a MATLAB Function block lives in
simulink/stateflow/chart_*.xml as HTML-escaped text.

    python3 tools/extract_eml.py baseline1.slx                      # list
    python3 tools/extract_eml.py baseline1.slx -o outdir            # write files
    python3 tools/extract_eml.py baseline1.slx --check simulink_blocks

Use it to compare the code that ACTUALLY RUNS in the model against the .m files
in the repository -- that comparison is the only thing that catches the two
copies drifting apart without anyone noticing.

--check is the Python twin of sync_eml_blocks.m in its check mode. The same
gate, but it runs in CI or on a machine with no MATLAB. Exits 1 on a mismatch.

WHY THAT MATTERS, MEASURED
--------------------------
Commit e5326a8 rewrote a documentation path (docs/AUDIT.md ->
docs/devlog/AUDIT.md) across the whole repository. Two of the files it touched
were block sources, and baseline1.slx was never resynchronised. Because
sync_eml_blocks compares VERBATIM, comments included, run_baseline,
run_test4_payload, run_test5_predictor and run_sanity_t2 all stopped dead - and
nobody noticed for a day, because nothing ran this gate automatically. It is
now called from check_all.
"""

import argparse
import html
import os
import re
import sys
import zipfile


def extract(slx_path):
    """Return {function_name: source} for every MATLAB Function block in the .slx."""
    found = {}
    with zipfile.ZipFile(slx_path) as z:
        for name in z.namelist():
            if not re.match(r"simulink/stateflow/chart_\d+\.xml$", name):
                continue
            raw = z.read(name).decode("utf-8", errors="replace")
            best = ""
            for m in re.finditer(r">([^<>]{60,})<", raw):
                text = html.unescape(m.group(1))
                if text.lstrip().startswith("function") and len(text) > len(best):
                    best = text
            if not best:
                continue
            # MATLAB's '...' line continuation can split the output list from
            # the function name across a real newline (e.g. simulink_blocks/
            # im_est_estimator.m and im_est_do_rebuild.m, both multi-line
            # signatures) - collapse it to a single space ONLY for this name
            # -detection pass, so the regex (which must not otherwise cross a
            # genuine newline, or it would run into the following help-text
            # comment) still finds it. 'best' itself stays untouched - it is
            # what gets compared against the .m file below.
            joined = re.sub(r"\.\.\.\s*\n\s*", " ", best)
            m = re.match(r"\s*function\s+.*?=\s*(\w+)\s*\(", joined)
            fname = m.group(1) if m else os.path.splitext(os.path.basename(name))[0]
            found[fname] = best.rstrip() + "\n"
    return found


def norm(text):
    """Ignore line-ending and trailing-whitespace differences, nothing else."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [ln.rstrip() for ln in text.split("\n")]
    while lines and not lines[-1]:
        lines.pop()
    return lines


def check(funcs, srcdir):
    """Compare the code in the .slx against the .m files. Return the problem count."""
    n_ok = n_diff = n_missing = 0

    for fname, in_model in sorted(funcs.items()):
        path = os.path.join(srcdir, fname + ".m")
        if not os.path.isfile(path):
            print(f"  [MISSING] {fname:<32} there is no {srcdir}/{fname}.m")
            n_missing += 1
            continue

        with open(path, encoding="utf-8", errors="replace") as fh:
            on_disk = fh.read()

        a, b = norm(in_model), norm(on_disk)
        if a == b:
            n_ok += 1
            continue

        n_diff += 1
        print(f"  [DIFFER ] {fname:<32} (model {len(a)} lines / file {len(b)} lines)")
        for k in range(max(len(a), len(b))):
            la = a[k] if k < len(a) else ""
            lb = b[k] if k < len(b) else ""
            if la != lb:
                print(f"           line {k + 1}:")
                print(f"             model : {la[:69] or '(empty)'}")
                print(f"             file  : {lb[:69] or '(empty)'}")
                break

    # .m files with no corresponding block in the model
    if os.path.isdir(srcdir):
        extra = sorted(
            f[:-2] for f in os.listdir(srcdir)
            if f.endswith(".m") and f[:-2] not in funcs)
        for name in extra:
            print(f"  [EXTRA  ] {name:<32} no block in the model has this name")
            n_diff += 1

    print(f"\nMatch {n_ok} | Differ {n_diff} | Missing {n_missing}")
    if n_diff or n_missing:
        print(
            "\nThe model and {0}/ are OUT OF SYNC. Numbers taken now cannot be\n"
            "reproduced from the source in git. In MATLAB, pick a direction:\n"
            "  sync_eml_blocks('Apply',  true)   % the .m file is the correct one\n"
            "  sync_eml_blocks('Export', true)   % the model is the correct one\n"
            "\nBefore choosing 'Apply': that rewrites baseline1.slx, so its MD5 in\n"
            "docs/SNAPSHOT.md changes and the binary in the repository is no longer\n"
            "the one that produced the published numbers. For a comment-only\n"
            "difference, bringing the .m file back into line is the cheaper fix -\n"
            "see simulink_blocks/WIRING.md.".format(srcdir))
    return n_diff + n_missing


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("slx")
    ap.add_argument("-o", "--outdir", help="write each function to <outdir>/<name>.m")
    ap.add_argument("--check", metavar="DIR",
                    help="compare the .slx code against the .m files in DIR; exit 1 on a mismatch")
    args = ap.parse_args()

    if args.check:
        print("=" * 74)
        print("  CHECK_EML_SYNC - baseline1.slx vs simulink_blocks/")
        print("=" * 74)

    funcs = extract(args.slx)
    if not funcs:
        print("No MATLAB Function block was found.")
        return 1

    if args.check:
        n = check(funcs, args.check)
        print("\n" + "-" * 74)
        print("  PASS" if n == 0 else "  FAIL")
        return 1 if n else 0

    for fname, src in sorted(funcs.items()):
        if args.outdir:
            os.makedirs(args.outdir, exist_ok=True)
            path = os.path.join(args.outdir, fname + ".m")
            with open(path, "w") as fh:
                fh.write(src)
            print(f"  wrote {path}  ({len(src)} bytes)")
        else:
            print(f"  {fname:<34} {len(src):>6} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
