#!/usr/bin/env python3
"""
check_names.py -- no internal controller code in any figure, table or manuscript (REGISTER_P2 sec 63.1).

    python3 tools/check_names.py

The paper names are PID, DO, ESO, MOBADC, MOBADC-DC, MOBADC-W, MOBADC-W + preview, PA-MOBADC, PAW-MOBADC (proposed),
INDI-DE, MBP (analysis/p2_names.m). The codes L0-L3, V, (iii), iii-0, H3 and their variants stay in result files and
runners only. Scanned:
  - paper/manuscript.md, paper/tables/tables_p2.md, docs/RESULTS_P2.md, docs/EQUATIONS_TABLE.md;
  - paper/figures/*.labels.txt - every string drawn in each generated figure (written by make_p2_figures).
Exempt: `code spans` and fenced ``` blocks (file names such as `gd7/H3-circle.mat`, internal ids).
Exit 0 = pass, 1 = fail. Prints the banner CHECK_NAMES (read by verification/check_all.m).
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BANNED = [
    (r"(?<![\w-])L[0-3](?![\w.])", "L0-L3"),
    (r"\bL3_\w+", "L3_<variant>"),
    (r"L3_\{", "L3_{...}"),
    (r"\(iii(?:-0|-m)?\)", "(iii)"),
    (r"(?<![\w-])iii-?0(?![\w])", "iii-0"),
    (r"(?<![\w-])H3(?![\w.-])", "H3"),
    (r"\bH3_b\d+", "H3_b..."),
    (r"(?<![\w-])V\s*/\s*L\d", "V/L2"),
    (r"\|\s*V\s*\|", "column V"),
    (r"\bcolumns?\s+V\b", "column V"),
    (r"\bO_6\b|\bO6_0\b|\bP_6\b", "O_6 / P_6"),
]


def strip_code(text):
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    return re.sub(r"`[^`\n]*`", "", text)


def scan(path):
    hits = []
    raw = path.read_text(encoding="utf-8", errors="replace")
    clean = strip_code(raw)
    for n, ln in enumerate(clean.splitlines(), 1):
        for pat, name in BANNED:
            m = re.search(pat, ln)
            if m:
                hits.append((n, name, ln.strip()[:110]))
                break
    return hits


def main():
    # Windows consoles default to cp1252, which cannot print Vietnamese ('CẦN TÌM') or '−'; never crash on output.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print("  CHECK_NAMES - no internal controller code in figures, tables, manuscript (REGISTER_P2 sec 63.1)")
    files = sorted((ROOT / "paper").glob("manuscript*.md"))
    files += [ROOT / "paper" / "tables" / "tables_p2.md", ROOT / "docs" / "RESULTS_P2.md", ROOT / "docs" / "EQUATIONS_TABLE.md"]
    labels = sorted((ROOT / "paper" / "figures").glob("*.labels.txt"))
    files += labels
    if not labels:
        print("  note: no paper/figures/*.labels.txt yet (run make_p2_figures) - figures not checked")
    nbad = 0
    for f in files:
        if not f.exists():
            print(f"  note: {f.relative_to(ROOT)} not found - skipped")
            continue
        hits = scan(f)
        rel = f.relative_to(ROOT)
        if hits:
            nbad += len(hits)
            print(f"  FAIL {rel}: {len(hits)} line(s) with a code")
            for n, name, ln in hits[:8]:
                print(f"      line {n} [{name}]: {ln}")
            if len(hits) > 8:
                print(f"      ... {len(hits) - 8} more")
        else:
            print(f"  ok   {rel}")
    if nbad:
        print(f"  FAIL: {nbad} line(s) - use the names of analysis/p2_names.m")
        sys.exit(1)
    print("  PASS")
    sys.exit(0)


if __name__ == "__main__":
    main()
