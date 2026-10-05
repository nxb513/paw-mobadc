function info = delay_pred_ts(delay_ms)
%DELAY_PRED_TS  The wind-sensor delay on the PI-MoE prediction series (REGISTER_P2 sec 13.2).
%
%   delay_pred_ts(50)     % what_ts and wvalid_ts: time base shifted by +50 ms
%
%  what_ts holds w_hat(t_k) = PI-MoE's prediction of w(t_k + 150 ms) computed from the
%  measured wind up to t_k (python/export_wind_sim.py). With a sensor delay d the
%  controller has the measured wind only up to t - d, so the prediction it can hold at t is
%  the one made at t - d: the series is shifted LATER by d. what_ts is read with
%  interpolation OFF (held, wind_sim_load), so shifting its time base is exact for any d
%  (no whole-sample restriction); [0, d) holds zero, the same "no prediction yet" value
%  wind_sim_load uses before the first prediction. wvalid_ts (0 -> 1 at t_valid_from) is
%  shifted by the same d. delay_ms <= 0: no change.

assert(evalin('base', 'exist(''what_ts'',''var'')') == 1, 'delay_pred_ts: what_ts does not exist.');
info = struct('delay_ms', 0);
if delay_ms <= 0, return; end
d = delay_ms / 1000;
w = evalin('base', 'what_ts');
t = w.time(:) + d;
v = w.signals.values;
assert(all(v(1, :) == 0), 'delay_pred_ts: what_ts does not start with the zero "no prediction" sample.');
w.time = [0; t];
w.signals.values = [zeros(1, size(v, 2)); v];
assignin('base', 'what_ts', w);
if evalin('base', 'exist(''wvalid_ts'',''var'')') == 1
    s = evalin('base', 'wvalid_ts');
    s.time = [0; s.time(2:end) + d];
    assignin('base', 'wvalid_ts', s);
end
info.delay_ms = delay_ms;
end
