#!/usr/bin/env python3
"""
check_reading.py -- every work cited in the manuscript has been read in full (docs/READING_LOG.md).

    python tools/check_reading.py            # report; exit 0 (drafting)
    python tools/check_reading.py --final    # before submission: exit 1 if any cited work is not READ

Rule (user, 2026-10-07): a work is cited only if its full text was read; a work that cannot be read is downloaded by
the user or not cited; a work read and found not relevant is not cited. READING_LOG.md holds one "### <key> - ..."
entry per work under "## READ", a "## TO GET" table, and "## DROP". This script lists, for the keys cited in
paper/manuscript.md: READ, TO GET (cited before its full text was read - must be read or removed before
submission), DROP (read and judged not needed - must not be cited), and keys with no entry at all.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAN = ROOT / "paper" / "manuscript.md"
LOG = ROOT / "docs" / "READING_LOG.md"


def section(text, head):
    m = re.search(r"^## " + re.escape(head) + r"\b.*?$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1) if m else ""


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    final = "--final" in sys.argv
    man = MAN.read_text(encoding="utf-8")
    body = man.split("## References")[0]
    cited = sorted(set(re.findall(r"@([a-z]+\d{4}[a-z]?)\b", body)))
    log = LOG.read_text(encoding="utf-8")
    read = set(re.findall(r"^### ([a-z]+\d{4}[a-z]?) ", section(log, "READ"), re.M))
    toget = set(re.findall(r"^\| ([a-z]+\d{4}[a-z]?) \|", section(log, "TO GET"), re.M))
    drop = set(re.findall(r"^### ([a-z]+\d{4}[a-z]?) ", section(log, "DROP"), re.M))
    print("  CHECK_READING - cited works read in full (docs/READING_LOG.md)")
    groups = {"READ": [], "TO GET": [], "DROP (cited but dropped)": [], "no entry": []}
    for k in cited:
        if k in read:
            groups["READ"].append(k)
        elif k in toget:
            groups["TO GET"].append(k)
        elif k in drop:
            groups["DROP (cited but dropped)"].append(k)
        else:
            groups["no entry"].append(k)
    for g, ks in groups.items():
        print(f"  {g:26s} {len(ks):3d}  {' '.join(ks)}")
    bad = groups["TO GET"] + groups["DROP (cited but dropped)"] + groups["no entry"]
    hard = groups["DROP (cited but dropped)"] + groups["no entry"]
    ok = not (bad if final else hard)
    print(f"  {'PASS' if ok else 'FAIL'}" + ("" if final else "  (drafting: TO GET allowed; --final requires all READ)"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
