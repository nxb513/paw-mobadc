function R = check_p2_b5_b7(varargin)
%CHECK_P2_B5_B7  GD2b checks B5, B5+, B3 (sensors), B6, B7 (docs/devlog/GD2B_DESIGN.md sec 5).
%
%   R = check_p2_b5_b7('Segment', 'wind_real_t150_i0000.mat')
%
%  Every run goes through pa_configs (the pipeline every number uses): circle
%  (Test 4), K = 0.5, DoHarm [0 1], columns L2 (g_sens) and L3 (g_psens), plant P2
%  with its nominal sensors; wind sensor: the file's own measured series (E1b,
%  sigma 0 - pa_configs forbids adding noise to it) delayed 50 ms on the MATLAB side
%  (SensorDelayMs 50). The 0.1 m/s wind-sensor noise waits for the P2 wind export
%  (GD2B_DESIGN sec 7). First run on 2026-09-25 stopped on exactly that assert.
%    run A  nominal                       -> B5 (runs, T_min > 0, drift < 1e-6, numbers)
%    run B  P2 sensor noise OFF           -> B3 exact sampling/delay, B5+ with run A
%    run C  p2_poison = 1 (NaN on v1)     -> B6: metrics identical to run A, digit for digit
%    run D  step 5e-4 s                   -> B7: |pooled(D)/pooled(A) - 1| < 0.5%
%  About 4 x 2 x 40 s of simulation.

opt = struct('Segment', 'wind_real_t150_i0000.mat');
for i = 1:2:numel(varargin), opt.(varargin{i}) = varargin{i+1}; end
setup_path();
cols = {'g_sens', 'g_psens'};  lab = {'L2', 'L3'};
logs = {'p2_gamma_c_log', 'p2_nu_c_log', 'p2_noise_pos_log', 'p2_noise_gyro_log', ...
        'p2_noise_acc_log', 'p2_Fcmd_log', 'gamma_log'};
base = {'Grid', true, 'Only', cols, 'DoHarm', [0 1], 'PayloadModel', 1, 'PayloadWind', 0.5, ...
        'Cond', 'Test 4', 'PlantModel', 'p2', 'SensorDelayMs', 50, ...
        'OnDiverge', 'flag', 'KeepLog', logs};   % logs is already a cell
run = @(varargin) pa_configs(opt.Segment, base{:}, varargin{:});

fprintf('\n=== run A (nominal P2) ===\n');
[RA, MA] = run();                                 Simulink.sdi.clear;
fprintf('\n=== run B (P2 sensor noise OFF) ===\n');
[RB, MB] = run('P2SensorNoise', false);           Simulink.sdi.clear;
fprintf('\n=== run C (POISON: NaN on every v1 plant output) ===\n');
[~, MC]  = run('P2Poison', true);                 Simulink.sdi.clear;
fprintf('\n=== run D (step 5e-4 s) ===\n');
[~, MD]  = run('Step', '5e-4');                   Simulink.sdi.clear;

R = struct('id', {}, 'what', {}, 'measured', {}, 'tol', {}, 'pass', {});
% solver stops: print every message (block, time) before anything else
runs = {'A nominal', MA; 'B noise off', MB; 'C poison', MC; 'D step 5e-4', MD};
nstop = 0;
for r = 1:size(runs, 1)
    for c = 1:2
        m = runs{r, 2}.(cols{c});
        if isfield(m, 'crashed') && m.crashed
            nstop = nstop + 1;
            fprintf('\n  SOLVER STOPPED  run %s, %s:\n    %s\n', runs{r, 1}, lab{c}, m.crash_msg);
        end
    end
end
if nstop > 0
    fprintf('\n  B5 FAIL: %d run/column pair(s) stopped the solver - B3/B5+/B6/B7 not evaluated.\n', nstop);
    R = add(R, 'B5-run', 'run/column pairs that stopped the solver (0 = none)', nstop, 0);
    return
end
P = MA.cond.p2;

%% ---- B5 ----
fprintf('\n  B5 facts: f_max used %.4f N | F_TOT_MAX %.3f N | trim: %s | seeds pos %s\n', ...
    P.vars.f_max, P.vars.F_TOT_MAX, P.trim_target, mat2str(P.vars.p2_seed_pos));
for c = 1:2
    m = MA.(cols{c});
    crashed = isfield(m, 'crashed') && m.crashed;
    R = add(R, ['B5-run-' lab{c}], sprintf('%s: solver stopped (0 = no)', lab{c}), double(crashed), 0);
    if crashed, continue; end
    s = m.p2;
    fprintf('  %s: mean err %.2f mm | T_min %.3f N | slack %d | max||q|-1| %.1e | max|w.q| %.1e | theta_max %.1f deg (stat %.1f) | sat %.4f (stat %.4f)\n', ...
        lab{c}, 1000 * m.mean, s.T_min, s.n_slack, s.max_qnorm, s.max_wq, s.theta_max_deg, ...
        s.theta_max_stat_deg, s.sat_frac, s.sat_frac_stat);
    R = add(R, ['B5-T-' lab{c}],     sprintf('%s: -T_min [N] (must be < 0, i.e. T_min > 0)', lab{c}), -s.T_min, 0);
    R = add(R, ['B5-drift-' lab{c}], sprintf('%s: max(||q|-1|, |w.q|)', lab{c}), max(s.max_qnorm, s.max_wq), 1e-6);
end

%% ---- B3 sensors (run B exact, run A statistics) ----
Lb = RB.g_psens.log;  La = RA.g_psens.log;
Ts = P.vars.p2_Ts_pos;  h = 1e-3;
gc = Lb.p2_gamma_c_log;  gt = Lb.gamma_log;
kk = round(gc.t / Ts);                          % sample index k -> t_k = k Ts
src = round((gc.t - P.vars.p2_nd_pos * Ts) / h) + 1;   % true gamma at t_k - 8 ms
okk = src >= 1;
d_exact = max(max(abs(gc.v(okk, :) - gt.v(src(okk), :))));
d_ic = max(abs(gc.v(1, :) - P.vars.p2_gamma0.'));
R = add(R, 'B3-pos', sprintf('noise off: gamma_c(t_k) = gamma(t_k - 8 ms), %d samples (ZOH 125 Hz + 1-sample delay): max|d|', ...
    numel(kk)), max(d_exact, d_ic), 0);
R = add(R, 'B3-rate', 'gamma_c samples - (Stop/8 ms + 1)', abs(numel(gc.t) - (200 / Ts + 1)), 0);
nc = Lb.p2_nu_c_log;
dv = max(max(abs(nc.v(2:end, :) - (gc.v(2:end, :) - gc.v(1:end - 1, :)) * (1 / Ts))));
R = add(R, 'B3-vel', 'noise off: nu_c = backward difference of gamma_c / 8 ms: max|d| [m/s]', dv, 1e-12);
sp = std(La.p2_noise_pos_log.v(:));  sg = std(La.p2_noise_gyro_log.v(:));  sa = std(La.p2_noise_acc_log.v(:));
R = add(R, 'B3-npos', sprintf('mocap noise std %.3e vs %.3e m: |ratio - 1|', sp, P.sigma.pos), abs(sp / P.sigma.pos - 1), 0.05);
R = add(R, 'B3-ngyr', sprintf('gyro noise std %.3e vs %.3e rad/s: |ratio - 1|', sg, P.sigma.gyro), abs(sg / P.sigma.gyro - 1), 0.05);
R = add(R, 'B3-nacc', sprintf('accel noise std %.3e vs %.3e m/s^2: |ratio - 1|', sa, P.sigma.acc), abs(sa / P.sigma.acc - 1), 0.05);

%% ---- B5+ : command-force noise from the measured-velocity noise ----
fa = RA.g_psens.log.p2_Fcmd_log;  fb = RB.g_psens.log.p2_Fcmd_log;
st = fa.t >= 140;
dF = fa.v(st, :) - fb.v(st, :);
rmsF = sqrt(mean(dF.^2, 1));
Knu = evalin('base', 'Knu');  mq = P.params.m_Q;
sv = sqrt(2) * P.sigma.pos / Ts;
fprintf('\n  B5+ RMS(Fcmd with noise - without), t >= 140 s, L3: x %.3f  y %.3f  z %.3f N\n', rmsF);
fprintf('      estimate m*K_nu*sigma_v = %.3f / %.3f / %.3f N (sigma_v = sqrt(2)*sigma_p/Ts = %.4f m/s)\n', ...
    mq * Knu(1, 1) * sv, mq * Knu(2, 2) * sv, mq * Knu(3, 3) * sv, sv);
fprintf('      (reported for GD3; not a pass/fail check)\n');

%% ---- B6 poison ----
for c = 1:2
    a = MA.(cols{c}).mean;  b = MC.(cols{c}).mean;
    R = add(R, ['B6-' lab{c}], sprintf('poison: %s mean err, run C vs run A (%.17g vs %.17g): |d|', lab{c}, b, a), abs(b - a), 0);
end

%% ---- B7 step ----
for c = 1:2
    a = MA.(cols{c}).mean;  d = MD.(cols{c}).mean;
    R = add(R, ['B7-' lab{c}], sprintf('step 5e-4 vs 1e-3: %s |pooled ratio - 1| (%.3f vs %.3f mm)', lab{c}, 1000*d, 1000*a), abs(d / a - 1), 0.005);
end

fprintf('\n  check_p2_b5_b7 (segment %s)\n', opt.Segment);
for i = 1:numel(R)
    fprintf('  %-12s %-5s %-11.3e %-9.1e %s\n', R(i).id, pf(R(i).pass), R(i).measured, R(i).tol, R(i).what);
end
fprintf('\n  %d/%d PASS\n', sum([R.pass]), numel(R));
end

function R = add(R, id, what, m, tol)
R(end + 1) = struct('id', id, 'what', what, 'measured', m, 'tol', tol, 'pass', m <= tol);
end
function s = pf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
