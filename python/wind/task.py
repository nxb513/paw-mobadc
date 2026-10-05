"""
task.py -- THE DEFINITION OF THE WIND PREDICTION TASK. The single source.

===========================================================================
WHY THIS WAS FIXED BEFORE ANY PREDICTOR WAS WRITTEN
===========================================================================
Every number in W2-W5 is a measurement MADE ACCORDING TO this definition. If
the definition were adjusted after the results were seen - a different horizon,
a different window, a different way of pooling - then nobody, the author
included, could separate "chosen because it is right" from "chosen because it
gives a better number". So this file plays the same role for the wind branch
that core/expected_baseline.m plays for the payload branch: one place, fixed in
advance, and every change needs a recorded reason.

===========================================================================
WHAT THIS BRANCH TURNED OUT TO BE
===========================================================================
Stated here because anyone reading this file should know it before reading any
skill number: the learned wind predictor is reported in the paper as a NEGATIVE
ABLATION, not as a contribution.

The reason is not that PI-MoE is weak. It is that the ceiling was measured: a
controller given the PERFECT future wind (column O of the outdoor grid) beats
one given the sensor by +0.3% on the confirmation set. At this horizon there is
almost nothing to be gained by anticipating the wind, which bounds every wind
predictor and not only this one. See docs/RESULTS.md R7.2, and the oracle branch
of core/wind_sim_load.m.

The task definition below is still exactly as registered. It is not weakened to
match the outcome.

===========================================================================
THE TASK
===========================================================================
Given the past WINDOW_S seconds of wind velocity (3 axes), predict the wind
velocity at t + tau.

    input     w(t - WINDOW_S : t)        (n_w, 3)
    output    w_hat(t + tau)             (3,)

At the VELOCITY level - not at force level and not through the ESO - exactly as
the dataset was split in W1. Force, ESO and controller are later stages.

===========================================================================
HORIZON
===========================================================================
Primary: 140 ms. Not an arbitrary number - it is the measured effective lag of
the attitude loop on the payload branch (93 ms from the transfer function,
140 ms measured experimentally), i.e. the amount of lag a predictor exists to
compensate.

The sweep {40, 80, 140, 200, 400, 1000} ms gives a skill-versus-tau curve. That
curve is what says where the problem becomes hard, and it is itself the
"prediction ceiling by wind type": a Kalman filter with the correct Dryden model
attains the theoretical ceiling, so reading table W2.3 is reading the ceiling and
no separate measurement is needed.

===========================================================================
THE TASK SAMPLING RATE
===========================================================================
TASK_FS = 50 Hz, decimated from the source dataset's 200 Hz (an exact factor 4).

Two constraints meet at 50:
  * tau = 40 ms must be representable -> dt <= 40 ms, i.e. fs >= 25 Hz;
    at 20 Hz (dt = 50 ms) it does not exist.
  * every tau must be an integer number of steps, otherwise comparisons between
    horizons carry interpolation error. At 50 Hz: 2, 4, 7, 10, 20, 50 steps -
    all integers.

Decimation, not filtering. The spectral content of wind lies below ~2 Hz while
Nyquist is 25 Hz, so aliasing is negligible (verify_task_spec measures the
variance lost). Filtering before decimation would add phase lag inside the very
band being measured - the last thing wanted in a prediction task.

===========================================================================
HOW RESULTS ARE POOLED - THIS IS WHERE THE CONCLUSION IS DECIDED
===========================================================================
Runs differ in sigma by up to a factor of 4 (I from 5% to 20%). Therefore:

  * a raw pooled MSE is DOMINATED by the I = 20% runs. A method that is poor in
    light wind and good in strong wind would win, and that conclusion would not
    hold for most conditions.
  * an absolute RMSE is not comparable across wind types.

So TWO quantities are reported, both fixed here:

  1. pooled skill = 1 - MSE_pooled(model) / MSE_pooled(persistence), computed
     within each group (wind type, split). Persistence is the denominator
     because it is "do nothing" - zero then has a clear physical meaning, and it
     normalises sigma away.
  2. per-run skill -> median and interquartile range.

(2) is what produces an ERROR BAR - the thing the payload branch lacks
(docs/devlog/DISCUSSION.md §7, limitation 5). Without it there is no way to say
whether a difference between two methods is real.

===========================================================================
THE EVENT-WINDOW METRIC
===========================================================================
A gust lasts 10.5 s inside a 200 s record. A global RMSE dilutes the effect: a
predictor that halves the MSE inside the gust, where the gust occupies 1% of the
time and its MSE is 10 times the background, moves the global RMSE by only 2.3%.

So every result reports both: global, and within +-3 s around each entry of
eog_starts. Fixed now, before any data exist.
"""

import numpy as np

# ---- Fixed. Changing a line here changes the definition of the measurement. ----
HORIZONS_MS = (40, 80, 140, 200, 400, 1000)
HORIZON_PRIMARY_MS = 140

# THE INPUT WINDOW and THE POINT WHERE SCORING BEGINS are two different things.
#
# Originally a single constant WINDOW_S = 5 s played both roles. That breaks the
# moment the 5 s / 30 s ablation is added: the 30 s model would start scoring at
# second 30 while the W2 baselines start at second 5. On a 200 s record that is
# 170 s against 195 s - two different sample sets, and the difference is NOT a
# random sample but the opening stretch of every record. Comparisons between
# them would be biased in a direction nobody can predict.
#
# So: each method decides for itself how far back to look, but ALL of them are
# scored on the same index set, starting from the LONGEST window in the
# ablation.
WINDOWS_S = (5.0, 30.0)          # the W3 ablation axis
WINDOW_S = 5.0                   # the default input window of the W2 baselines
EVAL_START_S = max(WINDOWS_S)    # where scoring begins, for EVERY method,
                                 # including those that look back only 5 s

EVENT_HALF_S = 3.0
TASK_FS = 50.0
SOURCE_FS = 200.0
DECIMATE = int(SOURCE_FS / TASK_FS)

# ---- The working rate is a PARAMETER, not a constant ----
#
# W1-W4 run at TASK_FS = 50 Hz. W5 must run at 20 Hz, because that is the rate
# of a sonic anemometer - the industry standard, and there is almost no public
# atmospheric dataset faster than that.
#
# The only correct move is to bring BOTH down to 20 Hz: 200/20 = 10 divides
# exactly, so decimation is EXACT. Interpolating 20 -> 50 Hz is not: it invents
# content above 10 Hz, and an artificially smooth interpolated signal inflates
# skill at short tau - precisely the place where a sim-to-real report is easiest
# to cheat without anyone seeing it.
#
# W2/W3/W4 STAY at 50 Hz. W5 is an independent experiment at 20 Hz carrying its
# own synthetic control (W4-A re-run at 20 Hz), so comparisons inside W5 remain
# consistent without any already-recorded table having to be re-run.


def check_fs(fs, source_fs=SOURCE_FS):
    """SOURCE_FS must divide exactly by fs, otherwise interpolation is needed."""
    r = source_fs / fs
    if abs(r - round(r)) > 1e-9:
        raise ValueError(
            f"fs = {fs} Hz does not divide {source_fs} Hz exactly ({r:.4f}). "
            "Rate reduction must be integer decimation; a non-integer ratio "
            "requires interpolation, and interpolation invents high-frequency "
            "content.")
    return int(round(r))


def snap_horizons(fs, horizons=HORIZONS_MS):
    """Horizons snapped to the sample grid of fs, with duplicates removed.

    At 20 Hz the sample step is 50 ms, so 40 -> 50 and 140 -> 150: a 7% shift at
    short tau, while tau = 1000 ms is unchanged. The function RETURNS the snapped
    grid rather than snapping silently inside horizon_steps, so that a changed
    number appears at the call site instead of hiding inside a later function.
    """
    dt = 1000.0 / fs
    out = []
    for t in horizons:
        k = max(1, int(round(t / dt)))
        v = int(round(k * dt))
        if v not in out:
            out.append(v)
    return tuple(out)


def horizon_steps(tau_ms, fs=TASK_FS):
    """tau [ms] -> number of steps. Raises if it is not an integer."""
    k = tau_ms * 1e-3 * fs
    if abs(k - round(k)) > 1e-9:
        raise ValueError(
            f"tau = {tau_ms} ms is not an integer number of steps at fs = {fs} Hz "
            f"({k:.4f} steps). Every tau must be an integer number of steps, "
            f"otherwise comparisons between horizons carry interpolation error."
        )
    return int(round(k))


def valid_range(n, tau_ms, fs=TASK_FS):
    """[i0, i1) - the indices t that have enough history AND a target at t+tau.

    Every method must be scored on EXACTLY this index set. If persistence were
    scored over the whole record while AR started at sample 250, the two numbers
    would not be comparable.

    i0 comes from EVAL_START_S and not from each method's own input window - see
    the note at the top of this file.
    """
    i0 = int(round(EVAL_START_S * fs))
    i1 = n - horizon_steps(tau_ms, fs)
    if i1 <= i0:
        raise ValueError("the record is too short for this tau")
    return i0, i1


def event_mask(n, eog_starts, eog_T, fs=TASK_FS, half=EVENT_HALF_S):
    """The event-window mask: +-half seconds around each gust event.

    The window covers the whole event (0..eog_T), not just its start, plus half
    on each side - because what is being measured is the ability to KEEP UP with
    a transient, and the hardest parts of that are the rising edge and the end.
    """
    m = np.zeros(n, dtype=bool)
    for t0 in np.atleast_1d(eog_starts).ravel():
        a = int(round((t0 - half) * fs))
        b = int(round((t0 + eog_T + half) * fs))
        m[max(a, 0):max(b, 0)] = True
    return m


# =========================================================================
#  Metric
# =========================================================================
def mse(pred, true, mask=None):
    """MSE pooled over all 3 axes. The mask applies along the time axis."""
    e = np.asarray(pred, float) - np.asarray(true, float)
    if mask is not None:
        e = e[mask]
    return float(np.mean(e**2)) if e.size else np.nan


def rmse(pred, true, mask=None):
    return float(np.sqrt(mse(pred, true, mask)))


def skill(mse_model, mse_ref):
    """1 - MSE/MSE_ref.  1 = perfect, 0 = equal to the reference, negative = worse.

    The reference is always persistence. Neither R^2 nor absolute RMSE is used,
    because neither is comparable across runs with different sigma.
    """
    if not np.isfinite(mse_ref) or mse_ref <= 0:
        return np.nan
    return 1.0 - mse_model / mse_ref


def persistence(w, tau_ms, fs=TASK_FS):
    """The reference prediction: w_hat(t+tau) = w(t).

    It lives in the definition file rather than among the baselines, because it
    is the DENOMINATOR of every skill score - it is part of the measurement, not
    a method competing in it.
    """
    i0, i1 = valid_range(len(w), tau_ms, fs)
    return w[i0:i1], slice(i0, i1)


def target(w, tau_ms, fs=TASK_FS):
    """The target: w(t+tau), on the same index set."""
    i0, i1 = valid_range(len(w), tau_ms, fs)
    k = horizon_steps(tau_ms, fs)
    return w[i0 + k:i1 + k]


def aggregate(per_run):
    """Pool per-run results into one reported row.

    per_run: a list of dicts {'sse','n','sse_ref','n_ref', 'sse_ev','n_ev',
                              'sse_ev_ref','n_ev_ref'}
    Pooled by SUMMED SQUARED ERROR, not by averaging the per-run MSEs - the two
    differ when the runs are of unequal length, and only the summed-square form
    matches the definition of pooled MSE above.

    Note that the payload branch pools differently, by sqrt(mean(m_i^2)) over
    segments (core/pool_rule.m), and that the summed-square form was explicitly
    REJECTED there. The two branches measure different things - this one pools
    an error signal, that one pools per-segment summaries - and each states its
    own rule. Neither number may be read as the other.
    """
    def _p(k_sse, k_n):
        s = sum(r[k_sse] for r in per_run)
        n = sum(r[k_n] for r in per_run)
        return s / n if n else np.nan

    m, mr = _p("sse", "n"), _p("sse_ref", "n_ref")
    ev, evr = _p("sse_ev", "n_ev"), _p("sse_ev_ref", "n_ev_ref")
    per = [skill(r["sse"] / r["n"], r["sse_ref"] / r["n_ref"])
           for r in per_run if r["n"]]
    per = np.array([x for x in per if np.isfinite(x)])
    return {
        "rmse": np.sqrt(m),
        "skill": skill(m, mr),
        "rmse_event": np.sqrt(ev),
        "skill_event": skill(ev, evr),
        "skill_median": float(np.median(per)) if per.size else np.nan,
        "skill_iqr": (float(np.percentile(per, 25)), float(np.percentile(per, 75)))
                     if per.size else (np.nan, np.nan),
        "n_runs": len(per_run),
    }
