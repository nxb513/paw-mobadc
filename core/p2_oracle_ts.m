function wo_ts = p2_oracle_ts(wind_ts, tau_ms)
%P2_ORACLE_TS  Wind oracle w(t + tau) built by SHIFTING THE TIME BASE of the true wind
%(docs/REGISTER_P2.md sec 0.3.1), not by whole samples.
%
%   w_oracle_ts = p2_oracle_ts(wind_ts, tau_ms)
%
%  wind_ts is the plant's true-wind series (time/signals struct, as wind_sim_load
%  builds it). Output: the same time vector, values w(t + tau) by linear interpolation
%  (the interpolation the plant's From Workspace block uses), held at the last value
%  beyond the end - the same end rule as core/wind_sim_load.m (repeat the last sample).
%  tau_ms = 0 returns the true wind itself (O(0)). When tau is a whole number of samples
%  the index is shifted instead (exact: equals wind_sim_load's whole-sample shift, B4);
%  otherwise linear interpolation between samples.

t = wind_ts.time(:);
W = reshape(wind_ts.signals.values, numel(t), []);
dt = (t(end) - t(1)) / (numel(t) - 1);                 % uniform sample spacing
assert(max(abs(diff(t) - dt)) < 1e-9, 'p2_oracle_ts: the wind time base is not uniform.');
r = tau_ms * 1e-3 / dt;
if abs(r - round(r)) < 1e-9
    % tau is a whole number of samples: shift the index (exact; at the checkpoint
    % horizon this is wind_sim_load's own construction, bit for bit)
    kk = round(r);
    Wo = W([1 + kk:end, repmat(size(W, 1), 1, kk)], :);
else
    tq = min(t + tau_ms * 1e-3, t(end));
    Wo = interp1(t, W, tq, 'linear');
end
wo_ts = struct('time', wind_ts.time, 'signals', struct('values', Wo, 'dimensions', size(W, 2)));
end
