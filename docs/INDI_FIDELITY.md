# INDI_FIDELITY — đối chiếu đối thủ H3 (vòng ngoài INDI, Smeur 2018) với code

File này cùng dạng với `docs/MOBADC_FIDELITY.md`. Mỗi mục là một phương trình, hoặc một lựa chọn cài đặt, của vòng
ngoài INDI trong Smeur et al. (2018) mà khối H3 dùng hoặc thay thế. Mục gồm:
- số phương trình và trang trong bài;
- dạng LaTeX theo bài;
- dạng trong code kèm `file:dòng`;
- khác biệt và lý do;
- một ô để bạn tick.

**Tên gọi trong bài (bắt buộc):** H3 là *"ước lượng nhiễu dựa trên gia tốc kiểu INDI (vòng ngoài Smeur 2018)"*,
**không phải** toàn bộ bộ điều khiển INDI. Vòng tư thế vẫn là của Guo; không có INDI vòng trong, không nghịch đảo
(25)–(27), không có ma trận hiệu quả điều khiển thích nghi. Câu cho bài, bản tiếng Anh: xem cuối file.

## Nguồn

| # | tài liệu | chi tiết | đã kiểm bằng |
|---|---|---|---|
| S1 | Smeur, E.J.J., de Croon, G.C.H.E., Chu, Q. (2018). *Cascaded incremental nonlinear dynamic inversion for MAV disturbance rejection.* | Control Engineering Practice **73**, 79–90. https://doi.org/10.1016/j.conengprac.2018.01.003 | PDF 12 trang (siêu dữ liệu và trang 1), đọc cả tr. 81–85 |
| S1c | **Corrigendum** của S1: *Corrigendum to "Cascaded incremental nonlinear dynamic inversion control for MAV disturbance rejection"* | Control Engineering Practice **141** (12/2023), bài 105093, online 17/10/2023. https://doi.org/10.1016/j.conengprac.2022.105093 | **Đã đọc toàn văn** (1 trang, PDF người dùng tải qua thư viện, 2026-10-03; `refs/smeur2018_corrigendum.pdf`, SHA-256 `8f338923…88aa`, không commit) |
| S1a | arXiv:1701.07254 **v2** (12/01/2022) của S1 | Ghi chú của tác giả: *"The transfer function in Eq. 12 was incorrect, this has been adjusted. All the conclusions are still valid"* | Trang abs và bản HTML v2 trên arXiv |
| S2 | Sieberling, S., Chu, Q.P., Mulder, J.A. (2010). *Robust flight control using incremental nonlinear dynamic inversion and angular acceleration prediction.* | J. Guidance, Control, and Dynamics **33**(6), 1732–1742. https://doi.org/10.2514/1.49978 | Chỉ bản ghi Crossref; bài chưa đọc |
| S3 | Smeur, E.J.J., Chu, Q.P., de Croon, G.C.H.E. (2016). *Adaptive incremental nonlinear dynamic inversion for attitude control of micro air vehicles.* | J. Guidance, Control, and Dynamics **39**(3), 450–461. https://doi.org/10.2514/1.G001490 | Chỉ bản ghi Crossref; bài chưa đọc |

- **PDF của S1:** `refs/smeur2018.pdf`. Thư mục `refs/` nằm trong `.gitignore`, nên PDF **không** được commit.
- **Trang:** là số trang in của tạp chí. Trang in = trang PDF + 78.

### Corrigendum: phương trình nào bị sửa
- **Đã đọc S1c (2026-10-03).** Nội dung (nguyên văn ý, tr. 105093):
  - *"an incorrect transfer function was included in Eq. (12)"*; dạng đúng:
    $TF_{\eta_{ref}\to\eta} = \dfrac{K_\eta K_\Omega \alpha T_s^2 z^2}{z^3 + (K_\Omega\alpha T_s + K_\eta K_\Omega\alpha T_s^2 + \alpha - 3)z^2 + (3 - 2\alpha - K_\Omega\alpha T_s)z - 1 + \alpha}$ (12).
  - Kèm theo, các số của đoạn ngay sau (12) (tr. 81) đổi:
    | | bài gốc 2018 | corrigendum |
    |---|---|---|
    | gain chọn (câu văn) | $K_\Omega$ = 28.0, $K_\eta$ = 10.7 | $K_\Omega$ = 28.0, $K_\eta$ = **21.4** |
    | cực thực | 0.964 | 0.964 |
    | cặp cực phức | 0.968 ± 0.0463i | **0.965 ± 0.0445i** |
    | sai khác mô hình/đo (Fig. 5), lớn nhất | 6.4 % tại 0.14 s | **4.8 %** tại 0.14 s |
  - *"The mistake does not influence any of the conclusions drawn in the paper."* Không phương trình nào khác, không
    bảng nào (Table 2: ω_n, ζ, K_ξ, K_ξ̇) được nhắc tới.
- Đối chiếu thêm: bản tạp chí 2018 (`refs/smeur2018.pdf`) chứa (12) **bản cũ**; arXiv v2 (S1a, 01/2022) chứa (12) **đã
  sửa** và đúng các số trên ($K_\eta$ = 21.4, 0.965 ± 0.0445i) - khớp với S1c.
- **Ảnh hưởng tới H3: không có.** Mọi chỗ sửa thuộc thiết kế gain **vòng tư thế INDI** (12), (8)–(12), mà H3 không dùng
  (I9). Các phương trình và tham số H3 dựa vào — (4), (14), (17), (19), (23), (24), (28), bộ lọc ω_n = 50 rad/s,
  ζ = 0.55, gain vị trí — không bị sửa.
- Ghi chú lịch sử: trước khi có S1c, ô dưới đã được tick tạm theo arXiv v2 (commit `4d6723f`); nay thay bằng kết quả đọc
  S1c. File người dùng gửi trước đó (SHA `50c27f3d…`) là bài gốc 2018, không phải S1c.
  [x] corrigendum chỉ sửa (12)   [ ] còn sửa phương trình khác: ______   (đã đọc S1c; kèm (12) đổi các số ở tr. 81: K_η 10.7 → 21.4, cực phức, 6.4 % → 4.8 %)

**Kiểm bởi Huyhoang (có hỗ trợ đối chiếu), 2026-10-03:** đối chiếu với PDF gốc; mọi công thức, số phương trình, trang và tham số khớp bài; I1–I12 ĐÚNG sau khi sửa I8, I11, I12 (2026-10-03); ô corrigendum tick 2026-10-03 sau khi đọc S1c (chỉ sửa (12) và các số đi kèm ở tr. 81; không ảnh hưởng H3).

**Đối chiếu ngày 2026-09-30, do Claude đọc S1 tr. 79–85.** Mỗi mục có dòng "Đối chiếu" ghi KHỚP, hoặc KHÁC kèm lý do.
Đây là kết quả tôi đọc; ô kiểm vẫn để bạn tick.

**Tóm tắt:**
- **Khớp về dạng (đã đổi hệ trục):** I2, I4, I5, I6.
- **Khác, có lý do:** I1 (ζ, ω_f), I3 (gia tốc kế), I7 (lọc tổng thay vì lọc từng đầu vào), I8 (ước lượng lực đẩy),
  I9 (vòng tư thế Guo thay INDI trong), I10 (luật PD), I11 (bias), I12 (tần số).
- **Không dùng:** (5)–(7), (12), (13), (17)–(21), (25)–(27). Lý do ghi ở từng mục.
- Ba khác biệt **có lợi cho H3**: gia tốc kế lý tưởng hoá (I3), mô hình lực đẩy khớp đúng plant (I8; trừ lúc động cơ
  bão hoà, khi đó là bất lợi nhỏ), bias danh định bằng 0 (I11; độ nhạy bias 0.086 / 0.17 m/s² đã chạy, §59.2).
  Đã khai báo ở LIMITATIONS G3.

---

## Code đang chạy

Định nghĩa đã đăng ký: REGISTER_P2 §40.1. Các file:
- Khối **P2_H3** (MATLAB Function, 1 kHz): `simulink_blocks/p2_h3_indi.m`.
- Khối **P2_H3_out** (đọc ước lượng từ trạng thái bộ lọc; §50.5): `simulink_blocks/p2_h3_out.m`.
- Tham số: `core/p2_h3_prm.m`. Giá trị ban đầu: `core/p2_setup.m:177–179`.
- Đi dây: `build/build_p2_plant.m:636–659` (khối), `:153–172` (P2_CMP_Sel, P2_CMPW_Sel).
- Bật bằng `p2_cmp = 1` (`pa_configs` 'P2Cmp', 1).

Khi bật, luật vị trí của Guo (9) nhận `d̂_mf := d̂_H3` và `d̂_lf := 0` (kênh gió bị đặt về 0). DO và ESO vẫn chạy nhưng
luật không đọc chúng.

**Hệ trục:** S1 dùng NED (trục z hướng **xuống**). Code dùng hệ quán tính của Guo, trục z hướng **lên**
($\boldsymbol e_3$ hướng lên). Mọi so sánh dưới đây đã đổi hệ trục.

### I1. Bộ lọc bậc hai H
- Số phương trình / trang trong bài: **(4), tr. 81**. Giá trị: **§4.5, tr. 85**.
- Dạng theo bài: $$H(s) = \frac{\omega_n^2}{s^2 + 2\zeta\omega_n s + \omega_n^2} \quad (4)$$
  §4.5: một bộ lọc chung cho vòng trong và vòng ngoài, $\omega_n = 50$ rad/s, $\zeta = 0.55$.
- Dạng trong code: cùng dạng, rời rạc hoá ZOH chính xác ở h = 1 ms, hệ số DC bằng 1. `core/p2_h3_prm.m:14–17`
  ```matlab
  w = 2 * pi * wf_hz;  z = 1 / sqrt(2);
  A = [0 1; -w^2, -2 * z * w];  B = [0; w^2];  Cf = [1 0];
  E = expm([A, B; zeros(1, 3)] * P.h);
  Phi = E(1:2, 1:2);  Gam = E(1:2, 3);
  ```
- Khác biệt:
  - (a) **ζ = 1/√2 thay cho 0.55.**
  - (b) **ω_f không cố định:** chỉnh trên lưới {1, 2, 4, 8, 16} Hz (fixed-5, circle, K 0.5; argmin sai số gộp; nếu
    cực tiểu ở mép lưới thì mở rộng một lần; §40.1 / §50.3). Giá trị của bài, 50 rad/s ≈ 7.96 Hz, nằm giữa 4 và 16 Hz
    của lưới.
- Lý do:
  - (b) Bài chọn ω_n cho Bebop (nhiễu rung của cánh quạt, trade-off với vòng trong). Plant P2 có nhiễu BMI160 và
    không có vòng trong INDI, nên chỉnh ω_f trên cùng tập dò là cách công bằng nhất với đối thủ.
  - (a) ζ = 1/√2 được đăng ký trước (§40.1) và không chỉnh.
  - **Kết quả dò (§55, §56, D21):** lưới cho EDGE-UNRESOLVED (giảm đều tới 32 Hz), nên ω_f được **cố định 32 Hz**, là giá trị tốt nhất đã thử và hào phóng với đối thủ.
- Đối chiếu: **KHÁC, có lý do** (dạng khớp; tham số khác).
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I2. Phương trình chuyển động tịnh tiến
- Số phương trình / trang trong bài: **(14), tr. 82**.
- Dạng theo bài: $$\ddot{\boldsymbol\xi} = \boldsymbol g + \frac{1}{m}\boldsymbol F(\dot{\boldsymbol\xi}, \boldsymbol w) + \frac{1}{m}\boldsymbol T_N(\boldsymbol\eta, T) \quad (14)$$
  ($\boldsymbol g$ là véc-tơ trọng lực trong NED, $\boldsymbol F$ là lực khí động.)
- Dạng trong code: nhiễu được định nghĩa từ chính (14) viết trong hệ z hướng lên:
  $\boldsymbol d = m\boldsymbol a - \hat{\boldsymbol F}_{thr} + m g\boldsymbol e_3$. Ở P2, $\boldsymbol d$ gồm lực khí động
  lên thân **và lực dây tải**. `simulink_blocks/p2_h3_indi.m:23–24`
  ```matlab
  F = force_from_attitude(T, eta);
  u = m * a_meas - F + m * g * [0; 0; 1];
  ```
- Gain / tham số: $m$ ↔ `m` = 1.121 kg (khối lượng bộ điều khiển dùng, như luật (9) của Guo; tải **không** nằm trong
  m); $g$ ↔ 9.81.
- Khác biệt: không có về dạng. Lực tải nằm trong $\boldsymbol d$ vì bộ ước lượng không mô hình hoá tải, đúng tinh thần
  bài (mọi lực không mô hình được đo qua gia tốc).
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I3. Gia tốc đo $\ddot{\boldsymbol\xi}_0$
- Số phương trình / trang trong bài: **§3, tr. 83**, đoạn sau (16). **§4, tr. 83**, đoạn đầu.
- Dạng theo bài: $\ddot{\boldsymbol\xi}_0$ lấy bằng cách *"rotating the specific force measured by the accelerometer in
  the body axes to the NED frame and adding the gravity vector"*.
- Dạng trong code: `a_meas` là gia tốc kế của P2, vốn đã là **gia tốc động học trong hệ quán tính** cộng nhiễu trắng
  BMI160 (180 µg/√Hz). Không có phép quay và không rò trọng lực do sai tư thế. Tín hiệu đi vào khối qua
  `H3_z_a` (`build/build_p2_plant.m:639`).
- Khác biệt: gia tốc kế lý tưởng hoá (LIMITATIONS **M5, G3**; P2_SPEC_AUDIT L4).
- Lý do: mô hình cảm biến chung của P2. Khác biệt này **có lợi cho H3**, đối thủ duy nhất dùng gia tốc đo, nên được khai
  báo là giới hạn.
- Đối chiếu: **KHÁC, có lý do** (có lợi cho đối thủ).
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I4. Véc-tơ lực đẩy theo tư thế $\boldsymbol T_N(\boldsymbol\eta, T)$
- Số phương trình / trang trong bài: **(15), tr. 83**.
- Dạng theo bài (NED, $\boldsymbol T_B = [0, 0, T]^T$):
  $$\boldsymbol T_N(\boldsymbol\eta, T) = \boldsymbol M_{NB}(\boldsymbol\eta)\boldsymbol T_B = \begin{bmatrix}(s\phi s\psi + c\phi c\psi s\theta)T\\ (c\phi s\psi s\theta - c\psi s\phi)T\\ (c\phi c\theta)T\end{bmatrix} \quad (15)$$
- Dạng trong code: cùng tổ hợp lượng giác, theo quy ước (4b) của Guo (z lên, $f > 0$).
  `simulink_blocks/force_from_attitude.m:14–16` (dùng chung với plant)
  ```matlab
  F_act = f_act*[cpsi*sth*cphi + spsi*sphi;
                 spsi*sth*cphi - sphi*cpsi;
                 cth*cphi];
  ```
- Khác biệt: chỉ khác quy ước trục và dấu. Hai thành phần ngang **trùng từng số hạng** với (15). Theo (15), thành phần z
  của lực nâng trong NED mang dấu của $T$ (thân Z hướng xuống). Bài không ghi rõ dấu của $T$ → **CẦN KIỂM** nếu cần
  viết lại (15) trong bài của mình. Code dùng đúng quy ước của plant.
- Đầu vào: $T$ lấy từ I8; $\boldsymbol\eta$ = `eta_c` (tư thế **đo**, ZOH 1 ms, không nhiễu).
- Đối chiếu: **KHỚP** (sau khi đổi hệ trục).
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I5. Giả thiết bỏ đạo hàm của lực khí động
- Số phương trình / trang trong bài: **(16), (17), tr. 83**; **(22), (23), tr. 85**.
- Dạng theo bài: trong khai triển (16), các số hạng $\partial\boldsymbol F/\partial\dot{\boldsymbol\xi}$ và
  $\partial\boldsymbol F/\partial\boldsymbol w$ được đặt bằng 0 (*"the best guess for these terms is zero"*). Ở (23), sự thay
  đổi của trọng lực và lực khí động trong một bước thời gian nhỏ được bỏ qua:
  $$\ddot{\boldsymbol\xi} - \ddot{\boldsymbol\xi}_0 = \frac{1}{m}\boldsymbol T_N(\boldsymbol\eta, T) - \frac{1}{m}\boldsymbol T_N(\boldsymbol\eta_0, T_0) \quad (23)$$
- Dạng trong code: H3 không có mô hình khí động và không có kênh gió (`d̂_lf := 0`, P2_CMPW_Sel,
  `build/build_p2_plant.m:153–172`). Mọi lực ngoài được đo gộp qua gia tốc.
- Khác biệt: không có.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I6. Luật gia số phi tuyến (dạng dùng trong H3)
- Số phương trình / trang trong bài: **(24), (28), tr. 85** (và §7 so dạng này với dạng tuyến tính hoá (19)).
- Dạng theo bài:
  $$\boldsymbol T_N(\boldsymbol\eta, T) = m(\ddot{\boldsymbol\xi} - \ddot{\boldsymbol\xi}_0) + \boldsymbol T_N(\boldsymbol\eta_0, T_0) \quad (24)\qquad \boldsymbol T_N(\boldsymbol\eta, T) = m(\ddot{\boldsymbol\xi} - \ddot{\boldsymbol\xi}_f) + \boldsymbol T_N(\boldsymbol\eta_f, T_f) \quad (28)$$
  ($\ddot{\boldsymbol\xi}$ ở vế phải là gia tốc mong muốn, tức virtual control $\boldsymbol\nu_{\ddot\xi}$ ở (19).)
- Dạng trong code: luật (9) của Guo với $\hat{\boldsymbol d}_{mf} = \hat{\boldsymbol d}_{H3}$ và $\hat{\boldsymbol d}_{lf} = 0$:
  $$\boldsymbol F = m\boldsymbol a_d - \hat{\boldsymbol d}_{H3},\qquad \hat{\boldsymbol d}_{H3} = H\big[m\boldsymbol a - \hat{\boldsymbol F}_{thr}(\boldsymbol\eta, \hat T) + m g\boldsymbol e_3\big]$$
  `simulink_blocks/position_controller.m:10` (luật, MOBADC_FIDELITY E2); `simulink_blocks/p2_h3_out.m` và
  `p2_h3_indi.m:26–30` (ước lượng).
- **Tương đương đại số.** H có hệ số DC bằng 1, nên $H[m g\boldsymbol e_3] = m g\boldsymbol e_3$. Thay vào:
  $$\boldsymbol F = m(\boldsymbol a_d - g\boldsymbol e_3) - m\,H[\boldsymbol a] + H[\hat{\boldsymbol F}_{thr}]$$
  Đây chính là (28), với $\boldsymbol\nu = \boldsymbol a_d - g\boldsymbol e_3$ (gia tốc động học mong muốn),
  $\ddot{\boldsymbol\xi}_f = H[\boldsymbol a]$ và $\boldsymbol T_N(\boldsymbol\eta_f, T_f) \to H[\hat{\boldsymbol F}_{thr}]$ (xem I7).
- Khác biệt:
  - Dùng dạng **phi tuyến (28)**, không dùng dạng tuyến tính hoá (17)–(19).
  - Vì vậy **không có** ma trận $G(\boldsymbol\eta_0, T_0)$ (18), không có nghịch đảo $G^{-1}$, không có hiệu quả điều
    khiển thích nghi (20)–(21).
  - Phép biến lực thành tư thế và lực đẩy là của Guo, không phải (25)–(27) (xem I9).
- Lý do:
  - Bài đưa dạng phi tuyến ra để tránh sai số tuyến tính hoá khi gia số lớn (§4.4, tr. 84–85). §7 (tr. 88) so hai dạng
    bằng một thí nghiệm đổi gia tốc lớn và mô tả các đáp ứng theo trục Z khác nhau. Tôi không dùng §7 như bằng chứng
    dạng nào tốt hơn.
  - Lý do chính là viết dưới dạng ước lượng nhiễu cho phép giữ nguyên luật (9) của Guo cho mọi cột, nên so sánh chỉ
    khác nhau ở ước lượng nhiễu.
- Đối chiếu: **KHỚP** với (28), ở dạng viết lại.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I7. Đồng bộ bộ lọc
- Số phương trình / trang trong bài: **(28), tr. 85**; **§4.5, tr. 85**; Fig. 6, tr. 84.
- Dạng theo bài: gia tốc được lọc bằng H, và các tín hiệu chỉ số 0 cũng được lọc bằng **cùng** H. Trong Fig. 6,
  $\phi, \theta$ được lọc riêng thành $\phi_f, \theta_f$, rồi (28) dùng $\boldsymbol T_N(\boldsymbol\eta_f, T_f)$. Vòng trong và
  vòng ngoài dùng chung một H để gia số lực đẩy chuyển thẳng từ vòng ngoài vào vòng trong (tr. 83, cuối §3).
- Dạng trong code: một bộ lọc H áp lên **tổng** $m\boldsymbol a - \hat{\boldsymbol F}_{thr} + m g\boldsymbol e_3$. Vì H tuyến
  tính, điều này tương đương lọc cả hai số hạng bằng cùng một H. `p2_h3_indi.m:24–30`
- Khác biệt:
  - Code lọc $\boldsymbol T_N(\boldsymbol\eta, T)$ **sau** khi tính, tức là $H[\boldsymbol T_N(\boldsymbol\eta, T)]$.
  - Bài lọc từng đầu vào rồi mới tính, tức là $\boldsymbol T_N(H\boldsymbol\eta, HT)$.
  - Hai cách bằng nhau tới bậc một, khác nhau ở bậc hai theo biên độ góc.
  - Không có đồng bộ với vòng trong, vì không có INDI vòng trong (I9).
- Lý do: giữ đúng yêu cầu cốt lõi của bài, là cùng một độ trễ lọc trên gia tốc và trên lực đẩy, bằng một bộ lọc duy nhất.
- Đối chiếu: **KHÁC, có lý do** (khác ở bậc hai).
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I8. Ước lượng lực đẩy $T$
- Số phương trình / trang trong bài: **§4.3, tr. 84** (Fig. 8).
- Dạng theo bài:
  - Lực đẩy lấy từ đường cong tĩnh "lực đẩy theo tốc độ quay", là một hàm bậc hai khớp với số đo trên cân.
  - Tốc độ quay lấy từ **rpm đo** của động cơ.
  - Bài bác bỏ cách dùng gia tốc kế trục z thân để ước lượng T/m, vì sai khi có lực khí động theo trục z.
- Dạng trong code: không có rpm đo. $\hat T$ là **lệnh tổng lực đẩy đi qua mô hình trễ động cơ bậc nhất danh định**
  (τ_m = 17 ms), rời rạc hoá chính xác.
  `simulink_blocks/p2_h3_indi.m:25`, `core/p2_h3_prm.m:18`
  ```matlab
  s_next(1) = aT * T + (1 - aT) * f_cmd;          % aT = exp(-h / tau_m)
  ```
  Điều kiện đầu $\hat T_0 = (m_Q + m_L)g$ (`core/p2_setup.m:178–179`).
- **`f_cmd` lấy TRƯỚC bão hoà động cơ** (đã kiểm 2026-10-03, trả lời chỗ "CẦN KIỂM" cũ):
  - `f_cmd` của H3 = tín hiệu `fthr_c` (`build/build_p2_plant.m:640`: `V_fthr_d` → `H3_z_f`). `fthr_c` là bản giữ mẫu
    1 kHz (`H_fthr`, `:579`; `V_fthr_d`, `:596`) của tag `fthr` (`F_fthr`, `:498`).
  - Tag `fthr` được ghi bởi Goto `G_fthr` trong `Attitude_Reference`, nối từ đầu ra `f` của `Thrust_AttRef_16`
    (đọc từ XML của `baseline1.slx`, `system_16.xml`: `G_fthr` ← `Thrust_AttRef_16` out 1), tức là
    `simulink_blocks/thrust_attitude_ref.m:24`: `f = min(max(Fz/cc, 0), F_TOT_MAX)`.
  - Vậy `f_cmd` **đã** qua kẹp tổng lực đẩy `[0, F_TOT_MAX]` (P2: 27.603 N), nhưng **chưa** qua kẹp mô-men
    (`motor_allocation.m:10`) và bão hoà từng động cơ (`motor_allocation.m:13`). Lực đẩy tổng đã áp là
    `f_act = wrench_act(1)` (`motor_allocation.m:14–15`); `f_act ≠ f_cmd` khi và chỉ khi có động cơ chạm `f_min` = 0 hoặc
    `f_max` (kẹp mô-men một mình không đổi tổng lực đẩy, vì phân bổ (2) giải đúng khi không động cơ nào bão hoà).
  - **Ảnh hưởng:** lúc có động cơ bão hoà, $\hat T$ của H3 lệch khỏi lực đẩy thật, nên ước lượng nhiễu của H3 sai
    trong khoảng đó - một **bất lợi nhỏ cho H3**, chỉ trong thời gian bão hoà. Trong mọi lúc khác $\hat T$ khớp đúng.
  - **Thời gian bão hoà trong các lần chạy H3 đã có - chưa có số đúng loại:**
    - Đã ghi trong REGISTER chỉ có `tilt_sat_frac` (kẹp góc nghiêng 30°, không phải bão hoà động cơ): > 1 % trên 13/134
      đoạn ở H3-circle và 14/139 đoạn ở H3-hover (§57).
    - Đại lượng đúng cho câu hỏi này là thời gian có `f_i` của `motor_allocation` (`f_i_log`) ở 0 hoặc `f_max` của P2.
      Nó **không** được lưu trong file kết quả.
    - `p2.sat_frac` / `p2.sat_frac_stat` (`core/p2_summary.m:38–40`, đúng `f_max` của P2) có trong `results/gd7/H3-*.mat`
      trên máy người dùng, nhưng đo trên lực đẩy **sau trễ động cơ** (`p2_f_log` ← `V_lag`, `build/build_p2_plant.m:711`),
      nên chỉ là **cận dưới** của thời gian bão hoà lệnh. Số: **CẦN ĐỌC** từ các file đó (không sửa code).
    - `sat_frac` của `pa_configs` dùng hằng số v1 (6.0 N/động cơ, 21.6 N tổng), không phải giới hạn P2 (7.6675 N,
      27.603 N), nên **không dùng được** cho P2. Đã thêm (runner `84a243b`, REGISTER_P2 §60.4) chỉ số đúng loại:
      `sat_rotor` = tỉ lệ thời gian có `f_i_log` (đầu ra `Motor_Allocation`, sau kẹp, trước trễ) ở 0 hoặc `f_max` của P2,
      và `sat_p2` (thêm giới hạn tổng 27.603 N). CONFIRM2 sẽ báo hai chỉ số này cho H3; các lần chạy H3 cũ chỉ có cận dưới.
- Khác biệt: dùng mô hình trễ thay cho rpm đo. Plant P2 có trễ động cơ **đúng** bậc nhất 17 ms, nên $\hat T$ khớp với
  lực đẩy thật, trừ lúc có động cơ bão hoà (xem trên). Ngoài lúc bão hoà, điều này **có lợi cho H3**.
- Lý do: P2 không mô phỏng rpm. Mô hình trễ là cách gần nhất với "đo rpm" mà không thêm cảm biến; §40.1 đã đăng ký.
- Đối chiếu: **KHÁC, có lý do** (có lợi cho đối thủ).
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: sau sửa 2026-10-03: f_cmd trước bão hoà động cơ

### I9. Vòng trong: tư thế của Guo thay cho INDI vòng trong
- Số phương trình / trang trong bài: **(3)–(7), tr. 81**; **(8)–(12), tr. 81** (vòng tư thế và thiết kế gain; (12) bị
  sửa ở S1a / S1c); **(25)–(27), tr. 85** (nghịch đảo ra lệnh tư thế và lực đẩy).
- Dạng theo bài:
  - Vòng trong là INDI tư thế (7), có phản hồi động cơ và đạo hàm tốc độ góc đã lọc.
  - Lệnh $T, \phi_c, \theta_c$ lấy từ (25)–(27).
  - Gia số lực đẩy $\tilde T$ đi thẳng vào vòng trong (Fig. 6).
- Dạng trong code: **không dùng.** Lực $\boldsymbol F$ của luật (9) đi qua phép biến lực thành tư thế và lực đẩy của
  Guo, rồi tới luật tư thế của Guo (MOBADC_FIDELITY E3, E4), cùng gain với mọi cột.
- Khác biệt: H3 chỉ là **vòng ngoài** (ước lượng nhiễu dựa trên gia tốc). Đây là lý do của tên gọi bắt buộc ở đầu
  file.
- Lý do: so sánh công bằng. Mọi cột (Classical, DO, ESO, MOBADC, L3, H3) dùng chung vòng tư thế và gain của Guo; chỉ
  ước lượng nhiễu vị trí thay đổi. INDI vòng trong sẽ đổi cả vòng tư thế, và C4 (gain Guo mất ổn định khi trễ động cơ
  lớn) cho thấy vòng tư thế là một biến số riêng.
- Đối chiếu: **KHÁC, có lý do** (phạm vi).
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I10. Luật PD cho gia tốc mong muốn
- Số phương trình / trang trong bài: **§4.1, tr. 83**; Fig. 7, tr. 84.
- Dạng theo bài: $\boldsymbol\nu_{\ddot\xi}$ lấy từ một bộ PD trên vị trí và vận tốc (Fig. 7: $K_\xi$, $K_{\dot\xi}$), gain
  *"manually tuned to give a fast response with little overshoot"*.
- Dạng trong code: $\boldsymbol\nu = \boldsymbol a_d - g\boldsymbol e_3 = \boldsymbol K_\gamma\boldsymbol e_\gamma +
  \boldsymbol K_v\boldsymbol e_v + \ddot{\boldsymbol\gamma}_d$, với $\boldsymbol K_\gamma$ = diag(12, 12, 35),
  $\boldsymbol K_v$ = diag(8, 8, 18) của Guo và feed-forward gia tốc quỹ đạo. `simulink_blocks/position_controller.m:10`
- Khác biệt: gain của Guo thay cho gain chỉnh tay của bài; có thêm feed-forward $\ddot{\boldsymbol\gamma}_d$.
- Lý do: cùng gain và cùng feed-forward cho mọi cột; H3 được chỉnh qua ω_f (I1).
- Đối chiếu: **KHÁC, có lý do**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### I11. Bias gia tốc kế
- Số phương trình / trang trong bài: **§4.6, tr. 85**.
- Dạng theo bài:
  - Bias gia tốc kế làm lệch vị trí dừng.
  - Bias được ước lượng bằng hiệu giữa gia tốc suy từ vận tốc GPS / định vị trong nhà và gia tốc đo, qua bộ lọc bậc
    hai 0.25 rad/s.
- Dạng trong code: không ước lượng bias. Bias **danh định** của P2 bằng 0 (hiệu chuẩn; `core/p2_params.m:32`).
  Cột độ nhạy `H3_b086` / `H3_b170`: bias ngang 0.086 / 0.17 m/s², hướng ngẫu nhiên theo đoạn (MT19937, hạt
  7000000 + 100·seg + 31; `core/p2_acc_bias_vec.m:17`), bật bằng `'P2AccBias'` (`experiments/run_p2_gd7.m`, col_spec).
- Khác biệt: không có khâu ước lượng bias. Danh định vẫn bias 0, điều này **có lợi cho H3**; độ nhạy theo bias **đã có**:
  - Đêm 18 (REGISTER_P2 §58.2, §59.2; S40hover, 43 đoạn): H3 không bias 0.00211 m; `H3_b086` 0.00746 m, `H3_b170`
    0.01433 m. Trên các đoạn lặng, H3_b086 = 7.1–7.3 mm và H3_b170 = 14.1–14.3 mm, **khớp dự đoán giải tích viết trước
    khi chạy** $b/K_\gamma$ = 7.2 và 14.2 mm (§58.2). So với (iii-0): +116.72 % và +316.31 %.
  - Hai cột này nằm trong CONFIRM2 (§60.4, cột mô tả của tập hover).
  - Bản ghi cũ ("độ nhạy bias đã bị bỏ (D17)") lỗi thời: D17 chỉ bỏ độ nhạy bias của (iii-m); đã sửa 2026-10-03.
- Đối chiếu: **KHÁC, có lý do** (có lợi cho đối thủ).
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: sau sửa 2026-10-03: độ nhạy bias §59.2

### I12. Tần số chạy và thời điểm cập nhật
- Số phương trình / trang trong bài: **tr. 81** (mô hình động cơ của Bebop ở *"a sample frequency of 512 Hz"*);
  **tr. 86**, cột trái (phần thí nghiệm): *"The control algorithm, as well as the onboard accelerometer and gyroscope,
  were running at 512 Hz."* (vị trí từ Optitrack chỉ gửi ở 4 Hz, cùng đoạn).
- Dạng theo bài: thuật toán điều khiển, gia tốc kế và gyro chạy ở 512 Hz (tr. 86); mô hình động cơ ở 512 Hz (tr. 81).
- Dạng trong code:
  - H3 chạy ở **1 kHz** (tần số IMU/tư thế của P2; các ZOH `H3_z_*`, `build/build_p2_plant.m:639–641`).
  - Luật vị trí đọc $\hat{\boldsymbol d}_{H3}$ ở **125 Hz** (tần số lệnh lực vị trí của P2, LIMITATIONS M4).
- Khác biệt: ước lượng cập nhật ở 1 kHz, nhưng lệnh lực chỉ cập nhật ở 125 Hz như mọi cột (ZOH `H_Fcmd` ở `p2_Ts_pos`,
  `build/build_p2_plant.m:578`). Thành phần trên 62.5 Hz (Nyquist của lệnh 125 Hz) không dùng được và bị chồng phổ;
  đây là lý do lưới ω_f dừng dưới ~60 Hz (§56).
- Lý do: rời rạc hoá chung của P2.
- Đối chiếu: **KHÁC, có lý do**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: sau sửa 2026-10-03: thêm tr. 86

---

## Câu cho bài (tiếng Anh)

> **Methods.** As an acceleration-based competitor we implement the disturbance estimate of the outer INDI loop of
> Smeur et al. (2018) — an *INDI-type acceleration-based disturbance estimate*, not the full cascaded INDI controller:
> the estimate $H[m\boldsymbol a - \hat{\boldsymbol F}_{thr} + mg\boldsymbol e_3]$ replaces the observer estimates in the
> position law of Guo et al. (2020), which is algebraically the nonlinear increment law (28) of Smeur et al. The
> attitude loop, its gains and the position gains are those of Guo et al. for every controller; the filter is a
> second-order low-pass with ζ = 1/√2 whose cut-off is tuned on the tuning segments.
>
> **Limitations.** The simulated accelerometer returns the kinematic acceleration without attitude-error gravity
> leakage or bias, and the thrust estimate uses the exact motor-lag model of the plant; both favour this competitor.

Nguồn cho bài: S1 và S1c (đã đọc). S2 và S3 chỉ trích như nền tảng của INDI (INDI của Sieberling 2010; bộ lọc đồng
bộ và INDI thích nghi cho MAV của Smeur 2016). Chưa đọc hai bài này, nên không trích số phương trình nào từ chúng.
