"""
loader.py -- read the W1 dataset into the shape the prediction task needs.

Reading 1800 .mat files for every experiment is unusable: the reading alone
takes longer than a baseline's entire computation. So read once, decimate to
task.TASK_FS, and cache to .npz.

The cache lives in dataset/_cache/ and is labelled with the generator's
code_hash. If the generator changes and the dataset has not been regenerated -
or the other way round - the cache name does not match and it is rebuilt from
scratch instead of silently returning stale numbers. That is exactly the class
of error the payload branch hit: sync_eml_blocks reported 20/20 matching while
a Constant block pointed at the wrong variable, because the check looked at
CODE and not at VALUES.
"""

import pathlib

import numpy as np
from scipy.io import loadmat

from .dataset import load_metadata
from .task import DECIMATE, SOURCE_FS, TASK_FS


def _read_run(path, decimate):
    d = loadmat(str(path))
    w = np.asarray(d["wind"], dtype=np.float32)[::decimate]
    ev = np.atleast_1d(np.asarray(d.get("eog_starts", []), float)).ravel()
    return w, ev, float(np.ravel(d.get("eog_T", [0.0]))[0])


def load_group(dataset_dir, wind_type, split, use_cache=True, verbose=False,
               fs=None):
    """Returns a dict with:
         w        (n_runs, n, 3) float32 at TASK_FS
         seeds    (n_runs,)
         events   a list of arrays of gust start times [s]
         eog_T    float
    """
    dataset_dir = pathlib.Path(dataset_dir)
    meta = load_metadata(dataset_dir)

    # fs = None -> TASK_FS (50 Hz, W1-W4). W5 passes 20.0.
    #
    # The dataset is stored on disk at 200 Hz and the decimation happens HERE,
    # at read time. So changing the working rate does NOT require regenerating
    # the dataset: 200/50 = 4 and 200/20 = 10, both exact, so no interpolation
    # is involved.
    fs = TASK_FS if fs is None else float(fs)
    src_fs = float(meta["fs"])
    dec = src_fs / fs
    if abs(dec - round(dec)) > 1e-9:
        raise ValueError(
            f"the dataset's fs ({src_fs} Hz) is not an exact multiple of the "
            f"working fs ({fs} Hz). A non-integer ratio would need "
            f"interpolation, and interpolation invents high-frequency content."
        )
    dec = int(round(dec))
    if src_fs != SOURCE_FS and verbose:
        print(f"  [note] the dataset is at {src_fs:.0f} Hz, not {SOURCE_FS:.0f}")

    runs = [r for r in meta["runs"]
            if r["wind_type"] == wind_type and r["split"] == split]
    if not runs:
        raise ValueError(f"no runs found: type {wind_type}, split {split}")

    # fs MUST appear in the cache name. Without it, a read at 20 Hz silently
    # returns the 50 Hz array cached earlier - right size, right dtype, wrong
    # rate, and nothing reports an error. The old cache name used a fixed
    # TASK_FS, so this would have fired the first time W5 ran on a dataset
    # already read at 50 Hz.
    cache = (dataset_dir / "_cache" /
             f"wt{wind_type}_{split}_fs{fs:.0f}_{meta['code_hash']}.npz")
    if use_cache and cache.exists():
        z = np.load(cache, allow_pickle=True)
        return {"w": z["w"], "seeds": z["seeds"], "eog_T": float(z["eog_T"]),
                "events": list(z["events"])}

    W, seeds, events, eog_T = [], [], [], 0.0
    for r in runs:
        w, ev, T = _read_run(dataset_dir / r["file"], dec)
        W.append(w)
        seeds.append(r["seed"])
        events.append(ev)
        eog_T = max(eog_T, T)
    out = {"w": np.stack(W), "seeds": np.array(seeds),
           "events": events, "eog_T": eog_T}

    if use_cache:
        cache.parent.mkdir(parents=True, exist_ok=True)
        np.savez_compressed(
            cache, w=out["w"], seeds=out["seeds"], eog_T=eog_T,
            events=np.array(events, dtype=object),
        )
    if verbose:
        print(f"  type {wind_type} {split:<5s}: {out['w'].shape[0]} runs, "
              f"{out['w'].shape[1]} samples @ {fs:.0f} Hz")
    return out


def decimation_loss(dataset_dir, wind_type=6, seed=None):
    """The fraction of variance lost decimating from SOURCE_FS to TASK_FS.

    Decimating without filtering ALIASES the spectrum above the new Nyquist
    rather than removing it, so the variance is nearly unchanged - what needs
    measuring is whether it moves at all. The wind's content is below ~2 Hz and
    the new Nyquist is 25 Hz, so the expectation is < 1%. That number is checked
    by verify_task_spec.py rather than argued.
    """
    meta = load_metadata(pathlib.Path(dataset_dir))
    runs = [r for r in meta["runs"] if r["wind_type"] == wind_type]
    if seed is not None:
        runs = [r for r in runs if r["seed"] == seed]
    d = loadmat(str(pathlib.Path(dataset_dir) / runs[0]["file"]))
    w = np.asarray(d["wind"], float)
    dec = int(round(float(meta["fs"]) / TASK_FS))
    v0 = w.var(axis=0).sum()
    v1 = w[::dec].var(axis=0).sum()
    return abs(v1 - v0) / v0
