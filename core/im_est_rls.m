function R = im_est_rls(x, dt_d, n_pairs, lam)
%IM_EST_RLS  RLS fit of an AR(2*n_pairs) model to a (already decimated,
%            already anti-alias-filtered) signal x, returning the
%            tracked complex roots at every update.
%
%   R = im_est_rls(x, dt_d, n_pairs, lam)
%
%   x        Nx1, one axis, ALREADY decimated to dt_d and anti-alias
%            filtered by the caller - this function does no filtering
%            or decimation of its own, it is the pure estimation core.
%   dt_d     decimation period [s] (docs/REGISTER_C.md sec 4.34: 1.0 s)
%   n_pairs  number of complex-conjugate pairs (sec 4.34: 4)
%   lam      RLS forgetting factor (sec 4.34/4.35: 0.99, unchanged)
%
%  Port of the Python prototype (docs/REGISTER_C.md sec 4.33/4.34/4.35)
%  that found and fixed the fs oversampling problem - same equations,
%  not re-derived. Ported now because Part 3.4's real-signal test (sec
%  4.35 item 2) and the eventual Simulink wiring both need this running
%  in MATLAB; the Python version was for fast offline iteration only.
%
%  Returns R.t (Mx1), R.roots (Mx2n cell-free, complex, MxOrder), i.e.
%  the FULL root set at every update - selection/coasting/trust-gating
%  (docs/REGISTER_C.md sec 4.29 items 4a/4b, sec 4.35 item 4) is NOT
%  done here; this function is the estimation core only, kept separate
%  and independently testable, same discipline as every other function
%  this campaign has built.

order = 2*n_pairs;
N = numel(x);
theta = zeros(order,1);
P = eye(order)*1e3;
M = N - order;
troot = nan(M,1);
% COMPLEX pre-allocation, not real nan(M,order): roots(p) below returns
% complex values, and assigning a complex value into a plain real-typed
% array silently DISCARDS the imaginary part in MATLAB - it does not
% error the way it would in most other languages. Caught before this
% ever ran, not after - allocate complex from the start.
roots_all = complex(nan(M, order), nan(M, order));
for k = order+1:N
    phi = -x(k-1:-1:k-order);
    e = x(k) - phi'*theta;
    Pphi = P*phi;
    denom = lam + phi'*Pphi;
    Kk = Pphi/denom;
    theta = theta + Kk*e;
    P = (P - Kk*(Pphi'))/lam;
    idx = k - order;
    troot(idx) = (k-1)*dt_d;
    p = [1; theta];
    r = roots(p);
    r = r(:).';
    if numel(r) < order
        r = [r, nan(1, order-numel(r))]; %#ok<AGROW>
    end
    roots_all(idx, 1:numel(r)) = r;
end
R = struct('t', troot, 'roots', roots_all, 'dt_d', dt_d, 'n_pairs', n_pairs, 'lam', lam);
end
