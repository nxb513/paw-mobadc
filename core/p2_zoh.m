function [y, k, idx] = p2_zoh(x, fs, h)
%P2_ZOH  Sample a signal on the solver grid at rate fs and hold it (zero-order hold).
%
%   [y, k, idx] = p2_zoh(x, fs, h)
%     x   n x m signal on the base grid t = (0:n-1)'*h
%     fs  sample rate [Hz]; 1/fs must be an integer multiple k of h (fixed-step solver)
%     y   n x m held signal: y(i,:) = x(idx_j,:) for idx_j <= i < idx_{j+1}
%     idx sample indices 1, 1+k, 1+2k, ...
%
%  Errors if 1/fs is not an integer number of steps (e.g. 120 Hz at h = 1 ms:
%  PLANT_P2_SPEC decision 4.7 -> 125 Hz).

k = round(1 / (fs * h));
assert(k >= 1 && abs(k * h - 1 / fs) <= 1e-12, ...
    'p2_zoh: 1/fs = %.6g s is not an integer multiple of h = %g s.', 1 / fs, h);
n = size(x, 1);
idx = (1:k:n).';
j = floor(((1:n).' - 1) / k) + 1;       % which sample holds at each step
y = x(idx(j), :);
end
