function [sat_p2, sat_rotor, u_osc] = p2_cmd_sat(fi, fact, TStat, f_max, F_TOT_MAX)
%P2_CMD_SAT  REGISTER_P2 sec 60.4: saturation and control effort on the COMMANDED rotor forces.
%
%   [sat_p2, sat_rotor, u_osc] = p2_cmd_sat(f_i_log, f_act_log, TStat, f_max, F_TOT_MAX)
%     f_i_log, f_act_log: pa_raw_log structs (.t, .v, .ok) of Motor_Allocation's f_i (after its clamp,
%     BEFORE the motor lag) and f_act (the total thrust they produce); f_max, F_TOT_MAX: the limits of the
%     plant in use (P2: 7.6675 N per rotor, 27.603 N total). Window t >= TStat.
%
%   sat_rotor = fraction of samples with any f_i <= 0 or >= f_max (the rotor saturation that makes the
%               commanded thrust differ from the applied one - INDI_FIDELITY I8)
%   sat_p2    = fraction with a rotor saturated OR f_act >= F_TOT_MAX (total-thrust limit)
%   u_osc     = sqrt(mean_t sum_i (f_i(t) - mean_t f_i)^2): RMS oscillation of the rotor forces about
%               their own mean over the window - control effort, independent of the weight carried
%  NaN where a log is missing. The v1 fields sat_frac / u_rms of pa_configs are not touched.
sat_p2 = NaN;  sat_rotor = NaN;  u_osc = NaN;
if ~(isstruct(fi) && isfield(fi, 'ok') && fi.ok), return; end
m = fi.t(:) >= TStat;
F = fi.v(m, :);
if isempty(F), return; end
rot = any(F <= 1e-9 | F >= f_max - 1e-9, 2);
sat_rotor = mean(rot);
u_osc = sqrt(mean(sum((F - mean(F, 1)).^2, 2)));
if isstruct(fact) && isfield(fact, 'ok') && fact.ok
    ma = fact.t(:) >= TStat;
    if sum(ma) == sum(m)
        sat_p2 = mean(rot | fact.v(ma) >= F_TOT_MAX - 1e-6);
    end
end
end
