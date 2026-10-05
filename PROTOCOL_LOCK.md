# PROTOCOL LOCK

Locked before the independent confirmation set was scored, under condition
Test 4. Written by `protocol_lock('write')`, verified by
`protocol_lock('check')`. `run_confirm_once` calls `'check'` before it runs and
REFUSES to run if anything differs.

Registered predictions: `docs/devlog/W6_INTEGRATION.md` §0.49, table T4-1..T4-6.
They were written BEFORE any closed-loop result existed at Test 4.

From this point on: no change to the horizon, the configuration, the metric, or
the day split. A bad Test 4 may not retreat to Test 2.

<<<LOCK
lock_version = 2
locked_utc = 2026-09-09T20:57:13
condition = Test 3/4
R_traj = 0.8
V_traj = 1.26
payload_sigma = 1.575
payload_amp = 1.5
wind_amp = 1
K_w = 0.2
payload_model = 1
payload_wind_on = 1
payload_K_ratio = 0.5
K_sensitivity = 1
do_harm_base = 1
do_harm_pa = [0 1]
tau_pred = 0.22
tau_wind_ms = 150
ckpt = w4_frozen_20hz_t150_train2345_s0
configs = g_base,g_pay,g_wind,g_both,g_sens,g_psens,g_orac
controllers = Classical{0,0,0},ESO{0,1,1},DO{1,0,0},MOBADC{1,1,1},PA-MOBADC{1,1,1}+[0 1]
confirm_mode = both
confirm_field = sweep_field_grid, cham dang ky D0 (muc 0.78)
confirm_sin = sweep_pa_grid, payload_model=0, cham T4-1..T4-6 (muc 0.49)
metric_seg = mean(norm(p_d - p)) tren cua so t >= TStat
agg_pooled = sqrt(mean(m_i^2)) tren cac doan trong tap gop
agg_by_day = sqrt(mean(m_i^2)) trong NGAY, roi TRUNG VI qua cac ngay
uncertainty = jackknife theo NGAY tren trung vi
metric_rejected = sqrt(sum(sse_track)/sum(n_track)) - da can nhac va LOAI
pool_L1 = bao mo hinh theta_DC <= 15 do
theta_dc_max = 15
theta_dc_form = rad2deg(K*K_w*U/(m_p*g))
pool_L2 = mot bang = mot tap: moi cot cua bang do huu han va khong phan ky
pool_L3 = con so dau bai lay tu BANG CHINH (moi cot la bien the MOBADC)
pool_L4 = phan ky bao RIENG theo tung bo
divergence = ~isfinite(mean(en)) | mean(en) > 1 m
dv_thresh = 1
exclusion = OnDiverge=flag; loai theo pool_rule (L1)+(L2), KHONG loc NaN tung cot
Stop = 200
TStat = 140
solver = ode4/1e-3
manifest = CONFIRM_MANIFEST.json
manifest_sha256 = 71ca3a52688f9570588df0ebad1786be0c23c4a451613847444efc95d397e470
manifest_content = b1683d6d6df2319b780654c7451a3158c3b89548cbec60e94ce70fafc29f6957
manifest_split = b8dfceb218b7aafdac0848f98a3c82d27576dcc71c28fbaa00efdd6f5be9a2ad
manifest_ndays = 32
LOCK>>>

## The lock block is in Vietnamese, and it stays that way

This repository was converted to English in 2026-09. The block above was **not**
converted, and that is deliberate rather than an oversight.

The block was written at `2026-09-09T20:57:13` and its entire evidential value
rests on being unmodified since. Re-writing it — even to change only the
language of four descriptive fields — would replace the artefact whose whole
purpose is to be unreplaceable. `protocol_lock('check')` compares only the
numeric fields and the manifest hashes, so a translation would not break the
check; that it would pass is precisely why it must not be done. The check is not
what makes the lock credible. Not having been touched is.

The table below is a **reading aid, not part of the lock.** It carries no
authority; if it ever disagrees with the block, the block is right.

| field | value in the block | in English |
|---|---|---|
| `confirm_field` | `sweep_field_grid, cham dang ky D0 (muc 0.78)` | outdoor grid; scores registration D0 (§0.78) |
| `confirm_sin` | `sweep_pa_grid, payload_model=0, cham T4-1..T4-6 (muc 0.49)` | sinusoidal grid; scores T4-1..T4-6 (§0.49) |
| `metric_seg` | `mean(norm(p_d - p)) tren cua so t >= TStat` | per-segment metric: mean position-error norm over the statistics window `t ≥ TStat` |
| `agg_by_day` | `sqrt(mean(m_i^2)) trong NGAY, roi TRUNG VI qua cac ngay` | pool within a day, then take the MEDIAN across days |
| `uncertainty` | `jackknife theo NGAY tren trung vi` | jackknife over DAYS, on the median |
| `metric_rejected` | `... da can nhac va LOAI` | considered and REJECTED |
| `pool_L1` | `bao mo hinh theta_DC <= 15 do` | declared operating envelope, `θ_DC ≤ 15°` |
| `pool_L2` | `mot bang = mot tap: moi cot cua bang do huu han va khong phan ky` | one table = one segment set: every column of that table finite and non-divergent |
| `pool_L3` | `con so dau bai lay tu BANG CHINH (moi cot la bien the MOBADC)` | the headline number comes from the MAIN table, where every column is a MOBADC variant |
| `pool_L4` | `phan ky bao RIENG theo tung bo` | divergence reported SEPARATELY, per controller |
| `exclusion` | `OnDiverge=flag; loai theo pool_rule (L1)+(L2), KHONG loc NaN tung cot` | flag divergence and continue; exclude by `pool_rule` (L1)+(L2); do NOT filter NaN column by column |

`pool_L1` is described there as a *model* envelope. That justification was later
withdrawn — the simulated pendulum does not linearise — while the threshold
itself, 15°, is unchanged. See `core/pool_rule.m` (L1) and Section 6, R6.2. The
locked file records what was believed on 2026-09-09, which is what a locked file
is for.

## Scope note, 2026-09-25 (outside the lock block; the block above is unchanged)

Decision of the author (sole author; `docs/devlog/ADVISOR_NOTES.md`): the scope of this
lock is **v1** - the planar-pendulum plant and every result obtained on it, archived at
tag `v1-final` (`d3a7633`). v1 is not part of the paper. Work on plant **P2** is governed
by `docs/REGISTER_P2.md` (its own metric, pooling rule, envelope and gates, registered
before any P2 result existed); this lock does not constrain P2, and `run_confirm_once`
remains a v1 tool.
