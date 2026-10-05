#!/usr/bin/env python3
"""
verify_w4_split.py -- Kiem ban do thanh phan cua W4-A.

    python3 python/verify_w4_split.py [--dataset dataset]

===========================================================================
VI SAO PHEP KIEM NAY TON TAI
===========================================================================
Toan bo gia tri cua W4-A treo o mot cau: loai gio giu ra phai THAT SU chua
tung xuat hien trong tap huan luyen.

Neu ban do sai - vi du quen rang composite goi gen_dryden - thi con so
"chuyen giao" van in ra binh thuong, van dep, va SAI. Khong co gi bao loi.
Dung loai loi da xay ra ba lan o nhanh nay (mot bo loc cho ba truc, cua so
lech mot buoc, yhat_expert la duong di thu hai).

Nen ban do trong run_w4_crossmodel.py duoc doi chieu o day bang HAI duong
doc lap:

  1. DOC MA - phan tich generators.py xem ham nao goi ham nao.
  2. DOC DU LIEU - doi chieu voi tham so ma bo sinh TU GHI vao metadata luc
     sinh (eog_starts, per_f, ramp_t0).

Duong 1 bat duoc ro ri cau truc; duong 2 bat duoc truong hop ma doc dung ma
du lieu tren dia lai duoc sinh boi mot phien ban khac.

Duong 2 ban dau dinh phan biet bang PHO. Do khong chay duoc, va t2_measure()
ghi lai so do vi sao - chenh giua hai mo hinh cung co voi nhieu cua chinh
phep uoc luong pho o do dai ban ghi nay.
"""

import argparse
import ast
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from run_w4_crossmodel import (  # noqa: E402
    ALL_TYPES, COMPONENT_OF, EXPERIMENT, TYPES_WITH, train_types_for,
)
from wind.generators import WIND_TYPES  # noqa: E402

N_OK = N_BAD = 0


def check(name, ok, detail=""):
    global N_OK, N_BAD
    print(f"  [{'OK ' if ok else 'SAI'}] {name:<52s} {detail}")
    if ok:
        N_OK += 1
    else:
        N_BAD += 1


# =========================================================================
def calls_of(tree, fname):
    """Ten cac ham ma fname goi truc tiep, cong cac chuoi hang no truyen di."""
    fn = next((n for n in ast.walk(tree)
               if isinstance(n, ast.FunctionDef) and n.name == fname), None)
    if fn is None:
        return set(), set()
    names, consts = set(), set()
    for n in ast.walk(fn):
        if isinstance(n, ast.Call):
            f = n.func
            names.add(f.id if isinstance(f, ast.Name) else
                      getattr(f, "attr", ""))
            for arg in n.args:
                if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
                    consts.add(arg.value)
    return names, consts


def t1_read_source():
    """Duong 1: ban do phai khop voi cai ma generators.py THAT SU goi."""
    print("\n1. Doi chieu ban do thanh phan voi ma cua generators.py")
    src = (HERE / "wind" / "generators.py").read_text()
    tree = ast.parse(src)

    GEN = {1: "gen_dryden", 2: "gen_von_karman", 3: "gen_iec_gust",
           4: "gen_ramp", 5: "gen_periodic", 6: "gen_composite",
           7: "gen_composite_mix"}

    # Nam loai THUAN la DINH NGHIA cua thanh phan cung ten - loai 5 chua
    # 'periodic' vi gen_periodic chinh la dinh nghia cua no, khong phai vi no
    # goi ai. Phan nay dung theo cau truc, khong phai mot phat hien.
    BASE = {1: "turb_dryden", 2: "turb_vk", 3: "eog", 4: "ramp",
            5: "periodic"}
    derived = {wt: {BASE[wt]} if wt in BASE else set() for wt in ALL_TYPES}

    # Phan KHONG hien nhien, va la phan phep kiem nay ton tai vi no: loai nao
    # THUA HUONG thanh phan cua loai khac qua loi goi ham.
    for wt, g in GEN.items():
        names, consts = calls_of(tree, g)
        if "gen_dryden" in names or ("_turb" in names and "dryden" in consts):
            derived[wt].add("turb_dryden")
        if "gen_von_karman" in names or ("_turb" in names and
                                         "von_karman" in consts):
            derived[wt].add("turb_vk")
        if "_eog_train" in names:
            derived[wt].add("eog")
        if "gen_periodic" in names:
            derived[wt].add("periodic")

    for wt in ALL_TYPES:
        print(f"       {wt} {WIND_TYPES[wt]:<15s} ma -> {sorted(derived[wt])}")

    # Kiem chinh: voi moi thanh phan, TYPES_WITH phai bang tap loai chua no.
    for comp, declared in TYPES_WITH.items():
        if comp == "combo":
            continue
        actual = tuple(sorted(wt for wt in ALL_TYPES if comp in derived[wt]))
        check(f"TYPES_WITH['{comp}'] khop ma",
              tuple(sorted(declared)) == actual,
              f"khai bao {tuple(sorted(declared))}, ma cho {actual}")

    # Rang buoc quyet dinh: tap huan luyen KHONG duoc chua thanh phan giu ra.
    for h in (1, 2, 3, 4, 5):
        comp = COMPONENT_OF[h]
        leak = [t for t in train_types_for(h) if comp in derived[t]]
        check(f"giu {WIND_TYPES[h]}: tap train khong co '{comp}'",
              not leak,
              f"train {list(train_types_for(h))}" if not leak
              else f"RO RI qua loai {leak}")

    # 6 va 7 co CUNG tap huan luyen, nen run_w4_crossmodel dung lai mo hinh
    # thay vi huan luyen hai lan (~22 phut). Neo su that do o day: neu ban do
    # doi ma cache van con thi no se dung lai nham mot mo hinh DA THAY loai
    # dang giu ra - va con so chuyen giao se dep mot cach gia.
    check("loai 6 va 7 cung tap huan luyen (cache dung duoc)",
          train_types_for(6) == train_types_for(7),
          f"{list(train_types_for(6))} vs {list(train_types_for(7))}")

    # A2: to hop giu ra nhung thanh phan PHAI con trong tap train - neu khong
    # thi no la A1 tra hinh va nhan bi sai.
    for h in (6, 7):
        tt = train_types_for(h)
        have = set().union(*(derived[t] for t in tt))
        need = {"turb_dryden", "eog", "periodic"}
        check(f"giu {WIND_TYPES[h]} ({EXPERIMENT[h]}): thanh phan VAN duoc thay",
              need <= have, f"thieu {sorted(need - have)}" if not need <= have
              else f"du ca {sorted(need)}")


# =========================================================================
def t2_measure(ds):
    """Duong 2: doi chieu voi THAM SO ma bo sinh tu ghi ra luc sinh.

    Ban dau toi dinh phan biet bang PHO: Dryden va von Karman khac nhau o so
    mu duoi cao tan. Do KHONG chay duoc, va do duoc vi sao:

        chenh hinh dang giua hai mo hinh (std cua log-PSD)
            L =  20 m -> 0.150     L = 50 m -> 0.270     L = 100 m -> 0.338
        nhieu cua log-periodogram mot doan  = pi/sqrt(6) = 1.283
        gop 50 lan chay test                             = 0.181

    Tin hieu cung co voi nhieu ngay ca sau khi gop ca tap test. Ban ghi 200 s
    o V = 5 m/s chi chua vai chu ky quanh tan so ma hai mo hinh khac nhau
    (V/2piL = 0.008-0.04 Hz). Mot phep kiem nhu the se chap chon, va mot phep
    kiem chap chon con te hon khong co phep kiem.

    Thay bang mot dai luong CHINH XAC: bo sinh tu ghi tham so cua tung thanh
    phan vao metadata luc sinh - eog_starts/n_eog khi co EOG, per_f/per_n khi
    co tuan hoan, ramp_t0 khi co doan doc. Su co mat cua chung la bang chung
    truc tiep va khong nhieu rang thanh phan do CO trong lan chay.

    Con lai mot khoang khong phu duoc: tham so khong phan biet duoc nhieu loan
    Dryden voi von Karman (ca hai deu chi la "turb"). Cho do dua hoan toan
    vao duong 1 - doc ma - noi da xac nhan gen_composite goi gen_dryden va
    gen_composite_mix goi _turb(..., "dryden"). Ghi ro o day de khong ai
    tuong phan do da duoc kiem hai lan.
    """
    import json
    print("\n2. Doi chieu tham so bo sinh ghi trong metadata")
    md = json.loads((ds / "metadata.json").read_text())["runs"]

    # khoa dac trung -> thanh phan ma su co mat cua no chung minh
    KEY = {"eog_starts": "eog", "per_f": "periodic", "ramp_t0": "ramp"}
    have = {}
    for r in md:
        for k, comp in KEY.items():
            if k in r:
                have.setdefault(comp, set()).add(r["wind_type"])

    present = {wt for r in md for wt in [r["wind_type"]]}
    for comp in ("eog", "periodic", "ramp"):
        want = tuple(sorted(t for t in TYPES_WITH[comp] if t in present))
        got = tuple(sorted(have.get(comp, set())))
        check(f"'{comp}' xuat hien dung o cac loai ban do khai bao",
              want == got, f"ban do {want}, metadata {got}")

    for h in (3, 4, 5):
        if h not in present:
            continue
        comp = COMPONENT_OF[h]
        leak = sorted(set(train_types_for(h)) & have.get(comp, set()))
        check(f"giu {WIND_TYPES[h]}: khong lan chay train nao co '{comp}'",
              not leak, "sach" if not leak else f"RO RI qua loai {leak}")


# =========================================================================
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default=None,
                    help="co thi chay them phep do tren du lieu that")
    a = ap.parse_args()

    print("=" * 78)
    print("KIEM BAN DO THANH PHAN CUA W4-A")
    print("=" * 78)
    t1_read_source()
    if a.dataset:
        t2_measure(pathlib.Path(a.dataset))
    else:
        print("\n2. (bo qua phep do tren du lieu - them --dataset de chay)")

    print("\n" + "=" * 78)
    print(f"{N_OK} dat, {N_BAD} SAI")
    sys.exit(1 if N_BAD else 0)


if __name__ == "__main__":
    main()
