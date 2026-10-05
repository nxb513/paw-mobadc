"""
evaluate.py -- scoring, shared by EVERY method.

===========================================================================
WHY THIS IS ITS OWN FILE
===========================================================================
W2 scores the baselines, W3 scores PI-MoE, W4 scores generalisation. If each
of those had its own scoring implementation the tables would not be comparable
- and, more importantly, they would NEVER report an error. They would simply
differ.

That is exactly the class of error the payload branch already hit:
sync_eml_blocks reported 20/20 matching while a Constant block pointed at the
wrong variable, because the check looked at code and not at values. The only
reliable way for two numbers to be measured with the same instrument is for
them to call the same function.
"""

import numpy as np

from .task import aggregate, persistence, target, valid_range


def score_run(w, pred, sl, tau_ms, ev_mask=None, fs=None):
    """One run's summed squared error, in the shape aggregate() expects.

    pred must have been computed on EXACTLY the index set sl, and sl must equal
    persistence's index set - otherwise skill's numerator and denominator are
    measured on two different sets and every skill number is wrong.

    fs = None -> TASK_FS. W5 runs at 20 Hz and must pass fs in: with the
    predictor indexing at 20 Hz and persistence here defaulting to 50 Hz, the
    two sets differ. That actually happened on the first 20 Hz run - and the
    check just below is what caught it.
    """
    from .task import TASK_FS
    fs = TASK_FS if fs is None else fs
    y = target(w, tau_ms, fs)
    ref, ref_sl = persistence(w, tau_ms, fs)
    if sl != ref_sl:
        raise ValueError(
            f"the model's index set {sl} differs from persistence's {ref_sl}")
    e = np.asarray(pred, float) - y
    r = ref - y
    out = {"sse": float((e ** 2).sum()), "n": e.size,
           "sse_ref": float((r ** 2).sum()), "n_ref": r.size}
    if ev_mask is not None and ev_mask[sl].any():
        m = ev_mask[sl]
        out |= {"sse_ev": float((e[m] ** 2).sum()), "n_ev": int(e[m].size),
                "sse_ev_ref": float((r[m] ** 2).sum()), "n_ev_ref": int(r[m].size)}
    else:
        out |= {"sse_ev": 0.0, "n_ev": 0, "sse_ev_ref": 0.0, "n_ev_ref": 0}
    return out


def eval_runs(runs_w, predict, tau_ms, masks=None, fs=None):
    """runs_w: a list of (n,3) arrays. predict(w, i) -> (pred, slice)."""
    out = []
    for i, w in enumerate(runs_w):
        pred, sl = predict(w, i)
        out.append(score_run(w, pred, sl, tau_ms,
                             None if masks is None else masks[i], fs))
    return aggregate(out)


def window_batch(w, idx, window):
    """(B, 3, window): the window ENDING at t, i.e. [t-window+1, t].

    The window MUST contain the sample w[t]. This function originally used
    w[t-window:t], which drops the current sample and lets the leading
    coefficient multiply w[t-1] instead.

    The consequence is not obvious and it is large. persistence and
    predict_wiener both read w[t], so the model was off by one step against the
    very denominator of skill - equivalent to predicting 20 ms further ahead.
    On Dryden at 140 ms the ceiling is only +0.03, so a 20 ms offset is enough
    to flip the sign: measured -0.13 instead of +0.02.

    verify_baselines test 2 catches exactly this class of error for the
    baselines (a Markov process's Wiener coefficients must be zero at every lag
    but lag 0). This function is a different path, so that check does not
    protect it; verify_moe test 4 now compares against predict_wiener on real
    data, and that is what caught it.
    """
    out = np.empty((len(idx), 3, window), dtype=np.float32)
    for j, t in enumerate(idx):
        out[j] = w[t - window + 1:t + 1].T
    return out


def valid_indices(n, tau_ms, stride=1, fs=None):
    """fs = None -> W1-W4's default TASK_FS.

    W5 runs at 20 Hz and must pass fs in. This function once ignored fs and
    called valid_range(n, tau_ms) with the 50 Hz default; at 20 Hz that gives an
    i0 wrong by more than a factor of two and raises NOTHING - it simply returns
    a different index set.
    """
    from .task import TASK_FS
    i0, i1 = valid_range(n, tau_ms, TASK_FS if fs is None else fs)
    return np.arange(i0, i1, stride)
