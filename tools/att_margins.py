"""Linear margins of the Guo attitude loop with a first-order motor lag (REGISTER_P2 sec 2).

    python tools/att_margins.py            # Guo's gains + the bandwidth-parametrization table
    python tools/att_margins.py --csv out.csv

One axis, small angle, loop broken at the actuator input (tau_cmd -> tau_act):

    plant      P(s) = 1 / (I s^2)
    actuator   A(s) = exp(-s Td) / (tau_m s + 1)      Td = 1 ms (1 kHz sampling, sec 2.3)
    ESO        s z1 = z2 + b1 e, s z2 = u/I + z3 + b2 e, s z3 = b3 e,  e = eta - z1,
               u = tau_cmd (the observers read the COMMANDED torque, GD2B_DESIGN)
    control    u = -K_eta eta - K_omega s eta - I z3                  (Guo (18), eta_d = 0)

which gives u = -C(s) eta with

    C(s) = [(K_eta + K_omega s) D(s) + b3 I s^2] / [s (s^2 + b1 s + b2)],
    D(s) = s^3 + b1 s^2 + b2 s + b3,         L(s) = C(s) A(s) P(s).

Bandwidth parametrization (Gao 2003): K_eta = I wc^2, K_omega = 2 I wc,
b1 = 3 wo, b2 = 3 wo^2, b3 = wo^3, wo = k wc. With these gains I cancels in L(s):
one loop for roll, pitch and yaw.

L has three integrators (-270 deg at low frequency), so it is conditionally stable:
the gain margin is reported on BOTH sides (gain increase and gain reduction) and GM is
the smaller one. Stability: closed-loop roots with a 3rd-order Pade of the delay.
Numbers only - no simulation, no reading.
"""
import argparse
import numpy as np

TD = 1e-3                     # s, sampling delay at 1 kHz (registered, sec 2.3)
W = np.logspace(-3, 5, 400001)
GUO = {                       # init_MOBADC_params.m, [PAPER Appendix A.2]
    'roll':  dict(I=0.01,   Keta=2.16, Kom=0.20),
    'pitch': dict(I=0.0082, Keta=1.92, Kom=0.12),
    'yaw':   dict(I=0.0148, Keta=0.59, Kom=0.12),
}
GUO_ESO = (50.0, 833.0, 3906.0)


def loop_polys(I, Keta, Kom, b1, b2, b3, tau_m):
    """numerator / denominator of L(s) without the delay, highest power first."""
    D = np.array([1.0, b1, b2, b3])
    num = np.polyadd(np.polymul([Kom, Keta], D), [b3 * I, 0.0, 0.0])
    den = np.polymul([1.0, b1, b2, 0.0], [I, 0.0, 0.0])        # s(s^2+b1 s+b2) * I s^2
    if tau_m > 0:
        den = np.polymul(den, [tau_m, 1.0])
    return num, den


def pade3(T):
    """3rd-order Pade of exp(-sT)."""
    n = np.array([-T**3 / 120, T**2 / 10, -T / 2, 1.0])
    d = np.array([T**3 / 120, T**2 / 10, T / 2, 1.0])
    return n, d


def margins(I, Keta, Kom, b1, b2, b3, tau_m, Td=TD):
    num, den = loop_polys(I, Keta, Kom, b1, b2, b3, tau_m)
    s = 1j * W
    L = np.polyval(num, s) / np.polyval(den, s) * np.exp(-s * Td)
    mag = np.abs(L)
    ph = np.unwrap(np.angle(L))
    ph = ph - 2 * np.pi * np.round((ph[0] + 1.5 * np.pi) / (2 * np.pi))   # low-frequency phase = -270 deg
    ph_deg = np.degrees(ph)
    lm = np.log(mag)
    # gain crossovers
    pm, wgc = [], []
    for i in np.nonzero(np.sign(lm[:-1]) != np.sign(lm[1:]))[0]:
        t = lm[i] / (lm[i] - lm[i + 1])
        p = ph_deg[i] + t * (ph_deg[i + 1] - ph_deg[i])
        pm.append((p + 180.0 + 180.0) % 360.0 - 180.0)
        wgc.append(W[i] * (W[i + 1] / W[i]) ** t)
    # phase crossovers at -180 - 360 k
    gm_up, gm_dn, wpc = [], [], []
    x = (ph_deg + 180.0) / 360.0
    for i in np.nonzero(np.floor(x[:-1]) != np.floor(x[1:]))[0]:
        n = max(np.floor(x[i]), np.floor(x[i + 1]))        # the -180 - 360 k line crossed
        t = (n - x[i]) / (x[i + 1] - x[i])
        g = 20 * (lm[i] + t * (lm[i + 1] - lm[i])) / np.log(10)
        wpc.append(W[i] * (W[i + 1] / W[i]) ** t)
        (gm_up if g < 0 else gm_dn).append(abs(g))
    # closed-loop stability with the Pade delay
    pn, pd = pade3(Td)
    ch = np.polyadd(np.polymul(den, pd), np.polymul(num, pn))
    r = np.roots(ch)
    stable = bool(np.all(r.real < 0))
    PM = min(pm) if pm else np.nan
    GMu = min(gm_up) if gm_up else np.inf
    GMd = min(gm_dn) if gm_dn else np.inf
    return dict(stable=stable, PM=PM, wgc=max(wgc) if wgc else np.nan, GM=min(GMu, GMd),
                GM_up=GMu, GM_dn=GMd, max_re=float(np.max(r.real)))


def bw_gains(wc, k):
    wo = k * wc
    return dict(I=1.0, Keta=wc**2, Kom=2 * wc, b1=3 * wo, b2=3 * wo**2, b3=wo**3)


def fmt(m):
    if not m['stable']:                       # margins of an unstable loop are not margins
        return 'NO  %7s %7.2f %7s %7s %7s' % ('-', m['wgc'], '-', '-', '-')
    return 'yes %7.1f %7.2f %7.1f %7.1f %7.1f' % (m['PM'], m['wgc'], m['GM'], m['GM_up'], m['GM_dn'])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--csv', default='')
    a = ap.parse_args()
    b1, b2, b3 = GUO_ESO

    print('Position loop (x/y, Kgamma 12, Knu 8), for the time-scale separation of sec 2.4:')
    Kg, Kn = 12.0, 8.0
    w = W[W < 1e3]
    Lp = (Kn * 1j * w + Kg) / (1j * w) ** 2
    Tp = Lp / (1 + Lp)
    print('  sqrt(Kgamma)                 %6.2f rad/s' % np.sqrt(Kg))
    print('  closed-loop poles            %s rad/s' % np.round(np.sort(-np.roots([1, Kn, Kg]).real), 2))
    print('  open-loop crossover |L| = 1  %6.2f rad/s' % w[np.argmin(np.abs(np.abs(Lp) - 1))])
    print('  closed-loop -3 dB            %6.2f rad/s' % w[np.nonzero(np.abs(Tp) < 1 / np.sqrt(2))[0][0]])

    print('\nGuo gains, Guo ESO (50, 833, 3906), Td = 1 ms:')
    print('  axis   tau_m  stable     PM   w_gc      GM  GM_up  GM_dn   [deg, rad/s, dB]')
    for ax, g in GUO.items():
        for tm in (0.0, 0.017, 0.030, 0.050, 0.072):
            m = margins(g['I'], g['Keta'], g['Kom'], b1, b2, b3, tm)
            print('  %-5s  %4.0f ms %s' % (ax, tm * 1e3, fmt(m)))

    print('\nBandwidth parametrization, Td = 1 ms (I cancels: every axis):')
    rows = []
    for k in (2, 3, 4, 5):
        for wc in np.round(np.arange(0.5, 30.01, 0.5), 2):
            G = bw_gains(wc, k)
            m30 = margins(G['I'], G['Keta'], G['Kom'], G['b1'], G['b2'], G['b3'], 0.030)
            m72 = margins(G['I'], G['Keta'], G['Kom'], G['b1'], G['b2'], G['b3'], 0.072)
            m0 = margins(G['I'], G['Keta'], G['Kom'], G['b1'], G['b2'], G['b3'], 0.0)
            ok = m30['stable'] and m30['PM'] >= 45 and m30['GM'] >= 6 and m72['stable'] and m72['PM'] >= 20
            rows.append((k, wc, m0, m30, m72, ok))
    print('  k    wc | tau 30 ms: st    PM   w_gc     GM  GM_up  GM_dn | tau 72 ms: st    PM | no lag: PM | pass')
    for k, wc, m0, m30, m72, ok in rows:
        if wc % 1 == 0 or ok:
            print('  %d %5.1f |            %s | %s %6s | %6.1f | %s' % (
                k, wc, fmt(m30), 'yes' if m72['stable'] else 'NO ',
                '%.1f' % m72['PM'] if m72['stable'] else '-', m0['PM'], 'PASS' if ok else '-'))
    print('\nLargest wc meeting sec 2.3 (tau 30: stable, PM >= 45, GM >= 6 dB; tau 72: stable, PM >= 20):')
    for k in (2, 3, 4, 5):
        okw = [wc for kk, wc, *_r, ok in rows if kk == k and ok]
        print('  k = %d: %s' % (k, ('%.1f rad/s (feasible set %.1f-%.1f, %d grid points)'
                                     % (max(okw), min(okw), max(okw), len(okw))) if okw else 'none'))
    if a.csv:
        with open(a.csv, 'w') as f:
            f.write('k,wc,st30,PM30,wgc30,GM30,GMup30,GMdn30,st72,PM72,PM0,pass\n')
            for k, wc, m0, m30, m72, ok in rows:
                f.write('%d,%.2f,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%.3f,%.3f,%d\n' % (
                    k, wc, m30['stable'], m30['PM'], m30['wgc'], m30['GM'], m30['GM_up'], m30['GM_dn'],
                    m72['stable'], m72['PM'], m0['PM'], ok))


if __name__ == '__main__':
    main()
