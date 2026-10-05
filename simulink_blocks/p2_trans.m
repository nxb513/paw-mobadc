function [dx, gam, nu, a_Q, d_mf, d_lf, mon] = p2_trans(x, f_act, eta, w, prm)
%#codegen
%P2_TRANS  MATLAB Function block P2/P2_Core/P2/P2_Trans (GD2b, plant_model = 1).
%
%  Translational dynamics of the UAV + 3-D rigid-cable pendulum of plant P2. The
%  equations are NOT written here: this block calls core/plant_p2_free.m, the same
%  code verified offline by verification/verify_plant_p2.m (GD2a, 41/41).
%
%  In   x      12x1 state [x_Q; v_Q; q; omega] (Integrator P2_x, IC p2_x0)
%       f_act  total thrust AFTER the motor lag [N] (Gamma_mix * f, row 1)
%       eta    TRUE Euler angles (tag eta, Int_eta)
%       w      3x1 true wind [m/s]; the vertical component is dropped here (spec sec 5)
%       prm    [m_Q; m_L; L; g; zeta_s; K; K_w; U_ref]   (p2_prm, core/p2_setup.m)
%  Out  dx     12x1 state derivative
%       gam, nu, a_Q   true position, velocity, acceleration of the UAV
%       d_mf   T q - F_d  (cable force on the UAV, for logging)
%       d_lf   F_wQ       (wind force on the body, for logging)
%       mon    [T; slack; ||q|-1|; |omega.q|; theta]  (REGISTER_P2 sec 0.4 flags)

% Output sizes declared first (as every v1 block does, e.g. xp_dot = zeros(4,1)):
% the block sits in a loop with Integrator P2_x, and Simulink must know the output
% sizes before it knows the input sizes (GD2b, second build attempt).
dx   = zeros(12, 1);
gam  = zeros(3, 1);
nu   = zeros(3, 1);
a_Q  = zeros(3, 1);
d_mf = zeros(3, 1);
d_lf = zeros(3, 1);
mon  = zeros(5, 1);

P = struct('mode', 'free', 'g', prm(4), 'm_Q', prm(1), 'm_L', prm(2), 'L', prm(3), ...
           'zeta_s', prm(5), 'K', prm(6), 'K_w', prm(7), 'U_ref', prm(8));
F = force_from_attitude(f_act, eta);
[dx, o] = plant_p2_free(x, F, [w(1); w(2); 0], P);
gam  = x(1:3);
nu   = x(4:6);
a_Q  = dx(4:6);
d_mf = o.d_mf;
d_lf = o.d_lf;
qh   = x(7:9) / norm(x(7:9));
mon  = [o.T; double(o.slack); o.qnorm_err; o.wq; acos(max(min(-qh(3), 1), -1))];
end
