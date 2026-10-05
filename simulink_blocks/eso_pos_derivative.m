function zp_dot = eso_pos_derivative(gamma, zp, F, dmf_hat, Kp1, Kp2, Kp3, m, g)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
zp_dot = zeros(9,1);
% ESO vong vi tri, pt. (14)-(15) Guo 2020. Trang thai zp = [zp1;zp2;zp3]:
%   zp1_dot = zp2 + Kp1*ep1
%   zp2_dot = (1/m)*(F - m*g*e3 + zp3 + dmf_hat) + Kp2*ep1
%   zp3_dot = Kp3*ep1,     ep1 = gamma - zp1
% dlf_hat = zp3 (uoc luong nhieu gio/derivative-bounded).
zp1 = zp(1:3); zp2 = zp(4:6); zp3 = zp(7:9);
ep1 = gamma - zp1;
zp1_dot = zp2 + Kp1*ep1;
zp2_dot = (1/m)*(F - m*g*[0;0;1] + zp3 + dmf_hat) + Kp2*ep1;
zp3_dot = Kp3*ep1;
zp_dot  = [zp1_dot; zp2_dot; zp3_dot];
% (dlf_hat = zp3 duoc lay o khoi ESO_Out rieng - pha algebraic loop)
end
