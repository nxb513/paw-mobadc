"""
real_loader.py -- read MEASURED wind from NWTC's M5 tower into W1's format.

    https://wind.nlr.gov/MetData/135mData/M5Twr/20Hz/mat/<year>/<month>/<day>/

Each file is 10 minutes at 20 Hz (12000 samples). Three-axis sonics at six
heights: 119, 100, 74, 61, 41, 15 m. The variables are MATLAB structs with
.val/.units/.label/.height; units are m/s.

Note on the domain name: *.nrel.gov no longer resolves, *.nlr.gov does and
serves the same content.

===========================================================================
ROTATING THE AXES IS MANDATORY, NOT OPTIONAL
===========================================================================
spectra.turbulence_uvw() generates turbulence in a WIND-ALIGNED frame:

    axis 0 = along-wind (u), correlation length L_u
    axis 1,2 = crosswind (v, w),                L_u/2

and moe.AXIS_L_SCALE = (1.0, 0.5, 0.5) encodes exactly that assumption into
the expert bank. A sonic measures in the INSTRUMENT's frame. Feed instrument
readings straight into the model and channel 0 is not the along-wind
component, so the bank's whole anisotropy becomes wrong - the same class of
error as "one filter for three axes", which drove PI-MoE negative at W3, only
on the data side instead.

So use meteorology's standard DOUBLE ROTATION:
    yaw   : rotate about z until mean v = 0
    pitch : rotate about the new y until mean w = 0
After it, the mean is (U, 0, 0).

===========================================================================
ONE DIFFERENCE IN THE SYNTHETIC SET, WRITTEN DOWN SO NOBODY MISREADS IT
===========================================================================
In generators.py the turbulence is in the wind-aligned frame (axis 0 = u) BUT
the mean field, the gusts and the periodic component are multiplied by
_dir_vec(mean_dir_deg), i.e. they live in a FIXED frame rotated by some angle.
The two frames coincide only when mean_dir_deg = 0.

That does not invalidate any existing result: the model only assumes
anisotropy PER CHANNEL, and the turbulence really is generated that way, while
the mean is subtracted off inside the window. But it does mean that when real
data is rotated it must follow the TURBULENCE convention (axis 0 = along-wind),
not the gust one.
"""

import datetime
import hashlib
import json
import pathlib
import re
import subprocess

import numpy as np
from scipy import ndimage
from scipy.io import loadmat

SONIC_FS = 20.0                 # Hz, counted: 12000 samples / 600 s
FILE_SECONDS = 600.0
HEIGHTS = (119, 100, 74, 61, 41, 15)

# --------------------------------------------------------------------------
# QC thresholds. FIXED BEFORE looking at any model result.
#
# Every threshold has a measured reason behind it, not an arbitrary number:
#
#   U_MIN   At 12:00 on 2024-04-15 the measurement was U = 0.71 m/s with
#           I = 113%. When the mean wind is near zero, "turbulence intensity"
#           stops meaning anything and the wind direction - hence the rotation
#           - is undefined. 3 m/s is the lower edge of the band a UAV actually
#           flies in.
#   I_MAX   The same reason, bounding from the other side.
#   SD_MIN  A dead channel gives exactly sigma = 0. Measured: Sonic_*_15 at
#           12:00 returned U = 137 m/s with sigma = 0.
#   ABS_MAX The world gust record is ~113 m/s; 40 m/s is already beyond any
#           UAV condition. A larger value is a sensor error code.
#   DRIFT   Not used. See the note below.
# --------------------------------------------------------------------------
U_MIN = 3.0                     # m/s
I_MAX = 0.5                     # sigma_u / U
SD_MIN = 0.01                   # m/s
ABS_MAX = 40.0                  # m/s

# The largest step allowed between two samples, on the VECTOR (so it is
# invariant under rotation).
#
# DERIVED FROM PHYSICS, not from the data. In the inertial subrange the
# structure function is D(dt) = C2*(eps*dt)^(2/3). With U = 12 m/s and an
# integral scale L ~ 100 m, eps ~ U^3/L = 17.3 m^2/s^3, so
# D(0.05) ~ 2.0*(0.865)^(2/3) = 1.82 m^2/s^2, i.e. an RMS increment over 50 ms
# of ~1.35 m/s. A 10 m/s threshold is more than 7 sigma - it cannot be real
# turbulence.
#
# This is a REJECTION CRITERION, not a filter: an offending segment is
# DISCARDED, not repaired. Repairing it means replacing part of the signal with
# interpolation, and across 30 dev segments the V&M despiking only lowered the
# fraction exceeding 10 m/s from 17.6% to 16.5% while rejecting 64% of the
# segments - it is not a solution. See the docs, sections 0.55-0.56.
MAX_DU = 10.0                   # m/s between consecutive samples


# --------------------------------------------------------------------------
# The dev / heldout split of the M5 files.
#
# The measured-wind set is cut in TWO: one part for characterisation (measuring
# Tc, tuning QC, fixing the protocol) and one part LOCKED AWAY, never looked at
# until the final zero-shot measurement. Use one set for both and "zero-shot"
# stops being zero-shot: every design decision would have seen that data.
#
# Split BY DAY, not by file. Files from the same day share one weather pattern,
# so splitting within a day leaks: the 02:00 and the 06:00 segment of one day
# resemble each other more than any two days do.
#
# The four days below HAVE been used for characterisation (W5_REALWIND section
# 6: measuring Tc, choosing the QC thresholds, measuring the bank ceiling), so
# they are forced into 'dev' permanently. Named explicitly here rather than left
# to the hash, because this is a historical fact and not a rule.
CHARACTERISATION_DAYS = ("2024-01-18", "2024-02-14", "2024-04-15", "2024-05-20")


def day_of(path):
    """'MM_DD_YYYY_...' -> 'YYYY-MM-DD'."""
    m = re.match(r"(\d\d)_(\d\d)_(\d{4})_", pathlib.Path(path).name)
    if not m:
        return ""
    mo, d, y = m.groups()
    return f"{y}-{mo}-{d}"


def split_of(path):
    """'dev' or 'heldout'. Deterministic, and a function of the DAY alone.

    SHA-256 rather than Python's hash(): hash() of a string varies per process
    (PYTHONHASHSEED), so the same file would fall on different sides on two
    runs - which is a way to leak the held-out set with nobody seeing it.
    """
    day = day_of(path)
    if day in CHARACTERISATION_DAYS:
        return "dev"
    h = hashlib.sha256(day.encode()).hexdigest()
    return "heldout" if int(h[:8], 16) % 2 == 0 else "dev"


def is_m5_file(path):
    """Does the filename have M5's 'MM_DD_YYYY_HH_MM_SS_mmm.mat' form?

    Necessary, and it has caught a real error. The user's data directory also
    holds w2_results.mat, moe_w30_t140_alpha.mat, w4_frozen_20hz.mat and
    others. For those names day_of() returns '' and split_of('') still returns
    SOME split - so after the first run, verify reported "54 files, 13 days"
    when there were really only 48 M5 files across 12 days. Those stray files
    do not corrupt the results (they have no Sonic_* channels, so segments()
    skips them), but they make the DENOMINATOR wrong in every report - and a
    wrong denominator that reports no error is the kind of thing that walks
    straight into the paper.
    """
    return bool(re.match(r"\d\d_\d\d_\d{4}_\d\d_\d\d_\d\d_\d+\.mat$",
                         pathlib.Path(path).name))


def list_files(directory, split="dev"):
    """M5's own .mat files for a split. split = 'all' returns everything.

    The default is 'dev' DELIBERATELY: scoring on the locked set has to be a
    deliberate act, not the default value of an argument.
    """
    if split not in ("dev", "heldout", "all"):
        raise ValueError(f"split must be dev/heldout/all, not {split!r}")
    ps = [p for p in sorted(pathlib.Path(directory).glob("*.mat"))
          if is_m5_file(p)]
    if split == "all":
        return ps
    return [p for p in ps if split_of(p) == split]


def log_heldout(directory, argv, cfg):
    """Append ONE line to the ledger each time a script scores or uses the
    locked set.

    Placed here rather than in score_real_wind.py because since W6 there are TWO
    routes into the locked set: the scoring script, and export_wind_sim.py
    writing series for Simulink. Both must write to the SAME ledger, or the
    ledger stops counting.

    Returns (which use this is, path to the ledger).
    """
    p = pathlib.Path(directory) / "heldout_scoring.log"
    try:
        commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"],
                                cwd=pathlib.Path(__file__).resolve().parent,
                                capture_output=True, text=True,
                                timeout=10).stdout.strip() or "?"
    except Exception:
        commit = "?"
    n = sum(1 for _ in p.open()) if p.exists() else 0
    h = hashlib.sha256(json.dumps(cfg, sort_keys=True).encode()).hexdigest()[:12]
    with p.open("a") as f:
        f.write(f"{datetime.datetime.now().isoformat(timespec='seconds')}  "
                f"commit={commit}  cfg={h}  argv={' '.join(argv)}\n")
    return n + 1, p


def parse_time(path):
    """MM_DD_YYYY_HH_MM_SS_mmm.mat -> an ISO string."""
    m = re.match(r"(\d\d)_(\d\d)_(\d{4})_(\d\d)_(\d\d)_(\d\d)",
                 pathlib.Path(path).name)
    if not m:
        return pathlib.Path(path).stem
    mo, d, y, hh, mi, ss = m.groups()
    return f"{y}-{mo}-{d}T{hh}:{mi}:{ss}"


def load_file(path):
    """Read one .mat file, returning {name: (val, units, height)}."""
    d = loadmat(str(path), squeeze_me=True, struct_as_record=False)
    out = {}
    for k, v in d.items():
        if k.startswith("__") or not hasattr(v, "val"):
            continue
        out[k] = (np.asarray(v.val, dtype=float),
                  getattr(v, "units", ""), getattr(v, "height", None))
    return out


def sonic_uvw(chans, height):
    """(n,3) in the INSTRUMENT frame, not yet rotated. None if a channel is
    missing."""
    try:
        u, uu, _ = chans[f"Sonic_x_{height}"]
        v, _, _ = chans[f"Sonic_y_{height}"]
        w, _, _ = chans[f"Sonic_z_{height}"]
    except KeyError:
        return None, None
    if uu and uu != "m/s":
        raise ValueError(f"Sonic_x_{height} has units {uu!r}, expected 'm/s'")
    return np.column_stack([u, v, w]), uu


# --------------------------------------------------------------------------
# DESPIKING. OFF BY DEFAULT - see segments(despike_on=...).
#
# Why it exists: measured across 30 dev segments, 7 of them (23%) contain a
# physically impossible step between two samples 50 ms apart. The worst is
# i0006: 23.5 m/s in 50 ms, i.e. 470 m/s^2. The actual samples around the peak,
# after double rotation (axis 0 = ALONG-WIND, U = 12.14 m/s):
#
#        u         v
#     7.1572    3.4541
#   -15.0013   -2.9024     <- one sample
#     7.7217    2.9481
#
# u = -15.0 in a mean flow of +12.1 m/s means the wind REVERSED at more than
# twice the mean speed, within 50 ms, and came straight back. That is not wind.
# It is a textbook sonic spike (rain, an insect, or a lost electronic sample).
#
# The old QC could not catch it: it checked finiteness, max |v|, dead channels,
# calm and I_max - nothing about RATE OF CHANGE. A one-sample spike passes every
# one of those as long as |v| stays under ABS_MAX.
#
# Method: Vickers & Mahrt (1997) - sliding window, gate at 3.5 sigma, a limit on
# the number of CONSECUTIVE flagged samples. A PUBLISHED method rather than a
# threshold of my own: inventing a threshold after seeing i0006 is fitting the
# test to the result.
#
# ONE MODIFICATION, with its reason: median + MAD as the scale rather than
# mean + std. That is a known property of robust location estimators (a single
# outlier inflates std enough to hide itself), not a choice drawn from this
# data. For i0006: the spiked window's std is inflated to ~5.6, so a 22 m/s
# deviation is only 3.9 sigma - right at the threshold. With MAD it is ~30 sigma.
SPIKE_WIN_S = 5.0               # s, sliding window
SPIKE_NSIG = 3.5                # V&M 1997
SPIKE_MAX_RUN = 3               # consecutive samples; longer is a REAL EVENT
SPIKE_MAX_PASS = 10
SPIKE_MAX_FRAC = 0.01           # > 1% flagged -> a broken segment, not spikes


def _roll_med_mad(x, win):
    """Rolling median and MAD, via scipy.ndimage (C) rather than a Python loop.

    This was a Python loop at first. Fine for one segment, but auditing the
    whole archive is ~4000 segments x 3 channels x several passes, and there it
    was unusable. median_filter gives the same result in the interior; the only
    difference is at the EDGES.

    Edges use 'reflect', NOT 'nearest'. 'nearest' repeats the edge value, which
    shrinks the MAD at the boundary so everything there looks like a spike:
    measured on a CLEAN synthetic signal, 'nearest' flags 45 samples of which 26
    are at the edges, while 'reflect' flags 19 and NONE at the edges.
    """
    med = ndimage.median_filter(x, size=win, mode="reflect")
    mad = ndimage.median_filter(np.abs(x - med), size=win, mode="reflect")
    return med, 1.4826 * mad


def despike(uvw, fs=SONIC_FS, win_s=SPIKE_WIN_S, nsig=SPIKE_NSIG,
            max_run=SPIKE_MAX_RUN, max_pass=SPIKE_MAX_PASS):
    """Remove one-sample spikes. Returns (clean, n_spikes, peak_delta_before).

    A flagged value is replaced by linear interpolation between its valid
    neighbours. A run LONGER than max_run is NOT treated as a spike: that is a
    real event (a gust, a front), and removing it would make measured wind
    artificially resemble synthetic wind - exactly what qc() forbids itself
    from doing.
    """
    x = np.array(uvw, dtype=np.float64, copy=True)
    n, ncol = x.shape
    win = max(5, int(round(win_s * fs)) | 1)
    d0 = float(np.abs(np.diff(x, axis=0)).max()) if n > 1 else 0.0
    bad_all = np.zeros(n, dtype=bool)

    for ip in range(max_pass):
        # THE THRESHOLD RISES each pass - exactly as in V&M 1997.
        #
        # Without that detail the loop does not converge: once the genuine
        # spikes are interpolated, the next pass finds the new BOUNDARY points
        # and removes those too. Measured on a synthetic signal injected with
        # EXACTLY TWO spikes: a fixed threshold removed 15 samples, i.e. 13
        # healthy ones taken with them.
        ns = nsig + 0.1 * ip
        flag = np.zeros(n, dtype=bool)
        for c in range(ncol):
            med, sd = _roll_med_mad(x[:, c], win)
            sd = np.where(sd > 1e-9, sd, np.inf)      # a flat channel has no spikes
            flag |= np.abs(x[:, c] - med) > ns * sd
        flag &= ~bad_all                              # already repaired, leave it
        # Keep only the SHORT runs. A long run is a real event.
        idx = np.flatnonzero(flag)
        if idx.size == 0:
            break
        keep = np.zeros(n, dtype=bool)
        for grp in np.split(idx, np.flatnonzero(np.diff(idx) > 1) + 1):
            if grp.size <= max_run:
                keep[grp] = True
        if not keep.any():
            break
        good = np.flatnonzero(~keep)
        if good.size < 2:
            break
        for c in range(ncol):
            x[keep, c] = np.interp(np.flatnonzero(keep), good, x[good, c])
        bad_all |= keep

    return x, int(bad_all.sum()), d0


def spike_stats(uvw, fs=SONIC_FS):
    """Measure HOW spiky a segment is without repairing anything. For audits."""
    clean, n_bad, d0 = despike(uvw, fs=fs)
    d1 = float(np.abs(np.diff(clean, axis=0)).max()) if len(clean) > 1 else 0.0
    return {"n_spike": n_bad, "frac": n_bad / max(len(uvw), 1),
            "max_step_before": d0, "max_step_after": d1}


def double_rotation(uvw):
    """Double rotation into the wind-aligned frame. Returns (rotated, yaw_rad,
    pitch_rad).

    After it: mean(v) = 0 and mean(w) = 0 to machine precision.
    """
    m = uvw.mean(axis=0)
    yaw = np.arctan2(m[1], m[0])
    c, s = np.cos(yaw), np.sin(yaw)
    r1 = np.column_stack([uvw[:, 0] * c + uvw[:, 1] * s,
                          -uvw[:, 0] * s + uvw[:, 1] * c,
                          uvw[:, 2]])
    m1 = r1.mean(axis=0)
    pitch = np.arctan2(m1[2], m1[0])
    c, s = np.cos(pitch), np.sin(pitch)
    r2 = np.column_stack([r1[:, 0] * c + r1[:, 2] * s,
                          r1[:, 1],
                          -r1[:, 0] * s + r1[:, 2] * c])
    return r2, float(yaw), float(pitch)


def qc(uvw):
    """(passed, reason, stats). uvw must already be rotated.

    NO stationarity test. Measured wind is not stationary, and that is precisely
    what W5 set out to measure; rejecting non-stationary segments would make
    measured wind artificially resemble the synthetic set, i.e. improve the
    result by selecting the data. Only segments where the MEASUREMENT ITSELF is
    meaningless are rejected (calm, dead channel, error codes).
    """
    st = {}
    if not np.isfinite(uvw).all():
        return False, "NaN/Inf present", st
    U = float(uvw[:, 0].mean())
    sd = uvw.std(axis=0)
    st = {"U": U, "sigma": sd.tolist(),
          "I": float(sd[0] / U) if U > 1e-9 else np.inf}
    if np.abs(uvw).max() > ABS_MAX:
        return False, f"|v| = {np.abs(uvw).max():.1f} > {ABS_MAX} m/s", st
    if sd.min() < SD_MIN:
        return False, f"dead channel (sigma_min = {sd.min():.4f})", st
    if U < U_MIN:
        return False, f"calm (U = {U:.2f} < {U_MIN} m/s)", st
    if st["I"] > I_MAX:
        return False, f"I = {st['I']:.2f} > {I_MAX}", st
    # RATE OF CHANGE. Before this test a one-sample spike passed everything:
    # measured on i0006, a single sample of -15.0 m/s sits between +7.2 and
    # +7.7, in a mean flow of +12.1 m/s - the wind reversing at more than twice
    # the mean speed within 50 ms and returning immediately.
    du = float(np.sqrt((np.diff(uvw, axis=0) ** 2).sum(axis=1)).max())
    st["max_du"] = du
    if du > MAX_DU:
        return False, f"step {du:.1f} > {MAX_DU} m/s per sample", st
    return True, "", st


# The DEFAULT heights for W5. NOT 119 m.
#
# The legal UAV ceiling in most countries is 120 m AGL, so 119 m is JUST UNDER
# THE CEILING rather than an operating height. My first pilot used 119 m only
# because it is the first channel in the file - a choice with nothing to do with
# the problem.
#
# Repeated across the same 24 files, tau = 1000 ms:
#
#     z      segments passing QC   bank ceiling   wins at a grid edge
#    15 m       0/72  (sonic broken on all 4 days: |v| = 168 m/s)
#    41 m      44/72       +0.2460           43%
#    61 m      47/72       +0.1431           43%
#    74 m      49/72       +0.1203           53%
#   119 m      48/72       +0.1048           73%
#
# Wind in the UAV band is EASIER to predict: the ceiling at 41 m is 2.3x the
# ceiling at 119 m. And edge wins fall monotonically with height (73 -> 53 ->
# 43%), which is the right physics: the integral length scale L shrinks near the
# ground, and T_c = L/V.
#
# 41 m HAS SINCE BEEN DROPPED - 2026-09-07. It was previously (41, 61, 74).
#
# Audit over 40 files, 182 segments passing the old QC, split by height:
#
#     z    segments  mean I   median step   max     % segments > 10 m/s
#    41 m     30      0.35       17.50     24.97         100%
#    61 m     76      0.14        0.86      8.10           0%
#    74 m     76      0.14        1.23     11.71           3%
#
# The MEDIAN step at 41 m is 17.5 m/s per 50 ms, twenty times the other two
# heights, and 100% of segments exceed 10 m/s. The median - not the tail - means
# EVERY segment is like that, so this is not occasional spiking but a broken
# sensor. 30 of the 32 segments exceeding 10 m/s in the whole sample come from
# 41 m.
#
# Mean I of 0.35 against 0.14: the spikes themselves inflate sigma_u, so W5's
# earlier conclusion that "wind at 41 m is more turbulent" may be A CONSEQUENCE
# OF THE SPIKES rather than physics. And because skill is measured against
# persistence, which spikes degrade very fast, the conclusion "the bank ceiling
# at 41 m is 2.3x that at 119 m" (W5_REALWIND, height section) MUST BE
# REVISITED.
#
# A height is dropped because of the SENSOR, not because of a result: the same
# kind of decision W5 already made for 15 m ("sonic broken on all 4 days:
# |v| = 168 m/s"), and checkable independently of any control number.
DEFAULT_HEIGHTS = (61, 74)


def segments(paths, height, dur_s=200.0, fs=SONIC_FS, stride_s=None,
             verbose=False, despike_on=False):
    """Cut the files into dur_s segments, rotated and passed through QC.

    height: one value, or a sequence of heights. With several heights the
    segments are POOLED - each height is a different wind condition (T_c falls
    closer to the ground), so pooling turns height into a natural axis of T_c
    variation.

    Returns (runs, meta): runs is a list of (n,3) arrays in m/s with axis 0
    along-wind. QC runs PER SEGMENT rather than per file: a 10-minute file can
    be calm in its first half and not in its second.
    """
    heights = (height,) if np.isscalar(height) else tuple(height)
    n_seg = int(round(dur_s * fs))
    step = n_seg if stride_s is None else int(round(stride_s * fs))
    runs, meta = [], []
    for p in sorted(paths):
        chans = load_file(p)
        t0 = parse_time(p)
        for z in heights:
            raw, _ = sonic_uvw(chans, z)
            if raw is None:
                if verbose:
                    print(f"  {pathlib.Path(p).name}: missing channel z={z}")
                continue
            for i in range(0, len(raw) - n_seg + 1, step):
                seg = raw[i:i + n_seg]
                if not np.isfinite(seg).all():
                    continue
                # Despike BEFORE rotating: double_rotation derives the rotation
                # FROM the segment itself, so a spike still in it drags the
                # whole segment's rotation angle off.
                #
                # OFF BY DEFAULT. Turning it on changes the test set behind
                # every sim-to-real number already measured, so it has to be a
                # DELIBERATE act, declared in the paper, not a silent default.
                sp = {"n_spike": 0, "spike_frac": 0.0}
                if despike_on:
                    seg, nsp, _ = despike(seg, fs=fs)
                    sp = {"n_spike": nsp, "spike_frac": nsp / n_seg}
                    if sp["spike_frac"] > SPIKE_MAX_FRAC:
                        if verbose:
                            print(f"  {pathlib.Path(p).name} z={z} "
                                  f"+{i / fs:5.0f}s: dropped - {nsp} spikes "
                                  f"({100 * sp['spike_frac']:.1f}%)")
                        continue
                rot, yaw, pitch = double_rotation(seg)
                ok, why, st = qc(rot)
                if not ok:
                    if verbose:
                        print(f"  {pathlib.Path(p).name} z={z} "
                              f"+{i / fs:5.0f}s: dropped - {why}")
                    continue
                runs.append(rot.astype(np.float64))
                meta.append({"file": str(p), "t0": t0, "height": int(z),
                             "offset_s": i / fs, "yaw_deg": np.rad2deg(yaw),
                             "pitch_deg": np.rad2deg(pitch),
                             "despiked": bool(despike_on), **sp, **st})
    return runs, meta
