#!/usr/bin/env python3
"""
train_moe.py -- train PI-MoE (W3.2 + W3.3) and measure it on the test set.

    python3 python/verify_moe.py                      # RUN THIS FIRST
    python3 python/train_moe.py --dataset dataset --window 30
    python3 python/train_moe.py --dataset dataset --window 5

Writes: moe_w{window}_t{tau}.json  +  .pt  +  a table on stdout.

===========================================================================
MEASURED WITH THE SAME INSTRUMENT AS W2
===========================================================================
Scoring calls wind/evaluate.py - the same function run_w2_benchmark calls.
There is no second scoring implementation. So PI-MoE's number can sit beside
ar / wiener_pooled / wiener, and W2's three landmarks keep their meaning:

    ar             the fair rival, which does not know the regime
    wiener_pooled  the linear optimum WITHOUT knowing the regime
    wiener         the optimum KNOWING the regime  = the CEILING

W3's question then states itself as an inequality:

    PI-MoE <= wiener_pooled   ->  the model does NOT infer the regime
    PI-MoE  -> wiener         ->  the model DOES infer the regime

===========================================================================
THE OVERFITTING GAP - A THRESHOLD FIXED BEFORE TRAINING
===========================================================================
It was agreed to postpone generating a 600 s dataset until there was evidence
that data was short. To make that decision on numbers rather than on feeling,
the threshold is set HERE, before any run:

    skill(train) - skill(val) > OVERFIT_GAP  ->  print a warning to generate
                                                 the 600 s set

The INDEPENDENT window counts behind that threshold (200 runs x 200 s):

    5 s window:  1560 - 4333 depending on T_c
    30 s window:  680 - 1000

The 30 s window has 4-5 times fewer, and that is the reason for the suspicion.
But a suspicion is not evidence - this threshold turns it into a measurement.
"""

import argparse
import json
import pathlib
import sys
import time

import numpy as np
import torch

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from wind.evaluate import eval_runs, valid_indices, window_batch  # noqa: E402
from wind.generators import WIND_TYPES  # noqa: E402
from wind.loader import load_group  # noqa: E402
from wind.moe import (  # noqa: E402
    GATE_T, PIMoE, TC_GRID, TC_GRID_W5, nll_loss)
from wind.task import (  # noqa: E402
    HORIZON_PRIMARY_MS, TASK_FS, check_fs, event_mask, snap_horizons,
    valid_range,
)

def tc_grid_of(a):
    """The Tc grid from the CLI. 'w5' -> TC_GRID_W5, default -> W1-W4's
    TC_GRID."""
    if a.tc_grid is None:
        return TC_GRID
    if a.tc_grid.lower() == "w5":
        return TC_GRID_W5
    return tuple(float(x) for x in a.tc_grid.split(","))


OVERFIT_GAP = 0.05          # fixed before training
EVAL_STRIDE_FAST = 50       # during training
EVAL_STRIDE_FINAL = 5       # the final table; 0.1 s apart, dense enough


# =========================================================================
def load_all(ds, types, split, verbose=False, fs=None):
    """fs = None -> TASK_FS.

    The record length is CHECKED against the metadata's duration x fs. Forgetting
    to pass fs down here raises nothing - it simply returns arrays at a different
    rate, of the right dtype and the right shape, and every number afterwards is
    silently wrong. It happened exactly once: the window computed at 20 Hz (600
    samples) while the data was read at 50 Hz (10000 samples instead of 4000).
    """
    from wind.dataset import load_metadata
    md = load_metadata(pathlib.Path(ds))
    want = int(round(md["duration"] * (TASK_FS if fs is None else fs)))
    runs, meta = [], []
    for wt in types:
        g = load_group(ds, wt, split, verbose=verbose, fs=fs)
        if g["w"].shape[1] != want:
            raise SystemExit(
                f"load_all: type {wt} {split} has {g['w'].shape[1]} samples, "
                f"expected {want} ({md['duration']:.0f} s x "
                f"{TASK_FS if fs is None else fs:.0f} Hz). fs was not passed "
                f"down to the loader.")
        for i in range(g["w"].shape[0]):
            runs.append(g["w"][i].astype(np.float64))
            meta.append({"wt": wt, "seed": int(g["seeds"][i]),
                         "events": g["events"][i], "eog_T": g["eog_T"]})
    return runs, meta


def masks_for(runs, meta, fs=TASK_FS):
    return [event_mask(len(w), m["events"], m["eog_T"], fs) if len(m["events"])
            else None for w, m in zip(runs, meta)]


def predict_runs(model, runs, tau, window, stride=1, batch=512,
                 alpha_out=None, fs=TASK_FS):
    """Predict on each run. Returns a list of (pred, slice).

    stride > 1 scores on a subset of indices - legitimate because neighbouring
    indices are almost perfectly correlated (dt = 20 ms against T_c = 4-20 s) -
    but the stride must be the same across any methods being compared.
    """
    model.eval()
    out = []
    with torch.no_grad():
        for r, w in enumerate(runs):
            idx = valid_indices(len(w), tau, stride, fs)
            pr = np.empty((len(idx), 3))
            al = np.zeros(len(model.expert_names))
            for b in range(0, len(idx), batch):
                sl = idx[b:b + batch]
                xb = torch.from_numpy(window_batch(w, sl, window))
                o = model(xb)
                pr[b:b + batch] = o["yhat"].numpy()
                al += o["alpha"].numpy().sum(0)
            out.append((pr, idx))
            if alpha_out is not None:
                alpha_out.append(al / max(len(idx), 1))
    return out


def eval_model(model, runs, meta, tau, window, stride, fs=TASK_FS):
    """Score through wind/evaluate.py - the same function W2 uses."""
    preds = predict_runs(model, runs, tau, window, stride, fs=fs)
    ms = masks_for(runs, meta, fs)

    # With stride > 1 the model's index set is a subset of the full one. Score
    # persistence on EXACTLY that set by decimating both - otherwise the
    # numerator and the denominator sit on different samples and skill is
    # meaningless.
    from wind.task import aggregate, persistence, target
    rows = []
    for (pr, idx), w, mk in zip(preds, runs, ms):
        i0, i1 = valid_range(len(w), tau, fs)
        sel = idx - i0
        y = target(w, tau, fs)[sel]
        ref = persistence(w, tau, fs)[0][sel]
        e, r = pr - y, ref - y
        d = {"sse": float((e ** 2).sum()), "n": e.size,
             "sse_ref": float((r ** 2).sum()), "n_ref": r.size}
        if mk is not None and mk[idx].any():
            m = mk[idx]
            d |= {"sse_ev": float((e[m] ** 2).sum()), "n_ev": int(e[m].size),
                  "sse_ev_ref": float((r[m] ** 2).sum()),
                  "n_ev_ref": int(r[m].size)}
        else:
            d |= {"sse_ev": 0.0, "n_ev": 0, "sse_ev_ref": 0.0, "n_ev_ref": 0}
        rows.append(d)
    return aggregate(rows)


# =========================================================================
def train(model, runs, tau, window, steps, batch, lr, val_runs, val_meta,
          val_every, seed=0, lam_acf=0.1, verbose=True, fs=TASK_FS,
          lam_gate=0.0, gate_T=GATE_T):
    torch.manual_seed(seed)
    rng = np.random.default_rng(seed)
    opt = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-3)
    sch = torch.optim.lr_scheduler.CosineAnnealingLR(opt, steps)

    # i0 >= window - 1 so the window [t-window+1, t] lies wholly inside the
    # record.
    ranges = [(max(valid_range(len(w), tau, fs)[0], window - 1),
               valid_range(len(w), tau, fs)[1]) for w in runs]
    k = int(round(tau * 1e-3 * fs))
    hist, best = [], (np.inf, None)

    # The loss peak over EVERY step, not over the steps that get printed.
    #
    # The whole SD_FLOOR decision hangs on "is there still a spike", but this
    # loop only records the loss on steps divisible by val_every - 1 in 600 of
    # them in the sweep configuration. A spike shows up only if it happens to
    # land on such a step. The earlier +33/+190/+1076/+143000 figures were
    # spikes LUCKY ENOUGH to land on a printed step; the true peak may have been
    # larger, and a run that "saw no spike" proved nothing.
    loss_max, loss_max_step = -np.inf, 0

    for it in range(1, steps + 1):
        model.train()
        r = rng.integers(0, len(runs), batch)
        xb = np.empty((batch, 3, window), dtype=np.float32)
        yb = np.empty((batch, 3), dtype=np.float32)
        for j, ri in enumerate(r):
            i0, i1 = ranges[ri]
            t = rng.integers(i0, i1)
            xb[j] = runs[ri][t - window + 1:t + 1].T
            yb[j] = runs[ri][t + k]
        o = model(torch.from_numpy(xb))
        loss, parts = nll_loss(o, torch.from_numpy(yb), lam_acf,
                               lam_gate, gate_T)
        lv = loss.item()
        if lv > loss_max:
            loss_max, loss_max_step = lv, it
        opt.zero_grad()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        opt.step()
        sch.step()

        if it % val_every == 0 or it == steps:
            v = eval_model(model, val_runs, val_meta, tau, window,
                           EVAL_STRIDE_FAST, fs)
            hist.append({"step": it, "loss": lv, **parts,
                         "val_skill": v["skill"], "loss_max": loss_max,
                         "loss_max_step": loss_max_step})
            if verbose:
                print(f"  step {it:5d}  loss {lv:8.4f}  "
                      f"mse {parts['mse']:.5f}  acf {parts['acf']:.5f}  "
                      f"skill(val) {v['skill']:+.4f}  "
                      + (f"gate {parts['gate']:.4f}  " if lam_gate else "")
                      + f"max {loss_max:+.4g} @{loss_max_step}")
            if -v["skill"] < best[0]:
                best = (-v["skill"], {k2: v2.detach().clone()
                                      for k2, v2 in model.state_dict().items()})
    if best[1] is not None:
        model.load_state_dict(best[1])
    return hist


# =========================================================================
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default="dataset")
    ap.add_argument("--types", default="1,2,3,4,5,6,7")
    ap.add_argument("--window", type=float, default=30.0)
    ap.add_argument("--tau", type=int, default=HORIZON_PRIMARY_MS)
    ap.add_argument("--steps", type=int, default=3000)
    ap.add_argument("--batch", type=int, default=128)
    ap.add_argument("--lr", type=float, default=3e-3)
    ap.add_argument("--val-every", type=int, default=250)
    ap.add_argument("--seeds", default="0",
                    help="seed list, e.g. '0,1,2'. With several seeds a spread "
                         "table is printed too - see print_seed_summary.")
    ap.add_argument("--sd-floor", type=float, default=None,
                    help="floor on the window standard deviation in the logvar "
                         "term (m/s). Defaults to SD_FLOOR in moe.py. Above "
                         "exp(-LV_RANGE) = 0.0183 the floor replaces the -12 "
                         "clamp as the binding constraint and the ramp type "
                         "collapses - see the SD_FLOOR note.")
    ap.add_argument("--fs", type=float, default=TASK_FS,
                    help="working sample rate. W1-W4 use 50; W5 uses 20 to "
                         "match the sonic anemometer. Must divide SOURCE_FS.")
    ap.add_argument("--tc-grid", default=None,
                    help="'w5' selects TC_GRID_W5 (adds Tc = 40 and 60 s), or a "
                         "comma-separated list. Defaults to TC_GRID.")
    ap.add_argument("--lam-gate", type=float, default=0.0,
                    help="weight of the a-priori supervision on alpha. 0 = OFF, "
                         "and 0 must reproduce the baseline exactly (see "
                         "verify_gate_loss.py, test 1).")
    ap.add_argument("--gate-T", type=float, default=GATE_T,
                    help="temperature of the a-priori target. HELD FIXED, not "
                         "swept together with --lam-gate.")
    ap.add_argument("--final-stride", type=int, default=EVAL_STRIDE_FINAL)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    check_fs(a.fs)
    snapped = snap_horizons(a.fs)
    if a.tau not in snapped:
        raise SystemExit(
            f"tau = {a.tau} ms is not a whole number of steps at fs = {a.fs} Hz. "
            f"Valid horizons at this rate: {snapped}")

    types = [int(x) for x in a.types.split(",")]
    seeds = [int(x) for x in a.seeds.split(",")]
    W = int(round(a.window * a.fs))
    out = a.out or f"moe_w{int(a.window)}_t{a.tau}"

    print("=" * 78)
    print("W3 - PI-MoE")
    print(f"window {a.window:.0f} s ({W} samples)   tau = {a.tau} ms   "
          f"types {types}")
    from wind.moe import SD_FLOOR as _SDF
    print(f"overfitting threshold fixed in advance: "
          f"skill(train) - skill(val) > {OVERFIT_GAP}"
          f"   |   SD_FLOOR = {a.sd_floor if a.sd_floor is not None else _SDF}"
          f"\nfs = {a.fs} Hz   Tc grid = {tc_grid_of(a)}")
    print("=" * 78)

    t0 = time.time()
    tr, trm = load_all(a.dataset, types, "train", verbose=True, fs=a.fs)
    va, vam = load_all(a.dataset, types, "val", fs=a.fs)
    te, tem = load_all(a.dataset, types, "test", fs=a.fs)
    print(f"train {len(tr)} | val {len(va)} | test {len(te)} runs "
          f"({time.time()-t0:.1f} s)\n")

    all_seeds = []
    for seed in seeds:
        if len(seeds) > 1:
            print(f"\n{'-' * 78}\nSEED {seed}\n{'-' * 78}")
        model, n_par, one = run_one(a, seed, types, W, tr, trm, va, vam,
                                    te, tem, first=(seed == seeds[0]))
        all_seeds.append(one)

    if len(all_seeds) > 1:
        print_seed_summary(all_seeds, types)

    _save(a, out, model, n_par, types, seeds, all_seeds)
    print(f"\nWrote {out}.json / {out}.pt   ({time.time()-t0:.0f} s)")
    return 0


def run_one(a, seed, types, W, tr, trm, va, vam, te, tem, first):
    """One training run plus the full scoring. Returns (model, n_par,
    results)."""
    kw = {} if a.sd_floor is None else {"sd_floor": a.sd_floor}
    # THE SEED MUST BE SET BEFORE THE MODEL IS BUILT, not only inside train().
    #
    # This was a pre-existing bug, and it was measured: two fresh PROCESSES
    # constructing PIMoE without a seed gave two completely different weight
    # sets (parameter sums +0.347 and -10.536). torch.manual_seed() lived inside
    # train(), i.e. it ran AFTER the model had been initialised - so the `seed`
    # argument controlled batch sampling only, NOT initialisation.
    #
    # Two consequences:
    #   1. No W2-W5 checkpoint could be reproduced by re-running. The recorded
    #      "spread across seeds" is still valid as a measure of run-to-run
    #      variation, but the label "seed 0" did not identify anything.
    #   2. Worse for the lambda sweep: comparing lambda=0 against lambda>0
    #      across DIFFERENT initialisations mixes lambda's effect with
    #      initialisation noise. Against the +-0.02 spread measured on real
    #      wind, a +0.02 effect could not have been separated at all.
    # Seeding here makes the comparison PAIRED: at the same seed, lambda=0 and
    # lambda>0 start from exactly the same weights.
    torch.manual_seed(seed)
    model = PIMoE(a.tau, a.window, fs=a.fs, tc_grid=tc_grid_of(a), **kw)
    n_par = sum(p.numel() for p in model.parameters() if p.requires_grad)
    if first:
        print(f"{n_par/1000:.1f}k parameters, {len(model.expert_names)} experts: "
              f"{', '.join(model.expert_names)}\n")

    hist = train(model, tr, a.tau, W, a.steps, a.batch, a.lr, va, vam,
                 a.val_every, seed, fs=a.fs,
                 lam_gate=a.lam_gate, gate_T=a.gate_T)

    print("\nFinal scoring (stride %d)..." % a.final_stride)
    res = {}
    for name, (rr, mm) in (("train", (tr, trm)), ("val", (va, vam)),
                           ("test", (te, tem))):
        res[name] = eval_model(model, rr, mm, a.tau, W, a.final_stride,
                               a.fs)
        r = res[name]
        print(f"  {name:<5s} skill {r['skill']:+.4f}  median {r['skill_median']:+.4f}"
              f"  IQR [{r['skill_iqr'][0]:+.3f},{r['skill_iqr'][1]:+.3f}]"
              f"  RMSE {r['rmse']:.4f}")

    gap = res["train"]["skill"] - res["val"]["skill"]
    print(f"\nOverfitting gap: skill(train) - skill(val) = {gap:+.4f} "
          f"(threshold {OVERFIT_GAP})")
    if gap > OVERFIT_GAP:
        print("  >> OVER THRESHOLD. This window is short of data. Generate the "
              "600 s set:")
        print("     python3 python/generate_wind_dataset.py --out dataset600 \\")
        print("             --types 1,2,6,7 --duration 600 --seeds 1-300")
    else:
        print("  >> within threshold: no more data needed yet.")

    # --- per wind type, and alpha against the mixing ratio (type 7) ---
    print("\nPer wind type (test):")
    per_type, alpha_mix = {}, []
    for wt in types:
        sel = [i for i, m in enumerate(tem) if m["wt"] == wt]
        if not sel:
            continue
        rr = [te[i] for i in sel]
        mm = [tem[i] for i in sel]
        al = [] if wt == 7 else None
        r = eval_model(model, rr, mm, a.tau, W, a.final_stride, a.fs)
        per_type[wt] = r
        print(f"  {wt} {WIND_TYPES[wt]:<14s} skill {r['skill']:+.4f}  "
              f"median {r['skill_median']:+.4f}  "
              f"IQR [{r['skill_iqr'][0]:+.3f},{r['skill_iqr'][1]:+.3f}]")
        if wt == 7:
            predict_runs(model, rr, a.tau, W, a.final_stride * 4,
                         alpha_out=al, fs=a.fs)
            from wind.dataset import load_metadata
            md = load_metadata(pathlib.Path(a.dataset))
            by = {(r2["wind_type"], r2["seed"]): r2 for r2 in md["runs"]}
            for i, aa in zip(sel, al):
                p = by.get((7, tem[i]["seed"]), {})
                alpha_mix.append({"seed": tem[i]["seed"],
                                  "mix": p.get("mix"), "alpha": aa.tolist()})

    return model, n_par, {"seed": seed, "splits": res, "per_type": per_type,
                          "overfit_gap": gap, "history": hist,
                          "alpha_vs_mix": alpha_mix}


def print_seed_summary(all_seeds, types):
    """The spread across seeds - the condition for reporting a PER-TYPE number.

    Three runs at tau = 1000 ms differing ONLY in how the loss is bounded gave
    iec_gust +0.9197 / +0.6334 / +0.9867 and ramp +0.9509 / +0.9669 / +0.7629,
    while dryden stayed put to within 0.003. A spread of 0.35 on a reported
    number is far too large, so at the long horizon no per-type number can be
    drawn from a SINGLE run.

    This is exactly limitation 5 of the payload branch ("no error bars, one
    deterministic run per configuration"), already fixed at W2 with a
    per-run IQR. This function does the same for W3, but across SEEDS - because
    the spread here comes from initialisation and batch order, not from the
    data.
    """
    print(f"\n{'=' * 78}\nPOOLED OVER {len(all_seeds)} SEEDS (test)\n{'=' * 78}")
    print(f"{'type':<16s} {'mean':>11s} {'min':>9s} {'max':>9s} "
          f"{'spread':>9s}")
    for wt in types:
        v = [r["per_type"][wt]["skill"] for r in all_seeds
             if wt in r["per_type"]]
        if v:
            print(f"{WIND_TYPES[wt]:<16s} {np.mean(v):>+11.4f} {min(v):>+9.4f} "
                  f"{max(v):>+9.4f} {max(v) - min(v):>9.4f}")
    v = [r["splits"]["test"]["skill"] for r in all_seeds]
    print(f"{'TOTAL':<16s} {np.mean(v):>+11.4f} {min(v):>+9.4f} "
          f"{max(v):>+9.4f} {max(v) - min(v):>9.4f}")


def _clean(d):
    return {k: {k2: (list(v2) if isinstance(v2, tuple) else v2)
                for k2, v2 in v.items()} for k, v in d.items()}


def _save(a, out, model, n_par, types, seeds, all_seeds):
    last = all_seeds[-1]
    torch.save(model.state_dict(), out + ".pt")
    pathlib.Path(out + ".json").write_text(json.dumps({
        "window_s": a.window, "tau_ms": a.tau, "types": types, "seeds": seeds,
        "fs": a.fs, "tc_grid": list(tc_grid_of(a)),
        "sd_floor": model.sd_floor,
        "n_params": n_par, "expert_names": model.expert_names,
        "overfit_threshold": OVERFIT_GAP,
        "final_stride": a.final_stride,
        "runs": [{"seed": r["seed"], "overfit_gap": r["overfit_gap"],
                  "history": r["history"], "splits": _clean(r["splits"]),
                  "per_type": {str(k): v
                               for k, v in _clean(r["per_type"]).items()}}
                 for r in all_seeds],
        # The flat keys below keep the old shape so fig_gating.m and anything
        # else already reading this file still works - they refer to the LAST
        # seed.
        "overfit_gap": last["overfit_gap"], "history": last["history"],
        "splits": _clean(last["splits"]),
        "per_type": {str(k): v for k, v in _clean(last["per_type"]).items()},
        "alpha_vs_mix": last["alpha_vs_mix"],
    }, indent=1))


if __name__ == "__main__":
    sys.exit(main())
