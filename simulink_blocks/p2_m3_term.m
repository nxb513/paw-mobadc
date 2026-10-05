function [s_next, dM_now, dM_pred, mon] = p2_m3_term(s, w_meas, vQ, gam_d, nu_d, acc_d, gam_c, a_meas, prm)
%#codegen
%P2_M3_TERM  MATLAB Function block P2/P2_Core/P2/P2_M3 (REGISTER_P2 sec 45; GD8 (iii) FULL).
%
%  Open-loop linear pendulum model of the payload force (no correction from any payload-state
%  estimate, sec 45.7). Runs at the base step h (inputs held). Read by the loop only when p2_m3 = 1
%  (Position_Observers: P2_M3_Sel adds dM_pred to the payload channel, P2_M3_DoSel adds dM_now to the
%  DO's known-input port); with p2_m3 = 0 nothing reads it (value-neutral).
%
%  In   s       4x1 model state at t, [theta_x; theta_dot_x; theta_y; theta_dot_y] (Unit Delay M3_s, IC 0 =
%               hanging at rest, like the plant)
%       w_meas  3x1 measured wind (the sensor, 50 ms late, 20 Hz hold); vertical dropped
%       vQ      3x1 the controller's measured velocity nu_c
%       gam_d, nu_d, acc_d   3x1 the reference (trajectory_ref)
%       gam_c   3x1 the controller's measured position gamma_c
%       a_meas  3x1 the accelerometer (read only when prm(28) = 1, (iii-m))
%       prm     30x1 core/p2_m3_prm.m
%  Out  s_next  4x1 state at t + h: s(k+1) = Phi_h s(k) + Gam_h [F_wL; a_c]
%       dM_now  3x1 the model's payload force at t:  [C theta_x; C theta_y; -m_L (g + a_c,z)]
%       dM_pred 3x1 the same tau_m ahead with the inputs held (exact ZOH)
%       mon     6x1 [theta_x; theta_y; dM_pred(1:3); a_c,z] (log)
%
%  a_c = a_d - g e3 with a_d of Guo (9) recomputed from the reference and the measured state:
%     a_d = Kgamma (gamma_d - gamma_c) + Knu (nu_d - nu_c) + g e3 + acc_d
%  (no estimate enters, so no algebraic loop; p2_setup refuses M3 with the LQI law on).
s_next  = zeros(4, 1);
dM_now  = zeros(3, 1);
dM_pred = zeros(3, 1);
mon     = zeros(6, 1);
Phi_h = reshape(prm(1:4), 2, 2);    Gam_h = reshape(prm(5:8), 2, 2);
Phi_t = reshape(prm(9:12), 2, 2);   Gam_t = reshape(prm(13:16), 2, 2);
C = prm(17);  kL = prm(18);  L = prm(19);  m_L = prm(20);  g = prm(21);
Kg = prm(22:24);  Kn = prm(25:27);  acc_meas = prm(28);
if acc_meas >= 0.5
    a_c = a_meas;
else
    a_c = Kg .* (gam_d - gam_c) + Kn .* (nu_d - vQ) + acc_d;     % = a_d - g e3
end
S = [s(1), s(3); s(2), s(4)];
% wind force on the payload: relative velocity w - v_L, v_L = v_Q + L theta_dot (horizontal, small angle)
r = [w_meas(1) - vQ(1) - L * S(2, 1); w_meas(2) - vQ(2) - L * S(2, 2)];
F = kL * norm(r) * r;
for a = 1:2
    u = [F(a); a_c(a)];
    sn = Phi_h * S(:, a) + Gam_h * u;
    sp = Phi_t * S(:, a) + Gam_t * u;
    s_next(2 * a - 1) = sn(1);
    s_next(2 * a)     = sn(2);
    dM_now(a)  = C * S(1, a);
    dM_pred(a) = C * sp(1);
end
dM_now(3)  = -m_L * (g + a_c(3));
dM_pred(3) = dM_now(3);
mon = [S(1, 1); S(1, 2); dM_pred; a_c(3)];
end
