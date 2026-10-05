function F = position_controller(gamma_d, nu_d, acc_d, gamma, nu, dmf_hat, dlf_hat, Kgamma, Knu, m, g)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
F = zeros(3,1);
% Luat dieu khien vong vi tri, pt. (8)-(9) Guo 2020:
%   e_gamma = gamma_d - gamma;  e_nu = nu_d - nu                      (8)
%   a_d = Kgamma*e_gamma + Knu*e_nu + g*e3 + gamma_ddot_d             (9)
%   F   = m*a_d - dmf_hat - dlf_hat                                   (9)
% PID mode (Remark 9): dmf_hat = dlf_hat = 0 (qua Manual Switch).
e_gamma = gamma_d - gamma;
e_nu    = nu_d    - nu;
a_d = Kgamma*e_gamma + Knu*e_nu + g*[0;0;1] + acc_d;
F   = m*a_d - dmf_hat - dlf_hat;
end
