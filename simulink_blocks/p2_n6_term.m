function [s_next, delta, mon] = p2_n6_term(s, w_meas, w_sig, vQ, dmf_do, gate, prm)
%#codegen
%P2_N6_TERM  MATLAB Function block P2/P2_Core/P2/P2_N6 (REGISTER_P2 sec 15.4, 18.2; N6).
%
%  Wind -> payload term added to the controller's payload channel (active only when
%  p2_n6 = 1; otherwise the block is not compiled). Runs at the base step h (inputs held).
%
%  In   s       4x1 observer state at t, [theta_x; theta_dot_x; theta_y; theta_dot_y]
%               (Unit Delay N6_s, IC 0)
%       w_meas  3x1 measured wind (the sensor, 50 ms late) - drives the observer in EVERY column
%       w_sig   3x1 the column's wind (as WSEL: sensor / PI-MoE / oracle) - held over the
%               horizon; the ONLY input that differs between the N6 columns
%       vQ      3x1 the controller's measured velocity nu_c
%       dmf_do  3x1 the DO's payload estimate (DO_Out, before the payload predictor)
%       gate    wind_pred_on * wvalid (as WD_gate): the term is applied only while the
%               controller uses its wind model at all
%       prm     17x1 core/p2_n6_prm.m
%  Out  s_next  4x1 state at t + h: s(k+1) = Phi_o s(k) + Gam_o [u; dmf_do_h / (m_L g)]
%       delta   3x1 added to the payload channel:
%               pend_lin_predict(s, w_sig, vQ) - m_L g theta(t)   (the predicted CHANGE of the
%               horizontal cable force over tau; the DO already carries the present force)
%       mon     5x1 [theta_x; theta_y; delta_x; delta_y; gate] (log)
s_next = zeros(4, 1);
delta  = zeros(3, 1);
mon    = zeros(5, 1);
Phi_o = reshape(prm(1:4), 2, 2);
Gam_o = reshape(prm(5:8), 2, 2);
C = prm(15);  kL = prm(16);  L = prm(17);
S = [s(1), s(3); s(2), s(4)];
% observer: u from the measured wind, relative velocity w - v_L, v_L = v_Q + L theta_dot
r = [w_meas(1) - vQ(1) - L * S(2, 1); w_meas(2) - vQ(2) - L * S(2, 2)];
u = kL * norm(r) * r;
for a = 1:2
    sa = Phi_o * S(:, a) + Gam_o * [u(a); dmf_do(a) / C];
    s_next(2 * a - 1) = sa(1);
    s_next(2 * a)     = sa(2);
end
% prediction tau ahead with the column's wind held
d_pred = pend_lin_predict(S, w_sig, vQ, prm(9:17));
if gate >= 0.5
    delta(1) = d_pred(1) - C * S(1, 1);
    delta(2) = d_pred(2) - C * S(1, 2);
end
mon = [S(1, 1); S(1, 2); delta(1); delta(2); gate];
end
