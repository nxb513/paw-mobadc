# MASTER PLAN — PA-MOBADC với tải treo thực tế, dự đoán tải/gió và IM-est

> `docs/devlog/MASTER_PLAN.md`. Đọc cùng `CLAUDE_CODE_BRIEF.md` (luật làm việc), `TEST_PLAN_v2.md` (bảng trạng thái),
> `KE_HOACH_THUC_HIEN.md` (kế hoạch theo giai đoạn của user), `PLANT_P2_SPEC.md` (đặc tả plant), `docs/REGISTER_P2.md`
> (đăng ký). Khi mâu thuẫn: `REGISTER_P2.md` > brief > file này > KE_HOACH. `PROTOCOL_LOCK.md` chỉ quản lý v1
> (lưu trữ ở `v1-final`). Báo lại mọi mâu thuẫn. Tác giả duy nhất, không thầy/lab: `ADVISOR_NOTES.md`.
>
> **Đồng bộ 2026-09-25 (quyết định của user):** dự án chuyển sang **plant P2**; **v1 không vào bài** (giữ ở tag
> `v1-final` = `d3a7633` làm bằng chứng nội bộ). BRIDGE bỏ, thay bằng kiểm tra nội bộ GĐ3.
> Ký hiệu nguồn: **[✓]** đã đối chiếu thông tin xuất bản · **[?]** phải kiểm lại trên Google Scholar/IEEE Xplore
> trước khi đưa vào bài.

---

## PHẠM VI BÀI — CHỐT (quyết định của user 2026-09-30; thay mọi phạm vi cũ trong file này)

> Mọi mục bên dưới mâu thuẫn với khối này thì **khối này thắng**. Không thêm bước nào ngoài danh sách này.

**Mục tiêu:** chứng minh phương pháp **tốt hơn MOBADC** cho UAV mang tải treo trong **gió thật** (giao hàng hạ bằng
dây, cứu hộ).

| mã | đóng góp | bằng chứng (tập đoạn ghi rõ) |
|---|---|---|
| **C1** | dự đoán lực tải bù trễ vòng kín khi bay lộ trình | L3/L2 − 1: circle −50.3 % (circle_main, D2, §11.1), T3b −45.4 % (T3b_main, §34), square −24.8 % (square_main, §37); vững theo m_p, L (§41.4, S40), tổ hợp 2² (§49.2, S40), ζ_s, IMU, lực đẩy (§44.2, S40), nhiễu gió σ 0.1 (§49.1, S40 / S40hover). Hàng m_p 0.25 đã gộp lại theo envelope A2 (§50.1; đổi ≤ 0.3 điểm). |
| **C2** | **tính lực gió lên tải vào phần bù gió** — bù tĩnh (1 + K̂)·F̂ (iii-0), cho **hover và circle**; hậu nghiệm (D20, D22). Dev: hover S40hover +67.5 %, N6_hover +20.3 % (i0215 chi phối; không bão hoà +65.7 %), K̂ ±30 % vẫn +55.8 / +59.0 %; circle S40 −43.7 % (§59). (iii) mô hình con lắc là **kết quả âm** (§53). Nhạy với gai cảm biến gió (i0290, i0326; G15) | chỉ đứng nếu **H-static** (hover) và/hoặc **H-static-circle** đạt trên CONFIRM2 (§60.3: trung vị ngày ≥ 10 % VÀ h − 1.65·SE > 0 VÀ n_unsafe ≤ 1). |
| **C3** | biết trước gió **không giúp** trên 12 nhóm gió thật → đầu tư vào mô hình tải, không vào dự đoán gió | CỔNG G (§0.6, các nhóm N4b / N5 / N6). |
| **C4** | gain MOBADC gốc **mất ổn định** khi trễ động cơ > 17–25 ms | GĐ3 (§1.6.2, A4 fixed-5): 17 ms ổn định 10/10, 25 ms và 30 ms phân kỳ 10/10. |

**Thông điệp bài (sau đêm 17, §57):** dự đoán cần khi nhiễu **tuần hoàn / nhanh so với trễ vòng kín** — trên circle
L3 (C1) thắng INDI +112.9 % (circle_main); INDI ≈ 0.037 m trên mọi đoạn bất kể gió, tức lực tải do quỹ đạo mà INDI chỉ
đo được sau một nhịp trễ (giải thích, không chẩn đoán). Khi nhiễu **chậm** (hover), đo nhanh (INDI) là đủ: INDI/L3 − 1
−79.1 % trên tập không bão hoà của N6_hover (với cảm biến lý tưởng hoá, G3, G14). Đêm 18 (§58) đo INDI khi có bias
gia tốc kế ngang.

**So sánh:** Classical, DO, ESO, MOBADC (định nghĩa Guo; §46.3 / §49.3) + Classical/DO **có trim** (§47) + **INDI
tối thiểu** ("ước lượng nhiễu dựa trên gia tốc kiểu INDI (vòng ngoài Smeur 2018)", §40.1 / §50).

**BỎ HẲN:** IM-est; H4 DOB thích nghi (khối H4 trong model **để TẮT, không chạy**); held-out quỹ đạo không lập trước
(Giới hạn: **không khẳng định gì cho quỹ đạo không lập trước**); Monte Carlo; T3a; A7; gió tổng hợp; (iii) trên
T3b / square / T5; chạy tổng hợp cuối riêng.

**Lịch còn lại:** đêm 16 = xong (§51); đêm 16b = xong ((iii) NOT ACCEPTED, §53); đêm 17 = INDI (tune + bảng); đêm 18 = độ bền (iii-0) (§54.3, §58: N6_hover đầy đủ L3/INDI/(iii-0), K̂ ±30 % [đọc] + hệ số ±30 % [stress], INDI có bias gia tốc 0.086 / 0.17 m/s² trên S40hover, circle S40); đăng ký H-static (nếu đủ điều kiện) TRƯỚC khi mở CONFIRM2; đêm 19–20 = CONFIRM2 một lần (§60: D2, H-static, H-static-circle, H-hover; **bỏ H-model**; cột mô tả circle L0/L2/L3/V/(iii-0)/INDI, hover L3/(iii-0)/INDI/INDI+bias; H-static/H-static-circle chấm trên tập không bão hoà theo cột L3, n_unsafe trên toàn tập; ≥ 15 đoạn / ≥ 6 ngày; cấu hình đóng băng §60.6; chỉ mở sau khi tick xong MOBADC_FIDELITY + INDI_FIDELITY và §60 APPROVED; ≤ 7.5 h). EQUATIONS_TABLE ở GĐ11 (cuối).

**Quy tắc số liệu:** mọi con số trong tài liệu kết quả ghi rõ **tập đoạn** (circle_main / S40 / S40hover / N6_hover /
T3b_main / square_main / fixed-5); không trộn số của hai tập trong một phép so.

---

## 0. Cách dùng file này

- Mục 1: câu chuyện khoa học và đóng góp — mọi việc phải phục vụ một đóng góp ở đây.
- Mục 2: **mô hình plant P2** — công thức đầy đủ, giả thiết, nguồn, phép kiểm chứng. Không tự chế ngoài mục này.
- Mục 3–5: bộ điều khiển, dữ liệu gió, thống kê — phần lớn **giữ nguyên** từ hiện tại.
- Mục 6: pipeline code.
- Mục 7: kế hoạch theo giai đoạn, có **cổng quyết định**.
- Mục 8: khung bài báo. Mục 9: tài liệu tham khảo. Mục 10: việc làm ngay.

---

## 1. Câu chuyện khoa học

### 1.1 Bài toán
Quadrotor mang tải treo bằng dây, bay trong gió thật. MOBADC (Guo et al., 2020) **ước lượng** nhiễu tải (DO với
nội mô hình tần số cố định) và nhiễu gió (ESO) rồi bù. Vòng tư thế có trễ (~0.1–0.2 s) nên lực bù luôn đến muộn.

### 1.2 Ý tưởng
**Dự đoán** nhiễu trước τ giây và bù sớm:
- kênh tải: quay trạng thái DO theo nội mô hình, `d̂_mf(t+τ) = B e^{Aτ} ξ̂(t)`;
- kênh gió: dự đoán gió `ŵ(t+τ)` (PI-MoE, từ lịch sử cảm biến gió).

### 1.3 Bằng chứng v1 — ĐO LẠI TRÊN P2 (không vào bài dưới dạng số v1; tag `v1-final`)
| mã | bằng chứng trên v1 (con lắc phẳng) | nguồn | ghi chú khi đo lại trên P2 |
|---|---|---|---|
| E1 | Dự đoán tải: L3 so với **L2** (MOBADC + mode DC + cảm biến gió, không dự đoán) −50.8% pooled, giữ dấu mọi LOO [−66.2, −50.2]; so với L0 (Guo gốc) −60.4% | field_grid + SENS (REGISTER_ROBUST §23.1) | đo lại → D2 |
| E2 | Tắt tải → lợi ích ≈ 0 (circle, T5): dự đoán lực tải thật | REGISTER_C §4.28–4.31 | đo lại (GĐ6 đêm 4) |
| E3 | Cần nội mô hình đúng tần số: T5 IM-phys +4.1%, exact −48% — **đo ở τ 0.22 (không tối ưu), K = 0, 10 dòng đầu của T** | R-U1 (REGISTER_C §4.28–4.29) | đo lại với τ\* đúng (R-U1b trên P2) |
| E4 | τ\* phụ thuộc quỹ đạo: circle 230, T5 140, T3b 250, square 90, T3a 60 (cực tiểu nông) / L0.5 240, T5 L0.5 210 ms. "τ\* ≈ trễ vòng tư thế" **chỉ là cách đọc**, chưa xác lập | N0P (REGISTER_ROBUST §18.13, §23.3) | đo lại (GĐ6 đêm 1–2) |
| E5 | Dự đoán gió lên thân UAV: pooled h < 10% ở mọi ô N4b; nhưng ở 5 ô mốc 10% nằm trong 2 SE (do i0780); d200 h = 6.2% ± 1.9; chỉ K ≤ 1, chưa có gió mạnh | N4b (§26), SENS | đo lại trên P2 → CỔNG G |

### 1.4 Đóng góp dự kiến
| mã | đóng góp | trạng thái |
|---|---|---|
| **C1** | Dự đoán tải cho MOBADC: cơ chế (E2), điều kiện hiệu lực (E3), chọn τ (E4) | v1 = bằng chứng nội bộ; số của bài đo trên P2 |
| **C2** | **IM-est: MOBADC dự đoán với nội mô hình thích nghi tần số** — dùng được khi không biết trước quỹ đạo | frozen xong; online + held-out chưa |
| **C3** | Bản đồ dư địa dự đoán gió: khi nào có ích, khi nào không, vì sao | v1: thân UAV âm (nội bộ); trên P2 chưa |
| **C4** | Độ bền: quỹ đạo, dây, khối lượng tải, cường độ gió, lắc lớn | trên P2 |

Vai trò C2 vs C3 quyết định ở **CỔNG G** (định nghĩa khoá trong `docs/REGISTER_P2.md` §0).

### 1.5 Không phải đóng góp
Mô hình plant P2 là **mô hình chuẩn trong tài liệu** (mục 2). Không trình bày nó như phát minh. Chỉ phần
hiệu chỉnh tham số và kiểm chứng là việc của bài.

### 1.6 Cập nhật câu chuyện (2026-09-28, quyết định của user sau GĐ7, đêm 10 và P-QA — ghi nhận cho bài, KHÔNG phải cổng)
- **Số trên P2 (mô tả):** circle L3/L2 −50.3 %, V/L2 −53.9 % (V 0.01671 < L3 0.01802, `REGISTER_P2.md` §11.1);
  T3b L3/L2 −45.4 %, V/L2 −49.1 % (§34); square L3/L2 −24.8 %, V/L2 −31.6 % (§37). N6 (mô hình con lắc) không bổ sung
  ngoài dự đoán DO ở mọi quỹ đạo có dao động cưỡng bức (circle, T5 §31; square §37: h_model −4.5 %, trên cạnh +6.4 %
  nhưng ở góc −18.2 %).
- **Đọc cho bài:** khi quỹ đạo **lập trước** (circle, T3b, square), preview tham chiếu (V: đưa trước gia tốc tham chiếu τ_prev)
  đạt lợi ích **tương đương** dự đoán tải L3 (ở cả ba quỹ đạo V còn nhỉnh hơn một chút). Bài không trình bày L3 như
  cách duy nhất hay tốt nhất cho quỹ đạo lập trước; bảng quỹ đạo lập trước đặt L3 và V cạnh nhau (VP = kết hợp, chạy
  cuối cùng với các cột D2 còn lại).
- **Giá trị riêng của dự đoán** nằm ở chỗ preview không làm được:
  1. **hover / giữ vị trí**: không có tham chiếu tương lai để preview. Bằng chứng khám phá: h_model hover +18.2 % gộp,
     +61.4 % trên tập không chạm giới hạn (§27, §29); claim H-model đã đăng ký cho CONFIRM2 (§28.1).
  2. **quỹ đạo không lập trước** (tham chiếu không biết trước, không dừng): preview không khả dụng → **GĐ8 held-out
     là trọng tâm** của bài (A8/G3/G7; so (i) nội mô hình cố định, (ii) IM-est, (iii) mô hình con lắc trên cùng tập,
     §7.1).
- **Dự đoán gió (C3):** CỔNG G = NO ở mọi nhóm (§27) → C3 là bản đồ "khi nào không có ích"; P-QA (§35): cột P chịu
  **"phản ứng ngoài phân bố của PI-MoE với các bước nhảy một mẫu trong chuỗi gió"** (cách viết cố định). §38: đó là
  **gai máy đo sóng âm** (A 0.94, 4/198 file giữ 80 % số gai, hai ngày 2024-02-16 và 2024-04-27/28) - giới hạn dữ
  liệu; hậu nghiệm bỏ 30 đoạn có gai: D2, T3b, h_model đổi ≤ 0.6 điểm, không đổi dấu.

---

## 2. MÔ HÌNH PLANT P2 (`PlantModel = 'p2'`)

**Đặc tả đầy đủ, tham số và nguồn: `docs/devlog/PLANT_P2_SPEC.md` (chờ duyệt ở GĐ1).** Mục này chỉ giữ phương
trình lõi và các quyết định đã chốt. P2 = con lắc 3D dây cứng (2.1–2.7) + lực cản bậc hai tải và thân (2.8) +
động cơ bậc nhất + cảm biến gió/IMU/vị trí + điều khiển rời rạc.

### 2.1 Giả thiết
- **A1** Dây cứng, không giãn, khối lượng không đáng kể, luôn căng (T > 0); T ≤ 0 → cờ "slack", không dùng số đoạn đó.
- **A2** Tải là chất điểm. **A3** Điểm treo trùng trọng tâm UAV (Guo 2020, Assumption 2) → dây không tạo mô-men.
- **A4** UAV là vật rắn; động lực học tư thế như Guo 2020, eq. (5), (19)–(20), thêm động cơ bậc nhất (spec).
Tương đương dạng hình học SE(3) × S² của Sreenath, Lee & Kumar (CDC 2013) [✓], Sreenath, Michael & Kumar (ICRA 2013) [✓].

### 2.2 Ký hiệu
W quán tính, **e3 hướng lên**, trọng lực −g e3. x_Q, v_Q: UAV; m_Q = 1.121 kg. m_L = m_p; L dây.
**q ∈ S²** từ UAV xuống tải (treo tĩnh q = −e3), x_L = x_Q + L q; **ω ⊥ q**, q̇ = ω × q.
F = f R e3. F_wQ, F_wL: lực gió lên thân, lên tải. F_d: damping cấu trúc dây. μ = m_Q m_L/(m_Q + m_L).

### 2.3 Phương trình (F_d là NỘI LỰC — tác dụng lên cả hai vật, quyết định của user)
```
m_Q a_Q = F − m_Q g e3 + T q + F_wQ − F_d                                 (2.1)
m_L a_L =   − m_L g e3 − T q + F_wL + F_d                                 (2.2)
T  = μ [ q·F_wL/m_L − q·(F + F_wQ)/m_Q + L|q̇|² ]      (q·F_d = 0)         (2.3)
v̇_Q = (F + T q + F_wQ − F_d)/m_Q − g e3                                   (2.4)
q̇   = ω × q                                                               (2.5)
ω̇   = (1/L) q × [ (F_wL + F_d)/m_L − (F + F_wQ − F_d)/m_Q ]               (2.6)
```
Kiểm tĩnh: F = (m_Q + m_L) g e3, q = −e3, ω = 0, không gió ⇒ T = m_L g, a_Q = 0 (đã kiểm tay).
Chống trôi: q̂ = q/|q|, ω̂ = ω − (ω·q̂)q̂; log max||q|−1|, max|ω·q| (ngưỡng 1e-6).

### 2.4 Nhiễu mà bộ điều khiển thấy
m_Q ν̇ = F − m_Q g e3 + d_mf + d_lf ⇒ **d_mf = T q − F_d** (gồm cả −m_L g e3 khi treo tĩnh), **d_lf = F_wQ**.
Đây là điều kiện `payload_z_on = 1` đã phân kỳ ở v1 (`I-3.5`, `X-esoatt`) → kiểm ở GĐ3.

### 2.5 Damping dây (quy ước đã chốt)
F_d = −c L (ω × q), **c = 2 ζ_s ω_n m_L**, ω_n = √(g/L) — định nghĩa với **điểm treo cố định**: khi UAV có chuyển
động áp đặt, (2.6) cho đúng số hạng −2ζ_s ω_n ω như con lắc v1 (V2 khớp v1). Trong vòng kín (UAV tự do) hệ số cản
hiệu dụng là c/μ; phần mơ hồ này được bao bởi độ nhạy ζ_s ∈ {0.02, 0.05, 0.12} (giá trị danh định: spec).

### 2.6 Lực khí động — bậc hai, vận tốc tương đối, hiệu chỉnh tại U_ref
```
F_wL = ½ ρ (C_D A)_L |w − v_L| (w − v_L),   (C_D A)_L = 2 K K_w /(ρ U_ref)   [K = 0 ⇒ (C_D A)_L = 0]   (2.8)
F_wQ = ½ ρ (C_D A)_Q |w − v_Q| (w − v_Q),   (C_D A)_Q = 2 K_w /(ρ U_ref)                                (2.8b)
```
Tại v = 0, U = U_ref hai lực bằng lực v1 (K K_w U_ref và K_w U_ref). **U_ref = V_ref = 5 m/s** (mốc khoá của K_w:
1.0 N tại 5 m/s); trung vị T.U của 25 đoạn T.stable = 5.089828 m/s, lệch 1.8% → mốc khoá là đại diện (REGISTER_P2
§0.10). ⇒ (C_D A)_Q = 0.0653 m², (C_D A)_L = K·0.0653 m²; envelope P2 (REGISTER_P2 §0.10) K = 0.5, m_p = 0.5: U_max = 10.86 m/s.

**Mô hình lực gió của bộ điều khiển (quyết định của user):** cùng dạng bậc hai, tham số danh định, vận tốc tương
đối w − v_Q. L2/L3 đưa gió ĐO qua mô hình này; P đưa gió DỰ ĐOÁN (150 ms); **O = gió thật w(t+τ_w\*) qua CHÍNH mô hình lực của
bộ điều khiển**, τ_w\* đo trên P2 bằng bước N0W (REGISTER_P2 §0.3.1) (mô hình lực giữ cố định) ⇒ dư địa = giá trị của biết trước gió. Sai số tham số lực cản → Monte
Carlo riêng. Cột phụ tuỳ chọn "oracle lực thật" (lực thật tại t+τ): báo riêng, **không dùng cho CỔNG G**.

### 2.7 Kiểm chứng offline (bắt buộc trước Simulink) — V1–V7 như cũ; **V6 chạy ở cả ζ_s = 0 và ζ_s > 0** (F_d
nội lực ⇒ động lượng tổng bảo toàn); V2–V4 dùng chế độ UAV **áp chuyển động** (a_Q cho trước); V6 dùng chế độ tự do.
Unit test thêm cho động cơ, cảm biến, rời rạc (spec). File: `plant_p2_derivative.m`, `verification/verify_plant_p2.m`.

### 2.8 Không mô hình hoá (Giới hạn): dây đàn hồi/chùng (Kotaru 2017), tải vật rắn, điểm treo lệch trọng tâm,
tương tác khí động cánh quạt–tải, gió thẳng đứng, mô-men gió.

---

## 3. Bộ điều khiển (giữ nguyên, chỉ tóm tắt để trích)

- **MOBADC** (Guo et al., 2020, eq. (9)–(20)) [✓]: vòng vị trí DO (nội mô hình điều hoà, Guo & Chen 2005 [✓]) + ESO;
  vòng tư thế ESO. Gain theo Appendix của Guo.
- **Dự đoán tải:** d̂_mf(t+τ) = B e^{Aτ} ξ̂(t); nội mô hình theo trục (`DoWAxis`): IM-single, IM-phys, exact, IM-est.
- **Preview tham chiếu:** feedforward γ̈_d(t + τ_prev).
- **Dự đoán gió:** PI-MoE đóng băng (checkpoint `w4_frozen_20hz_t150_train2345_s0`, kiểm sha256), đầu vào lịch sử gió đo.
- **IM-est (C2):** RLS trên AR(2n) của gia tốc UAV đo được, fs = 1 Hz sau lọc chống aliasing 0.4 Hz, λ = 0.99,
  loại nghiệm > 0.9·Nyquist, cổng |z|, gộp tần số sát nhau, theo dõi nghiệm; nội mô hình
  {0, ω̂_k, ω_n = √(g/L)}; 25 khe cố định; rebuild 1 Hz, kiểm eig trước khi tráo, giữ ma trận tốt gần nhất;
  Variant Source (tắt = bit-exact). Tài liệu nền cho ước lượng tần số online: Marino & Tomei (TAC 2002) [✓],
  Hsu, Ortega & Damm (TAC 1999) [?], Regalia (ANF, 1991) [?], Bodson & Douglas (Automatica 1997) [?],
  Ljung, *System Identification* (RLS/AR) [?]. **Điểm mới phải nêu rõ so với các công trình này**: ghép ước lượng
  tần số với **dự đoán** nhiễu (quay e^{Aτ}) trong MOBADC có tải treo, dùng gia tốc UAV (không cần tương lai quỹ đạo).
- **Đối thủ dự kiến (G5):** INDI (Smeur, Chu & de Croon, JGCD 2016 [?]; Tal & Karaman, TCST 2021 [?]),
  DOB thích nghi tần số (Marino–Tomei), điều khiển có phản hồi góc tải (Sreenath/Lee [✓]; Klausen, Fossen &
  Johansen JIRS 2017 [✓]) hoặc MPC.

---

## 4. Dữ liệu gió và mô hình gió
- Gió thật NREL M5, 20 Hz; đoạn 200 s; cửa sổ thống kê t ≥ 140 s. Tập: field_grid_K050 (30 đoạn, 25 T.stable),
  exploration 32 ngày (tải ở GĐ0), **CONFIRM2 16 ngày (khoá, `CONFIRM2_MANIFEST.json`, chỉ mở ở GĐ10)**,
  confirm cũ (đã dùng, không chạy lại).
- U của đoạn = **trung bình vector trong cửa sổ thống kê** (như T.U, `sweep_field_grid.m:182`), dùng cho envelope và bin.
- Envelope P2 (**mới**, 2026-09-25, thay θ_DC ≤ 15° của v1; REGISTER_P2 §0.10): đoạn nằm trong envelope nếu UAV giữ
  được vị trí trước tổng lực gió tĩnh (thân + tải, bậc hai tại U): nghiêng cần ≤ 0.8·TILT_MAX và lực đẩy cần
  ≤ 0.8·F_TOT_MAX (lực đẩy danh định). Tính a priori từ U (`python/p2_envelope.py`); θ tải = atan(F_wL/(m_L g)) chỉ
  báo. U_max = 13.30 / 10.86 / 9.41 m/s ở K = 0 / 0.5 / 1.0 (m_p 0.5). Tập dev P2 theo envelope này
  được cố định và in danh sách ở GĐ5.
- Mô hình rối tổng hợp (nếu cần): Dryden/von Kármán theo MIL-F-8785C / MIL-HDBK-1797 [?].

---

## 5. Thống kê và báo cáo (giữ nguyên + chuẩn mới)
- Metric chính (REGISTER_P2 §0.2, cùng định nghĩa như PROTOCOL_LOCK của v1): mỗi đoạn `m_i = mean(norm(p_d − p))` trên cửa sổ t ≥ TStat (trung bình chuẩn,
  không phải RMS); gộp `sqrt(mean(m_i²))` trên tập đoạn.
- Luật pool: L1 envelope; L2 một bảng một tập đoạn (**mỗi quỹ đạo một bảng**, pool trên tập dev P2 đã đăng ký —
  hạ tầng sửa `X-segset` ở GĐ5); L3 số headline từ bảng chính.
- Mỗi số chính: pooled + **SE paired jackknife theo ngày** + trung vị theo ngày + **LOO [min, max]** + đoạn ảnh
  hưởng nhất (Efron & Tibshirani, *An Introduction to the Bootstrap* [?] cho jackknife).
- Đăng ký trước, không đổi ngưỡng sau khi thấy số, báo cả MISS.
- Tập xác nhận: claim trên P2 được xác nhận **một lần** trên CONFIRM2 (GĐ10).

---

## 6. Pipeline code

```
init_MOBADC_params  →  op_set / op_condition  →  pa_configs (cột) → pa_cell (1 run)
      │                                                  │
      ├─ PlantModel: 'planar_v1' (mặc định, bit-exact v1) | 'p2'
      ├─ (P2) lực cản bậc hai tải/thân, mô hình lực gió bậc hai của bộ điều khiển, động cơ,
      │        cảm biến gió/IMU/vị trí, điều khiển rời rạc — tham số theo PLANT_P2_SPEC
      ├─ ImEstOnline: 0 (mặc định) | 1   (Variant Source)
      └─ các option cũ (WindOff, SensorDelayMs, DoWAxis, TauPred, ...)
                                                         │
batch_robust('<khối>')  ── checkpoint theo đoạn (và theo τ) ── log đầy đủ thông báo lỗi
      │
pool_rule (L1/L2) → báo cáo chuẩn mục 5 → REGISTER_*.md → TEST_PLAN_v2
```
- P2 là **Variant Subsystem** mới thay khối con lắc + Memory khi `PlantModel = 'p2'`; v1 giữ nguyên để bit-exact.
- `G.cond` ghi mọi option trên + git hash + fingerprint model.
- Log mỗi run P2 thêm: T_min, cờ slack, max||q|−1|, θ_max, sat_frac.
- Gate bit-exact sau mọi thay đổi: `verify_repro`, `check_results_numbers`, `check_all`, `extract_eml --check`.
- Quy trình git/model: user build + push `baseline1.slx`; Claude Code không giả định slx đã cập nhật.

---

## 7. KẾ HOẠCH THEO GIAI ĐOẠN

Theo `KE_HOACH_THUC_HIEN.md` (GĐ0–11, điểm quyết định D1–D5). Mã việc trong `TEST_PLAN_v2.md`. Tóm tắt:

| GĐ | nội dung | cổng |
|---|---|---|
| 0 | tag `v1-final`, đồng bộ tài liệu, tải 32 ngày exploration (gặp thầy: bỏ, `ADVISOR_NOTES.md`) | — |
| 1 | `PLANT_P2_SPEC.md` + `REGISTER_P2.md` §0 (D2–D4, CỔNG G, oracle, nhóm điều kiện) | user APPROVED |
| 2 | 2a hàm thuần + V1–V7 + unit test (Octave); 2b nối Simulink (Variant), gate bit-exact | 7/7 PASS |
| 3 | **kiểm tra NỘI BỘ** (thay BRIDGE, không vào bài): bật từng thành phần P2 trên circle, 5 đoạn cố định §18.6; ca khó (hover có tải, T5 có tải không gió, T5 L1.5, m_p lớn) | **D1**: còn phân kỳ? |
| 4 | sửa bộ điều khiển nếu còn phân kỳ (chẩn đoán có ngân sách) | — |
| 5 | `REGISTER_P2.md` phần giao thức: tập dev theo envelope P2, mỗi quỹ đạo một bảng (hạ tầng `X-segset`), quy tắc τ, chuẩn báo cáo | user APPROVED |
| 6 | τ\* theo điều kiện (quy trình N0P, lưới 0:20:400 + mịn 10 ms); bảng chính circle; tách cơ chế | **D2** |
| 7 | gió (N5-A, N5-B, N6-oracle, N4b-P2) + tải diện rộng (N3, N2, m_p ∈ {0.25, 0.5, 0.65}, hover, N1c, N4a, ngưỡng góc lắc) | **D3 = CỔNG G** |
| 8 | IM-est: R-U1b (đăng ký lại trên P2) → A-CP1.5 … A-CP4 → held-out — **trọng tâm của bài** (mục 1.6) | **D4** |
| 9 | lý thuyết, đối thủ, Monte Carlo (gồm sai số tham số lực cản), kiểm tài liệu | — |
| 10 | CONFIRM2, một lần | — |
| 11 | viết, nộp | **D5** |

Định nghĩa D2–D4 và CỔNG G: **chỉ** trong `docs/REGISTER_P2.md` §0 (đăng ký trước GĐ3).

### 7.1 Hướng tính mới cho GĐ8 (ghi 2026-09-25 theo quyết định của user — **CHƯA LÀM**, chưa đăng ký)

So **3 cách dự đoán nhiễu tải** trên tập held-out (tham chiếu không dừng), cùng khung MOBADC, cùng τ:

| # | cách | cần biết | ước lượng tần số? |
|---|---|---|---|
| (i) | nội mô hình **tần số cố định** (Guo 2020; IM-single / IM-phys) | tần số đặt trước | không (cố định) |
| (ii) | **IM-est** (RLS/AR trên gia tốc UAV, mục 3) | không | có (online) |
| (iii) | **dự đoán bằng mô hình vật lý con lắc**: L đo được + gia tốc UAV, tích phân phương trình con lắc (2.5–2.6) tiến τ để có lực dây tại t + τ | L (đo được), gia tốc UAV | **không** |

- **Luận điểm:** nhiễu tải là **NỘI SINH** — sinh ra bởi chính chuyển động của UAV và nằm trong vòng kín (lực dây phụ
  thuộc gia tốc UAV, gia tốc UAV phụ thuộc lệnh bù). Các bộ ước lượng tần số / khử nhiễu hình sin trong tài liệu
  (Marino–Tomei 2002 [✓], Bodson–Douglas 1997 [?], ANF/Regalia 1991 [?]) giả định nhiễu **ngoại sinh**. Bài phải nói
  rõ hệ quả của khác biệt này cho (i) và (ii), và (iii) là phép thử trực tiếp: nếu biết vật lý thì không cần ước lượng
  tần số.
- **Hiện tượng "IM-est frozen nhỉnh hơn exact-frequency reference"** (`Q-est>ref`, v1) ghi là **câu hỏi cần giải
  thích trong khung nội sinh** này (vd tần số hiệu dụng của nhiễu vòng kín khác tần số tham chiếu) — không điều tra
  trước held-out (brief 2.8).
- Còn phải thiết kế trước khi đăng ký (GĐ8): trạng thái đầu (q, ω) cho (iii) lấy từ đâu (vd hướng q từ d̂_mf của DO,
  hoặc đo góc dây — phải khai báo đo gì); (iii) có cần ζ_s và C_D·A của tải không (mô hình danh định, sai số → Monte
  Carlo); ngưỡng D4 áp cho so sánh nào. Tất cả vào `REGISTER_P2.md` bằng sửa đổi **trước** A-HO.
- **Cập nhật 2026-09-27 (sau CỔNG G = NO, `REGISTER_P2.md` §27-28):** ứng viên (iii) có **bằng chứng sơ
  bộ mạnh ở hover** (khám phá, tập dev, không phải cổng): khối N6 = con lắc tuyến tính (UAV đứng yên), bộ quan sát
  Luenberger trên d̂_mf của DO, lan truyền 280 ms với **gió đo** →
  `h_model = 1 − L3_6/L3` = **+18.2 % gộp, +59.3 % trung vị theo ngày** (136 đoạn, 43 ngày); lợi ích đến từ mô
  hình, **không** từ biết trước gió (h_6,pred +0.86 %). Đây là một dạng đầu tiên của (iii) - chưa có đầu vào gia
  tốc UAV, nên chưa phải (iii) đầy đủ.
  - Xác nhận: giả thuyết **H-model** đã đăng ký cho CONFIRM2 (§28.1: hover, K 0.5, tập định nghĩa N6_hover, τ 280
    ms; trung vị ngày ≥ 10 % VÀ h_model − 1.65·SE > 0), chạy ở GĐ10.
  - Bước khám phá tiếp: **N6X** (§28.2) - cùng số hạng cộng lên dự đoán tải của DO trên circle_main (τ 290 ms) và
    T5_main (τ 170 ms), đo τ_m* trên fixed-5 (N0M): mô hình con lắc có bổ sung được **ngoài** dự đoán DO khi có dao
    động cưỡng bức không.
  - **Cập nhật 2026-09-28 (quyết định của user sau square, §37):** trên square số hạng N6 làm tệ hơn ở nửa **góc**
    (UAV phanh / dừng: −18.2 %, không chạm −28.0 %) và giúp ở nửa **cạnh** (+6.4 %). **Giả thuyết:** mô hình N6 chỉ
    có **gió** làm đầu vào, thiếu **gia tốc UAV** - khi UAV phanh, chuyển động điểm treo kích con lắc mà N6 không
    thấy. Vì vậy ở GĐ8, **(iii) ĐẦY ĐỦ = con lắc tuyến tính với đầu vào GIÓ + GIA TỐC UAV** (lệnh hoặc đo - khai báo
    khi đăng ký), so với **(i) nội mô hình cố định, (ii) IM-est, (iv) preview tham chiếu (V)**, trên **circle,
    T3b, square, T5, hover + held-out không dừng** (trọng tâm, mục 1.6). N6 hiện tại (chỉ gió) giữ vai trò cột
    tham chiếu "(iii) rút gọn".
  - Khi đăng ký GĐ8: so **(i) nội mô hình cố định, (ii) IM-est, (iii) mô hình vật lý con lắc** trên **cùng tập**
    đoạn (cùng quỹ đạo, cùng τ, cùng khung MOBADC); (iii) phải khai báo có/không thêm gia tốc UAV làm đầu vào (nếu có
    thì là thay đổi mô hình so với N6, đăng ký riêng), và trạng thái đầu lấy từ d̂_mf của DO (như N6) hay đo góc dây.
  - **Cập nhật 2026-09-29 (quyết định của user sau đêm 12, `REGISTER_P2.md` §41-42):** F1 (L ±20 %), F2 (m_L ±20 %)
    GIỮ trên S40hover; **F3 (C_D·A ±30 %) KHÔNG GIỮ** (−343 % / −310 %) với dạng N6 hiện tại. Cơ chế giả thuyết
    (§41.3): số hạng N6 là "thay đổi dự đoán" nhưng **không triệt tiêu DC** - mọi lệch giữa cân bằng của mô hình và
    ước lượng tĩnh của DO (gồm cả sai số feed-forward thân) thành lực lệch kéo dài. Chẩn đoán một vòng ở đêm 14 (§42).
    - **ĐIỀU KIỆN CHẤP NHẬN (iii) ĐẦY ĐỦ - đăng ký (§42.0):** mô hình con lắc đầy đủ (gió + gia tốc UAV) phải qua
      F1-F3 trên **S40hover** - L ±20 %, m_L ±20 %, **C_D·A tải và C_D·A thân riêng rẽ ±30 %** - với **h_model > 0
      VÀ mọi giá trị LOO > 0 ở MỌI biến thể** (cùng luật đọc §39.2). Không đạt → (iii) không được báo là đóng góp.
    - **Hướng thiết kế (ghi sẵn, CHƯA chốt):** DO giữ phần tĩnh (DC), số hạng mô hình chỉ lo phần **dao động** (triệt
      tiêu DC, vd lọc thông cao hoặc lấy cân bằng từ chính ước lượng DO). Chốt khi đăng ký GĐ8.
    - **H-model (CONFIRM2, §28.1) giữ nguyên.** Nếu (iii) đạt điều kiện trên ở dev → đăng ký thêm **H-model(iii)**
      **TRƯỚC** khi mở CONFIRM2 (GĐ10).
    - Bài báo: báo F3 của dạng N6 hiện tại như **lý do thiết kế** của (iii) (phần Results/Discussion).
  - **Cập nhật 2026-09-29 (sau đêm 14, `REGISTER_P2.md` §44-45): (iii) ĐÃ ĐĂNG KÝ (§45, user duyệt).** Hướng
    "DO giữ DC, mô hình chỉ lo phần dao động" ở trên **được thay** bằng: mô hình con lắc **vòng hở** (không hiệu chỉnh
    theo trạng thái tải), đầu vào gió đo + **gia tốc lệnh**, đầu ra **toàn bộ** lực tải dự đoán trước τ_m, bù thẳng;
    DO chỉ ước lượng **phần dư** (qua cổng đầu vào đã biết) → không lệch DC với mọi sai số tham số. Chấp nhận trên
    S40hover (10 biến thể, §45.3); kiểm "không gây hại" trên circle S40 (§45.7, mô tả; tệ hơn giữ dấu LOO → ghi
    giới hạn chế độ dùng). Dự phòng **(iii-obs)** (có observer hiệu chỉnh) chỉ đăng ký riêng nếu (iii) trượt.
    Biến thể so sánh: (iii-0) bù tĩnh, (iii-m) gia tốc đo + bias {0, 0.086, 0.17 (ngang), 0.39 (3 trục)} m/s².

---

## 8. Khung bài báo (dự kiến)
1. Introduction — bài toán, khoảng trống (MOBADC chỉ ước lượng; nội mô hình cố định), đóng góp C1–C4.
2. Model — P2 (mục 2, PLANT_P2_SPEC), giả thiết A1–A4, hiệu chỉnh khí động, kiểm chứng V1–V7 (Supplementary).
3. Controller — MOBADC, dự đoán tải, chọn τ, IM-est, dự đoán gió.
4. Analysis — T-stab.
5. Simulation setup — gió thật, tập dữ liệu, giao thức (đăng ký trước, confirm), thống kê.
6. Results — E1–E5 đo trên P2; quỹ đạo/dây/khối lượng/hover; bản đồ dư địa gió; IM-est + held-out;
   đối thủ; Monte Carlo; ngưỡng lắc lớn.
7. Discussion & Limitations — mục 2.8, i0780 (rối cao gần biên), X-esoatt (nếu còn), chỉ mô phỏng; preview ≈ dự
   đoán khi quỹ đạo lập trước (mục 1.6); PI-MoE với bước nhảy một mẫu trong chuỗi gió (P-QA §35-36);
   **giới hạn bộ điều khiển:** `wind_real_t150_i0251` phân kỳ ở cả 4 cột (L0 L2 L3 V) khi m_p = 0.25 (B1, REGISTER_P2
   §41.4) - ghi là giới hạn, không chẩn đoán (quyết định của user 2026-09-29); F3 của dạng N6 hiện tại (§41, §42).
   **DEVIATION cảm biến gió** (REGISTER_P2 §43): gió đo trên P2 không có nhiễu (σ = 0) ở mọi đêm, khác đặc tả 0.1 m/s;
   khai báo trong Methods + Giới hạn, kèm độ nhạy σ = 0.1 (§43.3); CONFIRM2 dùng σ = 0.
   **Rời rạc (P2_SPEC_AUDIT L3):** DO/ESO vị trí tích phân liên tục trên γ, ν giữ mẫu 125 Hz; chỉ lệnh lực ở 125 Hz
   (Methods + Giới hạn). **Gia tốc kế giản lược (L4):** gia tốc hệ quán tính + nhiễu, không lực riêng hệ thân, không
   rò trọng lực do sai góc - có lợi cho INDI (độ nhạy bias không chạy, phạm vi chốt §50.0).
   **Danh sách đầy đủ, câu cho bài:** `docs/LIMITATIONS_METHODS.md`; sửa đổi sau dữ liệu: `docs/DEVIATIONS.md`.
8. Conclusion.

---

## 9. Tài liệu tham khảo (kiểm lại toàn bộ trước khi nộp)
- [✓] K. Guo, J. Jia, X. Yu, L. Guo, L. Xie, "Multiple observers based anti-disturbance control for a quadrotor UAV against
  payload and wind disturbances," *Control Engineering Practice*, 102, 104560, 2020.
- [✓] L. Guo, W.-H. Chen, "Disturbance attenuation and rejection for systems with nonlinearity via DOBC approach,"
  *Int. J. Robust Nonlinear Control*, 15(3), 109–125, 2005.
- [✓] K. Sreenath, T. Lee, V. Kumar, "Geometric control and differential flatness of a quadrotor UAV with a cable-suspended
  load," *IEEE CDC*, pp. 2269–2274, 2013, doi:10.1109/CDC.2013.6760219.
- [✓] K. Sreenath, N. Michael, V. Kumar, "Trajectory generation and control of a quadrotor with a cable-suspended load —
  a differentially-flat hybrid system," *IEEE ICRA*, pp. 4888–4895, 2013.
- [✓] P. Kotaru, G. Wu, K. Sreenath, "Dynamics and control of a quadrotor with a payload suspended through an elastic cable,"
  *ACC*, pp. 3906–3913, 2017.
- [✓] F. A. Goodarzi, D. Lee, T. Lee, "Geometric stabilization of a quadrotor UAV with a payload connected by flexible cable,"
  *ACC*, 2014 (trang: nguồn ghi 4923–4930 hoặc 4925–4930 — kiểm lại).
- [✓] T. Lee, "Geometric control of quadrotor UAVs transporting a cable-suspended rigid body," *IEEE TCST*, 26(1), 255–264, 2018.
- [✓] T. Lee, M. Leok, N. H. McClamroch, "Geometric tracking control of a quadrotor UAV on SE(3)," *IEEE CDC*, pp. 5420–5425, 2010.
- [✓] K. Klausen, T. Fossen, T. Johansen, "Nonlinear control with swing damping of a multirotor UAV with suspended load,"
  *J. Intell. Robot. Syst.*, 88, 379–394, 2017.
- [✓] M. Guerrero et al., "Swing-attenuation for a quadrotor transporting a cable suspended payload," *ISA Trans.*, 68, 433–449, 2017.
- [✓] E. Sariyildiz, R. Oboe, K. Ohnishi, "Disturbance observer-based robust control and its applications: 35th anniversary
  overview," *IEEE TIE*, 67(3), 2042–2053, 2020.
- [✓] R. Marino, P. Tomei, "A globally convergent estimator for n-frequencies," *IEEE TAC*, 47(5), 857–863, 2002.
- [?] I. Palunko, R. Fierro, P. Cruz, "Trajectory generation for swing-free maneuvers of a quadrotor with suspended payload:
  A dynamic programming approach," *IEEE ICRA*, 2012.
- [?] L. Hsu, R. Ortega, G. Damm, "A globally convergent frequency estimator," *IEEE TAC*, 1999.
- [?] P. Regalia, adaptive notch filter (IEEE Trans. Signal Process., 1991).
- [?] M. Bodson, S. Douglas, "Adaptive algorithms for the rejection of sinusoidal disturbances with unknown frequency,"
  *Automatica*, 1997.
- [?] E. Smeur, Q. Chu, G. de Croon, "Adaptive incremental nonlinear dynamic inversion for attitude control of micro air
  vehicles," *J. Guid. Control Dyn.*, 2016.
- [?] E. Tal, S. Karaman, "Accurate tracking of aggressive quadrotor trajectories using incremental nonlinear dynamic
  inversion and differential flatness," *IEEE TCST*, 2021.
- [?] J. Baumgarte, "Stabilization of constraints and integrals of motion in dynamical systems," *Comput. Methods Appl.
  Mech. Eng.*, 1972.
- [?] J. D. Anderson, *Fundamentals of Aerodynamics*; S. F. Hoerner, *Fluid-Dynamic Drag*.
- [?] MIL-F-8785C / MIL-HDBK-1797 (Dryden, von Kármán).
- [?] L. Ljung, *System Identification: Theory for the User*.
- [?] Quanser, "Drone Parametrization" v0.4 (QDrone): khối lượng, quán tính, kích thước khung, lực đẩy tối đa (tài liệu hãng).
- [?] Bosch Sensortec, BMI160 datasheet: mật độ nhiễu gia tốc 180 µg/√Hz, offset ±40 mg, gyro 0.007–0.008 °/s/√Hz, ODR.
- [?] OptiTrack (NaturalPoint), Flex 13 specifications: 120 Hz, trễ 8.3 ms, độ chính xác ±0.2 mm.
- [?] Anemoment / LI-COR, TriSonica Mini datasheet: 20 Hz, độ chính xác tốc độ gió.
- [?] arXiv 2605.05483 — hằng số thời gian motor ~17 ms (quadrotor 3-inch). Tên bài, tác giả: điền khi kiểm.
- [?] J. Eschmann, D. Albani, G. Loianno, arXiv 2404.07837 — hằng số thời gian motor Crazyflie ~72 ms.
- [?] B. Efron, R. Tibshirani, *An Introduction to the Bootstrap*.

Quy tắc: không trích dẫn gì chưa đọc bản gốc hoặc chưa kiểm metadata. Mọi [?] phải thành [✓] trước khi nộp.

---

## 10. VIỆC LÀM NGAY (Claude Code) — theo quyết định 2026-09-25

1. [x] Tag `v1-final` tại `d3a7633` — trên remote (user push; tag object `fac19dba…`).
2. [x] Đồng bộ MASTER_PLAN, KE_HOACH_THUC_HIEN, brief, TEST_PLAN sang P2 và mã mới.
3. [x] `docs/REGISTER_P2.md` §0 (viết; chờ APPROVED trước GĐ3): D2–D4, CỔNG G, định nghĩa oracle, danh sách nhóm điều kiện.
4. [~] `docs/devlog/PLANT_P2_SPEC.md` bản cuối (6 quyết định 2026-09-25 đã áp dụng) → user APPROVED (GĐ1). **Chưa sửa model.**
