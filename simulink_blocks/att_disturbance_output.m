function dltau_hat = att_disturbance_output(za, Ixx, Iyy, Izz)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
dltau_hat = zeros(3,1);
% Quy doi uoc luong nhieu gia toc goc (za3) ve nhieu MOMENT cho luat (18):
%   dltau_hat = M(za1)*za3   (N.m)
phi = za(1); theta = za(2);
cphi = cos(phi); sphi = sin(phi);
cth  = cos(theta); sth = sin(theta);
M = [Ixx,       0,                        -Ixx*sth;
     0,         Iyy*cphi^2 + Izz*sphi^2,  (Iyy-Izz)*cphi*sphi*cth;
     -Ixx*sth, (Iyy-Izz)*cphi*sphi*cth,   Ixx*sth^2 + (Iyy*sphi^2 + Izz*cphi^2)*cth^2];
dltau_hat = M*za(7:9);
end
