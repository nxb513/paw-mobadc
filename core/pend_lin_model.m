function M = pend_lin_model(P, tau)
%PEND_LIN_MODEL  Linear pendulum about the hanging position, one horizontal axis
%(REGISTER_P2 sec 14; the core of GĐ8 (iii) "prediction by a physical pendulum model").
%
%   M = pend_lin_model(P, tau)        % P = p2_params(...), tau [s] prediction horizon
%
%  State s = [theta; theta_dot] per axis (theta = horizontal cable component q_x or q_y,
%  small angle), input u = horizontal wind force on the payload [N], UAV held (a_Q = 0):
%     theta_ddot = -wn^2 theta - 2 zeta_s wn theta_dot + u / (m_L L),   wn = sqrt(g/L)
%  Output: horizontal cable force on the UAV  d = m_L g theta.
%  Exact zero-order-hold propagation over a horizon T with u held (closed form, the matrix
%  exponential of the augmented system):  s(t+T) = Phi(T) s(t) + Gam(T) u
%     expm([A B; 0 0] T) = [Phi Gam; 0 1]
%  Returned for T = P.h (simulation step) and T = tau (prediction horizon).
wn = sqrt(P.g / P.L);
A = [0 1; -wn^2, -2 * P.zeta_s * wn];
B = [0; 1 / (P.m_L * P.L)];
M = struct('A', A, 'B', B, 'C', P.m_L * P.g, 'wn', wn, 'tau', tau, 'h', P.h, ...
    'kL', P.K * P.K_w / P.U_ref, 'L', P.L);
[M.Phi_h, M.Gam_h] = zoh(A, B, P.h);
[M.Phi_tau, M.Gam_tau] = zoh(A, B, tau);
end

function [Phi, Gam] = zoh(A, B, T)
E = expm([A, B; zeros(1, 3)] * T);
Phi = E(1:2, 1:2);  Gam = E(1:2, 3);
end
