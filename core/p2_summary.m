function S = p2_summary(mon, flog, TStat, f_max, eta_d)
%P2_SUMMARY  End-of-run flags and extremes of one plant-P2 run (GD2b).
%
%   S = p2_summary(mon, flog, TStat, f_max)
%   S = p2_summary(mon, flog, TStat, f_max, eta_d)
%     mon, flog: p2_mon_log and p2_f_log as read by pa_configs' pa_raw_log (.t, .v, .ok)
%     eta_d    : eta_d_log (the attitude reference AFTER the tilt clamp of
%                thrust_attitude_ref) -> tilt_sat_frac, the fraction of time the command
%                sits at the 30 deg per-axis clamp (REGISTER_P2 sec 4.1 (c)); NaN without it
%
%  From p2_mon_log = [T; slack; ||q|-1|; |omega.q|; theta] at every solver step and
%  p2_f_log (the 4 lagged motor thrusts, decimated). REGISTER_P2 sec 0.4:
%    physical divergence = T <= 0 (slack) here; solver stops / non-finite states
%                          are caught by pa_configs (crash) - both leave the pool;
%    numerical flag      = max||q|-1| > 1e-6 or max|omega.q| > 1e-6.

assert(mon.ok && flog.ok, 'p2_summary: P2 logs missing (%s / %s).', mon.why, flog.why);
t = mon.t(:);
v = mon.v;
T = v(:, 1);  sl = v(:, 2) > 0.5;  qn = v(:, 3);  wq = v(:, 4);  th = v(:, 5);
num = (qn > 1e-6) | (wq > 1e-6);
S = struct();
S.T_min        = min(T);
S.n_slack      = sum(sl);
S.t_first_slack = first_time(t, sl);
S.max_qnorm    = max(qn);
S.max_wq       = max(wq);
S.theta_max_deg = rad2deg(max(th));
S.phys_div     = any(sl) || any(~isfinite(v(:)));
S.num_flag     = any(num);
S.t_first_num  = first_time(t, num);
st = t >= TStat;
S.theta_max_stat_deg = rad2deg(max(th(st)));
S.theta_rms_stat_deg = rad2deg(sqrt(mean(th(st).^2)));   % payload swing (N6, REGISTER_P2 sec 15.4)

tf = flog.t(:);
fv = flog.v;
sat = any(fv <= 1e-9 | fv >= f_max - 1e-9, 2);
S.sat_frac      = mean(sat);
S.sat_frac_stat = mean(sat(tf >= TStat));
S.f_max_used    = f_max;

% tilt clamp: thrust_attitude_ref clamps |phi_d| and |theta_d| to TILT_MAX = 30 deg each
TILT_MAX = 30*pi/180;
S.tilt_sat_frac = NaN;  S.tilt_sat_frac_stat = NaN;
if nargin >= 5 && isstruct(eta_d) && isfield(eta_d, 'ok') && eta_d.ok
    te = eta_d.t(:);
    at = max(abs(eta_d.v(:, 1:2)), [], 2) >= TILT_MAX - 1e-9;
    S.tilt_sat_frac      = mean(at);
    S.tilt_sat_frac_stat = mean(at(te >= TStat));
end
end

function tt = first_time(t, mask)
k = find(mask, 1);
if isempty(k), tt = NaN; else, tt = t(k); end
end
