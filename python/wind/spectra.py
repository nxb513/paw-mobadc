"""
spectra.py -- theoretical Dryden / von Karman spectra and a series generator
              driven by them.

===========================================================================
WHY SYNTHESISE FROM THE SPECTRUM RATHER THAN USE A RATIONAL FILTER
===========================================================================
The usual way to generate turbulence is to pass white noise through a rational
filter (Simulink's Aerospace Blockset does this). That has one problem which
cannot be fixed: the von Karman spectrum IS NOT RATIONAL. Its exponents are
5/6 and 11/6,

    Phi_u(Omega) = sigma^2 (2L/pi) / (1 + (1.339 L Omega)^2)^(5/6)

so every rational filter is only an APPROXIMATION of von Karman, with the
error concentrated at the low end of the spectrum - exactly where
predictability is decided.

The more serious consequence is in verification. Generate with an approximate
filter, take the FFT, compare against the theoretical formula, and the
discrepancy is inherent to the approximation - so the check can no longer
detect a PROGRAMMING error: every discrepancy gets attributed to "the
approximation". Verification loses all its value.

Synthesising directly from the spectrum makes both models EXACT by
construction, so any deviation seen in verify_wind_dataset.py is a real fault -
either a coding error or sampling variance. That is the main reason.

The price: the generated series is periodic with period T = N*dt (the discrete
Fourier transform is periodic). This is suppressed by generating 2T and keeping
T - the residual correlation between the start and the end of the kept segment
is smaller than exp(-T/Tc) of the 2T series.

===========================================================================
SPECTRAL CONVENTION
===========================================================================
Every Phi(Omega) here is a ONE-SIDED spectrum in SPATIAL frequency Omega
[rad/m]:

    sigma^2 = int_0^inf Phi(Omega) dOmega

Converted to temporal frequency by Taylor's frozen-turbulence hypothesis,
Omega = omega / V, so

    S(omega) = Phi(omega/V) / V        [ (m/s)^2 / (rad/s) ]

V here is the ADVECTION speed, not necessarily the flight speed. See the note
in generators.py.
"""

import numpy as np

# The von Karman constant. Not a free parameter: it is the value that makes the
# spectral integral come out at exactly sigma^2 (checked back by
# test_spectra_normalisation).
VK_A = 1.339


# =========================================================================
#  One-sided spatial spectra
# =========================================================================
def dryden_psd(omega_sp, sigma, L, axis):
    """The one-sided Dryden spectrum in spatial frequency [rad/m].

    axis: 'u' along-wind, 'v'/'w' crosswind.
    """
    x = L * np.asarray(omega_sp, dtype=float)
    if axis == "u":
        return sigma**2 * (2.0 * L / np.pi) / (1.0 + x**2)
    return sigma**2 * (L / np.pi) * (1.0 + 3.0 * x**2) / (1.0 + x**2) ** 2


def von_karman_psd(omega_sp, sigma, L, axis):
    """The one-sided von Karman spectrum in spatial frequency [rad/m]."""
    x = VK_A * L * np.asarray(omega_sp, dtype=float)
    if axis == "u":
        return sigma**2 * (2.0 * L / np.pi) / (1.0 + x**2) ** (5.0 / 6.0)
    return (
        sigma**2
        * (L / np.pi)
        * (1.0 + (8.0 / 3.0) * x**2)
        / (1.0 + x**2) ** (11.0 / 6.0)
    )


PSD_MODELS = {"dryden": dryden_psd, "von_karman": von_karman_psd}


def temporal_psd(omega, sigma, L, V, axis, model):
    """S(omega) [ (m/s)^2/(rad/s) ], one-sided, in temporal frequency
    [rad/s]."""
    return PSD_MODELS[model](np.asarray(omega, dtype=float) / V, sigma, L, axis) / V


# =========================================================================
#  Synthesising a series from a spectrum
# =========================================================================
def synthesise(n, dt, psd_fn, rng, pad=2):
    """Generate a stationary zero-mean Gaussian series with one-sided spectrum
    psd_fn(omega).

    psd_fn takes an array of omega [rad/s] and returns S(omega)
    [(m/s)^2/(rad/s)].

    THE METHOD. Write x[k] = Re{ C_k exp(i w_k t) } summed over k. For bin k's
    variance to be exactly S(w_k)*dw one needs E|C_k|^2 = 2 S(w_k) dw, which is
    achieved by C_k = sqrt(S dw) * (g1 + i g2) with g ~ N(0,1). A sum of many
    independent Gaussian bins is still Gaussian - unlike the "fixed amplitude,
    random phase" construction, which is non-Gaussian at low bin counts.

    Converting to numpy.irfft's convention
    (x[n] = (1/N)(X[0] + 2*sum Re{X[k]...})) gives X[k] = N/2 * C_k.

    pad=2: generate twice the length and cut, to reduce the DFT's periodicity.
    """
    n_pad = int(n * pad)
    df = 1.0 / (n_pad * dt)
    dw = 2.0 * np.pi * df
    n_f = n_pad // 2 + 1
    omega = 2.0 * np.pi * np.arange(n_f) * df

    s = np.zeros(n_f)
    s[1:] = psd_fn(omega[1:])          # bin 0 = 0 -> zero mean
    amp = 0.5 * n_pad * np.sqrt(s * dw)

    g = rng.standard_normal(n_f) + 1j * rng.standard_normal(n_f)
    x_f = amp * g
    x_f[0] = 0.0
    if n_pad % 2 == 0:
        # The Nyquist bin must be real, and it carries one degree of freedom
        # rather than two.
        x_f[-1] = amp[-1] * rng.standard_normal() * np.sqrt(2.0)

    return np.fft.irfft(x_f, n=n_pad)[:n]


def turbulence_uvw(n, dt, sigma, L_u, V, rng, model):
    """The three turbulence components (u, v, w), as an (n, 3) array.

    L_v = L_w = L_u/2 following MIL-F-8785C at low altitude. sigma is taken
    equal on all three axes - see the [NEW] note in generators.py.
    """
    L = {"u": L_u, "v": 0.5 * L_u, "w": 0.5 * L_u}
    out = np.empty((n, 3))
    for i, ax in enumerate("uvw"):
        out[:, i] = synthesise(
            n, dt,
            lambda w, ax=ax: temporal_psd(w, sigma, L[ax], V, ax, model),
            rng,
        )
    return out
