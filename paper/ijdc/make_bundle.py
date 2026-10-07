"""Collect the anonymised IJDC LaTeX submission into one flat zip (paper/ijdc/ijdc_latex.zip).

The journal compiles the LaTeX source itself, so the zip holds everything manuscript.tex needs and nothing else:
manuscript.tex, the class and bibliography style, references.bib, manuscript.bbl (written by the LaTeX run; the CI
workflow builds the zip after compiling) and every figure that manuscript.tex includes. Files sit in the zip root,
because submission systems flatten folders; graphicx finds figures in the current directory before \\graphicspath.

Before writing, the text files are checked for anything that identifies the authors: names, e-mail addresses,
organisations and the ORCID iD, all read from title_page.tex (which is uploaded separately and is not bundled).

    python paper/ijdc/make_bundle.py            # writes paper/ijdc/ijdc_latex.zip
    python paper/ijdc/make_bundle.py --check    # checks only, writes nothing
"""
import argparse
import pathlib
import re
import sys
import zipfile

HERE = pathlib.Path(__file__).resolve().parent
FIGURES = HERE.parent / "figures"
OUT = HERE / "ijdc_latex.zip"


def identifiers(title_page):
    """Strings that would identify the authors: full names, e-mails, organisations, ORCID iDs."""
    tp = title_page.read_text(encoding="utf-8")
    ids = set()
    for fnm, sur in re.findall(r"\\fnm\{([^}]*)\}\s*\\sur\{([^}]*)\}", tp):
        f, s = fnm.replace("~", " ").strip(), sur.strip()
        ids |= {f"{f} {s}", f"{s} {f}", f"{s}, {f}"}
    ids |= set(re.findall(r"\\email\{([^}]*)\}", tp))
    ids |= {o.strip() for o in re.findall(r"\\orgname\{([^}]*)\}", tp) if len(o.strip()) > 3}
    ids |= set(re.findall(r"\d{4}-\d{4}-\d{4}-\d{3}[\dX]", tp))
    return sorted(ids)


def figures_of(tex):
    names = re.findall(r"\\includegraphics(?:\[[^\]]*\])?\{([^}]*)\}", tex)
    out = []
    for n in names:
        p = FIGURES / n
        if not p.suffix:
            p = p.with_suffix(".pdf")
        out.append(p)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="check only, do not write the zip")
    args = ap.parse_args()

    tex_path = HERE / "manuscript.tex"
    tex = tex_path.read_text(encoding="utf-8")
    cls = re.search(r"\\documentclass(?:\[[^\]]*\])?\{([^}]*)\}", tex).group(1) + ".cls"
    bst = re.search(r"\\bibliographystyle\{([^}]*)\}", tex).group(1) + ".bst"
    bib = re.search(r"\\bibliography\{([^}]*)\}", tex).group(1) + ".bib"

    files = [tex_path, HERE / cls, HERE / bst, HERE / bib]
    bbl = HERE / "manuscript.bbl"
    if bbl.exists():
        files.append(bbl)
    else:
        print("  note: no manuscript.bbl (written by the LaTeX run; the CI workflow bundles after compiling)")
    files += figures_of(tex)

    problems = []
    for f in files:
        if not f.exists():
            problems.append(f"missing: {f.relative_to(HERE.parent.parent)}")
    names = [f.name for f in files]
    dup = {n for n in names if names.count(n) > 1}
    if dup:
        problems.append(f"two files with the same name in a flat zip: {sorted(dup)}")

    ids = identifiers(HERE / "title_page.tex")
    for f in files:
        if f.exists() and f.suffix in (".tex", ".bib", ".bbl"):
            text = f.read_text(encoding="utf-8", errors="replace").lower()
            for s in ids:
                if s.lower() in text:
                    problems.append(f"{f.name} contains an author identifier: {s!r}")

    for f in files:
        size = f.stat().st_size if f.exists() else 0
        print(f"  {f.name:28s} {size:>10,d} B")
    print(f"  anonymity: {len(ids)} identifiers from title_page.tex checked in the .tex/.bib/.bbl files")
    if problems:
        for p in problems:
            print("  FAIL:", p)
        sys.exit(1)
    if not args.check:
        with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
            for f in files:
                z.write(f, arcname=f.name)
        print(f"  wrote {OUT.relative_to(HERE.parent.parent)} ({OUT.stat().st_size:,d} B, {len(files)} files)")
    print("  PASS")


if __name__ == "__main__":
    main()
