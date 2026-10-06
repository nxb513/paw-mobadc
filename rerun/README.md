# rerun/ - the final run of the paper

Added 2026-10-05. **The paper's numbers come from one new run** (`docs/REGISTER_FINAL.md`), not from the stored
results of `docs/REGISTER_P2.md`. Wind data are rebuilt from public NREL M5 files, horizons re-measured, every step run
on GitHub-hosted runners (MATLAB R2022b + Simulink) in parallel.

| file | what |
|---|---|
| `m5_dev_urls.txt` | the 260 NREL M5 files (65 dev-split days of 2024, hours 02/08/14/20), from `python/plan_real_download.py --split dev --all-days` |
| `m5_explore_files.txt` | the 128 files of the 32 exploration days (REGISTER_P2 sec 5.4) |
| `m5_confirm2_files.txt` | the 56 files of the 14 CONFIRM2 days (exported for completeness; not used by the final run) |
| `subset_sn.txt`, `subset_spk.txt` | segments re-exported with sensor noise 0.1 m/s (E1) / with the spike filter (E2) |
| `prep_data.sh` | download + export of every wind file the steps read |
| `rerun_steps.m` | every step: id, wave A-F, number of parallel parts, call |
| `rerun_run.m` | run steps in one MATLAB process: `addpath('rerun'); rerun_run({'D2#1/4', 'N0P-circle'})` |
| `final_tau.m` | the horizons, read from the saved sweeps by the rule of REGISTER_FINAL sec 3 |
| `rerun_merge.m` | merge the parallel parts (`<name>__s<k>of<n>N<N>.mat`) and the N0P parts |
| `rerun_summary.m` | list every result file and re-print each step's report (no simulation) |
| `make_workflow.py` | writes `.github/workflows/final.yml` from `rerun_steps.m` (`--check` in CI) |
| `m5_conf3_urls.txt` | the 232 NREL M5 files of CONFIRM3 (58 heldout-split days of 2022), fixed before any download |
| `confirm3_steps.m` | the CONFIRM3 steps (`C3-*`) and their dev test (`C3dev-*`); frozen configuration of REGISTER_FINAL sec 6.1 |
| `confirm3_gate.m`, `confirm3_gate.py` | opening condition of CONFIRM3 (APPROVED line in REGISTER_FINAL sec 6.1, code unchanged since) |

Check of the export (2026-10-05, local, before any run): the fresh export reproduces the registered development data
exactly (field_grid U, exploration fingerprint `73749ad2...`, every set SHA-256, fixed-5). Local R2024a also reproduced
D2 row 1 (`wind_real_t150_i0000`) to the printed digit: 0.0414 / 0.0334 / 0.0140 / 0.0136.

Start: GitHub -> Actions -> "final run (MATLAB, parallel)" -> Run workflow (`gh workflow run final.yml`). Waves A..F
need each other (`if: always()`); a part that fails or hits the 6-h limit uploads what it ran; "Re-run failed jobs"
resumes it. Results: artifact `final-results` of the report job. `rerun.yml` was the pilot (not used for numbers).
CONFIRM3 (`.github/workflows/confirm3.yml`, once): `CONFIRM3_MANIFEST.json` (`python/make_confirm3_manifest.py`),
export `--real-split heldout --only-days CONFIRM3_MANIFEST.json` into `wind_conf3/`, sets by the dev rules
(`core/p2_segset.m` option `Confirm2` with `wind_conf3`; `core/confirm_set.m`), results in `results/gd12/`. Dev test
first: `gh workflow run confirm3.yml -f dev_run=<final run id> -f devtest=true` (no 2022 file).
After a code fix, resume in a new run: `gh workflow run final.yml -f from_run=<run id> -f skip=<complete part ids,
comma-separated>` (the earlier run's `results-*` are downloaded first; the listed parts are skipped).
