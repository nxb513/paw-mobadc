#!/usr/bin/env python3
"""
verify_moe.py -- Kiem PI-MoE truoc khi huan luyen.

    python3 python/verify_moe.py

Khong can dataset, khong can huan luyen. Moi phep doi chieu voi mot dang dong
hoac voi mot cai dat doc lap da duoc kiem o W2.

===========================================================================
PHEP KIEM QUAN TRONG NHAT: TRAN CUA W2 NAM TRONG KHONG GIAN BIEU DIEN
===========================================================================
Neu dat gate thanh one-hot dung o T_c that cua mot lan chay, PI-MoE phai cho
ra DUNG du doan cua wiener oracle - cai da do duoc +0.0294 tren Dryden @140 ms
va la tran cua W2.

Do la mot tinh chat CAU TRUC, khong phai ket qua huan luyen. Neu no khong
dung thi moi phan con lai vo nghia: mo hinh khong the dat tran du hoc tot den
dau, va mot ket qua "AI khong len duoc tran" se bi doc nham thanh ket luan
khoa hoc trong khi no chi la loi lap trinh.

Nguoc lai, khi no dung thi cau hoi cua W3 tro nen sach: mo hinh CO the dat
tran, va viec con lai la no co HOC duoc cach chon che do tu du lieu hay khong.
"""

import pathlib
import sys

import numpy as np
import torch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from wind.baselines import predict_kalman_cv, theoretical_acf, wiener_coef  # noqa: E402
from wind.moe import (  # noqa: E402
    EXPERT_P, GUST_T, KALMAN_LAMBDAS, LV_RANGE, PER_BANDS, PIMoE, SD_FLOOR,
    SPEC_MODELS,
    TC_GRID,
    eog_acf, expert_bank, kalman_cv_filter, nll_loss, periodic_acf,
    shape_filters, wiener_filters,
)
from wind.spectra import synthesise, temporal_psd  # noqa: E402
from wind.task import TASK_FS, horizon_steps  # noqa: E402

_fail = []
V = 5.0


def check(name, ok, detail=""):
    print(f"  [{'OK ' if ok else 'SAI'}] {name:<52s} {detail}")
    if not ok:
        _fail.append(name)


def t1_wiener_bank():
    print("\n1. Ngan hang Wiener: qua trinh Markov -> chi tap 0 khac 0")
    for tau in (140, 1000):
        W = wiener_filters(tau)
        for i, tc in enumerate(TC_GRID):
            # Truc u la Markov -> chi tap 0 khac 0, bang exp(-tau/Tc).
            exp0 = np.exp(-(tau * 1e-3) / tc)
            ok = abs(W[0, i, 0] - exp0) < 1e-6 and np.abs(W[0, i, 1:]).max() < 1e-5
            check(f"tau={tau:5d} ms  Tc={tc:5.1f} s  truc u",
                  ok, f"a[0]={W[0,i,0]:.6f} vs {exp0:.6f}, "
                      f"max|a[1:]|={np.abs(W[0,i,1:]).max():.1e}")
            # Truc v/w KHONG Markov (pho co tu so 1+3x^2) -> tap sau phai
            # khac 0, va he so tap 0 phai khac truc u. Neu hai truc ra giong
            # nhau thi ngan hang dang dung mot bo loc cho ca ba - dung loi da
            # xay ra, va no lat dau skill tren Dryden.
            same = np.abs(W[1, i] - W[0, i]).max()
            check(f"tau={tau:5d} ms  Tc={tc:5.1f} s  truc v/w KHAC truc u",
                  same > 1e-3 and np.abs(W[1, i, 1:]).max() > 1e-4,
                  f"lech {same:.4f}, a[0]={W[1,i,0]:.4f}")


def t2_sigma_independence():
    """Tinh chat: a = R^-1 r, va R = sigma^2 rho nen sigma^2 rut gon o hai ve.

    Kiem tren ham tu hiep phuong sai DANG DONG chu khong tren ket qua quad.
    Ban dau tinh bang theoretical_acf va nguong 1e-9 thi bao SAI voi lech
    6.5e-07 - do la sai so CAU PHUONG, khong phai sai lech that: quad co dung
    sai, va nhan sigma^2 len 16 lan thi nhan luon sai so len 16 lan. Dung dang
    dong thi tinh chat dung den do chinh xac may.

    Do chinh xac cua quad van duoc kiem rieng - o phep 1, doi chieu a[0] voi
    exp(-tau/Tc) tren toan bo luoi.
    """
    print("\n2. He so Wiener KHONG phu thuoc sigma (nen che do chi la T_c)")
    tau, tc = 140, 10.0
    k = horizon_steps(tau)
    t = np.arange(EXPERT_P + k + 1) / TASK_FS
    a = [wiener_coef(sig**2 * np.exp(-t / tc), EXPERT_P, k)
         for sig in (0.25, 1.0, 4.0)]
    d = max(np.abs(a[0] - a[i]).max() for i in (1, 2))
    check("sigma = 0.25 / 1.0 / 4.0 cho cung he so (dang dong)",
          d < 1e-12, f"lech {d:.2e}")

    R = theoretical_acf("dryden", 1.0, tc * V, V, "u", EXPERT_P + k + 1)
    dq = np.abs(wiener_coef(R, EXPERT_P, k) - a[1]).max()
    check("theoretical_acf (quad) khop dang dong", dq < 1e-5,
          f"lech {dq:.2e} - sai so cau phuong, khong phai sai lech")


def t3_kalman_fir():
    print("\n3. Kalman FIR = Kalman de quy (sai lech do cat tap)")
    n = int(60 * TASK_FS)
    rng = np.random.default_rng(0)
    x = np.cumsum(rng.standard_normal((n, 3)), axis=0) * 0.05
    for tau in (140, 1000):
        for lam in KALMAN_LAMBDAS:
            h = kalman_cv_filter(tau, lam)
            rec, sl = predict_kalman_cv(x, tau, lam)
            i0 = sl.start
            fir = np.stack([
                np.array([h @ x[t - EXPERT_P + 1:t + 1, c][::-1] for c in range(3)])
                for t in range(i0, i0 + 200)])
            e = np.abs(fir - rec[:200]).max() / np.abs(rec[:200]).std()
            check(f"tau={tau:5d} ms  lambda={lam:g}", e < 0.02,
                  f"lech tuong doi {100*e:.3f}%")


def _force_gate(m, idx):
    with torch.no_grad():
        m.gate.weight.zero_()
        m.gate.bias.zero_()
        m.gate.bias[idx] = 50.0


def t4_ceiling_representable():
    """Gate one-hot o T_c that -> skill BANG wiener oracle cua W2.

    Ban dau phep kiem nay so dau ra cua mo hinh voi mot ban TU TINH LAI trong
    chinh file nay. No dat - va bo qua mot loi that: ngan hang dung MOT bo loc
    truc u cho ca ba truc, trong khi MIL-F-8785C cho L_v = L_w = L_u/2 va dang
    pho khac. Ban tu tinh lai mac dung mot loi do, nen hai ben khop nhau va
    phep kiem im lang. Do duoc sau do tren du lieu that: -0.13 thay vi +0.036.
    Sai he so 6% du de lat dau khi tran chi cao 3%.

    Nen bay gio doi chieu voi predict_wiener - bo cai dat DOC LAP da dung o
    W2 - va doi chieu bang SKILL tren du lieu that, khong phai bang dau ra
    tren mot cua so. Cham hon, va la phep kiem duy nhat co the bat duoc loai
    loi vua roi.
    """
    print("\n4. TRAN CUA W2 BIEU DIEN DUOC: gate one-hot = skill cua wiener")
    from wind.baselines import predict_wiener
    from wind.evaluate import valid_indices, window_batch
    from wind.task import aggregate, persistence, target, valid_range

    tau, W_s, V_ = 140, 30.0, 5.0
    n = int(400 * TASK_FS)
    wl = int(W_s * TASK_FS)
    for tc_i in (1, 3):
        tc = TC_GRID[tc_i]
        L, sig = tc * V_, 0.5
        runs = []
        for r in range(4):
            ax = []
            for j, (nm, sc) in enumerate((("u", 1.0), ("w", 0.5), ("w", 0.5))):
                ax.append(synthesise(
                    n, 1 / TASK_FS,
                    lambda w, nm=nm, sc=sc: temporal_psd(
                        w, sig, L * sc, V_, nm, "dryden"),
                    np.random.default_rng(700 + 4 * r + j)))
            runs.append(np.stack(ax, axis=1) + 5.0)

        m = PIMoE(tau, W_s).eval()
        _force_gate(m, tc_i)

        rows_m, rows_w = [], []
        for w in runs:
            i0, i1 = valid_range(len(w), tau)
            idx = valid_indices(len(w), tau, 25)
            sel = idx - i0
            y, ref = target(w, tau)[sel], persistence(w, tau)[0][sel]
            with torch.no_grad():
                pm = m(torch.from_numpy(window_batch(w, idx, wl)))["yhat"].numpy()
            pw = predict_wiener(w, {"L": L, "V": V_, "sigma": sig}, tau, 150,
                                model="dryden")[0][sel]
            for pr, acc in ((pm, rows_m), (pw, rows_w)):
                e, rr = pr - y, ref - y
                acc.append({"sse": float((e ** 2).sum()), "n": e.size,
                            "sse_ref": float((rr ** 2).sum()), "n_ref": rr.size,
                            "sse_ev": 0.0, "n_ev": 0,
                            "sse_ev_ref": 0.0, "n_ev_ref": 0})
        s_m = aggregate(rows_m)["skill"]
        s_w = aggregate(rows_w)["skill"]
        check(f"Tc = {tc:g} s", s_m > 0 and abs(s_m - s_w) < 0.01,
              f"PI-MoE {s_m:+.4f}  vs  predict_wiener {s_w:+.4f}")


def t5_expert_isolation():
    print("\n5. Gate one-hot o chuyen gia k -> dung bo loc k, khong lan")
    m = PIMoE(140, 30.0).eval()
    E, names = expert_bank(140)
    x = torch.randn(4, 3, int(30 * TASK_FS))
    nW = len(SPEC_MODELS) * len(TC_GRID)
    nS = len(PER_BANDS) + len(GUST_T)
    for idx in (0, len(TC_GRID), nW, nW + len(PER_BANDS), nW + nS):
        _force_gate(m, idx)
        with torch.no_grad():
            o = m(x)
        mu = x.mean(-1, keepdim=True)
        sd = x.std(-1, keepdim=True).clamp_min(1e-6)
        xn = ((x - mu) / sd)[..., -EXPERT_P:].flip(-1).numpy()
        ref = np.einsum("bcp,cp->bc", xn, E[:, idx]) * sd[..., 0].numpy() \
            + mu[..., 0].numpy()
        e = np.abs(o["yhat"].numpy() - ref).max()
        check(f"chuyen gia {idx}: {names[idx]:<16s}", e < 2e-4,
              f"alpha={o['alpha'][0, idx]:.4f}, lech {e:.2e}")

        # yhat_expert[:,:,k] phai BANG yhat khi gate one-hot o k.
        #
        # alpha_report.py cham ca 22 chuyen gia bang mot luot xuoi qua truong
        # nay thay vi 22 luot ep gate. Do la nhanh hon 22 lan, nhung no cung
        # la mot DUONG DI THU HAI toi cung mot con so - va duong di thu hai
        # la thu am tham lech di roi khong bao gi. Dung loai loi da xay ra o
        # window_batch va o phep kiem 4 ban dau. Neo no o day.
        e2 = np.abs(o["yhat_expert"][:, :, idx].numpy()
                    - o["yhat"].numpy()).max()
        check(f"  yhat_expert[{idx}] = yhat khi one-hot o {idx}", e2 < 1e-5,
              f"lech {e2:.2e}")


def t6_nll():
    print("\n6. Gauss NLL: log-phuong sai toi uu = log(sai so binh phuong)")
    torch.manual_seed(0)
    d = torch.randn(4096, 3) * torch.tensor([0.1, 1.0, 3.0])
    best, lv_best = None, None
    for c in np.linspace(-4, 3, 71):
        out = {"yhat": torch.zeros_like(d), "logvar": torch.full_like(d, float(c)),
               "acf": torch.zeros(4096, 1), "acf_target": torch.zeros(4096, 1)}
        l, _ = nll_loss(out, d, lam_acf=0.0)
        if best is None or l.item() < best:
            best, lv_best = l.item(), c
    # Voi MOT gia tri logvar dung chung ca ba truc,
    #     L(c) = 0.5 * sum_j [ v_j e^-c + c ]  ->  dL/dc = 0  ->  e^c = mean(v)
    # tuc cuc tieu o log TRUNG BINH CONG cua cac phuong sai. Phep kiem nay ban
    # dau ky vong trung binh HINH HOC va bao SAI (do +1.200, "ky vong" -0.797);
    # trung binh hinh hoc la nghiem khi MOI truc co logvar RIENG, khong phai
    # khi dung chung mot gia tri.
    var_am = float(d.var(0).mean())
    check("cuc tieu NLL o log(trung binh cong cac phuong sai)",
          abs(lv_best - np.log(var_am)) < 0.15,
          f"do duoc {lv_best:+.3f}, ky vong {np.log(var_am):+.3f}")

    # Phuong sai bat dong nhat: logvar rieng tung truc phai thang logvar chung
    per = {"yhat": torch.zeros_like(d),
           "logvar": torch.log(d.var(0)).expand_as(d).clone(),
           "acf": torch.zeros(4096, 1), "acf_target": torch.zeros(4096, 1)}
    l_per, _ = nll_loss(per, d, lam_acf=0.0)
    check("logvar theo tung truc tot hon mot gia tri chung",
          l_per.item() < best - 0.05, f"{l_per.item():.4f} < {best:.4f}")


def t7_shapes_and_size():
    print("\n7. Hinh dang, huu han, kich thuoc mo hinh")
    for W_s in (5.0, 30.0):
        m = PIMoE(140, W_s)
        n_par = sum(p.numel() for p in m.parameters() if p.requires_grad)
        x = torch.randn(8, 3, int(W_s * TASK_FS))
        o = m(x)
        ok = (o["yhat"].shape == (8, 3) and o["logvar"].shape == (8, 3)
              and o["alpha"].shape == (8, len(SPEC_MODELS) * len(TC_GRID)
                                        + len(PER_BANDS) + len(GUST_T)
                                        + len(KALMAN_LAMBDAS) + 1)
              and all(torch.isfinite(v).all() for v in o.values()))
        check(f"cua so {W_s:4.0f} s", ok,
              f"{n_par/1000:.1f}k tham so, {o['alpha'].shape[1]} chuyen gia, "
              f"{len(m.lags)} tre ACF")
        check(f"cua so {W_s:4.0f} s: alpha la phan bo xac suat",
              torch.allclose(o["alpha"].sum(-1), torch.ones(8), atol=1e-5))
        check(f"cua so {W_s:4.0f} s: mo hinh du nho cho ngan sach du lieu",
              n_par < 300_000, f"{n_par} < 300k")

    l, parts = nll_loss(o, torch.randn(8, 3))
    l.backward()
    g = [p.grad for p in m.parameters() if p.grad is not None]
    check("gradient chay het va huu han",
          len(g) > 5 and all(torch.isfinite(t).all() for t in g),
          f"{len(g)} tensor co gradient")


def t8_acf_target():
    print("\n8. Nhan ACF tu giam sat khop tinh truc tiep")
    m = PIMoE(140, 30.0)
    x = torch.randn(3, 3, int(30 * TASK_FS)).double()
    xn = (x - x.mean(-1, keepdim=True)) / x.std(-1, keepdim=True)
    a = m.window_acf(xn).numpy()
    ref = np.stack([[float((xn[b, :, l:] * xn[b, :, :-l]).mean())
                     for l in m.lags] for b in range(3)])
    check("khop numpy", np.abs(a - ref).max() < 1e-9,
          f"lech {np.abs(a-ref).max():.2e}, {len(m.lags)} tre")


def _skill(pred, y, ref):
    from wind.task import aggregate
    e, r = pred - y, ref - y
    return aggregate([{"sse": float((e ** 2).sum()), "n": e.size,
                       "sse_ref": float((r ** 2).sum()), "n_ref": r.size,
                       "sse_ev": 0.0, "n_ev": 0,
                       "sse_ev_ref": 0.0, "n_ev_ref": 0}])["skill"]


def _apply(h, x, tau):
    """Ap bo loc FIR h len chuoi vo huong x, tra (pred, y, ref) tren tap hop le."""
    k = horizon_steps(tau)
    i0, i1 = EXPERT_P, len(x) - k
    X = np.stack([x[i0 - q:i1 - q] for q in range(EXPERT_P)], axis=1)
    return X @ h, x[i0 + k:i1 + k], x[i0:i1]


def t12_nll_bounded():
    """NLL phai bi chan ngay ca khi mo hinh RAT tu tin va sai so RAT lon.

    Day la phep kiem sinh ra tu mot quan sat: o tau = 1000 ms, mat mat nhay
    len +33, +190, +40 o vai batch trong khi skill(val) van tang deu. Khong
    lam hong viec hoc, nhung lam ket qua phu thuoc seed nhieu hon muc nen co,
    va o cung lan chay do bon loai gio bi tut so voi ngan hang nho hon.
    """
    print("\n12. NLL bi chan khi dau logvar bi bao hoa")
    torch.manual_seed(0)
    m = PIMoE(1000, 30.0)
    with torch.no_grad():                       # ep mo hinh "rat tu tin"
        m.logvar_head.bias.fill_(-50.0)
    x = torch.randn(16, 3, int(30 * TASK_FS))
    o = m(x)
    lv_head = o["logvar"] - 2 * torch.log(x.std(dim=-1).clamp_min(1e-6))
    check("dau logvar bao hoa dung o -LV_RANGE",
          abs(lv_head.min().item() + LV_RANGE) < 0.05,
          f"min = {lv_head.min().item():.3f}, LV_RANGE = {LV_RANGE}")

    # Chan theo sai so CHUAN HOA, khong theo sai so tuyet doi. Cai dat ban
    # dau cua phep kiem nay dat sai so 50 lan do lech chuan roi doi loss nho -
    # do la doi sai: NLL cua mot bat ngo 50-sigma PHAI lon. Dieu can kiem la
    # loss khong vuot CAN GIAI TICH ma LV_RANGE dat ra:
    #     L <= 0.5 * (3*exp(LV_RANGE)*max(d/sd)^2 + 3*LV_RANGE)
    sd = x.std(dim=-1).clamp_min(1e-6)
    for k_sig in (1.0, 3.0):
        y = o["yhat"].detach() + k_sig * sd
        l, _ = nll_loss(o, y, lam_acf=0.0)
        bound = 0.5 * (3 * np.exp(LV_RANGE) * k_sig ** 2 + 3 * LV_RANGE)
        check(f"sai so {k_sig:.0f}*sigma: loss <= can giai tich",
              torch.isfinite(l) and l.item() <= bound + 1e-3,
              f"loss {l.item():8.1f}  can {bound:8.1f}")

    # So thang hai truong hop tren CUNG mot batch va cung sai so: dau logvar
    # bi chan (mo hinh hien tai) so voi dau logvar tu do truot xuong -50
    # (cach cu, noi rang buoc duy nhat la kep tuyet doi trong ham mat mat).
    # Day moi la phep so dung - so hai CAN o mot sd tuy y thi khong noi len gi.
    y1 = o["yhat"].detach() + sd
    l_new, _ = nll_loss(o, y1, lam_acf=0.0)
    unb = dict(o)
    unb["logvar"] = torch.full_like(o["logvar"], -50.0) + 2 * torch.log(sd)
    l_old, _ = nll_loss(unb, y1, lam_acf=0.0)
    # Ty le KY VONG la exp(12 - LV_RANGE): kep tuyet doi cho phep exp(-lv) len
    # e^12, con chan o dau chi cho e^LV_RANGE. Doi chieu voi con so do chu
    # khong voi mot nguong tuy y - nguong 1e4 dat luc truoc chi dung khi kep
    # ngoai con o -20, va no bao SAI ngay khi kep tro ve -12.
    exp_ratio = np.exp(12.0 - LV_RANGE)
    got = l_old.item() / l_new.item()
    check("chan o dau logvar chan duoc, chan tuyet doi thi khong",
          got > 0.5 * exp_ratio,
          f"ty le {got:.0f} lan (ky vong ~{exp_ratio:.0f})")

    # SAN NAM DUOI NGUONG, tuc kep -12 la rang buoc, khong phai san.
    #
    # San chi keo mot cua so ra khoi vung bao hoa cua kep khi
    #     -LV_RANGE + 2*log(san) > -12  <=>  san > exp(-LV_RANGE)
    # Quet do duoc: tren nguong (0.05) san cat spike tu +72 xuong +8 nhung lam
    # ramp sup ve +0.8510 voi bien do seed 0.3111; duoi nguong (0.01) dinh mat
    # mat trung den 3 chu so voi khong san va ramp giu +0.9777.
    #
    # Day la mot phep kiem ve THIET KE: neu ai do doi LV_RANGE hoac SD_FLOOR
    # ma vo tinh vuot nguong thi ramp se sup lai va khong ai biet vi sao.
    thr = float(np.exp(-LV_RANGE))
    check("SD_FLOOR nam duoi nguong exp(-LV_RANGE)",
          SD_FLOOR < thr,
          f"SD_FLOOR = {SD_FLOOR}, nguong = {thr:.4f}")

    # Cua so GAN PHANG - dung tinh huong da sinh ra spike. Loai ramp co doan
    # gio hang so tuyet doi, va o ria doan doc thi cua so phang trong khi dich
    # da doi.
    #
    # Can la MIN cua hai rang buoc, va phai lay min chu khong lay can cua san:
    # voi SD_FLOOR duoi nguong thi can cua san (5.5e5 o day) long hon han va
    # mot phep kiem dung no se qua ngay ca khi kep hong.
    flat = torch.full((8, 3, int(30 * TASK_FS)), 5.0)
    flat += 1e-4 * torch.randn_like(flat)
    of = m(flat)
    lf, _ = nll_loss(of, of["yhat"].detach() + 0.1, lam_acf=0.0)
    b_floor = 0.5 * (3 * np.exp(LV_RANGE) * (0.1 / SD_FLOOR) ** 2 + 3 * LV_RANGE)
    b_clamp = 0.5 * (3 * np.exp(12.0) * 0.1 ** 2 + 3 * 12.0)
    bound = min(b_floor, b_clamp)
    check("cua so gan phang: loss van bi chan",
          torch.isfinite(lf) and lf.item() <= bound + 1e-3,
          f"loss {lf.item():.1f}  can {bound:.3g} "
          f"(san {b_floor:.3g}, kep {b_clamp:.3g} -> "
          f"{'san' if b_floor < b_clamp else 'kep'} rang buoc)")

    # San CHI vao so hang logvar. Neu no cung duoc dung de chuan hoa dau vao
    # thi cua so phuong sai nho se den bo ma hoa duoi dang tin hieu bi thu
    # nho - do duoc: loai ramp tut tu +0.9669 xuong +0.7629 khi ap san cho ca
    # hai. Kiem bang cach do phuong sai cua dau vao da chuan hoa: no phai
    # bang 1 bat ke sd that nho den dau.
    sd_flat = flat.std(dim=-1, keepdim=True).clamp_min(1e-6)
    var_n = ((flat - flat.mean(-1, keepdim=True)) / sd_flat).var(dim=-1).mean()
    check("dau vao chuan hoa ve phuong sai 1 du cua so gan phang",
          abs(var_n.item() - 1.0) < 0.02,
          f"phuong sai {var_n.item():.4f}, sd that {sd_flat.mean().item():.2e} "
          f"<< SD_FLOOR = {SD_FLOOR}")

    l, _ = nll_loss(o, o["yhat"].detach() + sd)
    l.backward()
    g = max(p.grad.abs().max().item() for p in m.parameters()
            if p.grad is not None)
    check("gradient huu han", np.isfinite(g), f"max|grad| = {g:.3e}")


def t9_periodic_experts():
    """Chuyen gia tuan hoan phai du doan gan nhu chinh xac mot tin hieu nam
    trong bang cua no, va chuyen gia SAI bang thi khong.

    Phep kiem thu hai moi la phep co gia tri: neu MOI bang deu du doan tot
    thi ngan hang khong phan biet duoc gi, va gate khong the chon che do.
    """
    print("\n9. Chuyen gia tuan hoan: dung bang thi trung, sai bang thi truot")
    S, names = shape_filters(140)
    n = int(400 * TASK_FS)
    t = np.arange(n) / TASK_FS
    rng = np.random.default_rng(3)
    for f0, i_right, i_wrong in ((0.10, 0, 3), (0.80, 3, 0)):
        x = sum(rng.uniform(0.5, 1.5) * np.sin(2 * np.pi * f0 * (1 + 0.05 * j) * t
                                               + rng.uniform(0, 2 * np.pi))
                for j in range(3))
        s_r = _skill(*_apply(S[i_right], x, 140))
        s_w = _skill(*_apply(S[i_wrong], x, 140))
        check(f"f = {f0:.2f} Hz  ->  {names[i_right]}", s_r > 0.9,
              f"skill {s_r:+.4f}")
        check(f"f = {f0:.2f} Hz  ->  {names[i_wrong]} (sai bang)", s_w < s_r - 0.2,
              f"skill {s_w:+.4f}, kem hon {s_r - s_w:.3f}")


def t10_gust_experts():
    """Chuyen gia EOG tren mot chuoi xung EOG phai hon HAN Kalman van toc
    khong doi - do la ly do no ton tai.
    """
    print("\n10. Chuyen gia EOG tren chuoi xung EOG")
    from wind.generators import eog_shape as _eog
    from wind.moe import kalman_cv_filter as _kf
    S, names = shape_filters(140)
    nS = len(PER_BANDS)
    n = int(600 * TASK_FS)
    t = np.arange(n) / TASK_FS
    rng = np.random.default_rng(5)
    for tau in (140, 1000):
        Sx, nmx = shape_filters(tau)
        x = np.zeros(n)
        for t0 in np.arange(30, 570, 45.0):
            x += rng.uniform(1, 5) * _eog(t - t0, 10.5)
        s_e = _skill(*_apply(Sx[nS + 1], x, tau))          # eog_T10.5
        s_k = _skill(*_apply(_kf(tau, 1.0), x, tau))
        check(f"tau={tau:5d} ms  {nmx[nS+1]} vs kalman_l1",
              s_e > s_k, f"EOG {s_e:+.4f}  Kalman {s_k:+.4f}")


def t11_shape_acf():
    print("\n11. ACF cua hai ho chuyen gia moi")
    for lo, hi in PER_BANDS[:2]:
        r = periodic_acf(400, lo, hi)
        check(f"periodic [{lo:g},{hi:g}] Hz: R(0)=1, |R|<=1",
              abs(r[0] - 1) < 1e-12 and np.abs(r).max() <= 1 + 1e-12,
              f"R(0)={r[0]:.6f}, max|R|={np.abs(r).max():.6f}")
    # Du tre de phu ca T lon nhat: tu tuong quan cua mot xung dai T keo den
    # dung t = T. Ban dau phep kiem chi lay 400 tre = 8 s, ngan hon T = 10.5
    # va T = 20, nen no bao "ve 0 tai 0.0 s" cho ca hai - do la loi cua phep
    # kiem, khong phai cua eog_acf.
    for T in GUST_T:
        n = int(round(1.5 * max(GUST_T) * TASK_FS))
        r = eog_acf(n, T)
        z = np.argmax(np.abs(r) < 1e-9) / TASK_FS
        check(f"eog T={T:g} s: R(0)=1, ve 0 sau ~T",
              abs(r[0] - 1) < 1e-12 and abs(z - T) < 0.15 * T,
              f"R(0)={r[0]:.6f}, ve 0 tai {z:.1f} s")

    from wind.moe import SHAPE_RIDGE
    from scipy.linalg import toeplitz
    k = horizon_steps(140)
    for nm, R in (("eog T=10.5", eog_acf(EXPERT_P + k + 1, 10.5)),
                  ("per 0.05-0.15", periodic_acf(EXPERT_P + k + 1, 0.05, 0.15))):
        Rr = R.copy()
        Rr[0] *= 1.0 + SHAPE_RIDGE
        c = np.linalg.cond(toeplitz(Rr[:EXPERT_P]))
        a = wiener_coef(Rr, EXPERT_P, k)
        check(f"{nm}: nap cheo lam bai toan giai duoc",
              c < 1e7 and np.abs(a).max() < 5,
              f"cond {c:.1e}, max|a| {np.abs(a).max():.3f}")


def main():
    print("=" * 78)
    print("KIEM PI-MoE (W3.2 / W3.3)")
    print(f"luoi Tc = {TC_GRID} s | bang periodic {len(PER_BANDS)} | "
          f"gust T = {GUST_T} s | lambda Kalman = {KALMAN_LAMBDAS} | P = {EXPERT_P}")
    print("=" * 78)
    t1_wiener_bank()
    t2_sigma_independence()
    t3_kalman_fir()
    t4_ceiling_representable()
    t5_expert_isolation()
    t6_nll()
    t7_shapes_and_size()
    t8_acf_target()
    t9_periodic_experts()
    t10_gust_experts()
    t11_shape_acf()
    t12_nll_bounded()
    print("\n" + "=" * 78)
    if _fail:
        print(f"SAI {len(_fail)} phep kiem:")
        for f in _fail:
            print(f"   - {f}")
        return 1
    print("Tat ca dat.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
