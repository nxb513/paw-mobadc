function dmf_hat = do_output(gamma, nu, z, B_do, l_gain)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
dmf_hat = zeros(3,1);
% Dau ra DO, pt. (11a) + dong cuoi (12) Guo 2020:
%   xi_hat  = z + p(gamma,nu),  p = l*[gamma; nu]
%   dmf_hat = B*xi_hat
% Tach rieng khoi nay (khong nhan F) de pha algebraic loop: uoc luong chi
% phu thuoc TRANG THAI (z, gamma, nu), dung ban chat toan hoc cua DO.
dmf_hat = B_do*(z + l_gain*[gamma; nu]);
end
