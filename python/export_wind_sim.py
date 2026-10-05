#!/usr/bin/env python3
"""
export_wind_sim.py -- export a wind series (+ its prediction) to .mat for Simulink.

    python3 python/export_wind_sim.py --dataset dataset --wind-type 1 \\
            --index 0 --split test --ckpt w4_frozen_20hz_t150_train2345_s0 \\
            --out wind_sim_t150.mat

    # MEASURED M5 WIND - use this for every number about the predictor's value
    python3 python/export_wind_sim.py --real-dir <m5> --real-split dev \\
            --real-index 0 --ckpt w4_frozen_20hz_t150_train2345_s0 \\
            --out wind_real_t150.mat

===========================================================================
SYNTHETIC OR MEASURED - AND WHY IT DECIDES THE ANSWER
===========================================================================
On synthetic Dryden at tau = 150 ms, PI-MoE has a KNOWN NEGATIVE skill
(-0.046 at one seed, -0.0375 pooled at W4). On MEASURED wind at the same tau,
W5 measured +0.157. So any number about "how much the predictor helps" taken
from a synthetic series at short tau is measured in a regime already known to
be bad, and says nothing about PA-MOBADC.

--real-dir reads through exactly the pipeline score_real_wind.py uses:
list_files -> segments -> double rotation -> QC. The same dev/heldout split by
SHA-256 hash of the date, the same QC thresholds. So the skill printed here is
DIRECTLY comparable with the W5 table.

M5 holds 20 Hz records only, so --plant-fs 200 CANNOT be used with measured
wind; the faster-plant variant exists on synthetic alone.

===========================================================================
WHY PRECOMPUTE RATHER THAN PORT THE NETWORK TO MATLAB
===========================================================================
PI-MoE has 21163 learnable parameters plus a bank of (3,26,150) = 11700
numbers, with dilated convolutions, GELU and softmax. Porting that into a
MATLAB Function block with %#codegen is days of work across a very wide
surface of silent errors - next to payload_predictor.m, which is a handful of
identical trigonometric operations.

And it is unnecessary. WIND IS EXOGENOUS: the quadrotor does not change the
wind on its own, so w_hat(t+tau) is a PURE function of w[<= t], independent of
the control loop. Precomputing it and feeding it through From Workspace is
MATHEMATICALLY IDENTICAL to running it online.

Causality was checked by measurement, not by reading the code: corrupt the
ENTIRE future after t and the prediction at t moves by EXACTLY 0; corrupt
sample t itself and it moves by 1.4e-3 (the second test rules out a one-step
offset - the error that actually happened in window_batch).

Note that the wind->force map is NOT here. It lives in Simulink, because with
nonlinear drag it needs v_uav at that instant. See wind_to_force.m.

===========================================================================
TIME ALIGNMENT - THE EASIEST THING TO GET WRONG
===========================================================================
A prediction made AT t is about the instant t+tau. The controller at time t
uses it to compensate its own lag, exactly as payload_predictor does. So the
exported series is indexed by the instant the prediction IS AVAILABLE (t), not
by the instant it SPEAKS ABOUT (t+tau).

Both time bases are exported, and so is a check: if tau is misaligned here the
W7 results still print perfectly and are still wrong.

===========================================================================
SAMPLE RATE: PLANT AND PREDICTOR MUST SEE THE SAME SIGNAL
===========================================================================
The predictor reads wind at 20 Hz. Drive the plant with a 200 Hz record and
there is content the predictor STRUCTURALLY cannot see, so the error the
controller meets is larger than the error W5 measured - which means W5's skill
no longer describes the quantity in play.

So both are exported at 20 Hz by default. --plant-fs 200 makes a "more
realistic" variant, and results from it must be reported separately.
"""

import argparse
import hashlib
import json
import pathlib
import sys
from datetime import datetime, timezone

import numpy as np
import torch
from scipy.io import savemat

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from alpha_report import load_model                            # noqa: E402
from train_moe import predict_runs                             # noqa: E402
from wind.loader import load_group                             # noqa: E402
from wind.real_loader import (  # noqa: E402
    DEFAULT_HEIGHTS, day_of, SONIC_FS, list_files, log_heldout, segments,
)
from wind.task import horizon_steps, valid_range               # noqa: E402


# =========================================================================
def load_real_segments(a, fs):
    """The MEASURED M5 segments, double-rotated and through QC.

    ======================================================================
    WHICH SEGMENT - FIXED IN ADVANCE, NEVER CHOSEN BY THE RESULT
    ======================================================================
    segments() returns segments in a DETERMINISTIC order: sorted files, then
    height, then offset. --real-index indexes into that, default 0.

    Choosing an index because its number came out nicer is cherry-picking, and
    the paper's number would then mean nothing. So this function PRINTS the
    total and repeats that the paper's number must be POOLED over every index,
    not taken from one.

    ======================================================================
    M5 IS 20 Hz ONLY
    ======================================================================
    The source is .../M5Twr/20Hz/mat/. There is no faster record, so the
    --plant-fs 200 variant DOES NOT EXIST for measured wind. Anywhere it is
    needed, it must be reported as measured on SYNTHETIC.
    """
    if abs(fs - SONIC_FS) > 1e-9:
        raise SystemExit(
            f"measured M5 wind is {SONIC_FS:.0f} Hz, the checkpoint reads {fs:.0f} Hz.\n"
            "Pick a 20 Hz checkpoint (W5 uses w4_frozen_20hz_*).")
    if a.plant_fs and abs(a.plant_fs - fs) > 1e-9:
        raise SystemExit(
            "--plant-fs cannot be used with measured wind: M5 holds "
            f"{SONIC_FS:.0f} Hz records only.\nThe faster-plant variant exists on "
            "synthetic alone, and must be reported as such.")

    paths = list_files(a.real_dir, a.real_split)
    if not paths:
        # say WHAT was found, so the next diagnosis takes one run, not two (2026-09-25)
        d = pathlib.Path(a.real_dir)
        allm = sorted(d.glob("*.mat")) if d.is_dir() else []
        m5 = list_files(a.real_dir, "all") if d.is_dir() else []
        by = {s: len(list_files(a.real_dir, s)) for s in ("dev", "heldout")} if d.is_dir() else {}
        raise SystemExit(
            f"no M5 file at split={a.real_split} in {a.real_dir}.\n"
            f"  directory exists: {d.is_dir()} (resolved: {d.resolve()})\n"
            f"  *.mat files: {len(allm)}, of which M5-named: {len(m5)}, per split: {by}\n"
            f"  first *.mat names: {[q.name for q in allm[:3]]}\n"
            "See W5_REALWIND section 12: run plan_real_download.py --all-days.")

    # FILTER BY MANIFEST. An independent confirmation set has to be drawn from
    # DAYS never used before. Without this filter pick_indices still draws from
    # all 54 heldout days, 22 of which HAD already been scored on 2026-09-05 -
    # and the exported files would look exactly like an unseen set. Nothing else
    # would report an error.
    if a.only_days:
        man = json.loads(pathlib.Path(a.only_days).read_text())
        keep = set(man["days"])
        before = len(paths)
        paths = [p for p in paths if day_of(p) in keep]
        if not paths:
            raise SystemExit(
                f"manifest {a.only_days} lists {len(keep)} days but none matches "
                f"any of the {before} files at split={a.real_split}.")
        got = sorted({day_of(p) for p in paths})
        print(f"  manifest {a.only_days}: kept {len(paths)}/{before} files "
              f"from {len(got)} days")
        # The file-list hash must match the one in the manifest. If the
        # directory has changed - more downloaded, some deleted - the set is no
        # longer the set that was fixed.
        h = hashlib.sha256("\n".join(sorted(p.name for p in paths)).encode())
        if h.hexdigest() != man["sha256_files"]:
            raise SystemExit(
                f"HASH DOES NOT MATCH the manifest.\n  manifest {man['sha256_files']}\n"
                f"  directory {h.hexdigest()}\n"
                "The directory changed after the manifest was fixed. This is no "
                "longer the locked set - do not export.")
        print(f"  file-list hash matches the manifest ({man['sha256_files'][:16]}...)")
    heights = tuple(int(x) for x in a.real_height.split(","))
    runs, meta = segments(paths, heights, dur_s=a.real_dur, fs=fs)
    if not runs:
        raise SystemExit(f"{len(paths)} files but 0 segments passed QC.")
    print(f"  {len(paths)} files -> {len(runs)} segments through QC")
    return runs, meta


def pick_indices(meta, k):
    """k indices, BALANCED across height and even in time. Fully deterministic.

    ======================================================================
    WHY NOT A STRIDE
    ======================================================================
    segments() orders by file -> height -> offset, so the number of segments
    per file is very nearly constant (heights x offsets). Taking every Nth entry
    of that list is easy to ALIAS: if N divides the per-file count, every pick
    lands at the SAME height and the SAME offset. The table would look like 40
    independent samples while being 40 repeats of one condition.

    So split by height first, then take evenly in time within each height. No
    result is looked at - only the segment's own schedule.
    """
    by_h = {}
    for i, m in enumerate(meta):
        by_h.setdefault(int(m["height"]), []).append(i)
    hs = sorted(by_h)
    per = max(1, k // len(hs))
    out = []
    for h in hs:
        idx = by_h[h]
        if len(idx) <= per:
            out += idx
        else:
            step = len(idx) / per
            out += [idx[int(j * step)] for j in range(per)]
    return sorted(set(out))


def describe(m):
    return (f"{pathlib.Path(m['file']).name}  z = {m['height']:3d} m  "
            f"+{m['offset_s']:4.0f} s   U = {m['U']:5.2f} m/s  "
            f"I = {100 * m['I']:4.1f}%")


SPIKE_MAX_HOLD = 2


def spike_hold(w, thr, max_hold=SPIKE_MAX_HOLD):
    """Causal spike rejection: hold the last accepted sample while the horizontal step to it exceeds
    thr, at most max_hold samples in a row. Returns (filtered copy, number of held samples)."""
    out = np.array(w, dtype=np.float64, copy=True)
    held, n_held = 0, 0
    for k in range(1, len(out)):
        if np.hypot(*(out[k, :2] - out[k - 1, :2])) > thr and held < max_hold:
            out[k] = out[k - 1]
            held += 1
            n_held += 1
        else:
            held = 0
    return out, n_held


def out_name(out_path, i):
    p = pathlib.Path(out_path)
    return str(p.with_name(f"{p.stem}_i{i:04d}{p.suffix}"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default="dataset")
    ap.add_argument("--wind-type", type=int, default=None,
                    help="synthetic wind type. Ignored with --real-dir.")
    ap.add_argument("--split", default="test")
    # ---- MEASURED M5 wind ----
    ap.add_argument("--real-dir",
                    help="directory of M5 .mat files. Setting this exports "
                         "MEASURED wind instead of synthetic, and "
                         "--wind-type/--split/--index no longer apply.")
    ap.add_argument("--only-days", default=None,
                    help="CONFIRM_MANIFEST.json. Keep only files whose day is "
                         "in the manifest, and check the file-list hash. "
                         "REQUIRED for an independent confirmation set - see "
                         "the docs, section 0.49.")
    ap.add_argument("--real-split", default="dev", choices=("dev", "heldout"),
                    help="dev IS THE DEFAULT, deliberately. heldout writes to "
                         "the heldout_scoring.log ledger.")
    ap.add_argument("--real-index", type=int, default=0,
                    help="index into the DETERMINISTIC list segments() returns")
    ap.add_argument("--real-max", type=int, default=None,
                    help="export MANY segments: about this many, balanced "
                         "across height (see pick_indices). --out becomes a "
                         "pattern: <name>_i0000.mat. Use this for the paper's "
                         "numbers.")
    ap.add_argument("--real-height", default=",".join(map(str, DEFAULT_HEIGHTS)))
    ap.add_argument("--real-dur", type=float, default=200.0,
                    help="segment length [s]. 200 matches one synthetic run and "
                         "matches Simulink's StopTime.")
    ap.add_argument("--index", type=int, default=0,
                    help="which run within the group (NOT a seed)")
    ap.add_argument("--ckpt", help="checkpoint stem. Omit -> export the wind "
                                   "only, with no prediction.")
    ap.add_argument("--stride", type=int, default=1,
                    help="1 = every 20 Hz sample. Changing it means the hold "
                         "rate no longer matches.")
    ap.add_argument("--plant-fs", type=float, default=None,
                    help="sample rate of the wind series fed to the PLANT. "
                         "Default = the predictor's fs. Setting 200 is the "
                         "'more realistic' variant and MUST be reported "
                         "separately.")
    ap.add_argument("--mean-dir-deg", type=float, default=None,
                    help="ROTATE the mean wind to this bearing. Default is NO "
                         "rotation - see the note on rotation costing skill "
                         "below. Set it only when a figure genuinely has to "
                         "match a bearing.")
    ap.add_argument("--sensor-noise", type=float, default=0.0,
                    help="E1b: white noise on the MEASUREMENT of the wind "
                         "[m/s RMS per axis]. Added BEFORE the model sees it, "
                         "so PI-MoE and the sensor branch eat the same dirty "
                         "series. The wind acting on the UAV (w_plant) stays "
                         "CLEAN. 0 = as before, not one bit changes.")
    ap.add_argument("--sensor-bias", type=float, default=0.0,
                    help="E1b: a CONSTANT offset on the wind measurement [m/s "
                         "per axis]. A bias passes straight through any "
                         "predictor - use it to measure, not to compare.")
    ap.add_argument("--sensor-seed", type=int, default=20240601,
                    help="sensor-noise seed. Each segment derives its own seed "
                         "from this one.")
    ap.add_argument("--meas-spike-hold", type=float, default=0.0,
                    help="rerun/: causal spike filter on the wind MEASUREMENT - hold the last accepted "
                         "sample when the horizontal step exceeds this [m/s] (at most 2 samples in a "
                         "row). w_plant is untouched. 0 = off, not one bit changes.")
    ap.add_argument("--only-index", default=None,
                    help="REGISTER_P2 sec 43 (wind-sensor-noise sensitivity): export ONLY these "
                         "segment indices (comma list, positions in the deterministic "
                         "segments() list, i.e. the iNNNN of the existing files). Default: off.")
    ap.add_argument("--check-against", default=None,
                    help="REGISTER_P2 sec 43: directory holding the ORIGINAL export. Before "
                         "writing, each segment's w_true / w_plant / real_file / "
                         "real_offset_s must equal the original file of the same name "
                         "bit for bit, otherwise nothing is written and the run stops.")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    # ---- read the configuration FROM the checkpoint, never by hand ----
    if a.ckpt:
        model, S = load_model(a.ckpt)
        fs, tau, window_s = S["fs"], S["tau_ms"], S["window_s"]
    else:
        model, S, fs, tau, window_s = None, None, 20.0, 0, 30.0
    W = int(round(window_s * fs))

    print("=" * 74)
    if a.real_dir:
        print(f"EXPORT MEASURED M5 WIND FOR SIMULINK - {a.real_split}")
        print("=" * 74)
        if a.real_split == "heldout":
            k, p = log_heldout(a.real_dir, sys.argv, {
                "ckpt": a.ckpt, "index": a.real_index, "max": a.real_max,
                "dur": a.real_dur, "height": a.real_height,
                "mode": "export_wind_sim"})
            print(f"  ! LOCKED SET. This is USE number {k} - recorded in {p}")
            print("  ! Use heldout only for the paper's FINAL number. Every "
                  "diagnostic and every\n  ! round of tuning belongs on dev.")
        runs, meta = load_real_segments(a, fs)

        if a.only_index:
            # sec 43: a registered subset (S40 / S40hover) re-exported with a dirty sensor,
            # into its own directory; the clean files are never touched.
            sel = [int(x) for x in a.only_index.split(",") if x.strip()]
            bad = [i for i in sel if not 0 <= i < len(runs)]
            if bad:
                raise SystemExit(f"--only-index outside 0..{len(runs) - 1}: {bad}")
            if pathlib.Path(a.out).resolve().parent == pathlib.Path(".").resolve() \
                    or not a.check_against:
                raise SystemExit("--only-index needs --check-against and an --out in "
                                 "its own directory (never over the clean export).")
            print(f"  --only-index: {len(sel)} registered segments (REGISTER_P2 sec 43)")
            for i in sel:
                mt = {"src": "real_m5", "wtype": 0, "split": a.real_split,
                      "index": i, "seed": 0, "rmeta": meta[i],
                      "n_seg": len(runs)}
                print(f"\n--- #{i} ---")
                export_one(a, runs[i].astype(np.float64), fs, tau, window_s,
                           W, model, S, mt, out_name(a.out, i))
            outs = sorted(pathlib.Path(out_name(a.out, i)).name for i in sel)
            man = pathlib.Path(a.out).with_name(
                pathlib.Path(a.out).stem + "_batch.json")
            man.write_text(json.dumps({
                "created_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "split": a.real_split, "n": len(sel), "only_index": sel,
                "sensor_noise": a.sensor_noise, "sensor_seed": a.sensor_seed,
                "checked_against": a.check_against,
                "heights": a.real_height, "dur_s": a.real_dur,
                "ckpt": a.ckpt, "files": outs,
            }, indent=2))
            print(f"\nExported {len(sel)} files; every w_true/w_plant equal to "
                  f"{a.check_against} bit for bit. Manifest: {man.name}")
            return

        if a.real_max:
            sel = pick_indices(meta, a.real_max)
            print(f"  selected {len(sel)} segments, BALANCED across height "
                  f"(see pick_indices):")
            for i in sel:
                print(f"    #{i:5d}  {describe(meta[i])}")
            print(f"  ! This is a PREDETERMINED sample of {len(runs)} segments. "
                  "The paper's number is\n  ! POOLED over the whole sample, not "
                  "the best number in it.")
            for i in sel:
                mt = {"src": "real_m5", "wtype": 0, "split": a.real_split,
                      "index": i, "seed": 0, "rmeta": meta[i],
                      "n_seg": len(runs)}
                print(f"\n--- #{i} ---")
                export_one(a, runs[i].astype(np.float64), fs, tau, window_s,
                           W, model, S, mt, out_name(a.out, i))
            # A MANIFEST OF THIS BATCH, and a warning about LEFTOVER files.
            #
            # Re-exporting with a different segment selection does NOT delete the
            # old files: the index in the name comes from a position in the
            # segment set, and that set moves when QC moves. It has happened: the
            # export after dropping z = 41 m overwrote exactly 3 of 30 files and
            # left 27 OLD ones on disk - and
            # sweep_pa_grid('wind_real_t150_i*.mat') would pick up all 57,
            # mixing data from a broken sensor into the result table with
            # nothing to report it.
            outs = sorted(pathlib.Path(out_name(a.out, i)).name for i in sel)
            man = pathlib.Path(a.out).with_name(
                pathlib.Path(a.out).stem + "_batch.json")
            man.write_text(json.dumps({
                "created_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "split": a.real_split, "n": len(sel),
                "heights": a.real_height, "dur_s": a.real_dur,
                "ckpt": a.ckpt, "files": outs,
            }, indent=2))
            print(f"\nExported {len(sel)} files matching {out_name(a.out, 0)}")
            print(f"  Batch manifest: {man.name}")

            d = pathlib.Path(a.out).parent
            stem = pathlib.Path(a.out).stem
            here = {q.name for q in d.glob(f"{stem}_i*.mat")}
            stale = sorted(here - set(outs))
            if stale:
                print(f"\n  {'!' * 66}")
                print(f"  ! {len(stale)} LEFTOVER FILES, not part of this batch.")
                print("  ! They MATCH the same glob, so every sweep will pick up")
                print("  ! both them and the new files - mixing two exports into")
                print("  ! one table. DELETE them before running anything:")
                for q in stale:
                    print(f"  !     {q}")
                print(f"  {'!' * 66}")
            else:
                print("  No leftover files.")
            print("  Next step: sweep_wind_channel in MATLAB.")
            return

        if not (0 <= a.real_index < len(runs)):
            raise SystemExit(f"--real-index {a.real_index} is outside "
                             f"0..{len(runs) - 1}")
        print(f"  taking #{a.real_index}: {describe(meta[a.real_index])}")
        print(f"  ! ONE segment out of {len(runs)} is ONE SAMPLE, not a result."
              "\n  ! Use --real-max to take a balanced sample.")
        mt = {"src": "real_m5", "wtype": 0, "split": a.real_split,
              "index": a.real_index, "seed": 0, "rmeta": meta[a.real_index],
              "n_seg": len(runs)}
        w = runs[a.real_index].astype(np.float64)
    else:
        if a.wind_type is None:
            raise SystemExit("need --wind-type (synthetic) or --real-dir "
                             "(measured M5 wind)")
        if a.real_max:
            raise SystemExit("--real-max applies only with --real-dir.")
        g = load_group(a.dataset, a.wind_type, a.split, fs=fs)
        if not (0 <= a.index < g["w"].shape[0]):
            raise SystemExit(
                f"--index {a.index} is outside 0..{g['w'].shape[0]-1}")
        w = g["w"][a.index].astype(np.float64)      # (n,3) at fs
        seed = int(g["seeds"][a.index])
        mt = {"src": "synthetic", "wtype": a.wind_type, "split": a.split,
              "index": a.index, "seed": seed, "rmeta": None, "n_seg": 0}
        print(f"EXPORT WIND SERIES FOR SIMULINK - type {a.wind_type} "
              f"{a.split} #{a.index} (seed {seed})")
        print("=" * 74)
    export_one(a, w, fs, tau, window_s, W, model, S, mt, a.out)

def export_one(a, w, fs, tau, window_s, W, model, S, mt, out_path):
    """Export ONE segment. Split out of main so that the multi-segment loop
    reads the M5 data ONCE - segments() has to reopen every file, so calling
    the script 40 times means reading everything 40 times.

    mt: dict carrying src/wtype/split/index/seed/rmeta/n_seg for this segment.
    """
    n = len(w)
    src, wtype, split, index = mt["src"], mt["wtype"], mt["split"], mt["index"]
    seed, rmeta, n_seg = mt["seed"], mt["rmeta"], mt["n_seg"]

    # ---- wind bearing: NO ROTATION BY DEFAULT ----
    #
    # The first version rotated the mean wind to 40 deg to match the psi_w
    # hardcoded in disturbance_generator. Measured, that turned out to be a NET
    # LOSS:
    #
    #   6 Dryden runs, tau = 150 ms, bank CEILING (no training needed):
    #     unrotated  +0.0277  ->  rotated to 40 deg  +0.0253   delta -0.0024
    #     negative in 5 of 6 runs
    #
    # The reason: generators.py builds the turbulence in a WIND-ALIGNED frame -
    # axis 0 along-wind with L_u, axes 1/2 crosswind with L_u/2 - and
    # moe.AXIS_L_SCALE = (1, 0.5, 0.5) encodes exactly that assumption. But the
    # mean field is multiplied by _dir_vec(mean_dir_deg) with
    # mean_dir_deg = rng.uniform(0, 360), RANDOM per run. So rotating to line
    # the MEAN up with 40 deg rotates the turbulence OFF its own anisotropy
    # axis.
    #
    # And the rotation buys nothing: on a circular trajectory with isotropic
    # gains, tracking error does not depend on the bearing of a constant force.
    # run_baseline records that in a DIRECTIONLESS formula of its own:
    # e_wind = wind_amp/(m*Ky).
    #
    # So the data's own bearing is kept by default. --mean-dir-deg remains for
    # when a figure genuinely has to match, and its use must then be reported.
    if a.mean_dir_deg is None:
        w_rot = w
        m_xy = w[:, :2].mean(0)
        dir_deg = float(np.rad2deg(np.arctan2(m_xy[1], m_xy[0])) % 360.0)
        # Measured wind has been double-rotated, so the mean lies EXACTLY on
        # the x axis - the angle is 0 +- machine error. When that error is
        # negative, "% 360" yields 359.9999..., and verify_wind_force compares
        # it against atan2d (which returns (-180, 180]) and is off by exactly
        # 360 deg. Not a physical fault, but the check would report FAIL.
        if dir_deg > 360.0 - 1e-6:
            dir_deg = 0.0
        c, s = 1.0, 0.0
        print(f"  mean wind bearing {dir_deg:.1f} deg - KEPT, not rotated")
    else:
        m_xy = w[:, :2].mean(0)
        psi0 = np.arctan2(m_xy[1], m_xy[0])
        dpsi = np.deg2rad(a.mean_dir_deg) - psi0
        c, s = np.cos(dpsi), np.sin(dpsi)
        w_rot = w.copy()
        w_rot[:, 0] = c * w[:, 0] - s * w[:, 1]
        w_rot[:, 1] = s * w[:, 0] + c * w[:, 1]
        m2 = w_rot[:, :2].mean(0)
        err = abs(np.rad2deg(np.arctan2(m2[1], m2[0])) - a.mean_dir_deg)
        dn = np.abs((w_rot ** 2).sum(1) - (w ** 2).sum(1)).max()
        print(f"  ROTATED the mean wind {np.rad2deg(psi0):+.1f} -> "
              f"{a.mean_dir_deg:+.1f} deg (error {err:.2e}, norm {dn:.2e})")
        print("  ! Rotation COSTS skill on the synthetic set (measured -0.0024 "
              "at the ceiling, tau=150). It must be reported.")
        if a.real_dir:
            print("  !! MEASURED WIND: the double rotation already put the mean "
                  "at (U,0,0), so channel 0\n  !! IS the along-wind component - "
                  "exactly what AXIS_L_SCALE = (1, 0.5, 0.5)\n  !! assumes. "
                  "Rotating again here MIXES channel 0 with channel 1 and breaks "
                  "that\n  !! assumption. Do not, unless a figure genuinely has "
                  "to match, and report it.")
        assert err < 1e-9 and dn < 1e-9, "the rotation is wrong"
        dir_deg = a.mean_dir_deg

    # ---- the MEASURED wind: w_meas = w_true + sensor noise ----
    #
    # E1b. Sections 0.41-0.42 put sensor noise on the sensor branch ONLY, while
    # PI-MoE still ate CLEAN wind. That asymmetry favours PI-MoE, so the test
    # could conclude in one direction only - and the number it produced (a
    # crossing at 0.31 m/s) landed squarely in the region where PI-MoE wins,
    # i.e. it concluded NOTHING.
    #
    # Here the noise is added BEFORE the model sees anything. Both branches eat
    # the SAME realisation:
    #
    #     w_true --+--> (+ noise) --> w_meas --+--> PI-MoE --> w_hat
    #              |                            |
    #              |                            +--> sensor branch (MATLAB)
    #              |
    #              +--> w_plant  (the REAL wind on the UAV - NOT corrupted)
    #
    # w_plant stays CLEAN: the wind itself is real and nobody can dirty it. Only
    # what we MEASURE is dirty.
    #
    # w_meas is exported too, so MATLAB uses THIS realisation instead of drawing
    # its own - two independent realisations at the same sigma are still
    # comparable statistically, but one shared realisation removes a source of
    # variance that need not be there.
    #
    # OUT OF DISTRIBUTION, and said in advance rather than afterwards: PI-MoE
    # was frozen on CLEAN wind. Feeding it dirty wind puts the input outside the
    # training distribution. That is a genuine limitation. It is also exactly
    # the deployment situation - a frozen model has to read whatever sensor it
    # is given - and it does NOT break the freeze: nothing is retrained, only
    # the input at inference time changes.
    w_in = w_rot
    if a.sensor_noise > 0 or a.sensor_bias != 0:
        # Seeded PER SEGMENT: one shared seed for every segment would correlate
        # the realisations and make the pooled number agree artificially.
        # `index` is already unique and stable per segment, so it is enough.
        #
        # DO NOT also derive it from the filename: out_path is a STRING
        # (out_name() returns str), not a pathlib.Path, so .name does not exist.
        # The error fires only when sensor_noise > 0, so the s000 level would
        # pass and only the two later levels would crash.
        #
        # The seed NOT depending on sigma is DELIBERATE: every noise level uses
        # the same standardised draw, scaled. So the difference between levels
        # is the noise AMPLITUDE and not a change of realisation mixed in with
        # it - one less source of variance, in the "same realisation" spirit of
        # E1b.
        rs = np.random.default_rng(a.sensor_seed + 1000003 * int(index or 0))
        e = a.sensor_noise * rs.standard_normal(w_rot.shape) + a.sensor_bias
        w_in = w_rot + e
        print(f"  DIRTY SENSOR: sigma = {a.sensor_noise:.3f} m/s, "
              f"bias = {a.sensor_bias:.3f} m/s")
        print(f"    realised noise RMS (per axis) = "
              f"{np.sqrt((( e - e.mean(0))**2).sum(1).mean()/3):.4f} m/s")
        print("    ! PI-MoE AND the sensor branch both eat this series - a fair "
              "comparison.")
        print("    ! The input is OUTSIDE the training distribution (the model "
              "was frozen on clean wind).")

    # ---- optional causal spike filter on the MEASUREMENT (rerun/, 2026-10-05; default off) ----
    # A sample whose horizontal step from the last accepted value exceeds the threshold is
    # replaced by that value, at most SPIKE_MAX_HOLD samples in a row (a real step is then
    # accepted). Threshold 5 m/s = the spike definition of P-QA (REGISTER_P2 sec 36). Only what
    # the controller (and PI-MoE) reads changes; w_plant, the wind on the UAV, does not.
    n_held = None
    if a.meas_spike_hold > 0:
        w_in, n_held = spike_hold(w_in, a.meas_spike_hold)
        print(f"  SPIKE FILTER on w_meas: threshold {a.meas_spike_hold:.2f} m/s, "
              f"{n_held} sample(s) held")

    t = np.arange(n) / fs
    out = {"t": t[:, None], "w_true": w_rot, "fs": fs,
           "w_meas": w_in,
           "sensor_noise": float(a.sensor_noise),
           "sensor_bias": float(a.sensor_bias),
           "source": src, "wind_type": wtype, "split": split, "index": index,
           "seed": seed, "mean_dir_deg": dir_deg,
           "rotated": a.mean_dir_deg is not None,
           "duration_s": n / fs}
    if n_held is not None:                     # only when the filter is on: default files unchanged
        out |= {"meas_spike_hold": float(a.meas_spike_hold), "meas_spike_n": float(n_held)}
    if rmeta is not None:
        # Enough recorded to rebuild exactly this segment without relying on
        # anything remembered outside the file.
        out |= {"real_file": pathlib.Path(rmeta["file"]).name,
                "real_t0": rmeta["t0"], "real_height_m": rmeta["height"],
                "real_offset_s": rmeta["offset_s"],
                "real_yaw_deg": rmeta["yaw_deg"],
                "real_pitch_deg": rmeta["pitch_deg"],
                "real_U": rmeta["U"], "real_I": rmeta["I"],
                "real_sigma": np.asarray(rmeta["sigma"], float)[None, :],
                "real_n_segments": n_seg}

    # ---- the series fed to the plant ----
    if a.plant_fs and abs(a.plant_fs - fs) > 1e-9:
        gp = load_group(a.dataset, a.wind_type, a.split, fs=a.plant_fs)
        wp = gp["w"][a.index].astype(np.float64)
        wp_rot = wp.copy()
        wp_rot[:, 0] = c * wp[:, 0] - s * wp[:, 1]
        wp_rot[:, 1] = s * wp[:, 0] + c * wp[:, 1]
        out["t_plant"] = (np.arange(len(wp)) / a.plant_fs)[:, None]
        out["w_plant"] = wp_rot
        out["plant_fs"] = a.plant_fs
        print(f"  PLANT runs at {a.plant_fs:.0f} Hz - a VARIANT, report it "
              f"separately (the predictor only sees {fs:.0f} Hz)")
    else:
        out["t_plant"] = t[:, None]
        out["w_plant"] = w_rot
        out["plant_fs"] = fs

    # ---- prediction ----
    if model is not None:
        k = horizon_steps(tau, fs)
        # The model eats w_in (= w_rot when there is no sensor noise).
        pr = predict_runs(model, [w_in], tau, W, a.stride, fs=fs)
        yhat, idx = pr[0]
        t_avail = idx / fs                    # when the prediction IS AVAILABLE
        t_target = (idx + k) / fs             # the instant it SPEAKS ABOUT
        i0, i1 = valid_range(n, tau, fs)

        # The time-alignment check. A tau offset here still prints a perfectly
        # normal W7 result and is still wrong, so it is checked by an identity
        # rather than by eye.
        assert np.allclose(t_target - t_avail, tau * 1e-3), "time alignment is wrong"
        assert idx[0] == i0, f"prediction starts at {idx[0]}, expected {i0}"

        out |= {"t_pred": t_avail[:, None],      # indexed by WHEN IT IS AVAILABLE
                "t_pred_target": t_target[:, None],
                "w_hat": yhat, "tau_ms": tau, "window_s": window_s,
                "ckpt": a.ckpt, "train_types": S["train_types"],
                "tc_grid": S["tc_grid"], "stride": a.stride,
                "t_valid_from": float(t_avail[0])}
        print(f"  prediction: tau = {tau} ms, window = {window_s:.0f} s")
        print(f"    available from t = {t_avail[0]:.1f} s (to {t_avail[-1]:.1f} s)"
              f", {len(idx)} samples")
        print(f"    before {t_avail[0]:.1f} s there is NO prediction - the "
              "controller must use the plain MEASURED path over that stretch")

        # Skill, for cross-checking against the W5 table - the same quantity,
        # computed here so that a wrong exported series shows up on the spot.
        # The TARGET is always the REAL future wind: the aim is to predict the
        # wind, not to predict its measurement.
        y = w_rot[idx + k]
        sse = ((yhat - y) ** 2).sum()

        # The persistence baseline has TWO versions, answering two different
        # questions.
        #   clean : persistence is fed noise-free wind - the W5 table's baseline,
        #           kept so the number here is DIRECTLY comparable with W5
        #   dirty : persistence gets only the same sensor the model gets - this
        #           is the baseline that matches the control experiment, because
        #           the "sensor" branch in Simulink IS a ZOH of w_meas
        ssr = ((w_rot[idx] - y) ** 2).sum()
        out["skill_check"] = float(1 - sse / ssr)
        print(f"    skill on this very run: {out['skill_check']:+.4f}"
              "   (CLEAN persistence baseline - compare with the W5 table)")
        if w_in is not w_rot:
            ssn = ((w_in[idx] - y) ** 2).sum()
            out["skill_check_noisy_ref"] = float(1 - sse / ssn)
            print(f"    skill vs DIRTY persistence:     "
                  f"{out['skill_check_noisy_ref']:+.4f}"
                  "   (the baseline matching the control experiment)")
            print("      The second number is the one to read E1b by: it asks "
                  "'does the model beat\n      using the measurement directly', "
                  "which is the question the section 0.42 table asks.")

    # EVERY scalar must be a DOUBLE before it is written.
    #
    # savemat stores a Python int as int64, and MATLAB/Octave then does INTEGER
    # ARITHMETIC on it: int64(150) * 1e-3 gives 0, not 0.15 - the result keeps
    # the integer type and is ROUNDED, with no warning. Measured:
    #     k = round(tau_ms*1e-3*fs)  ->  0   instead of 3
    # If that reached the Simulink wiring the prediction would be clamped to
    # tau = 0, i.e. the "predictor" would become persistence, and the W7 table
    # would report "prediction does not help" with nothing anywhere reporting an
    # error. verify_wind_force.m catches it.
    for kk, vv in list(out.items()):
        if isinstance(vv, (int, np.integer)):
            out[kk] = float(vv)
        elif isinstance(vv, np.ndarray) and vv.dtype.kind in "iu":
            out[kk] = vv.astype(np.float64)

    if getattr(a, "check_against", None):
        # sec 43: the dirty-sensor file must differ from the clean one ONLY in
        # w_meas / w_hat (and their metadata) - the wind on the plant is untouched.
        from scipy.io import loadmat
        ref = pathlib.Path(a.check_against) / pathlib.Path(out_path).name
        if not ref.is_file():
            raise SystemExit(f"--check-against: {ref} not found - nothing written")
        R0 = loadmat(str(ref))
        for k in ("w_true", "w_plant"):
            if k not in R0 or not np.array_equal(np.asarray(out[k], float),
                                                 np.asarray(R0[k], float)):
                raise SystemExit(f"--check-against: {k} differs from {ref} - "
                                 "the segment is not the same; nothing written")
        for k in ("real_file", "real_offset_s"):
            if k in out and np.asarray(R0.get(k)).ravel().tolist() and \
                    str(np.asarray(R0[k]).ravel()[0]) != str(np.asarray(out[k]).ravel()[0]):
                raise SystemExit(f"--check-against: {k} differs from {ref}; nothing written")
        print(f"  check-against {ref.name}: w_true, w_plant, real_file, real_offset_s identical")
    savemat(out_path, out, do_compression=True)
    print(f"\nWrote {out_path}")
    print("  Simulink: From Workspace <- w_plant (linear interpolation),")
    print("            From Workspace <- w_hat   (ZOH 20 Hz),")
    print("            then BOTH through wind_to_force.m.")



if __name__ == "__main__":
    main()
