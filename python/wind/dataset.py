"""
dataset.py -- seed splits, writing files, metadata.

===========================================================================
THE SEED SPLIT
===========================================================================
    train      1 - 200
    validation 201 - 250
    test       251 - 300

Split by SEED, not by time interval. Cutting one run in half and taking the
first half as train and the second as test leaks: the two halves are one
realisation, with one parameter set (L, I), and they remain correlated across
a span of Tc at the join.

split_of() is the single source of which seed belongs to which set, and it is
written into the metadata AT GENERATION TIME - i.e. before any result has been
seen. Change the split after seeing a result and the old metadata is still
there as evidence.

===========================================================================
WHAT IS STORED
===========================================================================
This is a WIND dataset, not a force dataset:

    t, u, v, w                the total wind
    mean/turb/gust/periodic   each component separately
    wind_type, seed, L, V, I  the parameters

NO forces, NO ESO, NOTHING through Simulink. Those three layers are pure
functions of this data and can be regenerated at any time:

    wind velocity -> force model -> ESO (optional) -> predictor -> controller

So changing the force model, the ESO gains or the controller does NOT require
regenerating the dataset. That is the reason for the split.

===========================================================================
VERSION PROVENANCE
===========================================================================
The metadata records the SHA-256 of spectra.py + generators.py. If the
generator is later changed and old data is mixed with new, verify reports it.
The same lesson as sync_eml_blocks: two things that look identical but are not
is the hardest kind of error to find.
"""

import hashlib
import json
import pathlib

import numpy as np
from scipy.io import savemat

from .generators import COMPONENTS, WIND_TYPES, generate, total

SPLITS = {"train": (1, 200), "val": (201, 250), "test": (251, 300)}


def split_of(seed):
    for name, (lo, hi) in SPLITS.items():
        if lo <= seed <= hi:
            return name
    raise ValueError(
        f"seed {seed} is outside the split ranges (1-300). Extend SPLITS "
        f"explicitly rather than generating seeds outside them."
    )


HASHED_FILES = ("spectra.py", "generators.py")


def file_hashes():
    """Hash EACH FILE separately, so one knows WHICH file differs rather than
    only that something does.

    code_hash folds both files into one string - enough to detect a mismatch,
    not enough to fix it. When two machines produce two different hashes the
    next question is always "which file", and without this function that has to
    be guessed.
    """
    here = pathlib.Path(__file__).parent
    out = {}
    for name in HASHED_FILES:
        b = (here / name).read_bytes().replace(b"\r\n", b"\n")
        out[name] = (hashlib.sha256(b).hexdigest()[:16], len(b),
                     b.count(b"\n") + 1)
    return out


def code_hash():
    """The generator's fingerprint, INDEPENDENT OF LINE ENDINGS.

    This function originally hashed read_bytes() directly. The consequence: the
    same code generated on Windows (CRLF) and on Linux (LF) gave two different
    hashes, so the provenance mechanism raised a false alarm in exactly the case
    it is used for most - two different machines generating one dataset.

    CRLF is normalised to LF before hashing. A difference in CONTENT is still
    detected, which is the point; a difference in formatting is not.
    """
    h = hashlib.sha256()
    here = pathlib.Path(__file__).parent
    for name in HASHED_FILES:
        h.update((here / name).read_bytes().replace(b"\r\n", b"\n"))
    return h.hexdigest()[:16]


def estimate_size(n_types, n_seeds, duration, fs, n_comp=4):
    """Estimated bytes. float32, 3 axes, (1 total + n_comp components)."""
    per = duration * fs * 3 * 4 * (1 + n_comp)
    return n_types * n_seeds * per


def save_run(out_dir, wind_type, seed, duration, fs, dtype=np.float32):
    """Generate and write one run. Returns its metadata dict."""
    comp, p = generate(wind_type, seed, duration, fs)
    n = int(round(duration * fs))
    t = np.arange(n) / fs

    d = {"t": t.astype(dtype), "wind": total(comp).astype(dtype)}
    present = []
    for k in COMPONENTS:
        if k not in comp:
            continue
        present.append(k)
        if k == "mean":
            # The mean wind is constant by construction (_mean_field tiles one
            # vector). Store the 3-element vector rather than an (n,3) array:
            # a fifth of the space saved and nothing lost. Read it back with
            # repmat in MATLAB.
            d["mean"] = comp[k][0].astype(dtype)
        else:
            d[k] = comp[k].astype(dtype)

    # The parameters go into BOTH the .mat and metadata.json. The duplication
    # is deliberate: anyone opening a single file in MATLAB must see at once
    # which wind condition it is and which split it belongs to, without having
    # to cross-reference the metadata.
    p["split"] = split_of(seed)
    for k, v in p.items():
        d[k] = v

    name = WIND_TYPES[wind_type]
    sub = out_dir / name
    sub.mkdir(parents=True, exist_ok=True)
    savemat(str(sub / f"seed{seed:03d}.mat"), d, do_compression=True)

    p = dict(p)
    p["components"] = present
    p["code_hash"] = code_hash()
    p["file"] = f"{name}/seed{seed:03d}.mat"
    return p


def build(out_dir, wind_types, seeds, duration, fs, verbose=True):
    """Generate the whole dataset and write metadata.json."""
    out_dir = pathlib.Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Merge with the existing metadata rather than overwriting it. Adding one
    # wind type to an existing dataset directory is normal (type 7 was added
    # after W2), and overwriting metadata.json would label runs generated by the
    # OLD code with the NEW code_hash - exactly the error this provenance
    # mechanism exists to prevent.
    old = {}
    if (out_dir / "metadata.json").exists():
        prev = load_metadata(out_dir)
        old = {r["file"]: r for r in prev.get("runs", [])}
        if abs(prev.get("duration", duration) - duration) > 1e-9 or \
           abs(prev.get("fs", fs) - fs) > 1e-9:
            raise ValueError(
                f"the dataset already has duration={prev.get('duration')} "
                f"fs={prev.get('fs')}, which cannot be mixed with "
                f"duration={duration} fs={fs}. Use a different directory.")

    runs = []
    for wt in wind_types:
        for s in seeds:
            runs.append(save_run(out_dir, wt, s, duration, fs))
        if verbose:
            print(f"  {WIND_TYPES[wt]:<12s} {len(seeds)} seed")

    seen = {r["file"] for r in runs}
    runs = [r for f, r in old.items() if f not in seen] + runs

    types = {}
    for r in runs:
        types[str(r["wind_type"])] = r["wind_type_name"]

    meta = {
        "code_hash": code_hash(),
        "duration": duration,
        "fs": fs,
        "wind_types": types,
        "splits": {k: list(v) for k, v in SPLITS.items()},
        "n_runs": len(runs),
        "runs": runs,
    }
    (out_dir / "metadata.json").write_text(json.dumps(meta, indent=2))
    return meta


def load_metadata(out_dir):
    return json.loads((pathlib.Path(out_dir) / "metadata.json").read_text())
