function [y, info] = p2_sensor(x, fs, delay, N, bias, seed, h)
%P2_SENSOR  Sampled, delayed, noisy sensor on the solver grid (PLANT_P2_SPEC sec 2.5).
%
%   [y, info] = p2_sensor(x, fs, delay, N, bias, seed, h)
%     x      n x m true signal on the base grid t = (0:n-1)'*h
%     fs     sample rate [Hz] (1/fs integer multiple of h: 1 kHz, 125 Hz, 20 Hz)
%     delay  transport delay [s], integer multiple of h (0, 8 ms, 50 ms)
%     N      white-noise density [unit/sqrt(Hz)]; sigma = N*sqrt(fs/2) (Nyquist band,
%            convention of PLANT_P2_SPEC sec 2.5). Pass a struct('sigma',s) to give
%            sigma directly (mocap: 0.2 mm; wind: 0.1 m/s).
%     bias   1 x m constant offset (0 nominal)
%     seed   RNG seed for the noise (reproducible)
%
%   Sample j at step idx_j measures x(idx_j - d) + bias + sigma*n_j, d = delay/h
%   (clamped to the first sample), then held until the next sample (p2_zoh).

d = round(delay / h);
assert(abs(d * h - delay) <= 1e-12 && d >= 0, ...
    'p2_sensor: delay %.6g s is not an integer multiple of h = %g s.', delay, h);
if isstruct(N), sigma = N.sigma; else, sigma = N * sqrt(fs / 2); end
[n, m] = size(x);
src = max((1:n).' - d, 1);
xd = x(src, :);                               % delayed signal on the grid
[~, k, idx] = p2_zoh(xd, fs, h);
old = rng();
rng(seed);
noise = sigma * randn(numel(idx), m);
rng(old);
samp = xd(idx, :) + repmat(bias, numel(idx), 1) + noise;
j = floor(((1:n).' - 1) / k) + 1;
y = samp(j, :);
info = struct('k', k, 'd', d, 'sigma', sigma, 'idx', idx, 'samples', samp);
end
