function [prm, M] = p2_n6_prm(P, tau)
%P2_N6_PRM  Parameter vector of the N6 block P2/P2_Core/P2/P2_N6 (REGISTER_P2 sec 15.4, 18.2).
%
%   [prm, M] = p2_n6_prm(P, tau)     % P = p2_params (m_L, L, K of the run), tau [s] horizon
%
%  The linear pendulum of core/pend_lin_model.m (one horizontal axis, s = [theta; theta_dot])
%  run online at the base step h as a Luenberger observer on the DO's payload estimate
%     theta_m = dmf_hat_h / (m_L g)                       (C = m_L g)
%     s_dot = A s + B u + Lc (theta_m - theta),  Lc = [4wn - 2zeta wn; 3wn^2 - 2zeta wn l1]
%  (both observer poles at -2 wn, fixed in sec 15.4), discretised exactly (ZOH over h with
%  u and theta_m held):  s(k+1) = Phi_o s(k) + Gam_o [u; theta_m].
%  prm (17x1) = [Phi_o(:); Gam_o(:); Phi_tau(:); Gam_tau; C; kL; L]  - rows 9:17 are the
%  prm of core/pend_lin_predict.m.
M = pend_lin_model(P, tau);
wn = M.wn;  z = P.zeta_s;
l1 = 4 * wn - 2 * z * wn;
l2 = 3 * wn^2 - 2 * z * wn * l1;
Lc = [l1; l2];
Ao = M.A - Lc * [1 0];
Bo = [M.B, Lc];
E = expm([Ao, Bo; zeros(2, 4)] * P.h);
M.Lc = Lc;  M.Phi_o = E(1:2, 1:2);  M.Gam_o = E(1:2, 3:4);
M.obs_poles = eig(Ao);
prm = [M.Phi_o(:); M.Gam_o(:); M.Phi_tau(:); M.Gam_tau; M.C; M.kL; M.L];
end
