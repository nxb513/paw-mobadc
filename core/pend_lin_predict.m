function [d_pred, u] = pend_lin_predict(S, w, vQ, prm)
%#codegen
%PEND_LIN_PREDICT  Horizontal cable force on the UAV predicted tau ahead by the linear
%pendulum model (core/pend_lin_model.m; REGISTER_P2 sec 14, GĐ8 (iii) core). Fixed-size,
%codegen-safe: the same code is meant for a MATLAB Function block.
%
%   [d_pred, u] = pend_lin_predict(S, w, vQ, prm)
%
%  S    2x2 state [theta_x theta_y; theta_dot_x theta_dot_y] at t (columns = axes)
%  w    3x1 wind signal (vertical dropped) - the ONLY input that differs between columns
%  vQ   3x1 UAV velocity (the controller's estimate in closed loop)
%  prm  [Phi_tau(:); Gam_tau; C; kL; L]  (4 + 2 + 3 = 9x1), from pend_lin_model
%  u    2x1 quadratic wind force on the payload, relative velocity w - v_L,
%       v_L = v_Q + L theta_dot (horizontal, small angle), held over the horizon
%  d_pred  3x1 = [C theta_x(t+tau); C theta_y(t+tau); 0]
Phi = reshape(prm(1:4), 2, 2);  Gam = prm(5:6);
C = prm(7);  kL = prm(8);  L = prm(9);
r = [w(1) - vQ(1) - L * S(2, 1); w(2) - vQ(2) - L * S(2, 2)];
u = kL * norm(r) * r;
d_pred = zeros(3, 1);
for a = 1:2
    s1 = Phi * S(:, a) + Gam * u(a);
    d_pred(a) = C * s1(1);
end
end
