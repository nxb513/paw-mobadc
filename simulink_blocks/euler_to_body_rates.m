function omega = euler_to_body_rates(eta, eta_dot)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
omega = zeros(3,1);
% omega = T(eta)*eta_dot: doi Euler rates (world) sang body rates cho (18).
phi = eta(1); theta = eta(2);
cphi = cos(phi); sphi = sin(phi);
cth  = cos(theta); sth = sin(theta);
T = [1, 0,    -sth;
     0, cphi,  sphi*cth;
     0, -sphi, cphi*cth];
omega = T*eta_dot;
end
