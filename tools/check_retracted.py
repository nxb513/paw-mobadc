#!/usr/bin/env python3
"""
check_retracted.py -- the gate that catches what no other gate can.

    python3 tools/check_retracted.py

THIS ALREADY HAPPENED - IT IS NOT A HYPOTHETICAL
================================================
The numeric gates (`protocol_lock`, `pool_rule`, `fig_data`,
`check_results_numbers`) all check NUMBERS. None of them checks SENTENCES. So
the paper carried two wrong ones through many drafts while passing every gate:

  (1) "the horizon is not derivable from the nominal model"
      -> false: tools/tau_star.py derives both measured values, each within one
         20 ms grid step, with no free parameter.
  (2) "modelled as a linear pendulum ... sin(th) ~ th ... linearisation
      error 1.1%"
      -> false about this project's own source: payload_pendulum_derivative.m
         integrates sin/cos and payload_pendulum_output.m uses the full tether
         tension.

A third was caught later and is the clearest of the three: section 2.6 called a
circular fit a "positive structural result" while R3.4 said, of the same
number, that it carries no information because the parameter had been fitted to
the very datum it recovered. Same digits, opposite claim.

HOW IT WORKS
============
Each entry in BANNED is a phrase that has been REFUTED, by measurement or by
the source code. Such a phrase is not forbidden outright - the paper MUST be
able to say "we wrote X and X was wrong". So the rule is: the phrase may appear
only in a PARAGRAPH that also carries a retraction marker. No marker -> report.

This maintains itself: if someone rewrites the old sentence somewhere else, the
gate fires; and if the retraction paragraph is deleted, the gate fires too.

WHAT ELSE IT CHECKS
===================
  - the source tree, not just the paper: pool_rule.m carried the withdrawn
    linearisation justification long after the paper had dropped it, and
    pool_rule.m is the file a reviewer checking the pooling rule opens first;
  - references: every citation must have an entry and every entry must be
    cited, both directions;
  - the Highlights must obey the journal limit (at most five, 85 characters);
  - the Abstract length, and the body length as a warning;
  - the count of missed predictions, against the table in C6 - that number has
    already drifted once.
  - every build_*.m script is attributed in Section 4.0 of the manuscript.

2026-10-04: the v1 (planar-pendulum) study was removed from the repository, and
with it the checks that compared v1 documents and data (tau_star.py against
RESULTS.md, the A4 PROVISIONAL markers, REPO_MAP's register quotes, SNAPSHOT.md
fingerprints). The history above is kept because the BANNED phrases still apply.
"""

import hashlib
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# The files that ARE the paper, and therefore have to be right. docs/devlog/
# is HISTORY: it records the process including the wrong turns, so it is not
# scanned.
# 2026-10-04 (GD11d): the paper is the plant-P2 manuscript; its files are PAPER.
PAPER = [
    "paper/manuscript.md",
    "docs/RESULTS_P2.md",
    "paper/tables/tables_p2.md",
    "docs/EQUATIONS_TABLE.md",
    "README.md",
]
# 2026-10-04: the v1 (planar-pendulum) study, its documents and data were removed from the repository (user
# decision); git history keeps them. Nothing v1 is scanned any more.
V1_DOCS = []

# Retraction markers. A paragraph containing a banned phrase MUST carry at
# least one of these.
RETRACT = [
    "withdraw", "withdrawn", "retract", "was wrong", "were wrong",
    "no longer", "earlier draft", "earlier drafts", "in draft",
    "does not come back", "is void", "not match our own code",
    "did not match our own code", "superseded", "correction",
]

BANNED = [
    ("not derivable",
     "tools/tau_star.py derives tau* at both conditions, within one grid step"),
    ("must be measured, not derived",
     "same reason as above"),
    # Three wordings of ONE withdrawn claim. The first attempt at this entry was
    # the bare phrase "cannot be derived", which fired immediately on a TRUE
    # sentence - "three of four baseline rows cannot be derived from the
    # reference work's published parameters" - about a different subject
    # entirely. A banned phrase has to carry its subject with it, or the gate
    # reports the paper for saying something correct, and a gate that cries wolf
    # gets switched off. Same calibration rule as check_language's marker list.
    ("horizon it needs cannot be derived",
     "the wording that slipped past 'not derivable' and survived in "
     "COVER_LETTER.md until 2026-09-14 - tau_star.py derives both values within "
     "one grid step"),
    ("horizon cannot be derived", "as above"),
    ("horizon is undiscoverable", "as above - a third wording"),
    # The mechanism §7.1 offered for the contingency, withdrawn 2026-09-14 by the
    # cell registered in docs/REGISTER_C2.md. It is banned in three wordings for
    # the reason the tau* entries above give: one phrasing is never enough. Each
    # carries its subject, so none of them can fire on a true sentence about
    # something else - "propagates the wrong model forward" is only ever this
    # claim.
    ("propagates the wrong model forward",
     "refuted by R6.5 - reference preview never touches the disturbance internal "
     "model and is bounded by it almost as much (2.64x against 3.22x, 18% apart)"),
    ("prediction degrades sharply",
     "as above - what degrades is force-channel delay compensation from ANY "
     "signal source, not prediction specifically"),
    ("estimation degrades gracefully",
     "as above - the asymmetry it asserts is between estimation and prediction, "
     "and the measured asymmetry is between having the compensation and not"),
    # R6.3's own limitation paragraph, withdrawn 2026-09-14. It claimed the two
    # measured horizons came from the outdoor grid; they came from sweep_tau_eff
    # on the sinusoidal branch, which the re-run for Fig. 7 reproduces while
    # asserting payload_model = 0. Banned because it is the rare withdrawal that
    # made the paper look WORSE than the evidence: a wrong caveat is as much a
    # misstatement as a wrong claim, and it is likelier to be restored by
    # someone trying to be careful.
    ("compared against horizons measured on the pendulum branch",
     "false - sweep_tau_eff's payload branch calls reset_extensions, which sets "
     "payload_model = 0. Both horizons are sinusoidal-branch measurements, "
     "where F_p = 1.500 N is exactly the constant the closed form uses"),
    ("not a calibrated prediction of either value",
     "as above - the objection it states rested on the wrong provenance. The "
     "limitation that survives is the TRANSFER of 220 ms onto the outdoor grid, "
     "which is what R6.3 now says"),
    ("linear pendulum",
     "the simulated plant uses sin/cos and the full tension (payload_pendulum_*.m)"),
    ("linearisation envelope",
     "the 15 deg envelope is a declared operating choice, not a model-error bound"),
    ("linearisation error",
     "the simulator does not linearise, so no linearisation error exists"),
    ("actively harmful",
     "measured: the wrong internal model still cuts error by 11.8% - smaller, not harmful"),
    ("independent cross-check",
     "the wind channel 150 ms does not cross-check the payload horizon"),
    ("actuator-limit envelope",
     "A3-1 could not be scored, and two segments at 49%/63% saturation did NOT "
     "diverge - the 15 deg envelope may not be renamed"),
    ("saturation causes divergence",
     "measured and rejected in R6.2.1"),
    ("saturation explains the divergence",
     "as above"),
    ("positive structural result",
     "R3.4: 5.71 N was derived BACKWARDS from that very ESO row, so a "
     "one-parameter model recovering the datum it was fitted to is GUARANTEED "
     "and carries no information"),
    ("predicts their ESO row",
     "as above - that is a circular fit, not a prediction"),
    # A fourth wording of the same withdrawn claim, found in README.md by the
    # 2026-09-14 reviewer pass. The gate knew "cannot show a jackknife SE" and
    # walked straight past "which a bar cannot show" one clause later. Same
    # claim, different words - the recurring lesson of this list.
    ("a bar cannot show",
     "as below - an error bar shows a jackknife SE; that is what error bars are"),
    ("cannot show a jackknife SE",
     "an error bar shows exactly that - it is the standard way to plot one. The "
     "sentence was used to justify cutting five figures, and Tables 11-12 were "
     "cited as evidence for it; they show the SEs exist, not that they cannot be "
     "drawn. Withdrawn in R9"),
    ("only redraw numbers already stated",
     "true of four of the five retired figures, FALSE of the envelope scatter "
     "(now Fig. 4), which plots 26 individual segments and both development "
     "grids - no table in the paper holds that. Withdrawn in R9"),
    ("mechanism is the one R6.1 already established",
     "R6.1 establishes the internal-model VIOLATION; it does not establish the "
     "sign or size of the interaction in R5.1 - that is a reading, not a result"),
    # R6.4's original decomposition reading, withdrawn 2026-09-22. It treated
    # the L2->V / V->L3 magnitude split as a MECHANISM ATTRIBUTION - as if
    # payload prediction were 98.3% built from reference-lag compensation and
    # only 1.7% genuine disturbance prediction. A direct payload-off test
    # (docs/REGISTER_C.md sec 4.31; analysis/verify_circle_payload_separation_
    # k050.m, at R6.4's own exact K=0.5/25-segment configuration) refutes it:
    # L3's own gain over L2 collapses from -50.8% to +0.0% with no payload
    # force to predict, while V's gain is essentially unchanged (-49.9% with
    # the payload, -44.2% without it). Prediction genuinely uses the
    # disturbance throughout; the 98.3%/1.7% SPLIT is unchanged and still a
    # correct measurement, but describes two mechanisms compensating
    # correlated signals (nearly in phase on this trajectory, arg H ~= -9 deg,
    # sec 4.16/4.23), not one substituting for the other by 98.3%.
    ("compensation of the reference channel's delay, not of the disturbance",
     "withdrawn 2026-09-22 - the payload-off test shows prediction's own gain "
     "requires the real disturbance to exist (collapses to +0.0% without it), "
     "so it is not compensating the reference channel's delay instead of the "
     "disturbance; the two compensate correlated signals that coincide in "
     "phase on this trajectory. docs/REGISTER_C.md sec 4.31"),
    ("rather than disturbance prediction proper",
     "as above - the same withdrawn mutually-exclusive framing, a second "
     "wording"),
    ("prediction itself adds",
     "withdrawn 2026-09-22 - implies -4.86% is prediction's OWN, standalone "
     "gain; it is the INCREMENT prediction adds ON TOP of preview already "
     "being active (V->L3), not prediction's isolated benefit - which, "
     "measured with preview off, is -50.8%. Was the Highlights' own wording "
     "(docs/MANUSCRIPT.md); scanned and found nowhere else"),
    # Three wordings of one mechanism error, found while investigating why
    # sweep_tau_eff's own tau* pattern was clean on circle but flat on
    # T3a/T3b/square/Multisine (docs/REGISTER_C.md sec 4.53). The payload
    # channel was never oracle-injected - only the WIND channel's separate
    # branch (sweep_wind's w_oracle_ts) literally hands the controller a
    # true future value. The payload channel sweeps tau_pred through the
    # REAL predictor (simulink_blocks/payload_predictor.m's own
    # dmf_hat(t+tau) = B*e^{A*tau}*xi_hat, an internal-model extrapolation
    # of the DO's own estimated state), which is why its accuracy depends
    # on whether the assumed frequency matches the true disturbance -
    # exact on circle, wrong on the other four shapes. The circle numbers
    # these sentences described (220 ms, 120 ms, 83.6%, 64.7%) are
    # UNCHANGED; only the description of the mechanism that produced them
    # was wrong, fixed at the same time this entry was added.
    ("perfect future payload disturbance",
     "false about the mechanism - the payload channel is never oracle-injected, "
     "only swept through the real predictor's own internal-model extrapolation. "
     "docs/REGISTER_C.md sec 4.53"),
    ("perfect knowledge of the future payload disturbance", "as above - a second wording"),
    ("perfect future disturbance",
     "as above - MANUSCRIPT.md sec 4.2's own wording, a third; deliberately without "
     "'payload' in the phrase so it also catches an unqualified reprise of the same "
     "sentence, not just a verbatim repeat"),
]

# Absolutely banned: no context makes these sentences true.
BANNED_HARD = [
    ("recovers what the noise costs",
     "the filter reaches 0.0087/0.0090 against a clean baseline of 0.0085"),
    ("recovering what the noise costs", "as above"),
    ("Three preregistered intervals were missed",
     "12 predictions were missed in total; see the breakdown table in C6"),
]


def paragraphs(text):
    """(start line, text) for each paragraph, paragraphs separated by blank lines."""
    out, buf, start = [], [], 1
    for i, line in enumerate(text.splitlines(), 1):
        if line.strip() == "":
            if buf:
                out.append((start, "\n".join(buf)))
                buf = []
            start = i + 1
        else:
            if not buf:
                start = i
            buf.append(line)
    if buf:
        out.append((start, "\n".join(buf)))
    return out


def scan_banned():
    bad = []
    for rel in PAPER + V1_DOCS:
        p = ROOT / rel
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        # A line break must not make a phrase disappear: the paper wraps at 80
        # columns, so "was\nwrong" still has to count as "was wrong". This is
        # exactly what made the gate report wrongly on its first run.
        flat = " ".join(text.split()).lower()
        for phrase, why in BANNED_HARD:
            if phrase.lower() in flat:
                bad.append((rel, 0, phrase, why + "  [ABSOLUTELY BANNED]"))
        for start, par in paragraphs(text):
            low = " ".join(par.split()).lower()
            for phrase, why in BANNED:
                if phrase.lower() in low and not any(r in low for r in RETRACT):
                    bad.append((rel, start, phrase, why))
    return bad


def scan_refs():
    """Citations <-> reference list, both ways, plus unverified entries.

    Two silent failures in a reference list:
      - a [N] in the body with no matching entry -> the reader hits a dead end;
      - an entry nobody cites                    -> the list is being padded.
    Both happen the moment new entries are inserted in the middle, and both did:
    inserting [9]-[20] made two existing [9] citations point at the wrong work.

    Third check: count entries marked **[u]** - written from memory, checked
    against no record. They are not forbidden, but they must not walk silently
    into a submission.
    """
    f = ROOT / "paper" / "manuscript.md"
    if not f.exists():
        return ["paper/manuscript.md not found"], 0
    t = f.read_text(encoding="utf-8")
    k = t.find("## References")
    if k < 0:
        return ["paper/manuscript.md has no References section"], 0
    body = t[:k]
    # 2026-10-04: the references live in paper/references.bib and are cited by pandoc key ([@guo2020],
    # [@goldstein2002, chap. 1]); citeproc renders the numbered list. Every key cited must have an entry and every
    # entry must be cited. x-check records how an entry was verified; 'written from knowledge' = the old [u].
    bibf = ROOT / "paper" / "references.bib"
    if not bibf.exists():
        return ["paper/references.bib not found"], 0
    bib = bibf.read_text(encoding="utf-8")
    body = re.sub(r"`[^`\n]*`", " ", body)
    cited = set(re.findall(r"@([A-Za-z][\w-]*\d{4}[a-z]?)", body))
    listed = set(re.findall(r"^@\w+\{([^,\s]+),", bib, re.MULTILINE))
    bad = []
    miss = sorted(cited - listed)
    orph = sorted(listed - cited)
    if miss:
        bad.append(f"citations with no entry in references.bib: {miss}")
    if orph:
        bad.append(f"entries nobody cites: {orph} - the list is being padded")
    n_u = len(re.findall(r"x-check = \{written from knowledge", bib))
    return bad, n_u


# Banned phrases IN THE SOURCE, and why this is a SEPARATE list.
#
# This gate scanned the PAPER and not the source, so for a long time it
# reported PASS while pool_rule.m - the ONLY source of the pooling rule - still
# carried the withdrawn justification verbatim ("the threshold comes from the
# linearisation error of sin(theta) ~ theta"). A reviewer checking
# reproducibility opens exactly that file.
#
# A separate list because the source MUST be allowed to quote what was
# withdrawn - a retraction note is a good thing and it needs the old sentence
# verbatim. So only ASSERTIVE phrasings are banned here, and a line carrying a
# retraction marker is skipped.
CODE_BANNED = [
    ("nguong den tu sai so tuyen tinh hoa",
     "the 15 deg envelope is a declared operating envelope, not a model-error bound"),
    ("tuyen tinh hoa quanh theta = 0",
     "payload_pendulum_* integrates sin/cos and uses the full tension"),
    # Found in sweep_e1b.m, which produces Tables 9-10: the same withdrawn
    # justification in wording the two patterns above did not match. A banned
    # phrase list only catches the phrasings it knows, so each new one found is
    # added rather than assumed to be the last.
    ("mo hinh con lac tuyen tinh khong con dung",
     "the simulated pendulum does not linearise, so there is no linearisation "
     "limit to exceed; 15 deg is a declared envelope (pool_rule L1, R6.2)"),
    ("linear pendulum model no longer holds",
     "as above, in English"),
    ("where the linear pendulum",
     "as above - the plant integrates sin/cos and uses the full tether tension"),
]
# Retraction markers for the SOURCE scan, in both languages.
#
# Bilingual on purpose and only for now: the repository is mid-conversion from
# Vietnamese to English (see tools/check_language.py), so a retraction note may
# still be in either language. Drop the last two rows once that conversion
# reports DONE - but not before, or every Vietnamese retraction note left in
# tiers 2 and 3 starts reporting as an assertion.
#
# The Vietnamese here - these rows, plus the Vietnamese patterns in CODE_BANNED
# above - is the only Vietnamese left in tier 1, so check_language reports this
# file at 7 markers and will keep doing so until the conversion is finished.
# That is the intended behaviour, not unfinished work: the meter cannot reach
# zero until the condition for deleting these rows is actually met, which is a
# stronger guarantee than a comment saying "remember to delete this".
#
# It is a SEARCH STRING, not prose, and it is deliberately NOT fenced out of the
# count the way the frozen lock text is in protocol_lock.m. Fencing would silence
# the one signal that says the conversion is unfinished.
CODE_RETRACT = ["withdrawn", "was wrong", "used to say", "used to carry",
                "no longer", "earlier version", "does not linearise",
                "da bi rut", "cau do sai", "ly do cu", "tung ghi",
                "khong tuyen tinh hoa", "khong con dung"]
CODE_GLOBS = ["*.m", "simulink_blocks/*.m", "tools/*.py", "python/*.py"]


def scan_code():
    """Is a withdrawn phrase still being ASSERTED in the source?

    Scans BY LINE, not by paragraph: MATLAB comments start every line with %,
    so "paragraph" has no meaning here. A banned line is let through if it, or
    either of the two lines around it, carries a retraction marker.
    """
    bad = []
    seen = {pathlib.Path(__file__).resolve()}   # this file defines the phrases
    for g in CODE_GLOBS:
        for p in sorted(ROOT.glob(g)):
            if p.resolve() in seen or not p.is_file():
                continue
            seen.add(p.resolve())
            try:
                lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
            except OSError:
                continue
            low = [ln.lower() for ln in lines]
            for i, ln in enumerate(low):
                for phrase, why in CODE_BANNED:
                    if phrase not in ln:
                        continue
                    near = " ".join(low[max(0, i - 2):i + 3])
                    if any(r in near for r in CODE_RETRACT):
                        continue
                    bad.append((p.relative_to(ROOT).as_posix(), i + 1, phrase, why))
    return bad


def _words(s):
    s = re.sub(r"```.*?```", " ", s, flags=re.S)
    s = re.sub(r"\|.*?\|", " ", s)               # bo bang
    return re.findall(r"[A-Za-z][A-Za-z'\u2019-]*", s)


def scan_length():
    """Abstract and body length - the journal's limits, not the paper's.

    This is the kind of constraint that gets ignored until submission and then
    bounces at the technical-check stage, before a single reviewer reads a
    line. The abstract stood at 488 words against a typical 200-word limit:
    nobody reads that off the page, and no gate was counting.

    The body limit is a WARNING, not a failure. How long a paper should be is
    an editorial judgement, not a script's - so it prints the number and leaves
    the decision to a person.

    WHERE BODY_WARN COMES FROM, AND WHERE IT DOES NOT
    -------------------------------------------------
    ABS_MAX = 210 tracks a real limit: Elsevier journals in this area state an
    abstract maximum, and the abstract had stood at 488 words against it.

    BODY_WARN = 12000 has NO such source. It was picked as a rough norm for the
    field, and for a while this gate printed it as "the usual", which reads like
    a journal rule and is not one. Control Engineering Practice's guide for
    authors could not be read to confirm or deny a word limit - ScienceDirect
    serves a CAPTCHA to anything automated - and no limit appeared in any other
    source. What could be checked against the journal is the printed form: a
    2020 CEP article (101 (2020) 104509) runs 16 pages in two columns.

    So the threshold stays, because a number that goes up unnoticed is worse
    than an imperfect number, but the message now says whose threshold it is.
    Anyone cutting 8000 words to satisfy this line would be cutting to satisfy
    a guess.

    2026-09-14 - IT IS NO LONGER ONLY A GUESS, AND THE GUESS WAS LUCKY. The
    limit is still unverifiable (ScienceDirect now returns 403 rather than a
    CAPTCHA, and the Elsevier guide URL redirects there), and Crossref cannot
    help because CEP carries article numbers rather than page ranges. But the
    16-page 2020 article this comment already cited was retrieved in full and
    measured: 12 209 words before its References heading. BODY_WARN = 12000 is
    within 2% of that.

    The threshold is NOT moved to 12209. One article is one data point, moving
    it would imply a precision that does not exist, and the two numbers agree
    anyway. tools/length_audit.py holds the measurement and the per-section
    breakdown; docs/LENGTH_AUDIT.md holds what is to be done about it.
    """
    ABS_MAX, BODY_WARN = 210, 12000
    f = ROOT / "paper" / "manuscript.md"
    if not f.exists():
        return ["paper/manuscript.md not found"], None
    t = f.read_text(encoding="utf-8")
    bad = []
    m = re.search(r"^## Abstract$(.*?)^\*\*Keywords", t, re.M | re.S)
    if not m:
        bad.append("could not isolate the Abstract section")
        n_ab = None
    else:
        n_ab = len(_words(m.group(1)))
        if n_ab > ABS_MAX:
            bad.append(f"Abstract {n_ab} words, limit {ABS_MAX}")
    full = ROOT / "docs" / "MANUSCRIPT_FULL.md"
    n_body = len(_words(full.read_text(encoding="utf-8"))) if full.exists() else 0
    return bad, (n_ab, n_body, BODY_WARN)


def scan_highlights():
    """Highlights: at most FIVE, each <= 85 characters (the journal's rule).

    The easiest thing in the paper to get wrong and the least likely to be
    checked by eye: one good sentence, or one extra number, goes over - and the
    journal bounces it at submission rather than at review
    binh duyet. Dem bang may.
    """
    LIM, MAXN = 85, 5
    f = ROOT / "paper" / "manuscript.md"
    if not f.exists():
        return ["paper/manuscript.md not found"]
    t = f.read_text(encoding="utf-8")
    m = re.search(r"^## Highlights$(.*?)^## ", t, re.M | re.S)
    if not m:
        return ["paper/manuscript.md has no Highlights section"]
    items = [ln.strip()[2:].strip() for ln in m.group(1).splitlines()
             if ln.strip().startswith("- ")]
    bad = []
    if not items:
        bad.append("the Highlights section is empty")
    if len(items) > MAXN:
        bad.append(f"{len(items)} items, maximum {MAXN}")
    for it in items:
        if len(it) > LIM:
            bad.append(f"{len(it)} characters (maximum {LIM}): \"{it[:60]}...\"")
    return bad


def scan_miss_count():
    """The count of MISSED predictions must match the C6 table, everywhere.

    This number has drifted once already ("Three preregistered intervals were
    missed" is in BANNED_HARD for that reason), and it drifts in a very easy
    way: each time another prediction is registered and scored, the prose in
    three other places goes unedited. So the C6 table is the SINGLE SOURCE, and
    every prose sentence has to add up to it.
    """
    f = ROOT / "paper" / "manuscript.md"
    if not f.exists():
        return ["paper/manuscript.md not found"]
    t = f.read_text(encoding="utf-8")
    m = re.search(r"^\| where \| scored \| missed \|$(.*?)(?:^\s*$)", t, re.M | re.S)
    if not m:
        return ["paper/manuscript.md (C6) has no 'where | scored | missed' table"]
    sc = ms = 0
    rows = 0
    for ln in m.group(1).splitlines():
        c = [x.strip() for x in ln.strip().strip("|").split("|")]
        if len(c) != 3 or c[0].startswith("---"):
            continue
        a = re.match(r"^(\d+)", c[1])
        b = re.match(r"^(\d+)", c[2])
        if not (a and b):
            continue
        sc += int(a.group(1)); ms += int(b.group(1)); rows += 1
    if rows == 0:
        return ["no readable row in the C6 table"]
    bad = []
    pat = re.compile(r"(\d+) of the (\d+) registered predictions"
                     r"|[Oo]f\s+the (\d+) registered predictions[^.]*?,\s*(\d+) were missed")
    # A BARE count - no denominator, and often spelled out - is the form that got
    # past this gate. docs/COVER_LETTER.md said "Six preregistered predictions
    # were missed across two registrations" and went on saying it through two
    # further registrations, because the pattern above needs "N of the M". A bare
    # count is checked by VALUE, not by style. A heading may reasonably read
    # "Twelve registered predictions were missed" when the sentence under it gives
    # "12 of the 29"; what must never happen again is a bare count that is simply
    # the wrong number. The first version of this check reported the correct
    # heading too, which would have taught the next reader to ignore it.
    WORD = {w: i for i, w in enumerate(
        "zero one two three four five six seven eight nine ten eleven twelve "
        "thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty".split())}
    # "predictions" OR "intervals". The synonym is not hypothetical: Section 5.4
    # read "Three registered INTERVALS were missed" and stayed at three through
    # eleven further misses, because this pattern only knew the word
    # "predictions". A gate keyed on one noun checks one noun.
    bare = re.compile(r"\b([A-Za-z]+|\d+)\s+(?:pre)?registered\s+"
                      r"(?:predictions|intervals)\s+were\s+missed", re.I)
    seen = 0
    for rel in PAPER:
        p = ROOT / rel
        if not p.exists():
            continue
        # FLATTEN, then scan. The paper wraps at 80 columns, so a count can sit
        # either side of a line break - docs/RESULTS.md R0.5 read
        #     "**12 of the 29\nregistered predictions ... were missed**"
        # and stayed at 12/29 through two further registrations because this
        # scanner walked one line at a time and neither half matched. The BANNED
        # scan in this same file flattens for exactly this reason; this one did
        # not, so the gate reported PASS over a live contradiction with the C6
        # table. A line index is kept so the report still names a line.
        # Emphasis markers are DROPPED, not turned into spaces. REPORT_TO_ADVISOR
        # read "**15 of\nthe 31** registered predictions missed": flattening the
        # newline gave "the 31** registered", and the '**' sits between the number
        # and the word the pattern needs next, so the match failed and the gate
        # passed over a wrong denominator. This is the SECOND time markup, not
        # arithmetic, hid a stale count from this scan - the first was the line
        # wrap the comment above describes. Dropping the characters keeps the
        # line index aligned, which turning them into spaces would not.
        raw = p.read_text(encoding="utf-8")
        flat_chars, line_of = [], []
        ln = 1
        for ch in raw:
            if ch == "\n":
                ln += 1
                ch = " "
            if ch == "*":
                continue
            flat_chars.append(ch)
            line_of.append(ln)
        flat = "".join(flat_chars)
        for line, off in ((flat, 0),):
            for g in bare.finditer(line):
                tok = g.group(1).lower()
                if not (tok.isdigit() or tok in WORD):
                    continue
                if "of the" in line[max(0, g.start()-24):g.start()+40]:
                    continue              # carries a denominator; pat handles it
                seen += 1
                i = line_of[g.start()]
                n = int(tok) if tok.isdigit() else WORD[tok]
                if n != ms:
                    bad.append(f"{rel}:{i} says {n} predictions were missed, "
                               f"the C6 table sums to {ms}")
            for g in pat.finditer(line):
                seen += 1
                i = line_of[g.start()]
                if g.group(1):
                    gm, gs = int(g.group(1)), int(g.group(2))
                else:
                    gs, gm = int(g.group(3)), int(g.group(4))
                if (gm, gs) != (ms, sc):
                    bad.append(f"{rel}:{i} says {gm}/{gs}, the C6 table sums to {ms}/{sc}")
    if seen == 0:
        bad.append("no sentence quotes the missed-prediction count - the C6 table is orphaned")
    return bad


def scan_attribution():
    """Every build_*.m must appear in Section 4.0's attribution table.

    Section 4.0 claims a checkable boundary: what this work adds to baseline1.slx
    is exactly what a build_*.m script inserts, and nothing else is. That claim is
    only worth something if the table is complete - a script added later and not
    listed would silently become an unattributed component, which is the precise
    thing the table exists to prevent. So the boundary is checked against the
    directory rather than trusted.

    The reverse direction matters too: a row naming a script that no longer exists
    attributes a component the model does not have.
    """
    man = ROOT / "paper" / "manuscript.md"
    bdir = ROOT / "build"
    if not man.exists() or not bdir.is_dir():
        return []
    text = man.read_text(encoding="utf-8")
    m = re.search(r"^### 4\.0 (.*?)^### 4\.1 ", text, re.M | re.S)
    if not m:
        return ["paper/manuscript.md has no Section 4.0 attribution table"]
    table = m.group(1)
    scripts = sorted(f.stem for f in bdir.glob("build_*.m"))
    bad = []
    for name in scripts:
        if name not in table:
            bad.append(f"build/{name}.m inserts blocks into baseline1.slx but is "
                       f"not in Section 4.0's table - the component it adds is "
                       f"unattributed")
    for cited in re.findall(r"`(build_[A-Za-z0-9_]+)`", table):
        if cited not in scripts:
            bad.append(f"Section 4.0 names `{cited}`, which is not in build/")
    return bad


def main():
    print("=" * 74)
    print("  CHECK_RETRACTED - has a withdrawn claim come back")
    print("=" * 74)

    bad = scan_banned()
    if bad:
        print(f"\n[MISMATCH] {len(bad)} place(s):\n")
        for rel, ln, phrase, why in bad:
            print(f"  {rel}:{ln}")
            print(f"      phrase : \"{phrase}\"")
            print(f"      why    : {why}")
            print("      -> either remove the sentence, or put it in a paragraph "
                  "that retracts it\n")
    else:
        print(f"\n[OK] {len(PAPER)} paper files: no withdrawn claim has returned.")

    rbad, n_u = scan_refs()
    if rbad:
        print("\n[MISMATCH] reference list:")
        for x in rbad:
            print(f"      ! {x}")
    else:
        print("\n[OK] references: every citation has an entry, every entry is cited.")
    if n_u:
        print(f"      [ATTENTION] {n_u} entry(ies) marked **[u]** - written from")
        print( "                  memory, checked against no record. Verify or")
        print( "                  delete them BEFORE SUBMITTING.")

    cbad = scan_code()
    if cbad:
        print("\n[MISMATCH] a withdrawn phrase is still ASSERTED in the source:")
        for rel, ln, phrase, why in cbad:
            print(f"      ! {rel}:{ln}  \"{phrase}\"")
            print(f"        why: {why}")
    else:
        print("[OK] source: no withdrawn phrase is still asserted.")

    lbad, linfo = scan_length()
    if lbad:
        print("\n[MISMATCH] length:")
        for x in lbad:
            print(f"      ! {x}")
    elif linfo:
        n_ab, n_body, warn = linfo
        print(f"\n[OK] Abstract {n_ab} words.")
        if n_body > warn:
            print(f"      [ATTENTION] body ~{n_body} words, above this gate's "
                  f"own threshold of {warn}.")
            print("      That threshold is an INTERNAL HEURISTIC. Control "
                  "Engineering Practice\n"
                  "      publishes no word limit that could be verified from "
                  "its guide for authors,\n"
                  "      so do not treat this line as a journal rule. What was "
                  "checked against the\n"
                  "      journal instead: a 2020 CEP article runs 16 printed "
                  "pages in two columns.\n"
                  "      Length here is an editorial decision, and it is the "
                  "author's.")

    hbad = scan_highlights()
    if hbad:
        print("\n[MISMATCH] Highlights (journal rule: <= 5 items, <= 85 chars each):")
        for x in hbad:
            print(f"      ! {x}")
    else:
        print("\n[OK] Highlights: count and length within the rule.")

    mbad = scan_miss_count()
    if mbad:
        print("\n[MISMATCH] missed-prediction count vs the C6 table:")
        for x in mbad:
            print(f"      ! {x}")
    else:
        print("[OK] the missed-prediction count matches the C6 table everywhere.")

    abad = scan_attribution()
    if abad:
        print("\n[MISMATCH] Section 4.0 attribution table:")
        for x in abad:
            print(f"      ! {x}")
    else:
        print("[OK] every build_*.m is attributed in Section 4.0.")

    n = (len(bad) + len(rbad) + len(hbad) + len(mbad) + len(cbad)
         + len(lbad) + len(abad))
    print("\n" + "-" * 74)
    print(f"  {'PASS' if n == 0 else str(n) + ' MISMATCH(ES)'}")
    sys.exit(1 if n else 0)


if __name__ == "__main__":
    main()
