function nu_dot = translational_dynamics(F_act, d_mf, d_lf, m, g)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
nu_dot = zeros(3,1);
% Dong luc hoc tinh tien, pt. (4a)/(7) Guo 2020:
%   m*nu_dot = F - m*g*e3 + d_mf + d_lf
nu_dot = (F_act - m*g*[0;0;1] + d_mf + d_lf)/m;
end
