function z_dot = do_derivative(gamma, nu, z, F, dlf_hat, A_do, B_do, l_gain, G_do, g)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
z_dot = zeros(size(z));   % kich thuoc theo z: 6 trang thai (hoa 1) hoac 12 (hoa [1 3])
% Disturbance Observer, pt. (11)-(13) Guo 2020 (l chon hang so, Sec. 3.3.1):
%   p(gamma,nu) = l*[gamma; nu]                                      (11b,13)
%   xi_hat  = z + p                                                   (11a)
%   dmf_hat = B*xi_hat                                                (12)
%   z_dot   = (A - l*G*B)*z + A*p - l*(G*B*p + f(nu) + G*F + G*dlf_hat) (12)
% voi f(nu) = [nu; 0; 0; -g].
% F o day la wrench THUC da ap (F_act) - phan mem onboard biet chinh xac
% (bao hoa nam trong code, eta do duoc) -> uoc luong khong lan artifact.
% (dmf_hat = B*(z+p) duoc tinh o khoi DO_Out rieng - pha algebraic loop)
p    = l_gain*[gamma; nu];
f_nu    = [nu; 0; 0; -g];
z_dot   = (A_do - l_gain*G_do*B_do)*z + A_do*p ...
          - l_gain*(G_do*B_do*p + f_nu + G_do*F + G_do*dlf_hat);
end
