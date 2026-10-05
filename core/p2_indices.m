function [q, names] = p2_indices(m)
%P2_INDICES  The per-column indices of REGISTER_P2 sec 60.4 from one pa_configs metric struct M.(cfg).
%
%   [q, names] = p2_indices(M.g_psens)      % q: 1 x 10, NaN where the run stopped or a log is missing
%
%  names: mean (the registered metric), e_rms, e_max, e_p95 (position error norm over t >= TStat);
%  u_osc (RMS oscillation of the commanded rotor forces about their own mean over t >= TStat);
%  sat_p2 (fraction of t >= TStat with a commanded rotor force at 0 or the plant's f_max, or the total
%  thrust at F_TOT_MAX - P2: 7.6675 / 27.603 N; core/p2_cmd_sat.m); tilt_sat_frac (whole run, p2_summary);
%  th_rms_deg, th_max_deg (payload swing over t >= TStat, p2_summary); sat_rotor (rotor part of sat_p2).
%  Reads stored fields only. The v1 fields sat_frac / u_rms (v1 limits, about m g / 4) are not used.
names = {'mean', 'e_rms', 'e_max', 'e_p95', 'u_osc', 'sat_p2', 'tilt_sat_frac', 'th_rms_deg', 'th_max_deg', ...
    'sat_rotor'};
q = nan(1, numel(names));
if ~isstruct(m), return; end
f = {'mean', 'e_rms', 'e_max', 'e_p95', 'u_osc', 'sat_p2'};
for k = 1:numel(f)
    if isfield(m, f{k}) && isscalar(m.(f{k})), q(k) = m.(f{k}); end
end
if isfield(m, 'p2') && isstruct(m.p2)
    g = {'tilt_sat_frac', 'theta_rms_stat_deg', 'theta_max_stat_deg'};
    for k = 1:numel(g)
        if isfield(m.p2, g{k}) && isscalar(m.p2.(g{k})), q(6 + k) = m.p2.(g{k}); end
    end
end
if isfield(m, 'sat_rotor') && isscalar(m.sat_rotor), q(10) = m.sat_rotor; end
end
