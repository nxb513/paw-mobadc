"""Collect the anonymised IJDC LaTeX submission into one flat zip (paper/ijdc/ijdc_latex.zip).

The journal compiles the LaTeX source itself, so the zip holds everything manuscript.tex needs and nothing else:
manuscript.tex, the class and bibliography style, references.bib, manuscript.bbl (written by the LaTeX run; the CI
workflow builds the zip after compiling) and every figure that manuscript.tex includes. Files sit in the zip root,
because submission systems flatten folders; graphicx finds figures in the current directory before \\graphicspath.
Figures are renamed Fig<n>.pdf in the zip (and in its manuscript.tex), as the journal asks.

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
    """(source file, name in the bundle) per figure: Fig<n>.pdf, n = the figure's number (IJDC: "Name your figure
    files with 'Fig' and the figure number")."""
    out = []
    for m in re.finditer(r"\\includegraphics(?:\[[^\]]*\])?\{([^}]*)\}.*?\\label\{fig:(\d+)\}", tex, flags=re.S):
        p = FIGURES / m.group(1)
        if not p.suffix:
            p = p.with_suffix(".pdf")
        out.append((p, f"Fig{m.group(2)}{p.suffix}", m.group(1)))
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

    figs = figures_of(tex)
    for src, dst, ref in figs:                           # the bundled manuscript.tex names the figures Fig<n>
        tex = tex.replace("{" + ref + "}", "{" + dst + "}")
    # (source path or None, name in the zip, text for a rewritten file)
    items = [(None, "manuscript.tex", tex), (HERE / cls, cls, None), (HERE / bst, bst, None), (HERE / bib, bib, None)]
    bbl = HERE / "manuscript.bbl"
    if bbl.exists():
        items.append((bbl, "manuscript.bbl", None))
    else:
        print("  note: no manuscript.bbl (written by the LaTeX run; the CI workflow bundles after compiling)")
    items += [(src, dst, None) for src, dst, _ in figs]

    problems = []
    for src, name, _ in items:
        if src is not None and not src.exists():
            problems.append(f"missing: {src.relative_to(HERE.parent.parent)}")
    names = [name for _, name, _ in items]
    dup = {n for n in names if names.count(n) > 1}
    if dup:
        problems.append(f"two files with the same name in a flat zip: {sorted(dup)}")
    left = re.findall(r"\\includegraphics(?:\[[^\]]*\])?\{([^}]*)\}", tex)
    if any(not re.fullmatch(r"Fig\d+\.pdf", n) for n in left):
        problems.append(f"figures not renamed: {left}")

    ids = identifiers(HERE / "title_page.tex")
    for src, name, text in items:
        if name.endswith((".tex", ".bib", ".bbl")):
            t = (text if text is not None else src.read_text(encoding="utf-8", errors="replace")).lower()
            for s_ in ids:
                if s_.lower() in t:
                    problems.append(f"{name} contains an author identifier: {s_!r}")

    for src, name, text in items:
        size = len(text.encode("utf-8")) if text is not None else (src.stat().st_size if src.exists() else 0)
        origin = f"  <- {src.name}" if src is not None and src.name != name else ""
        print(f"  {name:20s} {size:>10,d} B{origin}")
    print(f"  anonymity: {len(ids)} identifiers from title_page.tex checked in the .tex/.bib/.bbl files")
    if problems:
        for p_ in problems:
            print("  FAIL:", p_)
        sys.exit(1)
    if not args.check:
        with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
            for src, name, text in items:
                if text is not None:
                    z.writestr(name, text)
                else:
                    z.write(src, arcname=name)
        print(f"  wrote {OUT.relative_to(HERE.parent.parent)} ({OUT.stat().st_size:,d} B, {len(items)} files)")
    print("  PASS")


if __name__ == "__main__":
    main()
