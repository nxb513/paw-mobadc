function [dx, out] = plant_p2_free(x, F, w, P)
%PLANT_P2_FREE  Plant P2, free (closed-loop) mode: x = [x_Q; v_Q; q; omega] (12x1).
%#codegen
%
%   [dx, out] = plant_p2_free(x, F, w, P)
%     F  3x1 total rotor force, inertial frame [N];  w  3x1 wind [m/s]
%  Equations (2.1)-(2.6) of MASTER_PLAN sec 2; header of plant_p2_derivative.
%  Called by plant_p2_derivative (Octave/MATLAB tests) and by the MATLAB Function
%  block p2_trans (Simulink) - one implementation for both.

e3 = [0; 0; 1];
mQ = P.m_Q;  mL = P.m_L;  L = P.L;  g = P.g;
vQ = x(4:6);  q = x(7:9);  om = x(10:12);
[qh, omh, qd, vL, FwQ, FwL, Fd, nq] = p2_cable_aero(vQ, q, om, w, P); %#ok<ASGLU>

mu  = mQ * mL / (mQ + mL);
T   = mu * (qh.' * FwL / mL - qh.' * (F + FwQ) / mQ + L * (qd.' * qd));
aQ  = (F + T * qh + FwQ - Fd) / mQ - g * e3;
omd = (1 / L) * cross(qh, (FwL + Fd) / mL - (F + FwQ - Fd) / mQ);
dx  = [vQ; aQ; qd; omd];

out = struct('T', T, 'd_mf', T * qh - Fd, 'd_lf', FwQ, 'F_wQ', FwQ, 'F_wL', FwL, ...
             'F_d', Fd, 'v_L', vL, 'a_Q', aQ, 'slack', T <= 0, ...
             'qnorm_err', abs(nq - 1), 'wq', abs(om.' * qh));
end
