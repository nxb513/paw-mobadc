# PAW-MOBADC: payload-drag wind feed-forward for a quadrotor with a slung load, under measured wind

This repository holds the paper and everything needed to regenerate its numbers, tables and figures. The proposed
method, **PAW-MOBADC**, extends the multiple-observer anti-disturbance controller **MOBADC** (Guo et al., *Control
Engineering Practice* 102, 104560, 2020): the payload disturbance estimate is propagated over the loop delay
(PA-MOBADC), and the payload's aerodynamic drag is included in the measured-wind feed-forward. Plant **P2**: a
quadrotor coupled to a three-dimensional spherical pendulum, driven by measured NREL M5 wind. Every claim was
registered before its data were opened (`docs/REGISTER_P2.md`); the held-out set CONFIRM2 (14 days) was used once.

> **This is a simulation.** Measured wind drives a simulated vehicle; there is no flight test.

Tags: `paper-results-p2` (results and CONFIRM2 complete), `v1-final` (the earlier planar-pendulum study, removed
from this branch).

## Layout

| path | content |
|---|---|
| `CLAUDE.md` | working rules for Claude Code on this repository (read first) |
| `docs/MIGRATION.md` | moving the repository and its data (not in git) to another machine, checked by SHA-256 |
| `paper/manuscript.md` | the paper (pandoc Markdown; equations labelled `{#eq:...}`) |
| `paper/references.bib` | every reference, cited by key (`[@guo2020]`); `paper/elsevier-with-titles.csl` renders them numbered |
| `paper/figures/` | Figures 1-9 (`.pdf`, `.png`, and `.labels.txt` = every string drawn) - generated only |
| `paper/tables/tables_p2.md` | Tables 1-6 - generated only |
| `docs/RESULTS_P2.md` | every result number with its set, role and source file - generated only |
| `docs/REGISTER_P2.md` | the registration: plan, amendments and results in order (append only) |
| `docs/EQUATIONS_TABLE.md` | every equation, its source, what was changed |
| `docs/DEVIATIONS.md`, `docs/LIMITATIONS_METHODS.md` | deviations after data were seen; methods and limitations |
| `docs/MOBADC_FIDELITY.md`, `docs/INDI_FIDELITY.md` | how the baseline and the INDI-type comparison follow their papers |
| `data/SHA256SUMS.txt` | size and SHA-256 of every result file the paper reads (the files are not in git) |
| `baseline1.slx`, `build/`, `simulink_blocks/` | the Simulink model; each `build_*.m` inserts one component (paper Section 4.0); the source of every MATLAB Function block |
| `core/` | parameters, the P2 plant, segment sets (`p2_segset.m`), the run harness (`pa_configs.m`) |
| `experiments/` | the runners (`run_p2_gd6.m`, `run_p2_gd7.m`) and the night scripts `gd*_*.m` that produced the results |
| `analysis/` | `make_results_p2.m`, `make_p2_tables.m`, the statistics `p2r_*.m`, the names `p2_names.m` |
| `figures/p2/make_p2_figures.m` | Figures 1-9 |
| `verification/` | `check_all.m` (7 gates, no simulation), `verify_p2_repro.m` (re-simulation against the stored results), block checks |
| `tools/`, `python/` | text gates; wind download and export; the frozen wind predictor and its training code |

Files of the earlier v1 study (planar pendulum) that comments or old notes still name - `AUDIT.md`, `W6_INTEGRATION.md`,
`REGISTER_C.md`, `docs/MANUSCRIPT.md`, ... - are at the tag `v1-final`, unchanged (`docs/devlog/README.md`).

## Kept on purpose: the v1 path inside the model

`baseline1.slx` still contains the plant of the earlier v1 study (planar pendulum) as the `plant_model == 0` side of
its Variant controls, with `experiments/run_baseline.m`, `core/expected_baseline.m`, `baseline_table.txt` and
`payload_model_table.txt`. They are kept (user decision 2026-10-04) for two reasons:

- **Protocol lock.** `PROTOCOL_LOCK.md` (locked 2026-09-09, never edited) fixes the operating condition Test 3/4 and
  the parameters derived from it; gate 2 of `check_all` sets that state from the lock and compares it, on this path.
- **Bit-exact reproduction.** Taking the v1 path out means rebuilding and saving `baseline1.slx`. The stored results
  were produced by the model as it is, and `verify_p2_repro` reproduces Figures 3 and 9 bit for bit on that file.

Which plant runs: `init_MOBADC_params` sets `plant_model = 0` (v1) as the workspace default. Every run of the paper
goes through `pa_configs(..., 'PlantModel', 'p2')`, which sets `plant_model = 1`; the P2 signals are then selected by
Variant Sources and the v1 plant's outputs are not read - the poison test B6 replaces each of them by NaN and the
P2 metrics are unchanged to every printed digit (`docs/devlog/GD2B_DESIGN.md`, `verification/check_p2_b5_b7.m`).

## Reproduce a table or a figure

All commands run in MATLAB from the repository root after `setup_path`. They read the result files in `results/`
(see Data). `REGISTER_P2` sections define each item.

| item | command | result files read | REGISTER_P2 |
|---|---|---|---|
| every number of the text | `make_results_p2` -> `docs/RESULTS_P2.md` | `results/gd6`, `gd7`, `gd10` | sec 0.2 (statistics) |
| Table 1 (parameters) | `make_p2_tables` | none (`core/p2_params.m`) | sec 62.2 |
| Table 2 (Guo's controllers, with trim) | `make_p2_tables` | `gd6/guo_p2.mat`, `gd6/guo_trim_p2.mat` | sec 49, 51 |
| Table 3 (registered claims) | `make_p2_tables` | `gd6/d2_p2.mat`, `gd10/D2.mat`, `gd7/static-*.mat`, `gd10/C2-*.mat`, `gd7/N5-H-StrongRel.mat` | sec 60.3 |
| Table 4 (payload mass x cable length) | `make_p2_tables` | `gd6/tab_circle_*_p2.mat`, `gd6/d2_p2.mat` | sec 62.2 |
| Table 5 (six controllers, circle) | `make_p2_tables` | `gd6/guo_p2.mat`, `gd6/guo_trim_p2.mat`, `gd7/six-circle-h3.mat` | sec 63.2 |
| Table 6 (ablation) | `make_p2_tables` | `gd6/d2_p2.mat`, `gd7/six-circle-h3.mat`, `gd7/static-hover.mat`, `gd10/D2.mat`, `gd10/C2-*.mat` | sec 63.3 |
| Figure 1 (system) | `make_p2_figures('Only', 1)` | none | sec 62.1 |
| Figure 2 (wind data) | `make_p2_figures('Only', 2)` | `field_grid_K050.mat`, exploration and CONFIRM2 segment lists | sec 62.1 |
| Figure 3 (one CONFIRM2 segment) | `make_p2_figures('Only', 3)` - re-simulates, must equal the stored rows | `gd10/sets.mat`, `gd10/D2.mat`, `gd10/C2-circle.mat`, `wind_conf2/` | sec 62.1 |
| Figure 4 (C1) | `make_p2_figures('Only', 4)` | `gd6/d2_p2.mat`, `gd10/D2.mat`, `gd6/tab_T3b_p2.mat`, `gd6/tab_square_p2.mat` | sec 62.1 |
| Figure 5 (horizon) | `make_p2_figures('Only', 5)` | `gd6/n0p_p2.mat` | sec 62.1 |
| Figure 6 (C2, effort, swing) | `make_p2_figures('Only', 6)` | `gd7/static-*.mat`, `gd10/C2-*.mat`, `gd10/D2.mat` | sec 62.1 |
| Figure 7 (prediction vs measurement) | `make_p2_figures('Only', 7)` | `gd7/H3-*.mat`, `gd7/static-*.mat`, `gd10/C2-*.mat` | sec 62.1 |
| Figure 8 (C3 groups) | `make_p2_figures('Only', 8)` | `gd7/N4b-*.mat`, `gd7/N5-*.mat`, `gd7/N6.mat` | sec 62.1 |
| Figure 9 (six trajectories) | `make_p2_figures('Only', 9)` - re-simulates, must equal the stored rows | `gd6/d2_p2.mat`, `gd6/guo_p2.mat`, `gd7/six-circle-h3.mat` | sec 63.5 |

`verify_p2_repro` re-simulates D2 row 1, the Figure 9 segment and the Figure 3 segment (14 runs). Figures 3 and 9 must
equal their stored rows bit for bit; D2 row 1 (`gd6/d2_p2.mat`, written by an earlier build of the model) must be
unchanged to the printed digit, and the largest difference is printed (1.04e-7 m; REGISTER_P2 sec 65).

## Names in the paper and codes in the result files

<!-- names-table: generated by tools/readme_names.py; do not edit -->

| name in the paper | code in the result files | result files with this column |
|---|---|---|
| PID | `Classical` | `gd6/guo_p2.mat` |
| PID + trim | `Classical+trim` | `gd6/guo_trim_p2.mat` |
| DO + trim | `DO+trim` | `gd6/guo_trim_p2.mat` |
| DO | `DO` | `gd6/guo_p2.mat` |
| ESO | `ESO` | `gd6/guo_p2.mat` |
| MOBADC | `MOBADC` | `gd6/guo_p2.mat` |
| MOBADC | `L0` | `gd10/D2.mat`, `gd6/d2_p2.mat` |
| MOBADC-DC | `L1` | `gd7/H3-circle.mat` |
| MOBADC-W | `L2` | `gd10/D2.mat`, `gd6/d2_p2.mat`, `gd6/tab_T3b_p2.mat`, `gd6/tab_square_p2.mat` |
| MOBADC-W + preview | `V` | `gd10/D2.mat`, `gd6/d2_p2.mat`, `gd6/tab_T3b_p2.mat`, `gd6/tab_square_p2.mat` |
| PA-MOBADC | `L3` | `gd10/C2-circle.mat`, `gd10/C2-hhover.mat`, `gd10/C2-hover.mat`, `gd10/D2.mat`, `gd6/d2_p2.mat`, `gd6/tab_T3b_p2.mat`, `gd6/tab_square_p2.mat`, `gd7/H3-circle.mat`, `gd7/H3-hover.mat`, `gd7/N4b-P2-base.mat`, `gd7/N5-H-StrongRel.mat`, `gd7/iii-circle.mat`, `gd7/iii-hover.mat`, `gd7/static-circle.mat`, `gd7/static-hover-k.mat`, `gd7/static-hover.mat` |
| PAW-MOBADC | `L3_iii0` | `gd10/C2-circle.mat`, `gd10/C2-hover.mat`, `gd7/six-circle-h3.mat`, `gd7/static-circle.mat`, `gd7/static-hover-k.mat`, `gd7/static-hover.mat`, `gd7/static-indi-bias.mat` |
| MBP | `L3_iii` | `gd7/iii-circle.mat`, `gd7/iii-hover.mat` |
| INDI-DE | `H3` | `gd10/C2-circle.mat`, `gd10/C2-hover.mat`, `gd7/H3-circle.mat`, `gd7/H3-hover.mat`, `gd7/six-circle-h3.mat`, `gd7/static-hover.mat` |
| PAW-MOBADC (K-hat x 0.7) | `L3_iii0_k070` | `gd7/static-hover-k.mat` |
| PAW-MOBADC (K-hat x 1.3) | `L3_iii0_k130` | `gd7/static-hover-k.mat` |
| INDI-DE (bias 0.086) | `H3_b086` | `gd10/C2-hover.mat`, `gd7/static-indi-bias.mat` |
| INDI-DE (bias 0.17) | `H3_b170` | `gd10/C2-hover.mat`, `gd7/static-indi-bias.mat` |
| oracle | `O` | `gd10/C2-hhover.mat`, `gd7/N4b-P2-base.mat`, `gd7/N5-*.mat, gd7/N4b-*.mat`, `gd7/N5-H-StrongRel.mat` |
| PA-MOBADC + N6 term | `L3_6` | `gd7/N6.mat` |
| oracle + N6 term | `O_6` | `gd7/N6.mat` |

<!-- /names-table -->

## Check everything

```matlab
setup_path
check_all          % 7 gates: syntax, protocol lock, withdrawn claims, number propagation,
                   % model vs block sources, equations table, controller names
verify_p2_repro    % re-simulation of stored results (a few minutes; REGISTER_P2 sec 65)
```

The text gates also run without MATLAB, and on every push (GitHub Actions):

```bash
python tools/check_retracted.py      # withdrawn claims, references vs references.bib, Highlights, Abstract length
python tools/check_propagation.py    # manuscript numbers in RESULTS_P2 / tables (verbatim, or rounded where allowed)
python tools/check_equations.py      # every labelled equation has a source row; no priority claim
python tools/check_names.py          # no internal controller code in figures, tables, text
python tools/readme_names.py --check # the names table above is up to date
```

Render the paper: `cd paper && pandoc manuscript.md --citeproc -o manuscript.pdf` (equation labels need the
pandoc-crossref filter: `--filter pandoc-crossref`).

## Data

- **Wind:** public NREL NWTC M5 tower data, sonic anemometers at 61 m and 74 m, 20 Hz. Segments are 200 s long and
  are rebuilt, not stored:

  ```bash
  python3 python/plan_real_download.py --split dev --write get_m5
  python3 python/export_wind_sim.py --real-dir <m5> --real-split dev --real-max 10000 \
          --ckpt w4_frozen_20hz_t150_train2345_s0 --out wind_expl_t150.mat
  ```

- **Held-out days:** `CONFIRM2_MANIFEST.json` (read by `core/p2_segset.m`). `CONFIRM_MANIFEST.json` and
  `used_days.txt` record the days an earlier confirmation used, which CONFIRM2 excludes.
- **Result files:** `results/gd6`, `results/gd7`, `results/gd10` are not in git. `data/SHA256SUMS.txt` lists the
  size and SHA-256 of each; `python tools/data_manifest.py --check` verifies a local copy. They will be deposited on
  Zenodo at submission, and the DOI added here and in the paper.
- **In git:** `field_grid_K050.mat` (5 KB; `core/p2_segset.m` builds the development pool from it) and the frozen
  wind predictor `w4_frozen_20hz_t150_train2345_s0.pt` (SHA-256
  `0bc4b5b8ce39ef442506f82070c02c67c13efa3254f9932d9f00ad4882ea7fad`), trained on synthetic wind only and never
  retrained; the oracle study (C3) uses it.
