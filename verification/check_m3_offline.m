function R = check_m3_offline(varargin)
%CHECK_M3_OFFLINE  REGISTER_P2 sec 45.3, checks C2 and C3 of GD8 (iii): offline, no Simulink, no controller.
%
%   R = check_m3_offline                         % C2 on the fixed-5 segments + C3
%   R = check_m3_offline('Files', {...})          % other segments
%   R = check_m3_offline(..., 'Stop', 60)         % shorter (tests only)
%   R = check_m3_offline('OnlyC3', true)          % C3 only (no wind file needed)
%
%  C2 (fidelity): plant P2 with the UAV motion imposed (core/plant_p2_prescribed via
%     plant_p2_derivative, RK4 at 1 ms from rest) against the (iii) block code itself
%     (simulink_blocks/p2_m3_term.m, measured-acceleration input = the imposed a_Q, nominal parameters),
%     driven by the same true wind, velocity and acceleration. Two motions per segment:
%       hover  - UAV held (a_Q = v_Q = 0)
%       circle - UAV on the Test 4 reference circle (trajectory_ref, R_traj, w_traj of op_set('Test 4'))
%     e1  = RMS(|dM_xy - d_mf,xy|) / RMS(|d_mf,xy|) over t >= TStat (horizontal),
%     e1z = RMS(dM_z - d_mf,z) / RMS(d_mf,z) (vertical, reported).
%     Reading (registered): e1 <= 10 % on every segment x motion whose theta RMS <= 10 deg; larger
%     angles are reported.
%  C3 (no DC offset): constant wind, UAV held, the model with payload C_D*A x 0.7 (and each other
%     acceptance variant of sec 45.3: L, m_L +-20 %, payload C_D*A x 1.3); the steady compensation
%     offset dM(t + tau) - dM(t) at the model's own equilibrium, in closed form and by iterating the
%     block to steady state. With a DC mode in the DO (L3), r_hat -> d_mf - dM(t) exactly, so the
%     compensation error = dM(t + tau) - dM(t). Registered: 0 (|.| < 1e-9 N) in every variant.
opt = struct('Files', {{}}, 'Stop', 200, 'TStat', 140, 'TauMs', 100, 'OnlyC3', false, 'Quiet', false);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'check_m3_offline: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
setup_path();
P = p2_params('mode', 'prescribed');
Kg = diag([12, 12, 35]);  Kn = diag([8, 8, 18]);        % Guo (9) (not read in measured mode)
R = struct('c2', [], 'c3', []);
if ~opt.OnlyC3
    files = opt.Files;
    if isempty(files), files = p2_fixed5('Quiet', true); end
    evalc('evalin(''base'', ''init_MOBADC_params'')');     % op_set reads the base workspace
    C = op_set('Test 4');
    Rt = 0.8;  wt = C.w_traj;
    prm = p2_m3_prm(P, opt.TauMs / 1000, Kg, Kn, 1);
    fprintf('\n  C2 (sec 45.3): (iii) block vs plant P2, UAV motion imposed; circle R %.2f m, w %.4f rad/s (%.2f m/s)\n', ...
        Rt, wt, Rt * wt);
    fprintf('  %-26s %-7s %7s %8s %8s %8s  %s\n', 'segment', 'motion', 'th RMS', 'th max', 'e1', 'e1z', 'reading');
    c2 = struct('file', {}, 'motion', {}, 'th_rms', {}, 'th_max', {}, 'e1', {}, 'e1z', {}, 'counts', {});
    for f = 1:numel(files)
        for mo = {'hover', 'circle'}
            r = c2_one(files{f}, mo{1}, P, prm, Rt, wt, opt);
            r.counts = r.th_rms <= 10;
            c2(end + 1) = r; %#ok<AGROW>
            fprintf('  %-26s %-7s %7.2f %8.2f %7.1f%% %7.1f%%  %s\n', r.file, r.motion, r.th_rms, r.th_max, ...
                100 * r.e1, 100 * r.e1z, tern(r.counts, tern(r.e1 <= 0.10, 'ok', 'FAIL'), ...
                'reported (theta RMS > 10 deg)'));
        end
    end
    c = [c2.counts];
    pass = any(c) && all([c2(c).e1] <= 0.10);
    fprintf('  C2: %s - e1 <= 10%% on the %d segment x motion case(s) with theta RMS <= 10 deg\n', ...
        tern(pass, 'PASS', 'FAIL'), sum(c));
    R.c2 = c2;  R.c2_pass = pass;
end
R.c3 = c3_all(P, Kg, Kn, opt.TauMs / 1000);
R.c3_pass = all(abs([R.c3.off_closed]) < 1e-9) && all(abs([R.c3.off_iter]) < 1e-9);
fprintf('  C3: %s - steady compensation offset 0 in every variant (|.| < 1e-9 N)\n', tern(R.c3_pass, 'PASS', 'FAIL'));
end

function r = c2_one(fn, motion, P, prm, Rt, wt, opt)
Z = load(fn, 't_plant', 'w_plant');
tw = Z.t_plant(:);  W = Z.w_plant;  W(:, 3) = 0;
h = P.h;  n = round(opt.Stop / h) + 1;  t = (0:n - 1)' * h;
Wt = interp1(tw, W, min(max(t, tw(1)), tw(end)), 'linear');
wind = @(tt) interp1(tw, W, min(max(tt, tw(1)), tw(end)), 'linear').';
if strcmp(motion, 'hover')
    mot = @(tt) deal(zeros(3, 1), zeros(3, 1));
else
    mot = @(tt) circle(tt, Rt, wt);
end
z3 = zeros(3, 1);
x = [0; 0; -1; 0; 0; 0];                      % hanging at rest (the plant's IC)
Dp = zeros(n, 3);  Dm = zeros(n, 3);  Q = zeros(n, 3);
s = zeros(4, 1);                              % model from rest, like the Unit Delay IC
f = @(xx, tt, ww) plant_p2_derivative(xx, pack(tt, ww, mot), P);
for k = 1:n
    [aQ, vQ] = mot(t(k));
    wk = Wt(k, :).';
    [dx1, o] = f(x, t(k), wk);
    Dp(k, :) = o.d_mf.';  Q(k, :) = x(1:3).';
    [s, dMn] = p2_m3_term(s, wk, vQ, z3, z3, z3, z3, aQ, prm);
    Dm(k, :) = dMn.';
    if k == n, break; end
    wm = wind(t(k) + h / 2);  w2 = Wt(k + 1, :).';
    dx2 = f(x + h / 2 * dx1, t(k) + h / 2, wm);
    dx3 = f(x + h / 2 * dx2, t(k) + h / 2, wm);
    dx4 = f(x + h * dx3, t(k) + h, w2);
    x = x + h / 6 * (dx1 + 2 * dx2 + 2 * dx3 + dx4);
end
m = t >= opt.TStat;
rmsn = @(D) sqrt(mean(sum(D.^2, 2)));
th = acosd(max(-1, min(1, -Q(m, 3))));
r = struct('file', fn, 'motion', motion, 'th_rms', sqrt(mean(th.^2)), 'th_max', max(th), ...
    'e1', rmsn(Dm(m, 1:2) - Dp(m, 1:2)) / rmsn(Dp(m, 1:2)), ...
    'e1z', rmsn(Dm(m, 3) - Dp(m, 3)) / rmsn(Dp(m, 3)), 'counts', []);
end

function u = pack(tt, ww, mot)
[aQ, vQ] = mot(tt);
u = struct('a_Q', aQ, 'v_Q', vQ, 'w', ww);
end

function [a, v] = circle(tt, Rt, wt)
[~, v, a] = trajectory_ref(tt, Rt, wt, 0, 0, 1, zeros(4, 1));
v = v(:);  a = a(:);
end

function c3 = c3_all(P0, Kg, Kn, tau)
V = {'nominal', 1, 1, 1; 'cP070', 1, 1, 0.7; 'cP130', 1, 1, 1.3; 'L080', 0.8, 1, 1; 'L120', 1.2, 1, 1; ...
     'm080', 1, 0.8, 1; 'm120', 1, 1.2, 1};
w = [8; 3; 0];  z3 = zeros(3, 1);
fprintf('\n  C3 (sec 45.3): constant wind [%g %g] m/s, UAV held, tau_m %.0f ms; model parameters scaled, plant nominal\n', ...
    w(1), w(2), 1000 * tau);
fprintf('  %-8s %14s %14s %14s\n', 'variant', 'dM_x eq [N]', 'offset closed', 'offset iter');
c3 = struct('variant', {}, 'dM_eq', {}, 'off_closed', {}, 'off_iter', {});
for k = 1:size(V, 1)
    Pn = P0;  Pn.L = P0.L * V{k, 2};  Pn.m_L = P0.m_L * V{k, 3};  Pn.K_w = P0.K_w * V{k, 4};
    [prm, M] = p2_m3_prm(Pn, tau, Kg, Kn, 1);
    % closed form: theta_dot = 0 at equilibrium, so u = kL |w| w, s_eq = -A^-1 B [u; 0]
    u = M.kL * norm(w(1:2)) * w(1:2);
    off = zeros(2, 1);  deq = zeros(2, 1);
    for a = 1:2
        se = -M.A \ (M.B * [u(a); 0]);
        sp = M.Phi_t * se + M.Gam_t * [u(a); 0];
        off(a) = M.C * (sp(1) - se(1));  deq(a) = M.C * se(1);
    end
    % iterate the block itself to steady state (hover, constant wind)
    s = zeros(4, 1);
    for it = 1:round(200 / P0.h)
        [s, dMn, dMp] = p2_m3_term(s, w, z3, z3, z3, z3, z3, z3, prm);
    end
    oi = dMp(1:2) - dMn(1:2);
    c3(end + 1) = struct('variant', V{k, 1}, 'dM_eq', deq(1), 'off_closed', max(abs(off)), ...
        'off_iter', max(abs(oi))); %#ok<AGROW>
    fprintf('  %-8s %14.6f %14.3g %14.3g\n', V{k, 1}, deq(1), max(abs(off)), max(abs(oi)));
end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
