function f = p2_motor_sat(f_cmd, P)
%P2_MOTOR_SAT  Per-rotor thrust limits of plant P2: 0 <= f_i <= P.f_max (7.67 N nominal).
f = min(max(f_cmd, 0), P.f_max);
end
