function R = check_n6_model(varargin)
%CHECK_N6_MODEL  N6-M0 (REGISTER_P2 sec 14.4): the linear pendulum model of N6 against the
%full plant P2 with the UAV motion imposed (hover: UAV held, a_Q = v_Q = 0). Offline, no
%Simulink, no controller.
%
%   R = check_n6_model('TauMs', tw)                 % A4 fixed-5 + the 3 highest-U N6_hover segments
%   R = check_n6_model('TauMs', tw, 'Files', {...}) % other segments
%   R = check_n6_model(..., 'Stop', 60)             % shorter (tests only)
%
%  Per segment, t >= TStat (140 s):
%   (a) fidelity: the linear model driven by the true wind from rest (its own v_L), exact ZOH
%       at 1 ms, vs the plant's horizontal cable force on the UAV d_h = (T q - F_d)_xy:
%          e1 = RMS(|d_model - d_h|) / RMS(|d_h|)
%   (b) prediction tau ahead (the O_6 situation: true state at t, true wind w(t + tau) held):
%          e2 = RMS(|d_pred(t+tau|t) - d_h(t+tau)|) / RMS(|d_h(t+tau) - d_h(t)|)
%       (< 1: better than "no change"), and e2abs = the same error / RMS(|d_h|).
%   Angle: theta = acos(-q_z) (cable from vertical) - RMS and max in the window.
%  Registered reading (sec 14.4): N6-M0 PASSES iff e1 <= 10 % on every checked segment whose
%  theta RMS <= 10 deg; larger angles and (b) are reported. FAIL -> N6 does not run; report.
opt = struct('TauMs', [], 'Files', {{}}, 'Stop', 200, 'TStat', 140, 'NHigh', 3, 'Quiet', false);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'check_n6_model: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
assert(~isempty(opt.TauMs), 'check_n6_model: TauMs (tau_w* from N0W) must be given explicitly.');
setup_path();
files = opt.Files;
if isempty(files)
    files = p2_fixed5('Quiet', true);
    S = p2_segset('N6_hover', 'CapPerDay', 4, 'Quiet', true);
    [~, o] = sort(S.U, 'descend');
    hi = S.files(o(1:min(opt.NHigh, end)));
    files = [files(:); hi(:)];
    fprintf('  N6_hover (cap 4): %d segments, sha256 %s; highest-U checked: %s\n', S.n_seg, S.sha256, ...
        strjoin(hi(:)', ' '));
end
P = p2_params('mode', 'prescribed');
M = pend_lin_model(P, opt.TauMs / 1000);
fprintf('  linear model: wn %.3f rad/s, zeta_s %.2f, K %.2f, L %.1f, m_L %.2f, tau %.0f ms\n', M.wn, ...
    P.zeta_s, P.K, P.L, P.m_L, opt.TauMs);
fprintf('  %-26s %7s %7s %8s %8s %8s %8s  %s\n', 'segment', 'U', 'th RMS', 'th max', 'e1', 'e2', 'e2abs', 'reading');
R = struct('file', {}, 'U', {}, 'th_rms', {}, 'th_max', {}, 'e1', {}, 'e2', {}, 'e2abs', {}, 'counts', {});
for f = 1:numel(files)
    r = one_segment(files{f}, P, M, opt);
    r.counts = r.th_rms <= 10;
    R(end + 1) = r; %#ok<AGROW>
    fprintf('  %-26s %7.2f %7.2f %8.2f %7.1f%% %7.1f%% %7.1f%%  %s\n', r.file, r.U, r.th_rms, r.th_max, ...
        100 * r.e1, 100 * r.e2, 100 * r.e2abs, tern(r.counts, tern(r.e1 <= 0.10, 'ok', 'FAIL'), ...
        'reported (theta RMS > 10 deg)'));
end
c = [R.counts];
pass = all([R(c).e1] <= 0.10);
fprintf('\n  N6-M0 (sec 14.4): %s - e1 <= 10%% on the %d segment(s) with theta RMS <= 10 deg\n', ...
    tern(pass, 'PASS', 'FAIL'), sum(c));
if ~any(c), fprintf('  (no segment with theta RMS <= 10 deg - not decided)\n'); end
end

function r = one_segment(fn, P, M, opt)
Z = load(fn, 't_plant', 'w_plant');
tw = Z.t_plant(:);  W = Z.w_plant;  W(:, 3) = 0;
h = P.h;  n = round(opt.Stop / h) + 1;  t = (0:n - 1)' * h;
wind = @(tt) interp1(tw, W, min(max(tt, tw(1)), tw(end)), 'linear').';
Wt = interp1(tw, W, min(max(t, tw(1)), tw(end)), 'linear');     % every step, 3 columns
z3 = zeros(3, 1);
% ---- plant, prescribed hover, RK4 at 1 ms from rest ----
x = [0; 0; -1; 0; 0; 0];
Dh = zeros(n, 2);  Q = zeros(n, 3);  Qd = zeros(n, 2);  VL = zeros(n, 2);
f = @(xx, ww) plant_p2_derivative(xx, struct('a_Q', z3, 'v_Q', z3, 'w', ww), P);
for k = 1:n
    wk = Wt(k, :).';
    [dx1, o] = f(x, wk);
    Dh(k, :) = o.d_mf(1:2).';  Q(k, :) = x(1:3).';  VL(k, :) = o.v_L(1:2).';
    qd = cross(x(4:6), x(1:3));  Qd(k, :) = qd(1:2).';
    if k == n, break; end
    wm = wind(t(k) + h / 2);  w2 = Wt(k + 1, :).';
    dx2 = f(x + h / 2 * dx1, wm);
    dx3 = f(x + h / 2 * dx2, wm);
    dx4 = f(x + h * dx3, w2);
    x = x + h / 6 * (dx1 + 2 * dx2 + 2 * dx3 + dx4);
end
% ---- (a) linear model from rest, exact ZOH, u from the true wind and its own v_L ----
S = zeros(2, 2);  Dm = zeros(n, 2);
for k = 1:n
    Dm(k, :) = M.C * S(1, :);
    r = [Wt(k, 1) - M.L * S(2, 1); Wt(k, 2) - M.L * S(2, 2)];
    u = M.kL * norm(r) * r;
    for a = 1:2, S(:, a) = M.Phi_h * S(:, a) + M.Gam_h * u(a); end
end
m = t >= opt.TStat;
rmsn = @(D) sqrt(mean(sum(D.^2, 2)));
e1 = rmsn(Dm(m, :) - Dh(m, :)) / rmsn(Dh(m, :));
% ---- (b) prediction tau ahead from the true state, true wind w(t + tau) held ----
kt = round(M.tau / h);
idx = find(m & (1:n)' + kt <= n);
idx = idx(1:10:end);                                  % every 10 ms
prm = [M.Phi_tau(:); M.Gam_tau; M.C; M.kL; M.L];
E = zeros(numel(idx), 2);  Dp = zeros(numel(idx), 2);
for j = 1:numel(idx)
    k = idx(j);
    Sk = [Q(k, 1) Q(k, 2); Qd(k, 1) Qd(k, 2)];
    dp = pend_lin_predict(Sk, Wt(k + kt, :).', z3, prm);
    E(j, :) = dp(1:2).' - Dh(k + kt, :);
    Dp(j, :) = Dh(k + kt, :) - Dh(k, :);
end
th = acosd(max(-1, min(1, -Q(m, 3))));
r = struct('file', fn, 'U', norm(mean(W(tw >= opt.TStat, 1:2), 1)), 'th_rms', sqrt(mean(th.^2)), ...
    'th_max', max(th), 'e1', e1, 'e2', rmsn(E) / rmsn(Dp), 'e2abs', rmsn(E) / rmsn(Dh(m, :)), 'counts', []);
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
