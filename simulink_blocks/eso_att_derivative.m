function za_dot = eso_att_derivative(eta, za, tau, Ka1, Ka2, Ka3, Ixx, Iyy, Izz)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
za_dot = zeros(9,1);
% ESO vong tu the theo pt. (19)-(20) Guo 2020, cai dat DAY DU M_hat, C_hat
% tinh tu uoc luong (za1, za2) - khong luoc bo C.
% *** DANG CHUAN HOA (Remark trong paper cua ban) ***
% Neu za3 uoc luong truc tiep d_ltau (N.m) va ap nguyen gain Appendix
% Ka3 = 3906*I3, da thuc dac trung moi truc la s^3+50s^2+833s+3906/I_ii;
% voi I_xx = 0.01: 50*833 = 41650 < 390600 -> MAT on dinh (Routh).
% Bo gain Appendix khop chinh xac bandwidth parameterization (s+w0)^3
% (3w0 = 50, 3w0^2 = 833 -> w0 ~ 16.7 rad/s) => nhom tac gia tham so hoa
% theo NHIEU GIA TOC GOC. Do do:
%   za3 := uoc luong M^-1*d_ltau  (rad/s^2)
%   za2_dot = M_hat\(tau - C_hat*za2) + za3 + Ka2*ea1
% -> da thuc moi truc: s^3 + 50 s^2 + 833 s + 3906 (on dinh, dung Appendix).
% Quy doi ve moment o khoi Att_Dist_Output: dltau_hat = M(za1)*za3.
za1 = za(1:3); za2 = za(4:6); za3 = za(7:9);
ea1 = eta - za1;
Mhat = M_of_eta(za1, Ixx, Iyy, Izz);
Chat = C_of_eta(za1, za2, Ixx, Iyy, Izz);
za_dot = [za2 + Ka1*ea1;
          Mhat\(tau - Chat*za2) + za3 + Ka2*ea1;
          Ka3*ea1];
end

function M = M_of_eta(eta, Ixx, Iyy, Izz)
phi = eta(1); theta = eta(2);
cphi = cos(phi); sphi = sin(phi);
cth  = cos(theta); sth = sin(theta);
M = [Ixx,       0,                        -Ixx*sth;
     0,         Iyy*cphi^2 + Izz*sphi^2,  (Iyy-Izz)*cphi*sphi*cth;
     -Ixx*sth, (Iyy-Izz)*cphi*sphi*cth,   Ixx*sth^2 + (Iyy*sphi^2 + Izz*cphi^2)*cth^2];
end

function C = C_of_eta(eta, eta_dot, Ixx, Iyy, Izz)
phi = eta(1); theta = eta(2);
phid = eta_dot(1); thetad = eta_dot(2); psid = eta_dot(3);
cphi = cos(phi); sphi = sin(phi);
cth  = cos(theta); sth = sin(theta);
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
end
