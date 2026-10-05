# MOBADC_FIDELITY — đối chiếu MOBADC (Guo et al. 2020) với code

Mỗi mục bên dưới là một phương trình của Guo et al. (2020) mà code dùng. Mục gồm: số phương trình và trang trong bài,
dạng LaTeX theo bài, dạng trong code kèm `file:dòng`, gain và tham số, khác biệt nếu có, và một ô để bạn tick. Mục
cuối giải thích các lệch tái lập cũ ở Table S4.

**Bài gốc.** Guo, K., Jia, J., Yu, X., Guo, L., Xie, L. (2020). *Multiple observers based anti-disturbance control for
a quadrotor UAV against payload and wind disturbances.* Control Engineering Practice 102, 104560.
https://doi.org/10.1016/j.conengprac.2020.104560. Bản PDF (11 trang) nằm ở `refs/guo2020.pdf`. Thư mục này đã có trong
`.gitignore`, nên PDF **không** được commit.

**Kiểm bởi Huyhoang (có hỗ trợ đối chiếu), 2026-10-03:** đối chiếu với PDF gốc; mọi công thức, số phương trình, trang và tham số khớp bài; E1–E17 ĐÚNG sau khi sửa E11, E13 (2026-10-03).

**Đối chiếu ngày 2026-09-29, do Claude đọc cả 11 trang.**
- "Trang" là số trang in ở chân trang của bài.
- Dạng theo bài được chép theo ký hiệu của bài.
- Mỗi mục có dòng "Đối chiếu" ghi KHỚP, hoặc KHÁC kèm lý do. Đây là kết quả tôi đọc; ô kiểm vẫn để bạn tick.

**Tóm tắt:**
- **11 mục khớp nguyên văn:** E1, E2, E4, E6, E7 (có chênh ghi chú), E8, E9, E11, E14, E15, E16.
- **6 mục khác có lý do:** E3, E5, E10, E12, E13, E17.
- **Không có lệch cài đặt nào**, tức là không có chỗ code làm khác bài mà không có lý do. Hai chỗ bài tự mâu thuẫn buộc
  code phải chọn một cách đọc: E10 và E17.

---

## Code đang chạy trên P2

Mọi khối điều khiển là các khối MATLAB Function trong `baseline1.slx`. Bản đọc được nằm ở `simulink_blocks/*.m`, và
`tools/extract_eml.py --check` (bước 7 của `check_all`) bảo đảm hai bên trùng nhau. Hai plant v1 và P2 dùng **cùng một
bộ điều khiển**. P2 chỉ thay plant và đầu vào. Trên P2, bộ điều khiển đọc tín hiệu đo:
- `gamma_c`, `nu_c`: mocap 125 Hz, trễ 8 ms, vận tốc lấy bằng sai phân;
- `eta_c`: ZOH 1 ms, không nhiễu;
- `omega_c`: gyro có nhiễu;
- `Fcmd_c`: vòng vị trí chạy ở 125 Hz.

Nguồn: `build/build_p2_plant.m` dòng 218–250, `docs/devlog/GD2B_DESIGN.md` §2.2. Giá trị số của P2 lấy từ
`core/p2_params.m` và `core/init_MOBADC_params.m`.

### E1. Lực đẩy theo tư thế
- Số phương trình / trang trong bài: **(4b), tr. 3**. Ma trận quay: **(1), tr. 3**.
- Dạng theo bài (LaTeX): $m\dot{\boldsymbol v} = \boldsymbol F - mg\boldsymbol e_3 + \boldsymbol d_f$ (4a),
  $$\begin{bmatrix}F_x\\F_y\\F_z\end{bmatrix} = f\begin{bmatrix} c_\psi s_\theta c_\phi + s_\psi s_\phi \\ s_\psi s_\theta c_\phi - s_\phi c_\psi \\ c_\theta c_\phi \end{bmatrix} \quad (4b)$$
- Dạng trong code: giống hệt (4b). `simulink_blocks/force_from_attitude.m:14`
  ```matlab
  F_act = f_act*[cpsi*sth*cphi + spsi*sphi;
                 spsi*sth*cphi - sphi*cpsi;
                 cth*cphi];
  ```
- Gain / tham số: $f$ ↔ `f_act` (tổng lực đẩy sau phân bổ, trước trễ động cơ; ≤ 27.603 N trên P2); $\phi,\theta,\psi$ ↔
  `eta`, là góc **thật** (`UAV_Plant/Int_eta`).
- Khác biệt: không có về dạng. Đầu vào trên P2 là góc thật, không phải `eta_c`. Hai tín hiệu này chỉ khác nhau một ZOH
  1 ms, vì `eta_c` không có nhiễu (GD2B_DESIGN §2.2).
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E2. Luật điều khiển vị trí
- Số phương trình / trang trong bài: **(8), (9), tr. 4**.
- Dạng theo bài (LaTeX):
  $$\boldsymbol e_\gamma = \boldsymbol\gamma_d - \boldsymbol\gamma,\ \boldsymbol e_v = \boldsymbol v_d - \boldsymbol v \quad (8)\qquad \boldsymbol a_d = \boldsymbol K_\gamma\boldsymbol e_\gamma + \boldsymbol K_v\boldsymbol e_v + g\boldsymbol e_3 + \ddot{\boldsymbol\gamma}_d,\ \ \boldsymbol F = m\boldsymbol a_d - \hat{\boldsymbol d}_{mf} - \hat{\boldsymbol d}_{lf} \quad (9)$$
- Dạng trong code: giống hệt. `simulink_blocks/position_controller.m:10`
  ```matlab
  e_gamma = gamma_d - gamma;
  e_nu    = nu_d    - nu;
  a_d = Kgamma*e_gamma + Knu*e_nu + g*[0;0;1] + acc_d;
  F   = m*a_d - dmf_hat - dlf_hat;
  ```
- Gain / tham số (ký hiệu bài ↔ code ↔ giá trị P2):

  | bài | code | giá trị |
  |---|---|---|
  | $\boldsymbol K_\gamma$ | `Kgamma` | diag(12, 12, 35) (A.2, tr. 10) |
  | $\boldsymbol K_v$ | `Knu` | diag(8, 8, 18) (A.2, tr. 10) |
  | $m$ | `m` | 1.121 kg (A.1, tr. 10) |
  | $g$ | `g` | 9.81 m/s² (bài không ghi giá trị) |
- Khác biệt: không có về dạng. Trên P2, $\boldsymbol\gamma, \boldsymbol v$ là giá trị **đo**, và luật chạy ở 125 Hz.
  Cột L0 là luật này nguyên dạng. Remark 9 (tr. 7) định nghĩa "classical PID" bằng (9), (16), (18) khi bỏ các ước lượng
  $\hat{\boldsymbol d}$; code làm đúng như vậy bằng công tắc.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E3. Tư thế tham chiếu và tổng lực đẩy
- Số phương trình / trang trong bài: **(16), tr. 5**.
- Dạng theo bài (LaTeX):
  $$f = \frac{F_z}{c_\theta c_\phi},\quad \theta_d = \arctan\Big(\frac{F_x c_\psi + F_y s_\psi}{F_z}\Big),\quad \phi_d = \arctan\Big(c_\theta\frac{F_x s_\psi - F_y c_\psi}{F_z}\Big) \quad (16)$$
  Bài viết "$\psi_d$ is the desired yaw angle that is set to zero in the paper".
- Dạng trong code: `simulink_blocks/thrust_attitude_ref.m:16`
  $$F_z \leftarrow \max(F_z, F_{z,\min}),\ \theta_d = \mathrm{atan2}(F_xc_\psi + F_ys_\psi, F_z),\ \phi_d = \mathrm{atan2}\big(c_{\theta_d}(F_xs_\psi - F_yc_\psi), F_z\big),\ |\phi_d|,|\theta_d| \le 30^\circ,\ f = \mathrm{sat}_{[0,F_{tot,\max}]}\big(F_z/\max(c_\theta c_\phi, 0.5)\big)$$
  ```matlab
  Fx = F(1); Fy = F(2); Fz = max(F(3), Fz_min);
  theta_d = atan2(Fx*cpsi + Fy*spsi, Fz);
  phi_d   = atan2(cos(theta_d)*(Fx*spsi - Fy*cpsi), Fz);
  theta_d = min(max(theta_d, -TILT_MAX), TILT_MAX);
  phi_d   = min(max(phi_d,   -TILT_MAX), TILT_MAX);
  cc = max(cos(theta)*cos(phi), 0.5);
  f  = min(max(Fz/cc, 0), F_TOT_MAX);
  ```
- Gain / tham số: `Fz_min` = 0.5 N; `TILT_MAX` = 30°; `F_TOT_MAX` = 27.603 N trên P2 (đêm 14 D2: 18.396 N). Không giá trị
  nào có trong bài.
- Khác biệt:
  1. Trong $\phi_d$, bài viết $c_\theta$, còn code dùng $c_{\theta_d}$. Lý do: với $c_{\theta_d}$, cặp $(\theta_d, \phi_d)$ là
     nghịch đảo đúng của (4b) tại tư thế lệnh. Tự kiểm: thay (4b) vào thì $(F_xs_\psi - F_yc_\psi)/F_z = \tan\phi/c_\theta$.
     Với $c_\theta$ thật thì hai cách khác nhau ở bậc $|\theta - \theta_d|$.
  2. Code dùng `atan2` thay cho `arctan`. Hai hàm cho cùng giá trị khi $F_z > 0$, và điều này luôn đúng nhờ sàn $F_{z,\min}$.
  3. Có ba kẹp mà bài không công bố: sàn $F_z$ (tránh kỳ dị), góc 30° (Assumption 4 của bài giả thiết góc nhỏ, tr. 6),
     và tổng lực đẩy.
  4. Mẫu số của $f$ có sàn 0.5.
  Các điểm 2–4 đã khai báo ở MANUSCRIPT §3.2. Điểm 1 chưa khai báo; tôi sẽ thêm vào bảng GĐ11.
- Đối chiếu: **KHÁC, có lý do**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E4. Luật điều khiển tư thế
- Số phương trình / trang trong bài: **(17), (18), tr. 5**; Remark 3 (tr. 5): $\boldsymbol\omega_d = 0$.
- Dạng theo bài (LaTeX):
  $$\boldsymbol e_\eta = \boldsymbol\eta_d - \boldsymbol\eta \quad (17)\qquad \boldsymbol\tau_d = \boldsymbol K_\eta\boldsymbol e_\eta - \boldsymbol K_\omega\boldsymbol\omega - \hat{\boldsymbol d}_{l\tau} \quad (18)$$
  $\boldsymbol\omega = [p, q, r]^\top$ là tốc độ góc trong hệ thân (tr. 3).
- Dạng trong code: giống hệt. `simulink_blocks/attitude_controller.m:9`
  ```matlab
  e_eta   = eta_d - eta;
  tau_cmd = K_eta*e_eta - K_omega*omega - dltau_hat;
  ```
- Gain / tham số: $\boldsymbol K_\eta$ = diag(2.16, 1.92, 0.59), $\boldsymbol K_\omega$ = diag(0.20, 0.12, 0.12) (A.2, tr. 10).
  $\boldsymbol\omega$ ↔ `omega_c` (gyro, có nhiễu σ 2.73e-3 rad/s).
- Khác biệt: không có.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E5. Đổi tốc độ góc Euler sang tốc độ góc thân
- Số phương trình / trang trong bài: **không có trong bài.** Bài chỉ định nghĩa $\boldsymbol\Omega = [\dot\phi,\dot\theta,\dot\psi]^\top$
  và $\boldsymbol\omega = [p,q,r]^\top$ (tr. 3) mà không cho phép đổi. Phép đổi là kiến thức sách giáo khoa về phép quay
  ZYX (ví dụ Beard & McLain 2012, ch. 3; trang: CẦN TÌM).
- Dạng theo bài (LaTeX): không có. Dạng sách giáo khoa:
  $$\boldsymbol\omega = \begin{bmatrix} 1 & 0 & -s_\theta \\ 0 & c_\phi & s_\phi c_\theta \\ 0 & -s_\phi & c_\phi c_\theta \end{bmatrix}\boldsymbol\Omega$$
- Dạng trong code: giống dạng sách giáo khoa. `simulink_blocks/euler_to_body_rates.m:9`
  ```matlab
  T = [1, 0,    -sth;
       0, cphi,  sphi*cth;
       0, -sphi, cphi*cth];
  omega = T*eta_dot;
  ```
- Gain / tham số: không có.
- Khác biệt: code bổ sung phép đổi mà bài dùng ngầm. Lý do: (18) cần $\boldsymbol\omega$ trong hệ thân. Kiểm bằng sympy:
  $M(\boldsymbol\eta) = T^\top \mathrm{diag}(I)\,T$ với đúng ma trận $T$ này (xem E11).
- Đối chiếu: **KHÁC (bổ sung dạng sách giáo khoa), có lý do**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E6. Hệ sinh nhiễu tải (nội mô hình của DO)
- Số phương trình / trang trong bài: **(6), tr. 3**.
- Dạng theo bài (LaTeX):
  $$\dot{\boldsymbol\xi} = \boldsymbol A\boldsymbol\xi,\ \boldsymbol d_m = \boldsymbol B\boldsymbol\xi,\quad \boldsymbol A = \mathrm{blkdiag}(\boldsymbol A_x, \boldsymbol A_y, \boldsymbol A_z),\ \boldsymbol A_i = \begin{bmatrix}0 & \sigma_i\\ -\sigma_i & 0\end{bmatrix},\quad \boldsymbol B = \begin{bmatrix}1&0&0&0&0&0\\0&0&1&0&0&0\\0&0&0&0&1&0\end{bmatrix} \quad (6)$$
- Dạng trong code: giống hệt, với $\sigma_x = \sigma_y = \sigma_z$ = `payload_sigma`. `build/build_do_matrices.m:158`
  ```matlab
  A_do(b+1:b+2, b+1:b+2) = [0 w; -w 0];
  B_do(i, b+1) = 1;
  ```
- Gain / tham số: $\sigma_i$ ↔ `payload_sigma` = 1.575 rad/s (circle, Test 4). Về đơn vị, xem E17.
- Khác biệt: không có với cấu hình của bài (`do_harm = 1`, cột L0). Bài cũng dùng một σ chung ("σ_i is approximately
  equal to 0.25 s⁻¹", tr. 7 và 9). Các cột L2/L3/V của bài này thêm mode DC hoặc bảng tần số riêng từng trục; đó là phần
  mở rộng, không thuộc Guo.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E7. Bộ quan sát nhiễu (DO) — phương trình trạng thái
- Số phương trình / trang trong bài: **(10)–(13), tr. 4**. Gain $l$: A.2, tr. 10.
- Dạng theo bài (LaTeX):
  $$\boldsymbol z = \hat{\boldsymbol\xi} - \boldsymbol p(\boldsymbol\gamma,\boldsymbol v)\ (11a),\quad \boldsymbol p = \int \boldsymbol l(\boldsymbol\gamma,\boldsymbol v)[\dot{\boldsymbol\gamma}^\top, \dot{\boldsymbol v}^\top]^\top dt\ (11b),\quad \boldsymbol l = \Big(\frac{\partial\boldsymbol p}{\partial\boldsymbol\gamma}, \frac{\partial\boldsymbol p}{\partial\boldsymbol v}\Big)\ (13)$$
  $$\dot{\boldsymbol z} = (\boldsymbol A - \boldsymbol l\boldsymbol G\boldsymbol B)\boldsymbol z + \boldsymbol A\boldsymbol p - \boldsymbol l\big(\boldsymbol G\boldsymbol B\boldsymbol p + \boldsymbol f(\boldsymbol v) + \boldsymbol G\boldsymbol F + \boldsymbol G\hat{\boldsymbol d}_{lf}\big),\ \ \hat{\boldsymbol\xi} = \boldsymbol z + \boldsymbol p,\ \ \hat{\boldsymbol d}_{mf} = \boldsymbol B\hat{\boldsymbol\xi} \quad (12)$$
  $$\boldsymbol G = \tfrac{1}{m}[\boldsymbol 0_{3\times3}, \boldsymbol I_{3\times3}]^\top,\quad \boldsymbol f(\boldsymbol v) = [\boldsymbol v^\top, 0, 0, -g]^\top \quad \text{(tr. 4)}$$
  Bài viết "p(γ,v) can be chosen as a linear function such that l(γ,v) will be a constant matrix" (tr. 5).
- Dạng trong code: giống hệt, với $\boldsymbol p = \boldsymbol l[\boldsymbol\gamma; \boldsymbol v]$ ($\boldsymbol l$ hằng; hằng số tích phân
  của (11b) nằm trong điều kiện đầu của $\boldsymbol z$). `simulink_blocks/do_derivative.m:14`
  ```matlab
  p    = l_gain*[gamma; nu];
  f_nu    = [nu; 0; 0; -g];
  z_dot   = (A_do - l_gain*G_do*B_do)*z + A_do*p ...
            - l_gain*(G_do*B_do*p + f_nu + G_do*F + G_do*dlf_hat);
  ```
- Gain / tham số: $\boldsymbol l$ (A.2, tr. 10) là ma trận 6×6. Nó chỉ khác 0 ở cột $\boldsymbol v$: hàng 1–2 bằng 0.1 ở cột
  $v_x$, hàng 3–4 bằng 0.08 ở cột $v_y$, hàng 5–6 bằng 0.1 ở cột $v_z$. Code dựng đúng ma trận này
  (`build/build_do_matrices.m:161`, `l_axis` = [0.10, 0.08, 0.10]). $\boldsymbol G$ ↔ `G_do` với $m$ = 1.121 kg.
- Khác biệt: không có về dạng. Có một chỗ bài không nói rõ: $\boldsymbol F$ trong (12) chỉ được gọi là "equivalent control
  force" (tr. 3). Code dùng lực **đã áp**, tức lực sau phân bổ và bão hoà nhân với hướng theo tư thế thật (tag `F_act`,
  E1). Trên P2, đó là lực **trước** trễ động cơ, vì bộ điều khiển không biết trễ này. Cực sai số mỗi trục:
  $s^2 + (l/m)s + \sigma(\sigma + l/m)$. Với $l = 0.08$ thì phần thực là −0.0357, hằng số thời gian 28 s.
- Đối chiếu: **KHỚP** (cách hiểu $\boldsymbol F$ đã khai báo ở trên).
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E8. Bộ quan sát nhiễu (DO) — đầu ra
- Số phương trình / trang trong bài: **(12), dòng 2–3, tr. 4**.
- Dạng theo bài (LaTeX): $\hat{\boldsymbol\xi} = \boldsymbol z + \boldsymbol p(\boldsymbol\gamma,\boldsymbol v),\ \hat{\boldsymbol d}_{mf} = \boldsymbol B\hat{\boldsymbol\xi}$
- Dạng trong code: giống hệt. `simulink_blocks/do_output.m:10`
  ```matlab
  dmf_hat = B_do*(z + l_gain*[gamma; nu]);
  ```
- Gain / tham số: như E7.
- Khác biệt: không có. Code tách đầu ra thành khối riêng để phá vòng đại số; về toán học không đổi.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E9. ESO vị trí
- Số phương trình / trang trong bài: **(14) tr. 4, (15) tr. 5**.
- Dạng theo bài (LaTeX):
  $$\dot{\boldsymbol z}_{p1} = \boldsymbol z_{p2} + \boldsymbol K_{p1}\boldsymbol e_{p1},\ \ \dot{\boldsymbol z}_{p2} = \tfrac{1}{m}\big(\boldsymbol F - mg\boldsymbol e_3 + \boldsymbol z_{p3} + \hat{\boldsymbol d}_{mf}\big) + \boldsymbol K_{p2}\boldsymbol e_{p1},\ \ \dot{\boldsymbol z}_{p3} = \boldsymbol K_{p3}\boldsymbol e_{p1},\ \ \boldsymbol e_{p1} = \boldsymbol x_{p1} - \boldsymbol z_{p1} \quad (15)$$
  với $\boldsymbol x_{p1} = \boldsymbol\gamma$ và $\boldsymbol x_{p3} = \boldsymbol d_{lf}$ (14), tức $\boldsymbol z_{p3}$ là một **lực**.
- Dạng trong code: giống hệt. `simulink_blocks/eso_pos_derivative.m:11`, `simulink_blocks/eso_pos_output.m:7`
  ($\hat{\boldsymbol d}_{lf} = \boldsymbol z_{p3}$)
  ```matlab
  ep1 = gamma - zp1;
  zp1_dot = zp2 + Kp1*ep1;
  zp2_dot = (1/m)*(F - m*g*[0;0;1] + zp3 + dmf_hat) + Kp2*ep1;
  zp3_dot = Kp3*ep1;
  ```
- Gain / tham số: $\boldsymbol K_p = [\boldsymbol K_{p1}, \boldsymbol K_{p2}, \boldsymbol K_{p3}]$, mỗi khối là 50, 833, 78 × I₃ (A.2, tr. 10).
- Khác biệt: không có. Nhận xét: đa thức đặc trưng mỗi trục là $s^3 + 50s^2 + 833s + 78/m$, với nghiệm $-24.96 \pm 14.35j$ và
  $-0.084$ rad/s. Ước lượng gió vì vậy chậm, hằng số thời gian khoảng 12 s. Đó là hệ quả của chính gain trong bài.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E10. ESO tư thế
- Số phương trình / trang trong bài: **(19), (20) tr. 5**; phân tích ổn định **(29), (30) tr. 6**; Assumption 4 (tr. 6).
- Dạng theo bài (LaTeX), với $\boldsymbol x_{a1} = \boldsymbol\eta$, $\boldsymbol x_{a2} = \boldsymbol\Omega$, $\boldsymbol x_{a3} = \boldsymbol d_{l\tau}$ là **mô-men**:
  $$\dot{\boldsymbol z}_{a1} = \boldsymbol z_{a2} + \boldsymbol K_{a1}\boldsymbol e_{a1},\ \ \dot{\boldsymbol z}_{a2} = \hat{\boldsymbol M}^{-1}\big(\boldsymbol\tau - \hat{\boldsymbol C}\boldsymbol z_{a2} + \boldsymbol z_{a3}\big) + \boldsymbol K_{a2}\boldsymbol e_{a1},\ \ \dot{\boldsymbol z}_{a3} = \boldsymbol K_{a3}\boldsymbol e_{a1} \quad (20)$$
  $$\boldsymbol W_{9\times9} = \begin{bmatrix} -\boldsymbol K_{a1} & \boldsymbol I_{3\times3} & \boldsymbol I_{3\times3} \\ -\boldsymbol K_{a2} & -\boldsymbol M_0^{-1}\boldsymbol C_0 & \boldsymbol M_0^{-1} \\ -\boldsymbol K_{a3} & \boldsymbol 0_{3\times3} & \boldsymbol 0_{3\times3}\end{bmatrix} \quad (30)$$
  Ô (1,3) được in là $\boldsymbol I_{3\times3}$ (đã phóng to để đọc). Theo (20) thì ô này phải là $\boldsymbol 0$, nên có lẽ đó là lỗi in.
- Dạng trong code: $\boldsymbol z_{a3}$ được **chuẩn hoá** thành gia tốc góc ($\boldsymbol M^{-1}\boldsymbol d_{l\tau}$) và đưa ra ngoài $\hat{\boldsymbol M}^{-1}$.
  `simulink_blocks/eso_att_derivative.m:18`
  $$\dot{\boldsymbol z}_{a2} = \hat{\boldsymbol M}(\boldsymbol z_{a1})^{-1}\big(\boldsymbol\tau - \hat{\boldsymbol C}\boldsymbol z_{a2}\big) + \boldsymbol z_{a3} + \boldsymbol K_{a2}\boldsymbol e_{a1}$$
  ```matlab
  ea1 = eta - za1;
  Mhat = M_of_eta(za1, Ixx, Iyy, Izz);
  Chat = C_of_eta(za1, za2, Ixx, Iyy, Izz);
  za_dot = [za2 + Ka1*ea1;
            Mhat\(tau - Chat*za2) + za3 + Ka2*ea1;
            Ka3*ea1];
  ```
- Gain / tham số: $\boldsymbol K_a = [\boldsymbol K_{a1}, \boldsymbol K_{a2}, \boldsymbol K_{a3}]$, mỗi khối là 50, 833, 3906 × I₃ (A.2, tr. 10).
  $\boldsymbol\tau$ ↔ tag `tau_act` (mô-men sau phân bổ, trước trễ động cơ).
- Khác biệt: **bài tự mâu thuẫn, nên code chọn cách đọc chạy được.** Lấy $\boldsymbol C_0 = 0$, $\boldsymbol M_0 = \mathrm{diag}(I)$ và gain
  A.2, rồi tính trị riêng lớn nhất của W mỗi trục:
  - W như in, ô (1,3) = $\boldsymbol I$: Re lớn nhất bằng +8.36, +11.79, +1.77 ($I$ = 0.01, 0.0082, 0.0148);
  - W khớp (20), ô (1,3) = 0: đa thức là $s^3 + 50s^2 + 833s + 3906/I_{ii}$. Tiêu chuẩn Routh cho $50\cdot833 - 3906/I_{ii}$
    bằng −348 950, −434 691, −222 269, và Re lớn nhất bằng +19.7, +22.3, +15.2.

  Cả hai cách đều **không ổn định**, trái với Theorem 2 (tr. 6). Code đọc $\boldsymbol z_{a3}$ theo đơn vị gia tốc góc. Khi đó đa
  thức là $s^3 + 50s^2 + 833s + 3906$, nghiệm $-21.15 \pm 7.74j$ và $-7.70$, ổn định. Mô-men được đổi lại ở E12. Lý do:
  không có cách đọc nguyên văn nào vừa theo (20) vừa ổn định với gain in trong bài. Nhiễu mô-men ngoài bằng 0 trong mọi
  lần chạy, nên ESO này chỉ bù sai số mô hình.
- Đối chiếu: **KHÁC, có lý do** (bài không tự nhất quán). Cần khai báo trong bài của ta.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E11. M(η) và C(η, η̇)
- Số phương trình / trang trong bài: **(5) và phần khai triển của M, C, tr. 3** (bài dẫn Raffo et al. 2010, Automatica
  46(1), 29–39).
- Dạng theo bài (LaTeX):
  $$\boldsymbol M(\boldsymbol\eta)\ddot{\boldsymbol\eta} + \boldsymbol C(\boldsymbol\eta,\dot{\boldsymbol\eta})\dot{\boldsymbol\eta} = \boldsymbol\tau + \boldsymbol d_\tau \quad (5)$$
  $$\boldsymbol M = \begin{bmatrix} I_{xx} & 0 & -I_{xx}s_\theta \\ 0 & I_{yy}c_\phi^2 + I_{zz}s_\phi^2 & (I_{yy}-I_{zz})c_\phi s_\phi c_\theta \\ -I_{xx}s_\theta & (I_{yy}-I_{zz})c_\phi s_\phi c_\theta & I_{xx}s_\theta^2 + (I_{yy}s_\phi^2 + I_{zz}c_\phi^2)c_\theta^2 \end{bmatrix}$$
  $c_{11} = 0$;
  $c_{12} = (I_{yy}-I_{zz})(\dot\theta c_\phi s_\phi + \dot\psi s_\phi^2 c_\theta) - (I_{xx} + I_{yy}c_\phi^2 - I_{zz}c_\phi^2)\dot\psi c_\theta$;
  $c_{13} = (I_{zz}-I_{yy})\dot\psi c_\phi s_\phi c_\theta^2$;
  $c_{21} = (I_{zz}-I_{yy})(\dot\theta c_\phi s_\phi + \dot\psi s_\phi^2 c_\theta) + (I_{xx} + I_{yy}c_\phi^2 - I_{zz}c_\phi^2)\dot\psi c_\theta$;
  $c_{22} = (I_{zz}-I_{yy})\dot\phi c_\phi s_\phi$;
  $c_{23} = (-I_{xx} + I_{yy}s_\phi^2 + I_{zz}c_\phi^2)\dot\psi s_\theta c_\theta$;
  $c_{31} = (I_{yy}-I_{zz})\dot\psi c_\theta^2 s_\phi c_\phi - I_{xx}\dot\theta c_\theta$;
  $c_{32} = (I_{zz}-I_{yy})(\dot\theta c_\phi s_\phi s_\theta + \dot\phi s_\phi^2 c_\theta - \dot\phi c_\phi^2 c_\theta) + (I_{xx} - I_{yy}s_\phi^2 - I_{zz}c_\phi^2)\dot\psi s_\theta c_\theta$;
  $c_{33} = (I_{yy}-I_{zz})\dot\phi c_\phi s_\phi c_\theta^2 + (I_{xx} - I_{yy}s_\phi^2 - I_{zz}c_\phi^2)\dot\theta c_\theta s_\theta$.
- Dạng trong code: giống hệt từng phần tử, 9/9 với C và 6/6 với M (M đối xứng: 6 phần tử độc lập).
  - **M** có ở ba file, giống hệt nhau: `simulink_blocks/eso_att_derivative.m:27–34` (ESO tư thế, tại $\boldsymbol z_{a1}$),
    `simulink_blocks/rotational_dynamics.m:13–20` (plant, chạy cả trên P2), `simulink_blocks/att_disturbance_output.m:10–12`
    (đổi $\boldsymbol z_{a3}$ sang mô-men, E12).
    ```matlab
    M = [Ixx,       0,                        -Ixx*sth;
         0,         Iyy*cphi^2 + Izz*sphi^2,  (Iyy-Izz)*cphi*sphi*cth;
         -Ixx*sth, (Iyy-Izz)*cphi*sphi*cth,   Ixx*sth^2 + (Iyy*sphi^2 + Izz*cphi^2)*cth^2];
    ```
  - **C** chỉ có ở **hai** file: `simulink_blocks/eso_att_derivative.m:36–55` (hàm `C_of_eta`, gọi ở `:21` với
    $(\boldsymbol z_{a1}, \boldsymbol z_{a2})$) và `simulink_blocks/rotational_dynamics.m:22–41` (gọi ở `:9` với $(\boldsymbol\eta, \dot{\boldsymbol\eta})$ thật).
    Hai hàm giống nhau từng ký tự (đã `diff`). `att_disturbance_output.m` **không có C**: nó chỉ tính $\boldsymbol M(\boldsymbol z_{a1})\boldsymbol z_{a3}$
    (`:13`). Bản ghi trước ("hai bản giống hệt … `att_disturbance_output.m:10`") chỉ đúng với M; đã sửa 2026-10-03.
    ```matlab
    % simulink_blocks/eso_att_derivative.m:41-54  (= rotational_dynamics.m:27-40)
    c11 = 0;
    c12 = (Iyy-Izz)*(thetad*cphi*sphi + psid*sphi^2*cth) ...
          - (Ixx + Iyy*cphi^2 - Izz*cphi^2)*psid*cth;
    c13 = (Izz-Iyy)*psid*cphi*sphi*cth^2;
    c21 = (Izz-Iyy)*(thetad*cphi*sphi + psid*sphi^2*cth) ...
          + (Ixx + Iyy*cphi^2 - Izz*cphi^2)*psid*cth;
    c22 = (Izz-Iyy)*phid*cphi*sphi;
    c23 = (-Ixx + Iyy*sphi^2 + Izz*cphi^2)*psid*sth*cth;
    c31 = (Iyy-Izz)*psid*cth^2*sphi*cphi - Ixx*thetad*cth;
    c32 = (Izz-Iyy)*(thetad*cphi*sphi*sth + phid*sphi^2*cth - phid*cphi^2*cth) ...
          + (Ixx - Iyy*sphi^2 - Izz*cphi^2)*psid*sth*cth;
    c33 = (Iyy-Izz)*phid*cphi*sphi*cth^2 ...
          + (Ixx - Iyy*sphi^2 - Izz*cphi^2)*thetad*cth*sth;
    C = [c11 c12 c13; c21 c22 c23; c31 c32 c33];
    ```
  - **So từng phần tử với Guo tr. 3** (dạng theo bài ở trên; `phid, thetad, psid` = $\dot\phi, \dot\theta, \dot\psi$;
    `cphi` = $c_\phi$ …). Đối chiếu bằng mắt từng số hạng, rồi kiểm lại bằng sympy (hiệu code − bài rút gọn về 0):

    | phần tử | code (`eso_att_derivative.m`) | so với bài |
    |---|---|---|
    | $c_{11}$ | `:41` | KHỚP (= 0) |
    | $c_{12}$ | `:42–43` | KHỚP |
    | $c_{13}$ | `:44` | KHỚP |
    | $c_{21}$ | `:45–46` | KHỚP |
    | $c_{22}$ | `:47` | KHỚP |
    | $c_{23}$ | `:48` | KHỚP |
    | $c_{31}$ | `:49` | KHỚP |
    | $c_{32}$ | `:50–51` | KHỚP |
    | $c_{33}$ | `:52–53` | KHỚP |

    Kết quả: **9/9 KHỚP**, cả ở `rotational_dynamics.m:27–40`. Bản `.m` trùng khối EML trong `baseline1.slx`
    (`tools/extract_eml.py baseline1.slx --check simulink_blocks`: Match 29, Differ 0, 2026-10-03).
- Gain / tham số: $I_{xx}, I_{yy}, I_{zz}$ = 0.01, 0.0082, 0.0148 kg·m² (A.1, tr. 10).
- Khác biệt: không có. Kiểm thêm bằng sympy: $M = T^\top\mathrm{diag}(I)T$; $C\dot\eta$ trùng với dạng Christoffel của $M$;
  $\dot M - 2C$ phản đối xứng (chạy lại 2026-10-03 trên chính biểu thức đọc từ code: cả hai đúng). Ghi chú: trong (5), $\boldsymbol\tau$ đứng trực tiếp; đúng chặt thì lực suy rộng theo $\boldsymbol\eta$ là
  $T^\top\boldsymbol\tau$. Code theo đúng bài, và plant với ESO dùng cùng dạng.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: sau sửa 2026-10-03: trích code C, so 9/9

### E12. Đổi ước lượng gia tốc góc sang nhiễu mô-men
- Số phương trình / trang trong bài: **không có trong bài**. Đây là hệ quả của cách đọc ở E10. Theo (19)–(20), tr. 5, bài có
  $\hat{\boldsymbol d}_{l\tau} = \boldsymbol z_{a3}$.
- Dạng theo bài (LaTeX): $\hat{\boldsymbol d}_{l\tau} = \boldsymbol z_{a3}$
- Dạng trong code: $\hat{\boldsymbol d}_{l\tau} = \boldsymbol M(\boldsymbol z_{a1})\,\boldsymbol z_{a3}$. `simulink_blocks/att_disturbance_output.m:10`
  ```matlab
  dltau_hat = M*za(7:9);
  ```
- Gain / tham số: không có.
- Khác biệt: thêm phép đổi để (18) nhận mô-men đúng như trong bài. Lý do: như E10.
- Đối chiếu: **KHÁC, có lý do**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E13. Phân bổ lực cho động cơ và bão hoà
- Số phương trình / trang trong bài: **(2), tr. 3**. Bài **không công bố** giới hạn mô-men hay lực động cơ.
- Dạng theo bài (LaTeX):
  $$\begin{bmatrix}f\\ \tau_\phi\\ \tau_\theta\\ \tau_\psi\end{bmatrix} = \begin{bmatrix} 1&1&1&1\\ -d_\phi&-d_\phi&d_\phi&d_\phi\\ d_\theta&-d_\theta&d_\theta&-d_\theta\\ c_{\tau f}&-c_{\tau f}&-c_{\tau f}&c_{\tau f}\end{bmatrix}\begin{bmatrix}f_1\\f_2\\f_3\\f_4\end{bmatrix} \quad (2)$$
- Dạng trong code: ma trận giống hệt (`core/init_MOBADC_params.m:40`). Phân bổ ngược, kẹp, rồi tính lại, ở
  `simulink_blocks/motor_allocation.m:9`
  ```matlab
  tau_c   = min(max(tau_cmd, -TAU_MAX), TAU_MAX);
  wrench  = [f_cmd; tau_c(1); tau_c(2); tau_c(3)];
  f_i_raw = Gamma_mix \ wrench;
  f_i     = min(max(f_i_raw, f_min), f_max);
  wrench_act = Gamma_mix * f_i;
  ```
- Gain / tham số: $d_\phi$ = 0.1068 m, $d_\theta$ = 0.0879 m, $c_{\tau f}$ = 0.00963 (A.1, tr. 10); `f_max` = 7.6675 N/động cơ trên
  P2 (đêm 14 D2: 5.11); `f_min` = 0; `TAU_MAX` = 0.5 N·m (giả định của ta, xem dưới).
- Khác biệt: code thêm bão hoà từng động cơ và kẹp mô-men ±0.5 N·m trước khi phân bổ, rồi tính lại lực/mô-men đã áp.
  - `TAU_MAX` = 0.5 N·m là **giả định của ta** (giới hạn vật lý; kẹp trước khi phân bổ để giữ quyền điều khiển tư thế),
    **không** lấy từ bài.
  - Sửa 2026-10-03 (đối chiếu của người dùng): bản trước ghi "±0.5 N·m đọc từ Fig. 11(b), tr. 10". Sai nguồn: Fig. 11(b)
    chỉ có **trục đồ thị** từ −0.5 tới 0.5 N·m, không phải giới hạn được công bố.
  - Chú thích trong code vẫn còn câu cũ (`simulink_blocks/motor_allocation.m:6` và `:9`, "khớp Fig. 11(b)"). Chỉ là
    chú thích, giá trị không đổi. **Chưa sửa**, vì sửa chú thích là sửa khối EML trong `baseline1.slx` (đổi MD5 của
    model và hash runner CONFIRM2). Ghi để sửa khi model được dựng lại lần sau.
  - Đã khai báo ở MANUSCRIPT §3.2 (bảng các kẹp: "choices of this work").
- Đối chiếu: **KHÁC, có lý do**. Riêng ma trận (2) thì **khớp**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: sau sửa 2026-10-03: TAU_MAX là giả định của ta

### E14. Lệnh động cơ u(f) — chỉ để ghi log
- Số phương trình / trang trong bài: **(3), tr. 3**.
- Dạng theo bài (LaTeX): $$u_i = c_{uf}\sqrt{f_i - f_b} - u_b \quad (3)$$
- Dạng trong code: giống hệt (thêm $\max(\cdot, 0)$ trong căn). `simulink_blocks/motor_allocation.m:17`
  ```matlab
  u_i = c_uf*sqrt(max(f_i - f_b, 0)) - u_b;        % pt. (3), chi de log
  ```
- Gain / tham số: $c_{uf} = 6.12\times10^{-5}$, $f_b$ = −0.2046 N, $u_b$ = 0.1922 V (A.1, tr. 10).
- Khác biệt: không có. Lượt trước tôi nghi dạng này vì với các hằng số của bài, lực treo 2.75 N cho $u \approx -0.19$ V. Bài
  in đúng như vậy, nên code khớp bài; con số lạ là của bài (đơn vị hoặc cách viết của $c_{uf}$). **Không ảnh hưởng kết
  quả:** `u_i` không có khối hay số liệu nào đọc.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E15. Tham số vật lý (Phụ lục A.1)
- Số phương trình / trang trong bài: **Appendix A.1, tr. 10**.
- Dạng theo bài: $m$ = 1.121 kg, $I_{xx}$ = 0.01, $I_{yy}$ = 0.0082, $I_{zz}$ = 0.0148 kg·m², $d_\theta$ = 0.0879 m, $d_\phi$ =
  0.1068 m, $c_{uf} = 6.12\times10^{-5}$, $f_b$ = −0.2046 N, $u_b$ = 0.1922 V, $c_{\tau f}$ = 0.00963.
- Dạng trong code: `core/init_MOBADC_params.m:32` (P2: `core/p2_params.m:13`, `m_Q`)
  ```matlab
  m   = 1.121;
  Ixx = 0.01;  Iyy = 0.0082;  Izz = 0.0148;
  d_theta = 0.0879;  d_phi = 0.1068;
  c_uf = 6.12e-5;  f_b = -0.2046;  u_b = 0.1922;  c_tauf = 0.00963;
  ```
- Gain / tham số: như trên, 10/10 giá trị trùng. $g$ = 9.81 m/s² là số của ta (bài không ghi).
- Khác biệt: không có.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E16. Gain điều khiển và gain bộ quan sát (Phụ lục A.2)
- Số phương trình / trang trong bài: **Appendix A.2, tr. 10**.
- Dạng theo bài:
  - $\boldsymbol K_\gamma$ = diag(12, 12, 35), $\boldsymbol K_v$ = diag(8, 8, 18) (dùng trong (9));
  - $\boldsymbol K_\eta$ = diag(2.16, 1.92, 0.59), $\boldsymbol K_\omega$ = diag(0.20, 0.12, 0.12) (dùng trong (18));
  - $\boldsymbol K_p$ = [50 I, 833 I, 78 I] (dùng trong (15));
  - $\boldsymbol l$ 6×6 như ở E7 (dùng trong (12));
  - $\boldsymbol K_a$ = [50 I, 833 I, 3906 I] (dùng trong (20)).
- Dạng trong code: `core/init_MOBADC_params.m:46`
  ```matlab
  Kgamma  = diag([12, 12, 35]);   Knu     = diag([8, 8, 18]);
  K_eta   = diag([2.16, 1.92, 0.59]);  K_omega = diag([0.20, 0.12, 0.12]);
  Kp1 = 50*eye(3);  Kp2 = 833*eye(3);  Kp3 = 78*eye(3);
  l_axis = [0.10 0.08 0.10];
  Ka1 = 50*eye(3);  Ka2 = 833*eye(3);  Ka3 = 3906*eye(3);
  ```
- Gain / tham số: như trên, mọi giá trị trùng.
- Khác biệt: không có về giá trị. Hệ quả ổn định: E9 ổn định; E10 chỉ ổn định ở dạng chuẩn hoá.
- Đối chiếu: **KHỚP**.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

### E17. Đơn vị của σ: Hz hay rad/s
- Số phương trình / trang trong bài: (6) tr. 3 cần $\sigma_i$ theo **rad/s**, vì $\boldsymbol A_i = [0\ \sigma_i; -\sigma_i\ 0]$. Nhưng phần thí
  nghiệm cho σ theo **Hz**:
  - Test 1 (tr. 7): "$\sigma_i$ is approximately equal to $\frac{1}{2\pi}\sqrt{g/L}$ s⁻¹";
  - Test 3 (tr. 7): "$\sigma_i$ is approximately equal to $1/T$ where $T$ is the period of a circling flight … around 1.26 m/s
    and $\sigma_i$ is approximately equal to 0.25 s⁻¹";
  - Test 4 (tr. 9): "1.26 m/s, $\sigma_i$ is approximately equal to 0.25 s⁻¹ and the radius … 0.8 m".
- Dạng theo bài (LaTeX): $\sigma_i \approx 1/T = v/(2\pi R) = 1.26/(2\pi\cdot0.8) = 0.25\ \mathrm{s}^{-1}$ (Hz)
- Dạng trong code: $\sigma = 2\pi\cdot 1/T = v/R$ = 1.575 rad/s. `core/init_MOBADC_params.m:82` (mặc định Test 2: 0.625 =
  0.5/0.8); `core/op_set.m` cho Test 3/4.
  ```matlab
  payload_sigma = 0.625;   % rad/s - Test 2 default (Test 3/4: 1.575)
  ```
- Gain / tham số: `payload_sigma` = 1.575 rad/s (circle Test 3/4); Test 2 là 0.625 rad/s (0.5 m/s, tr. 7).
- Khác biệt: **bài tự mâu thuẫn về đơn vị.** Code đổi 0.25 Hz thành 1.575 rad/s cho (6). Lý do:
  - Tải bị kéo ở tần số quỹ đạo $v/R$.
  - Công thức Test 1 của bài cũng là Hz ($\frac{1}{2\pi}\sqrt{g/L}$).
  - Nếu đặt 0.25 thẳng vào (6), nội mô hình sẽ lệch tần số quỹ đạo 6.3 lần.
- Đối chiếu: **KHÁC, có lý do** (bài không tự nhất quán). Cần khai báo trong bài của ta.
- Kiểm tra của tôi:  [x] ĐÚNG   [ ] SAI - ghi chú: ______

---

## Giải thích lệch tái lập cũ (Table S4)

**Câu hỏi.** Table S4 (SUPPLEMENTARY §S5) đặt Table 4 của bài v1 (mô phỏng, gió đo ngoài trời) cạnh Table 1 của Guo
(Test 4, tr. 9). Các lệch là: DO +77.2 %, ESO −62.7 %, Classical −2.4 %, MOBADC −7.6 %. Nguyên nhân là cài đặt, hay
điều kiện (gió, quỹ đạo, chỉ số, cửa sổ)?

**Trả lời: do điều kiện. Đã đối chiếu với bản gốc: không có lệch cài đặt nào giải thích được các chênh lệch này.**

1. **Cài đặt.** 17 phương trình và mọi gain, tham số ở trên đều khớp bài, trừ các chỗ khác có lý do.
   - E3 (dùng $c_{\theta_d}$, các kẹp), E5 (bổ sung sách giáo khoa), E13 (bão hoà): đều không đổi thứ tự DO/ESO.
   - E10: chỉ ảnh hưởng ESO tư thế. Trong mọi lần chạy không có nhiễu mô-men, và dạng nguyên văn thì không ổn định.
   - E17: dạng đọc 1.575 rad/s là cách duy nhất để nội mô hình đúng tần số quỹ đạo.
   Phần ảnh hưởng tới hàng DO và ESO vị trí là E6–E9 và E16, và phần này **khớp nguyên văn**.
2. **Chỉ số: cùng định nghĩa.**
   - Table 1 của Guo dùng $\bar\gamma = \frac1n\sum\|\boldsymbol\gamma_i - \boldsymbol\gamma_{d,i}\|$ và
     $s = \sqrt{\frac{1}{n-1}\sum(\|\boldsymbol\gamma_i - \boldsymbol\gamma_{d,i}\| - \bar\gamma)^2}$ (tr. 9).
   - Table 4 của ta (RESULTS §R3.2) dùng "Mean" = trung bình theo đoạn của sai số chuẩn trung bình trong đoạn, và "± STD"
     = trung bình theo đoạn của độ lệch chuẩn **trong** đoạn.
   - Theo từng lần bay, hai định nghĩa là một.
3. **Cửa sổ: khác.**
   - Guo bay 3 vòng ở 1.26 m/s. Mỗi vòng dài $T = 2\pi\cdot0.8/1.26 \approx 4$ s, nên cả phép đo khoảng 12 s (tr. 7, 9).
   - Ta đo 60 s cuối ($t \ge 140$ s) của 200 s mô phỏng. Cửa sổ này đặt ra vì cực chậm nhất của DO có hằng số thời gian
     28 s (E7).
   - Như vậy cửa sổ của Guo có thể chứa quá độ của DO, còn của ta thì không.
4. **Điều kiện: khác về loại.**
   - Guo bay trong phòng: gió từ hai quạt 380 W, "up to 5 m/s" (tr. 7), tải 0.5 kg với chiều dài dây không công bố.
   - Ta mô phỏng với gió đo ngoài trời (NREL M5) và con lắc vật lý L = 1 m ghép gió (K = 0.5).
5. **Cơ chế hai nhiễu giải thích chiều của cả hai lệch** (AUDIT §A3; W6_INTEGRATION §0.14).
   - DO khử tải sin nên phần còn lại là gió: $\approx$ `wind_amp`$/(mK_\gamma)$ = 0.0743·`wind_amp`.
   - ESO khử gió chậm nên phần còn lại là tải sin: $(2/\pi)(A/m)|H|$ = 0.0360·`payload_amp`.
   - Ở điều kiện phòng thí nghiệm, hàng DO khớp Guo trong 1 % (0.0732 so với 0.0725). Suy ngược thì `wind_amp` = 0.975 N,
     khớp 1 N trong 2.5 %.
   - Ngoài trời, gió biến thiên lớn và DO không có mode DC, nên DO kém thêm (+77.2 %) còn ESO bắt được gió chậm
     (−62.7 %). Chiều của cả hai lệch đúng như cấu trúc dự báo.
6. **Chỗ còn lại thuộc về bảng của Guo, không thuộc cài đặt.**
   - Trong Table 1, ESO (0.2054) **tệ hơn** Classical (0.1502) ở Test 4, trong khi ở Test 2 (chỉ có gió) ESO tốt hơn
     Classical 64 %.
   - Suy ngược biên độ tải thì hàng Classical đòi 3.66 N, hàng ESO đòi 5.71 N. Không một biên độ nào tái lập cả hai.
   - Bài tự giải thích ở Test 3 (tr. 9): "ESO only based method is not able to sufficiently mitigate the payload
     oscillating disturbance". Điều đó nói ESO không giúp; nó không giải thích vì sao ESO làm tệ hơn Classical.
7. **Hệ quả cho P2.** Bộ điều khiển trên P2 là cùng mã (E1–E17). Cột L0 trên P2 vì thế là MOBADC nguyên dạng, trừ hai chỗ
   bài tự mâu thuẫn (E10, E17) đã chọn cách đọc chạy được.
8. **Kiểm trên P2 (đêm 15, REGISTER_P2 §49.3; circle_main, 134 đoạn, gió M5, không cảm biến gió).**
   - MOBADC trùng D2 L0 trên cả 134 đoạn (lệch 0): cột "MOBADC" chạy đúng là bộ điều khiển của L0.
   - So với Classical (gộp): ESO −62.3 %, DO −8.4 %, MOBADC −77.6 %. Thứ tự **MOBADC tốt nhất, rồi ESO, DO, Classical**,
     giống điều kiện gió ngoài trời của v1 (Table 4: ESO −50.7 %, DO −10.7 %, MOBADC −77.4 % so với Classical).
   - DO gần Classical vì DO của Guo không có mode DC: trọng lượng tải không được ước lượng, Classical và DO lệch z
     trung bình +0.125 m và +0.118 m (§49.3), đúng cơ chế ở mục 5. Đây là điều kiện (gió + tải có trọng lượng), không
     phải cài đặt.

**Kết luận: không có lệch cài đặt, nên không dừng.** Có hai chỗ bài tự mâu thuẫn (E10: ESO tư thế theo (20) và (30) không
ổn định với gain A.2; E17: σ ghi bằng Hz nhưng dùng trong (6) như rad/s) và một chỗ code chọn cách viết chính xác hơn
(E3: $c_{\theta_d}$). Cả ba phải được khai báo trong bài của ta; chúng sẽ có dòng [B] trong bảng GĐ11.
