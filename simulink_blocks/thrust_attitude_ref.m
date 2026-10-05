function [f, eta_d] = thrust_attitude_ref(F, eta, psi_d, Fz_min, F_TOT_MAX)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
f = 0; eta_d = zeros(3,1);
% Pt. (16) Guo 2020 + 2 gioi han an toan chuan autopilot [MOI]:
%  (a) kep goc nghieng lenh |phi_d|,|theta_d| <= 30 deg
%      -> nhat quan Assumption 4 (bay goc nho)
%  (b) kep tong luc day lenh f trong [0, 21.6] N (= 0.9*4*f_max, f_max = 6 N)
% Neu khong kep: khi Fz cham day Fz_min, atan2 cho goc lenh ~90 deg ->
% UAV lat -> mat luc nang thang dung -> phan ky. Thi nghiem that cua bai
% bao cat canh + bay toi diem dau quy dao truoc nen khong gap tinh huong nay.
TILT_MAX  = 30*pi/180;   % [MOI]
% F_TOT_MAX: input since GD2b (workspace variable F_TOT_MAX). v1 default 21.6
% (= 0.9*4*f_max, f_max = 6 N; init_MOBADC_params), the same double as the old
% literal. Plant P2: 0.9 x plant max = 27.603 N (PLANT_P2_SPEC sec 2.1).
Fx = F(1); Fy = F(2); Fz = max(F(3), Fz_min);
phi = eta(1); theta = eta(2); psi = eta(3);
cpsi = cos(psi); spsi = sin(psi);
theta_d = atan2(Fx*cpsi + Fy*spsi, Fz);
phi_d   = atan2(cos(theta_d)*(Fx*spsi - Fy*cpsi), Fz);
theta_d = min(max(theta_d, -TILT_MAX), TILT_MAX);
phi_d   = min(max(phi_d,   -TILT_MAX), TILT_MAX);
cc = max(cos(theta)*cos(phi), 0.5);    % f theo dong dau (16), goc thuc te
f  = min(max(Fz/cc, 0), F_TOT_MAX);
eta_d = [phi_d; theta_d; psi_d];
end
