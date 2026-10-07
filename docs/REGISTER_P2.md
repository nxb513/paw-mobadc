# REGISTER_P2 — preregistration for plant P2

> Hierarchy for P2 (author's decision 2026-09-25, `docs/devlog/ADVISOR_NOTES.md`): **this file** >
> `docs/devlog/CLAUDE_CODE_BRIEF.md` > `docs/devlog/MASTER_PLAN.md` > `docs/devlog/KE_HOACH_THUC_HIEN.md`.
> `PROTOCOL_LOCK.md` governs v1 only (archived at `v1-final`); its metric and pooling definitions are restated in
> §0.2 and are owned here for P2; its 15° envelope is replaced for P2 by §0.10. Plant: `MASTER_PLAN.md` §2 and `docs/devlog/PLANT_P2_SPEC.md`.
> v1 results are frozen at tag `v1-final` (`d3a7633`). **No v1 number is evidence for any gate below.**

**Status of §0:** written 2026-09-25 from the user's decisions (a)–(e); revised the same day with the user's six
follow-up decisions (ζ_s = 0.05; τ_m = 30 ms assumed; `U_ref = 5` m/s; data-sufficiency rule; `O` uses `v_Q(t)`,
`O_F` only in the Monte Carlo; CONFIRM2 rule §0.6.1), then with the sole-author decisions (hierarchy above;
nominal plant and sensors from published sources, `PLANT_P2_SPEC.md` §2; **new P2 envelope §0.10**), then with the
user's review of 2026-09-25 (CONFIRM2 uncertainty §0.6.1; oracle horizon step N0W §0.3.1; two D1 flags §0.4;
report-only `O(0)` with `h_sensor` / `h_pred` §0.3, §0.6).
It must be marked **APPROVED** by the user
**before GĐ3 runs anything**. At the time of writing there is **no P2 closed-loop number** (the P2 model does not
exist yet), so nothing below was chosen after seeing a P2 result.

Sections after §0 (the protocol part: P2 dev set, one table per trajectory, τ rule on P2, block registrations) are
written at GĐ5 and do not change §0.

---

## 0. Decision gates, oracle definitions, condition groups

### 0.1 Freeze rule
- After APPROVED, §0 changes only by a **dated amendment committed before the first run of the block it affects**.
  An amendment written after any number of that block has been seen is not allowed; if it is ever needed, it is
  reported in the paper as a deviation, with the original rule's outcome shown too.
- Thresholds are never moved after seeing numbers (brief 3.1). Every gate outcome is reported, HIT or MISS.

### 0.2 Statistics used by every gate (same definitions as v1's PROTOCOL_LOCK and REGISTER_ROBUST §19.3, owned here)
- Per segment `m_i = mean(norm(p_d − p))` over `t ≥ TStat = 140 s` (`Stop = 200 s`); pooled `sqrt(mean(m_i²))`.
- Each table pools **one set** (pool_rule L2): a segment that raises **either flag of §0.4** (physical divergence or
  numerical flag) in any column of the table is held out of every column and listed, with the two flags reported
  separately.
- Reported with every gate number: pooled, `SE_pool` (paired delete-one-day jackknife), by-day median (+ jackknife),
  leave-one-segment-out (LOO) `[min, max]`, most influential segment, red flag.
- **"Keeps its sign under LOO"** means: for every leave-one-segment-out recomputation over the table's pooled set,
  the statistic has the same **strict** sign as its full-set value. A LOO value of exactly 0 counts as a flip.
- **Per-day value** of a ratio statistic (e.g. `h_d`) is computed from the day's own pooled columns
  (`h_d = 1 − pooled_d(O)/pooled_d(L3)` over that day's segments in the set), then the median is taken over days.

### 0.3 Columns on P2 and the two oracles (user decision (b))

The controller's wind-force model is **quadratic, the same form as the plant's body drag (MASTER_PLAN 2.8b), with
nominal parameters, relative velocity `w − v_Q`**:

`F̂(w, v_Q) = ½ ρ (C_D A)_Q^nom |w − v_Q| (w − v_Q)`, where `(C_D A)_Q^nom` is the plant's nominal value (spec).

It replaces v1's linear `K_w · w` at the controller's wind input (`WM_Kw`). The columns differ **only** in the wind
signal given to `F̂`; everything else is identical to `L3` (same payload prediction, same τ):

| column | wind signal into `F̂` | used by |
|---|---|---|
| `L2` | measured `w_meas(t)`, no payload prediction | D2 |
| `L3` | measured `w_meas(t)` + payload prediction at τ | D2, CỔNG G |
| `P` | PI-MoE prediction `ŵ(t + 150 ms \| t)` (frozen checkpoint, sha256 checked; horizon fixed by the checkpoint) | CỔNG G |
| `O` = `O(τ_w*)` | **true wind `w(t + τ_w*)` through the same `F̂`**, `τ_w*` from step N0W (§0.3.1) | CỔNG G |
| `O(150)` | true wind `w(t + 150 ms)` through the same `F̂` (the checkpoint's horizon) | reported beside `O`, not in the gate |
| `O(0)` | true **current** wind `w(t)` through the same `F̂` (perfect sensor, no advance knowledge) | reported beside `O`, not in the gate |
| `O_F` (optional) | **true-force oracle**: the plant's own `F_wQ` with the plant's parameters at `w(t + τ_w)` | reported separately, **never** in CỔNG G |

- Two wind horizons: `P` keeps the frozen checkpoint's **150 ms** (`wind_tau_ms` of
  `w4_frozen_20hz_t150_train2345_s0`); `O` uses **`τ_w*`** measured on P2 by N0W (§0.3.1). On P2 the motor lag
  (τ_m 30 ms), the wind-sensor delay (50 ms) and discretisation can move the best horizon away from 150 ms, and an
  oracle at the wrong horizon could make CỔNG G a false NO. The payload-prediction τ is a separate quantity (GĐ6).
- **Condition of the predictor on P2 (fact, for interpreting `c`):** PI-MoE receives the **measured** wind history —
  50 ms late and with σ 0.1 m/s noise **[corrected §43: on P2 the measured wind has NO noise (σ = 0) in every run; only the 50 ms delay and the 20 Hz hold are applied - a deviation from this text, found 2026-09-29]** — unlike the clean data it was trained on. Counted from the last sample it
  actually sees, its effective horizon is ~200 ms (150 + 50). This is the real operating condition and is kept.
- **Fact:** `O` is the true wind, so at nominal sensors it also removes the sensor's noise and 50 ms delay; `h` is
  therefore the value of perfect wind knowledge (advance **and** clean), as defined by the user's decision (b).
  `O(0)` separates the two parts (§0.6): `h_sensor` (perfect sensor, no advance) and `h_pred` (advance knowledge
  alone). The input of `O(0)` must equal the plant's wind `wind_ts` (printed check, max difference expected 0).
- `v_Q` in `F̂` is the controller's own current estimate at time `t` for every column (the future `v_Q(t + τ)` is
  not available to a causal controller). So `O` measures **the value of knowing the wind in advance with the force
  model held fixed**; `O − L3` is the headroom that a perfect wind predictor could give.
- **Decided:** `O` uses `v_Q(t)`. With nominal parameters (controller = plant) `O_F ≡ O` by construction, so
  **`O_F` is run only in the drag-parameter Monte Carlo (GĐ9)**, where the controller's `(C_D A)^nom` differs from
  the plant's. No two-pass (future `v_Q`) column is defined.
- Drag-parameter error (controller `(C_D A)^nom` ≠ plant) is a **separate Monte Carlo** (GĐ9), never mixed into the
  gate tables.

#### 0.3.1 N0W — oracle wind horizon `τ_w*` on P2 (runs before any CỔNG G group)
- Procedure = N0P's (REGISTER_ROBUST §12.1, §18.3): circle (`Test 4`), `K = 0.5`, `L = 1.0`, `m_p = 0.5`, nominal
  plant and sensors (`PLANT_P2_SPEC.md` §2), payload τ = circle τ\* on P2 (GĐ6), column `O(τ_w)` only, on the
  **5 fixed segments of REGISTER_ROBUST §18.6** (`i0000, i0319, i0453, i0715, i0900`).
- Grid: coarse `τ_w ∈ 0:20:400 ms`, then fine 10 ms steps within ±20 ms of the coarse minimum.
  `τ_w*` = argmin over coarse + fine of `pooled O(τ_w)` on the fixed set `S_c` = the segments finite and unflagged
  (§0.4) at **every** τ_w evaluated (N0P rule); a segment dropped from `S_c` is listed.
- Implementation (registered, to verify in GĐ2b): `O(τ_w)` is built by **shifting the time base** of the true
  wind (`w(t + τ_w)` with the same linear interpolation as `wind_ts`), not by whole 20 Hz samples, because the
  current code (`core/wind_sim_load.m:280`, `kk = round(τ·fs)`) can only shift in 50 ms steps. At `τ_w = 150 ms`
  the new construction must reproduce today's `w_oracle_ts` to floating-point rounding (printed check). Below the
  20 Hz sample spacing the oracle is an interpolation of the measured series (no wind information above 10 Hz).
- One `τ_w*` for every CỔNG G group and for CONFIRM2 (not re-measured per group or on CONFIRM2). The 5 segments
  are also in the dev set; that overlap is accepted as for N0P's τ\*.
- The grid contains `τ_w = 0`: `O(0)` on the 5 fixed segments is reported in the N0W table from the same runs
  (no extra run), beside `O(τ_w*)` and `O(150)`.

### 0.4 D1 (GĐ3, internal check) — descriptive, decided by the user
- Run as in `KE_HOACH_THUC_HIEN.md` GĐ3: circle, the 5 fixed segments of REGISTER_ROBUST §18.6
  (`i0000, i0319, i0453, i0715, i0900`), P2 components switched on one at a time; plus the hard cases (hover with
  payload, T5 with payload and no wind, T5 L 1.5, the largest m_p, the v1 `X-esoatt` cases).
- Two flags, recorded and reported **separately** (time of first occurrence, `θ_max`, stopping block):
  - **physical divergence** = solver stop, non-finite state, or slack (`T ≤ 0`);
  - **numerical flag** = constraint drift `max||q|−1| > 1e-6` or `max|ω·q| > 1e-6` (the run continues).
  Both flags remove the segment from every pool (§0.2), in every block, not only GĐ3.
- **D1 = "divergence remains"** if any registered case shows **physical divergence** on any of its segments with
  **all** P2 components on. Numerical flags are reported beside D1; if they occur, the constraint-stabilisation
  (MASTER_PLAN §2.3) is checked before any closed-loop block runs.
  Next step (GĐ4 or GĐ5) is the user's decision. GĐ3 numbers are diagnostic only and never enter the paper or a gate.

### 0.5 D2 (GĐ6) — payload prediction on P2
- Table: the **circle main table** on P2 — GĐ5's registered P2 dev set for circle, `K = 0.5`, `L = 1.0`,
  `m_p = 0.5`, payload τ = τ\* measured on P2 for circle (N0P procedure).
- `Δ = pooled(L3)/pooled(L2) − 1`.
- **D2 PASS ⇔ `Δ ≤ −30%` AND `Δ` keeps its (negative) sign under LOO** (every LOO `Δ < 0`).
- `SE_pool`, by-day median and the most influential segment are reported beside it but are not part of the gate.
- FAIL → stop; the direction is reviewed by the user (sole author, `ADVISOR_NOTES.md`). No further P2 block runs
  until the user decides.

### 0.6 D3 = CỔNG G (GĐ7) — wind prediction (user decision (c))

For each registered condition group `G` (§0.8), on that group's one pooled set:

- headroom `h = 1 − pooled(O(τ_w*))/pooled(L3)`;
- **G has headroom ⇔ `h ≥ 10%` pooled AND `h` keeps its sign under LOO AND the by-day median of `h_d` is `≥ 5%`.**
- capture `c = (pooled(L3) − pooled(P)) / (pooled(L3) − pooled(O(τ_w*)))`, `P` = frozen PI-MoE at 150 ms; evaluated
  **only** for a group with headroom
  (otherwise the denominator is not resolved and `c` is reported as "not evaluated");
- **G is captured ⇔ `c ≥ 0.5` pooled AND `pooled(L3) − pooled(P)` keeps its (positive) sign under LOO.**
- **CỔNG G = YES ⇔ at least one registered group has headroom AND is captured.** Otherwise NO.
  "Headroom but not captured" is a NO for the gate and is reported as such (headroom exists, the predictor does not
  reach it).
- Reported beside every group, **not** part of the gate: `O(150)`, `h(150)`, `c(150)`, `τ_w*`, and the split of `h`
  by `O(0)` (§0.3), each with the §0.2 statistics:
  - `h_sensor = 1 − pooled(O(0))/pooled(L3)` — value of a perfect sensor, no advance knowledge;
  - `h_pred   = 1 − pooled(O(τ_w*))/pooled(O(0))` — value of advance knowledge alone.
  Identity: `1 − h = (1 − h_sensor)(1 − h_pred)`; the two parts multiply, they do not add.
- **Reading note (not a gate):** if CỔNG G = YES for a group and `h_sensor > 0.5 · h` (the perfect-sensor part is
  more than half of the headroom), the report adds: "headroom mainly from sensor quality, not from prediction".
- **Reading note (not a gate):** when `|τ_w* − 150| ≥ 50 ms` (one 20 Hz wind sample) and a group with headroom is not
  captured (`c < 0.5`), the report adds: "may be due to the predictor's horizon / input distribution (§0.3)".
  Retraining PI-MoE (another horizon, noisy delayed inputs) is **new research** and needs its own amendment before
  any such run; it is not part of CỔNG G.
- **Data-sufficiency rule (decided):** a group whose pooled set (after the envelope and the one-set divergence
  rule) has fewer than **15 segments or 6 days** (brief N5 / REGISTER_ROBUST §24.5) is **not evaluable**: its
  numbers are reported, it is not merged with another bin, the bin edges are not re-cut, and it cannot make the
  gate YES. The P2 envelope (§0.10, new definition 2026-09-25) is accepted with this consequence.
- Consequence (KE_HOACH GĐ7): YES → payload + wind prediction are the main contribution, IM-est an extension;
  NO → payload prediction + IM-est are the main contribution, wind prediction is a negative result with a map of
  conditions. The final framing is D5 (the user).
- **Multiple comparisons (stated, not corrected):** CỔNG G is an "any of ~10 groups" test (**12 listed since amendment A3, §5.2**: N5-A-Strong is empty under A2 and N6 is pending, so at most 10 can be evaluated). No p-value correction is
  applied; the guards are the three-part headroom test (pooled + LOO sign + by-day median), reporting **every**
  group including failures, and carrying any YES group to CONFIRM2 (GĐ10) as a registered claim (§0.6.1).

#### 0.6.1 CONFIRM2 rule (GĐ10, decided before any CONFIRM2 day is opened)
- Carried to CONFIRM2: the D2 result (if PASS) and **every** group that made CỔNG G = YES. Nothing else is a
  confirmatory claim; other numbers stay exploratory.
- Each claim is run **once** on the 16 CONFIRM2 days (`CONFIRM2_MANIFEST.json`) with the **identical** definition:
  same group, bin edges, envelope, trajectory, payload τ, **the same `τ_w*` from N0W**, columns, frozen PI-MoE
  checkpoint (sha256) and a recorded git hash.
  The segment set = every CONFIRM2 segment that meets the group's definition (printed before the run); no
  re-running, no changes after the numbers are seen.
- `SE` = the statistic's own **paired delete-one-day jackknife** over the CONFIRM2 days in the set (§0.2).
- **Confirmed** (half the discovery threshold, same direction, and resolved from zero at one-sided 1.65 SE):
  - D2: `Δ_conf ≤ −15%` pooled **AND** `Δ_conf + 1.65·SE(Δ_conf) < 0`;
  - a CỔNG G group: `h_conf ≥ 5%` pooled **AND** `h_conf − 1.65·SE(h_conf) > 0` **AND** `c_conf ≥ 0.3`
    (`c_conf` with `O(τ_w*)` and `P` at 150 ms, as in §0.6).
  LOO and the by-day median are reported beside, not part of the test.
- For every carried CỔNG G group, CONFIRM2 also runs `O(0)` and reports `h_sensor`, `h_pred` and the §0.6 reading
  note — reported, not part of the confirmation test.
- A claim whose CONFIRM2 set fails the data-sufficiency rule (§0.6) is **"not confirmable"**, reported as such; the
  paper then states it as a development-set result only.
- Outcomes (CONFIRMED / NOT CONFIRMED / NOT CONFIRMABLE) are all reported, per claim.
- **Amendment H-hover (§26.3, 2026-09-27):** one further claim is carried to CONFIRM2 - the hover
  headroom hypothesis H-hover, with its own rule; it does not change CỔNG G.
- **Amendment H-model (§28.1, 2026-09-27):** a further claim carried to CONFIRM2 - the value of the
  N6 pendulum-model term with the measured wind in hover (h_model), with its own rule.

### 0.7 D4 (GĐ8) and D5
- **D4:** the held-out threshold `X` (e.g. "IM-est recovers ≥ 30% of the exact-frequency benefit") is set **by the
  user** and committed here as an amendment **before** `A-HO` runs. Held-out is scored once. R-U1b is re-registered
  on P2 before GĐ8 starts.
- **D5:** qualitative (title, contribution sentence), decided by the user from D2–D4 (sole author). No threshold.

### 0.8 Condition groups for CỔNG G — the complete list, registered in advance

Common unless stated: circle (`Test 4`), `L = 1.0`, `m_p = 0.5`, nominal plant and sensors of `PLANT_P2_SPEC.md`
§2 (wind sensor 20 Hz, σ 0.1 m/s **[corrected §43: on P2 the measured wind has NO noise (σ = 0) in every run; only the 50 ms delay and the 20 Hz hold are applied - a deviation from this text, found 2026-09-29]**, **delay 50 ms**), columns `L3, P, O(τ_w*)` + report-only `O(150), O(0)` (`O_F` only in the GĐ9 Monte Carlo; `τ_w*` from N0W §0.3.1, which runs first), payload τ by the τ rule (REGISTER_ROBUST §19.4, re-measured on P2 in GĐ6). Wind bins use `U` = magnitude
of the mean horizontal wind vector over `t ≥ TStat` (as `T.U`, `sweep_field_grid.m:182`); Weak `U < 6`, Medium
`6 ≤ U ≤ 12`, Strong `U > 12` m/s. Segment sets come from GĐ5's registered P2 dev set (field_grid + the 32
exploration days; never CONFIRM2) ∩ the P2 envelope of the group's own `(K, m_p)` (§0.10), fixed and printed
before the block runs.

| # | group | K | factor changed | set |
|---|---|---|---|---|
| 1 | `N5-A-Weak` | 0 | wind bin Weak | P2 dev set ∩ bin ∩ envelope (K 0) |
| 2 | `N5-A-Medium` | 0 | wind bin Medium | P2 dev set ∩ bin ∩ envelope (K 0) |
| 3 | `N5-A-Strong` | 0 | wind bin Strong (envelope ⇒ in effect 12–13.30 m/s) | P2 dev set ∩ bin ∩ envelope (K 0) |
| 4 | `N5-B-Weak` | 0.5 | wind bin Weak | P2 dev set ∩ bin ∩ envelope (K 0.5) |
| 5 | `N5-B-Medium` | 0.5 | wind bin Medium (envelope ⇒ in effect 6–10.86 m/s) | P2 dev set ∩ bin ∩ envelope (K 0.5) |
| 6 | `N4b-P2-base` | 0.5 | — | P2 circle main set |
| 7 | `N4b-P2-d200` | 0.5 | wind-sensor delay 200 ms (nominal 50 ms) | P2 circle main set |
| 8 | `N4b-P2-L15` | 0.5 | `L = 1.5` (τ\* measured on P2 for L 1.5) | P2 circle main set |
| 9 | `N4b-P2-K10` | 1.0 | `K = 1.0` | P2 circle main set ∩ envelope (K 1.0, `U ≤ 9.41`) |
| 10 | `N6` | — | wind → payload oscillation | **definition pending** |

- `N5-B-Strong` (K = 0.5, `U > 12`) lies wholly outside the K = 0.5 envelope (`U_max = 10.86`): reported per
  segment only (stress), never pooled — not a group. Likewise every segment above its group's `U_max`.
- `N5-A-Strong` keeps its definition; the envelope limits it to 12–13.30 m/s, so it may fail the data-sufficiency
  rule and be "not evaluable" — known in advance, accepted.
- `N6` gets an **analogous** definition (its own oracle `O_6`, `h_6 = 1 − pooled(O_6)/pooled(L3)`, the same
  three-part headroom test and capture test) by an amendment committed before N6's first run. Until then it is on
  the list but cannot make the gate YES.
- Nothing else (T5, other trajectories, other L/K/delay values, m_p levels) is a CỔNG G group; such cells may be
  reported but do not count. Adding a group needs an amendment before any number of that group exists.

### 0.9 K and m_p on P2
- `K` keeps its name as the payload-to-body drag ratio under quadratic drag: `(C_D A)_L = K · (C_D A)_Q`
  (MASTER_PLAN 2.8). **`K = 0` ⇒ `(C_D A)_L = 0`** (no wind force on the payload); **`K = 0.5`** ⇒ `(C_D A)_L = 2 · 0.5 · K_w/(ρ U_ref)`,
  MASTER_PLAN (2.8) (the user's "(2.9)"; the MASTER_PLAN numbering puts that formula in (2.8)).
- `m_p ∈ {0.25, 0.5, 0.65}` kg is the payload-mass sweep (GĐ7, payload branch), each reported with the saturation
  fraction (`sat_frac`) and peak thrust. CỔNG G groups use `m_p = 0.5`. **One table = one set:** the m_p table pools
  on the intersection of its levels' envelopes, i.e. the smallest `U_max` (at K = 0.5: `U ≤ 9.99`, set by
  `m_p = 0.25`).

### 0.10 `U_ref` and the P2 envelope (decided)
- **`U_ref = V_ref = 5` m/s** — the locked anchor of `K_w` (`core/wind_to_force.m`: `|w| = 5 m/s ⇒ 1.0 N`), so the
  quadratic body drag gives exactly 1.0 N at 5 m/s and `K_w` stays locked.
- **Record (not a free choice):** the median of `T.U` over the 25 `T.stable` segments of `field_grid_K050.mat` is
  **5.089828 m/s** (computed by the user in MATLAB, 2026-09-25:
  `median(Z.T.U(logical(Z.T.stable)))`). The locked anchor differs from the data median by **1.8%** (< 2%), so
  calibrating at the anchor or at the data median gives almost the same drag; the anchor is taken as representative.
- Resulting drag areas: `(C_D A)_Q = 2 K_w/(ρ U_ref) = 0.0653 m²`; `(C_D A)_L = K · 0.0653` (`0.0327 m²` at `K = 0.5`).
- **P2 envelope — new definition (author's decision 2026-09-25; replaces v1's `θ_DC ≤ 15°` for P2; valid because no
  P2 result exists yet).** A segment is inside the envelope when the UAV can hold position against the total
  **static** wind force at the segment's `U` (body + payload, quadratic drag, `v = 0`), computed **a priori from `U`
  alone, never from tracking error**:
  - `F_h(U) = K_w U² / U_ref · (1 + K)`  (= `F_wQ + F_wL` from MASTER_PLAN 2.8b, 2.8), `W = (m_Q + m_L) g`;
  - required tilt `atan(F_h / W) ≤ 0.8 · TILT_MAX` (= 24°) **AND**
    required thrust `sqrt(F_h² + W²) ≤ 0.8 · F_TOT_MAX`, `F_TOT_MAX = 0.9 × plant max`;
  - the payload angle `θ_L = atan(F_wL / (m_L g))`, `F_wL = K K_w U²/U_ref`, is **reported**, not used.
  - The envelope is always evaluated with the **nominal** plant max (30.67 N ⇒ `F_TOT_MAX = 27.60 N`), so a table's
    set does not change with the thrust-sensitivity variant (one table = one set).
  - Computed by `python/p2_envelope.py` (no simulation). `U` = `T.U` definition (mean horizontal wind vector over
    `t ≥ TStat`).

  **U_max [m/s] (nominal plant max 30.67 N; `0.8·F_TOT_MAX = 22.08 N`; tilt binds in every cell):**

  | K \ m_p [kg] | 0.25 | **0.50** | 0.65 | θ_L at U_max (m_p 0.25 / 0.5 / 0.65) |
  |---|---|---|---|---|
  | 0 | 12.24 | **13.30** | 13.91 | 0° |
  | 0.5 | 9.99 | **10.86** | 11.35 | 39.1° / 25.7° / 22.0° |
  | 1.0 | 8.65 | **9.41** | 9.83 | 50.7° / 35.8° / 31.2° |

  **Thrust sensitivity (plant max 20.44 N ⇒ `0.8·F_TOT_MAX = 14.72 N`) — for information only:** hover alone
  (`W = 15.90 N` at m_p 0.5, `17.37 N` at 0.65) exceeds 14.72 N, so the envelope would be **empty** for m_p ≥ 0.5;
  at m_p = 0.25, `U_max` = 12.22 / 9.98 / 8.64 m/s (K 0 / 0.5 / 1.0, thrust binds). This is why the envelope uses
  the nominal plant max; the linear-thrust variant is reported as a closed-loop saturation sensitivity (`sat_frac`)
  on the nominal set.

  **Consequences (facts, for the record):**
  - v1's `θ_DC ≤ 15°` gave `U_max = 12.84` m/s at K 0.5, m_p 0.5 (linear force); the new envelope gives 10.86 m/s.
  - At K = 0 the envelope now removes segments (`U > 13.30` at m_p 0.5), because body drag counts.
  - Inside the new envelope the static payload angle reaches 25.7° at K 0.5 and 35.8° at K 1.0 (m_p 0.5) — larger
    swing than v1's 15° cap. v1's most turbulent segment `i0780` had `θ_DC = 26.9°` at K 1.0 under the linear form;
    whether P2 holds such angles is a GĐ3 question (D1), not assumed here.
  - Per-group segment/day counts are printed with the set in GĐ5; the data-sufficiency rule (§0.6) applies.

---

APPROVED: Huyhoang   ngày: 2026-09-25

---

## 1. GĐ3 — internal check, stage by stage (registered 2026-09-25, before any stage runs)

Diagnostic only (§0.4): nothing here enters the paper or a gate other than D1. Written
after GĐ2b check B5, which is the reason for this block: with the full P2 (motor lag,
discrete loops, sensors) every closed-loop run stopped the solver in the attitude
dynamics (`UAV_Plant/Int_etadot`, once `Attitude_Observer/Int_za`), circle `i0000`,
L2/L3: 6.99-8.47 s with P2 sensor noise, 16.2-31.4 s without; the same times with the
poison (B6) and at step 5e-4 s (B7). GĐ2b's wiring is taken as done (B1, B2, B4 PASS;
B6 stop times identical to 4 digits); B5 is recorded FAIL = attitude-loop divergence
and moved here (user decision).

### 1.1 The one diagnostic round of B5 (`verification/diag_p2_b5.m`)
The two L3 runs of B5 (sensor noise on / off) stopped 0.5 s before the solver stop;
printed facts: Euler and pendulum angles, cable tension, motor saturation per second;
dominant frequency and growth of roll/pitch in the last 3 s.

**Hypothesis registered before the run (the user's, not a conclusion):** the 30 ms motor
lag (pole ~33 rad/s) sits close to Guo's attitude-loop bandwidth
(~sqrt(K_eta/I_xx) = sqrt(2.16/0.01) ~ 15 rad/s ~ 2.3 Hz), and together with the
attitude ESO's phase it removes the phase margin. **Supported if the dominant roll/pitch
frequency is ~2-3 Hz** and the oscillation grows; not supported otherwise (a pendulum-
or position-loop frequency ~0.4-0.7 Hz, or a divergence led by motor saturation, points
elsewhere). Either way this is a reading for the user, not a gate.

#### 1.1.1 Result of the diagnostic round (2026-09-25, facts)
L3, circle `i0000`, nominal P2, per 1-s window (noise on | noise off):
- 0-1 s: pitch up to 32.2 | 31.5 deg, pendulum 25.7 | 25.3 deg, motor COMMANDS at 0 or
  f_max 8.7 | 4.5 % of the time, lagged motor thrust never saturated, tracking error 0.09 m.
- 1-2 s: roll/pitch ~63/69 deg in both, cable slack (T_min -3.08 | -1.67 N), commands
  saturated 87 % of the time; from 2-3 s on the UAV tumbles (Euler angles unwrap past
  90 deg, error grows to metres); the noise-off run keeps integrating until 31 s.
- Dominant roll/pitch frequency over the last 3 s: 0.67 / 1.67 Hz (noise on),
  0.67 / 3.00 Hz (noise off) - measured AFTER the tumble, so not an onset frequency.
**Against the registered hypothesis:** the divergence does not grow as a 2-3 Hz attitude
oscillation; it starts within the first second, with and without P2 sensor noise, and
the commands saturate before the lagged thrust does. Hypothesis NOT supported by this
round. No new hypothesis is opened here; the stages S1-S4 (below) separate the components.

### 1.2 Stage switches (inside the P2 Variant choice only; v1 untouched)
Compile-time Variant Sources in `P2/P2_Core/P2`, set by `core/p2_setup.m` from
`pa_configs` options `P2MotorLag`, `P2Discrete`, `P2Sensors` (defaults on = the nominal
P2 of GĐ2b):
- `p2_motor_lag` 0: plant force = the controller's clamped motor commands (no lag);
  1: first-order lag `tau_m` (`P2TauM`).
- `p2_discrete` 0: every controller signal continuous (no ZOH on loop inputs/outputs);
  1: position loop 125 Hz, attitude loop 1 kHz, ZOH (GD2B_DESIGN sec 2.2).
- `p2_sensors` 0: controller sees the TRUE position, velocity, acceleration, rates (sampled
  if `p2_discrete` = 1), wind measurement not delayed; 1: mocap 8 ms delay + noise,
  velocity by backward difference, IMU/gyro noise, wind sensor 50 ms delay.
  `p2_sensors` = 1 requires `p2_discrete` = 1 (asserted).

### 1.3 Stages, cases, order
| stage | plant | motor lag | discrete | sensors |
|---|---|---|---|---|
| S1 | 3-D pendulum + quadratic drag | off | off | off |
| S2 | S1 + motor lag | `tau_m` ∈ {17, 30} ms (0 = S1) | off | off |
| S3 | S2 at nominal `tau_m` = 30 ms + discrete loops | 30 ms | on | off |
| S4 | S3 + sensors (= the nominal P2 of B5) | 30 ms | on | on |

Case: circle (`Test 4`), K = 0.5, DoHarm [0 1], columns L2 and L3, `i0000` first. If S1
is stable on `i0000`, every stage is then run on the 5 fixed segments of REGISTER_ROBUST
§18.6 (`i0000, i0319, i0453, i0715, i0900`). Hover trim (§0 of GD2B_DESIGN), nominal
parameters otherwise.

#### 1.3.1 Added stages S3', S4' (registered 2026-09-25, user request, before they run)
| stage | plant | motor lag | discrete | sensors |
|---|---|---|---|---|
| S3' | S2a + discrete loops | 17 ms | on | off |
| S4' | S3' + sensors | 17 ms | on | on (mocap 8 ms + noise, IMU/gyro noise, wind sensor 50 ms) |

Same cases as §1.3: circle, K = 0.5, DoHarm [0 1], L2 and L3, the 5 fixed segments
(`i0000` included), hover trim, Guo's gains. S1-S4 are unchanged. The user's reading:
**S4' = the real D1 of direction A** (the full P2 with `tau_m` = 17 ms). Reported as §1.4.
Note kept with it, not a decision: PLANT_P2_SPEC's nominal `tau_m` is 30 ms (17 ms is a
sensitivity value) and §1.5 says `tau_m` is not reduced to make the loop stable; using
S4' as D1 therefore needs the user's explicit decision on the nominal `tau_m` and its
source, recorded before D1 is read.

### 1.4 What is reported (facts, per stage x segment x column)
stable (ran 200 s) / diverged; stop time and block; dominant roll/pitch frequency and
growth over the last 3 s before the stop (or over the last 3 s for a stable run);
T_min, theta_max, motor saturation fraction; for stable runs the mean tracking error.

### 1.5 Reading rule (registered now)
- The first stage at which a case diverges names the component under suspicion; a stage
  that diverges when the previous one did not is the evidence, nothing weaker.
- D1 (§0.4) is read on S4 = all components on: divergence remains if any registered case
  diverges there. Next step (GĐ4 or GĐ5) is the user's decision.
- **Principle if S2 confirms the motor lag (NOT done now, needs the user's go-ahead):**
  `tau_m` is NOT reduced to make the loop stable. Instead the attitude gains are re-tuned
  by a published method - bandwidth parametrization (Gao 2003, the source Guo 2020 uses)
  - for the nominal `tau_m`, against phase/gain-margin criteria registered BEFORE the
  tuning, the same gains for every column, and declared in the paper.

### 1.6 Result, circle `i0000` (2026-09-25, facts; model `c0cdfc7`, build fingerprint `d7c39fb4…`)
`experiments/run_gd3_stages.m` at `276ff7d`, saved `results/gd3/gd3_20260925_091926.mat`
(the user's machine). Columns as §1.4; frequencies and growth over the last 3 s before
the stop (diverged runs: a re-run stopped 0.5 s before the solver stop), or of the
200 s run (stable); saturation = fraction of time a motor sits at 0 or f_max.

| stage | col | stable | stop [s] | block | f roll / pitch [Hz] | growth roll / pitch | T_min [N] | θ_L max [deg] | sat | err [mm] |
|---|---|---|---|---|---|---|---|---|---|---|
| S1  | L2 | yes | – | – | 0.33 / 0.33 | 0.90 / 1.15 | 4.905 | 23.9 | 0.000 | 26.34 |
| S1  | L3 | yes | – | – | 0.33 / 0.33 | 0.88 / 1.16 | 4.905 | 23.6 | 0.000 | 11.32 |
| S2a (17 ms) | L2 | yes | – | – | 0.33 / 0.33 | 0.89 / 1.15 | 4.781 | 24.0 | 0.000 | 26.33 |
| S2a (17 ms) | L3 | yes | – | – | 0.33 / 0.33 | 0.87 / 1.16 | 4.781 | 23.7 | 0.000 | 11.33 |
| S2b (30 ms) | L2 | **NO** | 8.585 | `Attitude_Observer/Int_za` | 1.00 / 3.67 | 0.95 / 1.15 | -3.972 | 146.2 | 0.108 | – |
| S2b (30 ms) | L3 | **NO** | 9.810 | `UAV_Plant/Int_etadot` | 0.67 / 2.67 | 0.87 / 1.15 | -4.128 | 176.8 | 0.152 | – |
| S3  | L2 | **NO** | 11.809 | `Attitude_Observer/Int_za` | 0.67 / 3.00 | 1.71 / 1.11 | -5.468 | 177.4 | 0.217 | – |
| S3  | L3 | **NO** | 6.750 | `UAV_Plant/Int_etadot` | 0.33 / 2.00 | 0.76 / 0.93 | -5.124 | 177.2 | 0.211 | – |
| S4  | L2 | **NO** | 8.465 | `UAV_Plant/Int_etadot` | 0.33 / 2.33 | 0.52 / 1.03 | -3.039 | 147.4 | 0.146 | – |
| S4  | L3 | **NO** | 6.987 | `UAV_Plant/Int_etadot` | 0.67 / 1.67 | 0.77 / 1.06 | -4.947 | 144.8 | 0.219 | – |

Also recorded:
- S4 reproduces the B5 stop times of the nominal P2 (8.47 / 6.99 s): the stage switches
  at their ON setting leave the GĐ2b model unchanged.
- With the motor lag OFF - the S1 run and the build's compile check with all three
  switches OFF; not S2a, which has the lag state - Simulink warns of **1 algebraic loop**
  with discontinuities in it: `P2_Trans`, `P2_WindHat`, `M_mix`, `M_sat` (algebraic
  variable), `Motor_Allocation/Alloc_2_3`, `Pos_Ctrl_9`, `LQI_Ctrl`/`LQI_Switch`,
  `Thrust_AttRef_16`, `Att_Ctrl_18`, `DO_Out`, `Payload_Predictor/pred_fcn`, the switches
  `WD_Switch`, `PP_Switch`, `Manual Switch(1)`. Without the lag state the plant force is
  a direct feed-through of the command, and the continuous P2 outputs feed the
  controller in the same step. S1 completed 200 s in both columns with Simulink's
  algebraic-loop solve. Fact only: nothing is changed for it (S1 is a diagnostic stage,
  the nominal P2 always has the lag).
- The pendulum angle max 145-177 deg and T_min < 0 in S2b-S4 are values over the whole
  run up to the pre-stop: the payload swings over and the cable goes slack before the
  stop. The dominant frequencies are measured in the last 3 s, AFTER that - as in §1.1.1
  they are not onset frequencies, and no reading is taken from them.

**Reading rule §1.5 applied (nothing beyond it):** the first stage at which `i0000`
diverges is **S2b** (S1 and S2a stable in both columns, S2b diverged in both) → the
component under suspicion is the **motor lag at the nominal `tau_m` = 30 ms**; at 17 ms
the loop is stable. S3 and S4 stay diverged. D1 on S4 for `i0000`: divergence remains.
Since S1 is stable on `i0000`, §1.3 runs every stage on the 5 fixed segments next;
D1 is read once those are in. The principle of §1.5 (re-tune by bandwidth
parametrization, margins registered first, `tau_m` not reduced) is NOT started.

#### 1.6.1 Result, the 5 fixed segments, S1-S4 (2026-09-25, facts)
Provenance, stated plainly: this batch was NOT started on purpose. The user's MATLAB was
still at `c0cdfc7` (the `git pull` line of the command block was a comment), whose
`run_gd3_stages` did not know the option `'DryRun'`, added it as a field and ran the
full `Fixed5` batch of stages S1-S4. Model = `c0cdfc7` (fingerprint `d7c39fb4…`), saved
`results/gd3/gd3_20260925_120119.mat` on the user's machine. The `i0000` rows reproduce
§1.6 to every printed digit. The runner now rejects unknown options (`99b62a2`+).

| stage | stable (of 10 runs) | per segment, L2 / L3 |
|---|---|---|
| S1 | **10/10** | err mm: i0000 26.34/11.32, i0319 26.90/8.55, i0453 27.12/9.48, **i0715 327.36/305.90**, i0900 25.88/6.49 |
| S2a (17 ms) | **10/10** | err mm: i0000 26.33/11.33, i0319 26.91/8.58, i0453 27.11/9.51, **i0715 327.20/305.70**, i0900 25.88/6.51 |
| S2b (30 ms) | **0/10** | stop s: i0000 8.585/9.810, i0319 35.686/13.230, i0453 27.456/14.836, i0715 100.176/9.809, i0900 10.739/15.596 |
| S3 | **0/10** | stop s: i0000 11.809/6.750, i0319 5.883/19.107, i0453 21.648/16.758, i0715 54.284/32.652, i0900 37.099/7.372 |
| S4 | **0/10** | stop s: i0000 8.465/6.987, i0319 20.808/35.950, i0453 18.513/19.151, i0715 16.658/88.976, i0900 18.541/160.267 |

- Stable runs: T_min 4.52-4.91 N, pendulum angle max 23.6-31.2 deg except `i0715`
  (45.9-46.4 deg, T_min 4.52-4.68 N), no motor saturation (0.000). On `i0715` the mean
  tracking error is 306-327 mm in S1 and S2a alike (11-50 times the other segments).
- Diverged runs stop in `UAV_Plant/Int_etadot` or `Attitude_Observer/Int_za`; the
  pendulum angle max is 141-180 deg and T_min < 0 (slack) before the stop; saturation
  0.09-0.85. Frequencies over the last 3 s are after the tumble, as in §1.1.1: not read.
- S1 was solved with Simulink's algebraic-loop solve (§1.6). The loop was traced to the
  build, not to physics: `P2_Trans` is a MATLAB Function block (direct feed-through on
  every output), and gamma/nu were read through it; with the lag OFF this closed an
  artificial loop. Fixed in the build (gamma/nu taken from the state `P2_x`, same
  doubles; algebraic loop = compile error) - **S1 is re-run after the rebuild** and
  replaces the S1 rows above; S2a-S4 have the lag state, no loop, and must reproduce.

**Reading rule §1.5 applied:** on every one of the 5 segments, in both columns, the first
diverging stage is **S2b** → component under suspicion: the **30 ms motor lag** (17 ms
stable everywhere). **D1 on S4: divergence remains in 10/10 registered cases.**

#### 1.6.2 Result after the loop fix: the 5 fixed segments, all 7 stages (2026-09-25, facts)
Model rebuilt at `a72f80b` (build fingerprint `dfba208e8ad1c07858bb7065f2a3dbe479c22d1afa3b6cf01a7b5ab2178cc8ae`):
compile check `plant_model` 0 / 1 / 1 with every GĐ3 switch OFF / 0 all clean with
`AlgebraicLoopMsg = error` - **no algebraic loop in any configuration**. B1: `verify_repro`
32 cells, largest difference 0.000e+00; `check_results_numbers` 146/146;
`extract_eml` Match 25 / Differ 0 (inside `check_all`); `check_all` 9/1, the one
failure being the SNAPSHOT MD5 of the new `baseline1.slx` (`5638D01E3FD741A1…`,
158 510 bytes - SNAPSHOT is updated from the pushed file). Batch
`run_gd3_stages('Fixed5', true)`, 35 calls, **22.4 min**, saved
`results/gd3/gd3_20260925_123937.mat` (user's machine).

- **S1 after the fix = S1 before it, every printed digit, 10/10 runs** (the algebraic-loop
  solve had converged to the same trajectory to printed precision). **S2a, S2b, S3, S4 =
  §1.6.1, every printed digit, 40/40 runs** (stop times to 1 ms, blocks, T_min,
  theta_max, saturation, error). §1.6.1 therefore stands with S1 now loop-free.
- **S3' (17 ms + discrete): stable 10/10. S4' (17 ms + discrete + sensors): stable 10/10.**

| seg | S2a err L2 / L3 [mm] | S3' err L2 / L3 | S4' err L2 / L3 | S4' T_min [N] | S4' theta_L max [deg] |
|---|---|---|---|---|---|
| i0000 | 26.33 / 11.33 | 26.63 / 11.35 | 33.37 / 15.24 | 4.623 | 23.8 |
| i0319 | 26.91 / 8.58 | 27.24 / 8.62 | 32.85 / 14.36 | 4.622 | 31.1 |
| i0453 | 27.11 / 9.51 | 27.46 / 9.54 | 33.09 / 14.46 | 4.624 | 31.2 |
| i0715 | 327.20 / 305.70 | 328.12 / 306.48 | 332.35 / 310.98 | 4.363 | 45.6 |
| i0900 | 25.88 / 6.51 | 26.21 / 6.50 | 32.50 / 12.98 | 4.507 | 28.5 |

S3' and S4': no motor saturation (0.000), no slack (T_min ≥ 4.36 N). Adding the discrete
loops moves the error by ≤ 0.9 mm; adding the sensors by +5.6 to +6.6 mm (L2) and
+3.9 to +6.5 mm (L3).

**Reading rule §1.5 on the 17 ms chain (S1 → S2a → S3' → S4'):** no stage diverges on any
segment in either column. **D1 on S4' (direction A, the full P2 at `tau_m` = 17 ms): no
physical divergence, 10/10 registered cases.** As recorded in §1.3.1, S4' counts as D1
only once the user decides the nominal `tau_m` (PLANT_P2_SPEC: 30 ms) and its source.

## 2. GĐ3 → attitude-gain re-tune for the motor lag (DRAFT, written 2026-09-25, NOT approved, nothing tuned)

Written before any gain is changed, as its own commit (user rule: register before
tuning). Trigger: §1.6 - on `i0000` the first diverging stage is S2b, the component
under suspicion the 30 ms motor lag; the user takes this as confirmed. The principle of
§1.5 applies: `tau_m` is NOT reduced; the attitude gains are re-tuned by a published
method for the nominal `tau_m`, with the criteria below fixed before tuning.

### 2.1 What changes and what does not
- Structure of Guo 2020 kept: attitude law (18) `tau = K_eta e_eta - K_omega omega -
  dltau_hat` (PD on the measured Euler angles and body rates) and attitude ESO (20)
  with `dltau_hat = M(za1) za3`. Only the VALUES of `K_eta`, `K_omega`, `Ka1..Ka3`
  change. No new block, no new state, the ESO keeps reading the COMMANDED torque
  (as built in GĐ2b).
- The new gains are set for plant P2 only (by `core/p2_setup.m`); `init_MOBADC_params`
  and every v1 default stay as they are, checked by `verify_repro` (32 cells, 0.000e+00).
- The same gains for every column (L0-L3, O(·), and any later column) and every segment.
- `tau_m` stays 30 ms nominal, sensitivity {17, 50, 72} ms as in PLANT_P2_SPEC.
- Declared in the paper: "Guo's attitude gains re-tuned for a motor with first-order
  lag (bandwidth parametrization, Gao 2003); position loop and observers otherwise as
  published", with the method, the criteria of §2.3 and the resulting numbers.

### 2.2 Method - bandwidth parametrization (Gao 2003)
Per axis i, with the nominal inertia `I_ii` (Ixx, Iyy, Izz of Guo Appendix A.1):
- `K_eta,ii = I_ii wc^2`, `K_omega,ii = 2 I_ii wc` (PD normalised by inertia, the
  closed loop without lag and disturbance is `(s + wc)^2`);
- ESO: `Ka1 = 3 wo`, `Ka2 = 3 wo^2`, `Ka3 = wo^3`, `wo = k wc` (the ESO polynomial
  `(s + wo)^3`, in the same angular-acceleration normalisation Guo's gains use).
- `k` is registered before tuning: **k = 3 (proposed; for the user to fix)**. The trial
  table (§2.8) also lists k = 2, 4, 5 for information only; they are not a menu to pick
  from after the fact.
- With these gains `I_ii` cancels from the linear loop (§2.3): one loop, one `wc` for all
  three axes. **Open point for the user:** apply the same `wc` to yaw as well (one
  method, one number), or keep Guo's yaw gains (yaw is not implicated by §1.6).

### 2.3 Linear model and criteria (the one design calculation, no simulation)
Per axis, small angle, loop broken at the actuator input (`tau_cmd -> tau_act`):
`P(s) = 1/(I s^2)`, actuator `A(s) = e^{-s Td}/(tau_m s + 1)` with **`Td` = 1 ms** for
the 1 kHz sampling (ZOH half-sample plus one half-sample for the sampler, rounded up),
ESO fed by `tau_cmd`, control law (18) with `eta_d = 0`. Then `u = -C(s) eta`,
`C(s) = [(K_eta + K_omega s) D(s) + Ka3 I s^2] / [s (s^2 + Ka1 s + Ka2)]`,
`D(s) = s^3 + Ka1 s^2 + Ka2 s + Ka3`, `L = C A P`. Implemented in `tools/att_margins.py`.
- **PM**: the smallest phase margin over all gain crossovers.
- **GM**: `L` has three integrators (phase -270 deg at low frequency), so the loop is
  conditionally stable; GM is the smaller of the gain-increase and gain-reduction
  margins over all phase crossovers.
- **Stability**: closed-loop roots with a 3rd-order Padé of `Td`.
- **Criteria**: `tau_m` = 30 ms: stable, PM ≥ 45 deg, GM ≥ 6 dB; `tau_m` = 72 ms: stable,
  PM ≥ 20 deg. **Choose the LARGEST `wc`** meeting all of them, on a 0.5 rad/s grid.

### 2.4 Time-scale separation
`wc ≥ 3 x` the bandwidth of the current position loop (Guo's `K_gamma` = 12, `K_nu` = 8
on x/y). Definition registered: **`sqrt(K_gamma)` = 3.46 rad/s** (the user's ~3.5 rad/s),
so **`wc ≥ 10.4 rad/s`**. For information, other common definitions of the same loop:
open-loop crossover 8.14 rad/s, closed-loop -3 dB 9.47 rad/s, closed-loop poles 2 and
6 rad/s (`tools/att_margins.py`).
**If no `wc` meets §2.3 and §2.4 together: STOP**, do not tune; propose a re-tune of the
position loop as a separate registration (user rule).

### 2.5 Checks after tuning (only if §2.3 and §2.4 are met)
- GĐ3 stage S4 on the 5 fixed segments (§1.3): D1 must show no physical divergence
  (§0.4 physical flag).
- The same S1 (no motor lag) runs with the new gains, next to the S1 runs of §1.6 with
  Guo's gains: how much the re-tune alone changes the result without a lag.
- `verify_repro`, `check_results_numbers`, `extract_eml --check`: v1 untouched.

### 2.6 Recorded fact carried over from §1.6
The algebraic loop appears only with the motor lag OFF (S1, and the compile check with
all GĐ3 switches OFF). The nominal P2 always has the lag, so nothing is changed for it.

### 2.7 Trial calculation (linear, no simulation; 2026-09-25, `tools/att_margins.py`)
Order, stated plainly: the table was computed in the same session just BEFORE the
commit of §2.1-2.6. The criteria of §2.3-2.4 are the user's, word for word, and were not
changed after it; the proposed k = 3 was written after seeing that k = 2 gives the
largest `wc` - which is why k stays the user's decision. The algebra was checked against
an independent state-space model built from the equations (same closed-loop roots to 4
decimals; loop gain scaled by GM_up or GM_dn puts a root on the imaginary axis).

**Guo's gains, Guo's ESO (50, 833, 3906), `Td` = 1 ms** (PM deg / GM dB; `-` = unstable):

| axis | 0 ms | 17 ms | 30 ms | 50 ms | 72 ms |
|---|---|---|---|---|---|
| roll  | 52.9 / 14.4 | 32.2 / 12.4 | 19.3 / 10.4 | 5.0 / 5.6 | unstable |
| pitch | 40.1 / 11.8 | 21.4 / 9.3 | 9.4 / 6.5 | unstable | unstable |
| yaw   | 47.1 / 12.1 | 35.9 / 11.1 | 27.9 / 10.3 | 17.4 / 8.7 | 8.2 / 6.4 |

Facts: (i) at the nominal 30 ms Guo's loop is linearly STABLE with a small margin
(pitch 9.4 deg), unstable from 50 ms (pitch) and 72 ms (roll); so the S2b divergence of
§1.6 is not a linear instability of the attitude loop on its own - low margin plus the
nonlinear effects the linear model leaves out (saturation, large angles, the payload).
(ii) Guo's own pitch loop does not meet PM ≥ 45 deg even with no lag (40.1 deg).

**Bandwidth parametrization** (every axis; largest `wc` meeting §2.3):

| k | largest `wc` [rad/s] | at that `wc`: 30 ms PM / GM, loop crossover | 72 ms PM | binding criterion |
|---|---|---|---|---|
| 2 | **3.0** | 46.8 / 15.3, 6.19 rad/s | 33.1 | 30 ms PM ≥ 45 |
| 3 | 2.0 | 45.3 / 15.7, 4.87 rad/s | 34.3 | 30 ms PM ≥ 45 |
| 4 | 1.5 | 45.4 / 16.4, 4.21 rad/s | 35.9 | 30 ms PM ≥ 45 |
| 5 | 1.0 | 47.2 / 17.1, 3.18 rad/s | 39.9 | 30 ms PM ≥ 45 |

At the separation bound `wc` = 10.4 rad/s the 30 ms PM is 24 deg (k = 2) to 10 deg
(k = 5), and the 72 ms loop is at or past the stability limit for every k.
**§2.3 and §2.4 cannot be met together (largest feasible `wc` 3.0 < 10.4): by §2.4, STOP -
no tuning.** For information only (not a proposal of this section): feeding the ESO the
torque through the nominal lag model - a structural change - raises the 30 ms PM at
`wc` = 10.5 to 32 deg (k = 2) / 29 deg (k = 3), still below 45.

## 3. Amendment A1 - nominal `tau_m` = 17 ms (user decision, 2026-09-25)

**Written AFTER D1 at 17 ms was seen** (GĐ3 diagnostic, §1.6.2: S4' stable 10/10) **and
BEFORE any D2 / CỔNG G block exists or runs.** Stated in the paper in these words.

- **Decision:** nominal motor lag `tau_m` = **17 ms** (was 30 ms, PLANT_P2_SPEC §2.4 / 4.2).
  Sensitivity set **{0, 25, 30} ms** (was {17, 50, 72}). 30 ms is reported as a
  **stress case where Guo's published gains fail**, a finding, not a hidden failure.
- **Reasons (the user's):** (i) Guo et al. 2020 flew their QDrone stably with the
  published gains; (ii) with those gains the linear analysis (§2.7) and GĐ3 Fixed5
  (§1.6.1-1.6.2) give divergence 10/10 at 30 ms and stability 10/10 at 17 ms, so the real
  lag of that platform lies in the stable range; 17 ms is a value with a literature
  source (PLANT_P2_SPEC §2.4, ~17 ms, 3-inch quadrotor) inside that range.
- **Declared weakness:** no published measurement of the lag of the 2206 motor / 6045
  propeller the platform uses; the literature range is 17-94 ms. The nominal value is
  therefore chosen from the stability of the published controller, not measured.
- **Consequence for §2 (attitude re-tune DRAFT):** not pursued - Guo's gains are kept
  unchanged for every column. §2 and its trial table stay in this file as the record of
  why 30 ms was not taken as nominal with re-tuned gains (§2.7: no `wc` met the criteria
  together with the separation).
- **Code:** `core/p2_params.m` default `tau_m` 0.030 → 0.017. v1 unaffected (P2 only).

### 3.1 Stage S4@25 (registered now, before it runs)
Stage `S4t25` of `run_gd3_stages`: motor lag 25 ms + discrete + sensors (= S4 at 25 ms),
Guo's gains, circle, K = 0.5, DoHarm [0 1], L2 and L3, the 5 fixed segments. Purpose:
where the stability boundary lies between 17 ms (stable 10/10) and 30 ms (diverged
10/10). Reported as §1.4, facts; no gate.

## 4. i0715 - tilt clamp hypothesis (registered 2026-09-25, before the check runs)

**Observation (§1.6.1-1.6.2):** on `i0715` the mean tracking error is 305-332 mm in EVERY
stable stage, S1 included, pendulum angle 46 deg; the other 4 segments 6-33 mm.
**Hypothesis (the user's):** the P2 envelope (§0.10) counts only static station-keeping
against the wind (tilt ≤ 0.8·30 deg, thrust ≤ 0.8·F_TOT_MAX) and leaves out the
trajectory's acceleration - the circle needs `R w^2` = 0.8·1.575^2 = 1.98 m/s², ~11.4 deg
of tilt on its own - so near U_max the commanded tilt hits the 30 deg clamp of
`thrust_attitude_ref` (per axis, `|phi_d|, |theta_d| ≤ 30 deg`).
A priori (no simulation, mean wind only, U ≈ 10.7 m/s, K = 0.5): static tilt 23.4 deg,
static + circle acceleration in phase 32.4 deg > 30 deg.

### 4.1 Check (a), measured on the logs
The saved `results/gd3/*.mat` hold summaries only (no `eta_log`), so (a) is a RE-RUN of
S1 and S4' on the 5 fixed segments with the logs kept - not an offline read. Per run:
- `tilt_ge` : fraction of time `max(|phi|, |theta|) ≥ TILT_MAX` (actual attitude, `eta_log`);
- `tilt_ge95`: the same with `≥ 0.95·TILT_MAX`;
- `tilt_sat`: fraction of time the COMMAND sits at the clamp, `max(|phi_d|, |theta_d|) ≥
  TILT_MAX - 1e-9` (`eta_d_log`, the reference after the clamp) - new summary field
  `p2.tilt_sat_frac`, logged in every P2 run from now on, next to the motor `sat_frac` (c).
All over the whole 200 s run. TILT_MAX = 30 deg.

**Reading, fixed now (thresholds proposed by Claude, before any number exists):**
hypothesis **confirmed** if on `i0715`, in S1 and S4' and both columns, `tilt_sat ≥ 0.01`
(the command sits at the clamp ≥ 1% of the time) **and** on each of the other 4 segments
`tilt_sat < 0.001`. Otherwise not confirmed, and the envelope is NOT amended (user rule).
`tilt_ge` and `tilt_ge95` are reported beside it, not scored.

### 4.2 If confirmed (NOT done before (a) is reported)
Amendment of the envelope before GĐ5, stated as found through GĐ3: required tilt
`atan((F_h + m_tot·a_traj_max)/W) ≤ 0.8·TILT_MAX`, thrust likewise, with `a_traj_max`
from each block's own trajectory (circle 1.98 m/s²; T3b, square, T5 computed from their
trajectories); the U_max table recomputed per trajectory.

### 4.3 Results of §3.1 and §4.1 (2026-09-25, facts)
Batch `run_gd3_stages('Fixed5', true, 'Stages', {'S1','S4p','S4t25'})` at `881c0c6` (model
`5638D01E…`, fingerprint `dfba208e…`), 15 calls, 10.3 min, saved
`results/gd3/gd3_20260925_132441.mat` (user's machine). S1 and S4' reproduce §1.6.2 to
every printed digit (error, T_min, theta_L max, saturation).

**§4.1 check (a) - tilt clamp, whole 200 s run:**

| seg (U m/s) | S1 L2 | S1 L3 | S4' L2 | S4' L3 |
|---|---|---|---|---|
| | tilt_sat / tilt_ge / tilt_ge95 | | | |
| i0000 (3.83) | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| i0319 (7.46) | 0 / 0 / 0 | 0 / 0 / 0 | 0.0001 / 0 / 0 | 0 / 0 / 0 |
| i0453 (6.56) | 0 / 0 / 0 | 0 / 0 / 0 | 0.0001 / 0 / 0 | 0 / 0 / 0 |
| **i0715 (10.67)** | **0.3245** / 0.1779 / 0.3699 | **0.3086** / 0.1684 / 0.3534 | **0.3371** / 0.1729 / 0.3719 | **0.3214** / 0.1655 / 0.3566 |
| i0900 (6.11) | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |

(4 decimals as printed; U from REGISTER_ROBUST §18.6.)
**Reading of §4.1 applied: CONFIRMED.** On `i0715` the command sits at the 30 deg clamp
31-34% of the time in S1 and S4', both columns (≥ 0.01); on the other 4 segments
`tilt_sat` ≤ 0.0001 (< 0.001). The actual attitude is at or beyond 30 deg 17-18% of the
time and beyond 28.5 deg 35-37%. The a-priori figure (static 23.4 deg + circle
acceleration in phase → 32.4 deg, §4) is consistent with this. §4.2 (envelope amendment)
is now open.

**§3.1 S4@25 (25 ms + discrete + sensors): diverged 10/10.**

| seg | stop L2 / L3 [s] | block L2 / L3 |
|---|---|---|
| i0000 | 15.013 / 7.774 | Int_etadot / Int_etadot |
| i0319 | 15.322 / 13.706 | Int_etadot / Int_za |
| i0453 | 33.231 / 16.640 | Int_za / Int_etadot |
| i0715 | 79.824 / 119.137 | Int_etadot / Int_za |
| i0900 | 31.849 / 23.005 | Int_etadot / Int_etadot |

Pendulum angle max 129-179 deg and T_min < 0 before every stop. With Guo's gains the
full P2 is stable 10/10 at 17 ms and diverges 10/10 at 25 ms and at 30 ms: the boundary
lies between 17 and 25 ms. (Tilt fractions of diverged runs cover the tumble before the
stop and are not read.)

### 4.4 Amendment A2 - envelope with the trajectory's acceleration (APPROVED by the user 2026-09-25, see §5.1)
Found through GĐ3 (§4.3), written before GĐ5 and before any CỔNG G / D2 number exists.
Replaces the static condition of §0.10 for every block:

    tilt   = atan((F_h(U) + m_tot a_traj_max) / W)        ≤ 0.8 · 30 deg
    thrust = sqrt((F_h(U) + m_tot a_traj_max)^2 + W^2)    ≤ 0.8 · F_TOT_MAX
    F_h(U) = K_w U^2/U_ref (1 + K),  m_tot = m_Q + m_p,  W = m_tot g

Worst case: the trajectory's horizontal acceleration taken in phase with the mean wind
force; all trajectories fly at constant altitude. The combined tilt is compared with the
per-axis clamp (conservative). `a_traj_max` = largest horizontal reference acceleration
of `simulink_blocks/trajectory_ref.m` with the parameters of `core/op_set.m` over the
200 s run (1 ms grid): circle 1.9845 m/s² (= R w², exact); T3b 1.4892; square 2.0000
(min-jerk peak `10/sqrt(3) D/T^2`); T5 multisine 1.8299 (over 0-200 s; the two-axis
bound is 2.33); hover 0. Tool: `python3 python/p2_envelope.py --traj`.

**U_max [m/s], nominal plant (tilt binds in every cell):**

| trajectory | a_max | K 0 / m_p 0.5 | K 0.5 / m_p 0.5 | K 1.0 / m_p 0.5 |
|---|---|---|---|---|
| hover (= §0.10, static) | 0 | 13.30 | 10.86 | 9.41 |
| **circle** | 1.984 | **9.83** | **8.02** | **6.95** |
| T3b | 1.489 | 10.80 | 8.82 | 7.64 |
| square | 2.000 | 9.80 | 8.00 | 6.93 |
| T5 | 1.830 | 10.14 | 8.28 | 7.17 |

(m_p 0.25 / 0.65 columns: printed by the tool.)

**Consequences for §0.8 (facts of the arithmetic, for the user's decision):**
- `i0715` (U 10.67) is outside the circle envelope at K 0.5 (8.02); the other 4 fixed
  segments (U 3.83-7.46) stay inside.
- `N5-B-Medium` (K 0.5): in effect 6-10.86 → **6-8.02 m/s**.
- `N4b-P2-K10` (K 1.0): `U ≤ 9.41` → **`U ≤ 6.95`**.
- `N5-A-Medium` (K 0): 6-12 → **6-9.83 m/s**.
- **`N5-A-Strong` (K 0, U > 12) becomes EMPTY** (U_max 9.83 < 12): the group is known in
  advance to be "not evaluable" under A2 - it can no longer contribute to CỔNG G.
- Weak groups unchanged (U < 6 < every circle U_max).
- The per-run clamp fraction `p2.tilt_sat_frac` (§4.1 (c)) stays logged beside the
  envelope as a measured check of it.

## 5. Amendments A2 (approved), A3 (two groups), A4 (fixed segments) - 2026-09-25, before any number of GĐ5-GĐ7

### 5.1 A2 approved (user)
§4.4 applies to **every** group and block from now on. Added reason for the in-phase
worst case (the user's): on the circle the centripetal acceleration sweeps 360 deg every
orbit (T = 4.0 s) while the mean wind direction is nearly fixed over a segment, so the
in-phase alignment happens **every orbit**, not as a rare extreme; square and T5 also
sweep many directions. Comparing the combined tilt with the per-axis clamp is
conservative (safe side).
**N5-A-Strong** (K 0, U > 12) is recorded as **"empty - limited by the UAV's capability"**
(circle U_max 9.83 m/s at K 0): a physical fact, reported in the paper, not a gap in data.

### 5.2 A3 - two new CỔNG G groups ("relatively strong" wind)
Definition: **relatively strong = 80-100% of the trajectory's own U_max** (A2, K 0, m_p 0.5).
Written before any number of either group exists. Common settings as §0.8.

| # | group | trajectory | K | U range [m/s] | set |
|---|---|---|---|---|---|
| 11 | `N5-A-StrongRel` | circle | 0 | [0.8·9.83, 9.83] = **[7.86, 9.83]** | P2 dev set ∩ range |
| 12 | `N5-H-StrongRel` | **hover** (station-keeping in strong wind) | 0 | [0.8·13.30, 13.30] = **[10.64, 13.30]** | P2 dev set ∩ range |

- The data-sufficiency rule (§0.6, ≥ 15 segments and ≥ 6 days) applies to each.
- `N5-A-StrongRel` may share segments with `N5-A-Medium` (6-9.83): the groups are not
  disjoint; each is scored on its own set and both are reported.
- `N5-H-StrongRel` needs the payload τ\* measured on P2 **for hover** (τ rule,
  REGISTER_ROBUST §19.4): added to GĐ6.
- The family grows from ~10 to 12 listed groups; §0.6 "Multiple comparisons" updated.

### 5.3 A4 - the fixed 5 segments on P2 (replacement rule, before N0P/N0W on P2)
`i0715` (U 10.67) is outside the A2 circle envelope at K 0.5 (8.02). Rule for every P2
block that uses "the 5 fixed segments" (N0P, N0W, ...): **the §18.3 rule of
REGISTER_ROBUST unchanged - the first T.stable segment of each of 5 stable days at ranks
`round(linspace(1, n, 5))`, in T's own row order, from `field_grid_K050.mat` - applied
AFTER filtering `T.stable` by the A2 circle envelope at K 0.5 (`T.U ≤ U_max` = 8.02 m/s);
`n` = the number of days that still have such a segment.** Computed by
`core/p2_fixed5.m`, printed with the reason for every change; nobody picks by hand.
With the filter off it must return the §18.6 list exactly (built-in check). The GĐ3
results on the old 5 segments stay as they are (diagnostic).

### 5.4 Exploration data (GĐ0-data)
The 32 exploration days (`plan_real_download.py --split dev --all-days --exclude-used`,
`65 -> 32 days`, 128 files; 0 overlap with CONFIRM2 / CONFIRM / used days, checked by
count) were downloaded on 2026-09-25 in the cloud session (128/128 files, 336 MB, 0
errors) and must also be on the user's machine, **in a directory of their own**: the
`iNNNN` index is a position in the sorted file list of the raw directory, so mixing the
new days into the old dev directory would shift every existing index.
**Preview only (not a registered count):** the repository's own pipeline
(`segments()`, heights 61/74 m, 200 s, QC) gives 441 segments / 32 days; with U = |mean
horizontal wind| over t ≥ 20 s (differs from `T.U` by up to 0.6 m/s): `N5-H-StrongRel`
18 segments / 6 days, `N5-A-StrongRel` 68 / 11, `N5-B-Medium` 60 / 17, `N5-A-Medium`
128 / 19 - from the exploration days alone, before the old dev set is added. The
registered counts come from GĐ5's export with `T.U`.

#### 5.3.1 A4 list, printed by `p2_fixed5()` on the user's machine (2026-09-25)
`T.stable AND T.U ≤ 8.02 m/s` leaves **13 stable days**; ranks `[1 4 7 10 13]`:

| segment | day | U [m/s] | theta [deg] |
|---|---|---|---|
| `wind_real_t150_i0000.mat` | 2024-01-09 | 3.83 | 4.47 |
| `wind_real_t150_i0251.mat` | 2024-02-08 | 6.70 | 7.83 |
| `wind_real_t150_i0453.mat` | 2024-02-29 | 6.56 | 7.67 |
| `wind_real_t150_i0705.mat` | 2024-04-29 | 5.05 | 5.90 |
| `wind_real_t150_i0900.mat` | 2024-05-21 | 6.11 | 7.14 |

Replaced from REGISTER_ROBUST §18.6: `i0715` (U 10.67 > 8.02, outside the A2 circle
envelope); `i0319` (inside the envelope - the day ranks moved because other days lost all
their in-envelope segments, 15 → 13 days). Built-in check passed (the unfiltered rule
still returns the §18.6 list). **This is THE fixed-5 list for every P2 block** (N0P,
N0W, ...); GĐ3's results on the old list stay as diagnostics.

## 6. GĐ5 - protocol for every P2 block (DRAFT 2026-09-25, awaiting "APPROVED")

Written before any GĐ6-GĐ8 number exists. It fixes the data, the sets, τ and the report
format; the gate thresholds D2-D4 are in §0 and are **not** changed here.

### 6.1 The P2 dev set
- **field_grid part:** the 30 segments of `field_grid_K050.mat` (`T.file`,
  `wind_real_t150_i*.mat`), as exported for v1. No v1 `T.stable` flag is used on P2: the
  A2 envelope replaces it.
- **exploration part:** **every** segment through QC of the 32 exploration days (§5.4),
  exported in one go by
  `python python/export_wind_sim.py --real-dir <exploration dir> --real-split dev --real-max 10000 --ckpt w4_frozen_20hz_t150_train2345_s0 --out wind_expl_t150.mat`
  → `wind_expl_t150_i0000.mat … i0440.mat` + `wind_expl_t150_batch.json`. Own name, own
  directory: the old `wind_real_t150_iNNNN` indices are untouched. Done once in the cloud
  session (2026-09-25): **441 segments, 29 days** (3 of the 32 days have no segment through
  QC), U 2.07-25.96 m/s. File list SHA-256 `2bcdc4b54568e4b5…42dd42e33`; exploration
  fingerprint (sorted `file U day` lines, U to 1e-9) **`73749ad2a7cdf7b25774d8fbd348325d5964015c1f3465889297a84e668d210b`**
  (Python and Octave agree). The export on the user's machine must print the same
  fingerprint (`p2_segset`), else nothing runs.
- Never in the dev set: CONFIRM2 (locked until GĐ10), the old confirm set.
- **U** of a segment = `norm(mean(w_plant(t ≥ 140 s, 1:2)))` read from the segment file (=
  `T.U`; checked against `T.U` for the 30 field_grid segments to 1e-9). **Day** from
  `real_file`. `p2_segset` asserts that no exploration day is a field_grid day.

### 6.2 Sets: one per table and per CỔNG G group - `core/p2_segset.m` (X-segset)
Every P2 block reads its segments **only** through `p2_segset(name)`; the list is fixed
by `p2_segset('all', 'Save', true)` and its SHA-256 per set is written into this file
before the first block runs; a runner asserts the hash. A set = dev segments inside the
A2 envelope of its own (trajectory, K, m_p 0.5) and its U range:

| set | trajectory | K | U range (∩ U ≤ U_max) | used by |
|---|---|---|---|---|
| `circle_main` | circle | 0.5 | ≤ 8.02 | D2 main table; N4b-P2-base, -d200, -L15 |
| `T3b_main` / `square_main` / `T5_main` | T3b / square / T5 | 0.5 | ≤ 8.82 / 8.00 / 8.28 | one table per trajectory (GĐ6/GĐ8 blocks) |
| `N5-A-Weak` / `N5-B-Weak` | circle | 0 / 0.5 | U < 6 | CỔNG G #1 / #4 |
| `N5-A-Medium` / `N5-B-Medium` | circle | 0 / 0.5 | 6 ≤ U ≤ 9.83 / 8.02 | #2 / #5 |
| `N5-A-Strong` | circle | 0 | U > 12 → empty | #3 (A2: empty by capability) |
| `N4b-P2-K10` | circle | 1.0 | ≤ 6.95 | #9 |
| `N5-A-StrongRel` | circle | 0 | 7.86-9.83 | #11 (A3) |
| `N5-H-StrongRel` | hover | 0 | 10.64-13.30 | #12 (A3) |

Each table pools **one** set (pool_rule L2, §0.2): a segment flagged (§0.4) in any
column leaves every column of that table.

#### 6.2.1 Full P2 dev set, printed on the user's machine (2026-09-25, uncapped)
`p2_segset('all', 'Save', true)` at `67d7c38`: **30 field_grid + 441 exploration segments,
46 days**; U from the files vs `T.U` max difference **0.0**; exploration fingerprint
**`73749ad2…8d210b` = §6.1** (the user's export is the cloud export). Saved
`results/gd5/segsets_20260925_142457.mat` (user's machine).

| set | U range | n_seg | n_days | enough |
|---|---|---|---|---|
| `circle_main` | ≤ 8.02 | 340 | 42 | yes |
| `T3b_main` | ≤ 8.82 | 364 | 42 | yes |
| `square_main` | ≤ 8.00 | 340 | 42 | yes |
| `T5_main` | ≤ 8.28 | 351 | 42 | yes |
| `N5-A-Weak` | < 6 | 268 | 38 | yes |
| `N5-A-Medium` | 6-9.83 | 138 | 26 | yes |
| `N5-A-Strong` | > 12 | 0 | 0 | empty (A2) |
| `N5-B-Weak` | < 6 | 268 | 38 | yes |
| `N5-B-Medium` | 6-8.02 | 72 | 22 | yes |
| `N4b-P2-K10` | ≤ 6.95 | 313 | 42 | yes |
| `N5-A-StrongRel` | 7.86-9.83 | 67 | 13 | yes |
| `N5-H-StrongRel` | 10.64-13.30 | 31 | 11 | yes |

Every non-empty set meets the data-sufficiency rule. The per-set SHA-256 are recorded here
once the per-day cap (§6.3) is decided, from the run with that cap.

### 6.3 Segments per day - DECISION NEEDED
Exploration days carry up to 24 segments each (4 hours × 3 offsets × 2 heights), so the
pooled number is weighted towards the days with many in-range segments, and cost grows
with them. Counts on the **exploration part** (exact U; the field_grid part adds ≤ 30 per
set and is printed by `p2_segset` on the user's machine):

| set | all | cap 4 / day | cap 3 / day |
|---|---|---|---|
| `circle_main` | 320 / 29 d | 114 / 29 | 86 / 29 |
| `T3b_main` / `square_main` / `T5_main` | 344 / 320 / 331 | 114 each | 86 each |
| `N5-A-Weak` = `N5-B-Weak` | 255 / 29 | 109 / 29 | 84 / 29 |
| `N5-A-Medium` | 130 / 18 | 65 / 18 | 51 / 18 |
| `N5-B-Medium` | 65 / 15 | 49 / 15 | 40 / 15 |
| `N4b-P2-K10` | 294 / 29 | 113 / 29 | 86 / 29 |
| `N5-A-StrongRel` | 66 / 12 | 41 / 12 | 32 / 12 |
| `N5-H-StrongRel` | 28 / 8 | 20 / 8 | 17 / 8 |
| `N5-A-Strong` | 0 | 0 | 0 |

Every non-empty group passes the data-sufficiency rule (≥ 15 segments, ≥ 6 days) with or
without a cap. Cost of CỔNG G alone (5 columns ≈ 125 s per segment, measured GĐ3 rate):
**~71 h uncapped, ~29 h at cap 4, ~23 h at cap 3**. Cap rule if chosen: within a day, `c`
segments evenly spaced in the pool's own order (file → height → offset,
`round(linspace(1, n_day, c))`); no wind or result statistic.
**Proposal: cap 4 per day per set** (day balance; ~4 nights; every group stays sufficient).

#### 6.3.1 Decision (user, 2026-09-25): **cap 4 segments per day per set** - the exact rule
For one set: (1) membership = the dev segments inside the set's registered U range and A2
envelope (§6.2) - this is the only place U enters; (2) the members are kept in the dev
pool's own order: field_grid segments in `T`'s row order, then exploration segments by
export index (`wind_expl_t150_iNNNN`: M5 file (date, hour) → height → offset), which is a
fixed schedule, not a measurement; (3) for each day with `n > 4` members, keep positions
`round(linspace(1, n, 4))` of that day's members in that order; days with `n ≤ 4` keep all.
The choice among a day's members uses **no U value, no wind statistic, no tracking error,
no result** - only positions. (Membership itself is U-defined by design, so the 4 picked
on a day depend on which of that day's segments are in the set's range, never on how the
controller did.) Code: `cap_per_day` in `core/p2_segset.m`.
Lowest count at cap 4 (user's run): `N5-H-StrongRel` 23 segments / 11 days - every
non-empty set meets the data-sufficiency rule.
**Identical sets, noted:** `circle_main` = `square_main` (U_max 8.024 vs 7.998; no dev
segment has U in between - 0 in the exploration part, and the uncapped counts are equal,
340 = 340), so they carry the same SHA-256; `N5-A-Weak` = `N5-B-Weak` (below 6 m/s the
envelope cuts nothing at K 0 or 0.5).
**Per-set lists at cap 4, fixed (user's run 2026-09-25, `results/gd5/segsets_20260925_143232.mat`;
exploration fingerprint = §6.1; U vs `T.U` 0.0).** SHA-256 of the sorted file list, first
16 hex (the full value is in the saved file; runners check this prefix):

| set | n_seg | n_days | SHA-256 (16) |
|---|---|---|---|
| `circle_main` | 134 | 42 | `a227e9d87a2ac436` |
| `T3b_main` | 134 | 42 | `35bed7710bf224ee` |
| `square_main` | 134 | 42 | `a227e9d87a2ac436` (= circle_main) |
| `T5_main` | 134 | 42 | `4a933e516acfcb10` |
| `N5-A-Weak` | 122 | 38 | `a051c6fdcf0a6be2` |
| `N5-A-Medium` | 73 | 26 | `309278f9eb484c58` |
| `N5-A-Strong` | 0 | 0 | `e3b0c44298fc1c14` (empty list) |
| `N5-B-Weak` | 122 | 38 | `a051c6fdcf0a6be2` (= N5-A-Weak) |
| `N5-B-Medium` | 56 | 22 | `dd710794f4786481` |
| `N4b-P2-K10` | 132 | 42 | `03fae8f8a845cb5b` |
| `N5-A-StrongRel` | 42 | 13 | `f8479cc53cb0d8a0` |
| `N5-H-StrongRel` | 23 | 11 | `7b105836187d9f25` |

The two equalities noted above are confirmed by identical hashes. `T3b_main` and `T5_main`
also have 134 segments but other members (larger U_max), hence other hashes.

### 6.4 One table per trajectory
circle (D2, `circle_main`), T3b, square, T5, hover (N5-H-StrongRel): each pooled on its
own set, never merged across trajectories. Columns per block are registered with the
block (GĐ6-GĐ8), not here.

### 6.5 τ rule (REGISTER_ROBUST §19.4, carried to P2)
- **Known in advance** (the planned trajectory, the tether length L) → payload τ\* is
  **measured on P2** by the N0P procedure on the A4 fixed-5 (§5.3.1) and shared by every
  IM column: circle, T3b, square, **hover** (A3), and circle at L 1.5 (N4b-P2-L15).
- **Not known** to the controller (ζ_s, sensor delay, K, wind intensity) → τ stays at the
  nominal of the condition it perturbs (the P2 τ\* of that trajectory at nominal settings).
- **T5 ("unplanned"): decided (user, 2026-09-25) - (b):** measured once on P2 by N0P and
  used as T5's nominal (v1's 140 ms was measured on the v1 plant).
- Wind horizon τ_w\*: N0W, §0.3.1, on the A4 fixed-5.

### 6.6 Report format (unchanged, §0.2)
Every number: pooled `sqrt(mean(m_i²))` + `SE_pool` (paired delete-one-day jackknife) +
by-day median + LOO `[min, max]` + most influential segment; flagged segments listed with
the two flags separately; `tilt_sat_frac` and motor `sat_frac` reported per table.

### 6.7 Before GĐ6
1. User's machine: the export of §6.1 → `p2_segset('all', 'Save', true)` prints the
   exploration fingerprint (must equal §6.1) and the full counts incl. field_grid.
2. The per-set SHA-256 go into §6.2 (commit), then "APPROVED" on §6.

**§6 APPROVED by the user (in chat, 2026-09-25): "tôi APPROVED §6 rồi chạy", after the cap-4 rule
(§6.3.1) was confirmed as independent of wind and results.**

## 7. GĐ6 - night plan (registered 2026-09-25, before any GĐ6 run)

Runner `experiments/run_p2_gd6.m`; every call goes through `pa_configs` with the nominal
P2 (`PlantModel 'p2'`, `tau_m` 17 ms, discrete, sensors, wind-sensor delay 50 ms),
circle `Test 4` settings otherwise, `PayloadModel 1`, K 0.5, L 1.0, `OnDiverge 'flag'`.
Estimated at **50 s per simulated column-run** (the user's figure; GĐ3 measured ~25 s per
column when two share one call).

### 7.1 Night 1 - N0P on P2 (payload τ\*) + the preview τ for V
- Segments: the A4 fixed-5 (`p2_fixed5`, §5.3.1).
- Conditions (L 1.0), in this order: **circle, hover, T3b, square, T5**. Internal model per
  condition = the exact-frequency table `im_oracle_axis` (circle {0, w} = `DoHarm [0 1]`,
  the D2 table's own IM; hover {0, wn_p}; T3b {0, w}/{0, 2w}; square/T5 their own sets).
- Procedure = REGISTER_ROBUST sec 12 N0P, unchanged: column L3 (`g_psens`), coarse
  `TauPred` 0:20:400 ms, one bounded edge extension (+3 points), fine ±20 ms at 10 ms;
  τ\* = the fine minimum; an edge minimum is flagged EDGE-UNRESOLVED and not used; τ = 0
  is a physical floor, not an edge. Per (τ, segment) values saved (fixed-set recomputation).
- **N0V (circle only)**: the same procedure on column V's own configuration (`g_sens`,
  `TauPrev` swept, `TauPred` irrelevant) → τ_prev\* for V on P2. (v1's 0.12 s was measured
  on the v1 plant.)
- Runs: 5 × (21 + 5) × 5 = 650 (N0P) + 130 (N0V) = **780 runs ≈ 10.8 h** at 50 s
  (≈ 5.4 h at 25 s). Resumable per condition; circle and N0V first (D2 needs them).
- **Before night 2:** τ\* (circle) and τ_prev\* are transcribed into this section and
  committed; the D2 runner takes them as explicit arguments (never read from a file).

### 7.2 Night 2 - D2 main table, first pass
- Set: `p2_segset('circle_main', 'CapPerDay', 4)`; the runner asserts its SHA-256 against
  §6.3.1.
- Columns now: **L0** (Guo MOBADC, `g_base`, `DoHarm 1`), **L2** (`g_sens`), **L3**
  (`g_psens`, `TauPred` = τ\*_circle,P2), **V** (`g_sens`, `TauPrev` = τ_prev\*); L2/L3/V at
  `DoHarm [0 1]`. Later nights: L1, F2, P, O, VP on the same set (the one-set rule of §0.2
  is applied over the columns of the final table; a segment flagged in a later column is
  removed from the earlier columns' pool as well, and both versions are reported).
- **D2 (§0.5) is scored on L2 and L3 only**, on the set common to the columns run so far.
- Runs: 134 × 4 = 536 ≈ **7.4 h** at 50 s (≈ 3.7 h at 25 s).
- Per segment saved: mean error per column, crash/diverged, P2 flags (physical divergence,
  numerical flag), T_min, motor `sat_frac`, `tilt_sat_frac`.

### 7.3 Dry-run (2026-09-25, git `76a2836`/`e73645f`, 1 segment `i0000`, TauPred 0 and 200 ms) - facts
- circle, T3b, square (N0P), circle (N0V) and the D2 path run: 25-31 s per column-run;
  D2 101 s per segment (3 calls, 4 columns). D2 on this one segment with v1's τ (0.22 /
  0.12 s, dry run only): L0 0.0414, L2 0.0334, L3 0.0152, V 0.0152 - not a result.
- **hover and T5 diverge physically on the nominal P2 (τ_m 17 ms), both τ values:**
  hover - solver stop `Attitude_Observer/Int_za` at t = 11.833 s (TauPred 0) and 9.856 s
  (200 ms); T5 - `UAV_Plant/Int_etadot` at t = 26.786 s (0) and 7.381 s (200 ms). Same
  blocks as the GĐ3 divergences (§1.6).
- Relevance to D1 (§0.4): "hover with payload" and "T5 with payload" are among D1's
  registered hard cases; GĐ3 ran only the circle cases, so D1 is **not complete**: on the
  first hard cases tried with every P2 component on, physical divergence occurs.
- Recorded, not interpreted. Night 1 runs circle, N0V, T3b, square only; hover and T5 wait
  for the user's decision.

## 8. D1 / GĐ4 - the P2 initial condition is an implementation error, fixed; hover/T5 diagnostic (registered 2026-09-25, before the fix and before the run)

**What it is (the user's words): an IMPLEMENTATION-ERROR FIX, not a change to make runs
pass.** Every P2 run started from the CIRCLE's initial state - plant `P2_x`, mocap delay
and velocity-difference ICs, DO `Int_z` and ESO `Int_zp` ICs all hard-code
`[R_traj; 0; z0]`, `[0; R_traj w_traj; 0]` (inherited from v1's `Int_gamma`/`Int_nu`).
For hover that means starting 0.8 m and 1.26 m/s away from the reference, which is not
how a real mission starts.

### 8.1 Standard initial condition (every trajectory, plant P2 only)
- UAV: `x0 = gamma_d(0)`, `v0 = nu_d(0)` from `simulink_blocks/trajectory_ref.m` of the
  condition's own `traj_type/traj_par` (tau_prev plays no role at t = 0 for gamma_d/nu_d).
- Payload hanging at equilibrium: `q = -e3`, `omega = 0`. Motors, DO/ESO hover trim: as
  before (GD2B_DESIGN sec 3).
- Observers and sensors start from the same state (DO `-l_gain [x0; v0]` + trim, ESO
  `[x0; v0; 0]` + trim, mocap delay line `x0`, previous position `x0 - v0 Ts_pos`).
- **Circle: `gamma_d(0) = [R; 0; z0]`, `nu_d(0) = [0; R w; 0]` - the same numbers as
  before** (sign of zero normalised). Check after the rebuild: circle results must
  reproduce **to every printed digit** (GĐ3 S4' on `i0000`: 33.37 / 15.24 mm; the dry-run
  N0P circle `i0000`: 0.0334 at 0 ms, 0.0163 at 200 ms; D2 dry-run `i0000`: L0 0.0414,
  L2 0.0334, L3 0.0152, V 0.0152) and B1 (v1 bit-exact) must pass.
- From the rebuild on it applies to **every** P2 block (N0P T3b/square included: the
  dry-run's T3b/square numbers, taken with the circle IC, are superseded).
- v1 (`plant_model = 0`) keeps its IC expressions verbatim.

#### 8.1.1 Rebuild with the standard IC (2026-09-25, facts)
`build_p2_plant('Save', true)` at `863c756`: `Int_z` / `Int_zp` ICs now
`p2_ic_do(..., p2_ic_pos, p2_ic_vel)` / `p2_ic_eso(..., p2_ic_pos, p2_ic_vel)`; compile
check `plant_model` 0 / 1 / 1 all-OFF / 0 clean, no algebraic loop; fingerprint
`b0cca7bde8418f064a8a99200ce639382117f8f79d9340436f0dfaeb0b30f648`. **B1:** `verify_repro`
32 cells, largest difference 0.000e+00, REPRODUCED; `check_results_numbers` 146/146;
`extract_eml` Match 25 / Differ 0; `check_all` 9/1, the one failure the SNAPSHOT MD5 of
the new `baseline1.slx` (`ACE1FAF315D67198…`, 158 540 bytes - SNAPSHOT is updated from the
pushed file). The circle check of §8.1 is still to run.

### 8.2 The one diagnostic round (hover, T5)
hover and T5, A4 fixed-5, columns L2 and L3, TauPred 0 and 200 ms (as the dry-run), nominal
P2 (τ_m 17 ms) with the standard IC: 2 × 5 × 2 calls (2 columns each). Reported per run:
stable (200 s) / diverged, stop time and block, T_min, `tilt_sat_frac`, motor `sat_frac`.
**Reading, fixed now:** per condition, **no divergence in all 5 segments** (both τ, both
columns) → the cause was the start-up (the IC error); the standard IC stays for every
block and the condition goes into GĐ6. **Any divergence** → steady-state instability of
Guo's gains on P2 for that condition → direction 2: reported as a finding (limit of Guo's
gains on P2), and the dependent items leave GĐ6 (hover → `N5-H-StrongRel`; T5 → the T5
table and T5's τ).

### 8.3 D1 is NOT complete
hover-with-payload and T5-with-payload are registered D1 hard cases (§0.4); GĐ3 ran only
circle cases. This round is the missing part of D1 for those two cases.

## 9. Results of the 2026-09-25 batch (`gd6_tonight`, git `017498e`/local `593f2ea`, 4.1 h) - facts

Log `results/gd6/tonight_20260925_175126.txt` (user's machine).
- **Rebuild + B1:** fingerprint `b0cca7bd…` (same as §8.1.1); `verify_repro` 32 cells, 0.000e+00;
  146/146; extract_eml 25/0. The rebuild re-saved `baseline1.slx` (local commit `593f2ea`);
  its push was rejected (remote ahead) - to be pushed by hand, SNAPSHOT updated after.
- **§8.1 circle unchanged - every printed digit OK:** GĐ3 S4' `i0000` 33.37 / 15.24 mm; N0P
  circle dry-run 0.0334 / 0.0163; D2 dry-run L0 0.0414, L2 0.0334, L3 0.0152, V 0.0152.
  The Simulink warning "slprj/…/simulink_cache.xml is not a valid Simulink cache info
  file" (a cache file corrupted by a power cut) was printed during the batch; it does not
  touch any number (circle reproduced to the digit) and `slprj/` is cleared from now on.

### 9.1 §8.2 diagnostic (hover, T5; A4 fixed-5; L2/L3; TauPred 0 and 200 ms; standard IC)
**No divergence in any of the 40 runs** (20 hover, 20 T5); T_min 4.36-4.74 N; motor
saturation 0.000. Mean error [m], L2 / L3:

| seg | hover τ 0 | hover τ 200 | T5 τ 0 | T5 τ 200 |
|---|---|---|---|---|
| i0000 | 0.0089 / 0.0089 | 0.0089 / 0.0091 | 0.0212 / 0.0212 | 0.0212 / 0.0135 |
| i0251 | 0.0344 / 0.0344 | 0.0344 / 0.0352 | 0.0454 / 0.0454 | 0.0454 / 0.0377 |
| i0453 | 0.0078 / 0.0078 | 0.0078 / 0.0079 | 0.0189 / 0.0189 | 0.0189 / 0.0101 |
| i0705 | 0.0128 / 0.0128 | 0.0128 / 0.0131 | 0.0242 / 0.0242 | 0.0242 / 0.0145 |
| i0900 | 0.0018 / 0.0018 | 0.0018 / 0.0018 | 0.0177 / 0.0177 | 0.0177 / 0.0088 |

**Reading §8.2 applied:** hover and T5 - no divergence in all 5 segments, both τ, both
columns → **the dry-run divergence was the start-up (the IC implementation error); the
standard IC stays for every block; hover and T5 enter GĐ6.** For D1 (§0.4, §8.3): the
hard cases hover-with-payload and T5-with-payload show no physical divergence on the
full P2; the remaining registered hard cases (T5 L 1.5, largest m_p, v1 X-esoatt cases)
have not been run, so D1 is still not complete.
Also recorded (fact, not read): on `i0251` (U 6.70 m/s) the tilt command sits at the 30 deg
clamp 23 % of the time in hover and 25 % in T5 (`tilt_sat` 0.2324-0.2545); 0 on the other
4 segments. `i0251` is inside every A2 envelope.

### 9.2 Night 1 - τ\* on P2 (A4 fixed-5, pooled over 5/5 segments at every τ, no edge)
| run | condition | coarse min | **τ\*** | pooled at τ\* | pooled at 0 |
|---|---|---|---|---|---|
| N0P | circle (L3, DoHarm [0 1]) | 300 ms | **290 ms** | 0.0228 | 0.0406 |
| N0V | circle (V, TauPrev) | 180 ms | **180 ms** | 0.0204 | 0.0406 |
| N0P | T3b | 340 ms | **340 ms** | 0.0191 | 0.0271 |
| N0P | square | 120 ms | **120 ms** | 0.0225 | 0.0273 |

The circle and T3b curves are flat near the minimum (circle 0.0228 at 280-310 ms; T3b
0.0191 at 320-360 ms, to 4 decimals); the argmin is taken on the unrounded values as the
procedure fixes. v1 circle used 0.22 s (published) and v1 preview 0.12 s; on P2 (τ_m 17 ms,
discrete, sensors) the measured values are larger.

**Transcribed for night 2 (§7.2):** D2 `TauPred` = **0.290 s**, `TauPrev` = **0.180 s**,
set `circle_main` cap 4, SHA `a227e9d87a2ac436`. Still to measure: hover and T5 τ\*
(N0P), now that both enter GĐ6.

## 10. Registered 2026-09-25, before night 2's D2 report and before the i0251 run

### 10.1 D2 - secondary tilt-clamp report (the D2 gate is unchanged, §0.5)
With the D2 table: `tilt_sat_frac` (command at the 30 deg clamp, whole run) **per segment
for each of the 4 columns** (L0, L2, L3, V); a segment is **flagged** if any column has
`tilt_sat_frac > 0.01`; and, as a secondary number only, Δ = L3/L2 − 1 (with LOO) on the
one set **minus the flagged segments**. The D2 verdict is taken on the registered set as
before; the secondary number never replaces it. Code: `run_p2_gd6` D2 report
(`run_p2_gd6('D2REPORT')` re-prints it from `results/gd6/d2_p2.mat`).

### 10.2 i0251 - tilt clamp diagnostic (one round)
Question: why does the tilt command sit at the 30 deg clamp 23-25 % of the time on `i0251`
(U 6.70 m/s, inside every A2 envelope) in hover and T5 (§9.1)?
- Runs: **hover**, columns L2 and L3, TauPred = τ\*_hover from night 2's N0P (passed
  explicitly), `eta_log` kept; segments **`i0251`** and **`i0000`** (light wind, for
  comparison); each with the **real wind** and with **wind = 0** (`WindZero`: airframe,
  payload and controller wind inputs all zero). 2 × 2 calls, 2 columns each.
- Reported per run: `tilt_sat_frac` (whole run and t ≥ 140 s), actual tilt ≥ 30 deg
  fraction, and in the window **t ≥ 140 s** the roll/pitch oscillation about its mean:
  peak amplitude and RMS [deg], dominant frequency [Hz] (FFT peak, DC excluded).
- **Reading (fixed now):** on `i0251` with **wind = 0**, taking the larger of L2/L3 whole-run
  `tilt_sat_frac`:
  - **< 0.1 %** → the clamp comes from the wind (gusts) - **(a)**;
  - **≥ 1 %** → the attitude loop oscillates on its own and is held by the 30 deg clamp -
    **(b)** → **STOP before GĐ7** and report to the user;
  - between 0.1 % and 1 % → not decided by this round; reported to the user.
  `i0000` (both winds) is reported beside it for comparison, not scored.

## 11. Results of night 2 (`gd6_night2`, git `2bd5488`, 5.5 h) - facts

Log `results/gd6/night2_20260925_222044.txt` (user's machine); `results/gd6/d2_p2.mat`,
`results/gd6/n0p_p2.mat`. No error, no crash.

### 11.1 D2 main table, first pass (§7.2; circle_main cap 4, 134 segments / 42 days, SHA `a227e9d87a2ac436` asserted)
TauPred **290 ms** (L3), TauPrev **180 ms** (V), both from §9.2. One set: **134 / 134** valid in
every column (0 removed: crash, diverged, P2 flag).

| column | pooled mean error [m] |
|---|---|
| L0 (Guo MOBADC) | 0.04502 |
| L2 (`g_sens`) | 0.03628 |
| L3 (`g_psens`, τ 290 ms) | 0.01802 |
| V (`g_sens`, preview 180 ms) | 0.01671 |

**D2 (§0.5): Δ = L3/L2 − 1 = −50.3 %**, SE (day jackknife) 8.3 pts, LOO [−57.3, −50.2] %,
by-day median −62.2 %; most influential segment `wind_expl_t150_i0306`. Δ ≤ −30 % and every
LOO Δ < 0 → **D2 PASS** (first pass: columns L0, L2, L3, V; L1, F2, P, O, VP are later nights,
§7.2 one-set rule).
Also recorded (fact, not scored): V's pooled error is below L3's (0.01671 vs 0.01802).

### 11.2 §10.1 secondary - tilt command at the 30 deg clamp (not the gate)
**15 of 134** segments flagged (`tilt_sat_frac > 0.01` in some column); L0 / L2 / L3 / V:

| segment | day | L0 | L2 | L3 | V |
|---|---|---|---|---|---|
| wind_real i0251 | 2024-02-08 | 0.3071 | 0.3149 | 0.3110 | 0.3115 |
| wind_real i0846 | 2024-05-17 | 0.0442 | 0.0478 | 0.0402 | 0.0424 |
| expl i0013 | 2024-01-12 | 0.0239 | 0.0285 | 0.0262 | 0.0268 |
| expl i0041 | 2024-01-27 | 0.1219 | 0.1242 | 0.1035 | 0.1101 |
| expl i0151 | 2024-02-23 | 0.2217 | 0.2252 | 0.2139 | 0.2156 |
| expl i0162 | 2024-02-23 | 0.0099 | 0.0110 | 0.0102 | 0.0104 |
| expl i0184 | 2024-02-25 | 0.0730 | 0.0750 | 0.0613 | 0.0661 |
| expl i0222 | 2024-04-03 | 0.0103 | 0.0106 | 0.0073 | 0.0078 |
| expl i0244 | 2024-04-14 | 0.0336 | 0.0346 | 0.0302 | 0.0298 |
| expl i0247 | 2024-04-14 | 0.0251 | 0.0265 | 0.0219 | 0.0228 |
| expl i0304 | 2024-05-07 | 0.0246 | 0.0282 | 0.0274 | 0.0272 |
| expl i0306 | 2024-05-07 | 0.0495 | 0.0516 | 0.0478 | 0.0486 |
| expl i0317 | 2024-05-07 | 0.4002 | 0.4008 | 0.3989 | 0.3988 |
| expl i0323 | 2024-05-07 | 0.1639 | 0.1663 | 0.1633 | 0.1623 |
| expl i0357 | 2024-05-18 | 0.0106 | 0.0120 | 0.0080 | 0.0096 |

Secondary number: **Δ without the flagged segments = −62.3 %** (n = 119, LOO [−62.6, −62.2] %)
vs the registered −50.3 % (n = 134). The D2 verdict stays the registered one (§11.1).
Observed (fact, not read): the clamp occurs in all four columns at nearly the same fraction
on each flagged segment (i.e. it is not specific to L3); the most influential D2 segment
`i0306` is one of them; 4 of the 15 are one day (2024-05-07). Why the clamp occurs is the
question of §10.2 (next).

### 11.3 N0P hover and T5 (A4 fixed-5, pooled over 5/5 at every τ, no edge)
| run | condition | coarse min | **τ\*** | pooled at τ\* | pooled at 0 |
|---|---|---|---|---|---|
| N0P | hover | 0 ms | **0 ms** (floor) | 0.0173 | 0.0173 |
| N0P | T5 | 180 ms | **170 ms** | 0.0198 | 0.0275 |

hover: the curve rises monotonically from 0.0173 (0-40 ms) to 0.0180 (360-400 ms); fine
0/10/20 ms all 0.0173; τ = 0 is the physical floor (§7.1), not an edge → τ\*_hover = 0: in
hover the payload-prediction column L3 at its τ\* is L2 (no prediction benefit measured on
the fixed-5). T5: flat 0.0198 at 160-180 ms; argmin on unrounded values = 170 ms.

**Transcribed:** τ\*_hover = **0 s** (for §10.2 and N5-H-StrongRel), τ\*_T5 = **0.170 s**.
The N0P/N0V τ table on P2 is complete: circle 290, V 180, T3b 340, square 120, hover 0,
T5 170 ms.
Consequence for §10.2 (fact): with TauPred = τ\*_hover = 0, L3 coincides with L2 in hover
(§9.1: identical to 4 decimals at τ 0), so the i0251 diagnostic's two columns will read
alike; the registered procedure is run unchanged.

## 12. Result of the §10.2 i0251 diagnostic (git `6475ae7`, TauPred = τ\*_hover = 0) - facts

Log `gd6_i0251_log.txt`, `results/gd6/i0251_diag.mat` (user's machine). Hover, IM
`DoWAxis {[0 3.132], [0 3.132], [0 1.575]}`, 4 calls × 2 columns, all stable. L2 and L3
coincide to every printed digit (τ 0, §11.3).

| seg | wind | tilt_sat whole | tilt_sat t ≥ 140 | tilt ≥ 30° | amp roll / pitch [deg] | RMS roll / pitch [deg] | f roll / pitch [Hz] | err [m] |
|---|---|---|---|---|---|---|---|---|
| i0251 | real | 0.2329 | 0.0000 | 0.1218 | 11.40 / 13.03 | 2.49 / 4.33 | 0.017 / 0.017 | 0.0344 |
| i0251 | zero | 0.0000 | 0.0000 | 0.0000 | 0.16 / 0.37 | 0.04 / 0.11 | 1.717 / 2.250 | 0.0002 |
| i0000 | real | 0.0000 | 0.0000 | 0.0000 | 2.17 / 5.52 | 0.65 / 1.86 | 0.100 / 0.033 | 0.0089 |
| i0000 | zero | 0.0000 | 0.0000 | 0.0000 | 0.15 / 0.44 | 0.05 / 0.11 | 1.617 / 2.200 | 0.0002 |

**Reading §10.2 applied:** `i0251`, wind = 0, max L2/L3 whole-run `tilt_sat_frac` = 0.0000
(< 0.1 %) → **(a) the clamp comes from the wind (gusts)**; not (b); no STOP before GĐ7 on
this account. The one diagnostic round of this checkpoint is used.

Also recorded (facts, not read):
- On `i0251` with real wind the clamp lies entirely before t = 140 s (0.0000 in the scored
  window t ≥ 140 s); U (§6.1) is measured in that window only.
- With real wind the t ≥ 140 s spectrum peaks at the lowest FFT bin (1/60 s = 0.017 Hz):
  slow wind-driven tilt, no oscillation peak.
- With wind = 0 a residual attitude motion of 0.04-0.11 deg RMS at 1.6-2.3 Hz remains on
  both segments (the same on `i0000` and `i0251`), with position error 0.2 mm.

## 13. Registered 2026-09-25, before night 3 (N0W) and before any P / O number on P2

### 13.0 Finding recorded (not a gate): payload prediction does not help in hover
τ\*_hover = 0 (§11.3): holding position, the payload has **no trajectory-forced
oscillation** - its swing comes from the wind and the pendulum's own natural frequency - so
the internal model has nothing at a known frequency to predict, and the best payload τ is
the floor. This is **evidence for M2** (CLAUDE_CODE_BRIEF: the benefit needs an internal
model that contains the true forcing frequency) and the **motivation for GĐ8's comparison
(iii) "prediction by a physical pendulum model"** (MASTER_PLAN §7.1), which does not need a
forcing frequency. It changes no gate and no registered block.

### 13.1 N0W on P2 (night 3) - the §0.3.1 procedure with the P2 values fixed since
- Segments: the **A4 fixed-5** (§5.3.1: `i0000, i0251, i0453, i0705, i0900`), which replaced
  REGISTER_ROBUST §18.6's list for every P2 τ step (§5.3). `i0251` stays in (reading (a), §12).
- circle (`Test 4`), K 0.5, L 1.0, m_p 0.5, nominal P2, IM `DoHarm [0 1]`, column
  `O(τ_w)` = `g_orac` (payload prediction + oracle wind) with `OracleTauMs = τ_w`, payload
  `TauPred` = **0.290 s** (τ\*_circle, §9.2; passed explicitly), `TauPrev` 0.
- Grid: coarse 0:20:400 ms; one bounded edge extension (+3 points) if the minimum is at
  400 ms; **τ_w = 0 is a floor** (O(0) = the current true wind; a negative τ_w is not an
  oracle), as τ = 0 in N0P; fine 10 ms within ±20 ms of the coarse minimum.
- `S_c` = segments finite and unflagged at **every** τ_w evaluated (coarse, extension, fine,
  150 ms); τ_w\* = argmin of pooled `O(τ_w)` over coarse + fine on `S_c`; dropped segments
  listed. A fine point equal to a coarse point is not re-run (same call, cached).
- `O(150)`: one extra report-only point when 150 ms is not on the grid (5 runs); `O(0)` from
  the grid. Printed before any run (STOP unless both exact): the time-shift construction
  at the file's own horizon (150 ms) equals `wind_sim_load`'s `w_oracle_ts`, and
  `O(0)` equals `wind_ts` - max |difference| = 0 on each of the 5 segments.
- One τ_w\* for every CỔNG G group and CONFIRM2 (§0.3.1). Code: `run_p2_gd6('N0W',
  'TauPred', 0.290)`, results `results/gd6/n0w_p2.mat`, resumable per τ_w.

### 13.2 Implementation fix before any P column on P2: the sensor delay reaches PI-MoE's input
§0.3 states as the operating condition that PI-MoE receives the **measured** wind history,
**50 ms late** and noisy (effective horizon ~200 ms). In the code the delay was applied to
`wind_meas_ts` only (`delay_wind_meas`); `what_ts` (PI-MoE output, computed offline from the
noisy measured wind up to t_k) was **not** delayed - so P would have run with an undelayed
input, unlike §0.3 and unlike L3. This is an implementation error found before any P number
exists on P2 (P, `g_both`, has never run on P2; v1's N4b had no P column). Fix:
`pa_configs` option `PredDelay` (default false = bit-exact for every existing call) shifts
the time base of the held series `what_ts` (and `wvalid_ts`) by the sensor delay
(`core/delay_pred_ts.m`): the prediction made from `w_meas(≤ t − d)` is available at `t`.
Exact for any d (the series is held, interpolation off). The GĐ6/GĐ7 runner sets
`PredDelay true` for every call; it changes no column that has run (L0, L2, L3, V and O do
not read `what_ts`). Consequently at `N4b-P2-d200` P's input is 200 ms late, as L3's.

### 13.3 N0P circle, L = 1.5 (for `N4b-P2-L15`, CỔNG G #8) - night 3, after N0W
The §7.1 N0P procedure unchanged, condition `circle_L15` = circle at L 1.5 (IM `DoHarm
[0 1]`), A4 fixed-5, column L3. τ\*_L15 is transcribed here before the L15 block runs.

### 13.4 Nights 4-7 (order fixed by the user 2026-09-25; each block's run details are
### committed here before it runs; hours at 50 s per column-run, [measured night 2: ~27 s])
Common: nominal P2, `PredDelay true`, payload τ by §6.5 (circle 290 ms unless stated),
`O` = `O(τ_w*)` from §13.1, columns `L3, P, O(τ_w*)` + report-only `O(0)`, `O(150)` (§0.6:
`O(150)` is registered report-only beside every group; it is dropped only if τ_w\* = 150).
Every group: §0.6 statistics (h, c, h_sensor, h_pred, h(150), c(150), each with pooled,
SE day-jackknife, by-day median, LOO, most influential), one-set rule.
**Reuse:** a group whose set has the **same SHA** and the same configuration as a block
already run reuses its per-segment values (no re-run); the runner asserts the SHA.

| night | block | set (cap 4) | new column-runs | hours @50 s [@27 s] |
|---|---|---|---|---|
| 3 | N0W (§13.1) + N0P circle L 1.5 (§13.3) | A4 fixed-5 | 115-135 + 130 | 3.7 [2.0] |
| 4 | circle_main: `P`, `O(τ_w*)`, `O(0)`, `O(150)` → CỔNG G #6 `N4b-P2-base` (same SHA `a227e9d8`, L3 reused from D2) + D2 table columns | 134 | 536 | 7.4 [4.0] |
| 5 | `N4b-P2-d200`: L3, P (O columns do not read the delayed sensor - see reuse note below) | 134 | 268 | 3.7 [2.0] |
| 5-6 | `N4b-P2-L15`: L3, P, O, O(0), O(150) at L 1.5, TauPred τ\*_L15 | 134 | 670 | 9.3 [5.0] |
| 6 | `N4b-P2-K10`: same columns at K 1.0 | 132 | 660 | 9.2 [5.0] |
| 7-8 | `N5-A-Weak/-Medium/-StrongRel` (K 0) | 122 + 73 + 42 | 1185 | 16.5 [8.9] |
| 8 | `N5-B-Weak/-Medium` (K 0.5; see reuse note) | 122 + 56 | ≤ 890 | ≤ 12.4 [6.7] |
| 8 | `N5-H-StrongRel` (hover K 0, TauPred **0** as measured, IM hover) | 23 | 115 | 1.6 [0.9] |
| last | D2 table columns L1, F2, VP (mechanism table, secondary) | 134 | 402 | 5.6 [3.0] |

The user's "nights 5, 6-7" do not fit at 50 s per run; at the measured ~27 s they do
(night 5 ≈ 12 h of N4b at 50 s ≈ 6.5 h at 27 s). **Reuse note (decision for the user,
not applied until approved):** (i) at d200 the O columns read the oracle, not the delayed
sensor, so their runs are identical to night 4's - reuse per segment with a one-segment
bit-exact spot check; (ii) `N5-B-Weak/-Medium` have the configuration of `circle_main`
(K 0.5, circle) but other capped sets (other SHA) - reuse the per-segment values of the
segments they share with `circle_main`, spot-checked. Both are "same segment, same
configuration" reuse, not "same SHA"; without approval every run is made.
N6: definition in §14 (DRAFT), not run.

## 14. N6 - wind → payload oscillation: DEFINITION DRAFT (2026-09-25; NOT approved, NOT registered, nothing run)

To become an amendment only after the user approves it, committed before N6's first run
(§0.8). Until then N6 cannot make CỔNG G = YES.

**Question.** Does knowing the wind **on the payload** in advance help, where the payload's
motion is driven by the wind rather than by the trajectory? §13.0 shows the internal model
has nothing to predict in hover; N6 asks whether a wind-based term can.

**Condition (proposed): hover, K 0.5, L 1.0, m_p 0.5** - no trajectory forcing, so the swing is
wind + natural frequency only (circle mixes in the forced frequency the IM already
predicts). Payload TauPred = τ\*_hover = 0 (§11.3), IM hover. Set: new `N6_hover` = dev set ∩
A2 hover envelope at K 0.5 (U ≤ 10.86) ∩ cap 4, printed with its SHA before the run.
(Alternative for the user: circle_main, reusing night 4's L3, P, O.)

**The payload wind force in the controller.** In quasi-static equilibrium the whole wind
force on the payload reaches the UAV through the cable, so the controller's model of the
total wind force becomes `(1 + K) F̂(w, v_Q)` (the plant's payload drag is `K` times the
body's, §0.9). Implementation: the same `P2_WindHat` block with `p2_prm_w = [(1+K) K_w;
U_ref]` - a workspace value, no model change. The DO/IM keep estimating the remainder,
exactly as for the body wind in §0.3. The dynamic part (the pendulum's response to that
force) is **not** modelled here - that is GĐ8 (iii).

**Columns (all with the `(1+K)` model, so they differ only in the wind signal, as in §0.3):**
- `L3_6`: measured wind `w_meas(t)` (50 ms late, noisy **[corrected §43: on P2 the measured wind has NO noise (σ = 0) in every run; only the 50 ms delay and the 20 Hz hold are applied - a deviation from this text, found 2026-09-29]**) - the baseline;
- `O_6` = `O_6(τ_w*)`: true wind `w(t + τ_w*)` (τ_w\* from N0W, not re-measured);
- `P_6`: PI-MoE `ŵ(t + 150 | t)` (input delayed as §13.2);
- report-only: `O_6(0)`, and `L3` (body-only model) to show what the `(1+K)` model alone does.

**Gate (the §0.6 tests, unchanged in form):** `h_6 = 1 − pooled(O_6)/pooled(L3_6)`, headroom
⇔ `h_6 ≥ 10%` AND sign kept under LOO AND by-day median `h_6,d ≥ 5%`; `c_6 = (pooled(L3_6) −
pooled(P_6)) / (pooled(L3_6) − pooled(O_6))`, captured ⇔ `c_6 ≥ 0.5` AND `L3_6 − P_6 > 0`
under LOO. Reported beside: `h_6,sensor`, `h_6,pred` via `O_6(0)`, and the swing amplitude
(θ RMS, t ≥ 140 s) per column.

**Choices for the user before this is registered:** (1) hover (proposed) or circle_main;
(2) the quasi-static `(1+K)` model (proposed; no model change) or a dynamic payload model
(needs new blocks, overlaps GĐ8 (iii)); (3) baseline `L3_6` with the `(1+K)` model
(proposed: isolates the wind-knowledge effect) or the registered body-only `L3`.
Cost at 50 s per column-run: set size × 5 (≈ 23-60 segments in hover at cap 4 → 1.6-4.2 h).

## 15. Amendments (user decisions 2026-09-25, during night 3, before any CỔNG G group runs)

### 15.1 Reuse per segment - APPROVED
Approved: (i) `N4b-P2-d200` reuses the `O`, `O(0)` values of `N4b-P2-base` (the O columns read
the oracle, not the delayed sensor); (ii) `N5-B-Weak/-Medium` reuse `N4b-P2-base`'s `L3, P,
O, O(0)` for the segments they share with `circle_main` (same configuration: circle, K 0.5,
L 1.0, delay 50 ms, same τ). Also `N4b-P2-base` reuses D2's `L3` (same SHA, same TauPred -
the "same SHA" case of §13.4). **Every reuse is spot-checked:** before any reused value is
taken, the first shared segment's reused columns are re-run and must match the source to
every printed digit (`%.4f`, and the same flag); any difference → that source is not used
and every column is run. Code: `experiments/run_p2_gd7.m` (`load_sources`, `spot_check`).

### 15.2 `O(150)` - report column kept only in N0W and `N4b-P2-base`
Amends §0.6 ("reported beside every group") and §13.4: `O(150)`, `h(150)`, `c(150)` are
reported **only** in the N0W table (§13.1) and in `N4b-P2-base` (circle_main); every other
group has columns `L3, P, O(τ_w*)` + report-only `O(0)`. Committed before any group ran.

### 15.3 Hours (at 50 s per column-run [measured night 2: ~27 s]) - replaces §13.4's table
| block | new column-runs | hours |
|---|---|---|
| night 4: `N4b-P2-base` = circle_main `P, O(τ_w*), O(0), O(150)` (+ L3 from D2) | 536 + 1 spot | 7.4 [4.0] |
| `N4b-P2-d200`: `L3, P` (+ O, O(0) reused) | 268 + 2 spot | 3.7 [2.0] |
| `N4b-P2-L15` | 536 | 7.4 [4.0] |
| `N4b-P2-K10` | 528 | 7.3 [4.0] |
| `N5-A-Weak/-Medium/-StrongRel` | 948 | 13.2 [7.1] |
| `N5-B-Weak/-Medium` (shared segments reused) | ≤ 712 | ≤ 9.9 [≤ 5.3] |
| `N5-H-StrongRel` | 92 | 1.3 [0.7] |
| N6 (§15.4; after the N5 groups) | ≈ 5 × n(N6_hover) | ≈ 10 [5.6] for n ≈ 150 |
| last: D2 columns L1, F2, VP | 402 | 5.6 [3.0] |

### 15.4 N6 - REGISTERED (supersedes the §14 draft; user decisions 2026-09-25)
**Group #10 `N6`**: wind → payload oscillation, **hover**, K 0.5, L 1.0, m_p 0.5, nominal
P2, IM hover, payload TauPred = τ\*_hover = 0 (so the payload channel of L3 is the DO
estimate itself and the wind→payload channel is isolated). circle = a secondary report
(same definition on circle_main), **not** in the gate.
Set `N6_hover` = P2 dev set ∩ A2 hover envelope at K 0.5 (U ≤ 10.86) ∩ cap 4 per day
(`p2_segset('N6_hover')`, added to the registry); its SHA-256 is printed and transcribed here
before the first run.

**Model (dynamic, not quasi-static):** per horizontal axis a linear pendulum about the
hanging position, `s = [θ; θ̇]`, `θ̈ = −ω_n² θ − 2ζ_s ω_n θ̇ + u/(m_L L)`, nominal ω_n, ζ_s;
input `u` = the payload's quadratic wind force `K (K_w/U_ref) |w − v̂_L| (w − v̂_L)`,
`v̂_L = v̂_Q + L θ̂̇` (estimated relative velocity); output = horizontal cable force on the UAV
`m_L g θ`. Propagated τ = τ_w\* ahead in closed form with `u` held:
`expm([A B; 0 0] τ) = [Φ Γ; 0 1]`, `s(t+τ) = Φ s(t) + Γ u` (`core/pend_lin_model.m`,
`core/pend_lin_predict.m` - fixed-size, codegen-safe; the same core is GĐ8 (iii)).

**State and injection (fixed now, not tuned after any number):**
- State estimate `ŝ`: the same linear model run online at 1 kHz (exact ZOH), driven by the
  measured wind `w_meas` in **every** column, corrected by the DO: measurement
  `θ_m = d̂_mf,h / (m_L g)`, Luenberger gain placing both observer poles at `−2 ω_n`
  (`l1 = 4ω_n − 2ζ_s ω_n`, `l2 = 3ω_n² − 2ζ_s ω_n l1`).
- Payload channel used by the controller: `d̂_mf(t) + [pend_lin_predict(ŝ, w_sig, v̂_Q) −
  m_L g θ̂(t)]` - the DO's current estimate plus the model's predicted **change** over τ
  (no double counting of the present force, which the DO already carries).
- The columns differ **only** in `w_sig`, the wind held over the horizon.

**Columns:** `L3_6` (`w_sig` = measured `w_meas(t)`), `P_6` (PI-MoE `ŵ(t+150|t)`, input
delayed as §13.2), `O_6` (true `w(t + τ_w*)`); report-only `O_6(0)` (true `w(t)`) and `L3`
(no N6 term, body-only wind model).
**Gate:** `h_6 = 1 − pooled(O_6)/pooled(L3_6)`, headroom ⇔ `h_6 ≥ 10%` AND sign kept under
LOO AND by-day median `≥ 5%`; `c_6 = (pooled(L3_6) − pooled(P_6)) / (pooled(L3_6) −
pooled(O_6))`, captured ⇔ `c_6 ≥ 0.5` AND `L3_6 − P_6 > 0` under LOO - the §0.6 tests.
Reported beside: `h_6,sensor`, `h_6,pred` via `O_6(0)`, payload swing θ RMS per column.

**N6-M0 - offline model check, before any N6 closed-loop run** (`verification/check_n6_model.m
'TauMs', τ_w*`): plant P2 in prescribed mode (UAV held, hover) vs the linear model, on the
A4 fixed-5 + the 3 highest-U `N6_hover` segments (for large angles), t ≥ 140 s:
(a) `e1` = RMS error of the model's cable force driven by the true wind, relative to RMS of
the plant's; (b) `e2` = τ-ahead prediction error from the true state with the true future
wind, relative to the change over τ (`< 1` beats "no change"). **PASS ⇔ e1 ≤ 10 % on every
checked segment with θ RMS ≤ 10°**; larger angles and (b) reported. FAIL → N6 does not run,
reported to the user. (Octave test on synthetic wind, 60 s: e1 5.8 % at θ RMS 3.6°, 5.5 % at
11.6°, 15.1 % at 22.8° - code check only, no dev number.)
**Order:** N6-M0 after N0W (needs τ_w\*); the N6 model block (Simulink, P2 variant only) is
built and bit-exact-checked (N6 term off = unchanged) after the N5 groups; N6 runs last
among the groups.

## 16. Results of night 3 (`gd6_night3`, git `3513ee7`, 1.9 h) - facts

Log `results/gd6/night3_20260926_050515.txt`; `results/gd6/n0w_p2.mat`, `results/gd6/n0p_p2.mat`
(user's machine). ~25 s per column-run.

**Step 0 on the re-laid-out model (`baseline1.slx` `7E6187…`, `912c6ce`):** `verify_repro`
32 cells, largest difference 0.000e+00; `check_results_numbers` 146/146; D2 row 1 (`i0000`)
L0 0.0414, L2 0.0334, L3 0.0140, V 0.0136 - unchanged to the printed digit (with PredDelay on).

### 16.1 N0W (§13.1): oracle wind horizon on P2
Oracle construction check: 5/5 segments, O(150) time-shift vs `w_oracle_ts` and O(0) vs
`wind_ts`, max |d| = 0. S_c = 5/5 at every τ_w. Pooled O(τ_w) [m], coarse:

| τ_w [ms] | 0 | 20 | 40 | 60 | 80 | 100 | 150 | 200 | 300 | 400 |
|---|---|---|---|---|---|---|---|---|---|---|
| pooled | 0.0228 | 0.0228 | 0.0228 | 0.0228 | 0.0228 | 0.0229 | 0.0230 | 0.0232 | 0.0238 | 0.0244 |

Coarse minimum 20 ms; fine 0-40 ms at 10 ms (0.0228 at every point); argmin on unrounded
values → **τ_w\* = 20 ms** (not at an edge; 0 is the floor). N0W table: O(0) 0.0228,
O(150) 0.0230, O(τ_w\*) 0.0228; per segment O(0) / O(150) / O(20): i0000 0.0139 / 0.0139 /
0.0139, i0251 0.0422 / 0.0426 / 0.0422, i0453 0.0135 / 0.0137 / 0.0135, i0705 0.0173 /
0.0175 / 0.0173, i0900 0.0118 / 0.0119 / 0.0118.
**Transcribed: τ_w\* = 0.020 s** for every CỔNG G group and CONFIRM2 (§0.3.1).
Recorded (facts, not read, not a gate - the fixed-5 is not a CỔNG G set):
- The curve is flat from 0 to 80 ms and rises beyond; knowing the wind 150 ms ahead is
  slightly worse than knowing it now (O(150) 0.0230 vs O(0) 0.0228).
- On the same fixed-5, L3 at τ\*_circle = 290 ms pooled 0.0228 (§9.2) - equal to O(τ_w\*)
  to 4 decimals. The CỔNG G numbers come from the registered group sets (night 4 onward).
- `|τ_w* − 150| = 130 ms ≥ 50 ms`: the §0.6 reading note on the predictor's horizon will be
  attached to any group that has headroom but is not captured.

### 16.2 N0P circle, L = 1.5 (§13.3)
Pooled L3 [m]: 0.0426 at 0 ms, 0.0293 at 140, 0.0259 at 200, 0.0247 at 240, 0.0245 at 260,
0.0246 at 280, 0.0249 at 300, 0.0297 at 400; fine 240-280: 0.0247, 0.0246, 0.0245, 0.0245,
0.0246. Coarse minimum 260 ms → **τ\*_L15 = 260 ms** (5/5, no edge).
**Transcribed:** `N4b-P2-L15` runs with `TauPred` = **0.260 s**.

## 17. Results of night 4 (`gd7_night4(0.020)`, git `9e7cd6a`, 3.9 h) - facts

Log `results/gd7/night4_20260926_070650.txt`; `results/gd7/N4b-P2-base.mat` (user's machine).
Step 0: `verify_repro` 32 cells 0.000e+00, 146/146, D2 row 1 unchanged to the printed digit.

### 17.1 N6-M0 (§15.4) - PASS
`N6_hover` (cap 4) printed: **139 segments, SHA-256
`43226c02f081460607d5f98676c57cfa1207e98498ad2919c642af5d717144c7`** (transcribed here, §15.4).
τ = 20 ms (τ_w\*). Plant P2 prescribed (UAV held) vs the linear pendulum model:

| segment | U | θ RMS [deg] | θ max | e1 | e2 | e2abs | reading |
|---|---|---|---|---|---|---|---|
| real i0000 | 3.83 | 4.28 | 8.18 | 2.5 % | 164.7 % | 2.4 % | counts, ok |
| real i0251 | 6.70 | 12.31 | 23.24 | 5.0 % | 256.6 % | 4.2 % | reported |
| real i0453 | 6.56 | 10.18 | 13.78 | 1.5 % | 297.3 % | 2.0 % | reported |
| real i0705 | 5.05 | 7.02 | 14.37 | 2.4 % | 193.5 % | 2.3 % | counts, ok |
| real i0900 | 6.11 | 8.68 | 10.10 | 0.6 % | 440.3 % | 1.2 % | counts, ok |
| real i0715 | 10.67 | 25.36 | 32.83 | 2.9 % | 1886.4 % | 10.6 % | reported |
| expl i0215 | 10.56 | 25.77 | 39.97 | 6.0 % | 1239.7 % | 13.0 % | reported |
| expl i0134 | 10.50 | 25.02 | 35.08 | 3.0 % | 1912.9 % | 11.4 % | reported |

**N6-M0 PASS** (e1 ≤ 10 % on the 3 segments with θ RMS ≤ 10°). Recorded (facts, not read):
e1 stays ≤ 6 % up to θ RMS 26°; e2 > 100 % on every segment - at τ = 20 ms the change of
the cable force over the horizon is smaller than the model's absolute error (e2abs 1.2-13 %),
so the absolute τ-ahead prediction is worse than "no change". The registered N6 injection
uses the model's predicted **change** (§15.4), in which a common bias of the two model terms
cancels; e2 as defined does not measure that change.

### 17.2 CỔNG G #6 `N4b-P2-base` (circle_main, K 0.5, L 1.0, delay 50 ms, TauPred 290 ms, τ_w\* 20 ms)
Reuse: D2's L3, spot check on `i0000`: re-run 0.0140 vs source 0.0140 (printed digits equal;
|d| = 5.13e-08 m - equal to every printed digit, **not** bit-identical) → reuse ON.
One set: **132 / 134** - removed `wind_expl_t150_i0290`, `wind_expl_t150_i0293`: column **P**
only, solver stop "Derivative of state '1' in block `baseline1/UAV_Plant/Int_etadot` … not
finite" at t = 53.1 s and t = 187.0 s (physical divergence of the attitude, §0.4, in the
PI-MoE column; L3, O, O(0), O(150) finite on both).

| column | pooled [m] |
|---|---|
| L3 | 0.01810 |
| P | 0.01860 |
| O = O(20) | 0.01798 |
| O(0) | 0.01804 |
| O(150) | 0.01776 |

| statistic | pooled | SE | LOO | by-day median | most influential |
|---|---|---|---|---|---|
| h = 1 − O/L3 | +0.69 % | 0.13 | [+0.59, +0.72] % | +0.28 % | expl i0306 |
| L3 − P [m] | −0.00049 | 0.00008 | [−0.00050, −0.00047] | −0.00022 | expl i0184 |
| h_sensor | +0.38 % | 0.09 | [+0.35, +0.47] % | +0.22 % | expl i0306 |
| h_pred | +0.31 % | 0.18 | [+0.13, +0.32] % | +0.06 % | expl i0306 |
| h(150) | +1.88 % | 1.52 | [+0.34, +2.01] % | +0.21 % | expl i0306 |

Identity (1 − h) = (1 − h_sensor)(1 − h_pred): 0 residual.
**§0.6 verdict: evaluable (132 segments, 42 days); headroom NO (h = 0.69 % < 10 %); c not
evaluated; group #6 counts NO for CỔNG G.** (The runner also prints c = −397 % and
c(150) = −145 %; by §0.6 c is not evaluated without headroom - shown for completeness only.)
Recorded (facts, not read): P is worse than L3 (L3 − P < 0 under every LOO; +2.8 % pooled)
and caused the only two divergences; O(150) pools below O(20) on this set (h(150) 1.88 % vs
h 0.69 %), carried mostly by `i0306` (L3 0.1223, O 0.1212, O(150) 0.1164; also the most
influential D2 segment) - τ_w\* stays the registered N0W value (§0.3.1).

### 17.3 D2 table extended (§7.2, one-set rule over L0 L2 L3 V P O O(0) O(150))
132 segments valid in every column: L0 0.04519, L2 0.03633, L3 0.01810, V 0.01679, P 0.01860,
O 0.01798, O(0) 0.01804, O(150) 0.01776; **Δ = L3/L2 − 1 = −50.2 %** (n 132, LOO [−57.2,
−50.1] %) beside the registered D2 −50.3 % (n 134) - D2 PASS holds on the reduced set.

## 18. Registered 2026-09-26, before the runs: column-P diagnosis; amendment N0W-6 for N6

### 18.1 Diagnosis of the two P divergences (`wind_expl_t150_i0290` t = 53.1 s, `i0293` t = 187.0 s) - one round
Code: `experiments/diag_p_column.m`. Window W = [t_c − 5 s, t_c] (t_c = the solver-stop time).
**(A) offline, from the segment files** (no simulation): the PI-MoE output `w_hat` at its
availability times `t_pred`, its target times `t_pred_target`, the measured input `w_meas`,
the true wind `w_plant`; the series the controller holds (`what_ts` after the 50 ms
PredDelay shift, rebuilt exactly as `core/delay_pred_ts.m` does).
- A1 non-finite values (NaN/Inf) in `w_meas`, `w_hat`, the delayed `what_ts`;
- A2 the delayed series equals the original shifted by 50 ms (max |d| = 0);
- A3 t_c against the series' events: first prediction (`t_valid_from`, + 50 ms), last
  prediction, end of the segment;
- A4 jumps: max |Δŵ| (consecutive 20 Hz predictions, horizontal norm) in W vs the largest
  |Δŵ| over the whole of every other `circle_main` segment (the pooled maximum);
- A5 range: max |ŵ| in W vs max |w_plant| of the same segment;
- A6 prediction error e = |ŵ(t_pred) − w(t_pred_target)| (horizontal): RMS in W, RMS over
  the segment, and the percentile of the W-RMS among all 5-s windows (step 1 s, t ≥ 30 s) of
  every `circle_main` segment.
**(B) closed loop, 4 runs** (P and L3 on each of the two segments, nominal P2, TauPred 0.290,
τ_w\* irrelevant, stopped 20 ms before t_c so that the logs survive): the wind force the
controller applied (`dlfhat_log`), η (`eta_log`), the commanded tilt; max |force| and max
|η| in W, P vs L3. Descriptive.
**Reading (fixed now):**
- **implementation error** ⇔ any of: A1 non-finite; A2 ≠ 0; A3 t_c within 1 s of a series
  event; A4 max |Δŵ| in W > the pooled maximum; A5 max |ŵ| in W > 1.5 × max |w_plant| →
  fix, then re-run column P of every group already run (N4b-P2-base, and d200/L15/K10 if run);
- otherwise, **finding** ⇔ the W-RMS of e is at or above the 95th percentile of the pooled
  window distribution → "the learned wind predictor in closed loop causes divergence",
  reported with e around t_c vs the pooled distribution;
- otherwise (clean input, prediction error not unusual) → neither; reported to the user,
  who decides (the user's reading has two branches; this third case is added so that every
  outcome has a reading).

### 18.2 Amendment to §15.4 (N6): step N0W-6 - the horizon of O_6 (before any N6 run)
The wind → payload channel goes through the pendulum dynamics, so its best horizon may differ
from τ_w\* = 20 ms (§16.1). Before the N6 group runs:
- **N0W-6** = the N0W / N0P procedure (§13.1: coarse 0:20:400 ms, one bounded edge extension,
  fine ±20 ms at 10 ms, τ = 0 a floor, argmin on `S_c` = segments valid at every τ) for the
  column `O_6(τ)` = true wind `w(t + τ)` held over the horizon **and** the model propagated
  over the same τ (`Φ(τ), Γ(τ)`), hover, K 0.5, L 1.0, TauPred 0 (τ\*_hover), on the **A4
  fixed-5** (all inside the hover K 0.5 envelope, U ≤ 10.86) → **τ_6\***.
- The N6 group then uses **τ_6\*** in place of τ_w\* everywhere in §15.4: O_6 = w(t + τ_6\*),
  and the propagation horizon of every N6 column (L3_6, P_6, O_6, O_6(0)) is τ_6\*. P_6's
  PI-MoE keeps its 150 ms checkpoint horizon.
- N6-M0's e1 does not depend on τ (PASS stands, §17.1); e2 is re-reported at τ_6\* (offline).
- Cost ≈ 26 τ × 5 = 130 column-runs (~1 h). Runs after the N6 block is built (after N5).

## 19. Results of night 5 (`gd7_night5`, git `41d3981`, 9.2 h) - facts

Log `results/gd7/night5_20260926_184904.txt`; `results/gd7/N4b-P2-{d200,L15,K10}.mat`
(user's machine). Step 0: `verify_repro` 32 cells 0.000e+00, 146/146, D2 row 1 unchanged.
τ_w\* = 20 ms in every group.

| group | set, n valid / n | L3 | P | O | O(0) | **h** (SE; LOO; by-day median) | h_sensor | h_pred | L3 − P [m] | verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| #7 `N4b-P2-d200` | circle_main 132/134 | 0.01843 | 0.01897 | 0.01798 | 0.01804 | **+2.42 %** (0.29; [+2.32, +2.63]; +1.31) | +2.11 % | +0.31 % | −0.00054 | **NO** (no headroom) |
| #8 `N4b-P2-L15` | circle_main 132/134 | 0.01977 | 0.02020 | 0.01961 | 0.01966 | **+0.80 %** (0.43; [+0.39, +0.83]; +0.15) | +0.55 % | +0.25 % | −0.00043 | **NO** |
| #9 `N4b-P2-K10` | `N4b-P2-K10` (SHA `03fae8f8a845cb5b`) 129/132 | 0.02541 | 0.02591 | 0.02537 | 0.02538 | **+0.15 %** (0.05; [+0.13, +0.20]; +0.05) | +0.11 % | +0.04 % | −0.00050 | **NO** |

All three evaluable (≥ 129 segments, ≥ 41 days); c not evaluated (no headroom); identity
(1 − h) = (1 − h_sensor)(1 − h_pred) holds (residual ≤ 1.1e-16).
**Removed segments (one-set rule):**
- `wind_expl_t150_i0290`, `i0293`: column **P only**, in every group - d200: solver stop at
  t = 80.0 s (`UAV_Plant/Int_etadot`) and 177.1 s (`Attitude_Observer/Int_za`); L15: solver
  stop 65.7 s and `diverged` (tracking error > 1 m, run completed); K10: solver stop 60.7 s
  and 193.2 s. (N4b-P2-base: 53.1 s and 187.0 s, §17.2.)
- `wind_real_t150_i0251` at **K 1.0**: `diverged` in **all four** columns (L3, P, O, O(0)).
  U = 6.70 m/s, inside the K 1.0 A2 envelope (6.95); the §12 tilt-clamp segment. Recorded as
  a D1-type fact (the controller loses the segment at K 1.0 with or without prediction);
  reported, not diagnosed here.
**Reuse (§15.1):** d200's O, O(0) from N4b-P2-base; spot check on `i0000`: re-run 0.0139 vs
0.0139 (|d| 1.47e-07 and 1.45e-07 m; printed digits equal, not bit-identical) → reuse ON.
**Recorded (facts, not read):** P is worse than L3 in every group (L3 − P < 0 under every
LOO); the headroom is largest with the 200 ms sensor delay and comes mostly from the
perfect-sensor part (h_sensor 2.11 % of h 2.42 %); the prediction part h_pred stays ≤ 0.31 %.
CỔNG G so far: groups #6-#9 = NO (4 of the registered groups; N5-A/-B/-H and N6 remain).

## 20. Result of the §18.1 column-P diagnosis (git `dc6709a`) - facts; the one round is used

Log `diag_p_log.txt`, `results/gd7/diag_p_column.mat` (user's machine). First call stopped in
the closed-loop part on a code error of the runner (`KeepLog` wrapped in two cells, fixed in
`dc6709a`); the offline part is deterministic and printed the same values on both calls.
Pooled reference (132 other circle_main segments): max |Δŵ| 5.139 m/s; 5-s window prediction
error RMS: median 0.198, p95 0.682, max 2.008 m/s.

| | `expl i0290` (t_c 53.117 s) | `expl i0293` (t_c 186.981 s) |
|---|---|---|
| A1 non-finite (w_meas, ŵ, delayed what_ts) | 0, 0, 0 | 0, 0, 0 |
| A2 PredDelay shift max \|d\| | 0 | 0 |
| A3 nearest series event to t_c | 23.07 s | 12.87 s |
| A4 max \|Δŵ\| in W (pooled max 5.139) | 3.950 m/s | 0.393 m/s |
| A5 max \|ŵ\| in W / max \|w\| | 7.59 / 9.91 (0.77) | 4.66 / 9.98 (0.47) |
| A6 error RMS in W; whole segment; W percentile | 0.940; 0.855 m/s; **98.5** | 0.085; 1.075 m/s; 15.3 |
| B, P (to t_c − 20 ms): max \|wind force\| in W / before W | 3.126 / 9.062 N | 6.396 / 11.504 N |
| B, P: max \|η\| in W / before W; tilt-clamp fraction | 1225.1° / 828.0°; 0.013 | 641.0° / 500.1°; 0.002 |
| B, L3: max \|wind force\| in W / before W | 3.932 / 3.389 N | 1.371 / 4.463 N |
| B, L3: max \|η\| in W / before W; tilt-clamp fraction | 17.9° / 22.3°; 0.000 | 17.7° / 22.6°; 0.000 |

**Reading §18.1 applied:** no implementation-error criterion is met on either segment
(A1-A5 clean). `i0290`: **FINDING** - the learned wind predictor in closed loop causes
divergence (A6 in W at the 98.5th percentile ≥ p95). `i0293`: **NEITHER** (clean input,
prediction error in W not unusual) → reported to the user, who decides.
Recorded (facts, not read):
- In column P the attitude had already left any physical range **before** W on both segments
  (max |η| 828° and 500° in [30 s, t_c − 5 s]; L3 stays ≤ 22.6°), so the solver stop t_c is
  late in the divergence: W = [t_c − 5, t_c] does not contain its onset. The registered
  window assumed the stop to be close to the onset; that assumption does not hold.
- Before W, the wind force P's controller applied reached 9.1 N and 11.5 N (L3: 3.4 N and
  4.5 N on the same segments).
- Over the whole segment, the PI-MoE error RMS is 0.855 and 1.075 m/s on these two segments
  (pooled 5-s windows: median 0.198, p95 0.682 m/s).
- P's divergence changes no CỔNG G verdict so far (no group has headroom; c not evaluated).

### 20.1 Amendment (user decision 2026-09-26, before the run): onset-based second round
Reason (user): the registered reading window W = [t_c − 5, t_c] lies after the onset of the
divergence - a fault of the measuring tool, as FLOORDIAG earlier - so one more round is run,
registered here first. Code: `diag_p_column('Round', 2)`. Both segments (`i0290`, `i0293`).
- **t_on** = in the P run (nominal P2, as §18.1 B, stopped 20 ms before t_c), the first time
  max(|φ|, |θ|) > 30° or the commanded tilt reaches the 30° clamp, whichever is earlier.
  **W_on = [t_on − 5 s, t_on]**; A1-A6 of §18.1 recomputed in W_on (A3 on t_on).
- **A7 (switch transient)**, from the same P run and the L3 run of the same segment:
  (i) what column P feeds to the controller before 30.05 s - from the model: the position
  ESO's estimate `ESO_Out` (WD_Switch passes F̂(ŵ) only when `wind_pred_on · wvalid ≥ 0.5`,
  and `wvalid` turns on at t_valid_from + 50 ms = 30.05 s); checked on the logs as
  max |applied force − ESO_Out| for t < 30.05 s (expected 0);
  (ii) the step of the applied wind force at the switch, |F(30.05⁺) − F(30.05⁻)| [N], vs the
  largest 1-ms step of the applied force in normal operation = the L3 run of the same
  segment for t > 30.1 s (also reported: the P run's own largest step in (30.1 s, t_on − 5 s],
  and L3's own step at the switch);
  (iii) |t_on − 30.05| ≤ 1 s.
- **Reading (fixed now):** A7-(iii) true **or** A7-(ii) step > the normal reference →
  **implementation error (switch transient)**: fix the switch for column P only (e.g. P uses
  the measured wind in F̂ until the prediction is valid, then a smooth blend), then re-run
  column P of groups #6-#9; otherwise A1-A5 in W_on as §18.1 (any → implementation error);
  otherwise A6 in W_on ≥ pooled p95 → **FINDING**; otherwise **NEITHER** → the user decides.

### 20.2 Correction to §13.2 (fact, found while writing §20.1)
`delay_pred_ts` shifts `wvalid_ts` as well as `what_ts`, and `wvalid` gates WD_Switch for
**every** column with `wind_pred_on = 1` (L2, L3, V, P, O). With `PredDelay` on, the switch
from the ESO estimate to F̂ therefore happens at 30.05 s instead of 30.00 s in L2/L3/V/O too.
§13.2's statement "it changes no column that has run" is wrong for those columns. Size: the
reuse spot checks compare D2's L3 (PredDelay off, switch 30.00 s) with a re-run (on, 30.05 s):
|d| = 5.13e-08 m (§17.2), 1.47e-07 / 1.45e-07 m for O/O(0) across calls (§19) - below the
printed digit (stats window t ≥ 140 s). Consequence recorded: in N4b-P2-base the reused L3
switched 50 ms earlier than P and O of the same table. Left as is unless the user decides
otherwise.

### 20.3 N0W-6 - confirmation
The horizon step for N6 (N0W-6, §18.2) was registered on 2026-09-26 in commit `a5937ba`,
before any N6 run (no N6 closed-loop run exists; the N6 block is not built yet). N6 runs
only after N0W-6 has produced τ_6\*, which is transcribed here before the N6 group runs.

### 20.4 Result of the second round (§20.1, git `613b90a`) - facts; not readable as registered
Log `diag_p_r2_log.txt`, `results/gd7/diag_p_column_r2.mat` (user's machine).

| | `expl i0290` | `expl i0293` |
|---|---|---|
| first max(\|φ\|,\|θ\|) > 30° (P run) | **41.347 s** | **170.253 s** |
| first tilt command at the 30° clamp (P run) | 0.008 s | 0.008 s |
| t_on as registered (earlier of the two) | 0.008 s | 0.008 s |
| A1-A5 in [t_on − 5, t_on] | clean (no prediction in the window) | clean (no prediction in the window) |
| A6 in the window | NaN (0 predictions) | NaN (0 predictions) |
| A7 (i) max \|applied force − ESO_Out\| before 30.05 s | 0 N | 0 N |
| A7 (ii) step at the switch: P / L3; normal reference (L3, t > 30.10 s) | 0.176 / 0.179 N; 3.145 N | 0.158 / 0.178 N; 3.597 N |
| A7 (iii) \|t_on − 30.05\| | 30.042 s | 30.042 s |

The registered reading printed NEITHER on both, but the round is **not readable as
registered**: the tilt command touches the clamp at start-up (t = 0.008 s) on both segments,
so the "earlier of the two" definition of t_on fell on the start-up transient, W_on holds no
prediction and A6 is undefined - a fault of the definition written in §20.1, not a result.
The second diagnostic round is used; stopped and reported (brief rule 3.2.2).
Recorded (facts, not read):
- A7 (i): before the switch column P applies exactly the ESO estimate (0 N difference).
- A7 (ii) does not depend on t_on: the applied-force step at the switch is 0.16-0.18 N in P
  and the same in L3, against normal 1-ms steps of 3.1-3.6 N after the switch - not abnormal.
- With the attitude criterion alone, the onset is 41.347 s (i0290) and 170.253 s (i0293):
  11.3 s and 140.2 s after the switch at 30.05 s.
- Together these exclude the switch transient registered in §20.1 on both segments;
  A1-A5 were clean in both rounds (no implementation error found).

### 20.5 Third and LAST round for column P (user decision 2026-09-26, before the computation)
Reason for allowing it (user): rounds 1 and 2 could not be read because of the definition
of the measuring tool (the window after the onset; the start-up clamp in t_on), not because
of the data. Offline only, no simulation. Code: `diag_p_column('Round', 3)`.
- t_on by the attitude criterion alone, from §20.4: **41.347 s** (`i0290`), **170.253 s**
  (`i0293`), written literally in the code; window **[t_on − 5 s, t_on]**; A1-A6 of §18.1 in
  it (A3 on t_on); reading unchanged from §18.1 (any of A1-A5 → implementation error;
  otherwise A6 ≥ pooled p95 → FINDING; otherwise NEITHER).
- Whatever the result, it is recorded verbatim; **no fourth round**. Column P's diagnosis is
  then closed (§20.6) with the result of this round added to the closing statement.

### 20.6 Result of the third round (§20.5, git `221a986`) - facts, verbatim; column-P diagnosis CLOSED
Log `diag_p_r3_log.txt`, `results/gd7/diag_p_column_r3.mat` (user's machine). Offline, no
simulation. W = [t_on − 5 s, t_on], t_on by attitude (§20.4). Pooled reference (132 other
circle_main segments): max |Δŵ| 5.139 m/s; 5-s window error RMS median 0.198, p95 0.682,
max 2.008 m/s.

| | `expl i0290` (t_on 41.347 s) | `expl i0293` (t_on 170.253 s) |
|---|---|---|
| A1 non-finite (w_meas, ŵ, delayed what_ts) | 0, 0, 0 | 0, 0, 0 |
| A2 PredDelay shift max \|d\| | 0 | 0 |
| A3 nearest series event to t_on (threshold 1 s) | 11.30 s | 29.60 s |
| A4 max \|Δŵ\| in W (pooled max 5.139) | **12.685 m/s** | **8.436 m/s** |
| A5 max \|ŵ\| in W / max \|w\| (threshold 1.5) | 14.19 / 9.91 (1.43) | 12.33 / 9.98 (1.24) |
| A6 error RMS in W (100 predictions); whole segment; W percentile | 1.957; 0.855 m/s; **100.0** | 1.650; 1.075 m/s; **99.9** |

**Reading §18.1 applied (as printed):** both segments **IMPLEMENTATION ERROR (A1-A5) → fix,
re-run column P of every group already run**. The criterion met is **A4 only**, on both
segments (A1, A2, A3, A5 are not met). A6 is at/above the pooled p95 on both (it would read
FINDING), but §18.1 gives A1-A5 precedence.

What A4 measures (fact about the tool, not a new reading): ŵ is the PI-MoE output stored in
the segment file, computed offline from the measured wind; it does not depend on the
closed loop. A4 flags that in the 5 s before the attitude onset, on both diverging segments,
ŵ has a jump between consecutive 20 Hz predictions (12.7 and 8.4 m/s) larger than any jump
over the whole of each of the 132 other circle_main segments. A4 does not tell whether such a
jump is a defect in producing ŵ or the predictor's own output on that input; no further
round is opened to decide it (§20.5), so the §18.1 action "fix" has no identified target and
is **not carried out**. Column-P numbers already recorded (§17, §19) stand, with this
section as their caveat.

**Closing statement - column P (for the paper; association, not strong causation):**
1. Controller-side implementation checks are clean: no non-finite values (A1), the 50 ms
   PredDelay shift is exact (A2), the onsets are 11-140 s away from any series event (A3),
   and before the switch column P applies exactly the ESO estimate (A7 (i), 0 N).
   The predictor-side check A4 is **not** clean (above); an implementation error is therefore
   **not excluded** for the ŵ series, and is not confirmed either.
2. The ESO→F̂ switch transient is excluded: the applied-force step at 30.05 s is
   0.16-0.18 N in P, the same as in L3, ~20× smaller than normal 1-ms steps (3.1-3.6 N), and
   the attitude onset comes 11.3 s and 140.2 s after the switch (§20.4).
3. Column P is worse than L3 in every CỔNG G group run so far (§17, §19).
4. Column P diverges on 2 of the 134 circle_main segments (`i0290`, `i0293`), in every
   configuration, where L3 stays within 22.6° attitude.
5. In the 5 s before the attitude onset on both segments, ŵ has jumps larger than anywhere in
   the other 132 segments (A4) and a prediction error RMS at the 100.0th / 99.9th percentile
   of all pooled 5-s windows (A6). The divergences of P are thus **associated with** abnormal
   ŵ just before their onset; the data do not show that the jumps cause the divergence, nor
   whether they come from the predictor or from how ŵ was produced.

The column-P diagnosis is closed; no fourth round (§20.5).

**User decision on §20.6 (2026-09-26):** the wording above is kept: "no implementation error"
is **not** written; controller-side checks clean; A4 on the ŵ side failed; an export defect
and the genuine PI-MoE output are not yet told apart; column-P numbers stand with the §20.6
caveat. That distinction is the job of the separate checkpoint P-QA (§21), which is **not** a
fourth round of the column-P diagnosis.

## 21. Checkpoint P-QA - quality of the exported ŵ series (registered 2026-09-26, before any computation)
A new checkpoint (user decision), independent of §18/§20: its reading does not re-open the
column-P diagnosis. Offline, no simulation. Code: `analysis/p_qa.m` (written when due).

**When:** after GĐ7, before writing the paper; **at once** if any CỔNG G group shows headroom
(then c uses column P, so P-QA's reading must be in before c is read for that group).

**Population:** every segment exported for P2 - the full P2 dev set of §6.2.1 (30
`wind_real_t150_i*` field_grid + 441 `wind_expl_t150_i*`, 46 days), uncapped, the two
diverging segments included (their events are also listed separately). No held-out,
CONFIRM or CONFIRM2 file is read.

**Facts about the export, from the code (recorded now, before looking):** a segment is a
200 s window cut inside one M5 10-min file (`segments()`, offsets 0/200/400 s, heights 61/74
m); a window holding any NaN/Inf is dropped, not filled; despiking is off (default); QC
rejects |v| > 40 m/s and any step > 10 m/s per 50 ms; PI-MoE reads only the segment's own
`w_meas` through a sliding window of `window_s` (30 s) ending at t, so ŵ exists from
`t_valid_from` (30 s) to 199.85 s at 20 Hz. There is therefore no gap-filling step to find;
"missing-data handling" is tested through its signature (held samples) below.

**Quantities** (horizontal norm, as A4; at the 20 Hz prediction samples t_k):
- Δŵ_k = |ŵ(t_k) − ŵ(t_{k−1})|;
- Δw_k = |w_plant(t_k) − w_plant(t_{k−1})| (true wind, same segment, same times);
- Δm_k = |w_meas(t_k) − w_meas(t_{k−1})| (the predictor's input).
Per segment and pooled: quantiles 50 / 90 / 99 / 99.9 % and max of Δŵ, Δw, Δm, and the ratio
Δŵ/Δw at each quantile.

**Thresholds (fixed now):**
- T_norm = **5.139 m/s** (the pooled circle_main maximum of §20; literal);
- T_phys = the **99.9th percentile of Δw pooled over every sample of every segment** in the
  population (computed first, printed, then used unchanged);
- T_in = the 99.9th percentile of Δm pooled likewise (input steps).
Every event Δŵ_k > T_phys is listed (CSV), marked whether it also exceeds T_norm.

**Location of each event** (seconds):
- d_start = t_k − t_valid_from (predictor start-up); d_end = t_end − t_k (segment end);
- d_file = distance of t_k to the start or end of the raw M5 file (raw time
  `real_offset_s` + t_k, file length 600 s);
- held input: a run of ≥ 3 consecutive identical `w_meas` samples (all three channels) inside
  the predictor window [t_k − window_s, t_k];
- input step at entry: max Δm over t_k ± 1 sample; at exit: max Δm over
  t_k − window_s ± 1 sample (a sample leaving the 30 s window also moves ŵ).

**Classes of an event:**
- **B** (boundary / start-up / data handling) ⇔ d_start ≤ 1 s, or d_end ≤ 1 s, or d_file ≤ 1 s,
  or held input in the window;
- **I** (input noise) ⇔ not B and the input step at entry or at exit > T_in;
- **U** (unexplained) otherwise.
Also printed, descriptive: the share of all prediction samples lying in the B zones (base
rate), and the Spearman correlation of Δŵ_k with the entry input step over all samples.

**Reading (fixed now), on the events with Δŵ > T_norm:**
- B share ≥ 50 % → **EXPORT ERROR**: fix the export, re-export `what_ts`/ŵ, re-run column P of
  every group already run;
- otherwise I share ≥ 50 % → **PI-MoE PROPERTY** (out-of-distribution response to noisy
  input), written into the paper as such;
- otherwise → **NEITHER** (large jumps neither at boundaries nor on input noise), reported to
  the user, who decides (added so that every outcome has a reading).
The same shares for the events > T_phys are reported, not read. Whatever the result, it is
recorded verbatim.

**Implementation notes (2026-09-28, code written, before any run on real data):** Δŵ, Δw, Δm
are all taken between consecutive prediction samples (stride 1 → one 50 ms step); w_plant is
read at t_k on its own time grid; "held input in the window" = ≥ 3 identical samples lying
wholly inside [t_k − window_s, t_k]; entry/exit steps use one-sample Δm of w_meas. Per-segment
quantiles go to `p_qa_segments_<stamp>.csv` (pooled ones printed). Tested only on synthetic
segments (Octave: start-up, end/file-edge, held input, input spike, unexplained jumps; each
classified as intended).

## 22. Results of night 6 (`gd7_night6`, git `fe954c7`, 6.6 h) - facts
Log `results/gd7/night6_20260927_055247.txt`; `results/gd7/N5-A-{Weak,Medium,StrongRel}.mat`
(user's machine). Step 0: `verify_repro` 32 cells 0.000e+00, 146/146, D2 row 1 unchanged.
K 0, TauPred 0.290 s (circle τ\*), τ_w\* = 20 ms; no reuse (0 values reused: no earlier
group at K 0).

| group | set, n valid / n (days) | L3 | P | O | O(0) | **h** (SE; LOO; by-day median) | h_sensor | h_pred | c | L3 − P [m] | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| #1 `N5-A-Weak` | SHA `a051c6fdcf0a6be2`, 120/122 (38) | 0.00627 | 0.00639 | 0.00612 | 0.00616 | **+2.43 %** (0.56; [+2.22, +2.46]; +1.14) | +1.79 % | +0.66 % | −77.0 % | −0.00012 | **NO** |
| #2 `N5-A-Medium` | SHA `309278f9eb484c58`, 72/73 (25) | 0.01717 | 0.01776 | 0.01644 | 0.01664 | **+4.27 %** (3.95; [+4.11, +8.81]; +6.45) | +3.06 % | +1.25 % | −80.2 % | −0.00059 | **NO** |
| #11 `N5-A-StrongRel` | SHA `f8479cc53cb0d8a0`, 42/42 (13) | 0.01834 | 0.01884 | 0.01727 | 0.01763 | **+5.83 %** (4.34; [+5.50, +10.71]; +13.73) | +3.85 % | +2.06 % | −46.8 % | −0.00050 | **NO** |

All three evaluable; c printed, not evaluated (no headroom); identity residual ≤ 1.1e-16.
**Removed segments (one-set rule):**
- `wind_expl_t150_i0290`, `i0293` (in `N5-A-Weak`): column **P only**, solver stop at
  t = 55.122 s (`Attitude_Observer/Int_za`) and 190.210 s (`UAV_Plant/Int_etadot`). P now
  loses these two segments at K 0 as well as in every K 0.5 / K 1.0 configuration.
- `wind_real_t150_i0251` (in `N5-A-Medium`): **L3 only** `phys_div`; P, O, O(0) complete
  (0.0098, 0.0070, 0.0075). At K 1.0 (§19) it diverged in all four columns.
**Recorded (facts, not read):**
- P is worse than L3 in all three groups (L3 − P < 0 under every LOO); c < 0 throughout.
- h_sensor is the larger part of h in all three groups; h_pred ≤ 2.06 %.
- `N5-A-StrongRel` is the only group so far where a single leave-one-out value reaches 10 %
  (dropping `wind_expl_t150_i0316`, L3 0.0959 m, the most influential segment, gives h =
  +10.71 %) and where the by-day median exceeds 10 % (+13.73 %). The pooled h (+5.83 %) is
  below 10 %, so the registered test gives NO; nothing is re-read.
- Three segments carry L3 errors 5-20× the group's typical value without being flagged:
  `wind_expl_t150_i0319` 0.1253 m (Medium), `i0316` 0.0959 m (StrongRel), `i0432` 0.0467 m
  (Medium, StrongRel); they dominate the pooled RMS and are the most influential segments.
- No group has headroom, so P-QA (§21) stays scheduled after GĐ7.
CỔNG G so far: #1, #2, #6, #7, #8, #9, #11 = NO; #3 empty (A2); #4, #5, #12 (night 7) and
#10 N6 remain.

### 22.1 Report notes on night 6 (user decision 2026-09-27; not gate, verdicts not re-read)
- **#11 `N5-A-StrongRel`, reported side by side:** pooled h **+5.83 % (NO, the registered
  verdict)** | by-day median **+13.73 %** | LOO max **+10.71 %** (without `i0316`). The pooled
  value is dominated by `wind_expl_t150_i0319`, `i0316`, `i0432` (L3 5-20× the typical
  segment); most of h is h_sensor (+3.85 % of +5.83 %; h_pred +2.06 %).
- **tilt_sat_frac of `i0319`, `i0316`, `i0432`** (from the saved night-6 results, no
  simulation; `experiments/print_tilt_sat.m`). Reading fixed now: ≥ 1 % in a column → the
  segment is recorded as **reaching the UAV's capability limit**. Values (whole run / t ≥
  TStat, printed 2026-09-27):

  | segment (group) | L3 | P | O | O(0) | reading |
  |---|---|---|---|---|---|
  | `wind_expl_t150_i0319` (Medium) | 0.1837 / 0.1498 | 0.1835 / 0.1514 | 0.1787 / 0.1464 | 0.1800 / 0.1468 | **capability limit** |
  | `wind_expl_t150_i0316` (StrongRel) | 0.1726 / 0.1387 | 0.1706 / 0.1375 | 0.1697 / 0.1371 | 0.1712 / 0.1391 | **capability limit** |
  | `wind_expl_t150_i0432` (Medium, StrongRel) | 0.0774 / 0.0957 | 0.0768 / 0.0945 | 0.0756 / 0.0924 | 0.0765 / 0.0947 | **capability limit** |

  All three are ≥ 1 % in every column (7.6-18.4 % of the run at the tilt clamp): the
  segments that dominate the pooled h of #2 and #11 are segments where the UAV reaches its
  capability limit, in every column alike.
- **Column P loses `i0290`/`i0293` in every configuration run** (N4b-P2-base, d200, L15, K10,
  N5-A-Weak): reported under the §20.6 caveat (controller-side checks clean; ŵ-side A4 not;
  export defect vs genuine PI-MoE output not yet told apart), pending P-QA (§21).

## 23. Results of night 7 (`gd7_night7`, git `12c9578`, 2.3 h) - facts
Log `results/gd7/night7_20260927_123751.txt`; `results/gd7/N5-B-{Weak,Medium}.mat`,
`N5-H-StrongRel.mat` (user's machine). Step 0: `verify_repro` 32 cells 0.000e+00, 146/146,
D2 row 1 unchanged. τ_w\* = 20 ms.

| group | set, n valid / n (days) | L3 | P | O | O(0) | **h** (SE; LOO; by-day median) | h_sensor | h_pred | c | L3 − P [m] | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| #4 `N5-B-Weak` (K 0.5, TauPred 0.290) | SHA `a051c6fdcf0a6be2`, 119/122 (38) | 0.01280 | 0.01310 | 0.01274 | 0.01276 | **+0.47 %** (0.09; [+0.42, +0.48]; +0.24) | +0.37 % | +0.10 % | −489.9 % | −0.00030 | **NO** |
| #5 `N5-B-Medium` (K 0.5, TauPred 0.290) | SHA `dd710794f4786481`, 55/56 (22) | 0.02973 | 0.03076 | 0.02933 | 0.02946 | **+1.36 %** (0.43; [+1.20, +1.59]; +0.75) | +0.90 % | +0.46 % | −254.9 % | −0.00103 | **NO** |
| #12 `N5-H-StrongRel` (hover, K 0, TauPred 0) | SHA `7b105836187d9f25`, 19/23 (10) | 0.08559 | 0.08721 | 0.08236 | 0.08342 | **+3.77 %** (7.15; [+3.49, +5.00]; **+41.07**) | +2.53 % | +1.27 % | −50.2 % | −0.00162 | **NO** |

All three evaluable (#12: n 19 ≥ 15, 10 days ≥ 6); c printed, not evaluated (no headroom);
identity residual 0.
**Reuse (§15.1):** #4 and #5 from N4b-P2-base (96 and 29 shared segments). Spot checks:
#4 on `i0000` L3 |d| 5.13e-08, P/O/O(0) 0; #5 on `wind_real_t150_i0251` L3 |d| 3.09e-07,
P/O/O(0) 0; printed digits equal → reuse ON (384 of 488 and 116 of 224 values reused).
**Removed segments (one-set rule):**
- #4: `wind_expl_t150_i0290`, `i0293` - column P crash (values reused from N4b-P2-base);
  `wind_expl_t150_i0320` - **all four columns** solver stop (L3 96.81 s, P 87.19 s, O 99.93 s
  at `UAV_Plant/Int_etadot`; O(0) 124.48 s at `Attitude_Observer/Int_za`).
- #5: `wind_expl_t150_i0307` - L3 `phys_div`, P solver stop 172.23 s, O(0) solver stop
  187.60 s (both `UAV_Plant/Int_etadot`); O completed (0.0533).
- #12: `wind_real_t150_i0780`, `wind_expl_t150_i0309`, `i0313` - `diverged` in all four
  columns; `wind_expl_t150_i0430` - L3 only, solver stop 192.31 s (`Attitude_Observer/Int_za`);
  P, O, O(0) completed.
**Recorded (facts, not read):**
- P is worse than L3 in all three groups (L3 − P < 0 under every LOO), and on **every** one of
  the 19 hover segments of #12.
- #12: the pooled values are dominated by `wind_expl_t150_i0258` (L3 0.2603 m) and `i0261`
  (0.2410 m), then `i0311` (0.0999 m); the typical #12 segment has L3 ≈ 0.007-0.010 m and O ≈
  0.004-0.006 m. Pooled h +3.77 % (NO) against by-day median **+41.07 %** (h_sensor by-day
  +27.06 %, h_pred by-day +17.62 %). The registered pooled test gives NO; nothing is re-read.
- #5: the most influential segment for h is `wind_expl_t150_i0306` (L3 0.1223 m).
- h_sensor is the larger part of h in all three groups.
**CỔNG G after nights 4-7:** #1, #2, #4, #5, #6, #7, #8, #9, #11, #12 = **NO**; #3 empty (A2).
Only #10 (N6, §15.4, with N0W-6 §18.2 first) remains.

## 24. N6 block as built - implementation of §15.4 / §18.2 (2026-09-27, before any N6 run)
Code: `simulink_blocks/p2_n6_term.m` (MATLAB Function `P2/P2_Core/P2/P2_N6`), `core/p2_n6_prm.m`,
`build/build_p2_plant.m` steps [6] and band F, switches `p2_n6` / `p2_prm_n6`
(`core/p2_setup.m` options `N6`, `N6TauMs`; `pa_configs` `P2N6`, `P2N6TauMs`).
- **Where the term enters:** the payload channel, between `PP_Switch` (payload predictor at
  TauPred) and `Manual Switch` → tag `dmf_hat`, read by the position controller and by
  `ESO_15`. Variant Source `P2_N6_Sel`: `p2_n6 = 0` → port 1, the unchanged path; `p2_n6 = 1`
  → `PP_Switch + dmf_n6`. `p2_n6 = 0` everywhere by default (`init_MOBADC_params`,
  `reset_extensions`); the block itself runs whenever plant_model = 1 but nothing in the loop
  reads it while `p2_n6 = 0`.
- **DO estimate used by the observer:** `DO_Out/1` (the raw DO estimate, before the payload
  predictor), tapped by the Goto `dmf_do`; θ_m = d̂_mf,h / (m_L g).
- **Observer:** the continuous Luenberger observer of §15.4 (poles both at −2ω_n: nominal
  ω_n = 3.1321 rad/s, poles −6.264, l1 = 12.215, l2 = 25.604) discretised exactly at h = 1 ms
  with u and θ_m held (`expm` of the augmented system); inputs held at 1 kHz; initial state 0.
  u from the **measured** wind `w_meas` (sensor, 50 ms late) in every column, relative velocity
  `w − v̂_Q − L θ̂̇`, v̂_Q = `nu_c` (the controller's measured velocity).
- **Model parameters:** m_L, L, K of the run; ζ_s **nominal** (0.05) even if a run overrides the
  plant's ζ_s; K_w, U_ref locked (§0.10).
- **Column wind `w_sig`:** the output of `W_sel` - the wind the column's own wind model uses
  (sensor / PI-MoE with PredDelay / oracle at OracleTauMs). Held over the horizon
  `P2N6TauMs` = τ_6\* for every N6 column (O6_0: oracle 0 ms, propagation τ_6\*, §18.2).
- **Gate (implementation choice, stated here before any run):** the term is applied only while
  `wind_pred_on · wvalid ≥ 0.5` (the `WD_gate` signal, tapped as `p2_wgate`) - i.e. only
  while the controller uses its wind model at all; before the first prediction (t < 30.05 s)
  no column has a wind model and the N6 term is 0 in every column alike.
- **Report:** payload swing θ RMS per column = RMS of θ = acos(−q_z) over t ≥ TStat
  (`p2_summary.theta_rms_stat_deg`), pooled (RMS) over the one set; log `p2_n6_log` =
  [θ̂_x θ̂_y Δ_x Δ_y gate] at 100 Hz.
- **Runners:** `run_p2_gd6('N0W6', 'TauPred', 0)` (N0W-6: O_6(τ) with oracle AND propagation
  horizon τ; coarse 0:20:400 ms, one edge extension, fine ±20 ms, τ = 0 a floor, argmin on
  S_c; no O(150) point) → `results/gd6/n0w6_p2.mat`; `run_p2_gd7('N6', 'TauW', τ_6*, 'TauPred',
  0, 'Sha', '43226c02…')` - columns L3_6, P_6, O_6, O6_0, L3; gate on h_6, c_6 (§0.6 tests);
  report-only 1 − L3_6/L3 and θ RMS.
- **Off = unchanged (checked before N0W-6, `experiments/gd7_n6_prep.m`):** v1 (verify_repro,
  146/146, D2 row 1) and P2 at **full precision** on two saved segments - N5-H-StrongRel
  `wind_real_t150_i0384` (L3 P O O0) and N4b-P2-base `wind_real_t150_i0000` (P O O0 O150); any
  difference → STOP.
- Code check (Octave, synthetic wind, UAV held, DO = true force + noise, not a dev number):
  observer error 4.7 % of θ RMS (12.4°); with the oracle over 200 ms the channel's prediction
  of the cable force 200 ms ahead has RMS error 0.054 N vs 0.27 N for the present estimate.

## 25. N6 block built; off = unchanged; N0W-6 result (2026-09-27) - facts
**Build** (`build_p2_plant('Save', true)`, git `3fd031d`, R2022b): teardown 31, steps [1]-[6],
tidy_layout connectivity OK in every diagram; compile clean with no algebraic loop in all
5 states (plant_model 0; P2 nominal; P2 GD3 switches off; **P2 with the N6 term on**; 0 again).
P2 fingerprint **`5ac8ad704e87be08318f96014f1816daaa887e8716293f086aa09e35eea4ffc2`** (was
`b0cca7bd…`; changed by design: the N6 blocks). The rebuilt `baseline1.slx` must be committed
before the N6 group runs (SNAPSHOT MD5 updated then).
**Off = unchanged** (`gd7_n6_prep`, log `results/gd7/n6prep_20260927_152153.txt`):
- v1: `verify_repro` 32 cells 0.000e+00; `check_results_numbers` 146/146; D2 row 1 unchanged.
- P2 with p2_n6 = 0, full precision against the saved results: N5-H-StrongRel
  `wind_real_t150_i0384` L3 0.010084593312371307, P 0.013396028871434333, O
  0.0059796207698754331, O0 0.0072409916502292537; N4b-P2-base `wind_real_t150_i0000` P
  0.014586880376206812, O 0.013857092092320535, O0 0.013875309621934695, O150
  0.013882119585891119 - **8 of 8 bit-exact** (|d| = 0, same flags).
- N6 on, smoke test (dry run, i0000): O_6 at τ 0 / 200 ms = 0.0088 / 0.0038 m; no crash.
**N0W-6** (§18.2; hover, K 0.5, L 1.0, TauPred 0, A4 fixed-5, oracle AND propagation horizon τ;
48.7 min; `results/gd6/n0w6_p2.mat`). Pooled O_6(τ) [m], all 5 segments valid at every τ:

| τ [ms] | 0 | 20 | 40 | 60 | 80 | 100 | 120 | 140 | 160 | 180 | 200 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| O_6 | 0.0172 | 0.0162 | 0.0153 | 0.0143 | 0.0133 | 0.0123 | 0.0113 | 0.0103 | 0.0094 | 0.0085 | 0.0077 |

| τ [ms] | 220 | 240 | 260 | 270 | **280** | 290 | 300 | 320 | 340 | 360 | 380 | 400 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| O_6 | 0.0069 | 0.0063 | 0.0059 | 0.0057 | **0.0057** | 0.0057 | 0.0058 | 0.0060 | 0.0065 | 0.0071 | 0.0078 | 0.0086 |

Coarse minimum 280 ms (not at the edge); fine 260-300 ms at 10 ms → **τ_6\* = 280 ms**
(transcribed here; used as TauW of the N6 group, §18.2). Per segment O_6(0) / O_6(τ_6\*):
i0000 0.0088 / 0.0030, i0251 0.0342 / 0.0108, i0453 0.0076 / 0.0037, i0705 0.0127 / 0.0045,
i0900 0.0017 / 0.0012.
Recorded (fact, not read): at τ = 0 the N6 term is identically zero (Φ(0) = I, Γ(0) = 0), so
the τ = 0 point is the plain oracle column without N6; O_6(τ_6\*) is 67 % below it on the
fixed-5. This is not a gate number (the gate is h_6 = 1 − O_6/L3_6 on N6_hover, where L3_6
carries the same N6 term with the measured wind).

## 26. Registered 2026-09-27, before the N6 group runs (user decisions) - side reports and H-hover
None of these changes a CỔNG G verdict or the gate definition (§0.6); they are reported beside.
Common definition - **unsaturated subset**: the segments of a group's one set whose
`tilt_sat_frac` (fraction of the whole run with the tilt command at the 30° clamp, §22.1) is
**< 1 % in every column run on that segment**; printed with its n and days; the §0.2 statistics
(SE by paired delete-one-day jackknife, LOO, by-day median) and the §0.6 data-sufficiency
rule reported beside. On this subset the §0.6 quantities are **descriptive** (c is printed even
without headroom).

### 26.1 N6 side report (group #10) - registered BEFORE the N6 group runs
- Beside the gate numbers (full one set): `h_6 = 1 − O_6/L3_6` and `c_6` **on the unsaturated
  subset**.
- Two values kept apart, on the full one set and on the unsaturated subset:
  - `h_model = 1 − pooled(L3_6)/pooled(L3)` - value of the wind → payload channel model driven
    by the **measured** wind (no advance knowledge);
  - `h_6 = 1 − pooled(O_6)/pooled(L3_6)` - value of **advance knowledge** on top of that model.
  (`1 − O_6/L3 = 1 − (1 − h_model)(1 − h_6)`; the two multiply.)
- Report only; the N6 gate stays §15.4 / §0.6 on the full one set.

### 26.2 #11 `N5-A-StrongRel`, #12 `N5-H-StrongRel` - the same side report, **post hoc**
h and c on the unsaturated subset, computed from the saved results (no new run), labelled
**"post hoc"** in every table: defined on 2026-09-27, after both groups' results were seen
(§22, §23). Descriptive only; the registered verdicts (NO) stand.

### 26.3 Amendment to §0.6.1: claim H-hover carried to CONFIRM2
- **Origin (stated):** a hypothesis formed **post hoc** from #12 (§23: pooled h +3.77 %, NO;
  by-day median +41.07 %; pooled dominated by i0258/i0261). Exploratory on the dev set; it is not
  a CỔNG G YES and is carried to CONFIRM2 only as this separately registered claim.
- **Definition (fixed now, identical on CONFIRM2):** hover, K 0, L 1.0, m_p 0.5, nominal P2,
  payload TauPred 0 (τ\*_hover), IM hover (exact-frequency table), τ_w\* = 20 ms (N0W), columns
  L3, O(τ_w\*) (+ P, O(0) reported); U in **0.8-1.0 · U_max** of the hover K 0 envelope, i.e.
  **10.64-13.30 m/s** (U_max 13.30, §6.2); segments restricted to the **unsaturated subset**
  (tilt_sat_frac < 1 % in every column, decided after the run from the logs, by this fixed rule).
- **h** = 1 − pooled(O(τ_w\*)) / pooled(L3) on that subset; SE = paired delete-one-day jackknife
  over the CONFIRM2 days in the subset.
- **Confirmed ⇔ by-day median of h_d ≥ 10 % AND h − 1.65 · SE(h) > 0.** (No capture test: the
  claim is headroom - value of advance knowledge of the wind in hover - not capture by PI-MoE;
  P, c, h_sensor, h_pred, LOO reported beside.)
- Data sufficiency (§0.6): < 15 segments or < 6 days → **NOT CONFIRMABLE**, reported.
- Run once, on the 16 CONFIRM2 days, with a recorded git hash; CONFIRM2 stays closed until GĐ10.

## 27. Results of night 8 (`gd7_night8(0.280)`, git `b936501`, 5.8 h) - facts; CỔNG G closes NO
Log `results/gd7/night8_20260927_173157.txt`; `results/gd7/N6.mat` (user's machine). Model
`baseline1.slx` MD5 `61529E3DD30F3CD40D36CF160E65332E` (SNAPSHOT). Step 0: `verify_repro` 32 cells
0.000e+00, 146/146, D2 row 1 unchanged.
**N6-M0 e2 at τ_6\* = 280 ms (offline, §18.2):** e1 ≤ 10 % on the 3 segments with θ RMS ≤ 10°
(2.5 %, 2.4 %, 0.6 %) → PASS stands; e2 = 21.7 %, 21.4 %, 29.9 % there (the model's 280-ms
prediction beats "no change"); larger angles: e2 24.7 % (i0251, 12.3°), 26.6 % (i0453, 10.2°),
100.7 % (i0715, 25.4°), 68.6 % (expl i0215, 25.8°), 104.6 % (expl i0134, 25.0°).
**Group #10 N6** (N6_hover, SHA `43226c02…`, 139 segments / 43 days; hover, K 0.5, TauPred 0,
τ_6\* 280 ms): one set **136/139** (43 days) - removed `wind_real_t150_i0264` (diverged in all
five columns), `wind_expl_t150_i0290`, `i0293` (P_6 solver stop at 55.09 s and 183.66 s,
`Attitude_Observer/Int_za`).

| pooled [m] | L3_6 | P_6 | O_6 | O6_0 | L3 (no N6) |
|---|---|---|---|---|---|
| | 0.02024 | 0.02083 | 0.01966 | 0.01983 | 0.02476 |

| statistic | value | SE | LOO [min, max] | by-day median | most influential |
|---|---|---|---|---|---|
| **h_6 = 1 − O_6/L3_6** | **+2.87 %** | 3.52 | [−0.84, +2.91] | −2.60 % | expl i0215 |
| c_6 | −101.66 % | 3052 | [−101.87, +2637.70] | +362.23 % | expl i0215 |
| L3_6 − P_6 [m] | −0.00059 | 0.00049 | [−0.00110, −0.00057] | −0.00067 | expl i0215 |
| h_6,sensor | +2.03 % | 10.47 | [+1.92, +12.78] | +13.35 % | expl i0215 |
| h_6,pred | +0.86 % | 15.92 | [−15.62, +0.92] | −18.23 % | expl i0215 |
| h_model = 1 − L3_6/L3 (report, §26.1) | +18.24 % | 39.39 | [+17.72, +58.44] | +59.31 % | expl i0215 |

Payload swing θ RMS (t ≥ 140 s, pooled): L3_6 10.16°, P_6 10.16°, O_6 10.11°, O6_0 10.15°,
L3 10.15°. Evaluable (n 136, 43 days). **Headroom: NO** (h_6 < 10 %, LOO sign not kept,
by-day median < 5 %) → c_6 not evaluated → **#10 counts NO**.
**Recorded (facts, not read):**
- `wind_expl_t150_i0215` (U 10.56, θ RMS 25.8° in N6-M0) dominates every pooled statistic:
  L3_6 0.2290, L3 0.2534 m against ≈ 0.001-0.01 m for most segments.
- The N6 term with the **measured** wind lowers the error on almost every segment (h_model
  by-day median +59.31 %, pooled +18.24 %; LOO max +58.44 % without i0215); knowing the
  future wind adds nothing measurable on top (h_6,pred pooled +0.86 %, by-day −18.23 %;
  O6_0 ≤ O_6 on most segments).
- The N0W-6 gain (O_6 67 % below the τ = 0 point, §25) is thus the model's own 280-ms
  propagation, not advance knowledge: at τ = 0 the propagation is also 0.
- The term does not change the payload swing (θ RMS 10.1-10.2° in every column).
- Column P again loses expl i0290 / i0293 (§20.6 caveat, P-QA pending).
**CỔNG G = NO** (§0.6): every evaluable registered group - #1, #2, #4, #5, #6, #7, #8, #9, #10,
#11, #12 - has no headroom; #3 empty (A2). Consequence registered in §0.6 (KE_HOACH GĐ7):
payload prediction + IM-est are the main contribution; wind prediction is a negative result
with a map of conditions (final framing D5, the user). Still due: the §26 side reports
(`run_p2_gd7(<group>, 'Side', true)` for N6, N5-A-StrongRel, N5-H-StrongRel - from saved
results), P-QA (§21, now: after GĐ7), H-hover on CONFIRM2 (GĐ10), D2 columns L1/F2/VP.

## 28. Registered 2026-09-27 after night 8, before CONFIRM2 is opened and before any N6X run
**Main exploratory finding (user, 2026-09-27; not a gate):** in hover (N6 group, §27)
`h_model = 1 − L3_6/L3` = **+18.2 % pooled, +59.3 % by-day median** - the gain comes from the
pendulum model propagated 280 ms with the **measured** wind, not from advance knowledge
(h_6,pred +0.86 %).

### 28.1 Amendment to §0.6.1: claim H-model carried to CONFIRM2
- **Origin (stated):** exploratory, night 8 (§27), dev set. Not a CỔNG G claim.
- **Definition (identical on CONFIRM2):** hover, K 0.5, L 1.0, m_p 0.5, nominal P2, payload
  TauPred 0, IM hover (exact-frequency table), sensor delay 50 ms; columns **L3** (g_psens, no N6
  term) and **L3_6** (the same + the N6 term of §24 with the measured wind, horizon **280 ms**,
  observer and gate as built, model `baseline1.slx` MD5 `61529E3D…` or a bit-exact successor);
  segment set = the `N6_hover` definition (P2 hover envelope at K 0.5, U ≤ 10.86 m/s, cap 4 per
  day) applied to the CONFIRM2 days, printed before the run; one-set rule (§0.4) over both columns.
- **h_model = 1 − pooled(L3_6)/pooled(L3)**; SE = paired delete-one-day jackknife over the
  CONFIRM2 days in the set.
- **Confirmed ⇔ by-day median of h_model,d ≥ 10 % AND h_model − 1.65 · SE(h_model) > 0.** LOO,
  the unsaturated-subset value (§26) and θ RMS reported beside, not part of the test.
- Data sufficiency (§0.6): < 15 segments or < 6 days → **NOT CONFIRMABLE**, reported.
- Run once on the 16 CONFIRM2 days with a recorded git hash; CONFIRM2 stays closed until GĐ10.

### 28.2 Exploratory block N6X - does the pendulum-model term add BEYOND the DO payload prediction under forced oscillation?
Exploratory, **not a gate**; registered before any N6X run; nothing here is carried to CONFIRM2.
- **Term:** the N6 term of §24 unchanged (observer on the raw DO estimate, measured wind, gate,
  nominal ζ_s), **added on top of the payload predictor output** (PP_Switch at the trajectory's
  TauPred) - i.e. column **L3_6 = g_psens + p2_n6 = 1**. Stated limitation, fixed now: the model
  is the UAV-held linear pendulum (no UAV-acceleration input); under a trajectory the forced part
  of the swing is left to the DO/IM predictor, and the term adds the model's free + wind response
  over τ_m. That is exactly what is tested.
- **Conditions (K 0.5, L 1.0, m_p 0.5, nominal P2, sensor delay 50 ms, PredDelay):**

  | block | trajectory | set (cap 4, SHA) | IM | TauPred | τ_m |
  |---|---|---|---|---|---|
  | `N6X-circle` | circle (`Test 4`) | `circle_main`, 134 seg, `a227e9d87a2ac436` | DoHarm [0 1] | 0.290 s | **290 ms** |
  | `N6X-T5` | T5 (`Multisine`) | `T5_main`, 134 seg, `4a933e516acfcb10` | exact-frequency table | 0.170 s | **170 ms** |
- **Columns:** L3 (no term) and L3_6 (term at τ_m). L3 of `N6X-circle` reused from N4b-P2-base
  after the §15.1 spot check (same configuration); `N6X-T5` runs both.
- **Horizon check N0M (before the groups):** L3_6(τ) on the A4 fixed-5 per trajectory, the N0P/N0W
  procedure (coarse 0:20:400 ms, one bounded edge extension, fine ±20 ms at 10 ms; τ = 0 is the
  plain L3) → τ_m\*. Reported. If |τ_m\* − τ_m| ≥ 50 ms, a second pass `N6X-<traj>-tm` runs L3_6 at
  τ_m\* on the same set (L3 reused from the first pass), **reported as a second number, labelled
  "horizon chosen on the fixed-5"**; the first pass (τ_m fixed above) is the primary number.
- **Report (descriptive, §0.2 statistics):** pooled L3, L3_6; **h_model = 1 − L3_6/L3** (SE, LOO,
  by-day median, most influential), on the full one set and on the unsaturated subset (§26); θ RMS
  per column; removed segments.
- **Order:** after the §26 side reports, before P-QA; cost ≈ N0M 2 × 26 τ × 5 = 260 column-runs
  (~2 h) + `N6X-circle` 134 (L3 reused) + `N6X-T5` 268 ≈ 400 column-runs (~3 h).

## 29. §26 side reports (2026-09-27, git `018304d`, from the saved results - nothing run) - facts
Unsaturated subset = one-set segments with tilt_sat_frac < 1 % in every column (§26).

**N6 (#10) - §26.1, registered before the run.** One set 136 / 43 days; unsaturated 122 / 41
days (14 left out: real i0251 0.234, i0649 0.079, i0715 0.019; expl i0006 0.129, i0011 0.053,
i0115 0.048, i0120 0.084, i0134 0.043, i0151 0.021, i0215 0.253, i0321 0.167, i0326 0.183,
i0356 0.025, i0428 0.347 - max tilt_sat_frac over the columns).

| N6 | L3_6 | P_6 | O_6 | O6_0 | L3 | h_6 (SE; LOO; by-day) | c_6 (descr.) | h_model = 1 − L3_6/L3 (SE; LOO; by-day) |
|---|---|---|---|---|---|---|---|---|
| full | 0.02024 | 0.02083 | 0.01966 | 0.01983 | 0.02476 | +2.87 % (3.52; [−0.84, +2.91]; −2.60) | −101.7 % | +18.24 % (39.39; [+17.72, +58.44]; +59.31) |
| unsaturated | 0.00347 | 0.00437 | 0.00361 | 0.00301 | 0.00898 | **−4.03 %** (0.89; [−4.46, −3.60]; −2.60) | +643.4 % | **+61.38 %** (1.47; [+60.20, +61.59]; +59.86) |

Recorded (facts, not read): on the unsaturated subset h_model is +61.4 % with SE 1.5 % and a
LOO range of 1.4 points (the full-set pooled value is pulled down by the saturated segments,
chiefly expl i0215); O_6 (true wind 280 ms ahead) is **worse** than L3_6 (h_6 −4.0 %), while
O6_0 (true current wind) is better (1 − O6_0/L3_6 = +13.3 %); P_6 is worse than L3_6 in both
sets (L3_6 − P_6 < 0 under every LOO).

**#11 N5-A-StrongRel - §26.2, POST HOC.** One set 42 / 13 days; unsaturated 23 / 9 days (19 left
out, tilt_sat_frac 0.014-0.173). Full: h +5.83 % (NO, the registered verdict), c −46.8 %.
Unsaturated (POST HOC): L3 0.00754, P 0.00835, O 0.00645, O0 0.00675; **h +14.40 %** (SE 2.09;
LOO [+13.72, +15.03]; by-day +12.95 %); c −74.3 %; L3 − P −0.00081 m.

**#12 N5-H-StrongRel - §26.2, POST HOC.** One set 19 / 10 days; unsaturated **10 / 5 days (below
the data-sufficiency rule)** (9 left out, tilt_sat_frac 0.015-0.317). Full: h +3.77 % (NO), c
−50.2 %. Unsaturated (POST HOC): L3 0.00793, P 0.00985, O 0.00464, O0 0.00566; **h +41.52 %**
(SE 0.15; LOO [+41.44, +41.63]; by-day +41.47 %); c −58.1 %; L3 − P −0.00191 m.

Recorded (facts, not read): on every unsaturated subset P is worse than L3 (c < 0), so where
headroom appears it is not captured by PI-MoE. For the registered claim H-hover (§26.3, same
definition as #12's unsaturated subset): the dev set yields 10 segments / 5 days out of 46 dev
days; CONFIRM2 has 16 days - stated here, not acted on (the claim stays as registered).
CỔNG G verdicts unchanged.

## 30. Registered 2026-09-27 (user decisions): sensitivity set S40; reviewer-matrix blocks
Reference list of every case: `docs/devlog/REVIEWER_MATRIX.md` (codes A1-N). Gates and main
claims keep the full registered sets; **every sensitivity table uses S40**. Each block of the
matrix schedule (nights 10-15) is registered separately before it runs (reading = exploratory /
sensitivity, not a gate), with a dry run and an hour estimate.

### 30.1 Sensitivity set S40 (registered before any use)
- Source: `circle_main` at cap 4 (134 segments, 42 days, SHA `a227e9d87a2ac436`).
- Days: sorted by date; 40 taken at indices `round(linspace(1, 42, 40))`.
- One segment per taken day: for the j-th taken day (j = 1..40) the segment whose start time of
  day (`real_t0` + `real_offset_s`, read from the segment file) is nearest, in circular distance on
  the 24 h clock, to `(j − 0.5)/40 · 24 h`; ties → lower measurement height, then file name.
- Uses no wind value and no result. Code `p2_segset('S40')` (Octave test on a mock pool:
  40 segments / 40 days, deterministic). **Its SHA-256 is printed on the user's machine and
  transcribed here before the first S40 run.**
- **Printed 2026-09-27 (git `0fdc844`, from circle_main SHA `a227e9d87a2ac436`): 40 segments, 40
  days, SHA-256 `1db1de02532a38965fbcd85b249059dd9324990c47575258bb9e0b1d5dc36de0`.** (Transcribed;
  runners check this value.)
- Fact about the data (not a change of rule): the segment start times in circle_main fall in four
  slots only (≈ 02, 08, 14, 20 h), so the rule picks the slot nearest each target; S40 holds 11 / 10
  / 6 / 13 segments in those slots. S40 contains `wind_real_t150_i0251` (the §12 tilt-clamp
  segment) and `wind_expl_t150_i0290` (a column-P divergence, §20); they stay (the rule uses no
  result).
- Members: real i0000, i0131, i0192, i0251, i0327, i0452, i0453, i0578, i0643, i0705, i0770, i0833,
  i0900; expl i0017, i0018, i0025, i0054, i0071, i0072, i0086, i0112, i0128, i0145, i0162, i0179,
  i0201, i0219, i0233, i0244, i0249, i0277, i0290, i0294, i0327, i0355, i0373, i0385, i0399, i0420,
  i0439.

## 31. Results of night 9 (`gd7_night9`, git `0fdc844`, 7.5 h) - N6X, exploratory (§28.2) - facts
Log `results/gd7/night9_20260927_235324.txt`; `results/gd6/n0m_{circle,T5}_p2.mat`,
`results/gd7/N6X-{circle,T5}[-tm].mat` (user's machine). Step 0: `verify_repro` 32 cells 0.000e+00,
146/146, D2 row 1 unchanged.

**N0M (L3_6(τ) on the A4 fixed-5; τ = 0 is the plain L3), pooled [m]:**

| τ [ms] | 0 | 20 | 40 | 50 | 60 | 70 | 80 | 100 | 140 | 200 | 280 | 300 | 400 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| circle (TauPred 290) | 0.0228 | 0.0215 | 0.0207 | **0.0206** | 0.0206 | 0.0208 | 0.0212 | 0.0225 | 0.0269 | 0.0362 | 0.0508 | 0.0545 | 0.0729 |
| T5 (TauPred 170) | 0.0198 | 0.0190 | 0.0185 | 0.0183 | 0.0182 | **0.0182** | 0.0183 | 0.0186 | 0.0200 | 0.0230 | 0.0278 | 0.0291 | 0.0352 |

→ **τ_m\*(circle) = 50 ms, τ_m\*(T5) = 70 ms** (not at an edge). Both ≥ 50 ms from the registered
τ_m (290, 170) → the second pass (`-tm`) ran, as registered. On the fixed-5 only i0251 improves
strongly at τ_m\* (circle 0.0422 → 0.0356, T5 0.0380 → 0.0310); i0000/i0900 get worse.

**Groups (one set 134/134, 42 days; unsaturated subset circle 121/40, T5 127/41):**

| block | τ_m | L3 | L3_6 | h_model full (SE; LOO; by-day) | h_model unsaturated (SE; by-day) | θ RMS L3 / L3_6 |
|---|---|---|---|---|---|---|
| **N6X-circle** (primary) | 290 ms | 0.01802 | 0.05704 | **−216.5 %** (81.0; [−283.1, −215.5]; −345.6) | −345.0 % (13.1; −363.4) | NaN / 16.66° |
| N6X-circle-tm (τ on fixed-5) | 50 ms | 0.01802 | 0.01780 | +1.24 % (2.46; [−0.14, +1.30]; −3.94) | −4.43 % (0.93; −5.20) | NaN / 16.61° |
| **N6X-T5** (primary) | 170 ms | 0.01266 | 0.02103 | **−66.2 %** (16.5; [−71.9, −65.7]; −106.6) | −84.8 % (14.1; −113.7) | 15.21° / 13.62° |
| N6X-T5-tm (τ on fixed-5) | 70 ms | 0.01266 | 0.01411 | −11.5 % (5.88; [−13.4, −11.3]; −27.6) | −18.3 % (5.15; −28.3) | 15.21° / 14.49° |

Unsaturated subset, from the same log (added 2026-09-28, transcription only): L3 / L3_6 pooled and
LOO - circle 0.01270 / 0.05653, LOO [−349.7, −343.8] %; circle-tm 0.01270 / 0.01327, LOO [−4.83,
−4.34] %; T5 0.01135 / 0.02097, LOO [−93.7, −84.3] %; T5-tm 0.01135 / 0.01343, LOO [−21.5, −18.1] %.
Most influential: full set circle `i0306`, T5 `i0307`; unsaturated circle `i0017`, T5 `i0307`.

(L3 of N6X-circle reused from N4b-P2-base after the spot check, |d| 5.13e-08, printed digits
equal; its saved p2 summary predates `theta_rms_stat_deg`, hence NaN. No segment removed.)

**Answer to the §28.2 question (exploratory, descriptive):** under forced oscillation the
N6 term (UAV-held linear pendulum, measured wind) does **not** add beyond the DO payload
prediction: at the registered τ_m it raises the error 3.2× on circle and 1.7× on T5; at the
horizon chosen on the fixed-5 it is neutral on circle (+1.2 % full, −4.4 % unsaturated, by-day
−3.9 %) and still worse on T5 (−11.5 %). Recorded (facts, not read further):
- the term lowers the error only on the high-error segments (circle-tm: i0251, i0151, i0184,
  i0304, i0306, i0317; T5: i0251, i0151, i0304, i0307, i0326) and raises it on the calm ones;
- on T5 it lowers the payload swing (θ RMS 15.2° → 13.6°) while raising the tracking error;
- consistent with the limitation stated in §28.2 (no UAV-acceleration input): the model's
  free response over τ_m competes with the forced response the DO/IM predictor already carries.
The hover result (§27, §29: h_model +61.4 % unsaturated) and the claim H-model (§28.1) are
unaffected: they concern hover only.

## 32. Night 10 - the T3b table (REVIEWER_MATRIX A4) - registered 2026-09-28, before any run
Exploratory / descriptive (§30): **not a gate**; the numbers are recorded verbatim, no verdict.
One table per trajectory (§6.4); the columns are the D2 columns, so the table reads side by side
with circle's (§10, §17.3).

- **Set:** `T3b_main`, cap 4 per day: 134 segments, 42 days, SHA `35bed7710bf224ee` (§6.3.1; the
  runner asserts it).
- **Condition:** `Fig8 off-res` (A 1.13, ω 0.7875 rad/s; §4.4, REGISTER_C §3), nominal P2 as §7
  (τ_m 17 ms, discrete, sensors, wind-sensor delay 50 ms, `PredDelay`), K 0.5, L 1.0,
  `PayloadModel 1`, `OnDiverge 'flag'`.
- **Columns (4):**
  - **L0** Guo MOBADC as published: `g_base`, `DoHarm 1` (one harmonic at the condition's
    `payload_sigma` = 0.7875 on every axis - it does not hold the y-axis's 2ω; that is the
    published structure, stated as a fact, not changed);
  - **L2** `g_sens`, **L3** `g_psens` at `TauPred` = τ\*_T3b = **0.340 s** (§9.2), **V** `g_sens` at
    `TauPrev` = τ_prev\*(T3b) (below); L2/L3/V at the exact-frequency table
    `im_oracle_axis(T3b)` = {0, ω} x, {0, 2ω} y, {0, ω} z - the IM N0P T3b used.
  - Not in this table, stated now: L3_6 (§31: the N6 term does not add under forced oscillation;
    it would also need an N0M T3b); P / O columns (CỔNG G closed, §27); L1 / F2 / VP (user decision:
    last, with D2's).
- **Step 1 - N0V T3b** (before the table, same night): the §7.1 procedure unchanged (column V =
  `g_sens`, `TauPrev` 0:20:400 ms, one bounded edge extension, fine ±20 ms at 10 ms; τ = 0 a
  floor) on the A4 fixed-5 → τ_prev\*(T3b). **If it is EDGE-UNRESOLVED or fails, V runs at the
  circle's τ_prev\* = 0.180 s** and the table says so. The value used is printed in the log and
  transcribed here with the results.
- **Per table (§0.2, §6.6):** the one-set rule over the four columns; per column pooled
  `sqrt(mean(m²))`, SE (paired delete-one-day jackknife), by-day median, LOO [min, max], most
  influential segment; the ratios **L3/L2 − 1** (the D2 statistic), **V/L2 − 1**, **L2/L0 − 1**
  with the same statistics (descriptive); `tilt_sat_frac` (median, max, count > 1 %) and motor
  `sat_frac` (median, max) per column; removed segments with their flags.
- **Code:** `run_p2_gd6('TAB', ...)` (the three pa_configs calls of D2 per segment, with the
  trajectory's condition and IM); `run_p2_gd6('N0V', 'Only', {'T3b'})`; night script
  `gd7_tab_night('T3b')` (step 0 = the usual checks, STOP on failure). The circle D2 path is not
  touched (its row-1 check runs in step 0). Octave mock test: T3b / square set and IM selection,
  L0 without the table, resume key, SHA guard, one-set removal, N0V T3b and N0V circle unchanged.
- **Dry run** (1 segment, nothing saved, ~4 min):
  `run_p2_gd6('N0V', 'Only', {'T3b'}, 'DryRun', true)` and
  `run_p2_gd6('TAB', 'Only', {'T3b'}, 'TauPred', 0.340, 'TauPrev', 0.180, 'DryRun', true)`.
- **Hours** (night-2 measure ~27 s per column-run; D2 101 s per segment for 3 calls): N0V 130
  runs (+15 if extended) ≈ **1.0 h**; table 134 × ~101 s ≈ **3.8 h**; checks ~0.2 h → **≈ 5 h**.
- **Approved by the user (2026-09-28):** "T3b: bỏ L3_6 đồng ý (quỹ đạo tuần hoàn trơn, như
  circle/T5)".

## 33. Night 11 - the square table with column L3_6 (REVIEWER_MATRIX A5) - registered 2026-09-28, before any run
User decision (2026-09-28): the square keeps L3_6. Unlike circle / T3b / T5 (smooth periodic
references), the square's reference acceleration switches on and off at every corner (min-jerk
edges, dwell at the corners: the payload is excited by a non-periodic sequence of pulses, which a
DO with a sinusoidal internal model captures less well). **Question (exploratory, not a gate):
does the pendulum-model term (N6, measured wind) add beyond the DO payload prediction on the
square?** Everything of §32 applies unless changed here.

- **Set:** `square_main`, cap 4: 134 segments, 42 days, SHA `a227e9d87a2ac436` (= circle_main, §6.3).
- **Condition:** `Square` (D 1.3036 m, edge T 1.9399 s, dwell T_h 1.0 s; cycle 2.9399 s per corner),
  nominal P2 as §32, K 0.5, L 1.0.
- **Columns (5):** L0 L2 L3 V as §32 (`TauPred` = τ\*_square = **0.120 s**, §9.2; IM =
  `im_oracle_axis(square)`; V at τ_prev\*(square) from step 1, fallback 180 ms as §32) **+ L3_6** =
  L3 with the N6 term on (`P2N6`, measured wind through the column's own wind path, §24/§28.2),
  propagation horizon **τ_m\*(square)** from step 2. Same TauPred, IM, everything else as L3.
- **Step 1 - N0V square** (§32 procedure) → τ_prev\*(square).
- **Step 2 - N0M square** (the §28.2 procedure, `run_p2_gd6('N0M', 'Only', {'square'}, 'TauPred',
  0.120)`): L3_6(τ) on the A4 fixed-5, coarse 0:20:400 ms, one bounded extension, fine ±20 ms;
  τ = 0 is the plain L3 (a floor) → τ_m\*(square). **Used directly** as L3_6's horizon (no
  second pass: here τ_m\* is the registered horizon). If τ_m\* = 0: L3_6 ≡ L3, not run, h_model = 0
  by construction, reported. If EDGE-UNRESOLVED or failed: L3_6 not run, reported.
- **One set:** the one-set rule over all five columns (§0.2). **Unsaturated subset:**
  `tilt_sat_frac` < 1 % in both L3 and L3_6 (as §26.1 / §31, whose two columns were these).
- **Main quantity:** h_model = 1 − L3_6/L3 (pooled `sqrt(mean(m²))`), on the one set and on the
  unsaturated subset, each with SE (paired delete-one-day jackknife), by-day median, LOO [min,
  max], most influential segment; L3 and L3_6 pooled; payload swing θ RMS (t ≥ TStat) of both.
- **Reading, fixed now (applied separately to the one set and to the unsaturated subset, both
  printed; if they differ, both are recorded, neither overrides):**
  - h_model ≤ 0 → **DOES NOT ADD** on the square;
  - h_model > 0 AND every LOO value > 0 AND by-day median > 0 → **ADDS** on the square;
  - otherwise → **UNCLEAR**.
  The magnitude is reported, not thresholded (exploratory; no claim is carried to CONFIRM2 by
  this block - a claim would need its own registration before CONFIRM2 is opened).
- **Side report (not read): corner vs edge windows.** Per segment and column, the mean tracking
  error (pa_configs' `e_t`: ‖γ_d − γ‖ at 10 ms, t ≥ TStat) over two complementary windows of equal
  length, fixed by the reference alone: the **corner window** = the half cycle centred on the middle
  of each dwell (phase T + T_h/2 ± T_c/4, T_c = T + T_h; i.e. the dwell plus the last 0.235 s of the
  arriving edge and the first 0.235 s of the leaving edge), the **edge window** = the other half
  (centred on the middle of each edge, where the reference acceleration peaks). h_model in each
  window, same statistics, one set and unsaturated subset. Printed without a verdict.
- **Code:** `run_p2_gd6('TAB', ..., 'TauN6', τ_m*)` (a fourth pa_configs call per segment for L3_6;
  windows from `e_t`, square only); `run_p2_gd6('N0M', 'Only', {'square'})`; night script
  `gd7_tab_night('square')`. The T3b path is unchanged (same calls, same result key). Octave mock
  test: N0M square → τ_m\*, L3_6 call (`P2N6`, horizon), five-column one set, unsaturated subset,
  reading, corner/edge windows on an injected corner-only effect, SHA guard.
- **Dry run** (1 segment, nothing saved, ~6 min):
  `run_p2_gd6('N0M', 'Only', {'square'}, 'TauPred', 0.120, 'DryRun', true)` and
  `run_p2_gd6('TAB', 'Only', {'square'}, 'TauPred', 0.120, 'TauPrev', 0.180, 'TauN6', 0.050, 'DryRun', true)`
  (0.050 only exercises the path).
- **Hours:** N0V ≈ 1.0 h; N0M ≈ 1.0 h (130 runs, +15 if extended); table 134 × (~101 + ~30) s ≈
  **4.9 h**; checks ~0.2 h → **≈ 7 h**.

## 34. Results of night 10 (`gd7_tab_night('T3b')`, git `28f421a`, 4.9 h) - T3b table (§32), descriptive - facts
Log `results/gd7/tab_T3b_20260928_075221.txt`; `results/gd6/tab_T3b_p2.mat`, N0V row in
`results/gd6/n0p_p2.mat` (user's machine). Step 0: `verify_repro` 32 cells 0.000e+00, 146/146, D2 row
1 unchanged ([0.0414 0.0334 0.0140 0.0136]). Dry runs before (1 segment i0000): N0V τ 0 / 200 ms
0.0210 / 0.0097; TAB L0 0.0451, L2 0.0210, L3 0.0105, V 0.0097 (TauPrev 180 ms).

**Step 1 - N0V T3b (A4 fixed-5, 5/5 at every τ, no edge), pooled [m]:**

| τ_prev [ms] | 0 | 40 | 80 | 120 | 160 | 180 | 190 | 200 | 210 | 220 | 240 | 280 | 320 | 400 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| V | 0.0271 | 0.0243 | 0.0219 | 0.0198 | 0.0185 | 0.0181 | 0.0180 | 0.0179 | **0.0179** | 0.0179 | 0.0182 | 0.0194 | 0.0212 | 0.0261 |

Coarse minimum 200 ms; fine 180-220 ms; **τ_prev\*(T3b) = 210 ms** (argmin on unrounded values; the
curve is flat at 0.0179 over 200-220 ms) → V ran at 210 ms. Consistency: V at τ 0 (0.0271) equals N0P
T3b at τ 0 (0.0271, §9.2) - both are L2 at zero horizon.

**Step 2 - table (`T3b_main`, SHA `35bed7710bf224ee`; TauPred 340 ms, TauPrev 210 ms).** One set
**133/134 segments, 42 days**. Removed: `wind_expl_t150_i0307` - L2, L3, V solver stop
(`Attitude_Observer/Int_za` t = 168.33 s; `UAV_Plant/Int_etadot` t = 187.73 s; `Int_za` t = 194.59 s,
in the order L2, L3, V as printed); L0 completed (0.1304). (i0307 is also the most influential
segment of N6X-T5, §31.)

| column | pooled [m] | SE | by-day median | LOO [min, max] | most influential |
|---|---|---|---|---|---|
| L0 (Guo, DoHarm 1) | 0.04590 | 0.00213 | 0.04005 | [0.04516, 0.04598] | i0251 (real) |
| L2 (sensor) | 0.02178 | 0.00061 | 0.02023 | [0.02152, 0.02180] | i0251 |
| L3 (+ payload pred. 340 ms) | 0.01189 | 0.00112 | 0.00842 | [0.01149, 0.01192] | i0251 |
| V (+ preview 210 ms) | 0.01107 | 0.00113 | 0.00730 | [0.01069, 0.01111] | i0251 |

| ratio (descriptive) | value | SE | by-day median | LOO | most influential |
|---|---|---|---|---|---|
| **L3/L2 − 1** | **−45.4 %** | 3.67 | −57.5 % | [−46.6, −45.3] | i0251 (real) |
| V/L2 − 1 | −49.1 % | 3.81 | −63.2 % | [−50.4, −49.0] | i0165 (expl) |
| L2/L0 − 1 | −52.6 % | 0.91 | −50.2 % | [−52.6, −52.2] | i0165 (expl) |

- `tilt_sat_frac`: median 0 in every column; max 0.245 / 0.253 / 0.252 / 0.253 (L0 L2 L3 V); 6
  segments > 1 % in every column. Motor `sat_frac` 0 everywhere.
- Facts for reading side by side with circle (not a verdict): the D2 statistic on T3b is −45.4 %
  (circle §10: −50.3 %); every LOO value is negative. L2/L0 mixes two changes (IM: L0's one
  harmonic at 0.7875 on every axis vs the exact table with 2ω on y; and the wind-sensor path), so it
  is not attributable to the sensor alone.

## 35. Result of checkpoint P-QA (§21; `p_qa`, git `28f421a`) - facts, reading verbatim
Output `results/pqa/p_qa_20260928_074859.{mat,csv}` + `p_qa_segments_…csv` (user's machine).
Population 471 segments (assert passed), 1 599 516 prediction samples.

- Thresholds: T_norm 5.139 m/s (literal); **T_phys = p99.9(Δw) = 2.6000 m/s; T_in = p99.9(Δm) = 2.6000 m/s**.
- Pooled quantiles [m/s] (p50 / p90 / p99 / p99.9 / max): Δŵ 0.0758 / 0.2972 / 0.7937 / 1.7613 /
  **12.6849**; Δw 0.1122 / 0.4456 / 1.1935 / 2.6000 / 9.6770; Δm identical to Δw at every quantile;
  ratio Δŵ/Δw 0.676 / 0.667 / 0.665 / 0.677 / 1.311.
- Base rate of B zones 3.50 % of all prediction samples; Spearman(Δŵ, entry input step) **0.827**.
- Events Δŵ > T_phys: 914 in 51 segments - B 4.9 %, I 92.7 %, U 2.4 % (reported, not read).
- **Events Δŵ > T_norm: 251 in 12 segments - B 8.4 % (21), I 91.6 % (230), U 0 %.**
- Diverging segments of column P: `i0290` 64 events > T_phys, max Δŵ 12.685 m/s (= §20.6's A4 value);
  `i0293` 117 events, max 9.922 m/s; both mostly I (i0290 has 22 B = held input at 151-169 s).

**READING (§21, as printed): PI-MoE PROPERTY (I share ≥ 50 %) - out-of-distribution response to
noisy input; into the paper.** *[note §43: "noisy input" here can only mean steps in the exported M5 series itself -
the P2 wind sensor adds no noise (§43.1); §36-38 characterise those steps. The verdict is not re-read.]* Not an export error → no re-export, column P is not re-run.

Facts recorded with the reading (from the printout and the code; they do not change it):
1. **In the exported files `w_meas` ≡ `w_plant`** (`export_wind_sim.py --sensor-noise` default 0;
   ~~the P2 sensor noise and 50 ms delay are applied inside the model~~ **[corrected §43: only the 50 ms delay
   (and the 20 Hz hold) is applied inside the model; there is no wind-sensor noise anywhere on P2]**). Hence Δm = Δw exactly and
   T_in = T_phys. The "input steps" of class I are steps of the exported wind series itself, which
   the plant also receives; P-QA cannot separate spikes of the M5 sonic record (despiking off, QC
   only rejects steps > 10 m/s per 50 ms, §21) from physical gusts. The PI-MoE model was trained
   on the same kind of series.
2. Concentration: 231 of the 251 events > T_norm lie in six consecutive exploration segments
   `i0288`-`i0293` (3 / 50 / 28 / 22 / 71 / 57); the rest: i0130 10, i0131 5, i0127 2, i0060, i0132,
   i0402 1 each. From `d_file` the six have raw offsets 200 / 0 / 200 / 400 / 0 / 200 s, i.e. windows
   of the same kind of M5 10-min file(s) at the two heights (file identity not printed here).
3. Signature: the events come in pairs 50 ms apart; the entry input step is clustered at 5.0-6.3
   m/s with a small exit step (typ. < 0.3 m/s) - the shape of single-sample spikes in the input
   series (description, not a reading).
4. The true-wind step distribution itself has p99.9 = 2.6 m/s per 50 ms and max 9.68 m/s.

## 36. P-QA follow-up: single-sample spikes vs real gusts (user decision (b), 2026-09-28) - registered before any computation
Characterises the class-I steps of §35. It does **not** change the §21/§35 reading, the export or
the pipeline, and nothing is re-run. Offline, no simulation. Code `analysis/pqa_spikes.m`.
Wording for the paper, fixed (user): **"phản ứng ngoài phân bố của PI-MoE với các bước nhảy một mẫu
trong chuỗi gió"** / "out-of-distribution response of PI-MoE to single-sample steps in the wind series".

- **Population:** the 471 segments of §21 (no held-out / CONFIRM / CONFIRM2 file). Read per segment:
  `w_plant` (20 Hz), `real_file`, `real_height_m`, `real_offset_s`. **"Raw M5 file"** = one
  (`real_file`, `real_height_m`) pair, seen through its exported 200 s windows (coverage printed; a
  window dropped by the export's QC is not seen). The export's `w_plant` is that window's 20 Hz
  series rotated in the horizontal plane (horizontal norm unchanged), no despiking.
- **Definitions** (horizontal norm, whole 0-200 s of each segment):
  - jump at sample j: d_j = ‖w(j) − w(j−1)‖ ≥ **5 m/s**;
  - **spike** = a jump that returns within 1-2 samples: min over k ∈ {1, 2} of ‖w(j+k) − w(j−1)‖ ≤
    0.5 · d_j; the returning step(s) are not counted as new jumps;
  - every other jump = non-spike jump; a **spiked segment** holds ≥ 1 spike.
- **Printed:** the 12 segments of §35 (file, `real_file`, height, day, offset, spikes, jumps); per raw
  file: coverage, spikes, spikes per hour; the 20 raw files with most spikes; quantiles (p50 / p90 /
  p99 / max) of spikes per hour over all raw files; the rank of the 12 segments' raw files.
- **Summary numbers:** A = spikes / all jumps (spike share); C = (smallest number of raw files that
  hold ≥ 80 % of all spikes) / (number of raw files in the population).
- **Reading (fixed now):**
  - A ≥ 0.8 AND C ≤ 0.05 → **SENSOR SPIKES** (sonic-anemometer spikes; a data limitation);
  - A < 0.5 OR C > 0.2 → **REAL GUSTS**;
  - otherwise → **UNCLEAR**, reported to the user, who decides;
  - no jump at all → nothing to classify, reported.
- **Only if SENSOR SPIKES - POST HOC sensitivity (labelled so, never a gate, no re-run):** from the
  saved results, each without the spiked segments, beside the registered value, with n, days, SE
  (day jackknife), LOO, by-day median:
  - D2: L3/L2 − 1 on the one set of `results/gd6/d2_p2.mat` (L0 L2 L3 V);
  - T3b: L3/L2 − 1 and V/L2 − 1 on the one set of `results/gd6/tab_T3b_p2.mat`;
  - N6 (group #10, `results/gd7/N6.mat`): h_model = 1 − L3_6/L3 on the one set and on its
    unsaturated subset (tilt_sat_frac < 1 % in every column, as §26.1).

## 37. Results of night 11 (`gd7_tab_night('square')`, git `b756c3f`, 11.8 h) - square table + L3_6 (§33), descriptive - facts
Log `results/gd7/tab_square_20260928_130259.txt`; `results/gd6/tab_square_p2.mat`,
`results/gd6/n0m_square_p2.mat`, N0V row in `results/gd6/n0p_p2.mat` (user's machine). Step 0:
`verify_repro` 32 cells 0.000e+00, 146/146, D2 row 1 unchanged. Dry runs before (i0000): N0M τ 0 /
200 ms 0.0163 / 0.0296; TAB L0 0.0566, L2 0.0225, L3 0.0163, V 0.0164 (180 ms), L3_6 0.0168 (50 ms).
Wall time: table segments 3-17 took 371-1218 s (segment 4: 8973 s) instead of ~148 s - a machine
slowdown/sleep, not a result (the runs are deterministic); hence 11.8 h instead of ~7 h.

**Step 1 - N0V square (A4 fixed-5, 5/5 everywhere, no edge), pooled [m]:** 0: 0.0273 · 40: 0.0243 ·
80: 0.0222 · 100: 0.0217 · 110: 0.0215 · **120: 0.0215** · 130: 0.0215 · 140: 0.0217 · 180: 0.0231 ·
240: 0.0269 · 300: 0.0320 · 400: 0.0418 → **τ_prev\*(square) = 120 ms** (flat 110-130 ms; argmin on
unrounded values). Consistency: V at τ 0 (0.0273) = N0P square at τ 0 (0.0273, §9.2).

**Step 2 - N0M square (L3_6(τ), A4 fixed-5, TauPred 120 ms), pooled [m]:** 0: 0.0225 · 20: 0.0218 ·
40: 0.0213 · 50: 0.0212 · **60: 0.0212** · 70: 0.0213 · 80: 0.0214 · 100: 0.0219 · 120: 0.0227 · 200:
0.0277 · 300: 0.0350 · 400: 0.0411 → **τ_m\*(square) = 60 ms**, not at an edge → L3_6 ran at 60 ms.
τ 0 (0.0225) = N0P square at τ\* (0.0225, §9.2). At 60 ms only i0251 improves (0.0397 → 0.0339); i0000,
i0453, i0705, i0900 get worse (as circle/T5 in §31).

**Step 3 - table (`square_main` = circle_main set, SHA `a227e9d87a2ac436`; TauPred 120, TauPrev 120,
TauN6 60 ms).** One set **134/134, 42 days**, nothing removed.

| column | pooled [m] | SE | by-day median | LOO [min, max] |
|---|---|---|---|---|
| L0 | 0.05569 | 0.00205 | 0.05122 | [0.05485, 0.05574] |
| L2 | 0.02225 | 0.00095 | 0.02057 | [0.02182, 0.02228] |
| L3 | 0.01673 | 0.00112 | 0.01453 | [0.01617, 0.01676] |
| V | 0.01522 | 0.00118 | 0.01288 | [0.01465, 0.01525] |
| L3_6 | 0.01749 | 0.00079 | 0.01599 | [0.01704, 0.01751] |

(most influential segment of every column: `wind_expl_t150_i0306`)

| ratio (descriptive) | value | SE | by-day median | LOO |
|---|---|---|---|---|
| **L3/L2 − 1** | **−24.8 %** | 1.93 | −28.6 % | [−25.9, −24.7] |
| V/L2 − 1 | −31.6 % | 2.48 | −36.3 % | [−32.8, −31.5] |
| L2/L0 − 1 | −60.0 % | 0.36 | −60.1 % | [−60.2, −60.0] |

`tilt_sat_frac`: median 0; max 0.375-0.380; segments > 1 %: 9 (L0) / 10 (L2, L3, V, L3_6). Motor
`sat_frac` 0.

**h_model = 1 − L3_6/L3 and the §33 reading (as printed):**

| set | n (days) | L3 → L3_6 [m] | h_model | SE | LOO | by-day median | reading |
|---|---|---|---|---|---|---|---|
| one set | 134 (42) | 0.01673 → 0.01749 | **−4.52 %** | 2.41 | [−5.43, −4.45] | −9.94 % | **DOES NOT ADD** |
| unsaturated (tilt_sat < 1 % in L3 and L3_6) | 124 (40) | 0.01506 → 0.01636 | **−8.60 %** | 1.04 | [−8.91, −8.53] | −10.49 % | **DOES NOT ADD** |

Left out of the unsaturated subset: real i0251, i0846; expl i0013, i0041, i0151, i0184, i0304, i0306,
i0317, i0323. Payload swing θ RMS (one set) 17.59° → 17.39°. Most influential: i0306 (one set), i0017
(unsaturated).

**Side report (not read) - corner / edge half-cycle windows:**

| set, window | L3 → L3_6 [m] | h_model | SE | LOO | by-day median |
|---|---|---|---|---|---|
| one set, corner | 0.01418 → 0.01676 | −18.16 % | 5.73 | [−20.89, −18.00] | −31.34 % |
| one set, edge | 0.01951 → 0.01826 | +6.40 % | 0.65 | [+6.16, +6.43] | +4.92 % |
| unsaturated, corner | 0.01221 → 0.01564 | −28.04 % | 2.68 | [−28.76, −27.87] | −32.39 % |
| unsaturated, edge | 0.01808 → 0.01711 | +5.34 % | 0.28 | [+5.23, +5.37] | +4.86 % |

Facts recorded with the reading (not a new reading): (1) the registered answer on the square is the
same as on circle/T5 (§31): the N6 term does not add beyond the DO payload prediction; (2) against the
§33 expectation, the term lowers the error in the **edge** half (where the reference acceleration
peaks) and raises it in the **corner** half (dwell, UAV nearly at rest), and L3's own error is larger on
the edges (0.0195) than at the corners (0.0142); (3) as on circle and T3b, V is below L3 (−31.6 % vs
−24.8 % against L2); (4) the square's L3/L2 gain (−24.8 %) is about half of circle's (−50.3 %) and
T3b's (−45.4 %).

## 38. Result of the P-QA follow-up (§36; `pqa_spikes`, git `b756c3f`) - facts, reading verbatim
Output `results/pqa/pqa_spikes_20260929_005242.mat` (user's machine). 471 segments; **198 raw M5
files** (real_file × height), 26.2 h covered.

**The 12 segments of §35:**

| segment | raw file | h [m] | day | offset | spikes / jumps |
|---|---|---|---|---|---|
| real i0060 | 01_16_2024_14_00 | 61 | 2024-01-16 | 400 | 2 / 3 |
| expl i0127 | 02_16_2024_08_00 | 61 | 2024-02-16 | 0 | 4 / 4 |
| expl i0130 | 02_16_2024_08_00 | 74 | 2024-02-16 | 0 | 22 / 22 |
| expl i0131 | 02_16_2024_08_00 | 74 | 2024-02-16 | 200 | 16 / 16 |
| expl i0132 | 02_16_2024_08_00 | 74 | 2024-02-16 | 400 | 7 / 7 |
| expl i0288 | 04_27_2024_14_00 | 61 | 2024-04-27 | 200 | 59 / 61 |
| expl i0289 | 04_27_2024_20_00 | 61 | 2024-04-27 | 0 | 32 / 32 |
| expl i0290 | 04_27_2024_20_00 | 61 | 2024-04-27 | 200 | 23 / 24 |
| expl i0291 | 04_27_2024_20_00 | 61 | 2024-04-27 | 400 | 19 / 20 |
| expl i0292 | 04_27_2024_20_00 | 74 | 2024-04-27 | 0 | 46 / 47 |
| expl i0293 | 04_27_2024_20_00 | 74 | 2024-04-27 | 200 | 49 / 50 |
| expl i0402 | 05_22_2024_02_00 | 61 | 2024-05-22 | 400 | 0 / 1 |

**Per raw file:** spikes per hour p50 0.00, p90 0.00, p99 657.7, max 1116.0; **19 of 198 files hold
any spike**. Top: 04_27 14:00 h61 124 spikes (1116/h); 04_27 20:00 h74 95 (855/h); 04_27 20:00 h61 74
(444/h); 02_16 08:00 h74 45 (270/h); 02_16 08:00 h61 8; 04_28 02:00 h74 5, h61 4; every other file ≤ 2.
Ranks of the files holding the 12: 1, 2, 3, 4, 5, 8, 187.

**Summary:** jumps ≥ 5 m/s 393; spikes 370; non-spike jumps 23; **spiked segments 30 of 471**.
**A = 0.941; C = 4 of 198 files hold ≥ 80 % of the spikes = 0.020.**

**READING (§36, as printed): SENSOR SPIKES (sonic-anemometer spikes; a data limitation).** The spikes
sit in a few files of two days (2024-04-27/28 and 2024-02-16). The §35 reading stays; the paper
wording is the fixed sentence of §36.

**POST HOC sensitivity (§36; not a gate; no re-run) - without the spiked segments:**

| quantity | as registered: n (days), value, SE, LOO, by-day | without spiked: n (days), value, SE, LOO, by-day |
|---|---|---|
| D2 L3/L2 − 1 (circle_main) | 134 (42), −50.33 %, 8.28, [−57.35, −50.22], −62.23 | 128 (42), −49.90 %, 8.52, [−57.11, −49.79], −62.23 |
| T3b L3/L2 − 1 | 133 (42), −45.41 %, 3.67, [−46.61, −45.28], −57.45 | 126 (42), −45.15 %, 3.65, [−46.41, −45.02], −57.45 |
| T3b V/L2 − 1 | 133 (42), −49.14 %, 3.81, [−50.44, −49.02], −63.20 | 126 (42), −48.84 %, 3.79, [−50.20, −48.72], −63.20 |
| N6 h_model, one set | 136 (43), +18.24 %, 39.39, [+17.72, +58.44], +59.31 | 129 (43), +17.67 %, 39.72, [+17.14, +58.24], +59.31 |
| N6 h_model, unsaturated | 122 (41), +61.38 %, 1.47, [+60.20, +61.59], +59.86 | 117 (41), +61.51 %, 1.50, [+60.30, +61.73], +59.86 |

Spiked segments in each set: D2 6 (expl i0128, i0132, i0290, i0293, i0294, i0297); T3b 7 (the same +
i0326); N6 7 (expl i0115, i0128, i0132, i0294, i0297, i0326, i0433). Every value moves by ≤ 0.6 pt
and no sign changes: the spikes do not drive D2, the T3b table or h_model (fact; post hoc).

## 39. Night 12 - F1-F3 on hover, then B1 and B2 on S40 (user decisions 2026-09-28) - registered before any run
Sensitivity / descriptive (§30): **not a gate**; recorded verbatim.

### 39.1 Set S40hover (registered before any use)
- Source: `N6_hover` at cap 4 (SHA `43226c02f081…`, 139 segments / 43 days, §15.4).
- The S40 rule of §30.1 applied to **every day** of the source: days sorted by date; the j-th day
  (j = 1..n_days) contributes the segment whose start time of day (`real_t0` + `real_offset_s`) is
  nearest (circular, 24 h) to (j − 0.5)/n_days · 24 h; ties → lower height, then file name. Uses no
  wind value and no result. Code `p2_segset('S40hover')` (Octave mock: one segment per day,
  deterministic; S40 unchanged).
- **Its SHA-256 is printed on the user's machine at the dry-run step (`p2_segset('S40hover')`), passed
  to the night script, asserted by the runner, and transcribed here with the results.**
- **Transcribed (§41):** 43 segments / 43 days, SHA-256
  `53facf03712c81eef9ce2f82b2a054f263657818c5a55ad1e2f22be0249e3116` (source `N6_hover`
  `43226c02f081460607d5f98676c57cfa1207e98498ad2919c642af5d717144c7`).

### 39.2 F1-F3 (group `F-hover`)
- Configuration = N6 group #10's (§15.4, §25): hover, K 0.5, L 1.0, `TauPred` 0 (τ\*_hover), sensor
  delay 50 ms, hover IM table; N6 term on, **measured wind**, horizon **280 ms** (τ_6\*); nominal plant.
- **Controller-side parameters only** (`p2_setup ... 'PredScale', [s_L s_mL s_CdA]`; the plant's
  `p2_prm` keeps the nominal values): the N6 predictor's L (s_L) and m_L (s_mL); **C_D·A of payload and
  body together (s_CdA)**: the N6 wind-to-payload-force gain (via K_w) and the body C_D·A of the wind
  feed-forward `p2_prm_w` are multiplied by the same s_CdA (the ratio K is kept). ζ_s stays nominal.
  Default (no scale) leaves every value untouched.
- **Columns (10):** L3, L3_6 (nominal; **reused from N6** under the §15.1 rule - the first shared
  segment is re-run and every printed digit must match, otherwise both are run) and 8 × L3_6 at
  `L080 L090 L110 L120` (s_L 0.8 / 0.9 / 1.1 / 1.2), `m080 m120` (s_mL 0.8 / 1.2), `c070 c130`
  (s_CdA 0.7 / 1.3).
- **Quantity:** h_model,F = 1 − L3_6,F / L3 (L3 = the nominal column; note: s_CdA also changes the
  body wind feed-forward, so for c070 / c130 the difference includes that part), on the one set (valid in
  all 10 columns) and on its unsaturated subset (`tilt_sat_frac` < 1 % in every column), each with SE
  (day jackknife), LOO, by-day median, most influential segment.
- **Reading (fixed now), per variant and per set:** h_model,F > 0 AND every LOO value > 0 → **HOLDS**;
  otherwise → **FAILS**. Both sets printed; they do not override each other.

### 39.3 B1 (m_p) and B2 (L) on S40 (if the night leaves time; resumable)
- Circle (`Test 4`), K 0.5, nominal P2; set **S40** (SHA `1db1de02532a3896…`, §30.1); columns **L0 L2 L3
  V** as §32 (L0 DoHarm 1; L2/L3/V DoHarm [0 1]); statistics as §32 (pooled, SE, LOO, by-day, L3/L2,
  V/L2, L2/L0, tilt_sat, sat_frac); one-set rule per level.
- **Nominal level** (m_p 0.5, L 1.0): D2's rows (`d2_p2.mat`, §11.1, identical configuration) on the 40
  S40 segments - nothing re-run (the D2 row-1 check runs every night).
- **B1:** m_p ∈ {0.25, 0.65} (§0.9; S40's U ≤ 8.02 lies inside every level's envelope). Plant and
  controller trim use the level's m_p. `TauPred` **290 ms** at every level (§6.5 lists the trajectory and L
  as measured in advance; m_p is not in that list → nominal), `TauPrev` 180 ms.
- **B2:** L ∈ {0.5, 1.5}. L 1.5: `TauPred` = τ\*_L1.5 = **260 ms** (§16.2). L 0.5: **N0P circle L 0.5**
  first (§7.1 procedure, A4 fixed-5) → τ\*_L0.5; EDGE-UNRESOLVED or failed → L 0.5 not run, printed.
  `TauPrev` 180 ms at both levels (not re-measured, stated).
- Order in the night: F-hover → B1 (nominal, 0.25, 0.65) → B2 (L 1.5, N0P L 0.5, L 0.5).

### 39.4 Code, dry run, hours
- `p2_setup`/`pa_configs` option `PredScale`/`P2PredScale` (default [] - untouched); `p2_segset('S40hover')`;
  `run_p2_gd7('F-hover', ...)` (report `f_report`); `run_p2_gd6('TAB', 'Only', {'circle'}, 'MP'|'L'|'FromD2', ...)`;
  `run_p2_gd6('N0P', 'Only', {'circle_L05'})`; night script `gd7_night12(sha)`. Octave mock tests: F-hover
  (reuse ON after the spot check, 98 calls, 9 distinct scale vectors passed, reading), TAB circle levels
  (MP / L passed, nominal from D2 with no call, T3b refuses MP), N0P L 0.5; T3b / square / GĐ7 paths
  unchanged.
- **Dry run** (~6 min): `S = p2_segset('S40hover')` (prints the SHA);
  `run_p2_gd7('F-hover', 'TauW', 0.280, 'TauPred', 0, 'DryRun', true)`;
  `run_p2_gd6('TAB', 'Only', {'circle'}, 'MP', 0.25, 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true)`.
- **Hours** (~28 s per hover column-run, ~101 s per circle segment of 4 columns): F 43 × 8 ≈ 344 runs ≈
  **2.7 h**; B1 2 × 40 segments ≈ **2.2 h**; B2 L 1.5 ≈ 1.1 h + N0P L 0.5 ≈ 1.0 h + L 0.5 ≈ 1.1 h ≈ **3.2 h**;
  checks 0.2 h → **≈ 8.3 h** in total.

## 40. Competitors H3 and H4 (REVIEWER_MATRIX H3, H4) - registered 2026-09-28 before any code run on dev data
Design approved by the user with changes (`docs/devlog/COMPETITORS_DESIGN.md` §5). Descriptive comparison
tables, **not a gate**. Only the source of the disturbance compensation in the position loop changes;
Guo's position law `F = m a_d − d̂_mf − d̂_lf`, gains, attitude loop, sensors, delays, solver are common.
The competitors know nothing MOBADC does not (no L, no true wind). H5 (payload-angle feedback): later, T2.

### 40.1 H3 - "acceleration-based disturbance estimation of the INDI type (outer loop of Smeur 2018)"
(the paper's name; **not** called a full INDI controller)
- At the attitude rate (1 kHz): `d̂_H3 = H(z) [ m a_meas − F̂_thr + m g e3 ]`, m = the controller's mass (1.121
  kg); `a_meas` = the P2 accelerometer (inertial frame, nominal noise and bias); `F̂_thr` = the total-thrust
  command through the nominal motor lag (17 ms, exact ZOH), directed by the **measured** attitude with the
  plant's own `force_from_attitude` convention; H = 2nd-order low-pass, ζ_f = 1/√2, cut-off ω_f, exact ZOH;
  one filter on the sum = the same filter on both terms (filter synchronisation).
- `d̂_mf := d̂_H3`, `d̂_lf := 0` (new Variant `p2_cmp = 1`); the DO/ESO keep running, unused by the law.
- **Limitation (paper):** the P2 accelerometer is idealised (kinematic acceleration, no gravity leakage from
  attitude error) - favourable to H3 and to IM-est.
- **Tuning (1 parameter):** ω_f ∈ {1, 2, 4, 8, 16} Hz on the A4 fixed-5, circle, K 0.5; argmin of the pooled
  error; a grid-edge minimum → one extension (0.5 Hz below / 32 Hz above); frozen for every table.

### 40.2 H4 - frequency-adaptive DOB (Marino-Tomei type) on the DO output
- Input per axis (x, y, z): the DO estimate d̂_mf(t) (tap `dmf_do`, before any prediction).
- **n = 4 frequencies (the same n as IM-est, AR(8)) + a constant.** Frequency estimator: the linear
  parameterisation on state-variable-filtered signals used by Marino-Tomei 2002 - y satisfies
  `p (p^{2n} + θ1 p^{2n−2} + … + θn) y = 0`; filter `Λ(p) = (p + λ_f)^{2n+1}`; `z = φᵀθ`; normalised-gradient
  adaptation `θ̂̇ = γ φ ε / (1 + φᵀφ)`; the frequencies = the roots in p² of the degree-n polynomial, recomputed
  every 1 s, a slot active only for a real ω in [ω_min, ω_max].
- Amplitude and phase: RLS with forgetting λ_a on `[1, sin φ_k, cos φ_k]` (active slots; φ_k = ∫ ω̂_k dt);
  prediction `d̂_H4(t + τ) = c + Σ a_k sin(φ_k + ω̂_k τ) + b_k cos(φ_k + ω̂_k τ)`; replaces the payload channel
  (Variant `p2_cmp = 2`); the wind channel is the column's (ESO for the no-sensor level, measured-wind
  feed-forward for the sensor level).
- **DO under H4:** planned trajectory → its exact IM table (as L3); unplanned / held-out (GĐ8) → **DC only**
  (information equal to IM-est's).
- **Fixed constants** (λ_f, ω_min, ω_max, λ_a, initial θ̂, RLS P0) are chosen on **synthetic signals only**
  (sums of sines 0.2-1 Hz + DC + noise; no dev data) and transcribed as §40.5 **before the first dev run**.
  **γ₀** = the smallest γ giving < 2 % frequency error within 10 s on a synthetic 0.4 Hz sine.
- **Tuning (2 parameters: γ, τ):** τ\*_H4 by N0P (§7.1 procedure) at γ₀ on the fixed-5 circle (sensor level);
  then γ ∈ {¼, ½, 1, 2}·γ₀ at τ\*_H4 → γ\* (argmin); if γ\* ≠ γ₀, N0P once more at γ\*; frozen. τ per trajectory
  by the τ rule: N0P for H4 at γ\* on the fixed-5 for T3b, square, T5, hover.

### 40.3 Tables (user decision)
- **circle_main** (cap 4, SHA `a227e9d87a2ac436`) - **two levels:** no wind sensor: **L1** (Guo + payload
  prediction, `g_pay`; the D2 column, run here), **H3**, **H4a** (`g_pay` + H4); with measured wind: **L3**
  (D2's), **H3** (the same column), **H4b** (`g_psens` + H4). L0, L2 from D2 as reference.
- **Hover, N6_hover FULL** (cap 4, SHA `43226c02…`, 139 segments): L3, L3_6 (reused from N6 under the §15.1
  rule), **H3**, **H4b**; one set and the unsaturated subset (§26.1).
- **T3b, square, T5 on S40** (SHA `1db1de02…`): L3, V, H3, H4b (all run: S40 is not a subset of those sets).
- **Held-out GĐ8:** H3 and H4 included (registered with GĐ8).
- Per table (§0.2, §6.6): pooled, SE (day jackknife), LOO, by-day median, most influential; H3/L3 − 1 and
  H4/L3 − 1 (circle level A: against L1); tilt_sat, sat_frac; one-set rule over the table's columns.

### 40.4 Code, bit-exactness, hours
- New blocks in P2/P2_Core (EML `p2_h3_indi`, `p2_h4_dobaf`), Variant Sources `P2_CMP_Sel` (payload channel,
  after `P2_N6_Sel`) and `P2_CMPW_Sel` (wind channel, after `WD_Switch`); `p2_cmp = 0` by default (init /
  reset_extensions) → the unchanged path; after the build: B1 (verify_repro, check_results_numbers), D2 row 1,
  the N6 full-precision recheck (as `gd7_n6_prep`), before any H3/H4 run. Offline (Octave) tests first.
- **Hours** (~28 s per column-run): H3 tuning 25 runs ≈ 0.2 h; H4 tuning ≤ 2 × 130 + 20 runs ≈ 2.4 h; N0P H4
  for T3b / square / T5 / hover ≈ 4.4 h; circle_main 134 × 4 (L1, H3, H4a, H4b) ≈ 4.2 h; hover 139 × 2 ≈ 2.2 h;
  S40 3 × 40 × 4 ≈ 3.7 h → **≈ 17 h (≈ 2.5 nights)**, plus the build and its checks.

### 40.5 H4 constants and implementation details - fixed on synthetic signals, before any dev run (2026-09-28)
`analysis/h4_synthetic.m` (Octave; no dev data), code `core/p2_h4_const.m`, `core/p2_h4_prm.m`,
`simulink_blocks/p2_h4_dobaf.m`. Transcribed before the first dev run, as §40.2 requires.
- **State-variable filter: order 12, not 2n + 1 = 9** (implementation change found in the synthetic test,
  before any dev run): with order 9 the target p⁹y/Λ has a unit high-frequency gain, so the 1 kHz input
  staircase (ZOH), times the time-scaling factor, swamped the regression (residual with the TRUE θ: 65 vs a
  signal of 0.14). With `λ_f¹² / (p + λ_f)¹²` (unit DC gain, relative degree 3) every regressor is a filter state
  and the residual with the true θ is 1.8e-7. The parameterisation (`p(p⁸ + θ1 p⁶ + … + θ4) y = 0`) is unchanged.
- **Constants:** λ_f = 10 rad/s; time scale ω_s = 3 rad/s; slot band [2π·0.05, 2π·1.5] rad/s; complex roots
  accepted as real when |Im u| ≤ 0.05 |Re u|; roots every 1 s from 5 s on; initial root set ω₀ = {0.5, 1, 2, 4}
  rad/s; amplitude RLS forgetting λ_a = 1 − 1/3000 (≈ 3 s memory at 1 kHz), P0 = 10, trace cap 1e4, forgetting
  applied only to active parameters; a slot that appears, vanishes or moves by > 20 % restarts its amplitude;
  non-finite θ̂ → restart from ω₀.
- **Output form:** `d̂_H4 = d̂_DO(t) + Σ_active [a_k (sin(φ_k + ω̂_k τ) − sin φ_k) + b_k (cos(φ_k + ω̂_k τ) − cos φ_k)]`
  - the DO's present estimate plus the predicted CHANGE of the fitted oscillation (equal to the §40.2 form when
  the fit is exact; before any slot is active it passes the DO estimate through, as N6 does).
- **Constant choice (synthetic only):** (λ_f, ω_s) ∈ {(6, 2), (6, 3), (10, 2), (10, 3), (14, 3)}; the rule was
  the best multi-sine prediction ratio among the sets that reach γ₀: (10, 3) → 0.667 (6, 3: 0.743; 6, 2: 0.834;
  10, 2 and 14, 3: no γ met the criterion).
- **γ₀ = 3.162** (the smallest of logspace(0, 4, 9) giving < 2 % frequency error at every root update in
  [10, 20] s, signal 2 + sin(2π·0.4 t) + noise 0.01: error 1.54 %; γ = 1: 160 %). Multi-sine check
  (0.25 / 0.5 / 0.8 Hz + DC, τ 200 ms) at γ₀: prediction rms 0.243 vs held 0.365 (ratio 0.667); slots at
  the end 0.363 / 0.829 / 0.848 Hz - the two low components are not resolved (a fact about this competitor,
  reported as such). γ grid for §40.2: {0.79, 1.58, 3.16, 6.32}.
- **H3:** `p2_h3_prm` checked offline: DC gain 1 and −3 dB at ω_f for every grid value; with the plant
  relation and the same motor lag the estimate of a constant disturbance is exact (1e-17), sines lagged
  by the filter only; at the hover trim the z-estimate is −m_L g.
- **Runners:** `run_p2_gd6('N0H3' | 'N0H4' | 'GH4', ...)` (mock-tested). **Build:** `build_p2_plant` step 7
  (not yet run on the model - after the nights in progress; then B1, D2 row 1, N6 recheck, before any H3/H4 run).

## 41. Results of night 12 (`gd7_night12`, git `7cdd6d1`, 8.3 h) - F1-F3 on hover, B1, B2 (§39) - facts
Log `results/gd7/night12_20260929_010930.txt` (user's machine). Sensitivity / descriptive, **not a gate**.
Step 0: `verify_repro` 0 differences, `check_results_numbers` passed, D2 row 1 (i0000) unchanged
`[0.0414 0.0334 0.014 0.0136]`.

### 41.1 F-hover (§39.2) - S40hover (SHA `53facf03…`, 43 segments / 43 days)
Reuse from N6 (§15.1): spot check `wind_real_t150_i0000` L3 0.0089 / 0.0089, L3_6 0.0030 / 0.0030
(|d| 0) → **reuse ON** (86 of 430 values reused). One set **43 / 43** (0 removed); unsaturated subset
**40** (left out: `wind_real_t150_i0251` max tilt_sat_frac 0.2384, `wind_real_t150_i0715` 0.0205,
`wind_expl_t150_i0321` 0.1705).

| column (pooled L3_6,F [m]) | h_model,F one set | SE | LOO [min, max] | by-day median | reading | h_model,F unsaturated | SE | LOO [min, max] | by-day median | reading |
|---|---|---|---|---|---|---|---|---|---|---|
| L3 (reference) | 0.01049 | | | | | 0.00797 | | | | |
| L3_6 nominal (0.00400 / 0.00305) | +61.81 % | 3.08 | [+59.31, +63.18] | +56.66 % | **HOLDS** | +61.76 % | 1.82 | [+60.32, +62.37] | +56.90 % | **HOLDS** |
| L080 (0.00367 / 0.00282) | +65.00 % | 3.13 | [+62.37, +66.30] | +59.05 % | **HOLDS** | +64.56 % | 1.81 | [+63.12, +65.07] | +59.57 % | **HOLDS** |
| L090 (0.00382 / 0.00292) | +63.61 % | 3.12 | [+61.03, +64.96] | +58.28 % | **HOLDS** | +63.41 % | 1.83 | [+61.94, +63.96] | +58.30 % | **HOLDS** |
| L110 (0.00421 / 0.00319) | +59.84 % | 3.00 | [+57.42, +61.20] | +55.13 % | **HOLDS** | +59.92 % | 1.79 | [+58.51, +60.55] | +55.38 % | **HOLDS** |
| L120 (0.00442 / 0.00334) | +57.84 % | 2.91 | [+55.52, +59.18] | +53.61 % | **HOLDS** | +58.02 % | 1.74 | [+56.66, +58.67] | +53.67 % | **HOLDS** |
| m080 (0.00411 / 0.00311) | +60.84 % | 3.04 | [+58.39, +62.21] | +56.34 % | **HOLDS** | +60.95 % | 1.82 | [+59.51, +61.61] | +56.46 % | **HOLDS** |
| m120 (0.00394 / 0.00301) | +62.40 % | 3.10 | [+59.86, +63.76] | +57.01 % | **HOLDS** | +62.25 % | 1.82 | [+60.80, +62.81] | +57.15 % | **HOLDS** |
| c070 (0.04644 / 0.03993) | −342.90 % | 71.86 | [−403.57, −319.65] | −485.99 % | **FAILS** | −401.19 % | 66.25 | [−440.83, −363.19] | −503.41 % | **FAILS** |
| c130 (0.04295 / 0.03715) | −309.58 % | 62.89 | [−363.35, −288.81] | −439.55 % | **FAILS** | −366.28 % | 59.94 | [−402.89, −332.63] | −448.23 % | **FAILS** |

Most influential segment: `wind_real_t150_i0251` (one set), `wind_expl_t150_i0017` (unsaturated), every row.
**Reading §39.2 applied, verbatim:** F1 (L ±10 / ±20 %) and F2 (m_L ±20 %) **HOLD** on both sets; F3
(C_D·A of payload and body together ±30 %) **FAILS** on both sets.
**Recorded (facts, not read):** h_model,F falls monotonically with s_L (L080 highest, L120 lowest),
the m_L effect is < 1.5 points; the two C_D·A rows fail by a similar amount on both sides of nominal
(L3_6 ≈ 4.4× L3 at s_CdA 0.7 and 4.1× at 1.3); on the last segment (`wind_expl_t150_i0440`) L3 0.0052,
L3_6 0.0018, c070 0.0167, c130 0.0164.

### 41.2 Implementation check of the F3 path (2026-09-29, code reading - no run)
`PredScale(3)` reaches exactly two places, as §39.2 registers: `p2_prm_w(1)` (read only by
`P2_WindHat`, the controller's body wind feed-forward; `build_p2_plant` line 450) and `Pn.K_w` → `kL =
K·K_w/U_ref` of `p2_n6_prm` (the N6 observer input and its prediction). The plant's `p2_prm` stays
nominal; nothing else reads `p2_prm_w`. **No implementation error found.**

### 41.3 A mechanism consistent with 41.1 (offline algebra on the N6 model, no data - a hypothesis, not a reading)
The N6 term adds `delta = d_pred(τ) − m_L g θ̂(t)` (§24): the predicted CHANGE over τ = 280 ms. Its DC value
is zero only if the observer's measurement `θ_m = dmf_do/(m_L g)` equals the model's own equilibrium
`θ_eq = kL|r|r/(m_L g)`. The DO's estimate carries every residual the controller does not model,
including the body feed-forward's error (1 − s)·F_body; the model's payload force is s·K·F_body. Hence
`θ_m − θ_eq ∝ (1 + K − s(1 + K))·F_body = 1.5 (1 − s) F_body` - linear in (1 − s), the same size for
s = 0.7 and 1.3. Steady-state observer + τ-propagation (`p2_n6_prm`, m_L 0.5, L 1, K 0.5):

| U [m/s] | DC delta, s 0.7 / 1.3 (both) | payload part only | body part only | bias / (m K_γ), both |
|---|---|---|---|---|
| 5 | −0.44 / +0.44 N | ∓0.15 N | ∓0.29 N | 0.033 m |
| 7 | −0.87 / +0.87 N | ∓0.29 N | ∓0.58 N | 0.064 m |
| 9 | −1.43 / +1.43 N | ∓0.48 N | ∓0.95 N | 0.106 m |

(last column: the bias over the horizontal stiffness m·K_γ = 1.121·12 N/m, ignoring whatever the DO
removes - an upper bound). Its size is of the order of the measured L3_6,c ≈ 0.04 m, and it predicts the
observed symmetry. The body feed-forward error alone (L3 without N6) would be a DC-dominated residual,
which the DO's DC mode removes; in N6 it becomes a persistent `delta`. If this holds, F3 measures a
property of the N6 **form** (delta is not DC-free) rather than of the pendulum model's accuracy, and two
thirds of it comes through the body C_D·A. Not tested; see 41.5.

### 41.4 B1 and B2 (§39.3) - circle on S40 (SHA `1db1de02…`), columns L0 L2 L3 V, `TauPrev` 180 ms
| level | TauPred | one set | L0 | L2 | L3 | V | L3/L2 − 1 (SE; LOO; by-day) | V/L2 − 1 (SE; LOO; by-day) | L2/L0 − 1 | tilt_sat > 1 % (L0/L2/L3/V) |
|---|---|---|---|---|---|---|---|---|---|---|
| nominal m_p 0.5, L 1.0 (D2 rows) | 290 | 40/40 | 0.04369 | 0.03494 | 0.01530 | 0.01355 | −56.22 % (3.23; [−58.96, −55.94]; −64.87) | −61.21 % (3.20; [−63.88, −60.96]; −69.04) | −20.04 % | 2/3/3/3 |
| **B1** m_p 0.25 | 290 | **39/40** | 0.03657 | 0.02931 | 0.01790 | 0.01446 | −38.92 % (1.55; [−39.80, −38.71]; −42.78) | −50.68 % (1.90; [−51.69, −50.48]; −55.79) | −19.84 % | 5/5/5/5 |
| **B1** m_p 0.65 | 290 | 40/40 | 0.04604 | 0.03785 | 0.01713 | 0.01322 | −54.75 % (2.32; [−56.60, −54.51]; −61.19) | −65.06 % (3.45; [−68.02, −64.80]; −72.89) | −17.81 % | 2/2/2/2 |
| **B2** L 1.5 | 260 | 40/40 | 0.04492 | 0.03642 | 0.01703 | 0.01355 | −53.25 % (2.78; [−55.55, −52.99]; −60.92) | −62.80 % (3.75; [−66.04, −62.52]; −71.85) | −18.92 % | 3/3/3/3 |
| **B2** L 0.5 | **330** | 40/40 | 0.04265 | 0.03361 | 0.01380 | 0.01340 | −58.95 % (3.72; [−62.15, −58.66]; −68.86) | −60.14 % (3.06; [−62.68, −59.90]; −67.77) | −21.19 % | 2/3/3/3 |

(most influential segment `wind_real_t150_i0251` in every row except m_p 0.25: `wind_expl_t150_i0244` /
`i0162`; motor sat_frac 0 everywhere.)
- **m_p 0.25:** `wind_real_t150_i0251` crashed / diverged in **every** column (L0 `Attitude_Observer/Int_za`
  t = 59.785 s, L2 72.17 s, L3 `UAV_Plant/Int_etadot` 90.62 s, V diverged) → removed by the one-set rule;
  39 segments / 39 days. Recorded, not diagnosed (sensitivity block; the rule of §0.4 D1 applies if it is
  ever used in a claim).
- **N0P circle L 0.5 (§7.1, A4 fixed-5, 5/5 at every τ):** coarse minimum 320 ms (0.0213, flat 320-340),
  fine 300-340 → **τ\*_L0.5 = 330 ms**, edge ok. The curve: 0.0386 at 0 ms, 0.0213 at 320-340 ms, 0.0223 at
  400 ms. The P2 τ list of §11.3 gains circle L 0.5 → 330 ms (circle 290, L 1.5 260, §16.2).
- **Recorded (facts, not read):** L3/L2 − 1 stays between −53 % and −59 % over L ∈ {0.5, 1.0, 1.5} and at
  m_p 0.65; it is −39 % at m_p 0.25 (L3 higher, L2 lower than nominal). V/L2 − 1 lies between −51 % and
  −65 % at every level; V < L3 at every level. L2/L0 − 1 ≈ −18 … −21 % throughout.

### 41.5 Proposed - NOT registered (one diagnostic round for F3, awaiting the user's decision)
S40hover, same configuration as §39.2, reusing L3 and L3_6 nominal: split s_CdA into the payload part
(N6 kL only) and the body part (`p2_prm_w` only), s ∈ {0.7, 1.3}: columns `L3_6_cP070 L3_6_cP130
L3_6_cB070 L3_6_cB130` and `L3_cB070 L3_cB130` (body feed-forward error without N6); plus, per column, the
DC share of the error (RMS of the per-axis mean over t ≥ 140 s / pooled RMS) and the mean of `delta`
(from the N6 log). Reading to be fixed before the run: 41.3 is supported if (i) `L3_cB` stays within
±10 % of L3, (ii) `L3_6_cB` ≈ 2× `L3_6_cP` in excess error over nominal, (iii) the DC share of the
`L3_6_c*` error is > 50 %. ≈ 43 × 6 runs × 28 s ≈ 2.0 h. The F3 verdict of 41.1 stands either way.
**→ Approved by the user 2026-09-29 and registered in §42.1-42.2** (with the reading made precise there; every
column re-run so that the DC share is measured on the original C_D·A columns too).

## 42. Night 14 - F3 diagnostic (S40hover), then E3, D2-thrust, B3 (S40) - registered 2026-09-29, before any run
Sensitivity / diagnostic (§30): **not a gate**; recorded verbatim.

### 42.0 User decisions (2026-09-29, after night 12), recorded before the run
- **F3 = FAILS stands** (§39.2 reading, §41.1). Nothing in §42.1-42.2 can change it.
- **Acceptance condition for GĐ8 (iii) FULL (registered now; MASTER_PLAN §7.1):** the full pendulum model (wind +
  UAV acceleration inputs) must pass F1-F3 on **S40hover** - L ±20 %, m_L ±20 %, **C_D·A of the payload and C_D·A of
  the body separately ±30 %** - with **h_model > 0 AND every LOO value > 0 in EVERY variant** (the §39.2 reading).
  Otherwise (iii) is not reported as a contribution.
- **Design direction (written down, NOT fixed):** the DO keeps the static (DC) part; the model term handles only the
  oscillatory part (DC-free). Fixed when GĐ8 is registered.
- **H-model (CONFIRM2, §28.1) unchanged.** If (iii) meets the condition above on dev data → **H-model(iii)** is
  registered **BEFORE** CONFIRM2 is opened (GĐ10).
- The paper reports F3 of the present N6 form as the design reason for (iii).
- **B1, `wind_real_t150_i0251` at m_p 0.25** (all four columns crashed / diverged, §41.4): recorded as a **controller
  limitation**, not diagnosed.

### 42.1 F3 diagnostic (group `F3-diag`) - the one diagnostic round for F3; pure diagnosis, no fix tried
- Configuration = F-hover's (§39.2): S40hover (SHA `53facf03712c81ee…`, §39.1), hover, K 0.5, L 1.0, `TauPred` 0,
  sensor delay 50 ms, hover IM table; N6 term with the **measured** wind, horizon 280 ms; nominal plant.
- `PredScale` becomes `[s_L s_mL s_CdA,payload s_CdA,body]`: the payload part = the N6 wind-to-payload gain (kL via
  K_w), the body part = the body C_D·A of the wind feed-forward `p2_prm_w`; the 3-vector of §39 = both parts equal
  (bit-exact with night 12's calls).
- **Columns (10), every one run** (no reuse - the DC share needs each run's own time series): `L3`, `L3_6`,
  `L3_6_c070`, `L3_6_c130` (as §39.2, both parts scaled); `L3_6_cP070`, `L3_6_cP130` (payload part only);
  `L3_6_cB070`, `L3_6_cB130` (body part only); `L3_cB070`, `L3_cB130` (N6 term off, body part only).
- **Reproduction check:** L3, L3_6, c070, c130 against `results/gd7/F-hover.mat` - every value identical expected;
  the count and the max |d| are printed; a mismatch is recorded and the reading is still printed.
- **Per column** (one set = valid in all 10 columns; the unsaturated subset, `tilt_sat_frac` < 1 % in every column,
  printed as well): pooled error; excess over its nominal counterpart (L3_6_* → L3_6, L3_cB* → L3); **mean error vector**
  ē (γ_d − γ averaged over t ≥ 140 s, per axis); **DC share** = pooled |ē| / pooled error; **DC shift** = pooled
  |ē − ē of the nominal counterpart|; **|mean N6 delta|** over t ≥ 140 s (from the `P2_N6` log; N6 columns only),
  pooled; h_model (information).

### 42.2 Reading (fixed now; on the one set; the unsaturated subset is printed, not read)
- **(i)** (L3_cB − L3) / (L3_6_cB − L3_6) **< 0.25** at s = 0.7 and at s = 1.3 - the body C_D·A error does its damage
  through the N6 term, not directly;
- **(ii)** DC shift(L3_6_cB) / DC shift(L3_6_cP) **in [1.5, 3.0]** at both s (§41.3 predicts 2: mismatch
  (1 − s)·F_body against 0.5 (1 − s)·F_body);
- **(iii)** DC share of L3_6_c070 and of L3_6_c130 **> 0.5**.
- All three met → **SUPPORTED (§41.3)**; otherwise **NOT SUPPORTED**, with the failed conditions printed. SE (day
  jackknife), LOO and by-day median are printed for the three ratios. Either way F3 = FAILS stands; this is the one
  diagnostic round for F3 (no second); the result feeds only the design of (iii) (§42.0).

### 42.3 E3, D2-thrust, B3 - circle on S40 (as §39.3)
- Circle (`Test 4`), K 0.5, m_p 0.5, L 1.0; set **S40** (SHA `1db1de02532a3896…`); columns **L0 L2 L3 V** (L0 DoHarm 1;
  L2/L3/V DoHarm [0 1]); `TauPred` **290 ms** and `TauPrev` **180 ms** at every level (§6.5 lists the trajectory
  and L as measured in advance; sensor noise, thrust limit and ζ_s are not in that list → nominal τ, stated);
  statistics as §32 / §39.3; one-set rule per level; **nominal level = D2's rows** on S40 (nothing run; printed
  with E3).
- **E3:** gyro and accelerometer noise σ × **{0, 3}** (× 1 = nominal); position noise (E4) and accelerometer bias
  unchanged; seeds unchanged (per segment) - × 3 is the same realisation scaled.
- **D2-thrust:** plant maximum total thrust **20.44 N** (f_max 5.11 N per motor: the plant clamp and
  Motor_Allocation) and controller limit `F_TOT_MAX` = 0.9 × 20.44 = **18.396 N** (the nominal 0.9 rule: the
  controller knows its vehicle's limit). Fact (§0.10): hover weight 15.90 N at m_p 0.5; at the 30° tilt clamp the
  vertical capacity is 15.93 N - saturation is expected and reported (tilt_sat_frac, motor sat_frac per column;
  crashes / divergences by the one-set rule). S40 is not re-filtered (the 20.44-N envelope is empty for m_p ≥ 0.5,
  §0.10: "closed-loop saturation sensitivity on the nominal set").
- **B3:** plant ζ_s ∈ **{0.02, 0.12}** (0.05 = D2's rows). The controller has no ζ_s (DO IM at ω_p, unchanged); N6
  is not in these columns.
- Order in the night: F3-diag → E3 (× 0, × 3) → D2-thrust → B3 (0.02, 0.12).

### 42.4 Code, dry run, hours
- `p2_setup`/`pa_configs`: `ImuScale`/`P2ImuScale` (default 1), `ThrustMax`/`P2ThrustMax` (default [] = nominal),
  `PredScale` 4-vector; `run_p2_gd6('TAB', 'Only', {'circle'}, 'Imu'|'ThrustMax'|'Zeta', ...)` (one level per table);
  `run_p2_gd7('F3-diag', ...)` (report `d3_report`); night script `gd7_night14` (both SHAs fixed inside). Octave:
  `p2_setup` compared field by field with the previous version - defaults, the 3-vector PredScale, ZetaS and N6
  cases **bit-exact**, ImuScale 1 bit-exact; mock tests of F3-diag (120 calls, reading, reproduction count), the five
  TAB levels (36 calls each, option reaches pa_configs, one level per table enforced), F-hover and B1/B2 paths
  unchanged, and the whole night script (303 calls).
- **Dry run** (~10 min): `run_p2_gd7('F3-diag', 'TauW', 0.280, 'TauPred', 0, 'DryRun', true)` (1 segment, 10
  columns, raw ē and |mean delta| printed - checks the time-series reads; reproduction on that segment);
  `run_p2_gd6('TAB', 'Only', {'circle'}, 'ThrustMax', 20.44, 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true)`;
  `run_p2_gd6('TAB', 'Only', {'circle'}, 'Imu', 3, 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true)`.
- **Hours** (night 12: ~25 s per hover column-run, ~101 s per circle segment): F3-diag 43 × 10 ≈ 430 runs ≈ **3.0 h**;
  E3 2 × 40 ≈ **2.2 h**; D2-thrust ≈ **1.1 h**; B3 2 × 40 ≈ **2.2 h**; checks 0.2 h → **≈ 8.7 h**.

## 43. DEVIATION: the P2 wind sensor has no noise (σ = 0) — amendment, and a registered sensitivity (2026-09-29, before any σ = 0.1 run)

### 43.1 The deviation (fact). It was found at the equation-check step, after the results existed
- **Specified:**
  - `PLANT_P2_SPEC.md` §2.5 (TriSonica Mini): σ **0.1 m/s** white noise per axis at 20 Hz, delay 50 ms;
  - `core/p2_params.m:35`: `sig_wind = 0.1`;
  - this register §0 (lines 69, 191) and §15.4 / N6 columns ("50 ms late, noisy");
  - `GD2B_DESIGN.md` §6 planned a re-export with `--sensor-noise 0.1`. It was never executed.
- **Implemented:**
  - Every P2 run reads the measured wind from the exported file (`wind_meas_from_file = 1`).
  - The files were exported with `export_wind_sim.py --sensor-noise` at its default 0, so `w_meas ≡ w_plant` (§35
    fact 1).
  - `pa_configs.m:397-404` refuses to add noise to a from-file series.
  - The P2 model has no wind-noise block (`build_p2_plant.m` adds noise to position, accelerometer and gyro only).
  - `sig_wind` is read only by `verification/verify_plant_p2.m` (offline unit test).
  - What IS applied: the 50 ms delay (`SensorDelayMs` → `core/delay_wind_meas.m`) and the 20 Hz hold (`WM_From`,
    Interpolate off).
- **Scope:**
  - Affected: every P2 run from GĐ3 to night 14, in every column that reads the measured wind. That is L2, L3, V,
    L3_6, the PI-MoE input of P / P_6 (its prediction is therefore also made from clean input), and the N6 observer
    input.
  - Not affected: L0 (reads no measured wind), and O / O0 / O150 / O_6 / O6_0 (true-wind oracles).
- **Found** on 2026-09-29, by reading the code against the specification during the equation check
  (`docs/MOBADC_FIDELITY.md` work). No result prompted it. Every registered verdict stays as recorded.
- §0, §15.4 and §35 carry correction markers at the sentences that said otherwise. §35's verdict is not re-read.

### 43.2 Decisions (user, 2026-09-29)
- **(a)** σ = 0 is the configuration that ran. Nights 1–14 are **σ = 0 results** and are kept as recorded. The deviation
  is declared, not repaired retroactively.
- The paper declares the deviation and the sensitivity of §43.3.
- **CONFIRM2 (GĐ10) uses σ = 0**, the same as dev.

### 43.3 Sensitivity `SN` — σ = 0.1 m/s, the registered value (T1; not a gate)
- **Data.**
  - The S40 ∪ S40hover segments are re-exported with white noise **σ 0.1 m/s per axis** on `w_meas` (20 Hz).
  - Seed per segment: `20240601 + 1000003·i` for `wind_real_t150_i*`, and `20740601 + 1000003·i` for `wind_expl_t150_i*`.
    The two offsets make sure a real and an exploration segment with the same index do not share a draw.
  - PI-MoE `w_hat` is recomputed by the export on the noisy input, with the same frozen checkpoint
    `w4_frozen_20hz_t150_train2345_s0`.
  - Output goes to their own directory `wind_sn010/`, under the same file names.
  - `--check-against .`: each new file's `w_true` and `w_plant` must equal the clean file bit for bit, or nothing is
    written. The plant wind is therefore unchanged. The 50 ms delay is applied in the model as always.
  - Commands: `sn_export_cmds` prints the two export commands (M5 dev directory, exploration directory).
- **Runs.**
  - (i) S40 circle, `run_p2_gd6('TAB', 'Only', {'circle'}, 'DataDir', 'wind_sn010', 'TauPred', 0.290,
    'TauPrev', 0.180, 'Sha', '1db1de02532a3896')`. Columns L0 L2 L3 V; L0 serves as the check.
  - (ii) S40hover, `run_p2_gd7('SN-hover', 'TauW', 0.280, 'TauPred', 0, 'Sha', '53facf03712c81ee', 'DataDir',
    'wind_sn010')`. Columns L3 and L3_6, in group N6's configuration.
- **Check, before any reading.** L0 at σ 0.1 must equal D2's L0 on every S40 segment (|d| = 0), because L0 reads no
  measured wind. If not, the files are not the same segments; the reading is not made, and this is printed.
- **Reading (fixed now).**
  - Circle: $Δ_{L3}$ = L3/L2 − 1 and $Δ_V$ = V/L2 − 1 at σ 0.1. Each separately: < 0 AND every LOO value < 0 →
    **SIGN KEPT**, otherwise **NOT KEPT**. The set is the one set, valid in all four columns.
  - Hover: h_model = 1 − L3_6/L3 > 0 AND every LOO value > 0 → **HOLDS**, otherwise **FAILS**. Computed on the one
    set and on the unsaturated subset (`tilt_sat_frac` < 1 % in both columns). Both are printed and neither overrides
    the other.
  - Printed with it (descriptive): the pooled value per column at σ 0.1 against σ 0 on the same segments (circle: D2's
    rows; hover: group N6's values), the by-day median, and SE for h_model.
- **Order and hours.**
  - After night 14, before the (iii) design.
  - Export: python, minutes.
  - Runs: circle 40 × ~101 s ≈ 1.1 h + hover 43 × 2 × ~25 s ≈ 0.6 h + checks 0.2 h → **≈ 1.9 h**.
- **Dry run.** `sn_export_cmds`, then the two export commands, then both runs with `'DryRun', true` (1 segment each).
  The printout shows `sensor (FROM FILE): sigma 0.100`.

### 43.4 Paper
Methods (sensors) states: "the measured wind fed to the controller carries the 50 ms delay and 20 Hz hold of the
anemometer but no additive noise (σ = 0); this deviates from the specified σ = 0.1 m/s and was found after the
results; Section X reports the σ = 0.1 m/s sensitivity (§43.3)". Limitations repeats it.

## 44. Results of night 14 (`gd7_night14`, git `e38a558`, 8.9 h) - F3 diagnostic, E3, D2-thrust, B3 (§42) - facts
Log `results/gd7/night14_20260929_100257.txt` (user's machine). Sensitivity / diagnostic, **not a gate**.
Step 0: `verify_repro` 32 cells with difference 0; `check_results_numbers` 146/146; D2 row 1 (i0000) unchanged. The
code that ran = the §42 registration (`f2ed207` code, `5b04c71` register). The sigma-0 caveat of §43 applies to every
column that reads the measured wind.

### 44.1 F3 diagnostic (§42.1–42.2) - S40hover (43 segments / 43 days)
**Reproduction of F-hover:** 172 of 172 values (L3, L3_6, c070, c130) identical, max |d| 0 → **REPRODUCED**.
One set 43/43 (0 removed); unsaturated subset 40.

| column | pooled [m] | excess | DC share | DC shift [m] | \|mean δ\| [N] | h_model |
|---|---|---|---|---|---|---|
| L3 | 0.01049 | 0 | 0.481 | 0 | - | - |
| L3_6 | 0.00400 | 0 | 0.237 | 0 | 0.0561 | +61.8 % |
| L3_6_c070 | 0.04644 | +0.04244 | 0.993 | 0.04632 | 0.6321 | −342.9 % |
| L3_6_c130 | 0.04295 | +0.03895 | 0.994 | 0.04250 | 0.5707 | −309.6 % |
| L3_6_cP070 | 0.01562 | +0.01161 | 0.978 | 0.01545 | 0.2176 | −49.0 % |
| L3_6_cP130 | 0.01459 | +0.01059 | 0.979 | 0.01405 | 0.1947 | −39.1 % |
| L3_6_cB070 | 0.02956 | +0.02556 | 0.989 | 0.02942 | 0.4080 | −181.9 % |
| L3_6_cB130 | 0.03010 | +0.02609 | 0.993 | 0.02967 | 0.3983 | −187.0 % |
| L3_cB070 | 0.01605 | +0.00556 | 0.496 | 0.00292 | - | - |
| L3_cB130 | 0.00536 | **−0.00512** | 0.400 | 0.00292 | - | - |

| quantity (one set) | s = 0.7 (SE; LOO; by-day) | s = 1.3 (SE; LOO; by-day) | criterion |
|---|---|---|---|
| (i) (L3_cB − L3)/(L3_6_cB − L3_6) | +21.75 % (3.92; [+18.57, +23.13]; +15.37) | **−19.64 %** (3.53; [−20.90, −16.71]; −13.39) | < 25 % → met, met |
| (ii) DC shift cB / cP | 1.904 (0.011; [1.901, 1.912]; 1.933) | 2.113 (0.016; [2.100, 2.120]; 2.064) | [1.5, 3.0] → met, met |
| (iii) DC share of L3_6_c | 0.993 (0.001; [0.993, 0.994]; 0.996) | 0.994 (0.001; [0.994, 0.995]; 0.996) | > 0.5 → met, met |

**Reading §42.2 applied, verbatim: SUPPORTED (§41.3).** The unsaturated subset (printed, not read) meets all three
as well: (i) +18.78 % / −16.92 %, (ii) 1.922 / 2.112, (iii) 0.994 / 0.995. **F3 = FAILS stands (§42.0).**

**Recorded (facts, not read):**
- The excess error of the C_D·A columns is almost entirely a steady offset (DC share ≥ 0.978 in every N6 C_D·A column,
  against 0.237 for nominal L3_6). The shift splits about 1 : 2 between the payload part and the body part, and it is
  the same size at s = 0.7 and at 1.3 - as §41.3 predicts.
- **(i) at s = 1.3 is met through a negative ratio.** Without N6, body C_D·A × 1.3 *lowers* L3 by 49 %
  (0.01049 → 0.00536), while × 0.7 raises it by 53 %. The shift is small (0.0029 m) and the DC share falls to 0.40.
  That is, the error changes mostly in its oscillating part.
- A possible reason, offered as a hypothesis and not a reading: the controller's feed-forward models only the body drag
  (`p2_prm_w` = K_w), while the plant also puts K·F_body = 0.5·F_body on the payload. A body gain above 1 then covers
  part of the payload's wind force. This bears on the design of (iii) (MASTER_PLAN GĐ8). Nothing is registered or
  changed here.
- Even at the nominal parameters, `|mean δ|` is not zero: 0.056 N on the one set, 0.030 N on the unsaturated subset. The nominal N6 term also carries a small steady part.

### 44.2 E3, D2-thrust, B3 (§42.3) - circle on S40, columns L0 L2 L3 V, TauPred 290 ms, TauPrev 180 ms

| level | one set | L0 | L2 | L3 | V | L3/L2 − 1 (SE; LOO; by-day) | V/L2 − 1 (SE; LOO; by-day) | L2/L0 − 1 | tilt_sat > 1 % | motor sat max |
|---|---|---|---|---|---|---|---|---|---|---|
| nominal (D2 rows) | 40/40 | 0.04369 | 0.03494 | 0.01530 | 0.01355 | −56.22 % (3.23; [−58.96, −55.94]; −64.87) | −61.21 % (3.20; [−63.88, −60.96]; −69.04) | −20.04 % | 2/3/3/3 | 0 |
| **E3** IMU × 0 | 40/40 | 0.04369 | 0.03494 | 0.01530 | 0.01355 | −56.22 % (3.23; [−58.96, −55.94]; −64.87) | −61.21 % (3.20; [−63.88, −60.96]; −69.04) | −20.04 % | 2/3/3/3 | 0 |
| **E3** IMU × 3 | 40/40 | 0.04369 | 0.03494 | 0.01530 | 0.01355 | −56.21 % (3.23; [−58.96, −55.94]; −64.87) | −61.21 % (3.20; [−63.88, −60.96]; −69.05) | −20.04 % | 2/3/3/3 | 0 |
| **D2-thrust** 20.44 N | **38/40** | 0.03941 | 0.03504 | 0.01536 | 0.01377 | −56.16 % (3.94; [−59.76, −55.87]; −64.90) | −60.71 % (4.16; [−64.55, −60.44]; −68.62) | −11.07 % | 1/1/1/1 | 0.0022 |
| **B3** ζ_s 0.02 | 40/40 | 0.04382 | 0.03509 | 0.01542 | 0.01384 | −56.06 % (3.21; [−58.79, −55.78]; −64.75) | −60.55 % (3.13; [−63.16, −60.31]; −68.17) | −19.92 % | 2/3/3/3 | 0 |
| **B3** ζ_s 0.12 | 40/40 | 0.04346 | 0.03465 | 0.01523 | 0.01316 | −56.04 % (3.20; [−58.77, −55.76]; −64.55) | −62.03 % (3.27; [−64.77, −61.78]; −70.19) | −20.27 % | 2/3/2/3 | 0 |

(Pooled values in m; the most influential segment is `wind_real_t150_i0251` in every row except D2-thrust, where it is
`wind_expl_t150_i0244` or `i0017`.)
- **E3:** IMU noise × 0 and × 3 leave every pooled value unchanged at the printed precision; the ratios move by less
  than 0.001 point. On P2 the gyro noise enters only ω in (18), and η is clean (§4.8 of PLANT_P2_SPEC).
- **D2-thrust (20.44 N, F_TOT_MAX 18.396 N):** two segments removed by the one-set rule.
  - `wind_real_t150_i0251`: L2 crashed at 96.18 s (`UAV_Plant/Int_etadot`); L0 0.1155, L3 0.0719, V 0.0718 ran.
  - `wind_expl_t150_i0162`: every column crashed (`Int_etadot` at 45.2 / 25.1 / 118.3 s; `Attitude_Observer/Int_za`
    at 40.3 s).
  - On the remaining 38 segments, L3/L2 and V/L2 are within 0.5 points of nominal. Two segments degrade visibly:
    `i0244` L2 0.0650 / L3 0.0458 (nominal 0.0365 / 0.0235), and `i0294` L3 0.0250 (nominal 0.0135).
  - Motor saturation fraction max 0.0022.
  - Recorded, not diagnosed (sensitivity block, §42.3).
- **B3:** ζ_s 0.02 → 0.12 moves L3/L2 − 1 within 0.2 point and V/L2 − 1 from −60.55 % to −62.03 % (nominal −61.21 %).

## 45. GĐ8 (iii) FULL - design and acceptance - **REGISTERED 2026-09-29** (approved by the user with the additions of §45.7; before any (iii) code or run)
Drafted in `3b1d3a4`; approved by the user on 2026-09-29 with additions. The open points of §45.6 are answered there;
§45.7 holds the additions. Nothing of (iii) had been coded or run when this was registered.

### 45.0 Motivation (facts from §41, §44)
- The present N6 form (`delta = d_pred(τ) − m_L g θ̂(t)`, observer on the DO estimate) **fails F3** (§41.1).
- The mechanism is confirmed (§44.1). Any mismatch between the model's own equilibrium and the DO's static estimate
  turns into a persistent force offset (DC share ≥ 0.98), split about 1 : 2 between the payload C_D·A and the body
  C_D·A.
- Night 14 also showed that the controller's feed-forward misses the payload's wind force. Body C_D·A × 1.3 **alone**
  lowered hover L3 by **49 %** (0.01049 → 0.00536 m). The plant puts K·F_body = 0.5·F_body on the payload, and the
  controller models only the body.

### 45.1 The (iii) term (user decisions 2026-09-29)
- **Model:** a linear pendulum per horizontal axis (small angle, UAV-held form of `core/pend_lin_model.m`), **run
  open loop**. There is no observer correction from the DO. That is what makes it DC-consistent: its state settles at
  its own equilibrium, so the predicted change over τ goes to 0 at DC. Whatever the model gets wrong is left to the DO.
  $$\ddot\theta_i = -\tfrac{g}{L}\theta_i - 2\zeta_s\omega_n\dot\theta_i + \frac{F_{wL,i}}{m_L L} - \frac{a_{c,i}}{L},\qquad i \in \{x, y\}$$
- **Inputs:**
  - The **measured** wind (50 ms late, 20 Hz hold, as every column), through the payload drag
    $F_{wL} = (K K_w/U_{ref})\,|w - v_L|(w - v_L)$ with $v_L = \nu_c + L\dot\theta$ (the measured UAV velocity plus the
    model's own swing).
  - The **commanded** UAV acceleration $a_c = a_d - g e_3$ (z up: $a_d$ carries $+g e_3$), where $a_d$ is Guo (9),
    recomputed inside the block from γ_d, ν_d, γ̈_d, γ_c, ν_c and the LQI integrator state z_I (K1 = 0 in every
    Guo-gain column). It does not depend on any estimate, so there is no algebraic loop. (P2_SPEC_AUDIT L4 decision:
    (iii) uses the commanded acceleration.)
- **Output = the WHOLE payload force on the UAV**, static and oscillating, predicted τ_m ahead with the inputs held
  (exact ZOH propagation, as `pend_lin_predict`):
  - horizontal: $\hat d_{M,i}(t+\tau_m) = m_L g\,\theta_i(t+\tau_m)$;
  - vertical, quasi-static: $\hat d_{M,z} = -m_L(g + a_{c,z})$.
  - DC gain: constant wind gives θ = F_wL/(m_L g), so $\hat d_M = F_{wL}$. **The payload's wind force passes through
    the cable with gain 1.** Constant acceleration gives $\hat d_M = -m_L a$.
- **Compensation (direct, not the N6 delta form):**
  $$F = m a_d - \hat d_M(t+\tau_m) - P_{\tau_p}[\hat r] - \hat d_{lf}$$
  - $\hat d_M(t+\tau_m)$ is the model's force τ_m ahead.
  - $P_{\tau_p}[\hat r]$ is the existing payload predictor at τ_p applied to the DO's **residual** estimate $\hat r$.
  - $\hat d_{lf}$ is the body wind feed-forward (unchanged, `P2_WindHat`, nominal K_w).
- **The DO estimates only the residual.** The model's current force $\hat d_M(t)$ is added to the DO's known-input
  port (the same port as $\hat d_{lf}$, i.e. $G(\hat d_{lf} + \hat d_M(t))$ in (12)) through a Sum block in front of
  `DO_12`. The DO/do_derivative code is not touched. Then $\hat\xi$ converges to $d_{mf} - \hat d_M(t)$.
  - The DO's internal model is that of L3 (DC + the trajectory's table).
  - With (iii) on, the z-axis DC trim of §8 moves from the DO to the model (the model already supplies −m_L g), so the
    DO's z trim is 0.
  - Steady state: $\hat d_M(t+\tau_m) + \hat r = \hat d_M^{eq} + (d_{mf} - \hat d_M^{eq}) = d_{mf}$. **No DC offset for
    any parameter error.**
- **Parameters (controller side, nominal):** L, m_L, K·K_w/U_ref (payload C_D·A), ζ_s = 0.05, g. Initial state: hanging
  at rest (θ = θ̇ = 0), like the plant.
- **Horizons:**
  - τ_p = the trajectory's registered payload τ\* (hover 0, circle 290, T3b 340, square 120, T5 170 ms).
  - τ_m is measured per trajectory by **N0-iii**, the §7.1 procedure: fixed-5, coarse 0:20:400 ms, one bounded edge
    extension, fine ±20 ms at 10 ms, with τ_p fixed as above.
  - Hover goes first, because the acceptance runs on hover.

### 45.2 Variants for comparison (not accepted or rejected)
- **(iii-0) static:** no pendulum dynamics. The wind feed-forward becomes $(1+K)\hat F(w, \nu_c)$, i.e. `p2_prm_w` =
  (1+K) K_w (= `PredScale` body 1.5), and the DO takes it as known input as today. Available without new code.
- **(iii-m) measured acceleration:** as (iii), but $a_c$ ← the accelerometer (`nu_dot_c`, simplified IMU, L4). It runs
  with the accelerometer-bias sensitivity {0, 0.086, 0.17, 0.39} m/s² (bias direction as §45.6 (1)).

### 45.3 Acceptance condition (§42.0, extended by the user 2026-09-29) - S40hover
- **(iii)** is accepted only if **h_model = 1 − L3_iii / L3 > 0 AND every LOO value > 0 in EVERY variant**:
  - nominal;
  - L ±20 % (`L080`, `L120`);
  - m_L ±20 % (`m080`, `m120`);
  - payload C_D·A ±30 % (`cP070`, `cP130`);
  - body C_D·A ±30 % (`cB070`, `cB130`);
  - wind sensor σ = 0.1 m/s (files of §43.3). This variant uses L3 at σ 0.1 (group SN-hover) as its reference; every
    other variant uses nominal L3 (§39.2 convention).
- The one set is valid in every column. The unsaturated subset is printed as well. Failing any single variant means
  (iii) is **not** reported as a contribution (§42.0).
- Before the acceptance runs, three checks:
  - **C1:** (iii) off must be bit-exact: `verify_repro`, D2 row 1, N6 recheck.
  - **C2:** offline, plant P2 in prescribed-motion mode against the open-loop model, with the same wind and
    acceleration on the 5 fixed segments. e1 = RMS(model − plant d_mf,xy)/RMS(plant) must be ≤ 10 % for θ RMS ≤ 10°.
    Larger angles are reported.
  - **C3:** offline, with payload C_D·A × 0.7 in the model and constant wind, the closed-form steady offset of the
    compensation must be 0.

### 45.4 Implementation (after approval)
- `simulink_blocks/p2_m3_term.m` (MATLAB Function, state 4 = [θx θ̇x θy θ̇y], Unit Delay at 1 kHz) and
  `core/p2_m3_prm.m`.
- `build_p2_plant` step 8:
  - Variant `P2_M3_Sel` on the payload channel: compensation = $\hat d_M(t+\tau_m) + P_{\tau_p}[\hat r]$.
  - A Sum in front of `DO_12`'s $\hat d_{lf}$ port that adds $\hat d_M(t)$ when p2_m3 = 1.
  - When p2_m3 = 0 nothing is read, so the build is bit-exact by construction.
- Also: `p2_setup`/`pa_configs` options `M3`, `M3TauMs`, `M3Acc` ('cmd' | 'meas'), the z-trim change, runners
  N0-iii (hover, circle) / iii-hover / iii-circle (no-harm, §45.7); `AccBias` with the axes rule of §45.6 (1).

### 45.5 Hours (after approval)
C1 + C2 ≈ 0.5 h; N0-iii hover ≈ 1.0 h; acceptance 43 segments × 10 (iii) columns + (iii-0) + (iii-m) at bias 0 ≈
43 × 12 × 25 s ≈ **3.6 h** (L3 reused from N6 and from SN-hover, spot-checked); (iii-m) at the three bias levels
0.086 / 0.17 / 0.39 m/s² ≈ 43 × 3 × 25 s ≈ 0.9 h → **≈ 6.0 h** in all (one night).

### 45.6 Open points - answered by the user (2026-09-29)
1. **Accelerometer bias** (for (iii-m), and the same rule for INDI (H3) and IM-est):
   - **0.086 and 0.17 m/s²: horizontal only.** The bias vector is b·[cos φ, sin φ, 0], φ uniform on [0, 2π).
   - **0.39 m/s²: all three axes.** The bias vector is b·u, u uniform on the unit sphere.
   - b is the **norm** of the bias vector at every level (my reading of "0.39 on all three axes"; stated here so it
     can be corrected before any bias run).
   - **Random direction per segment, seeded by the segment:** MT19937 seed 7000000 + 100·i + 31 (i = the segment
     index of the file name; the sensor seeds of `p2_setup` use + 1 … + 23 of the same base). The same segment gets
     the same direction at every level with the same axes; the directions are printed per segment.
   - Level 0 = the nominal zero vector (bit-exact).
2. **Vertical channel quasi-static** $\hat d_{M,z} = -m_L(g + a_{c,z})$: agreed.
3. **Acceptance on hover only:** agreed, plus the circle no-harm check of §45.7.

### 45.7 Additions of the user (2026-09-29)
- **Design choice, stated:** the (iii) model runs **open loop** - it is **not corrected by any payload-state
  estimate** (no observer on θ, no DO feedback into the model). The DC consistency of §45.1 rests on that.
- **Fallback (iii-obs):** the same model with an observer correction (e.g. from the DO's payload estimate). It is
  **registered separately only if (iii) fails the acceptance of §45.3**; it is not run otherwise, and it is not a
  second try at the same acceptance without a new registration.
- **No-harm check on the circle (S40; descriptive, reading fixed now):**
  - Circle (`Test 4`), K 0.5, m_p 0.5, L 1.0, set S40 (SHA `1db1de02532a3896…`), nominal plant, σ = 0.
  - Columns: **L3** (the D2 row on S40, `TauPred` 290 ms, reused; spot-checked on i0000) and **L3+(iii)** (the same
    column with (iii) on; τ_p = 290 ms; τ_m = τ*_m,circle from **N0-iii circle**, the §7.1 procedure on fixed-5, run
    before the check).
  - Δ = pooled(L3+(iii)) / pooled(L3) − 1 on the one set valid in both; SE (day jackknife), every LOO value, by-day
    median; tilt_sat_frac per column.
  - **Reading:** Δ > 0 AND every LOO value > 0 → **WORSE ON THE CIRCLE**: the paper states it as a limitation of the
    regime in which (iii) is used (hover / the tested conditions only). Otherwise → **NOT WORSE** (no claim of
    improvement is read from it).
  - Not part of the acceptance of §45.3, and it cannot rescue or sink it.
- **Hours:** §45.5 (≈ 6.0 h) + N0-iii circle ≈ 0.9 h + no-harm 40 × ~30 s ≈ 0.3 h → **≈ 7.2 h**.

## 46. Night 15 - SN σ 0.1 (§43.3), the 2² m_p × L corners (S40), Guo's four controllers on circle_main - registered 2026-09-29, before any run
Sensitivity / descriptive (§30): **not a gate**; recorded verbatim. The sigma-0 caveat of §43 applies to every block
except SN.

### 46.0 User decisions (2026-09-29, after night 14), recorded before the run
- Night 15 = SN (§43.3) + the 2² payload × cable corners on S40 (the envelope of each corner's own m_p, Weak / Medium
  split) + PID / DO / ESO on circle_main as Guo defines them.
- **A7 (circle ω × 1.5) is dropped.** **A6 (T3a) moves to a later appendix** (not in night 15).
- GĐ8 (iii): §45 is a draft for approval; nothing of it runs in night 15.

### 46.1 SN - as registered in §43.3 (nothing changed)
Circle S40 (L0 L2 L3 V, L0 = the D2 check) and S40hover (L3, L3_6), wind-sensor σ 0.1 m/s from `wind_sn010/`; check
and reading as §43.3. Added check at step 0 of the night script: all 51 files (15 real + 36 exploration, the
`sn_export_cmds` lists) exist in `wind_sn010/`, otherwise **nothing** of night 15 runs; `sn_check_dir` asserts
`sensor_noise` = 0.1 and `w_meas ≠ w_true` in every file.

### 46.2 The 2² corners - circle on S40
- Circle (`Test 4`), K 0.5, set **S40** (SHA `1db1de02532a3896…`), columns **L0 L2 L3 V** (as §42.3); plant and
  controller use the corner's m_p and L together (the controller trim and the DO's IM take the level's values, as B1 /
  B2, §39.3).
- **Corners:** (m_p, L) = (0.25, 0.5), (0.25, 1.5), (0.65, 0.5), (0.65, 1.5).
- **τ:** `TauPred` = τ\* of the corner's L: **L 0.5 → 330 ms** (§41.4, B2), **L 1.5 → 260 ms** (§16.2). m_p is not in the
  §6.5 list of what τ depends on (trajectory, L), so it keeps the L value (stated). `TauPrev` **180 ms** at every corner.
- **Envelope of each corner's own m_p** (§0.10, K 0.5): U_max **9.99** (m_p 0.25) / **11.35** (m_p 0.65). S40 has
  U ≤ 8.02 m/s, so all 40 segments are expected inside at both m_p. `bin_report` prints the count and restricts the
  split to the envelope anyway.
- **Expected (from B1, §41.4):** `wind_real_t150_i0251` crashed / diverged in every column at m_p 0.25 → at both
  m_p 0.25 corners the one-set rule removes it if it recurs. Recorded as a controller limitation (§42.0), not diagnosed.
- **Report per corner (descriptive):** one set valid in all four columns; pooled per column; L3/L2 − 1 and V/L2 − 1
  (SE day jackknife; LOO; by-day median); L2/L0 − 1; tilt_sat_frac > 1 % per column; motor sat max. Then the same
  quantities per wind bin, **Weak U < 6** and **Medium 6 ≤ U ≤ 12** (the §7 / N5 bins), on the one set inside the
  envelope; n and days per bin printed; a bin with fewer than 2 segments is not computed. No verdict words; the
  corners are placed next to the B1 / B2 rows of §41.4 in the paper's sensitivity table.

### 46.3 Guo's four controllers on circle_main (REVIEWER_MATRIX H2; H1 = L0)
- **Definitions (Guo 2020 Remark 9 and the switch table of `pa_configs`; switches = [DO, position ESO, attitude ESO]):**
  - **Classical** {0, 0, 0}: (9), (16), (18) with every estimate off - PD position and attitude laws with Guo's gains;
  - **ESO** {0, 1, 1};
  - **DO** {1, 0, 0};
  - **MOBADC** {1, 1, 1}.
  - Every one: column `g_base` - Guo's DO internal model (`DoHarm` 1, no DC mode), no measured-wind feed-forward, no
    payload predictor, `TauPrev` 0; circle (`Test 4`), K 0.5, m_p 0.5, L 1.0; the P2 plant and sensors as everywhere.
- **Set:** circle_main, cap 4 per day, SHA `a227e9d87a2ac436…`, **134 segments** (the D2 set).
- **Metric:** per segment the mean ȳ and the standard deviation s of ‖γ − γ_d‖ over t ≥ 140 s (Guo's definitions in
  Table 1, `docs/MOBADC_FIDELITY.md`), and the pooled RMS of ‖γ − γ_d‖ (this study's metric, as D2). The window
  differs from Guo's (MOBADC_FIDELITY, Table S4 section).
- **Check:** MOBADC must equal D2's L0 on every one of the 134 segments (|d| = 0; same configuration). A difference
  is printed and recorded; the report is still printed.
- **Report (descriptive):** one set valid in all four; the Table 1 layout (mean of ȳ ± mean of s) next to the pooled
  value; each controller against Classical (pooled ratio − 1; SE; LOO; by-day); tilt_sat_frac. Guo's Table 1 Test 4
  numbers (Classical 0.1502 ± 0.0700, ESO 0.2054 ± 0.0205, DO 0.0725 ± 0.0480, MOBADC 0.0350 ± 0.0202 m; checked
  against the PDF) are printed for the layout only - a different experiment; nothing is read from the comparison.
- **Expected fact, from the configuration (closed form, written before the run):** at the hover trim the payload weight
  −m_L g sits in the position ESO's z_p3(3), because Guo's DO has no DC mode (GD2B_DESIGN §3 exception). In
  **Classical and DO** the position ESO is switched off, so the weight is not compensated, and with K1 = 0 (no
  integrator in Guo's law) the z channel settles at an offset m_L g / (m K_γ,z) = 0.5 · 9.81 / (1.121 · 35)
  ≈ **0.125 m**. This is Guo's definition taken literally. It will dominate their pooled error; the per-axis split is
  not coded and is not added (no registration beyond the plan without the user).

### 46.4 Order, code, dry run, hours
- `experiments/gd7_night15.m` (code `46e76a5`): step 0 checks (verify_repro, check_results_numbers, D2 row 1 unchanged,
  `wind_sn010/` complete) → STOP on any failure; 1 SN (circle, hover); 2 corners; 3 GUO. Each step resumable; an error
  in one step is printed and the next runs. Log `results/gd7/night15_*.txt`.
- Octave mock of the whole night script: 89 calls, the four switch settings reach `pa_configs`, corner tags
  `_mpXXX_LYYY`, the SN tag `_sn010`.
- **Before the night (user's machine):** `mkdir wind_sn010`, then the two python commands printed by `sn_export_cmds`
  (with the M5 dev and the exploration directories filled in).
- **Dry run** (~15 min, 1 segment each):
  - `run_p2_gd6('TAB', 'Only', {'circle'}, 'DataDir', 'wind_sn010', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true)`
    (the printout shows `sensor (FROM FILE): sigma 0.100`);
  - `run_p2_gd7('SN-hover', 'TauW', 0.280, 'TauPred', 0, 'DataDir', 'wind_sn010', 'DryRun', true)`;
  - `run_p2_gd6('TAB', 'Only', {'circle'}, 'MP', 0.25, 'L', 0.5, 'TauPred', 0.330, 'TauPrev', 0.180, 'DryRun', true)`;
  - `run_p2_gd6('GUO', 'DryRun', true)` (four controllers on i0000; MOBADC must print L0 0.0414).
- **Hours:** SN ≈ 1.9 h (§43.3); corners 4 × 40 × ~101 s ≈ 4.5 h; GUO 134 × 4 runs ≈ 4.9 h; checks 0.2 h → **≈ 11.5 h**.

### 46.5 Amendment before the run (user, 2026-09-29): GUO prints the error split by axis
- Guo's definitions stay as §46.3 for night 15.
- **For every controller**, per segment over t ≥ 140 s, from the same run (no extra run; `KeepTraj` only exposes the
  γ and γ_d series already computed, and they are not stored):
  - horizontal RMS $\sqrt{\overline{e_x^2 + e_y^2}}$;
  - vertical RMS $\sqrt{\overline{e_z^2}}$;
  - mean vertical error $\overline{e_z}$, with e = γ_d − γ (positive = the UAV below its reference).
- Report: pooled horizontal and vertical RMS per controller on the one set, the mean of $\overline{e_z}$, and each
  controller against Classical for the horizontal part (pooled ratio − 1; SE; LOO; by-day). Descriptive, nothing read.
- The §46.3 prediction (Classical and DO: $\overline{e_z}$ ≈ +0.125 m) is compared with the printed value; a
  difference is recorded, not diagnosed.
- The MOBADC = D2 L0 check is unchanged (the norm metric is computed exactly as before).
- Hours unchanged (≈ 11.5 h).

## 47. Guo's Classical and DO with the known payload weight pre-compensated (Classical+trim, DO+trim) - registered 2026-09-29, before any code or run; a later night
Descriptive, **not a gate**; complements §46.3 (user decision 2026-09-29).
- **Definition:** Classical {0, 0, 0} and DO {1, 0, 0} as §46.3, plus a constant feed-forward of the **known** payload
  weight in the position law: $\hat d_{trim} = -m_L g\,e_3$, i.e. $F = m a_d - \hat d_{mf} - \hat d_{lf} - \hat d_{trim}$
  (z up; $\hat d_{mf}$ = 0 in Classical). m_L = the nominal 0.5 kg the controller already uses for its hover trim.
  - The ESO's z_p3(3) trim is not used by these two (the ESO is switched out); nothing else changes.
  - MOBADC and ESO are not re-run (their trim is inside the ESO, which is in the law).
- **Set, metric, report:** circle_main (SHA `a227e9d87a2ac436…`, 134 segments), `g_base`, as §46.3 + the axis split of
  §46.5; the four §46.3 controllers (night 15 rows, reused) and the two +trim rows in one table; each +trim row
  against its own untrimmed row and against MOBADC (pooled ratio − 1; SE; LOO; by-day).
- **Check:** with the trim switched off the build is bit-exact (verify_repro, D2 row 1); the +trim rows' mean
  $\overline{e_z}$ is printed next to the untrimmed one.
- **Code (later):** one Constant (−m_L g e₃ · p2_trim_ff) added to the position law's disturbance input when the new
  workspace switch `p2_trim_ff` = 1 (default 0; the sum with 0 changes no bit, as the LQI K1 term); `pa_configs`
  'P2TrimFF'; `run_p2_gd6('GUO', 'Trim', true)`.
- **Hours:** 134 × 2 runs × ~25 s ≈ **1.9 h**. Placed in a night after night 15 (with the (iii) night or the H3/H4 night).

## 48. Rebuild, nights 16-17 - (iii) (sec 45) and the weight trim (sec 47): implementation notes, order, commands, hours - registered 2026-09-29, before any build or run
Code `51a2bfe`. Nothing here changes a reading of sec 45 or sec 47.

### 48.1 Implementation notes (how sec 45 / 47 are coded; stated before any run)
- **a_c (commanded):** Guo (9) recomputed inside `P2_M3` from γ_d, ν_d, γ̈_d (the reference Gotos) and γ_c, ν_c (the
  controller's measurements): $a_c = K_γ(γ_d − γ_c) + K_ν(ν_d − ν_c) + \ddot γ_d$ (= a_d − g e₃). The LQI law is never on
  in these columns (`lqi_on` = 0; `p2_setup` refuses M3 with it), so z_I of sec 45.1 does not enter.
- **Wind force on the payload:** $k_L |r| r$ with $r = (w − ν_c − L\dot θ)_{xy}$ (horizontal; the same form as the
  validated N6 model, `pend_lin_predict`); the vertical wind is dropped, as in the plant.
- **No gate:** the model runs from t = 0 in every (iii) column (it also supplies −m_L g from t = 0, since the DO/ESO z
  trim is 0 with M3). The N6 term's wind gate (`WD_gate`) is not used.
- **Rate:** the block runs at 1 kHz with its inputs held (as N6); state IC 0 (hanging at rest, like the plant).
- **(iii-m):** $a_c$ ← the accelerometer signal `V_acc_s` (inertial frame, noise, bias of sec 45.6 (1)).
- **(iii-0):** column `L3_iii0` = L3 with `PredScale` [1 1 1 1.5] (body feed-forward × (1 + K)), no model.
- **Parameter variants:** `L3_iii_<L|m|cP|cB><pct>` scale the model's L, m_L, payload C_D·A (k_L), and the body
  feed-forward (`p2_prm_w`) respectively; the plant stays nominal (as sec 39 / 42).
- **Weight trim (sec 47):** `P2_TRIM_Sel` adds `p2_trim_ff_v` = [0; 0; −m_L g] to dmf_hat after the Remark 9 switch
  (`Manual Switch`), so it is in the law with every estimate off.
- **Rebuild:** `build_p2_plant('Save', true)` adds, in one build, H3/H4 (sec 40, not yet in the saved model), (iii) and
  the trim. Compile check states: 0, P2, GD3 off, N6, H3, H4, (iii), (iii-m), trim, 0.

### 48.2 Before night 16 (user's machine, MATLAB not running a batch)
1. `git pull`; `build_p2_plant('Save', true)`; B1: `verify_repro` (32/32), `check_results_numbers` (146/146), `check_all`,
   `python tools/extract_eml.py baseline1.slx --check simulink_blocks` (must now show p2_h3_indi, p2_h4_dobaf,
   p2_m3_term as MATCH); report the fingerprint; update `docs/SNAPSHOT.md` MD5; push `baseline1.slx`.
2. Dry run (~15 min): `check_m3_offline('Files', {'wind_real_t150_i0000.mat'}, 'Stop', 60, 'TStat', 30)`;
   `run_p2_gd6('N0M3', 'Only', {'hover'}, 'TauPred', 0, 'DryRun', true)`;
   `run_p2_gd6('GUOTRIM', 'DryRun', true)` (the printout shows "known payload weight pre-compensated", mean e_z ≈ 0).

### 48.3 Night 16 - `gd8_night16` (≈ 4.2 h)
- 0: model holds the new blocks; **C1** (verify_repro, check_results_numbers, D2 row 1, N6 recheck on its first
  segment - bit-exact), **C2 + C3** (`check_m3_offline`, fixed-5) → STOP on any failure (sec 45.3: (iii) is not run).
- 1: N0M3 hover (TauPred 0) → τ*_m,hover; 2: N0M3 circle (TauPred 290 ms) → τ*_m,circle (sec 7.1 procedure; an
  EDGE-UNRESOLVED result is not usable).
- 3: GUOTRIM (sec 47) on circle_main.
- Hours: checks + C2/C3 ≈ 0.4 h; N0M3 hover ≈ 0.9 h, circle ≈ 1.1 h (~26 τ points × 5 segments); GUOTRIM ≈ 1.9 h.
- **After night 16:** τ*_m,hover and τ*_m,circle are transcribed here and committed before night 17.

### 48.4 Night 17 - `gd8_night17(tau_m_hover, tau_m_circle)` (≈ 4.9 h)
- 0: verify_repro, D2 row 1; the two arguments must equal the saved N0M3 results and neither may be EDGE-UNRESOLVED.
- 1: `iii-hover` (S40hover): L3 (reused from F-hover, spot-checked) + 14 run columns (≈ 43 × 14 × 25 s ≈ 4.2 h).
- 2: `iii-hover-sn` (σ 0.1, L3 reused from SN-hover) ≈ 0.3 h → the sec 45.3 acceptance line.
- 3: `iii-circle` (S40, L3 reused from D2, spot-checked) ≈ 0.3 h → the sec 45.7 no-harm reading.

## 49. Results of night 15 (`gd7_night15`, git `025b88f`, 10.2 h) - SN σ 0.1, the 2² corners, Guo's four controllers (§46) - facts
Log `results/gd7/night15_20260929_215248.txt` (user's machine). Sensitivity / descriptive, **not a gate**.
Step 0: `verify_repro` 32 cells, largest difference 0; `check_results_numbers` 146/146; D2 row 1 (i0000) unchanged;
`wind_sn010/` complete (51 files, `sensor_noise` 0.1 in every one, w_meas ≠ w_true). The code that ran = the §46
registration (`46e76a5` code, `f53d30b` register, `877d6a8` axis split, §46.5).
Export of the noisy files (§43.3): 15 real segments on the user's machine (`E:\windataset\m5`), 36 exploration
segments on the user's machine (`E:\m5_explore`); both printed "every w_true/w_plant equal ... bit for bit".

### 49.1 SN - wind-sensor σ 0.1 m/s (§43.3)
**Circle, S40** (one set 40/40; TauPred 290 ms, TauPrev 180 ms). Check L0 = D2 on every segment: **YES** (max |d| 0).

| column | σ 0.1 pooled [m] | σ 0 (D2 rows) | change |
|---|---|---|---|
| L2 | 0.03494 | 0.03494 | +0.00 % |
| L3 | 0.01530 | 0.01530 | +0.05 % |
| V | 0.01356 | 0.01355 | +0.10 % |

| quantity | σ 0.1 (SE; LOO; by-day) | σ 0 | reading §43.3 |
|---|---|---|---|
| L3/L2 − 1 | −56.20 % (3.22; [−58.94, −55.92]; −64.91) | −56.22 % | **SIGN KEPT** |
| V/L2 − 1 | −61.17 % (3.18; [−63.84, −60.92]; −68.95) | −61.21 % | **SIGN KEPT** |

**Hover, S40hover** (TauPred 0; one set 43/43, unsaturated subset 40):

| set | L3 σ 0.1 (vs σ 0) | L3_6 σ 0.1 (vs σ 0) | h_model σ 0.1 (SE; LOO; by-day) | σ 0 | reading |
|---|---|---|---|---|---|
| one set | 0.01050 (+0.11 %) | 0.00414 (+3.41 %) | +60.55 % (3.28; [+57.77, +61.86]; +53.83) | +61.81 % | **HOLDS** |
| unsaturated | 0.00798 (+0.20 %) | 0.00320 (+5.01 %) | +59.93 % (1.96; [+58.36, +60.47]; +53.44) | +61.76 % | **HOLDS** |

Recorded: the σ 0.1 noise changes the circle columns by ≤ 0.1 % and hover L3 by ≤ 0.2 %; the N6 column (L3_6) moves
most (+3.4 % / +5.0 %). The changes are not zero, so the noisy files were read.

### 49.2 The 2² corners - circle on S40, L0 L2 L3 V, TauPrev 180 ms

| corner (m_p, L), τ | one set | L0 | L2 | L3 | V | L3/L2 − 1 (SE; LOO; by-day) | V/L2 − 1 (SE; LOO; by-day) | L2/L0 − 1 | tilt_sat > 1 % |
|---|---|---|---|---|---|---|---|---|---|
| (0.25, 0.5), 330 ms | **39/40** | 0.03628 | 0.02893 | 0.01657 | 0.01457 | −42.72 % (1.76; [−43.78, −42.51]; −47.39) | −49.65 % (1.83; [−50.71, −49.46]; −54.26) | −20.25 % | 4/5/5/5 |
| (0.25, 1.5), 260 ms | **39/40** | 0.03681 | 0.02961 | 0.01933 | 0.01404 | −34.71 % (1.50; [−35.59, −34.46]; −38.35) | −52.59 % (2.23; [−53.83, −52.31]; −58.94) | −19.55 % | 5/5/5/5 |
| (0.65, 0.5), 330 ms | 40/40 | 0.04457 | 0.03603 | 0.01613 | 0.01288 | −55.24 % (2.54; [−57.32, −55.00]; −62.35) | −64.27 % (3.32; [−67.10, −64.02]; −72.44) | −19.15 % | 2/2/1/1 |
| (0.65, 1.5), 260 ms | 40/40 | 0.04792 | 0.04008 | 0.01878 | 0.01388 | −53.15 % (2.04; [−54.69, −52.91]; −59.27) | −65.36 % (3.95; [−68.90, −65.09]; −73.38) | −16.38 % | 2/2/2/2 |

- Both m_p 0.25 corners: `wind_real_t150_i0251` removed by the one-set rule (all four columns crashed / diverged:
  `UAV_Plant/Int_etadot`, `Attitude_Observer/Int_za`), as at m_p 0.25, L 1.0 in B1 (§41.4) - the controller
  limitation of §42.0. Motor saturation 0 in every corner.
- **Weak / Medium split** (on the one set; printed by `bin_report`):

| corner | Weak (n) L3/L2 − 1 (SE; LOO; by-day) | Weak V/L2 − 1 | Medium (n) L3/L2 − 1 | Medium V/L2 − 1 |
|---|---|---|---|---|
| (0.25, 0.5) | (28) −46.41 % (1.41; [−47.65, −46.23]; −48.81) | −52.59 % (1.41; [−53.77, −52.41]; −55.04) | (11) −35.10 % (3.20; [−37.38, −34.24]; −42.28) | −43.53 % (3.97; [−46.07, −42.58]; −50.31) |
| (0.25, 1.5) | (28) −38.52 % (1.19; [−39.44, −38.27]; −39.96) | −57.00 % (1.87; [−58.49, −56.75]; −60.40) | (11) −26.54 % (2.21; [−28.19, −25.92]; −30.53) | −43.57 % (4.06; [−46.11, −42.48]; −51.60) |
| (0.65, 0.5) | (28) −60.75 % (1.43; [−61.91, −60.56]; −63.35) | −70.17 % (1.99; [−71.96, −69.95]; −73.21) | (12) −46.03 % (4.42; [−49.92, −45.14]; −53.95) | −54.87 % (6.27; [−60.59, −53.68]; −67.42) |
| (0.65, 1.5) | (28) −57.85 % (1.37; [−58.94, −57.64]; −60.27) | −72.27 % (2.39; [−74.48, −72.02]; −76.95) | (12) −45.22 % (3.05; [−47.57, −44.50]; −50.49) | −54.97 % (7.03; [−61.69, −53.77]; −68.47) |

- Recorded (facts, not read): at m_p 0.25 the L3 gain is smaller than at m_p 0.5 / 0.65, and smaller again at L 1.5
  (−34.7 %); V keeps −50 % or more at every corner. In every corner the Weak bin has a larger relative gain than the
  Medium bin.
- **Envelope - an error in the §46.2 registration, found when writing this record.** §46.2 (and `bin_report`) used
  the **static (hover) envelope of §0.10** (U_max 9.99 / 11.35 at m_p 0.25 / 0.65). For the circle the registered
  envelope is **A2 with the trajectory's acceleration** (§4.4, approved §5.1; `python/p2_envelope.py --traj`): circle, K 0.5 →
  **U_max 7.38 (m_p 0.25) / 8.02 (0.5) / 8.39 (0.65)**. The largest U in S40 is **7.59 m/s** (printed), so at
  **m_p 0.25** at least one S40 segment (U in (7.38, 7.59]) lies **outside** the circle envelope and, by the A2 rule,
  should have been reported per segment and left out of the pooled m_p 0.25 rows. It is not `i0251` (U 6.70, §10.2).
  The same holds for B1 m_p 0.25 (§39.3 / §41.4 used the same static bound 9.99). m_p 0.5 and 0.65 are unaffected
  (7.59 < 8.02 < 8.39). Nothing is re-pooled here; the correction is put to the user (§49.4).

### 49.3 Guo's four controllers on circle_main (§46.3, §46.5)
One set **134/134**. Check MOBADC = D2 L0 on all 134 segments: **IDENTICAL** (max |d| 0).

| controller | pooled [m] | Mean ± STD (Guo layout) | vs Classical (SE; LOO; by-day) | pooled xy | pooled z | mean e_z | xy vs Classical (SE; LOO; by-day) |
|---|---|---|---|---|---|---|---|
| Classical | 0.20073 | 0.1947 ± 0.0371 | - | 0.16489 | 0.12500 | **+0.12500** | - |
| ESO | 0.07572 | 0.0744 ± 0.0229 | −62.28 % (0.85; [−62.71, −62.10]; −61.96) | 0.08383 | 0.00081 | −0.00000 | −49.16 % (2.39; [−51.10, −48.79]; −47.96) |
| DO | 0.18389 | 0.1773 ± 0.0228 | −8.39 % (0.34; [−8.59, −8.37]; −8.63) | 0.14656 | 0.11830 | **+0.11830** | −11.12 % (1.22; [−12.03, −11.08]; −12.35) |
| MOBADC | 0.04502 | 0.0412 ± 0.0167 | −77.57 % (1.85; [−78.83, −77.44]; −79.17) | 0.05587 | 0.00050 | +0.00000 | −66.12 % (5.79; [−71.17, −65.82]; −69.78) |

tilt_sat_frac max 0.393 / 0.395 / 0.398 / 0.400; segments > 1 %: 12 / 12 / 13 / 14.
- §46.3 prediction (mean e_z ≈ +0.125 m in Classical and DO): Classical **+0.12500** (as predicted); DO **+0.11830**,
  0.0067 m (5 %) below the prediction - recorded, not diagnosed.
- In Classical the vertical offset is 0.125 of the 0.201 pooled norm; in DO 0.118 of 0.184. The horizontal part
  alone orders the controllers the same way (MOBADC < ESO < DO < Classical).
- Guo's own Table 1 numbers are printed for the layout only (§46.3); nothing is read from the comparison.

### 49.4 Open point for the user (the envelope error of §49.2)
Proposal, descriptive, no new run: re-pool the m_p 0.25 rows (B1 at L 1.0, §41.4; the two m_p 0.25 corners, §49.2)
on the segments inside the circle envelope at m_p 0.25 (U ≤ 7.38 m/s), from the saved per-segment rows, and report
the segment(s) above 7.38 per segment; the rows above stay as recorded, marked "static envelope (§46.2 error)". The
S40 set itself (U ≤ 8.02, m_p 0.5) is unchanged. Decision needed before the paper table is written.

## 50. The fixed scope and the remaining runs (user decisions 2026-09-30) - registered before any build or run
Scope text: `docs/devlog/MASTER_PLAN.md`, block "PHẠM VI BÀI — CHỐT". Code `7f5c8d6`. This section replaces the
night plan of §48.3-48.4; the implementation notes of §48.1 and the build / B1 steps of §48.2 stand.

### 50.0 Decisions recorded
- **Dropped:** IM-est; H4 (the block is **not built**, `dmf_h4` = 0, `p2_setup` refuses `Cmp` 2); held-out /
  unplanned trajectories (Limitation: nothing is claimed for trajectories not planned in advance); Monte Carlo (F4);
  T3a (A6); A7; synthetic wind; (iii) on T3b / square / T5; a separate final combined run.
- **(iii):** night 16 runs **only the registered acceptance variants** (§45.3: nominal, L ±20 %, m_L ±20 %, payload
  C_D·A ±30 %, body C_D·A ±30 %, σ 0.1) and the circle no-harm check (§45.7). The comparison variants of §45.2 ((iii-0),
  (iii-m)) and the accelerometer-bias levels of §45.6 (1) are **not run** (not in the fixed list). C2 of the paper
  stands only if §45.3 is met.
- **INDI** (H3, §40.1, unchanged) is the one competitor kept; its tables are reduced to §50.3.
- **Night 15 (§49):** σ = 0.1 changes the prediction result by < 1.3 points (L3/L2 − 1: −56.20 vs −56.22 %; h_model
  +60.55 vs +61.81 %), so the σ = 0 deviation (§43) does not change a conclusion. The 2² corners: the weakest is
  light payload + long cable → Limitations. Guo on P2: the order of Guo's paper (MOBADC > ESO > DO > Classical); DO
  e_z 0.1183 vs 0.125 recorded only.

### 50.1 The envelope correction of §49.4 (approved) - no run
`run_p2_gd6('REPOOL025', 'Sha', '1db1de02532a3896')` re-pools, from the saved per-segment rows, the three m_p 0.25
tables on S40 - B1 at L 1.0 (§41.4, `tab_circle_mp025_p2.mat`) and the corners (0.25, 0.5), (0.25, 1.5) (§49.2) - on
the segments with **U ≤ 7.38 m/s** (A2 circle envelope, K 0.5, m_p 0.25, §4.4); every segment above is printed per
segment (L0 L2 L3 V). Statistics as §32 / §39.3 (one set, SE, LOO, by-day). The rows of §41.4 / §49.2 stay as
recorded and are marked "static envelope used in error"; the re-pooled rows are the ones the paper uses. Recorded in
`docs/DEVIATIONS.md`.

**Result (run 2026-09-30, git `2a4271d`, no simulation).** Above 7.38 m/s: `wind_expl_t150_i0201` (U 7.59) and
`wind_expl_t150_i0219` (U 7.48) - reported per segment in each table. Inside the envelope: 38 of 40 rows; one set 37
(`wind_real_t150_i0251` removed, as before). S40, circle, m_p 0.25:

| table | L0 | L2 | L3 | V | L3/L2 − 1 (SE; LOO; by-day) | V/L2 − 1 (SE; LOO; by-day) | L2/L0 − 1 | as recorded (L3/L2, V/L2) |
|---|---|---|---|---|---|---|---|---|
| B1, L 1.0 (τ 290 ms) | 0.03662 | 0.02935 | 0.01787 | 0.01450 | −39.09 % (1.64; [−40.03, −38.87]; −43.24) | −50.58 % (1.99; [−51.63, −50.36]; −55.96) | −19.87 % | −38.9 %, −50.7 % (§41.4) |
| corner L 0.5 (330 ms) | 0.03633 | 0.02896 | 0.01657 | 0.01463 | −42.80 % (1.85; [−43.93, −42.59]; −47.62) | −49.49 % (1.91; [−50.60, −49.29]; −54.26) | −20.28 % | −42.72 %, −49.65 % (§49.2) |
| corner L 1.5 (260 ms) | 0.03688 | 0.02966 | 0.01930 | 0.01406 | −34.93 % (1.58; [−35.87, −34.67]; −38.84) | −52.62 % (2.35; [−53.92, −52.32]; −59.23) | −19.57 % | −34.71 %, −52.59 % (§49.2) |

The correction moves every ratio by ≤ 0.3 point; no reading changes. The per-segment values of the two segments
above the envelope are in the log. `pqa_spikes` was re-run in the same session: identical to §36.

### 50.2 Night 16 - `gd8_night16` (≈ 7.7 h), after the rebuild and B1 of §48.2
- 0: the model holds the (iii) and trim blocks; **C1** (verify_repro, check_results_numbers, D2 row 1, N6 recheck on
  its first segment, bit-exact), **C2 + C3** (`check_m3_offline`, fixed-5) → STOP on any failure.
- 1: **N0M3 hover** (TauPred 0; §7.1 procedure) → τ*_m,hover. **Change of order (this section):** τ*_m is read in
  the same night from the saved result (`results/gd6/n0m3_hover_p2.mat`) instead of being transcribed between two
  nights; the rule that chooses it is the registered one and nothing else is read before it is fixed; an
  EDGE-UNRESOLVED result skips steps 2-3. The value is transcribed here after the night.
- 2: `iii-hover` (S40hover): L3 (F-hover, spot-checked) + `L3_iii`, `L3_iii_L080/L120/m080/m120/cP070/cP130/cB070/cB130`.
- 3: `iii-hover-sn` (S40hover, `wind_sn010/`): L3 (SN-hover, spot-checked) + `L3_iii` → the §45.3 acceptance line.
- 4: **N0M3 circle** (TauPred 290 ms) → τ*_m,circle (same rule as step 1); 5: `iii-circle` (S40) → §45.7 reading.
- 6: `GUOTRIM` (§47) on circle_main (the night-15 rows of `guo_p2.mat` are reused for the untrimmed controllers).
- Hours: checks 0.4; N0M3 hover 0.9; iii-hover 43 × 9 × 25 s ≈ 2.7; iii-hover-sn 0.3; N0M3 circle 1.2; iii-circle
  0.4; GUOTRIM 134 × 2 × 25 s ≈ 1.8 → **≈ 7.7 h**.

### 50.3 Night 17 - INDI (`gd8_night17`, ≈ 3.8-4.7 h), after night 16, before CONFIRM2
- 0: verify_repro, D2 row 1, the H3 block present → STOP on failure.
- 1: **N0H3** (§40.1): ω_f ∈ {1, 2, 4, 8, 16} Hz on the A4 fixed-5, circle, K 0.5; argmin of the pooled error; a
  grid-edge minimum → one extension (0.5 / 32 Hz); **frozen**. Read in the same night from the saved result (the rule
  of §50.2 step 1); EDGE-UNRESOLVED → nothing else run.
- 2: **`H3-circle`** (circle_main, SHA `a227e9d87a2ac436`, 134 segments): columns **L1** (Guo + DC + payload
  prediction at 290 ms, no wind sensor, run), **L3** (D2, spot-checked), **H3** (run). Two levels:
  **no wind sensor: H3/L1 − 1**; **measured wind: H3/L3 − 1** (H3 already sees the wind through the acceleration, as
  §40.3). One set over the three columns; SE (day jackknife), LOO, by-day; tilt_sat.
- 3: **hover, N6_hover** (SHA `43226c02f0814606…`, 139 segments): **L3** (N6, spot-checked), **H3**, and **L3_iii**
  (τ*_m,hover of night 16) **only if (iii) was ACCEPTED** at night 16 (both iii-hover and iii-hover-sn, read from
  their saved rows); H3/L3 − 1 (and L3_iii/L3 − 1); one set and the unsaturated subset (tilt_sat_frac < 1 % in every
  column).
- Descriptive, not a gate. Hours: N0H3 25 × 34 s ≈ 0.25; H3-circle 134 × 2 × 34 s ≈ 2.5; hover 139 × 1-2 × 25 s ≈
  1.0-1.9 → **≈ 3.8-4.7 h**.
- Paper name fixed: "ước lượng nhiễu dựa trên gia tốc kiểu INDI (vòng ngoài Smeur 2018)" / "acceleration-based
  disturbance estimation of the INDI type (outer loop of Smeur 2018)". Limitation: the P2 accelerometer is idealised
  (no gravity leakage from attitude error), favourable to INDI.

### 50.4 Nights 18-19 - CONFIRM2, once
D2, **H-model(iii)** (registered BEFORE CONFIRM2 is opened, only if (iii) is accepted on dev), H-hover; the full set of
indices. Registered separately before the opening (GĐ10); the 16 CONFIRM2 days stay closed until then.

### 50.5 Implementation note (build, 2026-09-30; before any H3 run)
The first build that included H3 failed its compile check with an **algebraic loop** (state "H3 ON"): position law →
thrust command → `P2_H3` (MATLAB Function, direct feedthrough on every input, it reads `f_cmd`) → `dmf_h3` →
position law. The H3 estimate itself depends only on the filter state (`d̂ = C_f x`, §40.1), so it is now read by a
separate block `P2_H3_out` (`simulink_blocks/p2_h3_out.m`) that takes only the Unit Delay `H3_s` and the parameters;
`P2_H3`'s own output is terminated. The values are identical (checked offline on 200 random states, |d| = 0); the
definition of H3 in §40.1 is unchanged. Also built: H4 is not (§50.0).
Rebuild at `00d0716` (R2022b): compile check clean in every state (v1, P2, GĐ3 off, N6, H3, (iii), (iii-m), trim,
back to v1); P2 wiring fingerprint `c965867910b8eaf907b6adcbcc617b41252212fad6a9413027ee377e281849bd`; MD5
`B27EA7C8FB6544E0CE68E8B765BAAAD3`; `extract_eml` 29/0/0. B1 on this file and its commit: pending (`docs/SNAPSHOT.md`).

## 51. Results of night 16 (`gd8_night16`, git `54a72f6`, model `B27EA7C8…`) - N0M3 hover/circle, GUOTRIM - facts
Run 2026-09-30 from 11:07; a power cut during GUOTRIM (25/134 rows saved); GUOTRIM resumed at git `12f6f74` (docs
only since `54a72f6`) from row 26 by `run_p2_gd6('GUOTRIM', 'Sha', 'a227e9d87a2ac436')` - rows are saved one by one,
nothing re-run. Step 0 (checks, §50.2) passed before step 1.

### 51.1 N0M3 hover (TauPred 0, fixed-5, L 1.0; column O = g_psens + (iii)) - **EDGE-UNRESOLVED**
Per-segment O (m) on the §7.1 coarse grid (the rule pools only segments finite at **every** grid value):

| τ_m (ms) | i0000 | i0251 | i0453 | i0705 | i0900 |
|---|---|---|---|---|---|
| 0 | 0.0019 | 0.1747 | 0.0025 | 0.0029 | 0.0010 |
| 100 | 0.0017 | 0.1742 | 0.0023 | 0.0025 | 0.0009 |
| 200 | 0.0018 | 0.1737 | 0.0024 | 0.0025 | 0.0010 |
| 220 | 0.0019 | crash | 0.0024 | 0.0026 | 0.0010 |
| 280 | crash | crash | 0.0029 | crash | 0.0012 |
| 300-400 | crash | crash | crash | crash | crash |

- Every segment diverges at τ_m ≥ 300 ms (i0251 from 220 ms) → no segment is finite on the whole grid → τ*_m = NaN,
  EDGE-UNRESOLVED; step 2 (`iii-hover`) and step 3 (`iii-hover-sn`) were **not run**, as registered.
- Over 0-200 ms the curve is flat: per segment ≤ 0.0004 m between its extremes (i0251: 0.1747 → 0.1737).
- **Reading:** the §7.1 grid was designed for the wind-delay search (τ_w), where a large τ only mis-times a
  feed-forward. For (iii), τ_m is a prediction horizon inside the loop, and horizons ≥ 220-300 ms destabilise it.
  This is a registration design error (mine), not a code fault. No choice of τ_m made.

### 51.2 N0M3 circle (TauPred 290 ms, fixed-5, DoHarm [0 1]) - **EDGE-UNRESOLVED**
- O decreases with τ_m up to the stability edge (i0000: 0.0341 at 0, 0.0230 at 100, 0.0133 at 200, 0.0106 at 240 ms;
  the other three finite segments alike; i0251 0.229 → 0.217). i0251 diverges at 240 ms; all five diverge at
  260 ms and above → τ*_m = NaN; step 5 (`iii-circle`, §45.7 no-harm) **not run**.
- The minimum lies at the stability edge: a τ_m chosen by this curve would sit next to divergence.

### 51.3 GUOTRIM (§47) - circle_main (SHA `a227e9d8…`, 134 segments, 42 days), descriptive
134 of 134 segments valid in all six columns (four rows reused from night 15, §49.3).

| controller | pooled | xy | z | mean e_z |
|---|---|---|---|---|
| Classical | 0.20073 | 0.16489 | 0.12500 | +0.12500 |
| ESO | 0.07572 | 0.08383 | 0.00081 | −0.00000 |
| DO | 0.18389 | 0.14656 | 0.11830 | +0.11830 |
| MOBADC | 0.04502 | 0.05587 | 0.00050 | +0.00000 |
| Classical+trim | 0.15313 | 0.16489 | 0.00080 | −0.00002 |
| DO+trim | 0.13921 | 0.14656 | 0.00674 | −0.00672 |

| ratio (pooled − 1) | value | SE | LOO | by-day median |
|---|---|---|---|---|
| Classical+trim vs Classical | −23.71 % | 1.69 | [−24.40, −23.63] | −24.93 |
| DO+trim vs DO | −24.30 % | 1.93 | [−25.13, −24.19] | −25.85 |
| Classical+trim vs MOBADC | +240.10 % | 26.29 | [+237.01, +257.17] | +237.46 |
| DO+trim vs MOBADC | +209.20 % | 22.67 | [+206.16, +223.37] | +208.86 |

- The trim removes the vertical offset (Classical mean e_z +0.125 → −0.00002 m); the horizontal error is unchanged
  to every printed digit (xy 0.16489, 0.14656), as expected from a purely vertical feed-forward.
- DO+trim keeps a vertical offset of −6.7 mm (mean e_z −0.00672, every segment −0.0067): the DO's z estimate
  settles 6.7 mm below the trimmed equilibrium. Not diagnosed.
- **Reading:** the known-weight trim explains the vertical part of Guo's Classical/DO gap only; with it, MOBADC
  still has 3.1-3.4 × smaller pooled error, all of it horizontal (xy 0.056 vs 0.147-0.165 m).

## 52. (iii) re-run at τ_m = 0 (user decision 2026-09-30, after §51) - DEVIATION D19 - registered before any run
Night 16's N0M3 left τ*_m EDGE-UNRESOLVED on hover and circle (§51.1-51.2). User decision (option A):
- **τ_m = 0, fixed, for hover and circle; no search.** Reason: on hover the fixed-5 curve is flat over 0-200 ms
  (≤ 0.0004 m per segment), so τ_m = 0 costs nothing there and no parameter is chosen from data; on the circle every
  segment diverges from ~260 ms (i0251 from 240 ms). This is **deviation D19** (`docs/DEVIATIONS.md`): written after
  the N0M3 results were seen; the registered procedure (§45.1 / §7.1 on the coarse grid) gave no value.
- With τ_m = 0 the model's prediction equals its present force: $\hat d_M(t+\tau_m) = \hat d_M(t)$ (p2_m3_prm: Phi_t = I,
  Gam_t = 0). Everything else of §45.1 is unchanged (open-loop model, DO on the residual, commanded acceleration).
- **Runs** (nothing else): `iii-hover` (S40hover, SHA `53facf03…3116`): L3 (reused from F-hover) + L3_iii + the 8
  variants of §45.3 (L ±20 %, m_L ±20 %, payload C_D·A ±30 %, body C_D·A ±30 %) **+ the comparison column (iii-0)**
  (`L3_iii0`, §48: body feed-forward × (1 + K), no model; user request); `iii-hover-sn` (σ 0.1, `wind_sn010/`);
  `iii-circle` (S40, SHA `1db1de02…`, no-harm §45.7).
- **Readings unchanged:** acceptance §45.3 (all 9 variants and the σ variant HOLD: h_model > 0 and every LOO > 0, one
  set of S40hover); no-harm §45.7 (Δ = L3_iii/L3 − 1 > 0 and every LOO > 0 → WORSE ON THE CIRCLE). The one set of the
  acceptance is defined over L3 and the 9 acceptance columns only; (iii-0) is printed on the segments of that set
  where it is finite (h_model, no reading) - so the comparison column cannot change the acceptance set.
- **Circle no-harm is still run at τ_m = 0 and reported as it comes.** Expected (not a gate): WORSE than L3 (fixed-5
  i0000 at τ_m = 0: O 0.0341 vs D2 L3 0.0140) - reported as the reason (iii) is used only in station keeping.
- **Positioning of C2 (user decision):** (iii) is the compensator of the **station-keeping / payload-lowering mode**:
  switched on when the reference velocity is zero (the reference is known in advance; no data-driven switching, no
  tuning); along a planned path the controller uses the DO + payload predictor (C1). No switching logic is built or
  run: every hover run has a zero reference velocity, every circle run a non-zero one.
- **Hypothesis, not diagnosed (user: no further diagnosis):** the commanded acceleration that drives (iii) already
  contains (iii)'s own compensation, so (iii) sits in a feedback loop through a_c; a long prediction horizon raises the
  gain of that loop, and the loop diverges (hover ≥ 300 ms, circle ≥ 260 ms).
- **DO+trim z offset −6.7 mm (§51.3):** noted only; not diagnosed.
- **Night 17 (INDI)** waits for the acceptance of this section; `gd8_night17` uses τ_m = 0 for `H3-hover-iii`.
- **Hours:** checks ≈ 0.4 h; iii-hover 43 × 10 runs ≈ 3.0 h (L3 reused; L3_iii + 8 variants + (iii-0)); iii-hover-sn
  0.3 h; iii-circle 0.3 h - **≈ 4.0 h**. Driver `gd8_night16b`. (Hour count corrected in the code commit; not a gate.)
- **Implementation note (dry run, before any run of this section):** in the iii-hover dry run (i0000) the 8 variant
  columns equalled L3_iii in every digit. `diag_m3_variants` (direct `pa_configs` calls, 60 s) showed the chain works
  when the scale is passed (max |d F_cmd| vs L3_iii: m080 1.009 N, L080 0.079 N, cB070 0.130 N); the fault was the
  column parser of `run_p2_gd7` (`col_spec`): its (iii) regular expression used an optional group and an
  empty-matching group, whose tokens MATLAB returns differently from Octave, so every variant was parsed with the
  nominal scale and copied from L3_iii. Rewritten without such groups (checked in Octave on all 16 column names);
  a variant column parsed at the nominal scale now stops the run. No result of any earlier night used this parser
  (the (iii) columns had never run).

## 53. Results of night 16b (`gd8_night16b`, git `feba8a1`, 4.1 h) - (iii) at τ_m = 0 (§52, D19) - facts
Step 0 passed: verify_repro 32 cells, largest difference 0; check_results_numbers 146/146; D2 row 1 unchanged; C2 PASS
(e1 ≤ 10 % on the 3 fixed-5 hover cases with θ RMS ≤ 10°: 2.5 / 2.4 / 0.6 %); C3 PASS (offset < 1e-9 N in all 7
variants). Reuse spot checks: F-hover L3 |d| 0, SN-hover L3 |d| 0, D2 L3 |d| 5.1e-8.

### 53.1 iii-hover (S40hover, SHA `53facf03…3116`) - one set 43 of 43 (43 days); unsaturated subset 40
One set (read), L3 pooled 0.01049; h_model = 1 − col/L3:

| column | pooled | h_model | SE | LOO | by-day median | reading |
|---|---|---|---|---|---|---|
| L3_iii | 0.02714 | −158.83 % | 200.46 | [−172.83, +42.72] | +68.53 % | FAILS |
| L3_iii_L080 | 0.02697 | −157.18 % | 198.50 | [−171.09, +42.39] | +66.11 % | FAILS |
| L3_iii_L120 | 0.02897 | −176.31 % | 156.91 | [−191.12, −19.94] | −2.15 % | FAILS |
| L3_iii_m080 | 0.02016 | −92.26 % | 145.03 | [−102.49, +53.50] | +68.79 % | FAILS |
| L3_iii_m120 | 0.03476 | −231.51 % | 257.89 | [−249.55, +27.80] | +67.67 % | FAILS |
| L3_iii_cP070 | 0.02598 | −147.80 % | 189.93 | [−161.12, +43.13] | +63.64 % | FAILS |
| L3_iii_cP130 | 0.02844 | −171.20 % | 203.83 | [−185.76, +33.64] | +58.88 % | FAILS |
| L3_iii_cB070 | 0.02547 | −142.91 % | 174.25 | [−155.65, +32.07] | +47.41 % | FAILS |
| L3_iii_cB130 | 0.02953 | −181.59 % | 204.40 | [−196.55, +23.72] | +48.46 % | FAILS |
| L3_iii0 (comparison) | 0.00344 | +67.18 % | 2.85 | [+64.70, +68.18] | +62.03 % | no reading |

- Most influential segment in every (iii) column: `wind_real_t150_i0251` (L3 0.0344, L3_iii 0.1747; the same
  0.1747 as N0M3 at τ_m = 0, §51.1). `wind_expl_t150_i0321` is the only other segment where L3_iii > L3
  (0.0304 vs 0.0229).
- Unsaturated subset (printed, not read), L3 pooled 0.00797: L3_iii +72.72 % (SE 1.78, LOO [+71.41, +73.55]); 8 of
  9 variants hold there. L3_iii_L120 fails there as well (−23.82 %, LOO [−33.34, −8.79]). L3_iii0 +66.26 %.

### 53.2 iii-hover-sn (σ 0.1, `wind_sn010/`) - one set 43 of 43
L3 pooled 0.01050; L3_iii 0.02714, h_model −158.49 % (SE 199.57, LOO [−172.65, +42.16], by-day +65.78 %) → **FAILS**.
Unsaturated subset (not read): +71.17 %.

### 53.3 Acceptance §45.3 → **(iii) NOT ACCEPTED**
0 of 9 variants and the σ variant hold on the one set. Under §42.0 / §45.3 / §50.0, (iii) is **not reported as a
contribution** and **C2 does not stand** as registered. §45.7 allows (iii-obs) to be registered separately; nothing is
registered here (user decision pending). H-model(iii) is not registered for CONFIRM2.

### 53.4 iii-circle (S40, SHA `1db1de02…`) - no-harm §45.7 - one set 40 of 40; unsaturated 37
L3 pooled 0.01530, L3_iii pooled 0.04931; Δ = L3_iii/L3 − 1 = **+222.33 %** (SE 79.80, LOO [+143.35, +232.01], by-day
+188.83 %) → **WORSE ON THE CIRCLE** (as expected, §52). L3_iii is 0.033-0.035 m on every segment except i0251
(0.2288), whatever the wind (L3 0.0098-0.0254): a trajectory-driven error of (iii) at τ_m = 0 on the circle. Not
diagnosed. tilt_sat_frac > 1 %: 3 segments in each column.

### 53.5 Notes (facts, no reading)
- (iii-0), the static (1 + K) body feed-forward without the pendulum model, is the only hover column better than L3
  on the one set with every LOO value > 0. It is a **comparison column** (§52); any claim from it would be post hoc and
  needs a separate registration (user decision).
- Night 17 (INDI) runs as registered: `gd8_night17` reads NOT ACCEPTED and runs `H3-hover` (L3, H3; no L3_iii).

## 54. C2 replaced: the static (1 + K) feed-forward (iii-0) - DEVIATION D20 (post hoc) - night 18 registered before any run
User decisions 2026-09-30, after §53.

### 54.1 (iii) - reported as a NEGATIVE result
(iii) is dropped as a contribution; (iii-obs) is **not** done. The paper reports §53 as it stands: NOT ACCEPTED under
§45.3; good on the unsaturated subset (h_model +72.72 %, not read) but badly wrong near the envelope limit (i0251:
L3_iii 0.1747 vs L3 0.0344) → **not safe**; on the circle +222.33 % (§53.4). The near-constant L3_iii ≈ 0.034 m on
the circle is noted only, not diagnosed. H-model (§28.1) and H-model(iii) are **removed from CONFIRM2**.

### 54.2 New C2 = (iii-0), the static (1 + K) body feed-forward - D20
- **Definition** (unchanged from §48 / §52): column `L3_iii0` = L3 with the body wind feed-forward scaled by
  (1 + K̂), K̂ = 0.5 the nominal K: `PredScale` [1 1 1 1.5] (`p2_prm_w` = [1.5 K_w; U_ref]); no pendulum model, no
  (iii) block. Everything else as L3.
- **D20 (post hoc):** found in a comparison column of night 16b (§53.1: +67.18 %, SE 2.85, LOO [+64.70, +68.18] on
  S40hover). It was not a registered claim; it becomes C2 only through the steps below and CONFIRM2.

### 54.3 Night 18 - robustness of (iii-0) (after night 17, before CONFIRM2) - registered before any run
| group | set | columns | reused | run |
|---|---|---|---|---|
| `static-hover` | N6_hover (SHA `43226c02…c7`, 139 segments / 43 days) | L3, H3, L3_iii0 | L3 (N6), H3 (night 17 `H3-hover`, same ω_f*), each spot-checked | L3_iii0 |
| `static-hover-k` | S40hover (SHA `53facf03…3116`) | L3, L3_iii0, L3_iii0_s070, L3_iii0_s130 | L3 (F-hover), L3_iii0 (iii-hover, §53) | ±30 % |
| `static-circle` | S40 (SHA `1db1de02…`) | L3, L3_iii0 | L3 (D2) | L3_iii0 |

- **±30 % on the coefficient:** L3_iii0_s070 / _s130 = the (1 + K̂) factor × 0.7 / × 1.3, i.e. `PredScale` body
  1.5 × 0.7 = **1.05** and 1.5 × 1.3 = **1.95** (a wrong K̂: 0.05 / 0.95).
- **Readings (descriptive; written before the run):**
  - h_static = 1 − L3_iii0*/L3 on the one set (valid in every column of the group); HOLDS iff h_static > 0 AND every
    LOO value > 0. Unsaturated subset (tilt_sat_frac < 1 % in every column) printed, not read.
  - **Eligible for H-static** iff it HOLDS for the nominal on N6_hover (`static-hover`) AND for the nominal and both
    ±30 % columns on S40hover (`static-hover-k`).
  - `static-hover` also prints H3 vs L3 and L3_iii0 vs H3 (ratio − 1, SE, LOO, by-day median) - the hover table L3 /
    INDI / (iii-0), descriptive.
  - `static-circle`: Δ = L3_iii0/L3 − 1; Δ > 0 AND every LOO > 0 → WORSE ON THE CIRCLE → (iii-0) is stated for
    station keeping only; otherwise NOT WORSE.
- **Hours:** checks ≈ 0.4 h; static-hover 139 runs ≈ 1.0 h (+ spot checks); static-hover-k 86 runs ≈ 0.6 h;
  static-circle 40 runs ≈ 0.3 h - **≈ 2.4 h**. Driver `gd8_night18`.

### 54.4 CONFIRM2 (nights 19-20) - what changes
- **H-model removed** (the old C2 did not pass).
- **H-static:** registered **after night 18 and before CONFIRM2 is opened**, only if eligible (§54.3). Criterion given
  by the user now: hover, the CONFIRM2 set built by the N6_hover rule; by-day median h_static ≥ 10 % AND
  h_static − 1.65·SE > 0. Registered in its own section with the set's SHA before any CONFIRM2 file is opened.
- D2 and H-hover unchanged (§28, §50.4).

## 55. Night 17 (`gd8_night17`, git `20a65b5`) - N0H3 EDGE-UNRESOLVED, stopped after step 1 - facts
Step 0 passed (verify_repro 32 cells 0.000e+00; D2 row 1 unchanged). N0H3 circle (fixed-5, DoHarm [0 1], g_psens +
H3), pooled over 5/5 segments:

| ω_f (Hz) | 1 | 2 | 4 | 8 | 16 | 32 (extension) |
|---|---|---|---|---|---|---|
| pooled O (m) | 0.0624 | 0.0485 | 0.0420 | 0.0389 | 0.0374 | 0.0367 |

- The error decreases monotonically. The minimum sat at the grid edge (16 Hz); the one registered extension (32 Hz)
  moved it to the new edge → **EDGE-UNRESOLVED**. Per §40.1 / §50.3 no ω_f* is frozen; `gd8_night17` stopped before
  H3-circle and H3-hover, as registered. Every segment lies within ±0.0005 m of the pooled value at each ω_f.
- 16 → 32 Hz lowers the pooled error by 1.9 %; 8 → 16 Hz by 3.9 %.
- For reference only (not a reading): on i0000 the H3 values (0.0371 at 32 Hz) are above D2's L2 (0.0334) and L3
  (0.0140) and below L0 (0.0414) for that segment.
- No decision made; user decision pending (a deviation in every case, the rule has given no value).

## 56. ω_f of H3 fixed at 32 Hz (user decision 2026-09-30, after §55) - DEVIATION D21 - registered before the H3 tables
- **ω_f* = 32 Hz, fixed** for H3-circle and H3-hover (and for the reused H3 column of night 18, §54.3). Reason:
  N0H3 stayed EDGE-UNRESOLVED after the registered extension (§55); 32 Hz is the best value tried, i.e. the choice
  **most generous to the competitor**. Written after the N0H3 numbers were seen → **deviation D21**.
- **Sampling (checked in the build):** the H3 estimate is computed at **1 kHz** (inputs through the ZOHs `H3_z_*` at
  `p2_Ts_att`, state in the Unit Delay `H3_s`; `build/build_p2_plant.m:639-651`), but the force command of the position
  law is held at **125 Hz** (`H_Fcmd`, ZOH at `p2_Ts_pos`, `build/build_p2_plant.m:578`; `core/p2_params.m:26`). The
  estimate therefore reaches the plant through a 125 Hz sample-and-hold: content above the Nyquist frequency of that
  hold (62.5 Hz) cannot be used by the loop and aliases into the command. A filter cut-off above ~60 Hz would not widen
  the usable bandwidth, which bounds the grid; 32 Hz is about half of that Nyquist frequency.
- **Limitation (paper):** the N0H3 curve still falls by ~2 % per doubling of ω_f at 32 Hz. This is attributed (not
  diagnosed) to the idealised accelerometer (INDI_FIDELITY I3) and the thrust model that matches the plant's motor lag
  exactly (I8), which make the filter cost almost nothing in noise; both favour INDI (LIMITATIONS G3, G14).
- The saved grid result (`results/gd6/n0h3_circle_p2.mat`, edge_ok = false) is kept unchanged; `gd8_night17` takes
  ω_f as an explicit argument and skips step 1.
- Tables and readings unchanged (§50.3): H3-circle (circle_main; L1, L3 from D2, H3) and H3-hover (N6_hover; L3 from
  N6, H3; no L3_iii, §53.3), descriptive.

## 57. Results of night 17 (`gd8_night17('H3Hz', 32)`, git `b62456b`, 3.2 h) - INDI (H3) tables at ω_f = 32 Hz - facts, descriptive
Step 0 passed (verify_repro 32 cells 0.000e+00; D2 row 1 unchanged). Dry run beforehand: H3 on i0000 0.0371, equal to
the 32 Hz point of N0H3. Reuse spot checks: D2 L3 |d| 5.1e-8, N6 L3 |d| 0.

### 57.1 H3-circle (circle_main, SHA `a227e9d8…`, 134 segments / 42 days) - one set 134 of 134; unsaturated 121
| column | pooled | tilt_sat > 1 % |
|---|---|---|
| L1 (no wind sensor) | 0.03216 | 12 |
| L3 (D2) | 0.01802 | 13 |
| H3 | 0.03837 | 13 |

- No wind sensor: H3/L1 − 1 = **+19.31 %** (SE 13.43, LOO [+18.98, +26.44], by-day median +51.16 %).
- Measured wind: H3/L3 − 1 = **+112.93 %** (SE 47.94, LOO [+112.40, +151.64], by-day median +196.47 %).
- Most influential in both: `wind_expl_t150_i0306` (L1 0.1596, L3 0.1223, H3 0.1282).
- H3 lies between 0.0360 and 0.0389 m on every segment except i0306, whatever the wind (L1 0.0145-0.0680): a
  trajectory-driven error of H3 on the circle, as for L3_iii (§53.4). Noted only, not diagnosed.

### 57.2 H3-hover (N6_hover, SHA `43226c02…c7`, 139 segments / 43 days) - one set 138 of 139; unsaturated 124
Removed: `wind_real_t150_i0264` (diverged in L3 and H3).

| set | L3 pooled | H3 pooled | H3/L3 − 1 | SE | LOO | by-day median |
|---|---|---|---|---|---|---|
| one set (n 138) | 0.02458 | 0.01906 | **−22.48 %** | 52.29 | [−75.91, −21.87] | −77.70 % |
| unsaturated (n 124, 41 days) | 0.00892 | 0.00186 | −79.13 % | 0.94 | [−79.28, −78.40] | −77.59 % |

- Most influential on the one set: `wind_expl_t150_i0215` (L3 0.2534, H3 0.2213); tilt_sat > 1 %: 14 segments in each
  column.

### 57.3 Notes (facts, no reading)
- On the circle, L3 (C1) has less than half the error of INDI; on hover, INDI has about a fifth of L3's error on the
  unsaturated subset (both descriptive; INDI's sensor model is idealised, G3, G14).
- Night 18 (§54.3) prints L3_iii0/H3 − 1 on N6_hover. For orientation only (different sets, not a comparison):
  (iii-0) on S40hover was 1 − L3_iii0/L3 = +67.18 % (§53.1); H3 on N6_hover unsaturated is 1 − H3/L3 = +79.13 %.

## 58. Night 18 amended (user decision 2026-10-01, after §57) - registered before any night-18 run
Amends §54.3. Nothing of night 18 has run.

### 58.1 (1 + K̂) ±30 %: both forms, one read
- **Read (main):** K̂ ±30 %, i.e. K̂ = 0.35 / 0.65 → factor **1.35 / 1.65** (columns `L3_iii0_k070`, `L3_iii0_k130`).
  Reason: the uncertainty sits in the payload drag, which is what K carries; consistent with the ±30 % C_D·A of F3.
- **Stress (printed, not read):** the whole factor ×0.7 / ×1.3 → **1.05 / 1.95** (`L3_iii0_s070`, `L3_iii0_s130`).
- Eligibility for H-static (§54.3) now reads: h_static HOLDS for the nominal on N6_hover AND for the nominal and
  `_k070`, `_k130` on S40hover. The `_s` columns do not enter it.

### 58.2 INDI with an accelerometer bias (S40hover) - descriptive
- Group `static-indi-bias` on S40hover (SHA `53facf03…3116`): columns L3 (F-hover), L3_iii0 (iii-hover), H3 (night 17
  H3-hover at 32 Hz, shared segments reused, the rest run), **H3_b086**, **H3_b170**.
- Bias b ∈ {0.086, 0.17} m/s² (gravity leakage of a 0.5° and 1° attitude error), **horizontal only**, direction random
  per segment (`core/p2_acc_bias_vec.m`, seed 7000000 + 100·seg + 31, the same direction at both levels), added to the
  accelerometer that H3 reads (`S_acc_bias`, `build/build_p2_plant.m:567`); ω_f 32 Hz. Only the H3_b columns carry it.
- **Reading (descriptive, no gate):** H3_b/L3_iii0 − 1 on the one set (SE, LOO, by-day); also H3_b/L3 − 1 and the
  nominal H3/L3_iii0 − 1.
- **Analytical prediction, written before the run:** a constant bias b enters the estimate as m·b, so the law applies a
  constant force error m·b; the position loop settles where m·K_γ·e = m·b, i.e. a horizontal offset
  **e ≈ b / K_γ,xy = 0.086 / 12 ≈ 7.2 mm and 0.17 / 12 ≈ 14.2 mm** (K_γ = diag(12, 12, 35)). For comparison, L3_iii0 on
  S40hover pools at 3.44 mm (§53.1).

### 58.3 static-hover and static-circle
Unchanged; static-hover prints L3_iii0/H3 − 1 on the same set (§54.3).

### 58.4 Hours
checks 0.4 h; static-hover-k 43 × 4 runs ≈ 1.2 h; static-indi-bias 43 × 2 runs (+ H3 where not shared) ≈ 0.6 h;
static-hover ≈ 1.0 h; static-circle ≈ 0.3 h → **≈ 3.5 h**.

## 59. Results of night 18 (`gd8_night18`, git `5e05c53`, 3.4 h) - (iii-0) robustness, INDI with bias (§54.3, §58) - facts
Step 0 passed (verify_repro 32 cells 0.000e+00; D2 row 1 unchanged; H3-hover at 32 Hz, 139 segments). Reuse spot checks
all |d| = 0 (F-hover L3, iii-hover L3_iii0, H3-hover H3, N6 L3) and D2 L3 |d| 5.1e-8.

### 59.1 static-hover-k (S40hover) - one set 42 of 43; unsaturated 39
Removed: `wind_expl_t150_i0290` - **L3_iii0_s130 phys_div** (a stress column; the one set is over every column, §54.3).

| column | pooled | h_static | SE | LOO | by-day | reading |
|---|---|---|---|---|---|---|
| L3 | 0.01060 | | | | | |
| L3_iii0 | 0.00344 | +67.51 % | 2.80 | [+65.11, +68.58] | +62.09 % | HOLDS |
| L3_iii0_k070 (1.35) | 0.00468 | +55.81 % | 2.03 | [+54.10, +56.69] | +51.91 % | HOLDS |
| L3_iii0_k130 (1.65) | 0.00434 | +59.00 % | 2.17 | [+57.00, +59.52] | +55.05 % | HOLDS |
| L3_iii0_s070 (1.05, stress) | 0.00968 | +8.64 % | 0.22 | [+8.46, +8.74] | +8.24 % | not read |
| L3_iii0_s130 (1.95, stress) | 0.00919 | +13.25 % | 0.70 | [+12.87, +13.47] | +12.42 % | not read |

Unsaturated subset (not read): nominal +66.87 %, k070 +55.63 %, k130 +57.60 %.

### 59.2 static-indi-bias (S40hover) - one set 43 of 43; unsaturated 40 - descriptive
Pooled: L3 0.01049, L3_iii0 0.00344, H3 0.00211, **H3_b086 0.00746, H3_b170 0.01433**.

| ratio | value | SE | LOO | by-day |
|---|---|---|---|---|
| H3_b086/L3_iii0 − 1 | +116.72 % | 27.28 | [+114.33, +133.21] | +323.57 % |
| H3_b170/L3_iii0 − 1 | +316.31 % | 55.39 | [+311.51, +349.72] | +724.27 % |
| H3_b086/L3 − 1 | −28.87 % | 11.48 | [−29.65, −19.21] | +40.77 % |
| H3_b170/L3 − 1 | +36.64 % | 22.90 | [+35.06, +55.70] | +174.23 % |
| H3/L3 − 1 (no bias) | −79.87 % | 1.86 | [−80.65, −78.28] | −76.46 % |
| L3_iii0/H3 − 1 (no bias) | +63.06 % | 2.08 | [+62.42, +64.43] | +63.38 % |

- **Prediction (§58.2) vs result:** on calm segments, where unbiased H3 is ≤ 0.0004 m, H3_b086 = 0.0071-0.0073 m and
  H3_b170 = 0.0141-0.0143 m, against the predicted offsets b/K_γ = 7.2 and 14.2 mm. The prediction holds.

### 59.3 static-hover (N6_hover) - one set 137 of 139; unsaturated 124
Removed: `wind_real_t150_i0264` (diverged in all three columns) and `wind_expl_t150_i0326` - **L3_iii0 crash** (solver
stopped at 192.7 s; L3 0.0208, H3 0.0046 on that segment).

| | L3 | H3 | L3_iii0 |
|---|---|---|---|
| pooled, one set (n 137) | 0.02461 | 0.01912 | 0.01962 |
| pooled, unsaturated (n 124) | 0.00892 | 0.00186 | 0.00306 |

- h_static (L3_iii0) = **+20.27 %** (SE 42.39, LOO [+19.75, +63.56], by-day +62.92 %) → **HOLDS**. Most influential:
  `wind_expl_t150_i0215` (L3 0.2534, H3 0.2213, L3_iii0 0.2242).
- H3/L3 − 1 = −22.30 % (SE 52.42, LOO [−75.87, −21.67]); L3_iii0/H3 − 1 = +2.61 % (SE 46.93, LOO [+2.43, +50.99],
  by-day +64.90 %).
- Unsaturated (not read): h_static +65.68 %; H3/L3 − 1 −79.13 %; L3_iii0/H3 − 1 +64.48 % (LOO [+64.09, +64.94]).

### 59.4 H-static eligibility (§54.3 / §58.1) → **ELIGIBLE**
static-hover L3_iii0 HOLDS; static-hover-k L3_iii0, _k070, _k130 HOLD.

### 59.5 static-circle (S40) - one set 39 of 40; unsaturated 36
Removed: `wind_expl_t150_i0290` - **L3_iii0 crash** (solver stopped at 81.8 s; L3 0.0113).
L3 0.01539, L3_iii0 0.00867; Δ = L3_iii0/L3 − 1 = **−43.67 %** (SE 2.16, LOO [−43.92, −42.33], by-day −34.59 %) →
**NOT WORSE** (lower on the circle). Unsaturated: −40.12 %.

### 59.6 Notes (facts, no reading)
- (iii-0) stopped the solver on two segments on which L3 ran: N6_hover i0326 and the circle i0290; its stress
  variant ×1.3 was flagged phys_div on S40hover i0290. Under the registered one-set rule these segments leave the
  set rather than count against the column.
- On the circle, (iii-0) lowered the error by 43.67 % (post hoc relative to the registered expectation "WORSE").

## 60. CONFIRM2 (GĐ10) - registration DRAFT (2026-10-03), amended 2026-10-03 after the user's review (§60 NOT APPROVED, five points: 60.3, 60.6-60.9); awaiting the user's approval; CONFIRM2 stays closed
Nothing of CONFIRM2 has been opened, downloaded or simulated. This section becomes binding when the user approves it
(an "APPROVED" line with the date is added in its own commit, together with the commit hash of the runner); after
that it changes only by a dated amendment committed **before** CONFIRM2 is opened. CONFIRM2 is opened only under the
condition of 60.9.

### 60.0 Lookup for the safety condition (user decision; a lookup, not a diagnosis round)
The two segments on which (iii-0) stopped the solver while L3 ran (§59.6) are both **spiked segments** of P-QA:
`wind_expl_t150_i0290` is one of the six §35 segments (raw file 04_27_2024 20:00, h 61 m, 23 spikes / 24 jumps,
§38 table); `wind_expl_t150_i0326` is in the §38 spiked list (T3b and N6 sets). Consequence (user): Limitation +
recommendation "the static feed-forward multiplies the measured wind by 1.5, so it is sensitive to single-sample
sensor spikes; a real system needs a spike filter" (LIMITATIONS G15). Nothing is re-run or filtered.

### 60.1 The CONFIRM2 days
`CONFIRM2_MANIFEST.json` (committed in `b6db22c`): file SHA-256 **`86f58ae95cdbb833ae1f42bf2a36fb5786a92a716843d9da8e50df265629ed23`**;
its own `n_days` = 16, `sha256_days` = `79ea95decaf9a07699b567ecfd4d8de3295db58fb7edfc3ab148faccc55d6bc2`. The runner
checks both before anything else and stops if either differs (the file SHA on the committed bytes with CR removed -
a Windows checkout with autocrlf adds CR; `p2_segset` checks the same). The day names are not read here.

### 60.2 Segment sets - by rule (the SHA of each list is printed as the FIRST output line at opening)
U of a segment and the envelope are computed by `core/p2_segset.m` (U = norm of the mean horizontal plant wind over
t ≥ 140 s, read from the segment file; no controller output). The rules are those of the dev sets, applied to the
16 CONFIRM2 days instead of the dev pool (`p2_segset(<rule>, 'CapPerDay', 4, 'Confirm2', 'wind_conf2')`, 60.8):
- **circle set** = the `circle_main` rule: circle (Test 4), K 0.5, m_p 0.5, L 1.0, A2 envelope (U ≤ 8.02 m/s), cap
  4 segments per day.
- **hover set** = the `N6_hover` rule: hover, K 0.5, m_p 0.5, L 1.0, envelope U ≤ 10.86 m/s, cap 4 per day.
- **H-hover set** = §26.3 unchanged = the `N5-H-StrongRel` rule: hover, K 0, U in 0.8-1.0 · U_max = 10.64-13.30 m/s,
  cap 4 per day (as on dev); unsaturated subset decided after the run by the fixed rule of §26.3.
- Cap 4 per day: evenly spaced in the pool's own order (the batch manifest's file order), as on dev.
Each list (file names, day, U) and its SHA-256 are printed and saved before the first simulation.

### 60.3 Claims (each run once; outcomes CONFIRMED / NOT CONFIRMED / NOT CONFIRMABLE, all reported)
Common: the frozen configuration of 60.6; SE = paired delete-one-day jackknife over the CONFIRM2 days of the set on
which the claim is scored; by-day median from each day's own pooled columns (§0.2); LOO [min, max] and the most
influential segment reported beside every claim, not part of any test.
**Data sufficiency (user 2026-10-03, every claim):** the set on which a claim is scored (D2: its one set;
H-static, H-static-circle: the L3-unsaturated subset of 2-3; H-hover: its unsaturated subset) must have
**≥ 15 segments AND ≥ 6 days**; otherwise the claim is **NOT CONFIRMABLE** - its numbers are printed, nothing is
merged, re-cut or re-run, and the paper states it as a development-set result only.
1. **D2 (circle set) - full set** - unchanged from §0.5 / §0.6.1: columns L0, L2, L3, V as `run_p2_gd6('D2',
   'TauPred', 0.290, 'TauPrev', 0.180)`; one set = finite in all four columns (§0.2); Δ = pooled(L3)/pooled(L2) − 1;
   **CONFIRMED ⇔ Δ ≤ −15 % AND Δ + 1.65·SE < 0**. No saturation subset for D2.
2. **H-static (hover set)** - §54.4 with the safety condition and the scoring subset (user 2026-10-03): columns L3
   and L3_iii0 (`PredScale` body 1.5, §54.2), as dev (`run_p2_gd7`, TauW 0.280, TauPred 0).
   - **Full set F** = every segment of the hover set. **n_unsafe** (counted on F) = the number of segments on which
     L3_iii0 is not finite (crash / diverged / phys_div / num_flag) while L3 is finite. **Every** such segment is
     listed with its flag, U and spike count (P-QA rule of §36, computed on the segment file).
   - **Scoring subset A** = the segments of F with L3 and L3_iii0 both finite **and tilt_sat_frac < 1 % in the L3
     column** (the subset is defined by **L3 only**, not by every column, so that a saturation caused by (iii-0)
     itself is NOT removed - it stays in A and counts against h). A segment whose L3 tilt_sat_frac is missing is
     not in A and is listed.
   - h = 1 − pooled_A(L3_iii0)/pooled_A(L3); SE, by-day median h_d over the days of A.
   - **CONFIRMED ⇔ A sufficient AND by-day median h_d ≥ 10 % AND h − 1.65·SE > 0 AND n_unsafe ≤ 1.**
   - Reported beside (not part of the test): the same statistics on the **full one set** (F ∩ L3, L3_iii0 finite),
     and the segments of F with tilt_sat_frac ≥ 1 % in L3 (listed with both columns' values).
   - **Reason (recorded):** consistent with the H-model rule (§28.1: unsaturated subset); on dev, the segment at the
     limit `wind_expl_t150_i0215` alone pulled the full-set h_static on N6_hover down to +20.27 % (SE 42.39,
     LOO up to +63.56 %) against +65.68 % on the unsaturated subset (§59.3, every column) - a single limit-hitting segment
     decides the full-set number and makes its SE large.
3. **H-static-circle (circle set)** - **post hoc (D22)**: L3 = D2's L3 column (the same run, reused after a
   spot check), L3_iii0 run with the same call as the D2 L3 column plus `PredScale` body 1.5; h_c = 1 −
   pooled_A(L3_iii0)/pooled_A(L3), with F, n_unsafe, A, the test and the beside-reports **exactly as in 2**
   (A defined by tilt_sat_frac < 1 % in the L3 column only).
4. **H-hover (H-hover set)** - §26.3 unchanged (K 0, τ_w\* = 20 ms, columns L3, O(τ_w\*), P, O(0); unsaturated subset
   = tilt_sat_frac < 1 % in **every** column, as registered in §26.3; **CONFIRMED ⇔ sufficient AND by-day median h_d ≥
   10 % AND h − 1.65·SE > 0**).
5. **H-model - removed** (§54.4; the old C2 did not pass §45.3). H-model(iii) was never registered.

### 60.4 Descriptive columns (no claim; for the paper's tables) and indices
- circle set: L0, L2, L3, V (from 1), L3_iii0 (from 3), **H3** (INDI, ω_f 32 Hz, §56).
- hover set: L3, L3_iii0 (from 2), **H3** (32 Hz), **H3_b086**, **H3_b170** (horizontal accelerometer bias 0.086 /
  0.17 m/s², §58.2).
- H-hover set: the four columns of 4.
- Per column and segment (fields of `pa_configs` / `p2_summary`, gathered by `core/p2_indices.m`; window t ≥ 140 s
  unless stated):
  - mean position error (the registered metric), RMS and max of the position error;
  - **`e_p95`** (new, additive): nearest rank, the ⌈0.95·n⌉-th smallest of the per-sample error norms;
  - **`u_osc`** (new, additive; control effort): $\sqrt{\mathrm{mean}_t \sum_{i=1}^4 (f_i(t) - \bar f_i)^2}$, the RMS
    oscillation of the **commanded** rotor forces $f_i$ about their own mean $\bar f_i$ over the window - independent of
    the weight carried;
  - **`sat_p2`** (new, additive): fraction of the window in which a commanded rotor force $f_i$ is at 0 or at the
    plant's $f_{max}$ (**P2: 7.6675 N**) or the total thrust $f_{act}$ is at $F_{TOT,max}$ (**P2: 27.603 N**);
    **`sat_rotor`**: its rotor part only (the case in which INDI's thrust estimate differs from the applied thrust,
    INDI_FIDELITY I8). $f_i$ = `f_i_log` = the output of `Motor_Allocation` **after its clamp and before the motor
    lag** (read from the model's existing log, no rebuild); limits = the base-workspace `f_max`, `F_TOT_MAX` set by
    `p2_setup`; `core/p2_cmd_sat.m`;
  - `tilt_sat_frac` (whole run, `p2_summary`); payload swing θ RMS / max.
  - Not used (user decision 2026-10-03): the v1 fields `sat_frac` (v1 limits 6.0 / 21.6 N, wrong for P2) and
    `u_rms` (RMS about m·g/4 with m = 1.121 kg, i.e. carrying the payload weight as a constant offset). They stay in
    `pa_configs` unchanged (v1 frozen). verify_repro must stay 0 and check_results_numbers 146/146.
- Table form: pooled (RMS over segments) for the mean / RMS indices, median and maximum over segments for max / p95,
  on the one set of each table and on its unsaturated subset; ratios with SE, LOO and by-day median as dev; every
  removed segment listed with its flags.

### 60.5 Order and hours (upper bound: 16 days × cap 4 = 64 segments per set)
Checks (60.9 conditions, manifest SHA, export check, verify_repro, D2 row 1, check_results_numbers) ≈ 0.5 h; circle
set: D2 (4 columns, ~110 s per segment) + L3_iii0 + H3 ≈ 64 × 160 s ≈ 2.9 h; hover set: 5 columns ≈ 64 × 130 s ≈
2.3 h; H-hover set: ≤ 64 × 4 columns ≈ ≤ 1.8 h (expected far fewer segments in the U band). **≤ 7.5 h in total, one
batch (nights 19-20).** Order: D2 → circle (L3_iii0, H3) → hover → H-hover → the claim report.

### 60.6 Frozen configuration (user 2026-10-03) - nothing is tuned on CONFIRM2
Every value below is the dev value already used for the numbers of §51-§59; none is chosen, searched or changed on
CONFIRM2:
- **Payload τ:** circle TauPred **290 ms** (τ\*_circle; L3, L3_iii0, H3 on the circle), V TauPrev 180 ms; hover
  TauPred **0** (τ\*_hover). τ_w: TauW 280 ms for the circle / hover groups (as dev; read only by O columns, of which
  these groups have none); H-hover τ_w\* = **20 ms** (§26.3).
- **INDI (H3):** ω_f = **32 Hz** (D21, §56); estimate computed at 1 kHz, force command at 125 Hz, as dev.
- **(iii-0):** K̂ = **0.5** (the nominal K), body feed-forward factor 1 + K̂ = **1.5** (`PredScale` [1 1 1 1.5]).
- **Accelerometer bias columns:** 0.086 / 0.17 m/s², horizontal, direction per segment from MT19937 seed
  7000000 + 100·seg + 31 (`core/p2_acc_bias_vec.m`), as dev.
- **Envelope A2** (`core/p2_umax.m`): U_max 8.02 (circle, K 0.5), 10.86 (hover, K 0.5), 13.30 (hover, K 0) m/s.
- **Wind sensor σ = 0** (export `--sensor-noise` default 0, no bias), sensor delay 50 ms, PredDelay as dev.
- **Spike filter OFF** (none exists in the pipeline; G15). The spike count of §36 is computed only to list segments.
- **Plant and controller:** P2 nominal; Guo gains Kγ diag(12, 12, 35), Kν diag(8, 8, 18); m 1.121 kg; m_p 0.5,
  L 1.0; τ_m irrelevant ((iii) removed); model `baseline1.slx` MD5 `B27EA7C8FB6544E0CE68E8B765BAAAD3` (or a
  bit-exact successor shown by verify_repro and D2 row 1).
- **Export pipeline = dev:** `python/export_wind_sim.py` (SHA-256 `33c870b7…5dff` at the runner's commit), command
  of §6.1 with only `--real-dir` and `--out` changed:
  `py -3.13 python/export_wind_sim.py --real-dir <confirm2 dir> --real-split dev --real-max 10000 --ckpt w4_frozen_20hz_t150_train2345_s0 --out wind_conf2/wind_conf2_t150.mat`
  (interpreter: **`py -3.13`**, the one that passed E0 - added 2026-10-03; the `python` on the user's PATH is 3.14.7
  and is used only by the runner's byte comparison `check_export_same.py`, which needs numpy + scipy there);
  checkpoint `w4_frozen_20hz_t150_train2345_s0.pt` SHA-256 `0bc4b5b8…7fad`, `.json` `fe280c38…0e08`. The export code
  differs from the dev export (`d1ecab2` / `cf49a90`) only by `4fb5f13` (options `--only-index` / `--check-against`,
  default off). **Proof before opening (E0):** three dev exploration segments (i0000, i0215, i0440) are re-exported
  with the current code into `wind_e0check/` and every variable of every file must equal the dev file bit for bit
  (`python/check_export_same.py`, run by the runner); otherwise CONFIRM2 is not exported:
  `python python/export_wind_sim.py --real-dir <exploration dir> --real-split dev --ckpt w4_frozen_20hz_t150_train2345_s0 --only-index 0,215,440 --check-against . --out wind_e0check/wind_expl_t150.mat`
  then `python python/check_export_same.py wind_e0check .` → `E0: 3 file(s) compared, 0 differing -> PASS`.
- **Git hash:** the export and the run use the runner's approved commit (git hash printed in both logs); the runner
  stops if the working tree has local changes to code (`core/`, `experiments/`, `python/`, `baseline1.slx`).

### 60.7 Incidents (user 2026-10-03)
- A stop (power cut, MATLAB crash, error) → the run is **only resumed from where it stopped** (per-segment
  checkpoints in `results/gd10/`); no code, parameter or set is changed and nothing already computed is re-run.
- An error found **after** CONFIRM2 is opened (a bug, a wrong parameter, a wrong file) is **not** fixed and re-run:
  it is reported as a deviation (DEVIATIONS.md, dated) **together with the result under the original rule**. Any
  corrected number is an additional, labelled exploratory number, never a replacement.
- A segment that crashes in a column is a result (one-set / n_unsafe rules), not an incident.

### 60.8 Runner and data path
- Runner `experiments/gd10_confirm2.m` (commit hash recorded in the APPROVED line). It calls only the dev runners
  (`run_p2_gd6` D2, `run_p2_gd7` with the CONFIRM2 groups `C2-circle`, `C2-hover`, `C2-hhover`, whose columns and
  configurations are those of the dev groups D2 / static-circle + H3-circle / static-hover + static-indi-bias /
  N5-H-StrongRel) with the option `'Conf2', 'wind_conf2'`: set from `p2_segset(..., 'Confirm2', 'wind_conf2')`,
  segment files read from `wind_conf2/`, results in `results/gd10/`, reuse only inside `results/gd10/` (the L3 of
  the CONFIRM2 D2 run), every index of 60.4 stored per column. Without `'Conf2'` every dev call is unchanged
  (bit-exact).
- `p2_segset(..., 'Confirm2', dir)`: pool = the files of `dir/wind_conf2_t150_batch.json`; checks before any U is
  computed: the manifest file SHA-256 and `sha256_days` (60.1), every segment's day ∈ the manifest days, no
  manifest day in the dev pool, every file named `wind_conf2_t150_i*.mat`. Without the option nothing changes.
- The claims of 60.3 are computed by the runner from the saved rows (its own code, written and tested on dev before
  opening), then printed with every listed segment; the per-group dev reports are printed beside as descriptive.
- **Dev test (before approval):** `gd10_confirm2('DevTest', true)` runs the whole chain on two dev segments per set
  (no CONFIRM2 file is read; results in `results/gd10_devtest/`), to check the plumbing only. In the dev test the
  opening condition is printed, not required, and E0 runs only if `wind_e0check/` exists.
- **Runner commit `84a243b`** (2026-10-03; supersedes `c1a3cf3`, which carried the v1 `sat_frac` / `u_rms` as
  indices - corrected before approval, no claim changed: `core/p2_cmd_sat.m`, `p2_indices`, the additive `pa_configs`
  fields of 60.4; same Octave checks repeated: dev groups `c1a3cf3` vs `84a243b` identical logs, calls and saved
  files; the mock CONFIRM2 claims identical).
- Runner first written in commit `c1a3cf3` (files: `experiments/gd10_confirm2.m`, `analysis/conf2_claims.m`, `core/p2_indices.m`,
  `python/check_export_same.py`; options in `core/p2_segset.m`, `experiments/run_p2_gd6.m`, `run_p2_gd7.m`; field
  `e_p95` in `core/pa_configs.m`). Checked in Octave with mocks (no Simulink): the dev groups D2, iii-hover,
  static-hover-k, static-circle, H3-circle, N5-H-StrongRel, iii-circle give the same log, the same 90 `pa_configs`
  calls and identical saved result files with the code before and after; `DevTest` and a mock CONFIRM2 run go end to
  end (n_unsafe, the L3-only subset, NOT CONFIRMABLE all exercised); a resume reproduces the claims exactly; a
  tampered manifest, a day outside the manifest, a manifest day in the dev pool, a foreign file, a wrong set SHA, a
  resume with another configuration, an unticked / doubly ticked / SAI box, no APPROVED line and a code change after
  the approved commit each stop the run. The real manifest passes both SHA checks (nothing else of CONFIRM2 read).
  `verify_repro` = 0 with `e_p95` is to be shown on MATLAB by the dev test (its step 1).

### 60.9 Opening condition (user 2026-10-03)
CONFIRM2 is downloaded, exported or opened **only after** (a) the user has ticked every check box of
`docs/MOBADC_FIDELITY.md` and `docs/INDI_FIDELITY.md` (one box per line: ĐÚNG / SAI, and the corrigendum line of
INDI_FIDELITY), and (b) this section is APPROVED by a line **starting with `APPROVED`** in this section that contains
the date (yyyy-mm-dd) and `commit <hash>` of the runner, e.g. `APPROVED: Huyhoang   ngày: 2026-10-05 - runner
commit 84a243b`; the runner requires that commit to be an ancestor of HEAD with no change to `core/`,
`experiments/`, `analysis/`, `python/` or `baseline1.slx` since. The runner reads both fidelity files first and
stops if any box line is unticked or ticked twice; if any item is ticked **SAI**, it stops and prints the item - the
consequence is decided by the user and registered here before opening.

### 60.10 Dev test of the runner (MATLAB R2022b, 2026-10-03) - facts
`gd10_confirm2('DevTest', true)` at git `49e6307` (runner code = `84a243b`, no code change since), log
`results/gd10_devtest/confirm2_20261003_104702.txt`, 0.5 h, after deleting the earlier dev-test results (made with
`c1a3cf3` at git `1fef573`, whose rows carried the v1 indices; that first dev test passed the same checks).
- **Step 0** (printed, not required in the dev test): MOBADC_FIDELITY 17/17 ticked, no SAI; INDI_FIDELITY 12/13 - the
  corrigendum line (38) unticked; no APPROVED line; no local code change. Opening would stop here, as intended.
- **Step 1:** `verify_repro` REPRODUCED (32 cells, largest difference 0.000e+00, with `e_p95`, `sat_p2`, `sat_rotor`,
  `u_osc` added); `check_results_numbers` **146 passed / 0 mismatched**; D2 row 1 (i0000) [0.0414 0.0334 0.0140
  0.0136] unchanged. E0 skipped (no `wind_e0check/` yet; required before opening).
- **Sets** by the dev rules: circle_main `a227e9d8…` (134 / 42 days), N6_hover `43226c02…` (139 / 43) - the registered
  SHAs; N5-H-StrongRel `7b105836…` (23 / 11).
- **Plumbing (2 segments per set):** D2 reuse spot check |d| 0; values equal to dev (H3 circle i0000 0.0371 as §57;
  hover H3_b086 / H3_b170 7.3-7.4 / 14.2-14.3 mm as §59.2); claims computed, all NOT CONFIRMABLE (2 segments) - h
  +67.25 % (hover), +37.95 % (circle), H-hover +42.33 % (1 unsaturated segment), D2 −59.13 %; identical to the first
  dev test, so the index change touched no claim.
- **New indices are read** (no NaN): `u_osc` 0.52-0.55 N (circle), 0.48-0.50 N (hover), 0.71-0.88 N (H-hover set) -
  no weight offset (the v1 `u_rms` was 2.5-3.0 N in the first dev test); `sat_p2` = `sat_rotor` = 0 on all 6
  segments, including `wind_real_t150_i0384` (tilt clamp 28 % of the run in L3): the tilt clamp acts, the rotors do
  not reach 0 or 7.6675 N. The counting itself is unit-tested (`core/p2_cmd_sat.m`, Octave, synthetic logs).
- **Times per segment:** D2 112 s (4 columns), C2-circle 55 s, C2-hover 136 s, C2-hhover 108 s → CONFIRM2 ≈ 64 ×
  167 s (circle) + 64 × 136 s (hover) + n_hh × 108 s + 0.25 h checks ≈ **5.6 h + n_hh × 108 s** (n_hh ≈ 9 if the dev
  rate holds; ≤ 7.5 h at n_hh = 64).
- **E0 (2026-10-03, user's machine, `py -3.13`, git `accec0f`, export code = runner `84a243b`): PASS.**
  `export_wind_sim.py --real-dir E:\m5_explore --real-split dev --ckpt w4_frozen_20hz_t150_train2345_s0
  --only-index 0,215,440 --check-against . --out wind_e0check\wind_expl_t150.mat`: "128 files -> 441 segments through
  QC" (= §6.1); `check_export_same.py wind_e0check .`: i0000, i0215, i0440 - **38 variables identical bit for bit**
  each (w_hat of the frozen PI-MoE included) → "E0: 3 file(s) compared, 0 differing -> PASS". The dev export pipeline
  is reproduced; the batch manifest of the check went to `wind_e0check\`, the dev one is untouched.
- **E0 with the runner's interpreter (2026-10-03):** numpy 2.5.3 + scipy 1.18.1 installed for the PATH `python`
  (3.14.7, user site); `python python/check_export_same.py wind_e0check .` → 38 variables identical bit for bit in each
  of the 3 files, "E0: 3 file(s) compared, 0 differing -> PASS" - the same command the runner calls. No code change
  (runner `84a243b`).
- **E0 from inside MATLAB (2026-10-03):** `system('python python/check_export_same.py wind_e0check .')` → status 0,
  PASS (MATLAB's PATH reaches the same interpreter).
- **Fidelity boxes complete (2026-10-03):** MOBADC_FIDELITY 17/17, INDI_FIDELITY 13/13. Corrigendum S1c **read**
  (CEP 141 (2023) 105093, 1 page): it corrects Eq. (12) (attitude-loop closed-loop transfer function) and, with it, the
  numbers of the next paragraph (K_η 10.7 → 21.4 in the text, complex poles 0.968 ± 0.0463i → 0.965 ± 0.0445i, model
  vs measured step 6.4 % → 4.8 %); "does not influence any of the conclusions". H3 uses neither (12) nor the INDI
  attitude loop, so nothing of H3 changes. (A first tick on the arXiv v2 evidence, `4d6723f`, is superseded.)

### 60.11 Approval
Dev test of the runner at code `84a243b` (git `49e6307`, identical code): verify_repro 0.000e+00 (32 cells),
check_results_numbers 146/146, D2 row 1 unchanged, E0 PASS (§60.10); fidelity boxes 17/17 and 13/13 (corrigendum read).

APPROVED: Huyhoang   ngày: 2026-10-03 - runner commit 84a243b

### 60.12 Prior exposure of the CONFIRM2 days - DEVIATION D23 (found 2026-10-03 at download, before any export or run)
- **Finding.** After the download (64 files, 16 days, hours 02/08/14/20, in `E:\m5_confirm2`), all 64 file names were
  already in `E:\windataset\m5` (none in `E:\m5_explore`), written 2026-09-02 15:26-15:41 by the W5 download of every
  dev day; 63/64 identical byte for byte. Cause and the full exposure statement: DEVIATIONS **D23**.
- **Exposure, in short:** all 16 days entered W5's pooled zero-shot wind-prediction tables (65 days, 1431 segments);
  **2 of the 16 days (2024-01-18, 2024-04-15) are W5 characterisation days**, inspected per segment to set the QC
  thresholds, the height band and the T_c grid of the frozen PI-MoE. No controller run, no P2 parameter used them.
- **Decision (user, 2026-10-03, before any export or controller result): CONFIRM2 = the 16 manifest days minus
  `CHARACTERISATION_DAYS` = 14 days.** The rule is set by the **level of exposure**: 2024-01-18 and 2024-04-15 were
  inspected segment by segment in W5 to set the QC thresholds, the height band and the T_c grid; the other 14 days
  only entered pooled wind statistics. Nothing else changes (sets by rule on the 14 days, §60.2; runner `84a243b`;
  `p2_segset` requires every day to be in the manifest, which still holds; data sufficiency ≥ 6 days unaffected).
- **Excluded files - moved, not deleted,** from `E:\m5_confirm2` to `E:\m5_confirm2_excluded` before the export
  (reason: W5 characterisation days, D23):
  `01_18_2024_02_00_00_000.mat`, `01_18_2024_08_00_00_000.mat`, `01_18_2024_14_00_00_000.mat`,
  `01_18_2024_20_00_00_000.mat`, `04_15_2024_02_00_00_000.mat`, `04_15_2024_08_00_00_000.mat`,
  `04_15_2024_14_00_00_000.mat`, `04_15_2024_20_00_00_000.mat`.
- **Sentence for the paper:** "The two days previously inspected segment-by-segment to set QC thresholds were excluded
  before any controller run; the remaining fourteen confirmation days contributed only to pooled wind statistics
  (deviation D23)."
- **For the future (not applied backwards):** `python/make_confirm2_manifest.py` (and `plan_real_download.py
  --exclude-used`) are to exclude `CHARACTERISATION_DAYS` as well. Changed **after** the CONFIRM2 run: a change in
  `python/` now would make the runner's approval check stop (no code change since `84a243b` is required).
- **Hours** with ≤ 14 days × cap 4 = ≤ 56 segments per set: ≈ 56 × 167 s + 56 × 136 s + n_hh × 108 s + 0.25 h ≈
  **4.9 h + n_hh × 108 s**.
- **Files, fixed before the export:**
  - `04_11_2024_14_00_00_000.mat`: the new transfer is truncated (63 981 B; the 2026-09-02 copy is 2 907 809 B). It is
    downloaded once more; if that copy equals the 2026-09-02 copy byte for byte it is used, otherwise the 2026-09-02
    copy is used (the archive's complete file) and the difference is reported. Either way the content is the 09-02 one.
  - Six files are short on the server itself (new = old byte for byte: 01_13 14h, 02_17 02h/08h/14h, 04_18 14h/20h,
    0.77-0.99 MB); they are exported as they are and the registered QC decides (no manual exclusion).

APPROVED (xác nhận sau D23, CONFIRM2 = 14 ngày): Huyhoang  ngày: 2026-10-03 - runner commit 84a243b

## 61. Results of CONFIRM2 (`gd10_confirm2`, git `eb427cb`, runner `84a243b`, 2026-10-03, 5.0 h) - facts
Log `results/gd10/confirm2_20261003_124651.txt` (user's machine). 14 days (16 minus the 2 W5 characterisation days,
§60.12 / D23). Run once; nothing re-run.

### 61.1 Checks and sets
- Step 0: MOBADC_FIDELITY 17/17, INDI_FIDELITY 13/13, APPROVED 2026-10-03 runner `84a243b` (ancestor, code unchanged),
  no local code change - all OK. Step 1: verify_repro 32 cells 0.000e+00 (REPRODUCED); check_results_numbers 146/146;
  D2 row 1 [0.0414 0.0334 0.0140 0.0136] unchanged; E0 PASS (3 files, 38 variables each).
- Sets (SHA-256 of each list, printed first):

  | set | rule | SHA-256 | segments / days |
  |---|---|---|---|
  | circle | circle_main | `2f442433f5f86be38450e3934cc22296e2eedf004e79d96573dcd8acfd3df91c` | 56 / 14 |
  | hover | N6_hover | `5b69e3ad8af37528df0e174c423872777cc5dfa7246196e5d86088d7bb25af5a` | 56 / 14 |
  | H-hover | N5-H-StrongRel | `19530f2821fe9ef482ebad0925fee7b7e930c8e9d5a83ba0e8d07e184b5d3854` | 4 / 1 |

  No segment of 2024-01-18 or 2024-04-15 in any list. Reuse spot check (D2 L3 for C2-circle) |d| 0.

### 61.2 Claims (sec 60.3) - the runner's verdicts
| claim | scored set | value | SE | LOO | by-day median | test | verdict |
|---|---|---|---|---|---|---|---|
| **D2** Δ = L3/L2 − 1 | one set 56 / 14 (full) | **−58.30 %** | 4.57 | [−60.66, −58.12] | −63.88 % | Δ ≤ −15 % ✓; Δ + 1.65 SE = −50.76 % < 0 ✓ | **CONFIRMED** |
| **H-static** h = 1 − L3_iii0/L3 | A 52 / 14 (L3 tilt_sat < 1 %) | **+63.00 %** | 1.37 | [+61.12, +64.09] | +61.30 % | median ≥ 10 % ✓; h − 1.65 SE = +60.75 % ✓; n_unsafe 0 ≤ 1 ✓ | **CONFIRMED** |
| **H-static-circle** (D22) | A 53 / 14 | **+37.18 %** | 3.04 | [+36.19, +37.40] | +35.07 % | median ✓; h − 1.65 SE = +32.16 % ✓; n_unsafe 0 ✓ | **CONFIRMED** |
| **H-hover** h = 1 − O/L3 | unsaturated 1 / 1 | +41.92 % | - | - | - | < 15 segments, < 6 days | **NOT CONFIRMABLE** |

- D2: pooled L0 0.04052, L2 0.03434, L3 0.01432, V 0.01291; most influential `wind_conf2_t150_i0093`. Tilt clamp > 1 %
  on 3 segments (i0082, i0090, i0093); Δ without them −62.4 % (n 53, secondary, sec 10.1). Dev: −50.33 % (134 / 42).
- H-static: beside, full one set +63.55 % (SE 1.75, LOO [+62.49, +65.74]); L3-saturated, not in A: i0004 (tilt_sat
  0.0329), i0018 (0.0124), i0027 (0.0556), i0089 (0.1871) - L3_iii0 lower than L3 on each (0.0159 / 0.0111 / 0.0084 /
  0.0074 vs 0.0364 / 0.0350 / 0.0240 / 0.0269). No (iii-0) failure (n_unsafe 0). Dev: +20.27 % full / +65.68 %
  unsaturated (N6_hover).
- H-static-circle: beside, full one set +39.00 % (SE 2.91, LOO [+37.59, +39.21]); not in A: i0082, i0090, i0093.
  Dev (S40): h_c = +43.67 %.
- H-hover: the K 0 band 10.64-13.30 m/s holds 4 segments, all on one day (2024-01-17); `wind_conf2_t150_i0015`
  (U 13.22) diverged in all four columns; i0010, i0013 saturated; one segment scored. Beside: c −50.91 %, h_sensor
  +29.21 %, h_pred +17.95 %, (L3 − P)/L3 −21.34 %, h on the one set (3) +40.69 %. H-hover stays a development-set
  result in the paper (§26.3, §0.6.1).

### 61.3 Descriptive columns (sec 60.4; no claim)
Circle (one set 56; unsaturated 53): pooled mean L3 0.01432, L3_iii0 0.00873, **H3 0.03717** (unsat. 0.01261 /
0.00792 / 0.03689); H3 lies at 0.0357-0.0373 m on every segment except i0093 (0.0508), as on dev (§57.1). Max of max:
0.658 / 0.678 / 0.675 m (from the 3 saturated segments; 0.063 / 0.049 / 0.053 m on the unsaturated subset); median p95 0.0211 / 0.0135 / 0.0432 m. u_osc 0.579 / 0.611 /
0.543 N. sat_rotor max 0.00022 (L3), 0.00095 (L3_iii0), 0 (H3).
Hover (one set 56; unsaturated 52): pooled mean L3 0.01057, L3_iii0 0.00385, **H3 0.00260**, H3_b086 0.00766,
H3_b170 0.01446 (unsat. 0.00680 / 0.00252 / 0.00150 / 0.00734 / 0.01427); on calm segments H3_b086 ≈ 7.1-7.5 mm and
H3_b170 ≈ 14.0-14.5 mm (b/K_γ = 7.2 / 14.2 mm, §58.2). u_osc 0.532 / 0.556 / 0.503 N; sat_p2 = sat_rotor = 0 in every
column; tilt_sat mean ≤ 0.0054.
Ratios computed here from the printed pooled values (no SE; for orientation only): circle H3/L3 − 1 = +159.6 %
(unsat. +192.6 %); hover H3/L3 − 1 = −75.4 % (unsat. −77.9 %), L3_iii0/H3 − 1 = +48.1 % (unsat. +68.0 %),
H3_b086/L3_iii0 − 1 = +99.0 %, H3_b170/L3_iii0 − 1 = +275.6 %.

### 61.4 Still to record
- §60.12 `04_11_2024_14_00_00_000.mat` (user's PowerShell, re-run 2026-10-03): the re-download in `E:\m5_confirm2`
  (written 2026-10-03 12:42:14) is **2 907 809 B, SHA-256 `91124B302A70AE1B1E2B5A406D23BD248C9452BF88BEB5064CE7D42F006B7F6B`**,
  equal byte for byte to the 2026-09-02 copy in `E:\windataset\m5` (written 15:35:24, same size and hash): **True**.
  The complete file was used; whichever copy the export read, the content is the same.
- Export: **56 files → 163 segments through QC, 14 days** (read from `wind_conf2/wind_conf2_t150_batch.json` by
  `make_p2_figures` figure 2, 2026-10-03; no D23 day among them, asserted).
- Done after the run: `make_confirm2_manifest.py` / `plan_real_download.py --exclude-used` also exclude
  `CHARACTERISATION_DAYS` (D23, for the future; the CONFIRM2 manifest is not regenerated; commit `9957ae7`).

### 61.5 Incident after the run: `baseline1.slx` modified on the user's disk (found 2026-10-03, GD11b) - facts
- **Found:** figure 3 of `make_p2_figures` (re-run of one CONFIRM2 segment) stopped at compile time in every column:
  "Variant control 'Choice' of variant block 'baseline1/UAV_Plant/P2_PZ_nu' ...". `git status` on the user's machine:
  ` M baseline1.slx`; the loaded file was `E:\windataset\baseline1.slx` (the only one on the path), not dirty in memory.
  The block had a third variant input `'Choice'` beside `p2_poison==0` / `p2_poison==1` (the committed model,
  `54a72f6`, has two). No repository script saves the model there; the cause (an interactive edit and save) is not
  known.
- **Timing (file dates on the user's machine):** `baseline1.slx` last written **2026-10-03 18:04:30**. CONFIRM2:
  step 0 found no local change in `core experiments analysis python baseline1.slx` (§61.1) at the 12:46:51 start,
  then closed and re-loaded the model from that clean file; the results were written `sets.mat` 13:00:20, `D2.mat`
  14:40:52, `C2-circle.mat` 15:31:51, `C2-hover.mat` 17:36:55, `C2-hhover.mat` and `claims.mat` 17:44:07. **The file
  was changed after the last CONFIRM2 result; no CONFIRM2 number is affected.**
- **Action (user, 2026-10-03):** the changed file kept as `baseline1_modified_backup.slx` (local, ignored), then
  `git checkout -- baseline1.slx` (back to `54a72f6`); `P2_PZ_nu` controls again `p2_poison==0` / `p2_poison==1`.
- **Check:** figure 3 re-ran `wind_conf2_t150_i0069` (lower median U 4.1076 m/s, rank 28 of 56) in L2, L3, (iii-0)
  and H3: |re-run − stored CONFIRM2 row| = **0** in all four columns (registered tolerance 1e-12); figure saved.
- **Guard added:** `make_p2_figures` figure 3 now stops before any simulation if `git status` reports a change in
  `baseline1.slx`, `core/` or `experiments/` (the runner's rule, §60.6).

## 62. GD11 figures and tables - registered before any figure is drawn (user decision 2026-10-03)
Main results stay at the registered and confirmed configuration: **L 1.0 m, m_p 0.5 kg**. Figures are produced by
`figures/p2/make_p2_figures.m`, tables by `analysis/make_p2_tables.m` (→ `docs/TABLES_P2.md`), both from saved results
(no simulation), except Figure 3 (see 3). Every panel states its set (dev circle_main / S40 / S40hover / N6_hover /
T3b / square / CONFIRM2) and role, as in RESULTS_P2. Error bars: ± 1.65 SE (paired day jackknife).

### 62.1 Figures
1. **System and block diagram** - P2 (quadrotor, slung payload, two wind paths: airframe and payload) and the
   controller with the compared estimates (L0/L2/L3/V, (iii-0), INDI-type H3). Schematic, no data.
2. **Wind data** - per segment, U (as `p2_segset`: norm of the mean horizontal plant wind over t ≥ 140 s) and
   TI = σ_u / U with u = horizontal plant wind projected on the segment's mean horizontal direction over the same
   window; dev pool (30 field_grid + 441 exploration segments) vs CONFIRM2 (the 14-day export, every segment through
   QC); vertical lines at the A2 envelopes: circle K 0.5 → 8.02 m/s, hover K 0.5 → 10.86 m/s, hover K 0 → 13.30 m/s.
3. **Illustrative time series** - segment rule (fixed now): the CONFIRM2 **circle** set (56 segments), sorted by U
   (ties: file name), the **lower median** (the 28th); columns L2, L3, L3_iii0 and H3: position error norm and payload
   swing over t ≥ 140 s. The time series are not stored, so this one segment is **re-simulated** with the frozen
   configuration (`KeepTraj`); the script prints the re-run mean error of each column next to the stored CONFIRM2 row
   (must agree to 1e-12, else the figure is not saved). Illustration only - no number of the paper comes from it.
4. **C1** - L3/L2 − 1 and V/L2 − 1 (± 1.65 SE) for circle (dev circle_main, CONFIRM2), T3b and square (dev); scatter of
   per-segment L3 vs L2 (dev circle_main and CONFIRM2, identity line).
5. **Horizon τ** - pooled error vs payload-prediction horizon τ from N0P (`results/gd6/n0p_p2.mat`), every condition
   in the file, τ\* marked.
6. **C2** - forest of h (± 1.65 SE): hover (dev N6_hover on A and on the full set, dev S40hover nominal and K̂ × 0.7 /
   × 1.3, CONFIRM2 on A) and circle (dev S40, CONFIRM2 on A); **new panel: control effort and payload swing** for L2,
   L3, (iii-0) and INDI - `u_osc` (RMS oscillation of the commanded rotor forces about their own mean, §60.4; the
   "u_rms" of the request) and θ RMS / max over t ≥ 140 s, from the CONFIRM2 descriptive indices (circle: L2 from the
   D2 rows, the others from C2-circle; hover: L3, (iii-0), H3 - L2 was not run on hover in CONFIRM2). Dev rows carry θ
   (`p2_summary`) but no `u_osc`; where dev lacks a quantity only CONFIRM2 is shown and the panel says so.
7. **Fast measurement vs prediction** - pooled L3, (iii-0) and H3 on circle and on hover, dev and CONFIRM2, with the
   ratios H3/L3 − 1 and L3_iii0/H3 − 1 (± 1.65 SE, from RESULTS_P2).
8. **C3 - map of the 12 wind groups** (§0.8, A3): per group h = 1 − O(τ_w\*)/L3 (N6: O_6/L3_6) ± 1.65 SE, n and days,
   the registered headroom verdict; group #3 (N5-A-Strong) shown as empty under A2.

### 62.2 Tables
1. **Parameters** - values read from `core/p2_params.m` / `init_MOBADC_params` at run time, labelled [PAPER] /
   [THIS WORK] / [DERIVED].
2. **Guo reproduction** - Classical / ESO / DO / MOBADC (+ Classical+trim, DO+trim) on circle_main: pooled, vs Classical
   (± SE, LOO, by-day), from `guo_p2.mat` / `guo_trim_p2.mat`.
3. **Claims** - D2, H-static, H-static-circle, H-hover: dev and CONFIRM2, value, SE, LOO, by-day median, n (days),
   verdict; **added columns `u_osc` and θ RMS** of the compared columns (CONFIRM2; dev θ where stored; dev `u_osc`
   not stored - marked "-").
4. **Sensitivity - every level, not only the best**, circle on S40, columns L0 L2 L3 V, L3/L2 − 1 and V/L2 − 1 (± SE,
   LOO, by-day), one set n: nominal (0.5, 1.0); m_p 0.25 (re-pooled on U ≤ 7.38 m/s, §50.1) and 0.65 at L 1.0;
   L 0.5 and 1.5 at m_p 0.5; the 2² corners (0.25, 0.5), (0.25, 1.5) (re-pooled, §50.1), (0.65, 0.5), (0.65, 1.5).
   Plus a **trend sentence generated from the numbers** (range of L3/L2 − 1 and V/L2 − 1 over all levels, the level
   with the smallest and largest gain) - stated as fact, not a reading.

## 63. Main comparison, ablation and trajectory figure on dev circle_main - registered 2026-10-03, before any run (user request; amended the same day before any run: names, table 5 rows, table 6, variant B)
**Dev set only. Nothing is run on CONFIRM2.** Role of every item: **DESCRIPTIVE** (no claim, no gate). PAW-MOBADC (the
proposed method) is the post-hoc (iii-0) of D20, found on dev; its registered confirmation is the H-static /
H-static-circle claims on CONFIRM2 (§61.2), not these tables.

### 63.1 Names in the paper (user decision 2026-10-03; replaces every earlier naming instruction)
| name in the paper | meaning | internal code (results files, runners only) |
|---|---|---|
| **PID** | Guo 2020 "Classical": PD position and attitude laws, every estimate off (§46.3) | `Classical` |
| **DO** | Guo 2020, disturbance observer only | `DO` |
| **ESO** | Guo 2020, extended state observers only | `ESO` |
| **MOBADC** | Guo 2020 as published (DO with one harmonic, position + attitude ESO, no wind sensor) | `MOBADC` = `L0` |
| **MOBADC-DC** (official, user 2026-10-03) | MOBADC with the DO's DC mode added, no wind sensor | `L1` |
| **MOBADC-W** | MOBADC-DC + measured-wind feed-forward | `L2` |
| **MOBADC-W + preview** | MOBADC-W + reference preview τ_prev | `V` |
| **PA-MOBADC** (Prediction-Augmented) | MOBADC-W + payload-disturbance prediction τ ahead (C1) | `L3` |
| **PAW-MOBADC** = **the proposed method** | PA-MOBADC + payload-wind compensation, static (1 + K̂) feed-forward (C2) | `L3_iii0` |
| **INDI-DE** | INDI-type acceleration-based disturbance estimation (outer loop of Smeur 2018), ω_f 32 Hz | `H3` |
| **MBP** (model-based payload predictor) | the negative result of §45/§53 (**not** called a "pendulum model", to avoid confusion with the plant) | `L3_iii` |
| PID + trim, DO + trim | §47 | `Classical+trim`, `DO+trim` |
| oracle / PI-MoE | C3 columns: true future wind / frozen predictor | `O` / `P` |

- **No code** (L0, L1, L2, L3, V, iii, iii-0, H3 and their variants) may appear in any figure, table or manuscript
  text. Checked by `tools/check_names.py` (step 9 of `check_all`) on `docs/MANUSCRIPT*.md`, `docs/TABLES_P2.md`,
  `docs/RESULTS_P2.md` and the text of every generated figure (`figures/p2/out/labels.txt`, written by
  `make_p2_figures`). File names and other `code spans` are exempt.
- **Manuscript (GĐ11d):** the model section states that **plant P2 is a 3-D spherical pendulum coupled to the UAV**
  (`EQUATIONS_TABLE` rows 1–5), replacing the two planar pendulums of v1.

### 63.2 Table 5 - main comparison on circle_main (dev), in the style of Guo 2020 Table 1
- **Configuration:** circle `Test 4` (R 0.8 m, 1.26 m/s), L 1.0 m, m_p 0.5 kg, K 0.5, sensor delay 50 ms; τ = 290 ms;
  K̂ = 0.5 (factor 1.5).
- **Set:** circle_main, cap 4 per day, SHA `a227e9d87a2ac436…`, 134 segments / 42 days (the D2 set).
- **Rows (no PA-MOBADC in this table):** PID, PID + trim, DO, DO + trim, ESO, MOBADC (stored: `guo_p2.mat`,
  `guo_trim_p2.mat`), INDI-DE and **PAW-MOBADC** (both from the run of §63.4).
- **Columns:**
  - mean = pooled $\sqrt{\mathrm{mean}_i\, m_i^2}$ (SE, paired day jackknife; by-day median);
  - STD = $\sqrt{\mathrm{mean}_i\, s_i^2}$, where $s_i$ is Guo's within-segment standard deviation of ‖γ − γ_d‖ over
    t ≥ 140 s, $s = \sqrt{\tfrac{1}{n-1}\sum(\lVert\boldsymbol e\rVert - \bar y)^2}$ (Guo 2020 Table 1, p. 9;
    `docs/MOBADC_FIDELITY.md` line 448–449; = `pa_configs` `std`);
  - θ RMS (payload swing, pooled quadratic mean).
  - u_osc is **not** in this table.
- **One set:** finite in all six main rows (PID, DO, ESO, MOBADC, INDI-DE, PAW-MOBADC); the trim rows on the same
  segments.

### 63.3 Table 6 - ablation MOBADC-W → PA-MOBADC (+ prediction, C1) → PAW-MOBADC (+ payload-wind compensation, C2)
Existing numbers only (nothing extra run; the circle dev PAW-MOBADC column comes from the run of §63.4).

| block | MOBADC-W | PA-MOBADC | PAW-MOBADC |
|---|---|---|---|
| circle, dev circle_main (134) | `d2_p2.mat` | `d2_p2.mat` | `six-circle-h3.mat` |
| circle, CONFIRM2 (56) | `gd10/D2.mat` | `gd10/D2.mat` | `gd10/C2-circle.mat` |
| hover, dev N6_hover | not run ("-") | `static-hover.mat` | `static-hover.mat` |
| hover, CONFIRM2 (56) | not run ("-") | `gd10/C2-hover.mat` | `gd10/C2-hover.mat` |

- **Per block:** pooled value of each stage on the block's one set (finite in its columns), and the step changes
  C1 = PA/MOBADC-W − 1 and C2 = PAW/PA − 1 (SE, LOO, by-day median), plus the total PAW/MOBADC-W − 1.
- The registered claim values (D2; H-static on the L3-unsaturated subset) stay in Table 3. This table uses each
  block's full one set and says so.

### 63.4 New run - variant B, `six-circle-h3` (chosen by the user)
- `run_p2_gd7('six-circle-h3', …)` on the 134 segments:
  - **runs** PAW-MOBADC (`L3_iii0`) and INDI-DE (`H3`);
  - **reuses** PA-MOBADC (`L3`) from D2 after one spot check (the first shared segment re-run, every printed digit
    must match), **not re-run**.
- Stored per run column: mean, **SD** (within-segment STD), the §60.4 indices, p2 (θ, tilt clamp).
- The report prints the re-run INDI-DE against `H3-circle.mat` on every segment (|d|; a different value is reported,
  and the stored H3-circle numbers of §57 stay as recorded).
- Variant A (`six-circle`) is not run.

### 63.5 Figure 9 - trajectories of the six controllers of Table 5 on one dev segment (as Guo 2020 Fig. 10)
- **Controllers:** PID, DO, ESO, MOBADC, INDI-DE, PAW-MOBADC.
- **Segment rule (unchanged):**
  - candidates = segments of dev circle_main (`d2_p2.mat`) whose PA-MOBADC row is finite and whose tilt-clamp fraction
    `p2{3}.tilt_sat_frac` < 1 %;
  - U as `p2_segset`;
  - chosen = the candidate whose U is closest to the candidates' median U; ties → the smallest segment index (file name).
- **Re-run:** the six on that segment with the runner calls and `KeepTraj`.
  - The mean error of each must equal its stored row to **1e-12** (`guo_p2.mat`; `six-circle-h3.mat`), otherwise the
    figure is not saved.
  - Not run if `git status` reports a local change in `baseline1.slx`, `core/` or `experiments/` (§61.5).
- **Time series** saved to `results/gd11/traj_<segment>.mat`.
- **Drawing:** six x–y panels over t ≥ 140 s, the desired circle dashed, one common scale. Illustration only.

### 63.6 Commands and hours (user's machine; ≈ 28 s per controller call, nights 17–18)
1. Dry run: `run_p2_gd7('six-circle-h3', 'TauW', 0.280, 'TauPred', 0.290, 'H3Hz', 32, 'DryRun', true)`. One segment,
   the three columns run (no reuse in a dry run), nothing saved, ≈ 2 min.
2. Run: `run_p2_gd7('six-circle-h3', 'TauW', 0.280, 'TauPred', 0.290, 'H3Hz', 32, 'Sha', 'a227e9d87a2ac436')`,
   ≈ 2.1 h (2 × 134 runs + 1 spot check).
3. `make_p2_tables`, then `make_p2_figures` (figures 1–9; figure 3 ≈ 2 min, figure 9 ≈ 3 min).

### 63.7 Lists (extends §62.1 / §62.2)
- **Figures 1–9:** §62.1 items 1–8, plus 9 = trajectories (§63.5).
- **Tables 1–6:** §62.2 items 1–4, plus 5 = main comparison (§63.2) and 6 = ablation (§63.3).

## 64. Results of §63 (`run_p2_gd7('six-circle-h3', …)`, git `69c2c5d`, 2026-10-03, ≈ 2.0 h) - facts, descriptive
- **Dry run** (1 segment, i0000): PA-MOBADC 0.0140 (= D2 row 1), INDI-DE 0.0371 (= the §57 dry run), PAW-MOBADC 0.0083.
- **Run:** set circle_main SHA `a227e9d87a2ac436…` asserted, 134 segments / 42 days. Reuse D2 (PA-MOBADC) spot check on
  i0000: |d| 5.13e-8, printed digits equal → ON. INDI-DE re-run against `H3-circle.mat`: 134 shared, **max |d| 0**.
- **PAW-MOBADC stopped the solver on 1 of 134 dev segments:** `wind_expl_t150_i0290` -
  "Derivative of state '1' in block 'baseline1/UAV_Plant/Int_etadot' at time 81.7605 is not finite". On the same
  segment PA-MOBADC 0.0113 and INDI-DE 0.0370 ran to the end. **Correction (same day, before any use):** an earlier
  version of this line called it "the first failure of PAW-MOBADC on any set" - wrong. It **reproduces the known
  stop of §59.5** (static-circle on S40, same segment, solver stopped at 81.8 s); with N6_hover `i0326` (§59.3) these
  are the two dev segments where PAW-MOBADC stopped and PA-MOBADC ran, both **spiked segments** (§60.0), covered by
  LIMITATIONS G15 (spike filter). CONFIRM2: n_unsafe 0 on circle and hover (§61.2). Nothing new to diagnose. Every
  table built on these sets states the segment as left out (make_p2_tables, generated line).
- **Report (one set 133 of 134, 42 days):** pooled mean PA-MOBADC 0.01806 m, INDI-DE 0.03838 m (pooled STD 0.02762 m),
  PAW-MOBADC 0.01199 m (pooled STD 0.02631 m); h = 1 − PAW-MOBADC / PA-MOBADC = **+33.64 %** (SE 8.23, LOO
  [+32.99, +42.93], by-day median +36.76 %); PAW-MOBADC / INDI-DE − 1 = **−68.77 %** (SE 8.85, LOO [−77.29, −68.71],
  by-day median −78.88 %); most influential segment in both `wind_expl_t150_i0306` (PA-MOBADC 0.1223, INDI-DE 0.1282,
  PAW-MOBADC 0.0992). The pooled STD exceeds the pooled mean for both re-run columns because of the saturated segments
  (i0306 above), not reported as a reading.
- **Checks after the run:** make_results_p2 15/15 MATCH; make_p2_tables table 4 4/4 MATCH; figure 3 re-run |d| 0 in
  four columns.
- **Figure 9 (§63.5):** 121 of 134 candidates (PA-MOBADC tilt clamp < 1 %); median U 4.5418 m/s; chosen
  **`wind_expl_t150_i0385`** (U 4.5418). Re-run = stored row, |d| 0 for all six: PID 0.17321, DO 0.15619, ESO 0.07122,
  MOBADC 0.03737, INDI-DE 0.03705, PAW-MOBADC 0.00792 m. Time series in `results/gd11/traj_wind_expl_t150_i0385.mat`.

## 65. `verify_p2_repro` after the repository cleanup (2026-10-04, git `e25d2d2`, user's machine) - facts

`verify_p2_repro` (written in the cleanup to replace the v1 step-0 checks) first required |d| = 0 in all three parts.
User's run, each part in a fresh MATLAB session with `diary` (logs `E:\logA.txt`, `E:\logB.txt`, `E:\logC.txt`):

- `check_all` 7/7 PASS; `data_manifest --check` PASS (39 result files equal to `data/SHA256SUMS.txt`).
- (b) Figure 9 (`wind_expl_t150_i0385`, six controllers) and (c) Figure 3 (`wind_conf2_t150_i0069`, four
  controllers): re-run = stored, **|d| = 0** in every column.
- (a) D2 row 1 (`wind_real_t150_i0000`, stored in `results/gd6/d2_p2.mat`, night 2, §11): MOBADC |d| = 0;
  MOBADC-W 0.033370858633448 vs stored 0.033370962425437 (|d| 1.04e-7 m), PA-MOBADC 0.013952531746635 vs
  0.013952583035184 (5.13e-8 m), MOBADC-W + preview 0.013570057070334 vs 0.013570092868104 (3.58e-8 m). Largest
  relative difference 3.1e-6. Every value is unchanged to the printed digit (0.0414 / 0.0334 / 0.0140 / 0.0136).
- Reading: `d2_p2.mat` was written on 2026-09-25 by the build of that date. The model was rebuilt afterwards
  (N6 blocks 2026-09-27, §24-§25; (iii), trim and H3 2026-09-30, §40, §45, §47, §48, §50; LQI blocks removed
  2026-10-04); which rebuild moved the
  wind-fed columns at the 1e-7 m level is not determined. Every step 0 since §11 checked "D2 row 1 unchanged" **to the
  printed digit**, never bit for bit, so no earlier check was violated. The rows written after 2026-10-03
  (`gd10/`, `gd7/six-circle-h3.mat`) are reproduced bit for bit by the current build.
- Consequence for the paper: the dev D2 numbers (Tables 3, 4, 6, Figure 4, `RESULTS_P2`) come from `d2_p2.mat`;
  a difference of ≤ 1.04e-7 m changes no printed number (errors are printed to 4 decimals in m, ratios to 2 decimals
  in %). No re-run is made for this.
- Criterion from now on (code `verification/verify_p2_repro.m`): (a) unchanged to the printed digit (4 decimals),
  largest |d| printed; (b), (c) bit for bit.
- MATLAB R2022b crashed twice on the user's machine on 2026-10-04 (19:49, 20:46; Windows event 1000, exception
  0xc0000374 heap corruption in `ntdll.dll`) while figures were being drawn or `verify_p2_repro` ran; the three
  sessions above ran without a crash. Cause not determined; no result file was written by the crashed sessions
  (`data_manifest --check` PASS).

## 66. Which model produced each result; the two kinds of fingerprint (2026-10-04, user's machine) - facts

Requested by the user after group 2 (removal of the H4 code) was reverted on a fingerprint mismatch (git `c5b5c4b`).
Every check here is read only: `baseline1.slx` was not rebuilt to disk or saved (`git status` clean after each).

### 66.1 Fingerprints - a model just built and the same model loaded from its file differ

| how | model | fingerprint |
|---|---|---|
| built in memory, `build_p2_plant('Check', false)`, code before group 2 (check A, `c5b5c4b`) | current file | `c965867910b8eaf907b6adcbcc617b41252212fad6a9413027ee377e281849bd` |
| built in memory, same call, group-2 code (`17cbb27`) | current file | `c965867910b8eaf9…` |
| recorded when the 2026-09-30 model was built (§50) | `54a72f6`, MD5 `B27EA7C8FB6544E0CE68E8B765BAAAD3` | `c965867910b8eaf9…` |
| loaded from file, `model_fingerprint` (check B) | `54a72f6`, MD5 `B27EA7C8…` | `fae8c428ca30a1d540e6838ba4ca192674bb72fd7d6e47ac7ae3462e3f5eba3f` |
| loaded from file, `model_fingerprint` (check B) | `f4c88bc` (LQI blocks removed), MD5 `B80D8A78577742AE9364E47247359160` | `fae8c428ca30a1d5…` |
| loaded from file, `build_p2_plant('FingerprintOnly')` (group-2 code) | working copy (= `f4c88bc`) | `fae8c428ca30a1d5…` |

Reading: the same model gives `c965…` just after the build and `fae8…` once saved and loaded; which part of the
fingerprint changes on save / load is not determined. Removing the LQI blocks did not change the fingerprint
(`54a72f6` and `f4c88bc` loaded: equal). The mismatch that reverted group 2 compared a loaded model with a built one.
Compared like with like, the group-2 code builds what the code before it builds (both `c965…`). Under the user's
rule (B = `fae8…`) group 2 was applied again (`234af39`). `build_p2_plant` documents the two kinds.

### 66.2 Result files of the paper -> model (`verification/results_provenance.m`, `tools/model_at_commit.py`)

Each runner stores the git revision of its **last** save; the model is the `baseline1.slx` committed at or before that
revision (assumed to be the one on disk at run time). Fingerprints are those recorded at the build (built kind).

| model commit (date) | MD5 | fingerprint recorded | result files (`results/`) |
|---|---|---|---|
| `024f15a` (2026-09-25) | `E2AD6FA3…` | not recorded | `gd6/d2_p2` (night 2, `2bd5488`); rows of `gd6/n0p_p2` (`2bd5488`, `593f2ea`) |
| `912c6ce` (2026-09-26) | `7E618706…` | `b0cca7bd…` | `gd7/N4b-P2-{base,K10,L15,d200}`, `gd7/N5-{A-Weak,A-Medium,A-StrongRel,B-Medium,H-StrongRel}`; rows of `gd6/n0p_p2` (`3513ee7`) |
| `b936501` (2026-09-27, N6 blocks) | `61529E3D…` | `5ac8ad70…` | `gd6/guo_p2` (night 15), `gd6/tab_T3b_p2`, `gd6/tab_square_p2`, the eight `gd6/tab_circle_*_p2`; rows of `gd6/n0p_p2` (`28f421a`, `7cdd6d1`, `b756c3f`) |
| `54a72f6` (2026-09-30, (iii) / trim / H3) | `B27EA7C8…` | `c965867910b8…` | `gd6/guo_trim_p2`; `gd7/H3-{circle,hover}`, `gd7/iii-{circle,hover}`, `gd7/static-{circle,hover,hover-k}`, `gd7/six-circle-h3` (Tables 5, 6, Figure 9; written 2026-10-04 01:36); CONFIRM2 `gd10/{sets,D2,C2-circle,C2-hover,C2-hhover}` |
| `f4c88bc` (2026-10-04 13:58, LQI removed) | `B80D8A78…` | (loaded: `fae8…`) | none stored - only the re-runs of Figures 3 and 9 and `verify_p2_repro` (§65) |

Not read yet (CẦN KIỂM): `gd7/N5-B-Weak`, `gd7/N6`, `gd7/static-indi-bias` did not appear in the user's output.

- The final results (CONFIRM2, Tables 5 and 6, Figure 9, the static and H3 rows) ran on `B27EA7C8`, before the LQI
  blocks were removed. No stored result ran on the model after that change.
- The results of the earlier nights ran on three earlier builds; each rebuild was checked at its step 0 ("D2 row 1
  unchanged" to the printed digit, `verify_repro` v1 bit-exact; §9, §25, §51 with step 0 of §50.2).
- Across model versions, re-runs on `B80D8A78` equal the stored rows of `guo_p2` (`61529E3D`), `six-circle-h3` and
  `gd10` (`B27EA7C8`) bit for bit (Figures 3 and 9, §65); `d2_p2` (`E2AD6FA3`) differs by ≤ 1.04e-7 m (§65).
- `docs/SNAPSHOT.md` (model MD5 record of the v1 study) is not in this branch (tag `v1-final`); this table replaces it
  for P2.

### 66.3 MATLAB crashes

MATLAB R2022b crashed again (exception 0xc0000374, heap corruption) on 2026-10-04 at 21:56 (in-memory rebuild, 4th
compile check), once while only loading the model (`FingerprintOnly`), and twice in `verify_p2_repro` under
`matlab -batch`. A crash writes no result file (`data_manifest --check` PASS). `verify_p2_repro` on the current code
is still to be completed.

### 66.4 Group 2 checked on the user's machine; two more files (2026-10-04, git `db07eb2`)

- Group 2 (`234af39`) checked, each step in its own `matlab -batch` process (the full `verify_p2_repro` crashed twice
  in one process, §66.3): `check_all` 7 passed / 0 failed; `verify_p2_repro('Quick', true)` PASS (D2 row 1 to the
  printed digit); `make_p2_figures('Only', 3, 'Save', false)` re-run = stored, max |d| 0; `make_p2_figures('Only', 9,
  'Save', false)` re-run = stored, max |d| 0; every process exit code 0; `git status` clean (model not saved).
  Together these are the three parts of `verify_p2_repro`.
- Table 66.2, two of the three files not read: `gd7/N5-B-Weak` (written 2026-09-27 13:34, git `12c9578`) -> model
  `912c6ce`, `7E618706…`, `b0cca7bd…`; `gd7/static-indi-bias` (2026-10-03 07:21, `5e05c53`) -> `54a72f6`,
  `B27EA7C8…`, `c965867910b8…`. Still CẦN KIỂM: `gd7/N6` (no line in the user's output).

### 66.5 The last file (2026-10-04)

`gd7/N6` (written 2026-09-27 23:18, git `b936501`) -> model `b936501` (the N6 build itself), `61529E3D…`,
`5ac8ad70…`. Table 66.2 now covers all 39 result files of the paper; nothing is left CẦN KIỂM there.

## 67. Authorship (amendment, 2026-10-07) - facts

The header, §0.5 and §0.7 describe decisions as taken by the user as "sole author". That was
the authorship when they were written. From 2026-10-07 the IJDC submission has three authors - Huy Hoang Tran, Xuan
Bach Nguyen (corresponding author) and Xuan Hai Le (supervision); `paper/ijdc/title_page.tex`,
`docs/devlog/ADVISOR_NOTES.md` (entry 2026-10-07). Nothing registered changes: every claim, threshold and decision
above stands as written and dated.

## 68. Figures on the user's new machine, from the final run (2026-10-07) - decisions, then facts

Decisions of the user in chat, 2026-10-07: the figures are drawn on this machine and from the final run
(`results/final`, REGISTER_FINAL sec 8-9), and the re-simulated figures need not agree bit for bit with the stored
rows ("không cần khớp 100%, chạy trên máy tôi không sao cả; ở đây mới là final"). Written while the first re-run
(Figure 9) was in progress, before any figure of this section was saved.

- **Machine:** the user's new Windows machine, MATLAB R2024a + Simulink (the stored rows: R2022b, old machine and
  GitHub runners).
- **Figures 3 and 9** (`make_p2_figures`, option `Tol`): saved if every re-run column's mean error agrees with the
  stored row to 5e-5 m (half of the 0.1 mm printed in the figure) instead of 1e-12; every |d| is printed and copied
  below. The selection rules of sec 62.1 (3) and 63.5 are unchanged.
- **Figure 4, figure-eight and square rows:** the one set of the stored columns L0 L2 L3 V (the final run's TAB
  tables also carry the PAW columns; the like-for-like rule of `make_results_final`), so the figure shows the numbers
  of the paper's text and of RESULTS_FINAL "Reproduction" (figure-eight -45.41 %, square -24.80 %).
- **Held-out rows** (CONFIRM2, `gd10/`): not part of the final run (REGISTER_FINAL sec 6). They are drawn only from the
  stored CONFIRM2 files or from a reproduction that the user approves separately; nothing of CONFIRM2 is re-run under
  this section.
- No number of the paper changes: the text and tables keep RESULTS_P2 / RESULTS_FINAL / tables_p2.

### 68.1 A new figure set for the IJDC manuscript (decision of the user, 2026-10-07) - registered before drawing

The user asked for new figures that follow the argument of the paper, free of the figure list of sec 62.1: only what
bears on the claims; results that weaken a claim go to the Discussion; further runs are allowed. Figure 1 (system) is
kept unchanged. Every figure is descriptive and adds no claim; numbers of held-out rows are read from the generated
`docs/RESULTS_P2.md` / `paper/tables/tables_p2.md` (CONFIRM2 is not re-run), development rows from `results/final`.
Generator: `figures/p2/make_ijdc_figures.m`.

- **wind** - mean wind speed U and turbulence intensity per segment, development pool vs held-out days (as sec 62.1
  (2)); the circle (8.02 m/s) and hover (10.86 m/s) envelopes marked.
- **steps** - pooled error of MOBADC -> MOBADC-W -> PA-MOBADC (C1) -> PAW-MOBADC (C2): circle, development one set
  (133) and held-out one set (56); hover, PA-MOBADC -> PAW-MOBADC on the registered scoring set (PA-MOBADC below its
  tilt clamp: development 124, held-out 52 = the "unsat4" block, which is contained in it and has the same size).
  Beside it the registered claims D2, H-static, H-static-circle as error reductions (dev, held-out; +-1.65 SE; by-day
  median) with their thresholds (sec 60.3: D2 <= -15 %, H by-day median >= 10 %).
- **flight** - one circle segment (the rule of sec 63.5: `wind_expl_t150_i0385`) re-simulated with MOBADC-W, PA-MOBADC,
  PAW-MOBADC and INDI-DE, and one hover segment re-simulated with PA-MOBADC and PAW-MOBADC; hover rule fixed now: dev
  N6_hover segments with PA-MOBADC tilt clamp < 1 % in `gd7/static-hover.mat`, the one closest to their median U
  (ties: file name). Shown: the position error vector over t >= 140 s in the path frame (along-track, radial; circle)
  and in the horizontal inertial frame with the mean wind direction (circle and hover). Each re-run column's mean
  error is compared with the stored final-run row (`Tol` 5e-5 m, sec 68).
- **horizon** - (a) the lag term of eq. lag-err for one harmonic, 2|sin(sigma tau_d / 2)|, against the loop delay,
  sigma = 1.575 rad/s; (b) the registered N0P sweeps (`gd6/n0p_p2.mat`) of circle, figure-eight, square, multisine and
  hover, pooled error relative to tau = 0, with tau*.
- **wind-speed** - per-segment mean error against U on the dev circle (133; MOBADC-W, PA-MOBADC, PAW-MOBADC, INDI-DE)
  and the dev hover set (PA-MOBADC, PAW-MOBADC; segments at the tilt clamp marked).
- **robust** - h = 1 - PAW-MOBADC / PA-MOBADC (+-1.65 SE) for K-hat x 0.7 / 1 / 1.3 (circle S40, hover S40hover),
  sensor noise 0.1 m/s, trajectory (figure-eight, square), the eight m_p x L levels and the preview variant; values
  of RESULTS_P2 / RESULTS_FINAL (E1, E3, E4-E6).
- **oracle** - C3 headroom per registered group (as sec 62.1 (8)), with the 10 % threshold.
- **Discussion, measure** - hover: pooled error of INDI-DE with accelerometer bias 0 / 0.086 / 0.17 m/s^2 against
  PA-MOBADC and PAW-MOBADC, held-out one set (RESULTS_P2) and dev S40hover (`gd7/static-indi-bias.mat`).

### 68.2 Amendment to 68.1 - the forms of the figures (user, 2026-10-07) - and the facts of the re-runs

The user asked for the figure forms of the control literature instead of statistical forest plots and deviation
clouds. Same data and segments as sec 68.1, other forms (`make_ijdc_figures`):
- **compare** replaces *steps*: bars of the pooled error of MOBADC, MOBADC-W, PA-MOBADC, PAW-MOBADC and INDI-DE (circle,
  development one set 133 / held-out 56; INDI-DE from Table 5 and the held-out C2-circle block) and of PA-MOBADC,
  PAW-MOBADC in hover on the registered scoring set (124 / 52). The registered claims are not drawn; they are Table 4.
- **response** replaces *flight*: the same two segments (circle `wind_expl_t150_i0385`, hover `wind_expl_t150_i0086`)
  as time responses over t >= 140 s - wind speed; circle: tracking error along the path and outward; hover: east and
  north.
- **sensitivity** replaces *robust*: pooled error of PA-MOBADC and PAW-MOBADC against K-hat x 0.7 / 1 / 1.3 (one set of
  `gd7/static-circle-k.mat`, 39, and `gd7/static-hover-k.mat`, 42); bars of h with +-1.65 SE per trajectory (with the
  prediction / with the preview), per payload mass and cable length, and with / without sensor noise (RESULTS_FINAL
  E1, E4).
- **oracle**: bars instead of points.

Facts of the re-runs (MATLAB R2024a, the user's new machine, against the stored final-run rows):
- `make_p2_figures('Only', 9, 'Root', 'results/final', 'Tol', 5e-5)`: six columns on `wind_expl_t150_i0385`, max |d|
  1.16e-16 (PAW-MOBADC), the other five 0.
- `make_ijdc_figures` 'flight' / 'response' segments: circle MOBADC-W 0, PA-MOBADC 3.12e-17, PAW-MOBADC 1.16e-16,
  INDI-DE 0; hover (the rule of 68.1: 124 candidates, median U 4.752 m/s) PA-MOBADC 0, PAW-MOBADC 0. The new machine
  reproduces the final run to rounding; the looser `Tol` of sec 68 was not needed.
