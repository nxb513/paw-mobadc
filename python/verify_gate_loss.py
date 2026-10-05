#!/usr/bin/env python3
"""
verify_gate_loss.py -- Kiem so hang giam sat tien tri TRUOC khi quet lambda.

    python3 python/verify_gate_loss.py

===========================================================================
VI SAO PHEP KIEM NAY TON TAI
===========================================================================
So hang nay cham vao ham mat mat cua MOI lan huan luyen tu day tro di. Neu
no sai - sai dau, sai chuan hoa, hay chay gradient vao cho khong duoc phep -
thi moi bang ve sau van in ra binh thuong va van SAI. Do dung la loai loi da
xay ra ba lan o nhanh nay (window_batch lech mot buoc, khoa cache thieu fs,
fs khong xuong loader): khong cai nao bao loi, tat ca chi lech di.

Nen moi tinh chat cua so hang duoc phat bieu thanh mot dai luong KIEM DUOC:

  1. lam_gate = 0 di qua DUNG duong di cu, den tung bit.
  2. argmax cua muc tieu = argmin sai so that.
  3. Muc tieu BAT BIEN THEO TI LE: nhan cua so voi c thi q khong doi.
  4. Gradient KHONG chay vao ngan hang vat ly.
  5. Muc tieu da detach - khong co gradient qua chinh no.
  6. Nhiet do lam dung chieu: T nho -> nhon hon.
  7. Chuyen gia du KHONG nam trong muc tieu, va trong so cua no van tu do.
"""

import pathlib
import sys

import numpy as np
import torch

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from wind.moe import (  # noqa: E402
    GATE_T, PIMoE, TC_GRID_W5, gate_oracle_loss, nll_loss,
)

N_OK = N_BAD = 0


def check(name, ok, detail=""):
    global N_OK, N_BAD
    print(f"  [{'OK ' if ok else 'SAI'}] {name:<54s} {detail}")
    if ok:
        N_OK += 1
    else:
        N_BAD += 1


def make(seed=0, tau=150, fs=20.0, B=64):
    torch.manual_seed(seed)
    m = PIMoE(tau, 30.0, fs=fs, tc_grid=TC_GRID_W5)
    m.eval()
    g = torch.Generator().manual_seed(seed + 1)
    x = torch.randn(B, 3, m.window, generator=g) * 0.7
    x = torch.cumsum(x, dim=-1) * 0.05 + torch.randn(
        B, 3, m.window, generator=g) * 0.3
    y = torch.randn(B, 3, generator=g) * 0.5
    return m, x, y


def main():
    print("=" * 76)
    print("KIEM SO HANG GIAM SAT TIEN TRI CHO GATE")
    print("=" * 76)

    m, x, y = make()
    out = m(x)
    E = len(m.expert_names)

    # ---- 1. lam_gate = 0 khong duoc doi gi ----
    print("\n1. lam_gate = 0 phai tai lap DUNG duong di cu")
    l0, p0 = nll_loss(out, y, 0.1)
    l0b, p0b = nll_loss(out, y, 0.1, lam_gate=0.0)
    check("lam_gate = 0 cho dung mot gia tri, den tung bit",
          l0.item() == l0b.item(),
          f"{l0.item():.12f} vs {l0b.item():.12f}")
    check("phan 'gate' bao 0.0 khi tat", p0b["gate"] == 0.0)
    lg, pg = nll_loss(out, y, 0.1, lam_gate=0.3)
    check("lam_gate > 0 thi mat mat THUC SU doi",
          abs(lg.item() - l0.item()) > 1e-9,
          f"lech {lg.item() - l0.item():+.6f}")
    check("so hang gate duoc ghi lai de doc duoc", pg["gate"] > 0)

    # ---- 2. muc tieu tro dung chuyen gia tot nhat ----
    print("\n2. Muc tieu tro dung chuyen gia co sai so nho nhat")
    ye = out["yhat_expert"]
    sse = ((ye - y[..., None]) ** 2).sum(1)          # (B,E-1)
    ref = ((out["persist"] - y) ** 2).sum(-1).clamp_min(1e-8)
    q = torch.softmax(-(sse / ref[:, None]) / GATE_T, dim=-1)
    check("argmax(q) = argmin(sai so) tren MOI cua so",
          bool((q.argmax(-1) == sse.argmin(-1)).all()),
          f"{int((q.argmax(-1) == sse.argmin(-1)).sum())}/{len(q)} cua so")
    check("q la phan bo xac suat", torch.allclose(q.sum(-1),
                                                  torch.ones(len(q))))
    check("q khong phu chuyen gia du", q.shape[1] == E - 1,
          f"{q.shape[1]} cot so voi {E} chuyen gia (ke ca du)")

    # ---- 3. bat bien theo ti le ----
    print("\n3. Bat bien theo ti le - cua so gio manh khong duoc de bep")
    for c in (0.1, 10.0, 100.0):
        o2 = m(x * c)
        g1 = gate_oracle_loss(out, y)
        g2 = gate_oracle_loss(o2, y * c)
        # alpha doi theo c (gate nhin cua so da chuan hoa nen KHONG doi), nen
        # so sanh chinh muc tieu q chu khong so mat mat.
        s2 = ((o2["yhat_expert"] - (y * c)[..., None]) ** 2).sum(1)
        r2 = ((o2["persist"] - y * c) ** 2).sum(-1).clamp_min(1e-8)
        q2 = torch.softmax(-(s2 / r2[:, None]) / GATE_T, dim=-1)
        e = (q2 - q).abs().max().item()
        check(f"nhan cua so voi {c:g} thi q khong doi", e < 1e-4,
              f"lech lon nhat {e:.2e}   (mat mat {g1.item():.4f} -> "
              f"{g2.item():.4f})")

    # ---- 4. gradient khong duoc cham vao vat ly ----
    print("\n4. Gradient chi chay vao gate, khong vao ngan hang vat ly")
    check("ngan hang E la buffer, khong phai tham so",
          not m.E.requires_grad and "E" not in dict(m.named_parameters()))
    m2, x2, y2 = make(seed=3)
    m2.train()
    o = m2(x2)
    gate_oracle_loss(o, y2).backward()
    gs = {n: (p.grad is not None and p.grad.abs().sum().item() > 0)
          for n, p in m2.named_parameters()}
    check("gate.weight CO gradient", gs.get("gate.weight", False))
    check("logvar_head KHONG co gradient", not gs.get("logvar_head.weight",
                                                      False))
    check("chuyen gia du (res) KHONG co gradient",
          not gs.get("res.0.weight", False))

    # ---- 5. muc tieu da detach ----
    print("\n5. Muc tieu la HANG SO doi voi mo hinh")
    m3, x3, y3 = make(seed=4)
    o3 = m3(x3)
    # Manh hon ca "da detach": du doan cua chuyen gia KHONG HE co duong
    # gradient, vi chung chi la ham cua dau vao va cua buffer E. Ngan hang la
    # vat ly thuan, khong mot tham so hoc duoc nao. Neu ngay nao do co nguoi
    # them mot tham so vao duong do thi phep kiem nay bao ngay.
    check("yhat_expert khong he yeu cau gradient (ngan hang thuan vat ly)",
          not o3["yhat_expert"].requires_grad)
    check("persist khong he yeu cau gradient", not o3["persist"].requires_grad)
    g3 = gate_oracle_loss(o3, y3)
    ga = torch.autograd.grad(g3, o3["alpha"], allow_unused=True)[0]
    check("CO gradient qua alpha", ga is not None and ga.abs().sum() > 0,
          "" if ga is None else f"tong |grad| = {ga.abs().sum().item():.3f}")

    # ---- 6. nhiet do dung chieu ----
    print("\n6. Nhiet do lam muc tieu nhon hon khi T nho")
    ent = []
    for T in (0.01, 0.1, 1.0):
        qq = torch.softmax(-(sse / ref[:, None]) / T, dim=-1)
        ent.append(float(-(qq * torch.log(qq + 1e-12)).sum(-1).mean()))
    check("entropy tang theo T", ent[0] < ent[1] < ent[2],
          f"T=0.01 -> {ent[0]:.3f}, T=0.1 -> {ent[1]:.3f}, "
          f"T=1 -> {ent[2]:.3f}   (deu = {np.log(E - 1):.3f})")

    # ---- 7. chuyen gia du van tu do ----
    print("\n7. Trong so cua chuyen gia du KHONG bi so hang nay ep")
    m5, x5, y5 = make(seed=5)
    m5.train()
    o5 = m5(x5)
    a_res = o5["alpha"][:, -1].mean().item()
    gate_oracle_loss(o5, y5).backward()
    # So hang chi nhin alpha DA chuan hoa lai tren phan vat ly, nen no khong
    # co so hang nao keo rieng trong so cua chuyen gia du xuong. Kiem bang
    # cach xac nhan mat mat khong doi khi ta thay doi rieng cot do.
    with torch.no_grad():
        o6 = {k: (v.clone() if torch.is_tensor(v) else v)
              for k, v in o5.items()}
        al = o6["alpha"].clone()
        al[:, -1] *= 0.5
        o6["alpha"] = al
        d = abs(gate_oracle_loss(o6, y5).item()
                - gate_oracle_loss(o5, y5).item())
    check("doi rieng trong so chuyen gia du khong doi mat mat", d < 1e-6,
          f"lech {d:.2e}   (alpha_du trung binh {a_res:.3f})")

    # ---- 8. hat giong dieu khien duoc CA khoi tao ----
    print("\n8. Hat giong phai dieu khien ca KHOI TAO, khong chi lay mau")
    # Loi co san: torch.manual_seed() nam trong train(), tuc chay SAU khi mo
    # hinh da duoc dung - nen `seed` chi dieu khien viec lay mau batch. Do
    # duoc: hai tien trinh moi dung PIMoE cho tong tham so +0.347 va -10.536.
    # Hau qua nang nhat la cho luot quet lambda: so sanh lambda=0 voi
    # lambda>0 tren hai khoi tao khac nhau thi hieu ung bi tron voi nhieu
    # khoi tao, ma bien do do da la +-0.02 tren gio that.
    def w(seed):
        torch.manual_seed(seed)
        m = PIMoE(150, 30.0, fs=20.0, tc_grid=TC_GRID_W5)
        return torch.cat([p.detach().flatten() for p in m.parameters()])
    check("cung hat giong -> cung trong so ban dau",
          bool(torch.equal(w(0), w(0))))
    check("khac hat giong -> khac trong so ban dau",
          not torch.equal(w(0), w(1)),
          f"|lech| lon nhat {(w(0) - w(1)).abs().max().item():.4f}")

    print("\n" + "=" * 76)
    print(f"{N_OK} dat, {N_BAD} SAI")
    sys.exit(1 if N_BAD else 0)


if __name__ == "__main__":
    main()
