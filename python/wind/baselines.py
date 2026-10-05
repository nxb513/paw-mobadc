"""
baselines.py -- the four classical predictors for W2.

===========================================================================
FOUR METHODS AND WHAT EACH IS FOR
===========================================================================
  persistence   w_hat(t+tau) = w(t).  The denominator of every skill score; it
                lives in task.py rather than here, because it is part of the
                MEASUREMENT.

  ar            A VAR(p) linear regression, LEARNED from the training set with
                p chosen on validation. This is the fair rival: it knows nothing
                about wind models, only the data - exactly the condition W3's
                learned predictor will face.

  wiener        The OPTIMAL linear predictor, computed from each run's TRUE
                spectrum (given L and I). This is a CEILING, not a rival.

  kalman_cv     The constant-velocity Kalman filter (alpha-beta). The classical
                rival for the NON-STATIONARY types - ramp and gust - where the
                Dryden model is wrong and wiener does not apply.

===========================================================================
WHY "KALMAN WITH THE RIGHT MODEL" IS WRITTEN AS A WIENER FILTER
===========================================================================
For a STATIONARY Gaussian process observed WITHOUT measurement noise, the
steady-state Kalman filter and the Wiener predictor are THE SAME operator. The
current model has no measurement noise (init_MOBADC_params.m says so), so
running the Kalman recursion and solving the normal equations directly give the
same answer - they differ only in effort and in how much can go wrong.

Solving directly has one decisive advantage: it uses the THEORETICAL
autocovariance, computed from the Dryden/von Karman closed-form spectrum,
rather than estimated from data. So it really is a theoretical ceiling and not
"a model that happens to fit well". And because the task limits the input to a
5-second window, the ceiling is the optimal linear predictor ON THAT WINDOW -
matching exactly the condition every other method works under.

===========================================================================
DECIMATION DURING TRAINING
===========================================================================
The training set holds 200 runs x 10000 samples = 2 million samples, but at
Tc = 4..20 s that is only ~2000 to 10000 INDEPENDENT samples. Estimating 300
coefficients from 2 million correlated samples is no more accurate than from
200 thousand - it merely costs ten times as long. So the normal equations are
accumulated with TRAIN_STRIDE = 10 by default. The same reasoning already used
to size the dataset by number of seeds.
"""

import numpy as np
from scipy import integrate, linalg

from .spectra import PSD_MODELS, temporal_psd
from .task import TASK_FS, horizon_steps, valid_range

TRAIN_STRIDE = 10


# =========================================================================
#  Shared machinery: the lag matrix
# =========================================================================
def _lagged(w, p, i0, i1):
    """(m, 3p+1): [w(t), w(t-1), ..., w(t-p+1)] over all three axes, plus a
    constant column.

    ALL three axes are used as regressors, not just the axis being predicted.
    For Dryden the three axes are independent so the cross terms buy nothing,
    but for periodic and gust the three axes are one scalar signal times a
    direction - perfectly correlated. Giving the baseline that information is
    deliberate: the rival has to be strong, or W3 would be beating a straw man.
    """
    m = i1 - i0
    X = np.empty((m, 3 * p + 1), dtype=np.float64)
    for k in range(p):
        X[:, 3 * k:3 * k + 3] = w[i0 - k:i1 - k]
    X[:, -1] = 1.0
    return X


# =========================================================================
#  AR / VAR, learned from data
# =========================================================================
def fit_ar(runs, tau_ms, p, fs=TASK_FS, stride=TRAIN_STRIDE, ridge=1e-6):
    """Accumulate the normal equations across many runs, then solve once.

    Accumulating X'X and X'y rather than concatenating all the data and calling
    lstsq: memory does not grow with the number of runs, so adding seeds is
    never a problem.
    """
    d = 3 * p + 1
    XtX = np.zeros((d, d))
    Xty = np.zeros((d, 3))
    k = horizon_steps(tau_ms, fs)
    for w in runs:
        w = np.asarray(w, float)
        i0, i1 = valid_range(len(w), tau_ms, fs)
        i0 = max(i0, p)
        X = _lagged(w, p, i0, i1)[::stride]
        y = w[i0 + k:i1 + k][::stride]
        XtX += X.T @ X
        Xty += X.T @ y
    XtX[np.diag_indices(d)] += ridge * np.trace(XtX) / d
    return linalg.solve(XtX, Xty, assume_a="pos")


def predict_ar(w, coef, p, tau_ms, fs=TASK_FS):
    w = np.asarray(w, float)
    i0, i1 = valid_range(len(w), tau_ms, fs)
    i0 = max(i0, p)
    return _lagged(w, p, i0, i1) @ coef, slice(i0, i1)


class ARFitter:
    """Fit AR for MANY orders and MANY horizons in a single pass over the data.

    Calling fit_ar() separately for each (p, tau) rescans the whole training set
    every time: 4 orders x 6 horizons = 24 passes, and the most expensive one
    (p=100 -> 301 columns) dominates. Across 6 wind types that is unusable.

    Two observations collapse it to one pass:

      * The design matrix's columns are ordered by lag: [lag0(3) lag1(3) ...
        constant]. So X'X at order p is a SUBMATRIX of X'X at p_max - take the
        indices {0..3p-1} plus the constant column. Compute it once at p_max and
        every smaller order is free.

      * X'X does not depend on the horizon; only X'y does. X'y is (301 x 3),
        which is cheap. So each extra horizon costs one thin multiplication.

    A SHARED index set is used for every horizon (taken from the longest one) -
    which is both what makes X'X reusable and what makes the horizons directly
    comparable, since they are scored on exactly the same samples.
    """

    def __init__(self, p_max, taus, fs=TASK_FS, stride=TRAIN_STRIDE, ridge=1e-6):
        self.p_max, self.taus, self.fs = p_max, list(taus), fs
        self.stride, self.ridge = stride, ridge
        d = 3 * p_max + 1
        self.XtX = np.zeros((d, d))
        self.Xty = {t: np.zeros((d, 3)) for t in self.taus}
        self.k_max = max(horizon_steps(t, fs) for t in self.taus)

    def add(self, w):
        w = np.asarray(w, float)
        n = len(w)
        i0 = max(int(round(valid_range(n, self.taus[0], self.fs)[0])), self.p_max)
        i1 = n - self.k_max
        if i1 <= i0:
            return
        X = _lagged(w, self.p_max, i0, i1)[::self.stride]
        self.XtX += X.T @ X
        for t in self.taus:
            k = horizon_steps(t, self.fs)
            self.Xty[t] += X.T @ w[i0 + k:i1 + k][::self.stride]

    def solve(self, p, tau_ms, ridge=None):
        """ridge: the regularisation coefficient, scaled by trace(A) so it does
        not depend on the data's scale. It must be a HYPERPARAMETER chosen on
        val, not a constant: when fitting each (L, I) cell separately, a cell
        holds only ~1/9 of the runs, and at order p = 100 (301 coefficients)
        there are no longer enough INDEPENDENT samples - columns that were
        already nearly collinear become outright singular. Measured skill -1.38
        with IQR [-17.3, -0.05] when ridge was left fixed at 1e-6.
        """
        r = self.ridge if ridge is None else ridge
        idx = np.r_[0:3 * p, self.XtX.shape[0] - 1]
        A = self.XtX[np.ix_(idx, idx)].copy()
        b = self.Xty[tau_ms][idx]
        A[np.diag_indices(len(idx))] += r * np.trace(A) / len(idx)
        return linalg.solve(A, b, assume_a="pos")


# =========================================================================
#  Wiener: the optimal linear predictor from the TRUE spectrum
# =========================================================================
_acf_cache = {}


def theoretical_acf(model, sigma, L, V, axis, n_lags, fs=TASK_FS):
    """R(k*dt) = int_0^inf S(omega) cos(omega k dt) domega.

    Uses quad with the cos weight - the integrand oscillates, and ordinary
    quadrature goes wrong at large lags. The result is checked back against
    Dryden's closed form in verify_baselines.py:
        u axis   : R(t) = sigma^2 exp(-t/T)
        v,w axes : R(t) = sigma^2 exp(-t/T) (1 - t/(2T)),  T = L/V
    """
    # Round the lag count up to a multiple of 64 before caching. Without that,
    # each horizon shifts n_lags slightly and the cache misses every time - and
    # quad with the cos weight is the most expensive part of the benchmark.
    n_req = n_lags
    n_lags = int(np.ceil(n_lags / 64) * 64)
    key = (model, round(sigma, 9), round(L, 9), round(V, 9), axis, n_lags, fs)
    if key in _acf_cache:
        return _acf_cache[key][:n_req]

    def S(w):
        return temporal_psd(w, sigma, L, V, axis, model)

    R = np.empty(n_lags)
    R[0] = integrate.quad(S, 0, np.inf, limit=400)[0]
    for k in range(1, n_lags):
        t = k / fs
        R[k] = integrate.quad(S, 0, np.inf, weight="cos", wvar=t,
                              limit=200)[0]
    _acf_cache[key] = R
    return R[:n_req]


def wiener_coef(R, p, k):
    """Solve R a = r_k for the k-step predictor from p past samples.

    R is the autocovariance, R[0..p+k]. The system matrix is symmetric positive
    definite Toeplitz -> solve_toeplitz, O(p^2) instead of O(p^3).
    """
    return linalg.solve_toeplitz((R[:p], R[:p]), R[k:k + p])


def mixture_acf(cells, model, n_lags, fs=TASK_FS):
    """The WEIGHTED MEAN autocovariance of a mixture of regimes.

    cells: a list of (weight, L, sigma, V).

    This answers the question: a SINGLE fixed linear filter that does not know
    which wind regime it is in - how well can it possibly do?

    There is a closed form. Hold the coefficients a fixed, score by pooled MSE
    over the mixture, and minimise sum_c p_c E_c[(y - a'x)^2]. Setting the
    derivative to zero gives

        ( sum_c p_c R_c ) a = sum_c p_c r_c

    i.e. the same Wiener equations with the averaged autocovariance. So "optimal
    WITHOUT knowing the regime" is computed exactly, with no data fitting and no
    risk of overfitting.

    This replaces the original plan of fitting a separate AR per (L, I) cell.
    That failed for a statistical reason: the L = 100 m cell has Tc = 20 s, and
    22 runs x 200 s gives only ~220 independent samples for 301 coefficients.
    Measured skill -0.36 with IQR [-1.6, -0.05] - no amount of regularisation
    rescues an underdetermined problem. This route never touches the data, so it
    is immune.
    """
    tot = sum(c[0] for c in cells)
    R = np.zeros(n_lags)
    for wgt, L, sigma, Vc in cells:
        R += (wgt / tot) * theoretical_acf(model, sigma, L, Vc, "u", n_lags, fs)
    return R


def predict_wiener_pooled(w, coefs, tau_ms, p, fs=TASK_FS):
    """Apply ONE set of Wiener coefficients to every run and every axis."""
    w = np.asarray(w, float)
    n = len(w)
    i0, i1 = valid_range(n, tau_ms, fs)
    i0 = max(i0, p)
    mu = w.mean(axis=0)
    x = w - mu
    out = np.empty((i1 - i0, 3))
    for j in range(3):
        X = np.empty((i1 - i0, p))
        for q in range(p):
            X[:, q] = x[i0 - q:i1 - q, j]
        out[:, j] = X @ coefs + mu[j]
    return out, slice(i0, i1)


def predict_wiener(w, params, tau_ms, p, fs=TASK_FS, model=None):
    """Predict with Wiener coefficients computed from that run's own true
    spectrum.

    The record's sample mean is removed before filtering: the Wiener formula
    assumes zero mean. The mean wind is therefore an ORACLE quantity - which is
    legitimate, because this is a CEILING and not a rival, and "knowing the true
    model" includes knowing the mean wind.
    """
    w = np.asarray(w, float)
    n = len(w)
    i0, i1 = valid_range(n, tau_ms, fs)
    i0 = max(i0, p)
    k = horizon_steps(tau_ms, fs)
    mu = w.mean(axis=0)
    x = w - mu

    L_ax = {0: params["L"], 1: 0.5 * params["L"], 2: 0.5 * params["L"]}
    ax_name = {0: "u", 1: "v", 2: "w"}
    out = np.empty((i1 - i0, 3))
    for j in range(3):
        R = theoretical_acf(model or params["model"], params["sigma"],
                            L_ax[j], params["V"], ax_name[j], p + k + 1, fs)
        a = wiener_coef(R, p, k)
        X = np.empty((i1 - i0, p))
        for q in range(p):
            X[:, q] = x[i0 - q:i1 - q, j]
        out[:, j] = X @ a + mu[j]
    return out, slice(i0, i1)


# =========================================================================
#  Constant-velocity Kalman (steady-state alpha-beta)
# =========================================================================
def alpha_beta(lam):
    """The steady-state alpha-beta gains as a function of the tracking index
    lambda = q*dt^2/r, spelled out in the argument name.

    The familiar closed form (Kalata). The steady-state form is used instead of
    running the covariance recursion because the process is stationary, so the
    gain converges anyway - and a closed form has no initialisation step to get
    wrong.
    """
    r = (4 + lam - np.sqrt(8 * lam + lam**2)) / 4
    a = 1 - r**2
    b = 2 * (2 - a) - 4 * np.sqrt(1 - a)
    return a, b


def kalman_cv_states(w, lam, fs=TASK_FS):
    """Run the filter once and return the estimated (position, velocity).

    Split out from the prediction because the STATE does not depend on the
    horizon - only the extrapolation x + v*tau does. Re-running the filter per
    tau repeats the same Python loop six times, and that loop is the most
    expensive part of the benchmark.
    """
    w = np.asarray(w, float)
    n, dt = len(w), 1.0 / fs
    a, b = alpha_beta(lam)
    x = w[0].copy()
    v = np.zeros(3)
    X = np.empty((n, 3))
    Vv = np.empty((n, 3))
    for i in range(n):
        xp = x + v * dt
        e = w[i] - xp
        x = xp + a * e
        v = v + (b / dt) * e
        X[i] = x
        Vv[i] = v
    return X, Vv


def predict_kalman_cv(w, tau_ms, lam, fs=TASK_FS, states=None):
    """The constant-velocity model: predict w(t) + v(t)*tau.

    The classical rival for ramp and gust. On Dryden it is the WRONG model
    (wind has no persistent trend) and it loses to wiener - which is the correct
    outcome, not a weakness of the measurement: every method has its domain, and
    the results table has to show that.

    states: (X, V) precomputed by kalman_cv_states, so they can be reused across
    horizons.
    """
    X, Vv = states if states is not None else kalman_cv_states(w, lam, fs)
    n = len(X)
    i0, i1 = valid_range(n, tau_ms, fs)
    return X[i0:i1] + Vv[i0:i1] * (tau_ms * 1e-3), slice(i0, i1)
