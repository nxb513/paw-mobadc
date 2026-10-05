#!/usr/bin/env python3
"""
run_w4_crossmodel.py -- W4-A: generalisation ACROSS WIND MODELS.

    python3 python/verify_w4_split.py --dataset dataset       # RUN THIS FIRST

    # (main) ONE model, frozen, measured on several unseen types:
    python3 python/run_w4_crossmodel.py --dataset dataset --tau 1000 \
            --train-types 2,3,4,5 --test 1,6,7 --seeds 0,1,2 \
            --seen moe_w30_t1000.json --out w4_frozen_t1000

    # (secondary) leave-one-type-out: a SEPARATE model per type
    python3 python/run_w4_crossmodel.py --dataset dataset --tau 1000 \
            --holdout 1,2 --out w4_t1000

Writes <out>.json + <out>.mat + <out>_train<types>_s<seed>.pt

===========================================================================
TWO MODES, TWO DIFFERENT QUESTIONS
===========================================================================
--train-types 2,3,4,5 --test 1,6,7
    ONE model learns from the known regimes, is frozen, and then meets new
    turbulence types. This asks "does the predictor learn a general rule".

--holdout 1,2
    A SEPARATE model per type (leave-one-type-out). This answers "for EACH
    regime, does a model transfer to it" - a narrower question, paid for with
    one training run per type.

===========================================================================
STATED CORRECTLY: THIS MEASURES THE GATE, NOT THE HYPOTHESIS SPACE
===========================================================================
The expert bank is PHYSICS WRITTEN IN ADVANCE and does NOT depend on the
training data. So when Dryden is held out, the 6 Dryden filters are STILL in
the bank.

That is a property, not a leak - but it changes what may be claimed. What is
tested here is NOT "can the hypothesis space cover a new regime" (it can, by
construction), but:

    does the GATE pick the right expert for a regime it has NEVER SEEN?

And because the bank does not change, the BANK CEILING on the held-out type
does not change either. So the measurement separates cleanly:

    bank ceiling = what the model would reach if the gate chose perfectly
                   (fixed)
    gate loss    = ceiling - PI-MoE
    gate gain    = PI-MoE - uniform gate (alpha = 1/E, the "no gating"
                   ablation)

Reporting this as "the neural network generalises" would be overstating it.

===========================================================================
COMPONENT LEAKAGE - AND WHY TYPE LABELS MUST NOT BE USED
===========================================================================
composite (6) calls gen_dryden DIRECTLY, and composite_mix (7) calls
_turb(..., "dryden"). Two consequences:

  1. Hold type 1 out but train on 6/7 and the model STILL sees Dryden
     turbulence - the "transfer" number would look good for a false reason.
  2. The other way round: train on {2,3,4,5} and test on 6/7, and 6/7 are NOT
     "combinations of components already seen" - their turbulence IS Dryden,
     which is being held out. One cannot both hold Dryden out and have 6/7
     built only from seen components. print_seen_table() prints that plainly
     so the label cannot be taken wrongly.

The `components` field in the metadata does NOT rescue this: it is a STORAGE
KEY, not a physical label. gen_ramp files its linear ramp under the key
"gust" even though it is not an EOG. Inferring components from it is wrong.

So the map below is WRITTEN BY HAND from the code in generators.py, and
verify_w4_split.py checks it back by reading that same code.
"""

import argparse
import json
import pathlib
import sys
import time

import numpy as np
import torch
from scipy.io import savemat

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from alpha_report import GROUPS, scan  # noqa: E402
from wind.baselines import ARFitter, predict_ar  # noqa: E402
from wind.evaluate import eval_runs  # noqa: E402
from wind.generators import WIND_TYPES  # noqa: E402
from wind.moe import GATE_T, PIMoE, TC_GRID, TC_GRID_W5  # noqa: E402
from wind.task import (  # noqa: E402
    HORIZON_PRIMARY_MS, TASK_FS, check_fs, snap_horizons,
)
from train_moe import (  # noqa: E402
    EVAL_STRIDE_FINAL, OVERFIT_GAP, eval_model, load_all, masks_for, train,
)

ALL_TYPES = (1, 2, 3, 4, 5, 6, 7)

# The DISTINGUISHING physical component of each type -> which types contain it.
# Written by hand from generators.py; verify_w4_split.py checks it against the
# code.
#
#   turb_dryden : gen_dryden, gen_composite (which calls gen_dryden),
#                 gen_composite_mix (_turb(...,"dryden"))
#   turb_vk     : ONLY gen_von_karman  -> holding type 2 out is perfectly clean
#   eog         : gen_iec_gust, gen_composite, gen_composite_mix
#   ramp        : ONLY gen_ramp (a linear ramp, stored under the "gust" key but
#                 not an EOG)
#   periodic    : gen_periodic, gen_composite, gen_composite_mix
COMPONENT_OF = {
    1: "turb_dryden", 2: "turb_vk", 3: "eog", 4: "ramp", 5: "periodic",
    6: "combo", 7: "combo",
}
TYPES_WITH = {
    "turb_dryden": (1, 6, 7),
    "turb_vk": (2,),
    "eog": (3, 6, 7),
    "ramp": (4,),
    "periodic": (5, 6, 7),
    "combo": (6, 7),
}

# TWO DIFFERENT experiments, which must be labelled differently.
#
#   A1 - a regime NEVER SEEN. Holding out types 1..5 also removes every type
#        carrying that component. This is the real "cross-model" test.
#   A2 - an unseen COMBINATION of components that HAVE been seen. Hold out 6
#        and 7 while still training on 1/3/5. That is COMPONENT generalisation,
#        a different and weaker question. Reporting both in one table would
#        mislead the reader.
EXPERIMENT = {1: "A1", 2: "A1", 3: "A1", 4: "A1", 5: "A1", 6: "A2", 7: "A2"}

def tc_grid_of(a):
    """The Tc grid from the CLI. 'w5' -> TC_GRID_W5 (adds 40 and 60 s for
    measured wind)."""
    if a.tc_grid is None:
        return TC_GRID
    if a.tc_grid.lower() == "w5":
        return TC_GRID_W5
    return tuple(float(x) for x in a.tc_grid.split(","))


AR_ORDERS = (5, 20, 50, 100, 150)
AR_RIDGES = (1e-6, 1e-3, 1e-1, 1.0)


def train_types_for(h, available=ALL_TYPES):
    """The types training is allowed to use when type h is held out.

    `available` lets this run on a dataset holding only some of the types.
    Intersecting with what actually exists, rather than assuming all 7: assume
    all 7 when some are missing and the script dies halfway; skip them silently
    and the experiment changes meaning with nobody seeing it. So the set
    actually used is PRINTED.
    """
    drop = set(TYPES_WITH[COMPONENT_OF[h]])
    return tuple(t for t in ALL_TYPES if t not in drop and t in available)


def types_in(ds):
    """The wind types the dataset actually holds, read from its metadata."""
    md = json.loads((pathlib.Path(ds) / "metadata.json").read_text())
    return tuple(sorted({r["wind_type"] for r in md["runs"]}))


# =========================================================================
def ar_transfer(ds, train_types, h, tau, quick=0, fs=TASK_FS):
    """AR fitted on train_types, with (p, ridge) chosen on the VAL split of
    train_types, then measured on the TEST split of type h.

    A mandatory control. If AR collapses across regimes too, then "MoE
    collapses" says nothing about MoE - it says how hard the problem is.
    Hyperparameters are chosen on the val split of train_types and NOT on type
    h: choosing on h is leakage, and it is the kind of leakage that flatters a
    transfer number.
    """
    tr, _ = load_all(ds, train_types, "train", fs=fs)
    va, vam = load_all(ds, train_types, "val", fs=fs)
    te, tem = load_all(ds, (h,), "test", fs=fs)
    if quick:
        tr = tr[:quick]

    fitter = ARFitter(max(AR_ORDERS), [tau], fs=fs)
    for w in tr:
        fitter.add(w)

    best, best_c, best_p = np.inf, None, None
    for p in AR_ORDERS:
        for rg in AR_RIDGES:
            c = fitter.solve(p, tau, ridge=rg)
            m = eval_runs(va,
                          lambda w, i, c=c, p=p: predict_ar(w, c, p, tau, fs),
                          tau, masks_for(va, vam, fs), fs)
            if np.isfinite(m["rmse"]) and m["rmse"] < best:
                best, best_c, best_p = m["rmse"], c, (p, rg)
    r = eval_runs(te, lambda w, i: predict_ar(w, best_c, best_p[0], tau, fs),
                  tau, masks_for(te, tem, fs), fs)
    return r, best_p


# =========================================================================
def components_of(wt):
    """The physical components present in one wind type."""
    return {c for c, ts in TYPES_WITH.items() if c != "combo" and wt in ts}


def print_seen_table(tt, tests):
    """Print which components HAVE been seen and which have not, per test type.

    This is not decoration. The design "train {2,3,4,5} -> test {1,6,7}" is easy
    to mislabel: types 6 and 7 are NOT "combinations of components already
    seen", because their turbulence is Dryden and Dryden is being held out
    (gen_composite calls gen_dryden directly). One cannot both hold Dryden out
    and have 6/7 made only of seen components - the two statements contradict
    each other in the data. Printing this table makes the label impossible to
    take wrongly.
    """
    seen = set().union(*(components_of(t) for t in tt)) if tt else set()
    print(f"\n  Components SEEN when training on {list(tt)}:")
    print(f"    {sorted(seen)}")
    print("  Per test type:")
    for h in tests:
        comp = sorted(components_of(h))
        mark = [f"{c}{'' if c in seen else ' [UNSEEN]'}" for c in comp]
        n_new = sum(c not in seen for c in comp)
        lab = ("a COMPLETELY unseen regime" if n_new == len(comp)
               else "a combination: %d/%d components already seen"
               % (len(comp) - n_new, len(comp))
               if n_new else "EVERY component seen (only the combination is new)")
        print(f"    {h} {WIND_TYPES[h]:<15s} {', '.join(mark)}")
        print(f"      -> {lab}")


def fit_model(a, tt, seed, cache):
    """Train (or reuse) one model on the type set tt."""
    ds = pathlib.Path(a.dataset)
    W = int(round(a.window * a.fs))
    key = (tt, seed)
    if key in cache:
        return cache[key]

    tr, trm = load_all(ds, tt, "train", fs=a.fs)
    va, vam = load_all(ds, tt, "val", fs=a.fs)
    print(f"  train {len(tr)} | val {len(va)} runs")
    # THE SEED MUST BE SET BEFORE THE MODEL IS BUILT, not only inside train().
    #
    # This was a pre-existing bug, and it was measured: two fresh PROCESSES
    # constructing PIMoE without a seed gave two completely different weight
    # sets (parameter sums +0.347 and -10.536). torch.manual_seed() lived
    # inside train(), i.e. it ran AFTER the model had been initialised - so the
    # `seed` argument controlled batch sampling only, NOT initialisation.
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
    model = PIMoE(a.tau, a.window, fs=a.fs, tc_grid=tc_grid_of(a))
    hist = train(model, tr, a.tau, W, a.steps, a.batch, a.lr, va, vam,
                 a.val_every, seed, fs=a.fs,
                 lam_gate=a.lam_gate, gate_T=a.gate_T)

    st = a.final_stride
    gap = (eval_model(model, tr, trm, a.tau, W, st * 10, a.fs)["skill"]
           - eval_model(model, va, vam, a.tau, W, st * 10, a.fs)["skill"])
    print(f"  overfitting gap        {gap:+.4f} (threshold {OVERFIT_GAP})")

    # Save the checkpoint. Not doing so in the first version was a genuine
    # mistake: the model trained on {2,3,4,5} was thrown away after the run, so
    # measuring it on another test type meant retraining from scratch.
    if a.out:
        stem = f"{a.out}_train{''.join(map(str, tt))}_s{seed}"
        torch.save(model.state_dict(), stem + ".pt")
        # A sidecar so the checkpoint DESCRIBES ITSELF: alpha_report.load_model
        # and diag_w4_mix read it instead of being handed tau/window by hand -
        # and passing those by hand eventually means passing them wrongly, with
        # nothing to report it.
        pathlib.Path(stem + ".json").write_text(json.dumps({
            "tau_ms": a.tau, "window_s": a.window, "fs": a.fs,
            "tc_grid": list(tc_grid_of(a)),
            "sd_floor": model.sd_floor, "train_types": list(tt),
            "seed": seed, "steps": a.steps,
            # These must be in the sidecar: two checkpoints with the same name
            # but different lam_gate are TWO DIFFERENT models, and the ablation
            # table hangs on exactly that.
            "lam_gate": a.lam_gate, "gate_T": a.gate_T,
            "expert_names": model.expert_names}, indent=1))
        print(f"  saved {stem}.pt / .json")

    cache[key] = (model, hist, gap)
    return cache[key]


def eval_type(a, model, tt, h, ar_cache):
    """Measure a FROZEN model on one wind type."""
    ds = pathlib.Path(a.dataset)
    W = int(round(a.window * a.fs))
    st = a.final_stride
    te, tem = load_all(ds, (h,), "test", fs=a.fs)
    mk = masks_for(te, tem, a.fs)

    r = eval_model(model, te, tem, a.tau, W, st, a.fs)
    al, rows_model, rows_exp, rows_uni = scan(model, te, a.tau, W, st,
                                              masks=mk, fs=a.fs)

    from wind.task import aggregate
    agg_exp = [aggregate([rows_exp[i][e] for i in range(len(te))])
               for e in range(len(model.expert_names) - 1)]
    sk_exp = np.array([g["skill"] for g in agg_exp])
    k = int(sk_exp.argmax())
    r_uni = aggregate(rows_uni)

    # Two routes to the same number must agree. eval_model and scan score
    # through two different pieces of code; if they disagree, every number in
    # this table is suspect. Exactly this class of error already happened in
    # window_batch.
    s_scan = aggregate(rows_model)["skill"]
    if abs(s_scan - r["skill"]) > 1e-6:
        raise SystemExit(
            f"eval_model {r['skill']:.6f} differs from scan {s_scan:.6f} - "
            "the two scoring paths have diverged, do not trust this table")

    # AR does not depend on the model's seed - fit once and reuse. Before
    # this, three seeds refitted it three identical times.
    ak = (tt, h, a.tau, a.fs)
    if ak not in ar_cache:
        ar_cache[ak] = ar_transfer(ds, tt, h, a.tau, a.quick, a.fs)
    r_ar, ar_p = ar_cache[ak]

    seen = set().union(*(components_of(t) for t in tt)) if tt else set()
    n_new = sum(c not in seen for c in components_of(h))

    gmask = np.array([[f(n) for n in model.expert_names] for _, f in GROUPS])
    print(f"\n  --- test on {h} {WIND_TYPES[h]} "
          f"({len(te)} runs, {n_new} unseen components) ---")
    print(f"    PI-MoE               {r['skill']:+.4f}   RMSE {r['rmse']:.4f}")
    print(f"    uniform gate (none)  {r_uni['skill']:+8.4f}")
    # AR_ORDERS counts SAMPLES, not seconds: the same p spans 2.5x longer at
    # 20 Hz than at 50 Hz. The memory length in seconds is printed as well, so
    # a comparison across the two rates is not misread as "AR got better".
    print(f"    AR                   {r_ar['skill']:+.4f}   (p,ridge)={ar_p}"
          f"   memory {ar_p[0] / a.fs:.2f} s")
    print(f"    bank ceiling         {sk_exp[k]:+.4f} ({model.expert_names[k]})")
    print(f"    gate loss            {sk_exp[k] - r['skill']:+.4f}")
    print(f"    gate gain            {r['skill'] - r_uni['skill']:+.4f}"
          f"   <- PI-MoE minus uniform gate")
    if np.isfinite(r.get("skill_event", np.nan)):
        print(f"    [events] MoE {r['skill_event']:+.4f}  "
              f"uniform {r_uni['skill_event']:+.4f}  "
              f"AR {r_ar['skill_event']:+.4f}  ceiling {agg_exp[k]['skill_event']:+.4f}")
    top = np.argsort(al.mean(0))[::-1][:4]
    print("    alpha: " + "  ".join(
        f"{model.expert_names[j]}={al.mean(0)[j]:.3f}" for j in top))

    return {
        "test_type": h, "test_name": WIND_TYPES[h],
        "train_types": list(tt), "n_components_unseen": n_new,
        "components": sorted(components_of(h)),
        "moe": r["skill"], "moe_rmse": r["rmse"],
        "moe_median": r["skill_median"], "moe_iqr": list(r["skill_iqr"]),
        "uniform_gate": r_uni["skill"],
        "ar": r_ar["skill"], "ar_order_ridge": list(ar_p),
        "bank_ceiling": float(sk_exp[k]),
        "bank_ceiling_expert": model.expert_names[k],
        "gate_loss": float(sk_exp[k] - r["skill"]),
        "gate_gain": float(r["skill"] - r_uni["skill"]),
        "moe_event": r.get("skill_event"),
        "uniform_gate_event": r_uni.get("skill_event"),
        "ar_event": r_ar.get("skill_event"),
        "bank_ceiling_event": agg_exp[k].get("skill_event"),
        "alpha_mean": al.mean(0).tolist(),
        "alpha_group": (al.mean(0) @ gmask.T).tolist(),
        "expert_names": model.expert_names,
    }


# =========================================================================
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default="dataset")
    ap.add_argument("--train-types", default=None,
                    help="ONE model trained on these types, frozen, then "
                         "measured on --test. E.g. '2,3,4,5'.")
    ap.add_argument("--test", default=None,
                    help="the types the frozen model is measured on, e.g. "
                         "'1,6,7'. Only with --train-types.")
    ap.add_argument("--holdout", default=None,
                    help="leave-one-type-out mode: a separate model per type. "
                         "E.g. '1,2'. Not to be combined with --train-types.")
    ap.add_argument("--window", type=float, default=30.0)
    ap.add_argument("--tau", type=int, default=HORIZON_PRIMARY_MS)
    ap.add_argument("--steps", type=int, default=3000)
    ap.add_argument("--batch", type=int, default=128)
    ap.add_argument("--lr", type=float, default=3e-3)
    ap.add_argument("--val-every", type=int, default=500)
    ap.add_argument("--seeds", default="0")
    ap.add_argument("--fs", type=float, default=TASK_FS,
                    help="working sample rate. W1-W4 use 50; the 20 Hz control "
                         "of W5 uses 20.")
    ap.add_argument("--tc-grid", default=None,
                    help="'w5' selects TC_GRID_W5 (adds Tc = 40 and 60 s).")
    ap.add_argument("--lam-gate", type=float, default=0.0,
                    help="weight of the a-priori supervision on alpha. 0 = OFF, "
                         "and 0 must reproduce the baseline exactly (see "
                         "verify_gate_loss.py, test 1).")
    ap.add_argument("--gate-T", type=float, default=GATE_T,
                    help="temperature of the a-priori target. HELD FIXED, not "
                         "swept together with --lam-gate.")
    ap.add_argument("--final-stride", type=int, default=EVAL_STRIDE_FINAL)
    ap.add_argument("--quick", type=int, default=0,
                    help="use only N training runs for AR - for smoke-testing "
                         "the pipeline")
    ap.add_argument("--seen", default=None,
                    help="W3's moe_w30_t{tau}.json, for the 'seen' column")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    check_fs(a.fs)
    snapped = snap_horizons(a.fs)
    if a.tau not in snapped:
        raise SystemExit(f"tau = {a.tau} ms is not a whole number of steps at "
                         f"fs = {a.fs} Hz. Valid horizons: {snapped}")

    if bool(a.train_types) == bool(a.holdout):
        raise SystemExit("choose EXACTLY ONE of: --train-types (+ --test) "
                         "or --holdout")
    if a.train_types and not a.test:
        raise SystemExit("--train-types requires --test")

    avail = types_in(a.dataset)
    seeds = [int(x) for x in a.seeds.split(",")]
    a.out = a.out or f"w4_t{a.tau}"
    t0 = time.time()

    # --- both modes reduce to one job list: (training set, test types)
    if a.train_types:
        tt = tuple(int(x) for x in a.train_types.split(","))
        tests = [int(x) for x in a.test.split(",")]
        jobs = [(tt, tests)]
        overlap = sorted(set(tt) & set(tests))
        if overlap:
            raise SystemExit(
                f"type {overlap} is in both --train-types and --test")
    else:
        hold = [int(x) for x in a.holdout.split(",")]
        jobs = [(train_types_for(h, avail), [h]) for h in hold]

    bad = sorted({t for tt_, ts in jobs for t in list(tt_) + ts
                  if t not in avail})
    if bad:
        raise SystemExit(f"the dataset has no type {bad}. It has: {list(avail)}")

    seen = {}
    if a.seen:
        S = json.loads(pathlib.Path(a.seen).read_text())
        if S["tau_ms"] != a.tau:
            raise SystemExit(f"--seen is tau = {S['tau_ms']} ms while this run "
                             f"is tau = {a.tau} ms - the two columns are not "
                             "comparable")
        for r in S["runs"]:
            for k, v in r["per_type"].items():
                seen.setdefault(int(k), []).append(v["skill"])

    print(f"{'=' * 78}\nW4-A  generalisation across wind models\n"
          f"window {a.window} s   tau = {a.tau} ms   fs = {a.fs} Hz\n"
          f"seeds {seeds}   Tc grid = {tc_grid_of(a)}\n{'=' * 78}")

    rows, cache, ar_cache = [], {}, {}
    for tt, tests in jobs:
        print(f"\n{'=' * 78}\nTRAIN on {list(tt)}  ->  MEASURE on {tests}"
              f"\n{'=' * 78}")
        print_seen_table(tt, tests)
        for sd in seeds:
            print(f"\n  --- seed {sd} ---")
            model, hist, gap = fit_model(a, tt, sd, cache)
            for h in tests:
                r = eval_type(a, model, tt, h, ar_cache)
                r |= {"seed": sd, "overfit_gap": gap}
                rows.append(r)

    # ---------------- summary table ----------------
    print(f"\n\n{'=' * 78}\nW4-A  SUMMARY  (tau = {a.tau} ms, "
          f"{len(seeds)} seeds)\n{'=' * 78}")
    ev = any(r.get("moe_event") is not None and np.isfinite(r["moe_event"])
             for r in rows)
    hdr = (f"{'test':<15s} {'unseen':>9s} {'PI-MoE':>16s} {'uniform':>9s} "
           f"{'AR':>9s} {'ceiling':>8s} {'gate gain':>10s}")
    if a.seen:
        hdr += f" {'MoE seen':>12s}"
    print(hdr)
    order = []
    for r in rows:
        if r["test_type"] not in order:
            order.append(r["test_type"])
    for h in order:
        rs = [r for r in rows if r["test_type"] == h]
        m = [r["moe"] for r in rs]
        ms = f"{np.mean(m):+.4f}" + (f" ±{np.std(m):.4f}" if len(m) > 1 else "")
        line = (f"{WIND_TYPES[h]:<15s} {rs[0]['n_components_unseen']:>9d} "
                f"{ms:>16s} {np.mean([r['uniform_gate'] for r in rs]):+9.4f} "
                f"{np.mean([r['ar'] for r in rs]):+9.4f} "
                f"{np.mean([r['bank_ceiling'] for r in rs]):+8.4f} "
                f"{np.mean([r['gate_gain'] for r in rs]):+10.4f}")
        if a.seen:
            sv = seen.get(h)
            line += f" {np.mean(sv):+12.4f}" if sv else f" {'—':>12s}"
        print(line)

    if ev:
        print(f"\n{'test (events +-3 s)':<20s} {'PI-MoE':>9s} {'uniform':>9s} "
              f"{'AR':>9s} {'ceiling':>8s}")
        for h in order:
            rs = [r for r in rows if r["test_type"] == h
                  and r.get("moe_event") is not None
                  and np.isfinite(r["moe_event"])]
            if not rs:
                continue
            print(f"{WIND_TYPES[h]:<20s} "
                  f"{np.mean([r['moe_event'] for r in rs]):+9.4f} "
                  f"{np.mean([r['uniform_gate_event'] for r in rs]):+9.4f} "
                  f"{np.mean([r['ar_event'] for r in rs]):+9.4f} "
                  f"{np.mean([r['bank_ceiling_event'] for r in rs]):+8.4f}")

    print("\nHow to read this:")
    print("  'unseen' = how many physical components of the test type are NOT")
    print("  in the training set. 0 means only the COMBINATION is new.")
    print("  'ceiling' does NOT move with the training set - the bank is fixed")
    print("  physics. 'gate loss' = ceiling - MoE is what the gate gives away.")
    print("  'gate gain' = MoE - uniform: what the CHOOSING contributes,")
    print("  separated from what the bank contributes. Negative means choosing")
    print("  is worse than not choosing.")
    print("  Compare MoE against AR: if AR collapses too, the collapse is a")
    print("  property of the problem and not of MoE.")

    d = {"tau_ms": a.tau, "window_s": a.window, "seeds": seeds,
         "fs": a.fs, "tc_grid": list(tc_grid_of(a)), "steps": a.steps, "mode": "frozen" if a.train_types else "holdout",
         "jobs": [{"train_types": list(t), "test": ts} for t, ts in jobs],
         "rows": rows,
         "types_with": {k: list(v) for k, v in TYPES_WITH.items()}}
    pathlib.Path(a.out + ".json").write_text(json.dumps(d, indent=1))
    savemat(a.out + ".mat", {
        "test_type": np.array(order),
        "test_name": np.array([WIND_TYPES[h] for h in order], dtype=object),
        "n_unseen": np.array([[r["n_components_unseen"] for r in rows
                               if r["test_type"] == h][0] for h in order]),
        **{k: np.array([np.mean([r[k] for r in rows if r["test_type"] == h])
                        for h in order])
           for k in ("moe", "uniform_gate", "ar", "bank_ceiling",
                     "gate_loss", "gate_gain")},
        "moe_std": np.array([np.std([r["moe"] for r in rows
                                     if r["test_type"] == h]) for h in order]),
        "moe_seen": np.array([np.mean(seen[h]) if seen.get(h) else np.nan
                              for h in order]),
        "tau_ms": a.tau})
    print(f"\nWrote {a.out}.json / {a.out}.mat   ({time.time() - t0:.0f} s)")


if __name__ == "__main__":
    main()
