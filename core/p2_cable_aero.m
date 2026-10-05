function [qh, omh, qd, vL, FwQ, FwL, Fd, nq] = p2_cable_aero(vQ, q, om, w, P)
%P2_CABLE_AERO  Shared kinematics and forces of plant P2 (used by plant_p2_free and
%plant_p2_prescribed; see plant_p2_derivative for the equations).
%#codegen
%
%  q_hat = q/|q|, omega_hat = omega - (omega.q_hat) q_hat, qdot = omega_hat x q_hat,
%  v_L = v_Q + L qdot, quadratic drag with relative velocity (1/2 rho C_D A = K_w/U_ref),
%  F_d = -c L (omega_hat x q_hat), c = 2 zeta_s omega_n m_L.

nq  = norm(q);
qh  = q / nq;
omh = om - (om.' * qh) * qh;
qd  = cross(omh, qh);
vL  = vQ + P.L * qd;
cQ  = P.K_w / P.U_ref;
cL  = P.K * cQ;
rQ  = w - vQ;
rL  = w - vL;
FwQ = cQ * norm(rQ) * rQ;
FwL = cL * norm(rL) * rL;
wn  = sqrt(P.g / P.L);
c   = 2 * P.zeta_s * wn * P.m_L;
Fd  = -c * P.L * cross(omh, qh);
end
