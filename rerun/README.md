# rerun/ - re-running the paper's results on another machine

Added 2026-10-05. The original result files (`results/`, 39 files, `data/SHA256SUMS.txt`) and wind segments live on
the author's machine only. This folder rebuilds them from public data and re-runs every result file with the
registered parameters. **Agreement is expected to be close, not bit for bit** (other machine, other MATLAB release
when run locally, wind segments re-exported). Nothing here changes a registered claim or the CONFIRM2 record.

| file | what |
|---|---|
| `m5_dev_urls.txt` | the 260 NREL M5 files (65 dev-split days of 2024, hours 02/08/14/20), from `python/plan_real_download.py --split dev --all-days` |
| `m5_explore_files.txt` | the 128 files of the 32 exploration days (REGISTER_P2 sec 5.4: `--exclude-used` before D23 added the characterisation days) |
| `m5_confirm2_files.txt` | the 56 files of the 14 CONFIRM2 days (16 manifest days minus 2024-01-18, 2024-04-15; D23) |
| `prep_data.sh` | download + export (`wind_real_t150_i*`, `wind_expl_t150_i*`, `wind_conf2/`) |
| `rerun_steps.m` | every runner call behind the 39 files, with the steps each one reuses |
| `rerun_run.m` | run some steps in one MATLAB process: `addpath('rerun'); rerun_run({'D2', 'six-circle-h3'})` |

Checks after the export (MATLAB): `p2_segset('all', 'CapPerDay', 4)` - every set must print its registered SHA-256
(REGISTER_P2 sec 6.3.1) and the exploration fingerprint `73749ad2...` (sec 6.1); the 30 field_grid segments are
asserted against `field_grid_K050.mat` T.U to 1e-9. If they differ, the runners refuse the set (SHA assert).

GitHub Actions: `.github/workflows/rerun.yml` (manual start) runs the steps in four waves along the reuse chain;
each step is one job (6 h limit; a job that stops uploads its partial results, and re-running it resumes).
MATLAB on GitHub-hosted runners is free for public repositories; a private one needs the secret `MLM_LICENSE_TOKEN`.
