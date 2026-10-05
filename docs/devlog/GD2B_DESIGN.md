# GĐ2b — THIẾT KẾ nối plant P2 vào Simulink (DUYỆT 2026-09-25, kèm bổ sung của user)

> Theo `PLANT_P2_SPEC.md` và `docs/REGISTER_P2.md` §0 (cả hai APPROVED 2026-09-25), hàm thuần GĐ2a (41/41 PASS).
> Build: `build/build_p2_plant.m` (idempotent, `Revert`, in fingerprint). Claude Code không chạy được MATLAB:
> user chạy build → kiểm B1–B7 (mục 5) → push `baseline1.slx` → báo hash.
> Cấu trúc model lấy từ XML của `baseline1.slx` hiện tại (đường dẫn khối, tag Goto/From, IC integrator).

---

## 1. Nguyên tắc giữ v1 bit-exact

- Biến `plant_model` (0 = v1, mặc định; 1 = P2), đặt bởi `core/reset_extensions.m` (mọi lần chạy về 0).
- **Toàn bộ khối tính của P2 nằm trong MỘT Variant Subsystem** `P2/P2_Core` (một lựa chọn, điều kiện
  `plant_model==1`, `AllowZeroVariantControls = on`, `VariantActivationTime = 'update diagram'`). Khi
  `plant_model = 0` không khối P2 nào được compile.
- Tín hiệu được chọn bằng **Variant Source** (`{'plant_model==0','plant_model==1'}`: cổng 1 = v1, cổng 2 = P2), đúng
  khuôn A-CP1 (REGISTER_C §4.50, 32/32 bit-exact).
- Thay đổi trên phần v1 chỉ gồm các thao tác **không đổi số** (bằng chứng: B1):
  - đổi tên tag của vài Goto/From (liệt kê ở mục 2) — Goto/From là khối ảo;
  - chèn Variant Source (ảo) trên các đường liệt kê ở mục 2;
  - `thrust_attitude_ref.m`: `F_TOT_MAX` thành đầu vào (tham số `F_TOT_MAX`, mặc định **21.6** trong
    `init_MOBADC_params`) — cùng số double với hằng cũ;
  - IC của `Int_z` (DO) và `Int_zp` (ESO) đổi từ biểu thức sang hàm `p2_ic_do(...)` / `p2_ic_eso(...)` tính
    **đúng biểu thức cũ** (cùng phép tính MATLAB) và chỉ cộng trim khi `plant_model = 1`.
- Đổi `.slx` ⇒ cập nhật MD5 trong `docs/SNAPSHOT.md` cùng lần build (WIRING.md: rebuild vì lý do thật).
- `f_max`: **đã xác nhận** trong XML — `Motor_Allocation/fmx` là Constant đọc biến workspace `f_max`.
  `p2_setup` gán `f_max = 30.67/4 = 7.6675 N` khi `plant_model = 1`; B5 in giá trị `f_max` thực dùng và build
  script assert `get_param(fmx,'Value') == 'f_max'`. Không có chặn 6 N ẩn.

---

## 2. Nối dây (P2 bật)

### 2.1 Tín hiệu vật lý (thật) — tag giữ tên cũ, nguồn chọn bằng Variant Source trong subsystem `P2`

| tag (người đọc) | v1: nguồn cũ (tag đổi tên) | P2: nguồn |
|---|---|---|
| `gamma` (Logging: sai số bám trên vị trí THẬT) | `UAV_Plant/G_gamma` → tag `gamma_v1` | x_Q của `P2_Trans` |
| `nu` | `UAV_Plant/G_nu` → `nu_v1` | v_Q |
| `nu_dot` (con lắc v1) | `UAV_Plant/PL_G_nu_dot` → `nu_dot_v1` | a_Q |
| `d_mf` (Logging, `Trans_4a` v1) | `Disturbances/G_d_mf` → `d_mf_v1` | T q − F_d |
| `d_lf` (Logging, `Trans_4a` v1) | `Disturbances/G_d_lf` → `d_lf_v1` | F_wQ |
| `tau_plant` (MỚI; `UAV_Plant/F_tau_act` đổi sang đọc tag này) | tag `tau_act` | τ sau trễ động cơ |

Động lực học tư thế (`Rot_5`, `Int_eta`, `Int_etadot`, `Body_Rates`) dùng chung cho v1 và P2 (giả thiết A3: dây
không tạo mô-men); ở P2 nó nhận mô-men **sau trễ** qua `tau_plant`.

### 2.2 Tín hiệu bộ điều khiển thấy (đo / rời rạc) — tag MỚI, các From của bộ điều khiển đổi sang đọc

| tag mới | From đổi tag | v1 (cổng 1) | P2 (cổng 2) |
|---|---|---|---|
| `gamma_c` | `Position_Observers/F_gamma`, `Translational_Control/F_gamma`, `F_gamma1` | `gamma` | mocap: ZOH 8 ms → trễ 1 mẫu (8 ms) → + nhiễu σ 0.2 mm |
| `nu_c` | `Position_Observers/F_nu`, `Translational_Control/F_nu`, `F_nu1` | `nu` | sai phân lùi của `gamma_c` ở 125 Hz |
| `nu_dot_c` | `Position_Observers/IM_Est_Online/IM_F_nu_dot` | `nu_dot` | ZOH 1 ms + nhiễu gia tốc σ 0.0395 m/s² (+ bias, danh định 0) |
| `omega_c` | `Rotational_Control/F_omega` | `omega` | ZOH 1 ms + nhiễu gyro σ 2.73e-3 rad/s |
| `eta_c` | `Attitude_Observer/F_eta`, `Attitude_Reference/F_eta`, `Rotational_Control/F_eta` | `eta` | ZOH 1 ms, sạch (quyết định 4.8) |
| `Fcmd_c` | `Attitude_Reference/F_Fcmd` | `Fcmd` | ZOH 8 ms (đầu ra vòng vị trí 125 Hz) |
| `fthr_c` | `Motor_Allocation/F_fthr` | `fthr` | ZOH 1 ms |
| `tau_cmd_c` | `Motor_Allocation/F_tau_cmd` | `tau_cmd` | ZOH 1 ms (đầu ra vòng tư thế 1 kHz) |

`Logging_Metrics/F_gamma`, `F_eta` **giữ** tag thật (`gamma`, `eta`): metric tính trên vị trí thật.

**Lực/mô-men mà bộ quan sát dùng:** tag `F_act` (`UAV_Plant/Force_4b`, từ lực đẩy **lệnh** đã chặn) và `tau_act`
(`Motor_Allocation`) giữ nguyên cho DO/ESO/ESO tư thế ở cả hai plant — bộ điều khiển thật biết lệnh của nó, không
biết trễ động cơ. Chỉ **plant** P2 dùng lực/mô-men sau trễ. (Hệ quả cho B6: "wrench tĩnh" là thông tin hợp lệ của
bộ điều khiển, không đầu độc được — mục 5.)

### 2.3 Khối trong `P2/P2_Core` (Variant Subsystem, chỉ compile khi `plant_model = 1`)
1. **Động cơ:** From `f_i` (lệnh đã chặn) → Saturation [0, `f_max`] → (u − f)/`p2_tau_m` → Integrator 4 trạng
   thái, IC `p2_f0 = (m_Q + m_L) g/4` → `Gamma_mix · f` → [f_act_p2; τ_p2].
2. **`P2_Trans`:** MATLAB Function `p2_trans(x, f_act, eta, w, prm)` = `force_from_attitude` + đúng
   `plant_p2_derivative` (free) của GĐ2a; Integrator 12 trạng thái, IC `p2_x0` (vị trí/vận tốc đầu của v1,
   q = −e3, ω = 0). Không vòng đại số, không Memory. η là η **thật** (`eta`).
3. **Gió thật:** From Workspace `wind_ts` (sao chép `Disturbances/WS_From`, cùng nội suy) → w_z = 0.
4. **Cảm biến / rời rạc:** như bảng 2.2; nhiễu bằng khối Random Number (Gaussian) với seed là biến workspace.
5. **Lực gió của bộ điều khiển:** From Workspace thô `wind_meas_ts`, `what_ts`, `w_oracle_ts` (sao chép
   `WM_From`/`WP_From`/`WO_From`, giữ `Interpolate`) → Multiport Switch (sao chép `WSEL`, điều khiển
   `wind_use_pred`) → w_z = 0 → `p2_wind_force_hat(w, nu_c, prm)` = (K_w/U_ref)|w − ν̃|(w − ν̃) → outport →
   tag `dlf_p2`. Trong `Position_Observers`: Variant Source chèn giữa `WSEL/1` và `WD_Switch/1` (cổng 1 = WSEL
   (K_w·w), cổng 2 = From `dlf_p2`). Cổng chọn thời điểm hợp lệ (`WD_gate`, ESO trước 30 s) giữ nguyên.
6. **Log** (To Workspace trong `P2_Core`): `p2_mon_log` = [T; slack; ||q|−1|; |ω·q|; θ] mỗi bước (1 kHz — để bắt
   cực trị đúng); `p2_f_log` (4 lực motor) và `p2_meas_log` ([gamma_c; omega_c; nu_dot_c], cho B3) phân rã
   `p2_log_dec` (mặc định 10 → 100 Hz); `p2_Fcmd_log` (Fcmd_c ở 125 Hz, cho B5).

### 2.4 Hook trong `pa_configs` (tuỳ chọn `'PlantModel'`, mặc định `'v1'` → không đổi gì)
`'PlantModel','p2'` gọi `core/p2_setup.m` **sau** khối DoHarm/DoWAxis (trước vòng các cột):
gán `plant_model = 1`, `f_max`, `F_TOT_MAX = 27.603`, `p2_prm`, `p2_tau_m`, `p2_x0`, `p2_f0`, σ, seed, trim; ghi tất
cả vào `M.cond.p2`. Sau mỗi cột: `p2_summary` (T_min, số lần slack, trôi cực đại, θ_max, thời điểm cờ đầu tiên,
sat_frac) → `R.(cfg).p2`, `M.(cfg).p2`. Tuỳ chọn `'OracleTauMs'` (mọi plant): `w_oracle_ts` = `p2_oracle_ts(wind_ts, τ)` — dịch chỉ số khi τ là bội
chu kỳ mẫu (chính xác), nội suy tuyến tính khi không (N0W). **Phân kỳ vật lý** (T ≤ 0) và **cờ số học** (trôi > 1e-6) theo
REGISTER_P2 §0.4 được gắn cờ riêng. `ImEstOnline` + P2 bị chặn bằng assert (thuộc GĐ8).

---

## 3. Điều kiện đầu — danh định = TRIM bay treo có tải (quyết định 4)
- Motor: `p2_f0 = (m_Q + m_L) g/4` mỗi motor.
- Ước lượng nhiễu DC dọc = **−m_L g**, đặt vào **MỘT** trạng thái; tổng ước lượng ban đầu = −m_L g e3, không bù đôi.
- **Chọn DO, mode DC trục z** (`Int_z`, chỉ số DC của trục z trong bố cục `do_w_axis`). Lý do:
  1. trọng lượng tải là **nhiễu tải** (d_mf = T q − F_d), đúng kênh DO được thiết kế để ước lượng;
  2. **ESO bị thay bởi mô hình gió** ở L2/L3/P/O sau t_valid = 30 s (`WD_Switch`, `WD_gate`): trim đặt ở `z_p3`
     sẽ **biến mất khỏi luật điều khiển tại t = 30 s** → bước 4.9 N; DO thì ở trong luật điều khiển suốt run ở mọi
     cột có mode DC;
  3. dự đoán tải (e^{Aτ}) giữ nguyên mode DC → trim không bị quay.
- **Ngoại lệ bắt buộc:** cột nào có DO **không** có mode DC trên trục z (L0 = Guo harm1) thì không có trạng thái
  DC trong DO → trim vào **ESO `z_p3(3)`** (ở L0 ESO nằm trong luật điều khiển suốt run vì `wind_pred_on = 0`).
  Quy tắc tự động trong `p2_setup` theo `do_w_axis{3}`; in ra cột nào dùng trạng thái nào. Tổng ban đầu vẫn là
  −m_L g e3 ở mọi cột. **Cần bạn xác nhận ngoại lệ L0.**
- **Khởi động lạnh** (DO/ESO = 0, motor như trên): tuỳ chọn `'P2Cold', true` — ca chẩn đoán GĐ3 (giả thuyết:
  cơ chế phân kỳ khi bật `payload_z_on` ở v1). Không phải danh định.
- Cùng điều kiện đầu cho mọi cột.

---

## 4. Nhiễu cảm biến: seed CHỈ theo đoạn
Seed = hàm của **chỉ số đoạn** (số `iNNNN` trong tên file) và loại cảm biến, không theo cột: mọi cột (L2/L3/P/O…)
của cùng đoạn thấy **cùng chuỗi nhiễu** (so sánh paired). Ghi `M.cond.p2.seeds`. Cột L0/L1 cũng dùng cùng seed.

---

## 5. Kiểm tra sau build

| # | kiểm | ngưỡng | công cụ |
|---|---|---|---|
| B1 | `plant_model = 0`: `verify_repro`, `check_results_numbers`, `check_all`, `extract_eml --check`; compile 0 → 1 → 0 trong build | 32/32 bit-exact, mọi mục PASS | build script + lệnh chuẩn |
| B2 | `p2_trans` trong Simulink vs `plant_p2_derivative` + RK4 MATLAB, cùng F(t), w(t) tuyến tính từng khúc, 20 s, model harness tạm (không lưu) | max\|Δx\| ≤ 1e-9 | `verification/check_p2_b2_b4.m` |
| B3 | động cơ (harness) vs `p2_motor_derivative`; cảm biến trong B5: trễ/lấy mẫu CHÍNH XÁC ở run tắt nhiễu, std nhiễu ở run bật nhiễu | ≤ 1e-12; bằng 0; lệch std ≤ 5% | `check_p2_b2_b4.m`, `check_p2_b5_b7.m` |
| B4 | `O(150)` (τ là bội chu kỳ mẫu → dịch chỉ số, chính xác) vs `w_oracle_ts` cũ; `O(0)` vs `wind_ts` | 0; 0 | `check_p2_b2_b4.m` |
| B5 | circle i0000, K 0.5, danh định, cột L2 + L3 | không lỗi; T_min > 0; trôi < 1e-6; số hợp lý | `check_p2_b5_b7.m` |
| B5+ | **RMS nhiễu lực lệnh vòng vị trí do nhiễu vận tốc đo**: RMS(Fcmd_có nhiễu − Fcmd_tắt nhiễu), t ≥ 140 s, cạnh ước lượng m·K_ν·σ_v ≈ 0.31 N | báo số (GĐ3 đánh giá) | `check_p2_b5_b7.m` |
| B6 | **đầu độc:** `plant_model = 1`, `p2_poison = 1` ép NaN tại mọi đầu ra plant v1 (Goto `gamma_v1`, `nu_v1`, `nu_dot_v1`, `d_mf_v1` — gồm con lắc + `PL_Mem_a` —, `d_lf_v1`, và đường `K_w` sau `WSEL`); chạy lại B5 | metric L2/L3 **trùng từng chữ số** B5 | `check_p2_b5_b7.m` |
| B7 | B5 ở bước 5e-4 vs 1e-3 | lệch pooled < 0.5% | `check_p2_b5_b7.m` |

**B3m kết quả (2026-09-25, đóng, user phương án 1):** FAIL 1.961e-12 N so với ngưỡng 1e-12, cả trước và sau hướng (b) (`p2_motor_derivative` nhân `1/tau_m` như Gain Simulink) - (b) không đổi kết quả. Sai lệch = 2.6e-13·f_max (4.9e-13 lực hover 3.976 N), mức làm tròn tích luỹ qua 2000 bước ode4; B2 (cùng đường ode4, 20 s) PASS 1.5e-11/1e-9. Ghi FAIL, ngưỡng không đổi, checkpoint đóng.

Về B6 và "wrench tĩnh": `f_act`/`tau_act` tĩnh là **lực lệnh** mà DO/ESO dùng hợp lệ (mục 2.2) nên không đầu độc;
đường của nó vào **plant** (Rot_5) đã được chuyển sang `tau_plant` — build script assert điều này, và
`Trans_4a` (plant v1, tiêu thụ `F_act`) chỉ ra `nu_dot_v1`/`gamma_v1`/`nu_v1`, đều bị đầu độc.
Các chỗ đầu độc là Variant Source `{'p2_poison==0','p2_poison==1'}` (cổng 2 = hằng NaN) → v1 compile y như cũ.

---

## 6. Giới hạn ghi vào bài (từ quyết định 1, 3)
- **Rời rạc (A):** bộ quan sát (DO/ESO/IM-est) tích phân liên tục trên đầu vào được giữ (ZOH), không rời rạc hoá;
  hợp lý vì băng thông quan sát << 2π·125 Hz ≈ 785 rad/s.
- **IMU giản lược:** gia tốc hệ quán tính cộng nhiễu, không lực riêng trong hệ thân. Vì η sạch, **không có rò trọng
  lực do sai góc** (ngoài đời ≈ g·sin 1° ≈ 0.17 m/s² mỗi 1° sai góc) — đáng kể cho IM-est.
- Trôi trạng thái con lắc không chiếu lại (đo GĐ2a: 6e-14 sau 200 s).

## 7. Chưa làm ở GĐ2b (đã duyệt để sau)
- Xuất lại gió đo cho P2: `export_wind_sim.py --sensor-delay-ms 50 --sensor-noise 0.1` (tuỳ chọn trễ phải thêm) vào
  thư mục riêng; P nhắm w(t + 100 ms), không căn. Trước đó B5 dùng file hiện có + `SensorDelayMs 50` +
  `SensorNoise 0.1` trên phía MATLAB và **chỉ cột L2/L3** (P chưa hợp lệ cho P2).
- WindOff / WindZero trên P2 — GĐ5.
