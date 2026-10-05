#!/usr/bin/env python3
"""
alpha_report.py -- what the gate selects, per wind type. And why `ramp` is poor.

    python3 python/alpha_report.py --model moe_w30_t140 --dataset dataset

Reads <model>.json + <model>.pt and does NOT retrain. W3's three-seed run takes
~68 minutes; alpha depends only on the learned weights, so it has to be
readable from a saved checkpoint.

Writes <model>_alpha.mat + _alpha.json for fig_gating.m.

===========================================================================
THE QUESTIONS THIS ANSWERS
===========================================================================
1. Does the gate track the true mixing ratio (type 7)? -> three scatter plots.
2. Which group does the gate select on each wind type? -> the per-type alpha
   table.
3. `ramp`: does the gate choose WRONGLY, or choose RIGHTLY and still do badly?

Question 3 is the new one, and it separates two completely different
hypotheses. The model loses to `ar` on `ramp` at both horizons (+0.9307 against
+0.9542 at 140 ms, +0.8614 against +0.9505 at 1000 ms). Unlike the three
earlier gaps (von Karman, periodic, EOG) this is NOT a missing expert:
`kalman_l1` is a constant-velocity filter, i.e. the correct model for a linear
ramp.

The measurement separates the two possibilities:

    bank ceiling      = the max over experts of the skill with a one-hot gate
    the model's skill = the actual skill

    ceiling >> model  ->  the right expert IS there and the gate does not pick it
    ceiling ~= model  ->  the gate already chose as well as possible; the limit
                          is the bank

All 22 experts are scored in ONE forward pass: forward returns "yhat_expert" -
exactly the yhat that would result from a one-hot gate on that expert, computed
on the model's own path. Running 22 separate passes would be more than 22 times
slower and - more importantly - would be a second path that could drift without
raising anything. That is exactly the error that already happened in
window_batch.
"""

import argparse
import json
import pathlib
import sys

import numpy as np
import torch
from scipy.io import savemat

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from wind.evaluate import valid_indices, window_batch  # noqa: E402
from wind.generators import WIND_TYPES  # noqa: E402
from wind.moe import PIMoE  # noqa: E402
from wind.task import (  # noqa: E402
    TASK_FS, aggregate, persistence, target, valid_range,
)
from train_moe import load_all  # noqa: E402

# Five expert groups. The first three correspond to the three components of
# type 7's mixing ratio, so each (group, component) pair is a direct test.
GROUPS = (
    ("Wiener (turbulence)", lambda n: n.startswith(("dry_", "von_"))),
    ("EOG (gust)",          lambda n: n.startswith("eog_")),
    ("periodic",            lambda n: n.startswith("per_")),
    ("Kalman",              lambda n: n.startswith("kalman")),
    ("residual (learned)",  lambda n: n == "residual"),
)


def load_model(stem):
    """Rebuild the model from <stem>.json + <stem>.pt."""
    S = json.loads(pathlib.Path(stem + ".json").read_text())
    kw = {}
    if S.get("sd_floor") is not None:
        kw["sd_floor"] = S["sd_floor"]
    if S.get("fs"):
        kw["fs"] = S["fs"]
    if S.get("tc_grid"):
        kw["tc_grid"] = tuple(S["tc_grid"])
    m = PIMoE(S["tau_ms"], S["window_s"], **kw)
    m.load_state_dict(torch.load(stem + ".pt", map_location="cpu"))
    m.eval()
    # The expert names must match, otherwise the alpha table's columns point at
    # the wrong experts and nothing reports an error.
    if list(S["expert_names"]) != list(m.expert_names):
        raise SystemExit(
            "alpha_report: expert_names in the .json differ from the rebuilt "
            "bank.\n"
            f"  .json: {S['expert_names']}\n  rebuilt: {m.expert_names}\n"
            "The checkpoint was produced by a different version of moe.py.")
    return m, S


def _sse(pred, y, ref, m=None):
    """m: the event mask, already taken on exactly pred's index set (or None).

    For the types containing gusts, the global skill is DILUTED by the long
    stretches with no event - W2 recorded that and reports a separate skill_ev
    column. Leaving sse_ev = 0 makes aggregate() return skill_event = nan and
    that column disappears silently.
    """
    e, r = pred - y, ref - y
    out = {"sse": float((e ** 2).sum()), "n": e.size,
           "sse_ref": float((r ** 2).sum()), "n_ref": r.size}
    if m is not None and m.any():
        out |= {"sse_ev": float((e[m] ** 2).sum()), "n_ev": int(e[m].size),
                "sse_ev_ref": float((r[m] ** 2).sum()),
                "n_ev_ref": int(r[m].size)}
    else:
        out |= {"sse_ev": 0.0, "n_ev": 0, "sse_ev_ref": 0.0, "n_ev_ref": 0}
    return out


def scan(model, runs, tau, window, stride, batch=256, masks=None,
         fs=TASK_FS):
    """One forward pass over the runs.

    Returns (alpha_run, rows_model, rows_expert, rows_uniform):
        alpha_run    (n_run, E+1)     each run's mean alpha
        rows_model   list of dicts    for aggregate() -> the model's skill
        rows_expert  (n_run, E) dicts skill with a one-hot gate on each expert
        rows_uniform list of dicts    skill with a UNIFORM GATE (alpha = 1/E)

    rows_uniform is the "PI-MoE without gating" ablation: the plain average of
    the whole physical expert bank, choosing nothing. Because a convex
    combination of FIR filters is itself an FIR filter, it is equivalent to ONE
    fixed linear filter - so it can be read beside wiener_pooled. The difference
    (model - uniform gate) is what the CHOOSING contributes, separated from what
    the bank contributes.

    Computed from the same forward pass, so it costs nothing extra.
    """
    nE = len(model.expert_names)
    alpha_run, rows_model, rows_expert, rows_uniform = [], [], [], []
    with torch.no_grad():
        for ri, w in enumerate(runs):
            idx = valid_indices(len(w), tau, stride, fs)
            i0, _ = valid_range(len(w), tau, fs)
            sel = idx - i0
            y = target(w, tau, fs)[sel]
            ref = persistence(w, tau, fs)[0][sel]

            pr = np.empty((len(idx), 3))
            pe = np.empty((len(idx), 3, nE - 1))
            al = np.zeros(nE)
            for b in range(0, len(idx), batch):
                s = idx[b:b + batch]
                o = model(torch.from_numpy(window_batch(w, s, window)))
                pr[b:b + batch] = o["yhat"].numpy()
                pe[b:b + batch] = o["yhat_expert"].numpy()
                al += o["alpha"].numpy().sum(0)
            mk = None
            if masks is not None and masks[ri] is not None:
                mk = masks[ri][idx]
            alpha_run.append(al / max(len(idx), 1))
            rows_model.append(_sse(pr, y, ref, mk))
            rows_expert.append([_sse(pe[:, :, e], y, ref, mk)
                                for e in range(nE - 1)])
            rows_uniform.append(_sse(pe.mean(axis=2), y, ref, mk))
    return np.array(alpha_run), rows_model, rows_expert, rows_uniform


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, help="the stem, without the file extension")
    ap.add_argument("--dataset", default="dataset")
    ap.add_argument("--split", default="test")
    ap.add_argument("--stride", type=int, default=25,
                    help="scoring stride. 25 = 0.5 s, dense enough for alpha.")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()

    model, S = load_model(a.model)
    names = model.expert_names
    fs = S.get("fs", TASK_FS)
    tau, W = S["tau_ms"], int(round(S["window_s"] * fs))
    types = list(S["types"])
    print(f"{a.model}: tau = {tau} ms, window {S['window_s']} s, "
          f"{len(names)} experts, SD_FLOOR = {S.get('sd_floor')}")

    runs, meta = load_all(pathlib.Path(a.dataset), types, a.split)
    print(f"{len(runs)} runs ({a.split}), stride {a.stride}\n")

    alpha_by_type = np.zeros((len(types), len(names)))
    skill_model = np.zeros(len(types))
    skill_best = np.zeros(len(types))
    best_name = []
    mix, alpha_mix = [], []

    md = json.loads((pathlib.Path(a.dataset) / "metadata.json").read_text())
    mix_by_seed = {r["seed"]: r.get("mix") for r in md["runs"]
                   if r["wind_type"] == 7}

    for ti, wt in enumerate(types):
        sel = [i for i, m in enumerate(meta) if m["wt"] == wt]
        if not sel:
            continue
        al, rm, re, _ = scan(model, [runs[i] for i in sel], tau, W,
                             a.stride, fs=fs)
        alpha_by_type[ti] = al.mean(0)
        skill_model[ti] = aggregate(rm)["skill"]
        sk = np.array([aggregate([re[r][e] for r in range(len(sel))])["skill"]
                       for e in range(len(names) - 1)])
        k = int(sk.argmax())
        skill_best[ti], _ = sk[k], None
        best_name.append(names[k])
        print(f"  {wt} {WIND_TYPES[wt]:<14s} model {skill_model[ti]:+.4f}   "
              f"bank ceiling {sk[k]:+.4f} ({names[k]})   "
              f"gap {sk[k] - skill_model[ti]:+.4f}")
        if wt == 7:
            for i, aa in zip(sel, al):
                m = mix_by_seed.get(meta[i]["seed"])
                if m is not None:
                    mix.append(m)
                    alpha_mix.append(aa)

    gmask = np.array([[f(n) for n in names] for _, f in GROUPS], dtype=float)
    out = a.out or (a.model + "_alpha")
    d = {"expert_names": np.array(names, dtype=object),
         "group_names": np.array([g for g, _ in GROUPS], dtype=object),
         "group_mask": gmask,
         "types": np.array(types),
         "type_names": np.array([WIND_TYPES[t] for t in types], dtype=object),
         "alpha_by_type": alpha_by_type,
         "skill_model": skill_model,
         "skill_bank_ceiling": skill_best,
         "best_expert": np.array(best_name, dtype=object),
         "mix": np.array(mix), "alpha_mix": np.array(alpha_mix),
         "tau_ms": tau, "window_s": S["window_s"], "fs": fs,
         "sd_floor": S.get("sd_floor")}
    savemat(out + ".mat", d)
    pathlib.Path(out + ".json").write_text(json.dumps(
        {k: (v.tolist() if isinstance(v, np.ndarray) else v)
         for k, v in d.items()}, indent=1))
    print(f"\nWrote {out}.mat / {out}.json")


if __name__ == "__main__":
    main()
