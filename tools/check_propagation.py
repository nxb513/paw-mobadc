#!/usr/bin/env python3
"""
check_propagation.py -- do the numbers travel intact from data to conclusion?

    python3 tools/check_propagation.py

THE PROBLEM
===========
A number in this paper travels along this chain:

    .mat files  ->  docs/RESULTS_P2.md (+ paper/tables/tables_p2.md)  ->  paper/manuscript.md

(Written for the v1 files docs/RESULTS.md and docs/MANUSCRIPT.md, tag v1-final; the text below keeps those names.)
                                         (Abstract, Highlights, C1-C6,
                                          Discussion, Limitations, Conclusion)

The FIRST leg already has a gate: check_results_numbers recomputes 85 numbers
in RESULTS.md from the .mat files. The SECOND leg had nothing - and it is the
longer leg, it passes through more rewriting, and it is the one a reader meets
first.

It failed twice in a row in a single paragraph: the segment-to-pooled ratio was
given as 0.72..0.93, copied from a stale source comment instead of computed;
the replacement, 0.42, was read off a four-digit console display when the data
said 0.42572, i.e. 0.43. Both passed every gate that existed.

THE RULE
========
The RESULT sections of the manuscript may only quote numbers that already
appear in RESULTS.md, VERBATIM. No re-rounding, no change of precision.

Changing precision sounds harmless and is not: 0.0236 and 0.02355 are the same
measurement, but once RESULTS.md changes there is no way to catch the stale
four-digit copy. Requiring the literal string is the only form an automated
gate can check.

EXCLUSION BY SECTION, NOT BY VALUE
==================================
Some sections are not results and legitimately carry numbers of their own:
physical parameters (Section 3.8, sourced from the reference work), the
analysis-only model of the boundedness theorem (Section 4.5), the notation,
the references, the appendices. Those are excluded BY SECTION NAME.

That is deliberate. An exclusion list keyed on VALUES would become the first
thing anyone edits when the gate complains - a rubber stamp. Excluding by
section forces an explicit statement that "this section is not results", which
is a claim that can itself be checked.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAN = ROOT / "paper" / "manuscript.md"
# 2026-10-04 (GD11d): the manuscript is the plant-P2 paper; its numbers come from the GENERATED P2 sources
# (analysis/make_results_p2.m -> RESULTS_P2.md, analysis/make_p2_tables.m -> TABLES_P2.md). The v1 sources
# (RESULTS.md, SUPPLEMENTARY.md) belong to the archived v1 manuscript (docs/devlog/archive/) and are not read.
RES = ROOT / "docs" / "RESULTS_P2.md"
TAB = ROOT / "paper" / "tables" / "tables_p2.md"
# 2026-10-07: the final run (docs/REGISTER_FINAL.md) adds a third generated source - analysis/make_results_final.m ->
# RESULTS_FINAL.md (the reproduction of every dev number of RESULTS_P2, and the checks E1-E6).
RES2 = ROOT / "docs" / "RESULTS_FINAL.md"

# Sections that are NOT results. Matched on the heading-line prefix.
SKIP = (
    "## Notation",
    "## 2. Related work",
    "## 3. Model",           # plant parameters (Table 1, sourced), not results
    "## 4. Controllers",     # gains and horizons (Table 1), not results
    "## References",
    "## Appendix",
    "## Back matter",
)

# Sections where a result may be ROUNDED (reviewer, 2026-10-04: the Introduction, Abstract and Highlights round;
# Results give absolute errors to three significant figures).
# There a number passes if some number of RESULTS_P2 / TABLES_P2 with at least as many decimals rounds (half up) to
# it; whole percentages are checked too. Everywhere else the rule stays VERBATIM.
ROUNDED = ("## Highlights", "## Abstract", "## 1. Introduction", "## 6. Results", "## 9. Conclusion")
# Millimetres anywhere outside SKIP: verbatim in the sources, or a metre value of the sources x 1000, rounded.
SHAPE_MM = (r"(?<![\w.])(\d+(?:\.\d+)?)\s*mm\b", "millimetres")
SHAPES_ROUNDED = [(r"(?<![\w.])(\d+)\s*%", "whole percentage"),
                  (r"(?<![\w.])(0\.\d{3})(?![\d])", "three-decimal value")]


def rounds_to(v, nums):
    from decimal import Decimal, ROUND_HALF_UP
    d = len(v.split(".")[1]) if "." in v else 0
    q = Decimal(1).scaleb(-d)
    target = Decimal(v)
    for r in nums:
        dr = len(r.split(".")[1]) if "." in r else 0
        if dr >= d and Decimal(r).quantize(q, rounding=ROUND_HALF_UP) == target:
            return True
    return False


# The SHAPES a result number can take. Anything outside these three is not
# considered: section numbers, years, citation numbers and sample sizes are
# not results.
SHAPES = [
    (r"(?<![\w.])(\d+\.\d+)\s*%", "percentage"),
    (r"(?<![\w.])(0\.\d{4,5})(?![\d])", "metres"),
    (r"(?<![\w.])(\d+\.\d+)\s*(?:SE|standard errors?)", "multiples of SE"),
]


def strip_code(t):
    t = re.sub(r"```.*?```", " ", t, flags=re.S)
    return re.sub(r"`[^`]*`", " ", t)


def sections(text):
    """(heading, body, start line) for each ## or ### section."""
    out, head, buf, start = [], "(file head)", [], 1
    for i, line in enumerate(text.splitlines(), 1):
        if line.startswith("## "):
            out.append((head, "\n".join(buf), start))
            head, buf, start = line.strip(), [], i
        else:
            buf.append(line)
    out.append((head, "\n".join(buf), start))
    return out


def main():
    print("=" * 74)
    print("  CHECK_PROPAGATION - manuscript numbers verbatim from RESULTS_P2.md\n"
          "                     and paper/tables/tables_p2.md (both generated)")
    print("=" * 74)
    if not MAN.exists() or not RES.exists():
        print("  missing paper/manuscript.md or docs/RESULTS_P2.md")
        sys.exit(1)

    # Section 6's material now lives in TWO files: docs/RESULTS.md and the
    # sections the M5 length audit moved to docs/SUPPLEMENTARY.md. Both are the
    # checkable source, so both are read. Reading only RESULTS.md reported four
    # numbers as uncheckable the moment R3.4 moved - 5.71, 3.66, 0.2056, 0.2054
    # - and the "fix" a hurried reader would reach for is deleting them from the
    # manuscript, which loses a real measurement rather than finding it.
    res = strip_code(RES.read_text(encoding="utf-8"))
    if TAB.exists():
        res = res + "\n" + strip_code(TAB.read_text(encoding="utf-8"))
    if RES2.exists():
        res = res + "\n" + strip_code(RES2.read_text(encoding="utf-8"))
    man_raw = MAN.read_text(encoding="utf-8")

    nums = re.findall(r"\d+(?:\.\d+)?", res)
    from decimal import Decimal
    nums_mm = [format(Decimal(x) * 1000, "f") for x in nums if x.startswith("0.")]
    bad, n_ok, n_skip = [], 0, 0
    for head, body, start in sections(man_raw):
        if any(head.startswith(s) for s in SKIP):
            n_skip += 1
            continue
        body = strip_code(body)
        rounded = any(head.startswith(s) for s in ROUNDED)
        for pat, kind in SHAPES + (SHAPES_ROUNDED if rounded else []) + [SHAPE_MM]:
            for m in re.finditer(pat, body):
                v = m.group(1)
                if kind == "whole percentage":
                    # a bare integer occurs everywhere ("130" contains "30"): verbatim only as "<n> %", else by rounding
                    okv = bool(re.search(r"(?<![\d.])" + re.escape(v) + r"\s*%", res)) or rounds_to(v, nums)
                elif kind == "millimetres":
                    okv = bool(re.search(re.escape(v) + r"\s*mm", res)) or rounds_to(v, nums_mm)
                else:
                    okv = bool(re.search(re.escape(v) + r"(?![\d])", res)) or (rounded and rounds_to(v, nums))
                if okv:
                    n_ok += 1
                else:
                    ln = start + body[:m.start()].count("\n")
                    bad.append((head, ln, kind, v))

    if bad:
        print(f"\n[MISMATCH] {len(bad)} number(s) in the manuscript that do NOT "
              "appear verbatim in RESULTS_P2.md / TABLES_P2.md:\n")
        for head, ln, kind, v in bad:
            print(f"  {head}")
            print(f"      line ~{ln}  {kind}: {v}")
            print("      -> either it is wrong, or it uses a different number of "
                  "digits")
            print("         than RESULTS_P2 / TABLES_P2. Both are fixed in the MANUSCRIPT, "
                  "never in the data.\n")
    else:
        print(f"\n[OK] {n_ok} result numbers in the manuscript all appear in RESULTS_P2.md / TABLES_P2.md "
              "(verbatim, or correctly rounded where rounding is allowed).")
    print(f"     ({n_skip} sections excluded: parameters, analysis-only model, "
          "references, appendices)")

    print("\n" + "-" * 74)
    print(f"  {'PASS' if not bad else str(len(bad)) + ' MISMATCH(ES)'}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
