# simulink_blocks/ — the code of the MATLAB Function blocks

Every `.m` file in this directory is the code of **one MATLAB Function block**
in `baseline1.slx`. File name = function name = the block holding it.

## Why this directory exists

The code that actually runs lives in `baseline1.slx`, a binary file. `git diff`
cannot read it, code review cannot see it, and nothing forces it to agree with
anything.

This directory makes that code readable and comparable. **It does not
synchronise itself** — see the Synchronisation gate below.

This directory was once referenced by `build/build_payload_pendulum.m` but had
never been committed, so `build/build_payload_pendulum.m` could not run and the
comment beside it claiming "a single source of truth" said the opposite of the
truth. The files here were extracted verbatim from `baseline1.slx` with:

    python3 tools/extract_eml.py baseline1.slx -o simulink_blocks

## The synchronisation gate

    sync_eml_blocks                      % CHECK only, change nothing
    sync_eml_blocks('Apply',  true)      % .m file -> model
    sync_eml_blocks('Export', true)      % model -> .m file

`run_baseline`, `run_test4_payload`, `run_test5_predictor` and `run_sanity_t2`
all call `sync_eml_blocks` in check mode before running, and **stop dead** if
the two copies differ. A number taken from a model that does not match the
source in git is a number nobody can reproduce.

`check_all` runs the same comparison as step 7, through the Python twin
`tools/extract_eml.py --check`, which needs no Simulink licence.

The workflow to follow: edit the **`.m` file** (so `git diff` can read it), then

    sync_eml_blocks('Apply', true); save_system('baseline1')

If you edited inside Simulink by accident, `sync_eml_blocks('Export', true)`
brings the change into git.

## Two comments point at a path that no longer exists — DELIBERATELY

`disturbance_generator.m` (line 28) and `payload_predictor.m` (line 57) read
<<<MARKER-QUOTE
`Xem docs/AUDIT.md muc A1` / `muc E`
MARKER-QUOTE>>>
— quoted here exactly as the frozen block holds it. That file now lives at
**`docs/devlog/AUDIT.md`**.

The old path is kept ON PURPOSE. Commit `e5326a8` rewrote these two lines to the
new path along with the rest of the repository, but `baseline1.slx` was never
resynchronised. Because `sync_eml_blocks` compares **verbatim, comments
included**, those two blocks reported a mismatch and `run_baseline`,
`run_test4_payload`, `run_test5_predictor` and `run_sanity_t2` all stopped —
blocking the reproduction path from 2026-09-12 until it was found.

There are two ways out, and the one chosen is the one that does NOT touch the
artefact:

- `sync_eml_blocks('Apply', true)` + `save_system` would fix the model. But the
  `.slx` is the artefact that produced every published number, and
  `docs/SNAPSHOT.md` holds its checksum. Changing one comment changes the MD5,
  and the binary in the repository is then no longer the binary that produced
  the results. That is not worth trading for a documentation path.
- Put the two `.m` lines back to exactly what the model holds. The files in this
  directory are a **readable copy** of the model; a copy has to be faithful,
  including when it faithfully repeats a stale path. This note is where the
  correction lives instead.

If the `.slx` ever has to be rebuilt for a REAL reason (an algorithm change, a
new block), fix these two lines in the same pass, update `docs/SNAPSHOT.md`, and
delete this section.

---

## The signal path of the slung payload

`build/build_payload_pendulum.m` uses this section. The pendulum is **already
present** in the committed `baseline1.slx`; this section is for understanding it
and for rebuilding it if that is ever needed.

The model routes with Goto/From at `TagVisibility = 'global'`. The payload
disturbance travels on the tag `d_mf`: a single Goto in `Disturbances`, two Froms
in `UAV_Plant` and `Logging_Metrics`. So nothing needs rewiring — only what
**feeds** that Goto changes.

    before:  Dist_Gen/1 ─────────────────────────────► G_d_mf  (tag d_mf)

    after:   Dist_Gen/1 ───────────────────► PL_Switch/3 ─────► G_d_mf
                                                  ▲  ▲
             Payload_Pendulum/1 ──────────────────┘  │
                     ▲                               │
             PL_Mem_a ┘                         PL_pm (payload_model)
                     ▲
             PL_Sel_xy (1:2)
                     ▲
             PL_F_nu_dot  ◄── PL_G_nu_dot in UAV_Plant, on Trans_4a/1

The `disturbance_generator` block **is not touched**. That is the strongest
guarantee available that `payload_model = 0` reproduces the baseline: not "a
similar formula" but the same block on the same path.

### Blocks in Disturbances

| Block | Type | Parameters |
|---|---|---|
| `PL_F_nu_dot` | From | `GotoTag = nu_dot`, global |
| `PL_Sel_xy` | Selector | `InputPortWidth = 3`, `Indices = [1 2]` |
| `PL_Mem_a` | Memory | `InitialCondition = [0;0]` |
| `PL_F_wp` | Constant | `[0;0]` (adds wind on the payload, stage 2.2) |
| `Payload_Pendulum` | Subsystem | 2 in / 2 out |
| `PL_pm` | Constant | `payload_model` |
| `PL_Switch` | Switch | `u2 >= Threshold`, `Threshold = 0.5` |
| `PL_dmf_log` | To Workspace | `dmf_log`, Structure With Time |
| `PL_theta_log` | To Workspace | `theta_log`, Structure With Time |

In `UAV_Plant`: `PL_G_nu_dot` (Goto, tag `nu_dot`, global) is tapped onto
`Trans_4a/1` without cutting the existing `Trans_4a/1 -> Int_nu` line.

### Inside Payload_Pendulum

    a_uav (In1)  F_wp (In2)
    PL_m_p PL_L PL_zeta PL_g PL_zon   (Constant, reading variables from the base workspace)

    pend_deriv(xp, a_uav, F_wp, m_p, L, zeta_p, g)  -> Int_xp -> xp
    pend_out  (xp, a_uav, m_p, L, g, payload_z_on)  -> d_mf_pend (Out1)
    Int_xp                                          -> xp        (Out2)

`Int_xp`: Integrator, `InitialCondition = [0;0;0;0]`.

### The algebraic loop

`d_mf` depends on the UAV acceleration through the `a*sin(theta)` term in the
tension, and the UAV acceleration in turn depends on `d_mf`. The `PL_Mem_a`
block breaks that loop: the pendulum sees the previous step's acceleration.

The price of that was measured by `python/verify_pendulum_block.py` (which runs
without MATLAB): **0.004%**, and dropping `FixedStep` to 0.5 ms changes it to
**0.003%**. The loop gain is `m_p*sin^2(th)/m` ~ 0.08 << 1, so the loop converges
quickly.

### Units and reference frames

- `a_uav` — **lateral acceleration, INERTIAL frame**, taken from `nu_dot(1:2)`.
  `translational_dynamics` gives `m*nu_dot = F - m*g*e3 + d_mf + d_lf`, so
  `nu_dot` is indeed inertial. No frame change on this path.
- `d_mf` — **a force, in N, INERTIAL frame**. Used as is: no division by mass, no
  frame change, no sign change.

---

## What the current blocks DO NOT implement

Recorded here so that nobody has to read the code backwards to find out:

- **`amp_tau` has no effect.** `disturbance_generator` takes it as an argument
  and then sets `d_ltau = zeros(3,1)`. The wind moment disturbance is exactly
  zero. `core/model_contract.m` stops a script outright if `amp_tau ~= 0`.
- **The wind direction is hardcoded** as `psi_w = 40*pi/180` inside
  `disturbance_generator`; it is not read from the workspace.
- **`payload_z_on = 0`** means the UAV never carries the payload's weight
  (4.9 N), and `m` in the plant does not include `m_p`. Keep that in mind before
  calling this a "physical" payload model. See `docs/devlog/AUDIT.md` section C1.
- **Two independent planar pendulums**, not a spherical one: `T_x` and `T_y` are
  computed separately and each axis carries the full `m_p*g`. This coincides with
  a linearised spherical pendulum at small angles; the measured RMS swing angle
  is 14.5 deg. See `docs/devlog/AUDIT.md` section C2.

---

## Plant P2 (GD2b) - `build/build_p2_plant.m`

Design: `docs/devlog/GD2B_DESIGN.md`. Two new MATLAB Function blocks live inside the
Variant Subsystem `P2/P2_Core` (choice `plant_model==1`): `p2_trans.m` (calls
`core/plant_p2_free.m`) and `p2_wind_force_hat.m`. `thrust_attitude_ref.m` takes
`F_TOT_MAX` as input 5 (Constant `F_TOT_MAX`, 21.6 in v1).

Between the commit that adds these files and the user's build + save of
`baseline1.slx`, `extract_eml --check` reports `thrust_attitude_ref` as DIFFER and the
two P2 files as EXTRA. That is the expected state until the model is rebuilt; after
`build_p2_plant('Save', true)` the check must report Match for all of them.
