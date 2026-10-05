function info = filter_wind_meas(fc)
%FILTER_WIND_MEAS  A CAUSAL low-pass filter on the measured wind series.
%
%   filter_wind_meas(2.0)    % cut off at 2 Hz
%   filter_wind_meas(inf)    % return the raw series
%
%  ======================================================================
%  THE FAIR CONTROL E1b WAS MISSING
%  ======================================================================
%  Preflight measured: with a dirty sensor at sigma = 0.6, PI-MoE scores
%  +0.4445 against DIRTY persistence. That sounds strong - but the baseline it
%  beats is a RAW measurement, with no filtering at all.
%
%  No real system feeds a noisy anemometer straight into a controller. It gets
%  filtered. So part of that +0.4445 is "the network can denoise" - and a
%  first-order filter can denoise too, with 1 parameter instead of 21163.
%
%  If PI-MoE only beats a RAW measurement and not a FILTERED one, then the
%  21163 parameters buy nothing again - the same conclusion already reached in
%  §0.34, in a different regime.
%
%  ======================================================================
%  WHY THIS IS A HARD CONTROL AND NOT AN EASY ONE
%  ======================================================================
%  A causal filter CANNOT remove noise without adding LAG. A first-order one
%  has a low-frequency group delay of ~1/(2*pi*fc):
%
%      fc = 0.5 Hz -> 318 ms      fc = 2 Hz -> 80 ms
%      fc = 1.0 Hz -> 159 ms      fc = 4 Hz -> 40 ms
%
%  The horizon is 150 ms. So at fc = 1 Hz the filter eats the WHOLE horizon -
%  cleaner, but late by exactly as much as was being compensated. That is a
%  genuine trade-off, and it is the reason a predictor CAN win: it is allowed
%  to denoise and look ahead at the same time.
%
%  If it does not win, the trade-off was already enough.
%
%  ======================================================================
%  SWEEPING fc AND TAKING THE BEST - TILTED TOWARDS THE BASELINE
%  ======================================================================
%  Letting the baseline pick its own best fc is deliberate: it makes the test
%  HARDER for PI-MoE, which is the direction to tilt. PI-MoE gets to re-choose
%  nothing - it has been frozen since W4.

assert(nargin >= 1, 'filter_wind_meas: a cut-off frequency fc [Hz] is required.');
assert(evalin('base','exist(''wind_meas_ts'',''var'')'), ...
    'filter_wind_meas: wind_meas_ts does not exist.');

% *** AN ERROR HAPPENED HERE, AND THIS IS THE FIX. ***
%
% This used to read:
%     if ~exist('wind_meas_raw_ts'), wind_meas_raw_ts = wind_meas_ts; end
%
% "Create it only once" sounds reasonable - it stops a repeated call filtering
% an already-filtered series. But it FROZE the FIRST segment's wind series, and
% every later segment and every later sigma level then filtered that same
% series. And because pa_configs has a branch "wind_meas_ts =
% wind_meas_raw_ts" to get back to raw, that stale series leaked into the
% UNFILTERED runs as well.
%
% The measured consequence: four different cut-off frequencies produced FOUR
% IDENTICAL NUMBERS (0.0426), and the raw sigma = 1.0 level produced the same
% number again. It cost 45 minutes.
%
% The CALLER is responsible for setting wind_meas_raw_ts per segment.
% pa_configs does that immediately after wind_sim_load. This function only
% READS it.
assert(evalin('base','exist(''wind_meas_raw_ts'',''var'')'), ...
    ['filter_wind_meas: wind_meas_raw_ts does not exist. The caller must set ' ...
     'it for EVERY segment, immediately after wind_sim_load - otherwise every ' ...
     'segment is filtered on the first segment''s series.']);
w = evalin('base','wind_meas_raw_ts');
v = w.signals.values;
t = w.time;

if ~isfinite(fc)
    assignin('base','wind_meas_ts', w);
    info = struct('fc', inf, 'a', 0, 'delay_ms', 0, 'rms_in', rms3(v), ...
                  'rms_out', rms3(v));
    return;
end

dt = median(diff(t));
assert(dt > 0, 'filter_wind_meas: the timestamps are not increasing.');
assert(fc < 0.5/dt, ...
    'filter_wind_meas: fc = %g Hz exceeds the sensor grid''s Nyquist of %g Hz.', ...
    fc, 0.5/dt);

% A discrete first-order CAUSAL filter: y[k] = a*y[k-1] + (1-a)*x[k].
% Not filtfilt: that is non-causal, and a non-causal filter on the sensor path
% is seeing the future - precisely the thing this whole paper is measuring.
a = exp(-2*pi*fc*dt);
y = filter(1-a, [1 -a], v, [], 1);
% Initialisation: filter() assumes zero state, which creates a transient at the
% start. The statistics window begins at t = 140 s so it has long since decayed,
% but setting the initial condition correctly is cheaper than explaining it
% later.
y(1,:) = v(1,:);
for k = 2:size(v,1)
    y(k,:) = a*y(k-1,:) + (1-a)*v(k,:);
end

wf = w;  wf.signals.values = y;
assignin('base','wind_meas_ts', wf);
info = struct('fc', fc, 'a', a, 'delay_ms', 1000/(2*pi*fc), ...
              'rms_in', rms3(v - mean(v,1)), 'rms_out', rms3(y - mean(y,1)));
end

function r = rms3(v)
r = sqrt(mean(sum(v.^2, 2)/3));
end
