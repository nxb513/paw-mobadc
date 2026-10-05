#!/usr/bin/env python3
"""
verify_wind_dataset.py -- Kiem chung bo sinh gio truoc khi sinh dataset lon.

    python3 python/verify_wind_dataset.py
    python3 python/verify_wind_dataset.py --psd-out wind_psd.mat

===========================================================================
KIEM CHUNG CAI GI VA VI SAO
===========================================================================
Bo sinh gio la thu ma moi ket qua ve sau dua len. Neu no sai thi W2 do sai,
W3 train sai, W4 ket luan sai - va khong buoc nao trong day co kha nang phat
hien ra. Nen no phai duoc kiem TRUOC, doi chieu voi cong thuc dong, chu khong
phai "nhin do thi thay hop ly".

Bay phep kiem, moi phep bat mot loai loi khac nhau:

  1. Chuan hoa pho     int_0^inf Phi dOmega = sigma^2
                       -> bat sai he so 2/pi, sai nhanh 1.339 cua von Karman
  2. Phuong sai do     std(turb) = I*V
                       -> bat sai chuan hoa trong synthesise()
  3. PSD do vs ly thuyet  Welch tren nhieu seed
                       -> bat sai quy uoc mot phia/hai phia, sai Jacobian 1/V
  4. Thoi gian tuong quan  Tc do duoc = L/V
                       -> bat sai truc tan so (day la cho de sai nhat)
  5. Gauss             skew ~ 0, kurtosis ~ 3
                       -> bat loi dung "bien do co dinh, pha ngau nhien"
  6. Hinh EOG          dinh = 1, do dai = T, ngoai khoang bang 0
  7. Tach seed         cac tap khong giao, hien thuc doc lap

Phep 4 dang chu y nhat: no la dai luong quyet dinh CA NHANH GIO. Tc do bang
tich phan ham tu tuong quan, khong phai doc tu tham so, nen no kiem tra
duong di tu L qua Omega=omega/V den chuoi thoi gian.
"""

import argparse
import sys

import numpy as np
from scipy import integrate, signal, stats

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))

from wind.dataset import SPLITS, code_hash, file_hashes, split_of
from wind.generators import (
    I_GRID, L_GRID, V_ADVECT, WIND_TYPES, draw_params, eog_shape, generate, total,
)
from wind.spectra import PSD_MODELS, temporal_psd, turbulence_uvw

FS = 200.0
DUR = 200.0
N_SEED = 24          # du de trung binh PSD, khong du lau

# Tan so lay mau cho CAC PHEP KIEM THONG KE (2, 4, 5). Thap hon FS rat nhieu
# va co chu dich: ba phep do la thoi gian tuong quan, phuong sai va phan bo,
# tuc cau truc TAN SO THAP. Nyquist 10 Hz = 62.8 rad/s da bo xa moi noi dung
# cua pho (Dryden L=20/V=5 co goc gay o 0.25 rad/s), trong khi han che chi
# phi cho phep chay ban ghi dai gap 30 lan - va do dai ban ghi moi la thu
# quyet dinh do chinh xac cua ba phep do nay.
FS_STAT = 20.0

_fail = []


def acf(x):
    """Ham tu tuong quan chuan hoa, tinh bang FFT.

    np.correlate(x, x, 'full') la O(n^2) va treo o ban ghi vai tram nghin
    mau - dung cai do thi khong chay noi ban ghi du dai de phep kiem co y
    nghia, va do chinh la cach phep kiem nay tung bao SAI oan cho bo sinh.
    """
    x = x - x.mean()
    n = len(x)
    m = 1 << int(np.ceil(np.log2(2 * n)))
    f = np.fft.rfft(x, m)
    r = np.fft.irfft(f * np.conj(f), m)[:n]
    return r / r[0]


def check(name, ok, detail=""):
    print(f"  [{'OK ' if ok else 'SAI'}] {name:<46s} {detail}")
    if not ok:
        _fail.append(name)


# =========================================================================
def t1_normalisation():
    print("\n1. Chuan hoa pho: int_0^inf Phi(Omega) dOmega = sigma^2")
    for model, fn in PSD_MODELS.items():
        for ax in "uw":
            for L in L_GRID:
                sig = 0.5
                val, _ = integrate.quad(
                    lambda w: fn(w, sig, L, ax), 0, np.inf, limit=400
                )
                r = val / sig**2
                check(f"{model:<11s} truc {ax}  L={L:5.0f} m", abs(r - 1) < 2e-3,
                      f"ty le {r:.5f}")


def t2_variance():
    """Ban ghi 2000 s = 400*Tc(L=50). Ngan hon thi sai so lay mau cua do lech
    chuan (~1/sqrt(2*T/Tc)) lon hon chinh sai so muon phat hien."""
    print("\n2. Phuong sai do duoc = (I*V)^2   (ban ghi 2000 s)")
    T = 2000.0
    n = int(T * FS_STAT)
    for model in PSD_MODELS:
        for I in I_GRID:
            sig = I * V_ADVECT
            s = []
            for k in range(8):
                x = turbulence_uvw(n, 1 / FS_STAT, sig, 50.0, V_ADVECT,
                                   np.random.default_rng(1000 + k + int(I * 100)),
                                   model)
                s.append(x.std(axis=0))
            r = np.mean(s, axis=0) / sig
            check(f"{model:<11s} I={I:.2f}  sigma={sig:.2f} m/s",
                  np.all(np.abs(r - 1) < 0.04),
                  f"u/v/w = {r[0]:.3f} {r[1]:.3f} {r[2]:.3f}")


def t3_psd(psd_out=None):
    print("\n3. PSD do (Welch, trung binh nhieu seed) vs ly thuyet")
    dump = {}
    n = int(DUR * FS)
    for model in PSD_MODELS:
        for L in (20.0, 100.0):
            sig = 0.10 * V_ADVECT
            acc = None
            for k in range(N_SEED):
                x = turbulence_uvw(n, 1 / FS, sig, L, V_ADVECT,
                                   np.random.default_rng(2000 + k), model)
                f, P = signal.welch(x[:, 0], fs=FS, nperseg=n // 8)
                acc = P if acc is None else acc + P
            P = acc / N_SEED
            # scipy tra PSD theo Hz; ly thuyet cua ta theo rad/s -> nhan 2*pi
            th = 2 * np.pi * temporal_psd(2 * np.pi * f, sig, L, V_ADVECT, "u", model)

            # So sanh trong dai co nang luong: 1e-3 .. 2 Hz. Ngoai dai do,
            # Welch cham san nhieu ro va ty le tro thanh vo nghia.
            m = (f > 1e-2) & (f < 2.0)
            ratio = P[m] / th[m]
            # Tach hai dai luong. |log| gop ca sai lech he thong lan tan xa
            # cua chinh Welch (uoc luong chi-binh-phuong), nen no khong bao
            # gio ve 0 va khong phan biet duoc hai thu. Trung vi CO DAU moi
            # do sai lech; |log| chi de canh dam tan xa.
            bias = np.median(ratio)
            scat = np.median(np.abs(np.log10(ratio)))
            check(f"{model:<11s} L={L:5.0f} m", abs(bias - 1) < 0.05,
                  f"sai lech {100*(bias-1):+.1f}%  (tan xa Welch {100*(10**scat-1):.1f}%)")
            if psd_out:
                key = f"{model}_L{int(L)}"
                dump[f"f_{key}"] = f
                dump[f"Pmeas_{key}"] = P
                dump[f"Pth_{key}"] = th
    if psd_out:
        from scipy.io import savemat
        savemat(psd_out, dump)
        print(f"     -> da ghi {psd_out} (ve hinh bang MATLAB)")


def t4_corr_time():
    """Tc = int_0^inf rho dt, cat o lan doi dau dau tien cua ACF mau.

    Uoc luong nay LECH THAP tren ban ghi ngan, va lech co he thong chu khong
    phai nhieu: do duoc 16.8 s cho Tc=20 s khi T/Tc=30, 18.7 s khi T/Tc=100,
    19.9 s khi T/Tc=300. Nen ban ghi phai dai it nhat 300*Tc thi con so moi
    noi duoc dieu gi ve bo sinh. Chay ngan hon la do chinh uoc luong, khong
    phai do gio.
    """
    print("\n4. Thoi gian tuong quan do duoc = L/V   (ban ghi 300*Tc)")
    for L in L_GRID:
        exp = L / V_ADVECT
        n = int(300 * exp * FS_STAT)
        tc = []
        for k in range(6):
            x = turbulence_uvw(n, 1 / FS_STAT, 0.5, L, V_ADVECT,
                               np.random.default_rng(3000 + k), "dryden")[:, 0]
            r = acf(x)
            z = np.argmax(r < 0)
            tc.append(np.trapezoid(r[:z], dx=1 / FS_STAT))
        m = np.mean(tc)
        check(f"L={L:5.0f} m -> Tc ky vong {exp:5.1f} s",
              abs(m / exp - 1) < 0.12, f"do duoc {m:5.1f} s")


def t5_gaussian():
    """Do skew/kurtosis tren mau LAY THUA cach nhau 5*Tc.

    Lay ca chuoi lien tuc thi 40000 mau chi la ~20 mau doc lap (Tc=10 s tren
    200 s), sai so chuan cua kurtosis ~ sqrt(24/20) = 1.1 - lon gap ba lan
    nguong 0.3 muon kiem. Phep kiem nhu vay bao SAI voi mot bo sinh dung.

    Lay thua 5*Tc tren ban ghi 4000 s cho ~1200 mau doc lap, sai so chuan
    0.14. Do duoc: kurt 3.04, skew -0.12. Phan bo bien la Gauss CHINH XAC
    theo cau truc (tong tuyen tinh cua he so Gauss phuc), nen phep kiem nay
    that ra kiem synthesise() co vo tinh lam hong tinh Gauss do khong - vi du
    dung "bien do co dinh, pha ngau nhien".
    """
    print("\n5. Nhieu loan la Gauss   (mau lay thua 5*Tc, ~1200 mau doc lap)")
    L, T = 20.0, 4000.0
    tc = L / V_ADVECT
    n = int(T * FS_STAT)
    step = int(5 * tc * FS_STAT)
    for model in PSD_MODELS:
        sk, ku, tot = [], [], 0
        for k in range(6):
            x = turbulence_uvw(n, 1 / FS_STAT, 0.5, L, V_ADVECT,
                               np.random.default_rng(4000 + k), model)[::step, 0]
            tot += len(x)
            sk.append(stats.skew(x))
            ku.append(stats.kurtosis(x, fisher=False))
        check(f"{model:<11s} skew ~ 0, kurtosis ~ 3",
              abs(np.mean(sk)) < 0.15 and abs(np.mean(ku) - 3) < 0.3,
              f"skew {np.mean(sk):+.3f}  kurt {np.mean(ku):.3f}  ({tot} mau)")


def t6_eog():
    print("\n6. Hinh gust IEC 61400-1")
    T = 10.5
    t = np.linspace(-5, 20, 20001)
    s = eog_shape(t, T)
    check("dinh chuan hoa ve 1", abs(np.abs(s).max() - 1) < 1e-9,
          f"max|s| = {np.abs(s).max():.6f}")
    check("bang 0 ngoai [0, T]",
          np.allclose(s[t < 0], 0) and np.allclose(s[t > T], 0))
    check("bang 0 tai hai dau", abs(s[np.argmin(abs(t))]) < 1e-9
          and abs(s[np.argmin(abs(t - T))]) < 1e-9)


def t7_splits():
    print("\n7. Tach seed va doc lap hien thuc")
    seen = {}
    bad = None
    for name, (lo, hi) in SPLITS.items():
        for s in range(lo, hi + 1):
            if s in seen:
                bad = s
            seen[s] = name
    check("cac tap khong giao nhau", bad is None, f"{len(seen)} seed")
    check("split_of khop bang", all(split_of(s) == seen[s] for s in seen))

    a, _ = generate(1, 1, 60, FS)
    b, _ = generate(1, 2, 60, FS)
    c, _ = generate(6, 1, 60, FS)
    ra = np.corrcoef(a["turb"][:, 0], b["turb"][:, 0])[0, 1]
    rc = np.corrcoef(a["turb"][:, 0], c["turb"][:, 0])[0, 1]
    check("hai seed khac nhau -> khong tuong quan", abs(ra) < 0.15, f"r = {ra:+.3f}")
    check("cung seed, khac loai gio -> khong tuong quan", abs(rc) < 0.15,
          f"r = {rc:+.3f}")

    d, _ = generate(1, 1, 60, FS)
    check("lap lai cung seed -> trung khop tuyet doi",
          np.array_equal(a["turb"], d["turb"]))


def t8_smoke():
    print("\n8. Sinh thu moi loai")
    for wt, name in WIND_TYPES.items():
        comp, p = generate(wt, 1, 60, FS)
        w = total(comp)
        ok = np.all(np.isfinite(w)) and w.shape == (int(60 * FS), 3)
        check(f"{wt} {name:<13s} thanh phan: {','.join(sorted(comp))}", ok,
              f"L={p['L']:.0f} I={p['I']:.2f} |w|={np.linalg.norm(w,axis=1).mean():.2f} m/s")


def t9_mixture():
    """Loai 7: ti le nang luong DO DUOC phai bang ti le DAT.

    Day la dieu kien de hinh "alpha theo ti le tron" co nghia. Neu ti le thuc
    te troi khoi ti le ghi trong metadata thi truc hoanh cua hinh do sai, va
    moi ket luan ve gating deu dua tren mot con so khong dung.
    """
    print("\n9. Loai 7: ti le tron dat duoc = ti le dat")
    from wind.generators import MIX_GRID
    seen = set()
    for seed in range(1, 60):
        comp, p = generate(7, seed, 200, FS)
        tot = p["sigma"] ** 2
        got = {k: float(v.var(axis=0).sum() / tot)
               for k, v in comp.items() if k != "mean"}
        want = dict(zip(("turb", "gust", "periodic"), p["mix"]))
        err = max(abs(got.get(k, 0.0) - want[k]) for k in want)
        if err > 1e-6:
            check(f"seed {seed} mix={p['mix']}", False, f"lech {err:.2e}")
            return
        seen.add(tuple(p["mix"]))
    check("60 seed dau, moi seed khop tuyet doi", True,
          f"lech max < 1e-6, phu {len(seen)}/{len(MIX_GRID)} o luoi")
    check("luoi tron duoc phu het", len(seen) == len(MIX_GRID),
          f"{len(seen)} / {len(MIX_GRID)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--psd-out", default=None,
                    help="ghi PSD do/ly thuyet ra .mat de ve hinh trong MATLAB")
    a = ap.parse_args()

    print("=" * 72)
    print("KIEM CHUNG BO SINH GIO")
    print(f"fs = {FS:.0f} Hz, do dai = {DUR:.0f} s, V = {V_ADVECT} m/s")
    # In ra de doi chieu giua cac may. Hai may cung branch PHAI ra cung mot
    # chuoi; khac nhau nghia la code khac nhau, va moi dataset sinh boi hai
    # ban do khong tron duoc.
    print(f"code_hash = {code_hash()}")
    for nm, (h, nb, nl) in file_hashes().items():
        print(f"   {nm:<16s} {h}  {nb:6d} byte  {nl:4d} dong")
    print("=" * 72)

    t1_normalisation()
    t2_variance()
    t3_psd(a.psd_out)
    t4_corr_time()
    t5_gaussian()
    t6_eog()
    t7_splits()
    t8_smoke()
    t9_mixture()

    print("\n" + "=" * 72)
    if _fail:
        print(f"SAI {len(_fail)} phep kiem:")
        for f in _fail:
            print(f"   - {f}")
        return 1
    print("Tat ca dat.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
