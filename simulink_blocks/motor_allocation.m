function [f_act, tau_act, f_i, u_i] = motor_allocation(f_cmd, tau_cmd, Gamma_mix, f_min, f_max, c_uf, f_b, u_b)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
f_act = 0; tau_act = zeros(3,1); f_i = zeros(4,1); u_i = zeros(4,1);
% Pt. (2) bai bao + bao hoa motor + kep moment lenh [MOI]:
% |tau_i| <= 0.5 N.m - dung dai lenh moment Fig. 11(b) cua bai bao.
% Kep tau TRUOC khi phan bo de giu quy luc cho moment, tranh ca 4 motor
% ket tran -> tau_act = 0 (mat dieu khien tu the).
TAU_MAX = 0.5;   % N.m [MOI - khop Fig. 11(b)]
tau_c   = min(max(tau_cmd, -TAU_MAX), TAU_MAX);
wrench  = [f_cmd; tau_c(1); tau_c(2); tau_c(3)];
f_i_raw = Gamma_mix \ wrench;                    % phan bo nguoc (2)
f_i     = min(max(f_i_raw, f_min), f_max);       % bao hoa tung motor
wrench_act = Gamma_mix * f_i;                    % tai hop luc/moment thuc
f_act   = wrench_act(1);
tau_act = wrench_act(2:4);
u_i = c_uf*sqrt(max(f_i - f_b, 0)) - u_b;        % pt. (3), chi de log
end
