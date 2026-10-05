#!/usr/bin/env python3
"""
check_params.py -- what init declares against what the model actually reads.

    python3 tools/check_params.py                    # baseline1.slx + init_MOBADC_params.m
    python3 tools/check_params.py --slx X --init Y

It reports three things:

  DEAD VARIABLE      init declares it, the model never reads it. Harmless to
                     the results, but it suggests a parameter is being driven
                     from the workspace when it is not. This happened with
                     wn_p and R_wind.

  MISSING VARIABLE   the model reads it, init does not declare it. Simulink
                     would report "Undefined variable" at compile time; this
                     catches it sooner.

  DEAD ARGUMENT      an argument of a MATLAB Function block that the body never
                     uses. This is the dangerous one: the variable has a value,
                     it is passed into the model, it gets printed in a table
                     caption - and it does nothing. That is what happened with
                     amp_tau (docs/devlog/AUDIT.md, item A1).

Runs without MATLAB: a .slx file is a ZIP archive.
"""

import argparse
import html
import os
import re
import sys
import zipfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Variables used only DURING init to build other variables; the model has no
# reason to read them.
BUILD_ONLY = {
    "c_tauf", "d_theta", "d_phi", "A_blk", "f_hover", "psi_w", "V_traj",
    # Internal-model harmonics: init uses these to build A_do/B_do/l_gain/do_w.
    "l_axis", "do_harm", "do_info",
}

# Variables the model does not read, kept DELIBERATELY so the code matches the
# notation of the paper. Listed separately rather than folded into BUILD_ONLY:
# they are GENUINELY dead, and hiding them would be repeating the habit that
# produced the amp_tau defect in the first place.
DOCUMENTED_UNUSED = {
    "Ky":     "alias of Kgamma; the model reads Kgamma",
    "Kv":     "alias of Knu; the model reads Knu",
    "Kp":     "collects Kp1..Kp3; the model reads them individually",
    "Ka":     "collects Ka1..Ka3; the model reads them individually",
    "M0_att": "the model reads Ixx/Iyy/Izz individually",
}


def model_reads(slx):
    """Base-workspace variables the model reads, taken from Constant blocks."""
    names = set()
    with zipfile.ZipFile(slx) as z:
        for entry in z.namelist():
            if not re.match(r"simulink/systems/system_.*\.xml$", entry):
                continue
            raw = z.read(entry).decode("utf-8", errors="replace")
            for blk in re.finditer(
                    r'<Block BlockType="Constant".*?</Block>', raw, re.S):
                v = re.search(r'<P Name="Value">([^<]*)</P>', blk.group(0))
                if not v:
                    continue
                expr = html.unescape(v.group(1))
                for tok in re.findall(r"[A-Za-z_]\w*", expr):
                    names.add(tok)
    return names


def eml_sources(slx):
    """{function_name: source} for every MATLAB Function block."""
    found = {}
    with zipfile.ZipFile(slx) as z:
        for entry in z.namelist():
            if not re.match(r"simulink/stateflow/chart_\d+\.xml$", entry):
                continue
            raw = z.read(entry).decode("utf-8", errors="replace")
            best = ""
            for m in re.finditer(r">([^<>]{60,})<", raw):
                t = html.unescape(m.group(1))
                if t.lstrip().startswith("function") and len(t) > len(best):
                    best = t
            if not best:
                continue
            m = re.match(r"\s*function\s+.*?=\s*(\w+)\s*\(", best)
            if m:
                found[m.group(1)] = best
    return found


def strip_comments(src):
    return "\n".join(re.sub(r"%.*$", "", ln) for ln in src.split("\n"))


def dead_arguments(src):
    """Arguments that appear in the signature but nowhere in the body."""
    m = re.match(r"\s*function\s+.*?\(([^)]*)\)", src, re.S)
    if not m:
        return []
    args = [a.strip() for a in m.group(1).split(",") if a.strip()]
    body = strip_comments(src[m.end():])
    # Drop any nested function definitions below this one
    body = re.split(r"^\s*function\s", body, maxsplit=1, flags=re.M)[0]
    return [a for a in args if not re.search(r"\b%s\b" % re.escape(a), body)]


def init_declares(path):
    """Top-level assignments in init (comments stripped)."""
    names = set()
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = re.sub(r"%.*$", "", line)
            for m in re.finditer(r"^\s*([A-Za-z_]\w*)\s*=(?!=)", line):
                names.add(m.group(1))
            for m in re.finditer(r";\s*([A-Za-z_]\w*)\s*=(?!=)", line):
                names.add(m.group(1))
    return names


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--slx", default=os.path.join(HERE, "baseline1.slx"))
    # core/, not the root: the sources were sorted into folders. Spelt out rather
    # than searched for, so a missing file is a clear error and not a silent
    # fallback to some other init file.
    ap.add_argument("--init",
                    default=os.path.join(HERE, "core", "init_MOBADC_params.m"))
    args = ap.parse_args()

    used = model_reads(args.slx)
    decl = init_declares(args.init)
    srcs = eml_sources(args.slx)

    problems = 0

    print("=" * 70)
    print("VARIABLES THE MODEL READS (from Constant blocks)")
    print("=" * 70)
    real = sorted(n for n in used if n in decl)
    print("  " + ", ".join(real))

    print()
    print("=" * 70)
    print("DEAD VARIABLES -- declared by init, never read by the model")
    print("=" * 70)
    dead = sorted(decl - used - BUILD_ONLY - set(DOCUMENTED_UNUSED))
    if dead:
        for n in dead:
            print(f"  {n}")
        print(f"\n  {len(dead)} of them. Remove them, or add them to BUILD_ONLY in")
        print("  this file if they are only used during init to build others.")
        problems += len(dead)
    else:
        print("  (none)")

    known = sorted(n for n in DOCUMENTED_UNUSED if n in decl)
    if known:
        print()
        print("  Dead but kept deliberately (not counted as a problem):")
        for n in known:
            print(f"    {n:<10} {DOCUMENTED_UNUSED[n]}")

    print()
    print("=" * 70)
    print("MISSING VARIABLES -- read by the model, not declared by init")
    print("=" * 70)
    # Filter tokens that are not variables: builtins and numeric constants
    builtin = {"zeros", "ones", "eye", "diag", "blkdiag", "pi", "inf", "nan",
               "true", "false", "sqrt", "cos", "sin", "deg2rad"}
    missing = sorted(n for n in used if n not in decl and n not in builtin)
    if missing:
        for n in missing:
            print(f"  {n}")
        problems += len(missing)
    else:
        print("  (none)")

    print()
    print("=" * 70)
    print("DEAD ARGUMENTS -- block arguments the function body never uses")
    print("=" * 70)
    any_dead_arg = False
    for fname in sorted(srcs):
        da = dead_arguments(srcs[fname])
        if da:
            any_dead_arg = True
            print(f"  {fname}({', '.join(da)})")
            for a in da:
                if a in decl:
                    print(f"      -> '{a}' IS declared in init. If it is printed in a")
                    print("         table caption, that table is reporting an operating")
                    print("         condition that does not exist. This is serious.")
                    if a == "amp_tau":
                        print("         docs/devlog/AUDIT.md item A1. Run remove_amp_tau.m in")
                        print("         MATLAB to strip this argument from the model.")
            problems += len(da)
    if not any_dead_arg:
        print("  (none)")

    print()
    print("=" * 70)
    if problems == 0:
        print("CLEAN.")
        return 0
    print(f"{problems} problem(s). See docs/devlog/AUDIT.md.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
