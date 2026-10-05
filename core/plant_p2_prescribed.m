function [dx, out] = plant_p2_prescribed(x, aQ, vQ, w, P)
%PLANT_P2_PRESCRIBED  Plant P2 with the UAV motion imposed (a_Q, v_Q given):
%x = [q; omega] (6x1). Used by the offline checks V2-V4.
%#codegen
%
%   T = m_L (-q.a_Q + L|qdot|^2 - g q.e3) + q.F_wL          (q.F_d = 0)
%   omegadot = (1/L) q x ( -g e3 - a_Q + (F_wL + F_d)/m_L )

e3 = [0; 0; 1];
mL = P.m_L;  L = P.L;  g = P.g;
q = x(1:3);  om = x(4:6);
[qh, omh, qd, vL, FwQ, FwL, Fd, nq] = p2_cable_aero(vQ, q, om, w, P); %#ok<ASGLU>

T   = mL * (-(qh.' * aQ) + L * (qd.' * qd) - g * qh(3)) + qh.' * FwL;
omd = (1 / L) * cross(qh, -g * e3 - aQ + (FwL + Fd) / mL);
dx  = [qd; omd];

out = struct('T', T, 'd_mf', T * qh - Fd, 'd_lf', FwQ, 'F_wQ', FwQ, 'F_wL', FwL, ...
             'F_d', Fd, 'v_L', vL, 'a_Q', aQ, 'slack', T <= 0, ...
             'qnorm_err', abs(nq - 1), 'wq', abs(om.' * qh));
end
