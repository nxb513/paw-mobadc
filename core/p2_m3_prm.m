function [prm, M] = p2_m3_prm(P, tau, Kgamma, Knu, acc_meas)
%P2_M3_PRM  Parameter vector of the (iii) block P2/P2_Core/P2/P2_M3 (REGISTER_P2 sec 45).
%
%   [prm, M] = p2_m3_prm(P, tau, Kgamma, Knu, acc_meas)
%
%  P         p2_params of the CONTROLLER's model (m_L, L, K, K_w of the run, times PredScale; zeta_s nominal)
%  tau       tau_m [s], the model's prediction horizon
%  Kgamma, Knu   Guo (9) gains of the position law (3x3, diagonal) - the block recomputes a_d from them
%  acc_meas  0 = the commanded acceleration a_c = a_d - g e3 (the registered (iii)); 1 = the accelerometer
%            ((iii-m), sec 45.2)
%
%  Linear pendulum per horizontal axis, s = [theta; theta_dot] (theta = horizontal cable component),
%  run OPEN LOOP (no correction from any payload-state estimate, sec 45.7):
%     theta_ddot = -wn^2 theta - 2 zeta_s wn theta_dot + F_wL / (m_L L) - a_c / L,   wn = sqrt(g / L)
%  inputs u = [F_wL; a_c] held over a step, exact ZOH over h (the state update) and over tau (the
%  prediction):  s(t+T) = Phi(T) s(t) + Gam(T) u,  expm([A B; 0 0] T) = [Phi Gam; 0 I].
%  Output: horizontal cable force on the UAV C theta, C = m_L g; vertical -m_L (g + a_c,z) (quasi-static).
%
%  prm (30x1) = [Phi_h(:) (4); Gam_h(:) (4); Phi_t(:) (4); Gam_t(:) (4); C; kL; L; m_L; g;
%                diag(Kgamma) (3); diag(Knu) (3); acc_meas; tau; zeta_s]
assert(tau >= 0, 'p2_m3_prm: tau must be >= 0.');
assert(isequal(Kgamma, diag(diag(Kgamma))) && isequal(Knu, diag(diag(Knu))), ...
    'p2_m3_prm: Kgamma and Knu must be diagonal (Guo (9)).');
assert(any(acc_meas == [0 1]), 'p2_m3_prm: acc_meas must be 0 (commanded) or 1 (measured).');
wn = sqrt(P.g / P.L);
A = [0 1; -wn^2, -2 * P.zeta_s * wn];
B = [0, 0; 1 / (P.m_L * P.L), -1 / P.L];
[Phi_h, Gam_h] = zoh(A, B, P.h);
[Phi_t, Gam_t] = zoh(A, B, tau);
M = struct('A', A, 'B', B, 'wn', wn, 'C', P.m_L * P.g, 'kL', P.K * P.K_w / P.U_ref, 'L', P.L, ...
    'm_L', P.m_L, 'g', P.g, 'tau', tau, 'h', P.h, 'Phi_h', Phi_h, 'Gam_h', Gam_h, 'Phi_t', Phi_t, 'Gam_t', Gam_t);
prm = [Phi_h(:); Gam_h(:); Phi_t(:); Gam_t(:); M.C; M.kL; P.L; P.m_L; P.g; ...
       diag(Kgamma); diag(Knu); acc_meas; tau; P.zeta_s];
end

function [Phi, Gam] = zoh(A, B, T)
E = expm([A, B; zeros(2, 4)] * T);
Phi = E(1:2, 1:2);  Gam = E(1:2, 3:4);
end
