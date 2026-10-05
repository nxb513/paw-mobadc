function eta_ddot = rotational_dynamics(tau_act, d_ltau, eta, eta_dot, Ixx, Iyy, Izz)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
eta_ddot = zeros(3,1);
% Dong luc hoc quay, pt. (5)/(7) Guo 2020 (Lagrange-Euler, toa do eta):
%   M(eta)*eta_ddot + C(eta,eta_dot)*eta_dot = tau + d_ltau
% M, C nguyen van trang 3 bai bao (Raffo et al. 2010).
M = M_of_eta(eta, Ixx, Iyy, Izz);
C = C_of_eta(eta, eta_dot, Ixx, Iyy, Izz);
eta_ddot = M \ (tau_act + d_ltau - C*eta_dot);
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
