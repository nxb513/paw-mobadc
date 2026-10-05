# PLANT_P2_SPEC — đặc tả plant P2 (BẢN CUỐI, chờ duyệt ở GĐ1)

> Đi cùng `MASTER_PLAN.md` §2 (phương trình lõi, quyết định đã chốt) và `docs/REGISTER_P2.md` §0 (cổng, oracle,
> nhóm điều kiện). File này thêm: **mọi thành phần, mọi tham số kèm nguồn hoặc "giả định + dải độ nhạy"**, ảnh hưởng
> tới kết luận, và mức cần thiết. **Chưa sửa model, chưa viết code P2** — code bắt đầu ở GĐ2a sau khi có APPROVED.
>
> Mức: **[B]** bắt buộc · **[IM]** cần nếu IM-est là đóng góp chính · **[N]** nên có (độ nhạy).
> Nguồn: **[PAPER]** Guo et al. 2020 Appendix A · **[REPO]** đã có trong repo (file:dòng) · **[ĐO]** đo trong dự án ·
> **[DS]** datasheet / tài liệu hãng · **[LIT]** bài báo · **[GĐ]** giả định (ghi rõ), có dải độ nhạy.
> Tác giả duy nhất, không có thầy/lab (`ADVISOR_NOTES.md`) ⇒ mọi số lấy từ tài liệu công bố. Tài liệu mới thêm vào
> `MASTER_PLAN.md` §9 với dấu [?] cho tới khi metadata được kiểm lại trước khi nộp.
> Các quyết định của bạn (2026-09-25) đã áp dụng; ghi lại ở §4.

---

## 1. Thành phần và mức

| # | thành phần | mức | ảnh hưởng tới kết luận dự đoán |
|---|---|---|---|
| P1 | Con lắc cầu 3D, dây cứng, tải chất điểm (MASTER_PLAN 2.1–2.6), gồm thành phần **thẳng đứng** (`payload_z_on = 1`) | [B] | Nguồn của d_mf mà DO ước lượng và dự đoán; E1–E4 đo lại trên nó. Thành phần thẳng đứng là chỗ v1 phân kỳ (`X-esoatt`) → D1 |
| P2 | Damping dây F_d là **nội lực**, c = 2 ζ_s ω_n m_L | [B] | Biên độ lắc và độ sắc cộng hưởng (N1c); bảo toàn động lượng (V6) |
| P3 | Lực cản **bậc hai**, vận tốc tương đối, lên tải và thân (2.8, 2.8b) | [B] | Toàn bộ bản đồ gió (CỔNG G); tạo damping khí động cho tải khi K > 0; làm lực gió phụ thuộc trạng thái |
| P4 | Mô hình lực gió của **bộ điều khiển**: bậc hai, tham số danh định, w − v_Q | [B] | Định nghĩa O (REGISTER_P2 §0.3); thay `K_w·w` tuyến tính ở `WM_Kw` |
| P5 | Động cơ bậc nhất (lực đẩy từng motor trễ τ_m), danh định có nguồn dải | [B] | Cộng thêm trễ vào vòng tư thế → dời τ\* (E4) và độ lớn lợi ích dự đoán (D2) |
| P6 | Bão hoà: plant 0 ≤ f_i ≤ 7.67 N (tổng 30.67 N); bộ điều khiển F_TOT_MAX = 0.9 × plant max = 27.6 N, nghiêng 30°, Fz ≥ 0.5 N | [B] | Quyết định m_p tối đa, ngưỡng lắc lớn và envelope P2 (REGISTER_P2 §0.10) |
| P7 | Cảm biến gió gắn máy (TriSonica Mini): 20 Hz, nhiễu trắng, trễ | [B], **danh định có nguồn** | Ô duy nhất có dư địa gió phân giải được ở v1 là ô trễ cảm biến (N4b d200) → phải có |
| P8 | IMU (BMI160): gia tốc + gyro, nhiễu trắng (+ bias gia tốc ở độ nhạy). **Gia tốc kế GIẢN LƯỢC: gia tốc hệ quán tính a_Q + nhiễu (+ bias), không phải lực riêng trong hệ thân** (sửa 2026-09-29, P2_SPEC_AUDIT L4; GD2B_DESIGN §6; vào Giới hạn - có lợi cho INDI/IM-est, không có rò trọng lực do sai góc). **Độ nhạy bias gia tốc {0, 0.086, 0.17, 0.39} m/s²** = g·sin 0.5°, g·sin 1°, bias BMI160 ±40 mg; cho INDI (H3), IM-est và biến thể (iii-m) | [B] danh định; [IM] cho bias | IM-est dùng gia tốc UAV (`nu_dot`); nhiễu/bias quyết định hội tụ tần số (A-CP2…A-CP4) |
| P9 | Vị trí từ mocap (OptiTrack Flex 13): lấy mẫu, trễ, nhiễu; vận tốc = sai phân vị trí mẫu | [B], danh định có nguồn | Nâng sàn sai số bám; v1 hồi tiếp trạng thái sạch |
| P10 | Điều khiển rời rạc: **lệnh lực** vòng vị trí 125 Hz (ZOH 8 ms), vòng tư thế 1 kHz, ZOH; **bộ quan sát DO/ESO vị trí tích phân liên tục (bước 1 ms) trên γ, ν đã giữ mẫu 125 Hz** (sửa 2026-09-29, P2_SPEC_AUDIT L3; quyết định GD2B_DESIGN §6 (A); vào Methods + Giới hạn) | [B], danh định (giả định có căn cứ) | Thêm trễ nửa chu kỳ → dời τ\*; v1 liên tục ở bước 1 ms |
| P11 | Gió vào mô hình: chuỗi NREL M5 20 Hz, **nội suy tuyến tính lên lưới 1 kHz, như v1** (sửa 2026-09-29, P2_SPEC_AUDIT L2: bản trước ghi "ZOH", code luôn nội suy tuyến tính), **cùng w cho thân và tải** | [B] (giữ như v1) | Không đổi so với v1 |

---

## 2. Tham số (mọi số có nguồn công bố hoặc ghi rõ là giả định)

### 2.1 UAV và bộ điều khiển
| tham số | giá trị | nguồn |
|---|---|---|
| m_Q | 1.121 kg | [PAPER] A.1; khớp Quanser QDrone [DS] (Quanser, *Drone Parametrization* v0.4) |
| I_xx, I_yy, I_zz | 0.01, 0.0082, 0.0148 kg m² | [PAPER] A.1; khớp Quanser v0.4 [DS] |
| khung (dài × rộng × cao) | 0.363 × 0.403 × 0.139 m | [DS] Quanser v0.4 |
| d_θ, d_φ, c_uf, c_τf | 0.0879 m, 0.1068 m, 6.12e-5, 0.00963 | [PAPER] A.1 |
| K_γ, K_ν, K_η, K_ω, Kp, l_axis | như `init_MOBADC_params.m:46–55` | [PAPER] A.2 |
| lực đẩy tối đa plant (**danh định**) | **30.67 N** tổng = 7.67 N/motor (mô hình lực đẩy phi tuyến) | [DS] Quanser v0.4 |
| lực đẩy tối đa plant (**độ nhạy**) | 20.44 N tổng = 5.11 N/motor (mô hình lực đẩy tuyến tính) | [DS] Quanser v0.4 |
| hover (QDrone, không tải) | 11.0 N ≈ 53.8% của 20.44 N (≈ 35.9% của 30.67 N) | [DS] Quanser v0.4 |
| F_TOT_MAX bộ điều khiển | **0.9 × plant max** = 27.60 N (danh định) / 18.40 N (độ nhạy) | quy tắc giữ từ v1 (0.9·4·f_max); `f_max = 6 N` của v1 **bỏ** (không có nguồn) |
| TILT_MAX | 30° | [REPO] `thrust_attitude_ref.m:12`, giữ từ v1 **[GĐ]** |
| g | 9.81 m/s² | [REPO] |
| bộ giải | ode4, bước 1e-3 s | [REPO]; giữ để v1 bit-exact; mọi chu kỳ lấy mẫu là bội nguyên của 1 ms (§4.7) |

### 2.2 Tải và dây
| tham số | giá trị | nguồn / dải |
|---|---|---|
| m_L = m_p | **0.5 kg** danh định; quét {0.25, 0.5, 0.65} | [PAPER] Guo 2020 Fig. 1 (tải 0.5 kg) |
| L | 1.0 m danh định; quét {0.5, 1.0, 1.5} | **[GĐ]** (Guo không cho chiều dài dây); ω_n = 4.43 / 3.13 / 2.56 rad/s |
| ζ_s | **0.05** danh định; độ nhạy {0.02, 0.05, 0.12} | **[GĐ]** — quyết định §4.1 |
| ω_n | √(g/L) | công thức |

**Kiểm lực đẩy theo m_p** (circle Test 4: R = 0.8 m, ω = 1.575 rad/s ⇒ a_c = R ω² = 1.98 m/s², nghiêng tĩnh
11.4° < 30°; lực đẩy dừng ≈ (m_Q + m_p)·√(g² + a_c²), chưa tính lắc và gió):

| m_p [kg] | hover [N] | circle dừng [N] | / F_TOT_MAX 27.60 (danh định) | / F_TOT_MAX 18.40 (độ nhạy) |
|---|---|---|---|---|
| 0.25 | 13.45 | 13.72 | 50% | 75% |
| 0.50 | 15.90 | 16.22 | 59% | 88% |
| 0.65 | 17.37 | 17.73 | 64% | **96%** |

Ở danh định mọi m_p còn dư ≥ 36%. Ở độ nhạy lực đẩy tuyến tính, m_p = 0.65 gần bão hoà ngay khi bay tròn không gió
→ độ nhạy này báo kèm `sat_frac`; envelope luôn tính theo lực đẩy danh định (ở 20.44 N envelope rỗng với m_p ≥ 0.5,
REGISTER_P2 §0.10).

### 2.3 Khí động
| tham số | giá trị | nguồn |
|---|---|---|
| K_w | 0.2 N/(m/s) | [REPO] khoá, `core/wind_to_force.m` (wind_amp 1.0 N / V_ref 5 m/s) |
| U_ref | **5 m/s** = V_ref (mốc khoá của K_w); hồ sơ: trung vị T.U của 25 đoạn T.stable = 5.089828 m/s (lệch 1.8%) | quyết định §4.3 · REGISTER_P2 §0.10 |
| (C_D A)_Q | 2 K_w/(ρ U_ref) = **0.0653 m²** | (2.8b) |
| (C_D A)_L | K·(C_D A)_Q — K = 0.5 ⇒ **0.0327 m²**; K = 0 ⇒ 0 | (2.8) |
| ρ | 1.225 kg/m³ (ISA mực nước biển) | **triệt tiêu trong lực**: F = K_w\|v\|v/U_ref; ρ chỉ dùng để diễn giải C_D·A |

Kiểm hợp lý vật lý theo kích thước khung Quanser: diện tích mặt trước (hộp bao, gió ngang) 0.403 × 0.139 =
0.056 m² hoặc 0.363 × 0.139 = 0.050 m² ⇒ **C_D ≈ 1.17–1.29**, nằm trong dải vật cản thô (Hoerner [?]). Hộp bao
lớn hơn diện tích đặc của khung hở nên C_D thật trên diện tích đặc sẽ cao hơn — ghi là giới hạn của phép kiểm.
(C_D A)_L = 0.0327 m² ứng với hộp cạnh ~18 cm (C_D ≈ 1.05) hoặc cầu đường kính ~30 cm (C_D ≈ 0.47).
Lực tại 5 m/s: thân 1.0 N (đúng mốc khoá), tải 0.5 N (K = 0.5).

### 2.4 Động cơ
| tham số | danh định | độ nhạy | nguồn |
|---|---|---|---|
| τ_m (bậc nhất, từng motor) | ~~30 ms~~ → **17 ms** (amendment A1, REGISTER_P2 §3) | ~~{17, 50, 72}~~ → **{0, 25, 30} ms**; 30 ms = stress, gain Guo thất bại | [LIT] ~17 ms cho quadrotor 3-inch (arXiv 2605.05483 [?]); 72 ms cho Crazyflie (Eschmann, Albani, Loianno, arXiv 2404.07837 [?]) |

### 2.5 Cảm biến
| cảm biến | tham số | danh định | độ nhạy | nguồn |
|---|---|---|---|---|
| gió (TriSonica Mini) | tần số | 20 Hz (khớp chuỗi NREL M5 20 Hz) | — | [DS] |
| | nhiễu σ | **0.1 m/s** mỗi trục — ⚠ **CÀI ĐẶT: σ = 0** (DEVIATION, REGISTER_P2 §43.1; độ nhạy 0.1 ở §43.3) | {0, 0.3} m/s | [DS] |
| | trễ | **50 ms** (1 mẫu) | {0, 100, 200} ms | [DS] 20 Hz ⇒ 1 mẫu; **[GĐ]** trễ đúng 1 mẫu |
| | nhiễu luồng khí cánh quạt | **không mô hình hoá** (Giới hạn) | — | — |
| IMU gia tốc (BMI160) | mật độ nhiễu | 180 µg/√Hz ⇒ σ = 0.0395 m/s² tại 1 kHz | ×{0, 3} | [DS] Bosch BMI160 |
| | bias | **0** (đã hiệu chuẩn) | ±40 mg = ±0.392 m/s² mỗi trục (offset điển hình) | [DS] |
| IMU gyro (BMI160) | mật độ nhiễu | 0.007 °/s/√Hz ⇒ σ = 0.157 °/s = 2.73e-3 rad/s tại 1 kHz (0.008 ⇒ 0.179 °/s) | ×{0, 3} | [DS] |
| vị trí (OptiTrack Flex 13) | tần số | **125 Hz (8 ms)** — xấp xỉ 120 Hz của datasheet, lệch 4% (§4.7) | — | [DS] OptiTrack |
| | trễ | **8 ms** — xấp xỉ 8.3 ms của datasheet (§4.7) | — | [DS] |
| | nhiễu σ | **0.2 mm** mỗi trục (từ độ chính xác ±0.2 mm) | {0, 1 mm} | [DS]; **[GĐ]** coi ±0.2 mm là σ |
| vận tốc | cách lấy | sai phân lùi của vị trí mẫu ⇒ σ_v ≈ √2·σ_p/T_s ≈ 0.035 m/s | lọc bậc nhất (độ nhạy) | **[GĐ]** (mocap chỉ cho vị trí) |

Quy ước nhiễu rời rạc: nhiễu trắng mật độ N lấy mẫu ở f_s ⇒ σ = N·√(f_s/2) (băng Nyquist). Ghi cùng số trong bài.

### 2.6 Rời rạc
| vòng | tần số | nguồn |
|---|---|---|
| vị trí (lệnh lực; DO/ESO vị trí tích phân liên tục trên đầu vào giữ 125 Hz - xem P10) | theo mocap: **125 Hz (8 ms)** (§4.7) | **[GĐ]** căn theo OptiTrack Flex 13 [DS] |
| tư thế (ESO tư thế, mô-men) | **1 kHz** | **[GĐ]** căn theo BMI160 ODR tới 1.6 kHz (gia tốc) / 6.4 kHz (gyro) [DS] |
| gió vào bộ điều khiển | 20 Hz, ZOH | TriSonica [DS] |

Mọi tham số cảm biến / rời rạc / động cơ trên là **danh định có nguồn** (không còn "0 như v1"). Góc tư thế η lấy
sạch ở 1 kHz (bộ ước lượng tư thế trên máy không mô hình hoá — §5, §4.8).

---

## 3. Chế độ chạy và kiểm chứng (MASTER_PLAN §2.7)
- **Tự do** (vòng kín đầy đủ) và **áp chuyển động** (a_Q cho trước, dùng cho V2–V4).
- V1 treo tĩnh T = m_L g · V2 góc nhỏ khớp con lắc v1 (áp chuyển động) · V3 năng lượng bảo toàn (ζ_s = 0, không gió) ·
  V4 con lắc nón ω² = g/(L cos θ) · V5 ràng buộc |q| = 1, ω·q = 0 trôi < 1e-6 · V6 động lượng tổng bảo toàn
  (ζ_s = 0 **và** ζ_s > 0, không gió, không lực đẩy ngoài) · V7 lực cản tại U_ref bằng K K_w U_ref và K_w U_ref.
- Unit test: động cơ (đáp ứng bước, hằng số thời gian), cảm biến (σ theo quy ước §2.5, trễ đúng số mẫu, tần số
  lấy mẫu), rời rạc (ZOH, bội nguyên của bước 1 ms).
- Log mỗi run P2: T_min, cờ slack, max||q|−1|, max|ω·q|, θ_max, sat_frac.
- Tắt P2 (`PlantModel = 'planar_v1'`) ⇒ bit-exact v1 (`verify_repro` 32/32).

---

## 4. Quyết định đã áp dụng (của bạn, 2026-09-25)

| # | điểm | quyết định | hệ quả trong spec / đăng ký |
|---|---|---|---|
| 4.1 | ζ_s danh định | **0.05**, độ nhạy {0.02, 0.05, 0.12} | Ở K > 0 tải đã có damping khí động thật, nên không dùng lại 0.12 của v1 (tránh tính damping hai lần). Ở K = 0 (N5-A) damping duy nhất là ζ_s → báo độ nhạy ζ_s cho N5-A |
| 4.2 | τ_m | **30 ms, giả định trong dải tài liệu**, độ nhạy {17, 50, 72} ms (sửa 2026-09-25) | §2.4; khai báo là giả định trong bài |
| 4.2a | τ_m — **amendment A1** (2026-09-25) | **17 ms**, độ nhạy {0, 25, 30} ms | Viết **SAU** khi thấy D1 @17 ms (GĐ3), **TRƯỚC** mọi khối D2/CỔNG G. Lý do: Guo 2020 bay ổn định với gain gốc; gain gốc phân kỳ 10/10 @30 ms, ổn định 10/10 @17 ms (REGISTER_P2 §1.6, §2.7) ⇒ τ_m thật nằm trong vùng ổn định; 17 ms có nguồn trong vùng đó. **Điểm yếu khai báo:** không có số đo công bố cho động cơ 2206 / cánh 6045; dải tài liệu 17–94 ms. 30 ms báo như phát hiện (stress, gain gốc thất bại). Chi tiết REGISTER_P2 §3 |
| 4.3 | U_ref | **5 m/s = mốc khoá** | Giữ đúng 1.0 N tại 5 m/s; trung vị T.U = 5.089828 lệch 1.8% (hồ sơ, REGISTER_P2 §0.10) |
| 4.4 | envelope P2 **mới** (giữ vị trí trước lực gió tĩnh: nghiêng ≤ 0.8·30°, lực đẩy ≤ 0.8·F_TOT_MAX) + quy tắc đủ dữ liệu | thay 15° cho P2 (2026-09-25) | U_max = 10.86 m/s (K 0.5, m_p 0.5), 9.41 (K 1.0), 13.30 (K 0); bảng đủ ở REGISTER_P2 §0.10; nhóm < 15 đoạn hoặc < 6 ngày = "không đánh giá được" |
| 4.5 | O và O_F | O dùng v_Q(t); **O_F chỉ trong Monte Carlo GĐ9** | REGISTER_P2 §0.3; không có cột hai lượt |
| 4.6 | quy tắc CONFIRM2 | REGISTER_P2 §0.6.1: SE = jackknife bỏ-một-ngày paired trên 16 ngày | **D2:** Δ_conf ≤ −15% **và** Δ_conf + 1.65·SE < 0. **Nhóm CỔNG G:** h_conf ≥ 5% **và** h_conf − 1.65·SE > 0 **và** c_conf ≥ 0.3. Cùng τ_w\* của N0W. Tập thiếu dữ liệu = "không xác nhận được" |
| 4.7 | 120 Hz không khớp bước giải 1 ms (1/120 s = 8.333 ms không là bội nguyên của 1 ms) | **(a): mocap + vòng vị trí 125 Hz (8 ms), trễ 8 ms**; bước giải giữ 1 ms | §2.5, §2.6; ghi trong bài là **xấp xỉ** (lệch 4% so với 120 Hz / 8.3 ms của datasheet); v1 bit-exact và chi phí chạy không đổi |
| 4.8 | nguồn góc tư thế η | **η sạch ở 1 kHz**; nhiễu gyro BMI160 vào tốc độ góc ω | Bộ ước lượng tư thế trên máy không mô hình hoá → mục Giới hạn (§5) |
| 4.9 | thông số phần cứng | tài liệu công bố (Quanser v0.4, BMI160, OptiTrack Flex 13, TriSonica Mini, arXiv) | §2; `f_max = 6 N` bỏ; F_TOT_MAX = 0.9 × plant max |
| 4.10 | horizon oracle gió trên P2 | bước **N0W** trước mọi nhóm CỔNG G (REGISTER_P2 §0.3.1) | τ_w\* đo trên P2; O = O(τ_w\*) cho CỔNG G, O(150) báo kèm; P giữ 150 ms |

**Ghi chú (để diễn giải kết quả, không phải tham số mới):**

- **Lực đẩy danh định 30.67 N nhất quán với Guo 2020**, vốn đã bay thật QDrone mang tải 0.5 kg. Với mô hình tuyến
  tính 20.44 N, riêng hover có tải đã cần 15.90 N = **78%** max, không đủ dư để bay tròn trong gió như Guo đã làm
  (bay tròn dừng đã là 16.22 N ⇒ 88% F_TOT_MAX 18.40 N; §2.2). Vì vậy 20.44 N chỉ là độ nhạy bão hoà.
- **PI-MoE trên P2 nhận lịch sử gió đo trễ 50 ms và nhiễu σ 0.1 m/s**, khác dữ liệu sạch lúc huấn luyện. Tính từ
  mẫu cuối cùng nó thấy, horizon thực ≈ **200 ms** (150 + 50). Đây là điều kiện thật và được giữ; ghi lại để diễn
  giải c (REGISTER_P2 §0.3, §0.6).

---

## 5. KHÔNG mô hình hoá (vào mục Giới hạn của bài)
- Dây đàn hồi, dây chùng có va đập (Kotaru, Wu & Sreenath 2017 [✓]); T ≤ 0 chỉ gắn cờ, đoạn đó không dùng.
- Tải là vật rắn (Lee 2018 [✓]); điểm treo lệch trọng tâm UAV (dây tạo mô-men).
- Tương tác khí động cánh quạt–tải (downwash lên tải), hiệu ứng mặt đất.
- Gió thẳng đứng, mô-men gió lên thân, **khác biệt gió giữa vị trí UAV và vị trí tải** (cùng w cho cả hai; L ≤ 1.5 m).
- Rối sinh ra bởi chính UAV; biến thiên ρ theo độ cao (triệt tiêu trong lực, §2.3).
- Khối lượng dây; ma sát khớp treo ngoài F_d.
- Pin sụt áp, giới hạn tốc độ quay motor ngoài bão hoà lực đẩy; lượng tử hoá ESC.
- Nhiễu luồng khí cánh quạt lên cảm biến gió gắn máy (TriSonica đo gió tương đối trong luồng xoáy).
- Bộ ước lượng tư thế trên máy (η lấy sạch, §4.8); lọc chống răng cưa của IMU; bias gyro.
- Bay thật, SITL/HIL — chỉ mô phỏng Simulink (`ADVISOR_NOTES.md`).

---

## 6. Duyệt

```
APPROVED: Huyhoang   ngày: 2026-09-25
```
