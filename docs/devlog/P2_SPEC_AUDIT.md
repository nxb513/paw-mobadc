# P2_SPEC_AUDIT — đặc tả P2 so với code đang chạy (đọc code, không mô phỏng)

**Việc:** đối chiếu mọi dòng `PLANT_P2_SPEC.md` §1 (thành phần) và §2 (tham số, cảm biến, tần số, trễ, bão hoà) cùng điều
kiện đầu và trim (REGISTER_P2 §8, GD2B_DESIGN §3) với giá trị hoặc khối **thật sự chạy** trên P2 (`file:dòng`).
**Ngày:** 2026-09-29. Làm trước khi thiết kế (iii), theo yêu cầu của user. **Người đọc:** Claude.

**Nhãn:** KHỚP · LỆCH (đặc tả và code khác nhau) · KHÔNG CÀI ĐẶT (có trong đặc tả, chưa có trong code).

---

## A. Thành phần (§1)

| # | đặc tả | code chạy trên P2 | nhãn |
|---|---|---|---|
| P1 | con lắc cầu 3D, dây cứng, tải chất điểm, có thành phần thẳng đứng | `core/plant_p2_free.m:17-19`: (2.3), (2.4), (2.6) đầy đủ 3D; `d_mf = T q − F_d` (`:22`) gồm cả thành phần thẳng đứng | KHỚP |
| P2 | F_d là nội lực, c = 2ζ_s ω_n m_L | `core/p2_cable_aero.m:21-23`; F_d vào (2.1) với dấu − và vào (2.6) cho tải với dấu + | KHỚP |
| P3 | lực cản bậc hai, vận tốc tương đối, lên tải và thân | `core/p2_cable_aero.m:15-20` (½ρC_DA = K_w/U_ref; tải: K·); v_L = v_Q + L q̇ | KHỚP |
| P4 | mô hình lực gió của bộ điều khiển: bậc hai, tham số danh định, w − v_Q | `simulink_blocks/p2_wind_force_hat.m:13-14` (dùng v_Q **đo** `nu_c`, bỏ w_z); `core/p2_setup.m` `p2_prm_w = [K_w; U_ref]` | KHỚP |
| P5 | động cơ bậc nhất từng motor, τ_m | `build/build_p2_plant.m:453-456` (Saturation → (u − f)/τ_m → Integrator), rồi Γ_mix | KHỚP |
| P6 | bão hoà: plant 0 ≤ f_i ≤ 7.67 N; F_TOT_MAX = 0.9 × 30.67; nghiêng 30°; F_z ≥ 0.5 N | `build_p2_plant.m:453` `M_sat` [0, `f_max`]; `core/p2_setup.m` `f_max` = 30.67/4, `F_TOT_MAX` = 0.9·30.67; `thrust_attitude_ref.m:12, 16, 24` | KHỚP |
| P7 | cảm biến gió gắn máy: 20 Hz, nhiễu trắng, trễ | 20 Hz: chuỗi file giữ mẫu (`WM_From` Interpolate off). Trễ 50 ms: `run_p2_gd6.m:94` và `run_p2_gd7.m:222` (`SensorDelayMs`) → `core/delay_wind_meas.m`. **Nhiễu: không có** | **LỆCH** (L1) |
| P8 | IMU: gia tốc + gyro, nhiễu trắng (+ bias gia tốc khi chạy độ nhạy) | `build_p2_plant.m:511-521`: gia tốc = **a_Q hệ quán tính** + nhiễu + bias; gyro = ω thân + nhiễu | **LỆCH** (L4) |
| P9 | mocap: lấy mẫu, trễ, nhiễu; vận tốc = sai phân vị trí | `build_p2_plant.m:497-509`: ZOH 8 ms → Delay 1 mẫu → + nhiễu; vận tốc = (γ_k − γ_{k−1})/T_s | KHỚP |
| P10 | điều khiển rời rạc: vòng vị trí theo mocap, vòng tư thế 1 kHz, ZOH | lệnh lực: ZOH 8 ms (`build_p2_plant.m:525`); tư thế: ZOH 1 ms (`:524, 526, 527`). **Bộ quan sát vị trí DO/ESO tích phân liên tục (bước 1 ms)** trên đầu vào đã giữ | **LỆCH** (L3) |
| P11 | gió vào mô hình: NREL M5 20 Hz, **ZOH** lên lưới 1 kHz, cùng w cho thân và tải | `build_p2_plant.m:448` dùng lại `Disturbances/WS_From`: Interpolate để mặc định = **tuyến tính** (`core/wind_sim_load.m:222`: "the PLANT wind series … LINEAR interpolation"); cùng w cho thân và tải (`p2_trans.m:34`); bỏ w_z | **LỆCH** (L2) |

## B. Tham số (§2.1–§2.6)

| mục | đặc tả | code (giá trị chạy) | nhãn |
|---|---|---|---|
| 2.1 m_Q | 1.121 kg | `core/p2_params.m:13`; bộ điều khiển `m` = 1.121 (`init_MOBADC_params.m:32`) | KHỚP |
| 2.1 I | 0.01, 0.0082, 0.0148 | `init_MOBADC_params.m:34` (khối quay v1 `Rot_5` chạy cả trên P2) | KHỚP |
| 2.1 khung 0.363 × 0.403 × 0.139 | chỉ để kiểm hợp lý C_D | không dùng trong code (không cần) | KHÔNG CÀI ĐẶT (không có vai trò mô phỏng) |
| 2.1 d_θ, d_φ, c_uf, c_τf | Guo A.1 | `init_MOBADC_params.m:35-37` | KHỚP |
| 2.1 gain | Guo A.2 | `init_MOBADC_params.m:46-62` (xem `docs/MOBADC_FIDELITY.md` E16) | KHỚP |
| 2.1 lực đẩy plant | 30.67 N (7.67 N/motor) | `p2_params.m:22` 30.67/4 = 7.6675 | KHỚP |
| 2.1 độ nhạy lực đẩy | 20.44 N | `p2_setup` `ThrustMax` (đêm 14) | KHỚP |
| 2.1 F_TOT_MAX | 0.9 × plant max = 27.603 N | `p2_params.m:23` | KHỚP |
| 2.1 TILT_MAX | 30° | `thrust_attitude_ref.m:12` | KHỚP |
| 2.1 g | 9.81 | `p2_params.m:12`; `init_MOBADC_params.m:33` | KHỚP |
| 2.1 bộ giải | ode4, 1e-3 s | `core/pa_configs.m:745` (`'Solver','ode4','FixedStep',opt.Step`, mặc định '1e-3') | KHỚP |
| 2.2 m_L | 0.5 kg; quét {0.25, 0.5, 0.65} | `init_MOBADC_params.m:192` `m_p`; `p2_setup` `P.m_L = ev('m_p')`; `MP` (B1) | KHỚP |
| 2.2 L | 1.0 m; quét {0.5, 1.0, 1.5} | `init_MOBADC_params.m:193`; `p2_setup` `P.L = ev('L')`; `L` (B2) | KHỚP |
| 2.2 ζ_s | 0.05; {0.02, 0.05, 0.12} | `p2_params.m:16`; `ZetaS` (đêm 14 B3) | KHỚP |
| 2.2 ω_n | √(g/L) | `p2_cable_aero.m:21` | KHỚP |
| 2.3 K_w | 0.2 N/(m/s) | `p2_params.m:18`; `p2_setup` assert bằng `wind_to_force` | KHỚP |
| 2.3 U_ref | 5 m/s | `p2_params.m:19` | KHỚP |
| 2.3 (C_DA)_Q, (C_DA)_L | 2K_w/(ρU_ref); K·(…) | `p2_cable_aero.m:15-16` (½ρ(C_DA)_Q = K_w/U_ref; ρ triệt tiêu) | KHỚP |
| 2.3 K | 0.5 (bài chính) | `run_p2_gd6.m:94` `PayloadWind 0.5` → `payload_K_ratio` → `P.K` | KHỚP |
| 2.4 τ_m | 17 ms (amendment A1); độ nhạy {0, 25, 30} | `p2_params.m:21`; `TauM`, `MotorLag` | KHỚP |
| 2.5 gió: tần số | 20 Hz | file xuất ở 20 Hz, `WM_From` giữ mẫu | KHỚP |
| 2.5 gió: nhiễu σ | 0.1 m/s mỗi trục | **σ = 0** (file sạch; `pa_configs.m:397-404` không cho thêm) | **LỆCH** (L1) |
| 2.5 gió: trễ | 50 ms (1 mẫu) | `SensorDelayMs 50` → dịch 1 mẫu (`delay_wind_meas.m`); PI-MoE dịch theo (`PredDelay`, §13.2) | KHỚP |
| 2.5 gió: độ nhạy nhiễu {0, 0.3} | — | 0.1: §43.3 (đã đăng ký); 0.3: chưa | KHÔNG CÀI ĐẶT (độ nhạy chưa chạy) |
| 2.5 gió: độ nhạy trễ {0, 100, 200} | — | `SensorDelayMs` hỗ trợ; đã chạy 200 (N4b-P2-d200) | KHỚP (0 và 100 chưa chạy) |
| 2.5 IMU gia tốc | 180 µg/√Hz ⇒ σ 0.0395 m/s² @1 kHz | `p2_setup.m:90` σ = N√(f_s/2) = 0.03947 | KHỚP (giá trị); hệ toạ độ: L4 |
| 2.5 bias gia tốc | 0; độ nhạy ±0.392 | `p2_bias_acc` = 0 (`p2_params.m:32`); độ nhạy: có biến, chưa có tuỳ chọn chạy | KHỚP (danh định); độ nhạy KHÔNG CÀI ĐẶT |
| 2.5 gyro | 0.007 °/s/√Hz ⇒ 2.73e-3 rad/s | `p2_setup.m:89` | KHỚP |
| 2.5 IMU độ nhạy ×{0, 3} | — | `ImuScale` (đêm 14 E3) | KHỚP |
| 2.5 mocap: tần số / trễ / nhiễu | 125 Hz / 8 ms / 0.2 mm | `p2_params.m:26-28`; `p2_setup.m:88, 100` (nd = 1); `build_p2_plant.m:497-500` | KHỚP |
| 2.5 mocap: độ nhạy nhiễu {0, 1 mm} | — | chưa có tuỳ chọn (E4) | KHÔNG CÀI ĐẶT (độ nhạy) |
| 2.5 vận tốc | sai phân lùi; σ_v ≈ 0.035 m/s | `build_p2_plant.m:503-508` | KHỚP |
| 2.5 vận tốc: lọc bậc nhất (độ nhạy) | — | không có | KHÔNG CÀI ĐẶT (độ nhạy) |
| 2.5 quy ước nhiễu | σ = N√(f_s/2) | `p2_setup.m:89-90` | KHỚP |
| 2.6 vòng vị trí | 125 Hz (DO/ESO vị trí, lệnh lực) | lệnh lực 125 Hz; DO/ESO liên tục | **LỆCH** (L3) |
| 2.6 vòng tư thế | 1 kHz | ZOH 1 ms trên η, `fthr`, `tau_cmd`; ESO tư thế liên tục ở bước 1 ms | KHỚP (bước giải = 1 ms) |
| 2.6 gió vào bộ điều khiển | 20 Hz, ZOH | `WM_From`, `WP_From`, `WO_From` Interpolate off | KHỚP |

## C. Điều kiện đầu và trim (REGISTER_P2 §8; GD2B_DESIGN §3)

| mục | quy định | code | nhãn |
|---|---|---|---|
| vị trí, vận tốc đầu | trạng thái tham chiếu của chính quỹ đạo tại t = 0 | `p2_setup.m:69` (`trajectory_ref`), `V.p2_x0` (`:112`) | KHỚP |
| dây | q = −e3, ω = 0 | `p2_setup.m:112`; `build_p2_plant.m:207` | KHỚP |
| động cơ | (m_Q + m_L) g/4 mỗi motor | `p2_setup.m:71`; `build_p2_plant.m:208` (`(m + m_p)*g/4`) | KHỚP |
| trim DO/ESO | một trạng thái giữ −m_L g: mode DC trục z của DO, hoặc z_p3(3) của ESO nếu DO không có mode DC | `p2_setup.m:77-83` | KHỚP |
| mocap (khối trễ), vận tốc trước | IC = vị trí đầu; γ_prev = γ_0 − v_0 T_s | `build_p2_plant.m` `C.ic_pos_p2`, `C.ic_prev_p2`; `p2_setup` `p2_gamma_prev0` | KHỚP |
| tư thế | η = 0 (hover trim) | khối quay v1 (IC 0) | KHỚP |
| seed nhiễu | theo đoạn | `p2_setup.m` `s0 = 7000000 + 100·seg` | KHỚP |

---

## D. Các lệch (báo user trước khi làm tiếp)

| # | lệch | đặc tả | code | đã có quyết định? | ảnh hưởng |
|---|---|---|---|---|---|
| **L1** | nhiễu cảm biến gió | σ 0.1 m/s | σ = 0 | **CÓ**: REGISTER_P2 §43 (2026-09-29): giữ σ = 0, khai báo, độ nhạy 0.1 ở §43.3 | mọi cột đọc gió đo |
| **L2** | gió vào plant: nội suy | "ZOH lên lưới 1 kHz" (P11, kèm "giữ như v1") | **tuyến tính** giữa các mẫu 20 Hz, như v1 (MANUSCRIPT §3.9 cũng ghi tuyến tính) | **KHÔNG** — hai ý trong cùng dòng P11 mâu thuẫn ("ZOH" và "giữ như v1"); code theo "giữ như v1" | không có với tính nhất quán (mọi đêm như nhau). Chỉ cần sửa câu trong đặc tả |
| **L3** | vòng vị trí rời rạc | DO/ESO vị trí + lệnh lực ở 125 Hz (P10, §2.6) | chỉ **lệnh lực** ở 125 Hz; DO/ESO tích phân liên tục (bước 1 ms) trên γ, ν đã giữ ở 125 Hz | **CÓ, nhưng ngoài đặc tả**: GD2B_DESIGN §6 (A) ghi là giới hạn ("băng thông quan sát ≪ 785 rad/s"); `PLANT_P2_SPEC` chưa sửa | nhỏ (cực nhanh nhất của ESO vị trí ≈ 29 rad/s); cần câu trong Methods |
| **L4** | gia tốc kế | "IMU (BMI160): gia tốc" (P8), không nói hệ toạ độ | gia tốc **hệ quán tính** a_Q + nhiễu; không phải lực riêng trong hệ thân (không có −g, không quay) | **CÓ, ngoài đặc tả**: GD2B_DESIGN §6 ("IMU giản lược"); COMPETITORS_DESIGN ghi giới hạn này cho H3 | hiện **chưa cột kết quả nào đọc** (IM-est chưa nối vào P2; H3 chưa chạy). Sẽ vào H3 và (iii) nếu (iii) dùng gia tốc đo |

**Không cài đặt (chỉ các mức độ nhạy chưa chạy, không phải danh định):** nhiễu gió 0.3; nhiễu mocap {0, 1 mm} (E4); lọc
vận tốc bậc nhất; bias gia tốc ±0.392; trễ gió {0, 100}.

**Không thấy lệch nào khác** ở các tham số, tần số, trễ, bão hoà, IC và trim.

## E. Quyết định của user (2026-09-29)
- **L2:** P11 sửa thành "gió vào plant nội suy tuyến tính, như v1" (`PLANT_P2_SPEC.md`).
- **L3:** ghi vào đặc tả (P10, §2.6), Methods và Giới hạn: DO/ESO tích phân liên tục trên γ, ν giữ mẫu 125 Hz; lệnh lực ở 125 Hz.
- **L4:** danh định giữ gia tốc kế giản lược, khai báo ở Giới hạn (có lợi cho INDI/IM-est). **(iii) dùng GIA TỐC LỆNH.**
  Độ nhạy bias gia tốc {0, 0.086, 0.17, 0.39} m/s² (tuỳ chọn `p2_setup ... 'AccBias'` / `pa_configs ... 'P2AccBias'`)
  áp cho INDI (H3), IM-est và biến thể (iii-m) - chạy cùng các khối đó, không chạy riêng.
