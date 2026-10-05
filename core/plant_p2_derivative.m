function [dx, out] = plant_p2_derivative(x, u, P)
%PLANT_P2_DERIVATIVE  Plant P2: quadrotor + 3-D rigid-cable pendulum, internal cable
%damping, quadratic drag on body and payload (MASTER_PLAN sec 2, PLANT_P2_SPEC).
%
%   [dx, out] = plant_p2_derivative(x, u, P)
%
%  Inertial frame, e3 UP, gravity -g e3. q = unit vector UAV -> payload
%  (hanging at rest: q = -e3), x_L = x_Q + L q, omega _|_ q, qdot = omega x q.
%
%  P.mode = 'free'        x = [x_Q; v_Q; q; omega]  (12x1)
%                         u.F  3x1 total rotor force in the inertial frame [N]
%                         u.w  3x1 wind velocity [m/s] (caller zeroes w(3): no vertical wind, spec sec 5)
%  P.mode = 'prescribed'  x = [q; omega]             (6x1)   UAV motion imposed (V2-V4)
%                         u.a_Q, u.v_Q  3x1, u.w 3x1
%
%  Equations (F_d internal: -F_d on the UAV, +F_d on the payload):
%     m_Q a_Q = F - m_Q g e3 + T q + F_wQ - F_d                               (2.1)
%     m_L a_L =   - m_L g e3 - T q + F_wL + F_d                               (2.2)
%     T       = mu [ q.F_wL/m_L - q.(F + F_wQ)/m_Q + L |qdot|^2 ]             (2.3)
%     omegadot = (1/L) q x [ (F_wL + F_d)/m_L - (F + F_wQ - F_d)/m_Q ]        (2.6)
%     F_d  = -c L (omega x q),  c = 2 zeta_s omega_n m_L,  omega_n = sqrt(g/L)
%     F_wQ = (K_w/U_ref) |w - v_Q| (w - v_Q),  F_wL = K (K_w/U_ref) |w - v_L| (w - v_L)
%  (1/2 rho (C_D A) = K_w/U_ref, so rho drops out.)
%
%  Drift control: the derivative is evaluated at q_hat = q/|q| and
%  omega_hat = omega - (omega.q_hat) q_hat. The state itself is not projected;
%  out.qnorm_err = ||q|-1| and out.wq = |omega.q_hat| are returned for logging
%  (numerical flag, REGISTER_P2 sec 0.4: either > 1e-6).
%
%  out: T, d_mf (= T q - F_d, cable force on the UAV), d_lf (= F_wQ), F_wQ, F_wL,
%       F_d, v_L, a_Q, slack (T <= 0), qnorm_err, wq.
%
%  Dispatcher (GD2b): the equations live in plant_p2_free / plant_p2_prescribed
%  (shared kinematics and forces: p2_cable_aero) so that the MATLAB Function block
%  p2_trans calls exactly the same code with fixed-size outputs (codegen).

if strcmp(P.mode, 'free')
    [dx, out] = plant_p2_free(x, u.F, u.w, P);
elseif strcmp(P.mode, 'prescribed')
    [dx, out] = plant_p2_prescribed(x, u.a_Q, u.v_Q, u.w, P);
else
    error('plant_p2_derivative: P.mode must be ''free'' or ''prescribed''.');
end
end
