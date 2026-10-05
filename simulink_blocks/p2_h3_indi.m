function [s_next, d_hat] = p2_h3_indi(s, a_meas, f_cmd, eta, prm)
%#codegen
%P2_H3_INDI  MATLAB Function block P2/P2_Core/P2/P2_H3 (REGISTER_P2 sec 40.1; competitor H3).
%
%  Acceleration-based disturbance estimate of the INDI type (outer loop of Smeur 2018) - NOT a
%  full INDI controller. Runs at the attitude rate (inputs held); read by the loop only through
%  the Variant P2_CMP_Sel (p2_cmp = 1: d_mf_hat := d_hat, d_lf_hat := 0).
%
%  In   s       7x1 state at t: [T; x_x(2); x_y(2); x_z(2)] (Unit Delay H3_s, IC below)
%       a_meas  3x1 the accelerometer (inertial frame, noise and bias as nominal)
%       f_cmd   total-thrust command [N] (fthr_c)
%       eta     3x1 the MEASURED attitude (eta_c)
%       prm     11x1 core/p2_h3_prm.m
%  Out  s_next  7x1 state at t + h
%       d_hat   3x1 H(z)[m a_meas - F_thr_hat + m g e3], F_thr_hat = force_from_attitude(T, eta)
s_next = zeros(7, 1);
d_hat  = zeros(3, 1);
Phi = reshape(prm(1:4), 2, 2);
Gam = prm(5:6);
Cf  = reshape(prm(7:8), 1, 2);
aT = prm(9);  m = prm(10);  g = prm(11);
T = s(1);
F = force_from_attitude(T, eta);
u = m * a_meas - F + m * g * [0; 0; 1];
s_next(1) = aT * T + (1 - aT) * f_cmd;
for a = 1:3
    x = s(2 * a:2 * a + 1);
    d_hat(a) = Cf * x;
    s_next(2 * a:2 * a + 1) = Phi * x + Gam * u(a);
end
end
