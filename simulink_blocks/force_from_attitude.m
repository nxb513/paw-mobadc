function F_act = force_from_attitude(f_act, eta)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
F_act = zeros(3,1);
% Pt. (4b) Guo 2020 - luc thuc te len khoi tam tu tong luc day f va
% GOC THUC TE eta (mat xich ghep vong tu the vao vong vi tri):
%   F = f*[c_psi*s_theta*c_phi + s_psi*s_phi;
%          s_psi*s_theta*c_phi - s_phi*c_psi;
%          c_theta*c_phi]
phi = eta(1); theta = eta(2); psi = eta(3);
cphi = cos(phi); sphi = sin(phi);
cth  = cos(theta); sth = sin(theta);
cpsi = cos(psi); spsi = sin(psi);
F_act = f_act*[cpsi*sth*cphi + spsi*sphi;
               spsi*sth*cphi - sphi*cpsi;
               cth*cphi];
end
