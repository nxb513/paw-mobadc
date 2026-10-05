"""
generators.py -- six wind generators behind one interface.

===========================================================================
THE INTERFACE
===========================================================================
Every generator takes (n, dt, params, rng) and returns a dict of COMPONENTS:

    {'mean': (n,3), 'turb': (n,3), 'gust': (n,3), 'periodic': (n,3)}

A component that does not apply is absent. The total wind is the sum of the
components, computed by total().

The components are stored separately rather than only their sum, for three
reasons:
  1. W4 needs to know whether each run contains a gust event and where, in
     order to compute the EVENT-WINDOW metric (without it the gust effect is
     diluted in the global RMS - computed: 1% of the time -> a 2.3% change in
     RMS).
  2. composite = Dryden + gust + periodic; attributing the result to a
     component requires having the components.
  3. The spectral check can only be run on the 'turb' part alone; gust and
     ramp are deterministic, and mixing them in leaves nothing to compare
     against a formula.

===========================================================================
PARAMETERS: WHICH ARE [PAPER], WHICH ARE [NEW]
===========================================================================
All of this is [NEW] - Guo et al. 2020 has only a CONSTANT 1.0 N wind and no
turbulence model at all. So every constant below MUST be declared in the
paper. The source is recorded at each one.

Three choices need stating explicitly, because they follow from no standard:

  * V_ADVECT = 5 m/s. Dryden puts its corner frequency at Omega = omega/V, so
    V sets the correlation time Tc = L/V. Test 4's TRAJECTORY speed is
    1.26 m/s; using that would give Tc = L/1.26, i.e. 16 s to 159 s for
    L = 20..200 m, and the wind becomes a nearly static displacement. The wind
    field a UAV passes through depends on the RELATIVE velocity between the UAV
    and the air mass, not only on the speed along the trajectory, so V is taken
    as the mean wind speed = 5 m/s. With L = 20/50/100 m that gives
    Tc = 4/10/20 s.

  * sigma_u = sigma_v = sigma_w = I * V. MIL-F-8785C gives different sigma
    ratios per axis and per altitude; isotropy is used here so that I has one
    single meaning ("turbulence intensity"), which makes sweeping I a clean
    ablation. The departure from the MIL spec is a limitation that must be
    declared.

  * L_v = L_w = L_u / 2. This one DOES follow MIL-F-8785C at low altitude.
"""

import numpy as np

from .spectra import turbulence_uvw

# ---- Parameter grids, [NEW] ----
V_ADVECT = 5.0                    # m/s, advection speed = mean wind speed
L_GRID = (20.0, 50.0, 100.0)      # m   -> Tc = 4, 10, 20 s
I_GRID = (0.05, 0.10, 0.20)       # turbulence intensity

# IEC 61400-1 Extreme Operating Gust
EOG_T = 10.5                      # s, duration of one gust event
EOG_AMP = (1.0, 5.0)              # m/s, amplitude drawn uniformly in this range

WIND_TYPES = {
    1: "dryden",
    2: "von_karman",
    3: "iec_gust",
    4: "ramp",
    5: "periodic",
    6: "composite",
    7: "composite_mix",
}
# These codes are PERMANENTLY FIXED. They go into a Simulink Constant block and
# into dataset directory names; changing one shifts every dataset already
# generated. That is exactly what happened with payload_model. 0 = no wind
# (reproducing the baseline).

# The energy mixing grid for type 7: (turb, gust, periodic), summing to 1.
#
# WHY A SEPARATE TYPE RATHER THAN CHANGING TYPE 6
# Type 6 draws each component's amplitude independently, so the mixing ratio is
# a HIDDEN variable - every run has a different ratio that nobody chose. That is
# a REALISTIC mixture, and W2's results on it stand.
#
# But the Mixture-of-Experts claim is "the gate shifts weight with the regime",
# and that claim is only MEASURABLE if the regime is a controlled axis. For
# type 7 the mixing ratio is set in advance and written into the metadata, so
# alpha_1, alpha_2, alpha_3 can be plotted against the true
# (f_turb, f_gust, f_per). That plot is the evidence for the claim; without it
# MoE is just "one more gate".
#
# Adding a new type rather than changing type 6 leaves every W2 measurement
# intact, following the permanently-fixed-code convention.
MIX_GRID = (
    (1.00, 0.00, 0.00),
    (0.00, 1.00, 0.00),
    (0.00, 0.00, 1.00),
    (0.50, 0.50, 0.00),
    (0.50, 0.00, 0.50),
    (0.00, 0.50, 0.50),
    (0.34, 0.33, 0.33),
    (0.60, 0.20, 0.20),
    (0.20, 0.60, 0.20),
    (0.20, 0.20, 0.60),
)


# =========================================================================
#  Drawing parameters from a seed
# =========================================================================
def draw_params(wind_type, seed):
    """seed -> parameters. Deterministic, and written into the metadata.

    Domain randomisation: each seed is a DIFFERENT wind condition, not the same
    condition redrawn with different noise. Fixing (L, I) and varying only the
    seed would show the network ONE condition, and W4 would then be measuring
    "generalisation to another realisation" rather than "to another condition" -
    a far weaker statement.

    A separate RNG for the parameters, distinct from the signal RNG, so that
    changing the duration or the sample rate later does not change that seed's
    parameter set.
    """
    rng = np.random.default_rng([seed, 0xC0FFEE])
    p = {
        "wind_type": wind_type,
        "wind_type_name": WIND_TYPES[wind_type],
        "seed": int(seed),
        "V": V_ADVECT,
        "L": float(rng.choice(L_GRID)),
        "I": float(rng.choice(I_GRID)),
        "mean_dir_deg": float(rng.uniform(0.0, 360.0)),
    }
    p["sigma"] = p["I"] * p["V"]

    if wind_type == 7:
        p["mix"] = [float(x) for x in MIX_GRID[rng.integers(len(MIX_GRID))]]
    if wind_type in (3, 6, 7):
        p["eog_amp"] = float(rng.uniform(*EOG_AMP))
        p["eog_T"] = EOG_T
        p["n_eog"] = int(rng.integers(1, 4))       # 1..3 events per run
    if wind_type == 4:
        p["ramp_dv"] = float(rng.uniform(-4.0, 4.0))   # m/s, size of the change
        p["ramp_dur"] = float(rng.uniform(10.0, 60.0))
    if wind_type in (5, 6, 7):
        p["per_n"] = int(rng.integers(2, 5))
        p["per_f"] = rng.uniform(0.05, 1.0, size=p["per_n"]).tolist()  # Hz
        p["per_a"] = rng.uniform(0.2, 1.5, size=p["per_n"]).tolist()   # m/s
    return p


def _dir_vec(deg):
    """The mean wind's bearing in the horizontal plane; the z component is 0."""
    r = np.deg2rad(deg)
    return np.array([np.cos(r), np.sin(r), 0.0])


def _mean_field(n, p):
    return np.tile(p["V"] * _dir_vec(p["mean_dir_deg"]), (n, 1))


# =========================================================================
#  The six generators
# =========================================================================
def _turb(n, dt, p, rng, model):
    return turbulence_uvw(n, dt, p["sigma"], p["L"], p["V"], rng, model)


def gen_dryden(n, dt, p, rng):
    return {"mean": _mean_field(n, p), "turb": _turb(n, dt, p, rng, "dryden")}


def gen_von_karman(n, dt, p, rng):
    return {"mean": _mean_field(n, p), "turb": _turb(n, dt, p, rng, "von_karman")}


def eog_shape(t, T):
    """The Extreme Operating Gust of IEC 61400-1.

        v(t) = -0.37 sin(3 pi t/T) (1 - cos(2 pi t/T)),  0 <= t <= T

    Normalised so the peak is 1, with the amplitude applied outside - so that
    the 'eog_amp' parameter means an actual peak amplitude rather than a scale
    factor.
    """
    s = np.zeros_like(t)
    m = (t >= 0.0) & (t <= T)
    s[m] = -0.37 * np.sin(3.0 * np.pi * t[m] / T) * (1.0 - np.cos(2.0 * np.pi * t[m] / T))
    peak = np.abs(s).max()
    return s / peak if peak > 0 else s


def _eog_train(n, dt, p, rng):
    """n_eog gust events placed at random, without overlapping."""
    t = np.arange(n) * dt
    T_tot = n * dt
    g = np.zeros(n)
    starts = []
    for _ in range(p["n_eog"]):
        for _try in range(50):
            t0 = rng.uniform(0.05 * T_tot, T_tot - p["eog_T"] - 0.05 * T_tot)
            if all(abs(t0 - s) > 1.5 * p["eog_T"] for s in starts):
                starts.append(t0)
                break
    starts.sort()
    for t0 in starts:
        g += p["eog_amp"] * eog_shape(t - t0, p["eog_T"])
    return g, starts


def gen_iec_gust(n, dt, p, rng):
    g, starts = _eog_train(n, dt, p, rng)
    p["eog_starts"] = [float(s) for s in starts]
    return {"mean": _mean_field(n, p), "gust": np.outer(g, _dir_vec(p["mean_dir_deg"]))}


def gen_ramp(n, dt, p, rng):
    """A linear change in the mean wind speed, then held."""
    t = np.arange(n) * dt
    T_tot = n * dt
    t0 = rng.uniform(0.15 * T_tot, 0.6 * T_tot)
    r = np.clip((t - t0) / p["ramp_dur"], 0.0, 1.0) * p["ramp_dv"]
    p["ramp_t0"] = float(t0)
    return {"mean": _mean_field(n, p), "gust": np.outer(r, _dir_vec(p["mean_dir_deg"]))}


def gen_periodic(n, dt, p, rng):
    """A sum of sinusoids - a crude model of shedding behind an obstacle, or of
    rotor downwash."""
    t = np.arange(n) * dt
    s = np.zeros(n)
    for f, a in zip(p["per_f"], p["per_a"]):
        s += a * np.sin(2.0 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    return {"mean": _mean_field(n, p), "periodic": np.outer(s, _dir_vec(p["mean_dir_deg"]))}


def gen_composite(n, dt, p, rng):
    """Dryden + gust + periodic.

    The only NON-STATIONARY type, and the most important one for the paper's
    claim: a single time-invariant linear filter cannot both match the Dryden
    spectrum and keep up with a gust event. If learning wins anywhere, it wins
    here.
    """
    out = gen_dryden(n, dt, p, rng)
    g, starts = _eog_train(n, dt, p, rng)
    p["eog_starts"] = [float(s) for s in starts]
    out["gust"] = np.outer(g, _dir_vec(p["mean_dir_deg"]))
    out["periodic"] = gen_periodic(n, dt, p, rng)["periodic"]
    return out


def gen_composite_mix(n, dt, p, rng):
    """Like composite, but with the ENERGY RATIO between the three components
    SET IN ADVANCE.

    Each component is generated at its natural amplitude, its actual variance is
    measured, and it is then rescaled so its energy contribution is exactly
    (f_turb, f_gust, f_per) of a total variance sigma_tot^2 = (I*V)^2.

    Rescaled AFTER generation rather than by setting amplitudes beforehand,
    because a gust series' variance depends on how many events land in the
    record and a periodic series' variance depends on phase - set the amplitudes
    first and the realised ratio still drifts. Both the REQUESTED and the
    ACHIEVED ratio go into the metadata so they can be compared.
    """
    f_t, f_g, f_p = p["mix"]
    tot = p["sigma"] ** 2
    out = {"mean": _mean_field(n, p)}
    d = _dir_vec(p["mean_dir_deg"])

    raw = {}
    if f_t > 0:
        raw["turb"] = _turb(n, dt, p, rng, "dryden")
    if f_g > 0:
        g, starts = _eog_train(n, dt, p, rng)
        p["eog_starts"] = [float(x) for x in starts]
        raw["gust"] = np.outer(g, d)
    if f_p > 0:
        raw["periodic"] = gen_periodic(n, dt, p, rng)["periodic"]

    want = {"turb": f_t, "gust": f_g, "periodic": f_p}
    got = {}
    for k, v in raw.items():
        var = float(v.var(axis=0).sum())
        if var <= 0:
            continue
        out[k] = v * np.sqrt(want[k] * tot / var)
        got[k] = want[k]
    p["mix_achieved"] = [got.get("turb", 0.0), got.get("gust", 0.0),
                         got.get("periodic", 0.0)]
    return out


GENERATORS = {
    1: gen_dryden,
    2: gen_von_karman,
    3: gen_iec_gust,
    4: gen_ramp,
    5: gen_periodic,
    6: gen_composite,
    7: gen_composite_mix,
}

COMPONENTS = ("mean", "turb", "gust", "periodic")


def generate(wind_type, seed, duration, fs):
    """Generate one run. Returns (components, params).

    The signal RNG is separate from the parameter RNG (draw_params), and is
    seeded with [seed, wind_type] so that the same seed gives two different
    realisations under two wind types - otherwise 'Dryden seed 7' and 'composite
    seed 7' would share exactly one turbulence series, and a comparison between
    the two types would be correlated.
    """
    if wind_type not in GENERATORS:
        raise ValueError(f"invalid wind_type: {wind_type} (valid: 1..7)")
    n = int(round(duration * fs))
    dt = 1.0 / fs
    p = draw_params(wind_type, seed)
    p["duration"] = float(duration)
    p["fs"] = float(fs)
    rng = np.random.default_rng([seed, wind_type])
    comp = GENERATORS[wind_type](n, dt, p, rng)
    return comp, p


def total(comp):
    """The total wind = the sum of whichever components are present."""
    keys = [k for k in COMPONENTS if k in comp]
    out = np.zeros_like(comp[keys[0]])
    for k in keys:
        out += comp[k]
    return out
