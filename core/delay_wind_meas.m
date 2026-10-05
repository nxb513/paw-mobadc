function info = delay_wind_meas(delay_ms)
%DELAY_WIND_MEAS  A pure transport delay on the measured wind series -
%                 shifts wind_meas_ts back by delay_ms, holding the
%                 first sample during the startup gap.
%
%   delay_wind_meas(0)      % no-op, an EXACT COPY
%   delay_wind_meas(200)    % the controller sees the wind from 200 ms ago
%
%  docs/REGISTER_ROBUST.md sec 7 (N4b) - registered before any use, part
%  of the wind-prediction-headroom-vs-condition sweep: does the wind
%  channel regain headroom when the sensor is late, as opposed to when
%  the tether/coupling change structurally (docs/REGISTER_ROBUST.md's
%  own reading rule for that block).
%
%  Operates on WHATEVER is currently in wind_meas_ts, not on
%  wind_meas_raw_ts - so it composes AFTER make_wind_meas's own
%  noise/bias and AFTER filter_wind_meas's own filtering, if either ran
%  first for this segment (the same order core/pa_configs.m already
%  calls them in). A real sensor's transport lag comes after its own
%  noise and antialiasing, not before it.

assert(nargin >= 1, 'delay_wind_meas: a delay in ms is required.');
assert(evalin('base','exist(''wind_meas_ts'',''var'')'), ...
    'delay_wind_meas: wind_meas_ts does not exist.');
w = evalin('base','wind_meas_ts');
v = w.signals.values;
t = w.time;

if delay_ms <= 0
    % An EXACT copy: every existing call (delay unset, or explicitly 0)
    % must be unchanged to the bit.
    assignin('base', 'wind_meas_ts', w);
    info = struct('delay_ms', 0, 'n_shift', 0);
    return
end

dt = median(diff(t));
assert(dt > 0, 'delay_wind_meas: the timestamps are not increasing.');
n_shift = round((delay_ms / 1000) / dt);
assert(n_shift < size(v, 1), ...
    'delay_wind_meas: delay_ms = %g exceeds the segment length.', delay_ms);

vd = v;
if n_shift > 0
    vd(n_shift+1:end, :) = v(1:end-n_shift, :);
    vd(1:n_shift, :) = repmat(v(1,:), n_shift, 1);
end

wd = w;  wd.signals.values = vd;
assignin('base', 'wind_meas_ts', wd);
info = struct('delay_ms', delay_ms, 'n_shift', n_shift);
end
