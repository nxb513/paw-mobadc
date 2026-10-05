"""
moe.py -- PI-MoE: the physics-informed mixture-of-experts wind predictor.

===========================================================================
THE IDEA, AND WHY IT IS A CONCLUSION OF W2 RATHER THAN AN ARCHITECTURE BOLTED ON
===========================================================================
W2 measured, at the 140 ms operating horizon:

    dryden      ar +0.0104  <  wiener_pooled +0.0143  <  wiener +0.0294
    von_karman  ar +0.0787  <  wiener_pooled +0.0856  <  wiener +0.0933

`wiener` is given each run's TRUE L and sigma; `wiener_pooled` is the single
best linear filter for the whole mixture. The gap between those two - 79% on
Dryden, 53% on von Karman - is not "predicting better", it is KNOWING WHICH
REGIME YOU ARE IN.

So the learned part's job is not to be a better predictor. It is to be a
REGIME SELECTOR, and the architecture has to say that.

===========================================================================
PRECOMPUTED WIENER FILTERS INSTEAD OF SOLVING INSIDE THE NETWORK
===========================================================================
The obvious route is to let the network estimate T_c and solve the Wiener
equations internally. That is expensive (a Toeplitz solve every step) and
awkward to differentiate through.

It is also unnecessary. For a Dryden process on the u axis the autocovariance
is R(t) = sigma^2 exp(-t/T_c), and the Wiener coefficients a = R^-1 r DO NOT
DEPEND ON SIGMA: it cancels on both sides. The regime has exactly ONE
parameter - T_c.

So use a BANK of precomputed filters on a T_c grid and let the gate weight
that bank. Three consequences:

  * "Regime inference" BECOMES the gate. There is no separate block to
    explain, and alpha against true T_c is a direct piece of evidence.
  * Every expert is a FIXED linear filter -> one matrix multiply, with
    nothing that can train badly.
  * W2's ceiling lies INSIDE the space the model can represent: set the gate
    one-hot at the true T_c and the model EQUALS the wiener oracle. That is a
    structural property, and verify_moe.py measures it back.

The constant-velocity Kalman filter also reduces to a linear filter (it is LTI
in steady state), so ALL the physical experts are a single (E, P) matrix and
one einsum.

===========================================================================
THE ENCODER LOOKS AT LOW FREQUENCIES
===========================================================================
A 30 s window at 50 Hz is 1500 samples. Feeding all of it to the TCN is
expensive and pointless: the encoder's job is to RECOGNISE THE REGIME, and the
regime is low-frequency structure (T_c from 2 to 25 s, i.e. 0.04-0.5 rad/s).
So the encoder eats the window decimated to ENC_FS = 5 Hz, while the experts
still read the last P samples at FULL RATE.

That splits along the true nature of the two problems: regime recognition is
low-frequency, prediction is high-frequency. And it cuts the encoder cost
tenfold.
"""

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

from .baselines import alpha_beta, theoretical_acf, wiener_coef
from .generators import eog_shape
from .task import TASK_FS, horizon_steps

# ---- Fixed at W3 ----
TC_GRID = (2.0, 4.0, 7.0, 10.0, 15.0, 25.0)

# The EXTENDED grid for W5 (measured wind). TC_GRID itself is NOT changed, so
# every table already recorded for W2/W3/W4 still reproduces exactly - PIMoE
# takes tc_grid as an argument, so W5 simply passes this one in.
#
# The reason comes from W5's pilot check (docs/devlog/W5_REALWIND.md, section 6).
#
# The FIRST pilot used z = 119 m and found 73% of segments winning at the grid's
# upper edge. That figure was inflated: 119 m is just under the legal ceiling
# (120 m AGL), not a quadrotor's operating height. Repeating it over the real
# UAV band - 41/61/74 m pooled, 140 segments - gives:
#
#     the winning expert is von_Tc10, i.e. INSIDE the grid rather than at an edge
#     edge wins fall to 46% (39% upper + 7% lower)
#     bank ceiling +0.1897 against +0.1048 at 119 m
#     ACF percentiles 0.8/5.8/9.8/15.9/30.0 s
#
# So the case for extending the grid is MUCH WEAKER than it first looked, but it
# survives: 39% of segments still win at Tc = 25 s, the upper edge, so the grid
# is still truncated on that side. Two more values is four more experts, which
# is cheap.
#
# This decision is drawn from a MEASUREMENT OF THE WIND REGIME, not from
# prediction performance on measured wind (never scored at that point), so it
# does not violate the train-synthetic -> freeze -> test-real principle.
TC_GRID_W5 = (2.0, 4.0, 7.0, 10.0, 15.0, 25.0, 40.0, 60.0)   # s, covers L/V = 4..20 plus both edges
SPEC_MODELS = ("dryden", "von_karman")        # the bank covers BOTH spectral models
KALMAN_LAMBDAS = (0.05, 1.0)                  # two regimes: smooth, and fast-tracking

# Frequency bands for the PERIODIC experts. The generator draws per_f ~
# U(0.05, 1.0) Hz with 2-4 components per run, so a single-frequency expert is
# not enough: the optimal predictor of a SUM of sinusoids is the Wiener filter
# of the SUM's ACF, not a convex combination of single-tone predictors. So each
# expert covers a BAND, plus one wide band spanning the whole range as the
# "frequency unclear" expert.
PER_BANDS = ((0.05, 0.15), (0.15, 0.35), (0.35, 0.65), (0.65, 1.00),
             (0.05, 1.00))
PER_DAMP = 20.0        # s, damping so the Toeplitz problem is not singular

# Event durations for the GUST experts. The generator uses exactly 10.5 s
# (IEC 61400-1); the other two keep the model from being brittle when it meets a
# longer or shorter gust.
GUST_T = (5.0, 10.5, 20.0)

# A ridge loaded onto the two WAVEFORM expert families. Not a numerical trick
# but a physical assumption: an observed signal is never a pure pulse or a pure
# sinusoid - there is always turbulence underneath. R[0] *= (1 + eta) is
# equivalent to assuming a fraction eta of the energy is white.
#
# It is not optional. The Toeplitz matrix of an EOG pulse - a smooth, nearly
# compactly supported function - is close to singular: measured cond(R) = 2.1e19
# and max|a| = 4.4e14 at eta = 0, and that filter scores a skill of -1.1e17.
# With eta = 1e-4: cond 8.6e5, max|a| = 0.39, and skill +0.9985 (tau = 140 ms) /
# +0.9852 (tau = 1000 ms) on an EOG pulse train, against Kalman's +0.9885 /
# +0.6234.
#
# eta was chosen by measurement rather than by guessing: 1e-5 gives slightly
# more skill (+0.9914 at 1000 ms) but cond rises to 8.6e6 - too close to the
# edge for float32. At 1e-2 and above the filter is over-smoothed (+0.9398).
SHAPE_RIDGE = 1e-4
EXPERT_P = 150                                # 3 s of history for the linear experts
ENC_FS = 5.0                                  # encoder sample rate
ACF_LAGS = (1, 2, 4, 8, 16, 32, 64, 128, 256, 512)

# The range of the log-variance head, MEASURED IN window standard deviations.
#
# logvar = head + 2*log(sd). Originally the head was unbounded and the loss
# clamped the TOTAL at +-12. That does not protect anything: when sd is small
# (~0.1), 2*log(sd) is already -4.6, so a head of only -7 hits the clamp and
# exp(-logvar) reaches 1.6e5. Measured at tau = 1000 ms: the loss jumped to
# +33, +190, +40 on a few batches while skill(val) kept rising - the NLL
# exploding on the high-error batches.
#
# Bound THE HEAD ITSELF rather than the total, and bound it SOFTLY with tanh so
# the gradient does not vanish at the edge. With LV_RANGE = 4 the predicted
# standard deviation lies within [0.14, 7.4] times the window's own - wider than
# any real case - and exp(-head) is bounded by 55, so the NLL term is bounded in
# terms of the NORMALISED error rather than the absolute one.
LV_RANGE = 4.0

# A floor on the window standard deviation, in m/s.
#
# Normalising by the window's standard deviation turns the NLL term into
# (d/sd)^2 * exp(-lv_head). For the ramp type, outside the ramp interval the
# wind is EXACTLY CONSTANT so sd = 0, and at the EDGE of the interval the window
# is nearly flat while the target already sits on the slope - so d/sd explodes.
# That is a property of the DATA, not of the loss, so bounding lv_head does not
# rescue it: what drags logvar down is the 2*log(sd).
#
# With sd = 1e-3 and d = 0.1 the NLL term reaches 5.5e5. That is exactly the
# source of the measured spikes: +33 and +190 at first, then +1076 and +143000
# after I widened the outer clamp from -12 to -20 - a repair that made
# everything worse.
#
# This floor is used for the logvar TERM ONLY, NOT for normalising the input.
#
# I first applied it to both. The consequence was measurable immediately: the
# ramp type - precisely the type whose windows have near-zero variance - fell
# from +0.9669 to +0.7629. The reason is obvious in hindsight: a ramp window has
# a true sd of ~0.01, and dividing by a floor of 0.05 makes the encoder's input
# five times smaller, so the gate sees a far weaker signal and chooses worse.
#
# The floor exists to bound (d/sd)^2 in the loss. It has no business in input
# normalisation. So the two uses are split:
#     sd_raw  = the true standard deviation -> normalises the input, and
#               multiplies back at the output
#     sd_loss = max(sd_raw, SD_FLOOR)       -> enters the logvar term only
# The prediction is unchanged either way (sd cancels through the linear
# experts), but the encoder now sees the correctly normalised shape.
#
# -------------------------------------------------------------------------
# THE VALUE: 0.01, not 0.05. There is an ANALYTIC THRESHOLD, and it was measured.
# -------------------------------------------------------------------------
# A sample's weight in the NLL is exp(-lv) with
#     lv = clamp(lv_head + 2*log(sd_loss), -12, 12),   lv_head >= -LV_RANGE
# so the floor can only pull a window OUT of the outer clamp's saturated region
# when
#     -LV_RANGE + 2*log(floor) > -12   <=>   floor > exp(-LV_RANGE) = 0.0183 m/s
# Below that threshold the flattest windows stay pinned at e^12 by the clamp and
# the floor only lowers the weight of the MODERATELY flat ones. Above it, the
# floor replaces the clamp as the binding constraint.
#
# Swept 3 seeds x {0, 0.002, 0.01, 0.05} on the types 1/4/6 test set, measuring
# the loss peak over EVERY step (not only the printed ones):
#
#   tau = 1000 ms   loss peak               ramp            TOTAL
#     0             +60.3 / +71.7 / +64.3   +0.9784         +0.3051
#     0.01          +60.2 / +71.7 / +64.3   +0.9777         +0.3133
#     0.05           +4.5 /  +8.4 /  +6.5   +0.8510 (!)     +0.2885
#
# The threshold predicts both columns correctly. A floor of 0.01 leaves the loss
# peak AGREEING TO THREE FIGURES with no floor at all - it does not touch the
# spike. A floor of 0.05 cuts the spike by an order of magnitude, and THAT is
# where the ramp type collapses: +0.8510 with a seed spread of 0.3111
# (min +0.6676), the same mechanism already measured on the full set.
#
# So the real trade-off is NOT between "stable" and "accurate" at every floor
# value; it sits AT the 0.0183 threshold. 0.01 is chosen - below the threshold,
# with margin - because:
#   - the remaining spike (+72 against a typical loss of -6) is held by the -12
#     clamp, and NO harm from it could be measured: ramp, dryden, composite and
#     the TOTAL are all better at 0.01 than at 0.05, at both horizons;
#   - against no floor at all, 0.01 is slightly ahead at tau = 140 (TOTAL
#     +0.3210 against +0.3115, three non-overlapping seeds) and level at
#     tau = 1000.
#
# This CORRECTS the earlier conclusion "SD_FLOOR has a price: ramp -0.113". That
# comparison changed two things at once - added the floor AND moved the outer
# clamp from -20 to -12 - so nothing could be attributed to the floor. This
# sweep holds the clamp fixed at -12 and moves only the floor.
SD_FLOOR = 0.01


# =========================================================================
#  The linear expert bank
# =========================================================================
# The three axes are NOT the same process. MIL-F-8785C at low altitude gives
#     L_v = L_w = L_u / 2
# and the v/w spectral shape differs from u:
#     R_u(t) = sigma^2 e^(-t/T)            T = L_u/V
#     R_w(t) = sigma^2 e^(-t/T)(1 - t/2T)  T = L_w/V = L_u/2V
# so the optimal Wiener filter DIFFERS BY AXIS.
#
# This bank originally used one u-axis filter for all three axes. The leading
# coefficient differs: 0.966 against 0.905 at T_c = 4 s - only 6% - but the
# achievable skill on Dryden is just +0.03, so a 6% coefficient error is enough
# to flip the sign: measured -0.13 instead of predict_wiener's +0.036. When the
# ceiling is only 3%, every approximation is expensive.
AXIS_NAMES = ("u", "w", "w")
AXIS_L_SCALE = (1.0, 0.5, 0.5)


def wiener_filters(tau_ms, tc_grid=TC_GRID, p=EXPERT_P, fs=TASK_FS, V=5.0,
                   models=SPEC_MODELS):
    """(3, K*M, p): Wiener coefficients indexed by AXIS x (spectral model, T_c).
    Index 0 is the most recent sample.

    T_c is a parameter of the wind FIELD (T_c = L_u/V), shared across the three
    axes; the filters are per-axis. So the gate still has to choose only ONE
    regime.

    sigma is set to 1 because the coefficients do not depend on it (see the note
    at the top of this file).

    BOTH spectral models are present. The bank originally held Dryden only, and
    it was measured on the real set: von Karman scored +0.0394 while AR - a rival
    that knows nothing about wind models - scored +0.0787, so PI-MoE lost by
    NEARLY HALF. The reason is not subtle: the von Karman spectrum has exponents
    5/6 and 11/6, no Dryden filter matches it, and 1/7 of the data is von Karman.
    If a regime is missing from the bank the gate cannot select it - that is a
    limit of the bank, not of the learning.
    """
    k = horizon_steps(tau_ms, fs)
    out = np.empty((3, len(models) * len(tc_grid), p))
    for j in range(3):
        c = 0
        for mdl in models:
            for tc in tc_grid:
                L = tc * V * AXIS_L_SCALE[j]
                R = theoretical_acf(mdl, 1.0, L, V, AXIS_NAMES[j], p + k + 1, fs)
                out[j, c] = wiener_coef(R, p, k)
                c += 1
    return out


def periodic_acf(n_lags, f_lo, f_hi, fs=TASK_FS, T_damp=PER_DAMP):
    """The normalised ACF of a process flat over [f_lo, f_hi], with damping.

        R(t) = exp(-t/T_damp) * (sin(2*pi*f_hi*t) - sin(2*pi*f_lo*t))
                                / (2*pi*t*(f_hi - f_lo))

    i.e. the inverse Fourier transform of a rectangular spectrum. The ACF of a
    BAND rather than of a single frequency, for two reasons: a run contains 2-4
    sinusoids at random frequencies, and the optimal predictor of a sum is the
    filter of the sum's ACF - not the average of single-tone predictors.

    The exp(-t/T_damp) damping is regularisation: a pure rectangular spectrum
    gives a near-singular Toeplitz matrix at order 150.
    """
    t = np.arange(n_lags) / fs
    r = np.empty(n_lags)
    r[0] = 1.0
    tt = t[1:]
    r[1:] = ((np.sin(2 * np.pi * f_hi * tt) - np.sin(2 * np.pi * f_lo * tt))
             / (2 * np.pi * tt * (f_hi - f_lo)))
    return r * np.exp(-t / T_damp)


def eog_acf(n_lags, T_gust, fs=TASK_FS):
    """The normalised ACF of a train of EOG pulses placed at random times.

    For sparse events at independent times, the autocovariance is proportional
    to the AUTOCORRELATION OF ONE PULSE:

        R(t) ~ integral g(s) g(s+t) ds

    Random amplitude does not change the NORMALISED ACF, and random timing only
    scales it - so one EOG shape gives exactly one expert. That is why this bank
    needs a few values of T and no sweep over amplitude or phase.
    """
    m = int(round(T_gust * fs))
    t = np.arange(m) / fs
    g = eog_shape(t, T_gust)
    c = np.correlate(g, g, "full")[m - 1:]
    c = np.concatenate([c, np.zeros(max(0, n_lags - len(c)))])[:n_lags]
    return c / c[0] if c[0] > 0 else c


def shape_filters(tau_ms, p=EXPERT_P, fs=TASK_FS, bands=PER_BANDS,
                  gusts=GUST_T, ridge=SHAPE_RIDGE):
    """(K, p) and names: the PERIODIC and GUST experts.

    Both families act identically on the three axes: the generator lays gust and
    periodic down as a SCALAR signal times a direction vector, so the three axes
    share one waveform. Unlike turbulence, where MIL-F-8785C gives L_v = L_w =
    L_u/2 and every axis needs its own filter.
    """
    k = horizon_steps(tau_ms, fs)
    out, names = [], []
    def _load(R):
        R = R.copy()
        R[0] *= 1.0 + ridge
        return R

    for lo, hi in bands:
        out.append(wiener_coef(_load(periodic_acf(p + k + 1, lo, hi, fs)), p, k))
        names.append(f"per_{lo:g}-{hi:g}Hz")
    for T in gusts:
        out.append(wiener_coef(_load(eog_acf(p + k + 1, T, fs)), p, k))
        names.append(f"eog_T{T:g}")
    return np.stack(out), names


def kalman_cv_filter(tau_ms, lam, p=EXPERT_P, fs=TASK_FS):
    """The steady-state alpha-beta filter, written as an FIR with p taps.

    This filter is LTI in steady state, so it HAS an impulse response. Taking
    that response and truncating it to p taps gives an equivalent linear filter -
    the same form as Wiener, so both expert families share one matrix and one
    einsum.

    Truncation error: the response decays as |eig| < 1 (measured at W2:
    0.38-0.98 depending on lambda), so p = 150 taps is enough. verify_moe.py
    measures this back directly, against the full recursion.
    """
    a, b = alpha_beta(lam)
    dt = 1.0 / fs
    tau = tau_ms * 1e-3
    x = v = 0.0
    h = np.empty(p)
    for j in range(p):
        u = 1.0 if j == 0 else 0.0
        xp = x + v * dt
        e = u - xp
        x = xp + a * e
        v = v + (b / dt) * e
        h[j] = x + v * tau
    return h


def expert_bank(tau_ms, tc_grid=TC_GRID, lams=KALMAN_LAMBDAS, p=EXPERT_P,
                fs=TASK_FS, models=SPEC_MODELS):
    """(3, K+M, p) and one name per expert.

    The constant-velocity Kalman filter does not depend on the axis (it is a
    kinematic model, not a spectral one), so it is repeated across all three.
    """
    W = wiener_filters(tau_ms, tc_grid, p, fs, models=models)
    S, snames = shape_filters(tau_ms, p, fs)
    K = np.stack([kalman_cv_filter(tau_ms, l, p, fs) for l in lams])
    S = np.broadcast_to(S, (3,) + S.shape)
    K = np.broadcast_to(K, (3,) + K.shape)
    names = [f"{m[:3]}_Tc{t:g}" for m in models for t in tc_grid] \
        + snames + [f"kalman_l{l:g}" for l in lams]
    return np.concatenate([W, S, K], axis=1), names


# =========================================================================
#  The encoder
# =========================================================================
class TCN(nn.Module):
    """A causal TCN with exponentially growing dilation and mean pooling.

    Small on purpose. The number of INDEPENDENT windows per wind type is
    680-4300 (with a 30 s window: 680 at T_c = 20 s). A million-parameter
    encoder on ~1000 independent samples would memorise. Most of the capacity
    sits in the physical experts - not an aesthetic choice but what the data
    budget allows.
    """

    def __init__(self, c_in=3, c=32, n_layers=5, k=3, dropout=0.1):
        super().__init__()
        self.layers = nn.ModuleList()
        for i in range(n_layers):
            d = 2 ** i
            self.layers.append(nn.Sequential(
                nn.Conv1d(c_in if i == 0 else c, c, k, dilation=d,
                          padding=d * (k - 1)),
                nn.GELU(),
                nn.Dropout(dropout),
            ))
        self.k, self.c = k, c

    def forward(self, x):
        for lay in self.layers:
            y = lay(x)
            y = y[..., :x.shape[-1]]            # drop the future padding
            x = y if x.shape[1] != y.shape[1] else x + y
        return x.mean(dim=-1)


# =========================================================================
#  PI-MoE
# =========================================================================
class PIMoE(nn.Module):
    """Predict w(t+tau) from the window w(t-W:t).

    Returns a dict:
        yhat    (B,3)      the prediction
        logvar  (B,3)      log variance of the prediction error  -> used at W5
        alpha   (B,E+1)    gate weights; E physical experts + 1 residual expert
        acf     (B,nlag)   the WINDOW's ACF, a SELF-SUPERVISED auxiliary head
    """

    def __init__(self, tau_ms, window_s, fs=TASK_FS, c=32, n_layers=5,
                 tc_grid=TC_GRID, lams=KALMAN_LAMBDAS, p=EXPERT_P,
                 enc_fs=ENC_FS, dropout=0.1, acf_lags=ACF_LAGS,
                 models=SPEC_MODELS, sd_floor=SD_FLOOR):
        super().__init__()
        E, names = expert_bank(tau_ms, tc_grid, lams, p, fs, models)
        self.register_buffer("E", torch.tensor(E, dtype=torch.float32))
        self.expert_names = names + ["residual"]
        self.p = p
        self.sd_floor = sd_floor
        self.tau_ms = tau_ms
        self.window = int(round(window_s * fs))
        self.dec = max(1, int(round(fs / enc_fs)))
        self.lags = [l for l in acf_lags if l < self.window]

        self.enc = TCN(3, c, n_layers, dropout=dropout)
        self.gate = nn.Linear(c, len(self.expert_names))
        self.logvar_head = nn.Linear(c, 3)
        self.acf_head = nn.Linear(c, len(self.lags))
        # The residual expert: small, and it reads only a SHORT decimated
        # history - the long-range part is already in h.
        self.res_taps = 25
        self.res = nn.Sequential(
            nn.Linear(c + 3 * self.res_taps, 64), nn.GELU(), nn.Linear(64, 3))

        nn.init.zeros_(self.gate.bias)
        nn.init.zeros_(self.logvar_head.weight)
        nn.init.zeros_(self.logvar_head.bias)

    # ---- the window's empirical ACF: the TARGET for the self-supervised head
    def window_acf(self, xn):
        """xn: (B,3,W), already mean-removed and divided by its own std."""
        out = []
        for l in self.lags:
            a = xn[..., l:]
            b = xn[..., :-l]
            out.append((a * b).mean(dim=(1, 2)))
        return torch.stack(out, dim=-1)

    def forward(self, x):
        """x: (B, 3, W) at TASK_FS, in m/s, NOT yet normalised."""
        mu = x.mean(dim=-1, keepdim=True)
        sd = x.std(dim=-1, keepdim=True).clamp_min(1e-6)
        sd_loss = sd.clamp_min(self.sd_floor)
        xn = (x - mu) / sd

        h = self.enc(xn[..., ::self.dec])
        alpha = F.softmax(self.gate(h), dim=-1)

        xl = xn[..., -self.p:].flip(-1)                  # index 0 = most recent
        lin = torch.einsum("bcp,cep->bce", xl, self.E)    # (B,3,E)

        xs = xn[..., -self.res_taps * self.dec::self.dec]
        r = self.res(torch.cat([h, xs.reshape(xs.shape[0], -1)], dim=-1))

        yn = (lin * alpha[:, None, :-1]).sum(-1) + alpha[:, None, -1] * r
        lv = LV_RANGE * torch.tanh(self.logvar_head(h) / LV_RANGE)
        return {
            "yhat": yn * sd[..., 0] + mu[..., 0],
            "logvar": lv + 2 * torch.log(sd_loss[..., 0]),
            "alpha": alpha,
            "acf": self.acf_head(h),
            "acf_target": self.window_acf(xn).detach(),
            # EACH expert's own prediction, converted back to m/s. It equals
            # yhat exactly when the gate is one-hot on that expert, so
            # alpha_report.py can score all 22 experts in ONE forward pass
            # instead of 22 - and it scores them on the path the model actually
            # uses, not on a reimplementation of the FIR in another file.
            "yhat_expert": lin * sd + mu,                # (B,3,E)
            # The LAST sample of the window IS the persistence prediction, i.e.
            # the DENOMINATOR of skill. gate_oracle_loss() needs it to turn each
            # expert's error into a dimensionless quantity. Returned here rather
            # than recomputed in the loss: recomputing is a second path, and a
            # second path is how window_batch drifted by one step with nobody
            # seeing it.
            "persist": x[..., -1],                       # (B,3)
        }


# =========================================================================
#  Losses
# =========================================================================
GATE_T = 0.1                    # temperature of the a-priori target


def gate_oracle_loss(out, y, T=GATE_T):
    """Push alpha towards the expert that is ACTUALLY best on each window.

    ===================================================================
    WHY IT IS NEEDED
    ===================================================================
    As it stands alpha is NOT supervised at all: it learns only through the
    NLL's gradient, and the NLL is dominated by its variance term, so the
    routing signal is very weak. The consequences were measured:

      * synthetic tau=150 composite: the ceiling of +0.4211 is reached by a
        PERIODIC expert, but alpha puts 87% on TURBULENCE -> gate gain -0.3244
      * measured wind, dev, tau=150: alpha puts 0.651 on von_Tc25 while the
        ceiling is von_Tc7; at tau=400 it puts 0.799 on von_Tc15 while the
        ceiling is von_Tc10

    The same pattern three times: the right expert IS in the bank and the gate
    does not choose it. Gate loss = 17% of the ceiling at tau=150 and 23% at
    tau=400.

    ===================================================================
    THE TARGET, AND WHY IT IS DIVIDED BY PERSISTENCE
    ===================================================================
        SSE_k   = ||yhat_k - y||^2          expert k's error
        SSE_ref = ||persist - y||^2         the DENOMINATOR of skill itself
        r_k     = SSE_k / SSE_ref           dimensionless; r<1 means better
        q       = softmax(-r / T)           a soft target, ALREADY detached

    Dividing by SSE_ref makes it SCALE INVARIANT: without it, strong-wind
    windows (SSE larger by a factor of a hundred) would crush light-wind ones
    and this term would become "learn sigma" instead of "learn to choose". On
    measured wind sigma_u spans 0.12..5.27 m/s, so that is not a remote worry.

    SOFT rather than hard: the argmin on a SINGLE window is very noisy, and many
    experts are nearly tied (the Tc grid is dense). A one-hot target would make
    the gate chase noise.

    ===================================================================
    THE RESIDUAL EXPERT IS EXCLUDED FROM THE PRIOR - DELIBERATELY
    ===================================================================
    alpha has E+1 entries; the last is the LEARNED residual expert. Its error
    changes during training, and it may later become the best one - at which
    point the prior would push alpha onto it and destroy the "physical bank"
    story outright. So the cross-entropy is placed on alpha RENORMALISED over
    the physical part, and the residual's weight is left FREE.

    ===================================================================
    A KNOWN RISK
    ===================================================================
    On the rows where THE BANK IS MISSING A REGIME (synthetic composite
    tau=400: ceiling +0.1399 but AR +0.5486), forcing alpha towards the ceiling
    LOCKS the model to a low ceiling. And MoE has been measured ABOVE the
    ceiling in places (composite_mix tau=400: +0.2687 against a ceiling of
    +0.0846). So this is an auxiliary term with a small lambda, and lambda MUST
    be chosen by SKILL on val, not by "gate loss".
    """
    with torch.no_grad():
        ye = out["yhat_expert"]                       # (B,3,E)
        sse = ((ye - y[..., None]) ** 2).sum(1)       # (B,E)
        ref = ((out["persist"] - y) ** 2).sum(-1)     # (B,)
        # A nearly constant window gives ref ~ 0; skill is then undefined and
        # that window says nothing about choosing. Clamp it so it cannot produce
        # an enormous r and dominate the batch.
        ref = ref.clamp_min(1e-8)
        r = sse / ref[:, None]
        q = F.softmax(-r / T, dim=-1)                 # (B,E)
    a = out["alpha"][:, :-1]                          # drop the residual expert
    logp = torch.log(a / a.sum(-1, keepdim=True).clamp_min(1e-12) + 1e-12)
    return -(q * logp).sum(-1).mean()


def nll_loss(out, y, lam_acf=0.1, lam_gate=0.0, gate_T=GATE_T):
    """Gaussian NLL on the prediction, plus a self-supervised ACF auxiliary.

    NO spectral loss on the OUTPUT. The MMSE predictor is a conditional
    expectation, so its variance is SMALLER than the true signal's by exactly
    the error variance:

        var(yhat)/var(y) = skill

    On Dryden at 140 ms, skill = 0.029, i.e. the optimal prediction carries only
    3% of the signal's power. Forcing yhat's spectrum to match y's would push
    the model AWAY from MMSE towards a noisier and worse predictor. That is the
    statistical fact sitting behind the definition of skill itself.

    Spectral supervision is still useful - but it belongs on an auxiliary head
    reconstructing the INPUT's ACF. Placing it there has a second advantage: a
    window's ACF can be computed on ANY data, including measured wind that
    carries no T_c label. Supervising T_c and sigma directly, as first intended,
    would have cost the whole sim-to-real part of W4.
    """
    d = out["yhat"] - y
    # The -12 clamp corresponds to a minimum predicted standard deviation of
    # e^-6 = 2.5e-3 m/s - below the resolution of any wind problem. I once
    # widened it to -20 and that was a step backwards: exp(20) = 4.9e8 instead
    # of exp(12) = 1.6e5, and the spike went from +190 to +143000. The real
    # bounds are SD_FLOOR and LV_RANGE; this clamp is only the last net.
    lv = out["logvar"].clamp(-12, 12)
    nll = 0.5 * ((d ** 2) * torch.exp(-lv) + lv).sum(-1).mean()
    acf = F.mse_loss(out["acf"], out["acf_target"])
    total = nll + lam_acf * acf
    parts = {"nll": nll.item(), "acf": acf.item(),
             "mse": (d ** 2).mean().item(), "gate": 0.0}
    # lam_gate = 0 must take EXACTLY the old path, with no 0.0 term added:
    # adding a zero tensor still changes the graph and can change the result in
    # the last digit. The test "lam_gate = 0 reproduces the baseline to 1e-6" is
    # only meaningful if that path is genuinely unchanged.
    if lam_gate:
        g = gate_oracle_loss(out, y, gate_T)
        total = total + lam_gate * g
        parts["gate"] = g.item()
    return total, parts
