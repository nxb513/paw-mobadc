#!/usr/bin/env python3
"""
check_equations.py -- every labelled equation of the manuscript has a row in docs/EQUATIONS_TABLE.md.

    python3 tools/check_equations.py            # gate (check_all step 8)
    python3 tools/check_equations.py --final    # before submission: also no [C?], no CẦN TÌM / CHƯA TRA, all ticked

Rules (user decision 2026-09-29, docs/devlog/KE_HOACH_THUC_HIEN.md GĐ11):
  - manuscript labels are pandoc-crossref style: `$$ ... $$ {#eq:name}`, cited as `@eq:name`;
  - every label in paper/manuscript.md has a table row (column 2, `eq:name`);
  - every `@eq:` citation points to a label that exists in the manuscript or in the table;
  - every row's type is [A], [B], [C] or [C?]; a [C] row must say where / when the literature was searched
    ("tra:" in its notes or source); labels in the table are unique.
--final additionally fails on any [C?] row, any "CẦN TÌM", "CẦN KIỂM" or "CHƯA TRA" in a row, and any row whose check cell is
not ticked "[x] ĐÚNG". "CẦN KIỂM" = a number read from a non-final source (e.g. an author PDF). Table rows not (yet) used in the manuscript are listed, not failed.
  - no priority claim on a formula (user decision 2026-10-04): the manuscript body (References excluded, code spans
    exempt) may not contain "novel", "novelty", "for the first time", or a "first" priority phrase ("the first to",
    "is the first", "first proposed / introduced / derived", "the first method / controller / formula / equation /
    approach / work / study / paper"). "first-order" and other plain uses of "first" are allowed.
Exit 0 = pass, 1 = fail. Prints the banner CHECK_EQUATIONS (read by verification/check_all.m).
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TABLE = ROOT / "docs" / "EQUATIONS_TABLE.md"
TYPES = {"[A]", "[B]", "[C]", "[C?]"}


def table_rows(text):
    """Rows of the equations table: dict label -> {type, row, line}. Section rows (no label) are skipped."""
    rows, dup = {}, []
    for n, ln in enumerate(text.splitlines(), 1):
        if not ln.startswith("|"):
            continue
        cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        if len(cells) < 7:
            continue
        m = re.fullmatch(r"`(eq:[A-Za-z0-9_-]+)`", cells[1])
        if not m:
            continue
        lab = m.group(1)
        if lab in rows:
            dup.append(lab)
        rows[lab] = {"type": cells[3], "row": ln, "line": n, "check": cells[-1]}
    return rows, dup


def manuscript_labels():
    labs, cites = {}, {}
    for f in sorted((ROOT / "paper").glob("manuscript*.md")):
        t = f.read_text(encoding="utf-8")
        for m in re.finditer(r"\{#(eq:[A-Za-z0-9_-]+)\}", t):
            labs.setdefault(m.group(1), []).append(f.name)
        for m in re.finditer(r"@(eq:[A-Za-z0-9_-]+)", t):
            cites.setdefault(m.group(1), []).append(f.name)
    return labs, cites


PRIORITY = [
    (r"\bnovel(ty)?\b", "novel"),
    (r"\bfor\s+the\s+first\s+time\b", "for the first time"),
    (r"\b(the|are|is|were|was)\s+(the\s+)?first\s+to\b", "first to"),
    (r"\b(is|are|was|were)\s+the\s+first\b", "is the first"),
    (r"\bfirst\s+(proposed|introduced|derived|presented|formulated|reported)\b", "first proposed"),
    (r"\bthe\s+first\s+(method|controller|formula|equation|approach|work|study|paper|scheme|design)s?\b",
     "the first <method>"),
]


def priority_claims():
    """Lines of the manuscript body (before '## References') that make a priority claim."""
    hits = []
    for f in sorted((ROOT / "paper").glob("manuscript*.md")):
        body = f.read_text(encoding="utf-8").split("\n## References")[0]
        body = re.sub(r"```.*?```", "", body, flags=re.S)
        for n, ln in enumerate(body.splitlines(), 1):
            ln2 = re.sub(r"`[^`\n]*`", "", ln)
            for pat, name in PRIORITY:
                if re.search(pat, ln2, flags=re.I):
                    hits.append(f"{f.name} line {n} [{name}]: {ln.strip()[:100]}")
                    break
    return hits


def main():
    # Windows consoles default to cp1252, which cannot print Vietnamese ('CẦN TÌM') or '−'; never crash on output.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    final = "--final" in sys.argv[1:]
    print("  CHECK_EQUATIONS - labelled equations vs docs/EQUATIONS_TABLE.md" + (" (--final)" if final else ""))
    if not TABLE.exists():
        print(f"  FAIL: {TABLE} not found")
        sys.exit(1)
    rows, dup = table_rows(TABLE.read_text(encoding="utf-8"))
    labs, cites = manuscript_labels()
    bad = []
    for d in sorted(set(dup)):
        bad.append(f"label {d} appears twice in the table")
    for lab, r in rows.items():
        if r["type"] not in TYPES:
            bad.append(f"{lab} (line {r['line']}): type {r['type']!r} is not one of [A] [B] [C] [C?]")
        if r["type"] == "[C]" and "tra:" not in r["row"]:
            bad.append(f"{lab} (line {r['line']}): [C] without a literature-search record ('tra: ...')")
    for lab, fs in sorted(labs.items()):
        if lab not in rows:
            bad.append(f"{lab} labelled in {', '.join(sorted(set(fs)))} has no row in EQUATIONS_TABLE.md")
    for lab, fs in sorted(cites.items()):
        if lab not in labs and lab not in rows:
            bad.append(f"@{lab} cited in {', '.join(sorted(set(fs)))} points to no label")
    for h in priority_claims():
        bad.append(f"priority claim (no 'novel' / 'first' on a formula): {h}")
    pend = {"[C?]": [], "CẦN TÌM": [], "CẦN KIỂM": [], "CHƯA TRA": [], "unticked": []}
    for lab, r in rows.items():
        if r["type"] == "[C?]":
            pend["[C?]"].append(lab)
        if "CẦN TÌM" in r["row"]:
            pend["CẦN TÌM"].append(lab)
        if "CẦN KIỂM" in r["row"]:
            pend["CẦN KIỂM"].append(lab)
        if "CHƯA TRA" in r["row"]:
            pend["CHƯA TRA"].append(lab)
        if not re.search(r"\[x\]\s*ĐÚNG", r["check"]):
            pend["unticked"].append(lab)
    if final:
        for k, v in pend.items():
            if v:
                bad.append(f"--final: {len(v)} row(s) {k}: {', '.join(v)}")
    ntype = {t: sum(r["type"] == t for r in rows.values()) for t in sorted(TYPES)}
    print(f"  table: {len(rows)} rows ({', '.join(f'{t} {n}' for t, n in ntype.items())})")
    print(f"  manuscript: {len(labs)} labelled equation(s), {len(cites)} cited label(s)")
    unused = sorted(set(rows) - set(labs))
    if unused:
        print(f"  not (yet) labelled in the manuscript: {len(unused)} row(s): {', '.join(unused)}")
    print("  still open before submission: " + "; ".join(f"{k} {len(v)}" for k, v in pend.items()))
    if bad:
        for b in bad:
            print(f"  FAIL: {b}")
        sys.exit(1)
    print("  PASS")
    sys.exit(0)


if __name__ == "__main__":
    main()
