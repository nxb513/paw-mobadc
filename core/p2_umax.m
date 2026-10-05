function [U, binds] = p2_umax(K, m_p, a_traj)
%P2_UMAX  Upper wind speed of the P2 envelope (REGISTER_P2 sec 0.10, amendment A2 sec 4.4).
%
%   U = p2_umax(K, m_p)            % static (sec 0.10): hover
%   U = p2_umax(K, m_p, a_traj)    % A2: + m_tot * a_traj in phase with the wind force
%
%  tilt = atan((F_h + m_tot a)/W) <= 0.8*30 deg,  sqrt((F_h + m_tot a)^2 + W^2) <= 0.8*F_TOT_MAX,
%  F_h(U) = K_w U^2/U_ref (1 + K). The same arithmetic as python/p2_envelope.py (nominal
%  plant, F_TOT_MAX = 0.9 * 30.67 N); a_traj per trajectory: circle 0.8*1.575^2.
if nargin < 3, a_traj = 0; end
P = p2_params();
W = (P.m_Q + m_p) * P.g;
f_tilt = tan(0.8 * 30 * pi / 180) * W;
t_lim = 0.8 * P.F_TOT_MAX;
if t_lim <= W, U = 0; binds = 'thrust'; return; end
f_thr = sqrt(t_lim^2 - W^2);
if f_tilt <= f_thr, binds = 'tilt'; else, binds = 'thrust'; end
f_h = min(f_tilt, f_thr) - (P.m_Q + m_p) * a_traj;
if f_h <= 0, U = 0; return; end
U = sqrt(f_h * P.U_ref / (P.K_w * (1 + K)));
end
