function fdot = p2_motor_derivative(f, f_cmd, P)
%P2_MOTOR_DERIVATIVE  First-order motor lag per rotor (PLANT_P2_SPEC sec 2.4).
%
%   fdot = p2_motor_derivative(f, f_cmd, P)      f, f_cmd: 4x1 [N]
%
%   fdot = (sat(f_cmd) - f) * (1/tau_m),   sat = clamp to [0, P.f_max]
%  P.tau_m = 0 is not a state: use p2_motor_sat(f_cmd, P) directly instead.

assert(P.tau_m > 0, 'p2_motor_derivative: tau_m = 0 has no state; use p2_motor_sat.');
% multiply by the reciprocal, exactly as the Simulink recipe does (Gain '1/p2_tau_m'):
% GD2b B3m, user decision (b) - same arithmetic on both sides, same math.
fdot = (p2_motor_sat(f_cmd, P) - f) * (1 / P.tau_m);
end
