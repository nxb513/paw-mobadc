# Development log - kept as provenance, not part of the submission

These files are the dated working notes of the P2 study, written in Vietnamese as the work happened. They are **not**
part of the paper and are **not** translated: a lab notebook is evidence of the order in which things were decided,
and rewriting it afterwards would remove that property. `docs/REGISTER_P2.md` (the registration) and the code cite
them by section.

| file | what it records |
|---|---|
| `MASTER_PLAN.md` | the plan of the P2 study: scope C1-C4, comparisons, what was dropped |
| `KE_HOACH_THUC_HIEN.md` | the author's stage-by-stage plan (who does what, what is checked, when a stage is done) |
| `PLANT_P2_SPEC.md` | the specification of plant P2: every component and parameter with its source or assumption |
| `P2_SPEC_AUDIT.md` | the specification checked line by line against the running code (`file:line`) |
| `GD2B_DESIGN.md` | how plant P2 was wired into `baseline1.slx` (stage 2b) |
| `COMPETITORS_DESIGN.md` | the design of the competitors H3 (INDI-DE) and H4 (frequency-adaptive DOB; H4 later dropped, REGISTER_P2 sec 50) |
| `ADVISOR_NOTES.md` | authorship and scope: single author with no advisor or lab until 2026-10-07, three authors for the IJDC submission from then on; the scope decisions (published parameters, simulation only) |

## Files named in comments that are not in this branch

Code comments and the older notes also name files of the earlier v1 study (planar pendulum) - for example
`AUDIT.md`, `W6_INTEGRATION.md`, `REGISTER_C.md`, `REGISTER_ROBUST.md`, `REGISTER_TAU.md`, `SNAPSHOT.md`,
`docs/RESULTS.md`, `docs/MANUSCRIPT.md`, `CLAUDE_CODE_BRIEF.md`, `TEST_PLAN_v2.md`. They were removed from this branch on
2026-10-04 and are kept unchanged at the tag **`v1-final`** (`git show v1-final:docs/devlog/AUDIT.md`). The paper's
current files are `paper/manuscript.md`, `paper/tables/tables_p2.md` and `docs/RESULTS_P2.md`.
