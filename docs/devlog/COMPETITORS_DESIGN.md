# Thiết kế đối thủ H3 (INDI) và H4 (DOB thích nghi tần số) trên P2 — ĐÃ DUYỆT (2026-09-28, có chỉnh sửa, xem §5)

*2026-09-27 nháp; **duyệt 2026-09-28** với các chỉnh sửa ở §5 (các mục §0-§3 dưới đây đã sửa theo). Đăng ký:
`REGISTER_P2.md` §40 (trước lần chạy đầu tiên). H5 (chống lắc phản hồi góc tải): để sau, T2.*

## 0. Nguyên tắc chung (áp cho cả hai)

- **Chỉ thay phần xử lý nhiễu ở vòng vị trí.** Luật vị trí của Guo giữ nguyên:
  `F = m·a_d − d̂_mf − d̂_lf`, `a_d = K_γ e_γ + K_ν e_ν + g e3 + γ̈_d` (`simulink_blocks/position_controller.m`).
  Cùng K_γ, K_ν, cùng vòng tư thế Guo, cùng cảm biến, nhiễu, trễ, bộ giải. Đối thủ chỉ thay **nguồn của
  `d̂_mf` (và `d̂_lf`)**. So sánh vì vậy tách đúng câu hỏi: *ước lượng/dự đoán nhiễu bằng cách nào tốt hơn*.
- **Không đụng v1, không đụng `do_derivative` / `DO_12`.** Mỗi đối thủ là khối mới trong nhánh Variant P2
  (`P2/P2_Core/P2`), đi vào qua một Variant Source mới ở `Position_Observers`, giống cách N6 đi vào
  (`P2_N6_Sel`). Mặc định tắt → bit-exact (kiểm như `gd7_n6_prep`: v1 32/32, P2 lưu sẵn so từng bit).
- **Tune công bằng, đăng ký trước:** mỗi đối thủ được tune **tối đa 2 tham số vô hướng**, bằng **cùng thủ tục**
  đã dùng cho τ\* của MOBADC: lưới đăng ký trước, trên **A4 fixed-5, circle**, argmin sai số gộp, rồi **đông cứng**
  cho mọi bảng. Không tune lại theo quỹ đạo, trừ τ (theo đúng quy tắc τ, như MOBADC).
- **Cùng thông tin:** đối thủ không được biết thêm gì so với MOBADC (không biết L, không biết gió thật).

## 1. H3 — ước lượng nhiễu dựa trên gia tốc kiểu INDI (vòng ngoài Smeur 2018)

**Tên trong bài (cố định):** "ước lượng nhiễu dựa trên gia tốc kiểu INDI (vòng ngoài Smeur 2018)" -
**KHÔNG** gọi là bộ điều khiển INDI đầy đủ (vòng tư thế vẫn là của Guo).

**Nguồn:** Smeur, Chu, de Croon 2016, *J. Guidance Control Dyn.* 39(3) — INDI tư thế [?];
Smeur, de Croon, Chu 2018, *Control Eng. Practice* 73 — INDI tầng (cascaded) cho vị trí, loại nhiễu gió [?];
Sieberling, Chu, Mulder 2010, *JGCD* 33(6) — INDI và đồng bộ bộ lọc [?]. ([?] = cần kiểm trích dẫn trước khi viết bài.)

**Cấu trúc (dạng tương đương với luật Guo):** với `m a = F_thr − m g e3 + d` (d = mọi nhiễu lực: tải + gió),
INDI dùng gia tốc **đo** để suy ra nhiễu mà không cần mô hình:

    d̂_INDI = H(s) · [ m·a_meas − F_thr,est + m g e3 ]        (H = lọc thông thấp bậc 2, tần số cắt ω_f)
    F      = m·a_d − d̂_INDI                                   (thay d̂_mf + d̂_lf; wind model tắt)

- `a_meas`: gia tốc kế P2 (1 kHz, có nhiễu/lệch như danh định, khung quán tính — `S_acc`).
- `F_thr,est`: vector lực đẩy **ước lượng** từ lệnh đẩy qua mô hình trễ động cơ danh định (17 ms) và tư thế đo —
  **cùng bộ lọc H** cho hai vế (đồng bộ bộ lọc, điều kiện cốt lõi của INDI).
- Đây đúng là INDI tầng ngoài của Smeur 2018 viết lại theo khung Guo: phần "gia số" chính là `d̂_INDI`.
- Không có dự đoán τ (INDI là phản ứng tức thời); đó chính là điểm so sánh với dự đoán của MOBADC.

**Tune (1 tham số):** ω_f ∈ **{1, 2, 4, 8, 16} Hz** (thêm 1 Hz: băng thông vòng tư thế ~2.4 Hz) trên fixed-5
circle, argmin; biên → mở 1 lần theo quy tắc N0P.

**Giới hạn (ghi vào bài):** gia tốc kế của P2 **lý tưởng hoá** - đo gia tốc động học trong khung quán tính (+ nhiễu,
lệch), **không rò trọng lực do sai tư thế** → điều này **CÓ LỢI cho INDI và IM-est** (cả hai dùng gia tốc đo).

## 2. H4 — DOB thích nghi tần số (ước lượng tần số Marino–Tomei trên ước lượng DO)

**Nguồn:** Marino, Tomei 2002, *IEEE TAC* 47(8), "Global estimation of n unknown frequencies" [✓ trong MASTER_PLAN];
Bodson, Douglas 1997, *Automatica* 33(12) — loại nhiễu sin tần số chưa biết [?]; Chen và cộng sự 2016, *IEEE TIE*
63(2) — tổng quan DOBC [?].

**Cấu trúc:** đây là cách "ngoại sinh" chuẩn trong tài liệu — đúng câu hỏi của MASTER_PLAN §7.1:

    DO_Out (d̂_mf, DO giữ nguyên) → [mỗi trục ngang] bộ ước lượng tần số Marino–Tomei, n = 1 sin + hằng
                                  → (ω̂, biên, pha) → d̂_H4(t + τ) = hằng + biên·sin(ω̂ (t + τ) + pha)
    F = m·a_d − d̂_H4(t + τ) − d̂_lf                          (d̂_lf, wind model: như cột so sánh tương ứng)

- Khác (i) nội mô hình cố định (Guo): tần số **thích nghi online**, không đặt trước.
- Khác (ii) IM-est: IM-est **dựng lại ma trận DO** từ AR/RLS trên gia tốc UAV; H4 **không đổi DO**, chỉ ước lượng
  tần số trên đầu ra DO rồi ngoại suy pha — cấu trúc "tách" chuẩn của tài liệu (nhiễu coi là ngoại sinh).
- Dự đoán τ: như cột P/L3 — τ theo quy tắc τ (N0P riêng cho H4 trên fixed-5).

- **Số tần số n = 4, CÙNG n như IM-est** (AR(8) = 4 cặp; không cố định n = 1) + thành phần hằng.
- **DO bên dưới H4:** trên quỹ đạo lập trước - bảng tần số đúng của quỹ đạo (như L3); trên quỹ đạo **không lập
  trước / held-out - chỉ có DC** (không biết tần số quỹ đạo) → thông tin **ngang IM-est**.

**Tune (2 tham số):** hệ số thích nghi γ ∈ {¼, ½, 1, 2} × γ₀ (γ₀ chọn offline trên tín hiệu sin tổng hợp: hội tụ
tần số trong 10 s ở 0.4 Hz — không dùng dữ liệu dev) trên fixed-5 circle; τ theo N0P.

## 3. Cột và bảng (ĐÃ CHỌN, §5 mục 5)

Đề xuất hai mức thông tin, mỗi mức so trên **cùng tập** (circle_main đủ; S40 cho quỹ đạo khác):

| mức | MOBADC | H3 INDI | H4 DOB-AF |
|---|---|---|---|
| không cảm biến gió | L1 (Guo + dự đoán tải τ\*) | INDI (gió nằm trong d̂_INDI) | H4 + d̂_lf = 0 |
| có gió đo | L3 | INDI (không đổi — đã thấy gió qua gia tốc) | H4 + F̂(w_meas) |

(+ L0 Guo gốc làm mốc chung.) Chỉ số: sai số bám gộp, SE/LOO/trung vị ngày (§0.2), tỉ lệ kẹp góc, phân kỳ.
- **circle_main: hai mức** như bảng trên. **Nơi khác: một mức (có gió đo).**
- **BẮT BUỘC - hover trên N6_hover ĐẦY ĐỦ:** cột L3, L3_6, INDI, H4 (+ tập không chạm giới hạn §26).
- **Số 8 (T3b), vuông, T5 trên S40.**
- **Held-out GĐ8 có INDI và H4.**

## 4. Cần anh duyệt

1. Nguyên tắc §0 (chỉ thay nguồn d̂ ở vòng vị trí, vòng tư thế Guo chung) — đồng ý?
2. INDI dạng "d̂ từ gia tốc đo" (§1) thay vì INDI đầy đủ cả vòng tư thế — đồng ý? (INDI tư thế đầy đủ = đổi vòng
   tư thế → không còn so riêng phần xử lý nhiễu.)
3. H4 đặt trên **đầu ra DO** (không sửa DO) — đồng ý?
4. Lưới tune và ngân sách (≤ 2 tham số, fixed-5 circle, đông cứng) — đồng ý?
5. Bảng cột §3 — chọn hai mức hay chỉ một?

Ước công: code + kiểm offline (Octave) 1–2 ngày mỗi đối thủ; mỗi đối thủ 1 lần tune (~5 τ × 5 đoạn) + 1 bảng.

## 5. Duyệt 2026-09-28 (user) - các chỉnh sửa, đã đưa vào §0-§3
1. §0 đồng ý. Tên H3 trong bài: "ước lượng nhiễu dựa trên gia tốc kiểu INDI (vòng ngoài Smeur 2018)", không gọi là
   bộ điều khiển INDI đầy đủ.
2. §1 đồng ý. Giới hạn: gia tốc kế P2 lý tưởng hoá (không rò trọng lực do sai tư thế) → có lợi cho INDI và IM-est.
   Lưới ω_f thêm 1 Hz: {1, 2, 4, 8, 16} Hz.
3. §2 đồng ý, thêm: H4 dùng cùng n như IM-est; trên quỹ đạo không lập trước / held-out, DO dưới H4 chỉ có DC.
4. Ngân sách tune: ≤ 2 tham số, lưới đăng ký trước, fixed-5 circle, đông cứng; γ₀ từ sin tổng hợp.
5. §3: circle_main hai mức; nơi khác một mức (có gió đo); bắt buộc hover N6_hover đầy đủ (L3, L3_6, INDI, H4 +
   tập không chạm); held-out GĐ8 có INDI và H4; T3b, square, T5 trên S40.
6. H5 (chống lắc phản hồi góc tải): để sau, T2.
