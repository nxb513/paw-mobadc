function [prm, M] = p2_h3_prm(P, wf_hz, m)
%P2_H3_PRM  Parameter vector of the H3 block P2/P2_Core/P2/P2_H3 (REGISTER_P2 sec 40.1).
%
%   [prm, M] = p2_h3_prm(P, wf_hz, m)   % P = p2_params (h, tau_m, g), wf_hz = filter cut-off [Hz],
%                                       % m = the CONTROLLER's mass (the position law's m)
%
%  Acceleration-based disturbance estimate of the INDI type (outer loop of Smeur 2018):
%     d_hat = H(z) [ m a_meas - F_thr_hat + m g e3 ]
%  H = 2nd-order low-pass w^2/(s^2 + 2 zeta w s + w^2), zeta = 1/sqrt(2), discretised exactly
%  (ZOH over h, input held): x(k+1) = Phi x(k) + Gam u(k), y(k) = Cf x(k) (DC gain 1).
%  Thrust estimate: first-order lag of the command, T(k+1) = aT T(k) + (1 - aT) f_cmd(k),
%  aT = exp(-h / tau_m) (the nominal motor lag, sec 40.1).
%  prm (11x1) = [Phi(:); Gam; Cf(:); aT; m; g]
w = 2 * pi * wf_hz;  z = 1 / sqrt(2);
A = [0 1; -w^2, -2 * z * w];  B = [0; w^2];  Cf = [1 0];
E = expm([A, B; zeros(1, 3)] * P.h);
Phi = E(1:2, 1:2);  Gam = E(1:2, 3);
aT = exp(-P.h / P.tau_m);
M = struct('A', A, 'B', B, 'Cf', Cf, 'Phi', Phi, 'Gam', Gam, 'aT', aT, 'wf_hz', wf_hz, 'zeta', z, 'm', m);
prm = [Phi(:); Gam; Cf(:); aT; m; P.g];
end
