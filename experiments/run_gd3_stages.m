function G = run_gd3_stages(varargin)
%RUN_GD3_STAGES  GD3 internal check, stage by stage (docs/REGISTER_P2.md sec 1).
%
%   G = run_gd3_stages()                               % i0000, stages S1 S2a S2b S3 S4
%   G = run_gd3_stages('Fixed5', true)                 % the 5 fixed segments of REGISTER_ROBUST sec 18.6
%   G = run_gd3_stages('Stages', {'S1'})               % a subset
%   G = run_gd3_stages('Fixed5', true, 'DryRun', true) % print the plan only, no simulation
%
%  Stage  motor lag      discrete  sensors (P2 noise, mocap delay, wind-sensor 50 ms)
%  S1     off            off       off
%  S2a    17 ms          off       off
%  S2b    30 ms          off       off
%  S3     30 ms          on        off
%  S4     30 ms          on        on    (= the nominal P2 of GD2b check B5)
%  S3p    17 ms          on        off   (S3' of REGISTER_P2 sec 1.3.1 = S2a + discrete)
%  S4p    17 ms          on        on    (S4' = S3' + sensors, the full P2 at 17 ms = nominal, amendment A1)
%  S4t25  25 ms          on        on    (S4 at 25 ms, REGISTER_P2 sec 3.1; not in the default list)
%  Tilt clamp (REGISTER_P2 sec 4.1): tilt_sat = command at the 30 deg clamp (p2.tilt_sat_frac),
%  tilt_ge / tilt_ge95 = actual max(|phi|,|theta|) >= 30 / 28.5 deg, whole run.
%  Circle (Test 4), K = 0.5, DoHarm [0 1], columns L2 (g_sens) and L3 (g_psens), hover trim.
%
%  Facts per stage x segment x column (sec 1.4): stable (200 s) / diverged, stop time and
%  block; dominant roll/pitch frequency and amplitude growth over the last 3 s (for a
%  diverged run, from a re-run stopped 0.5 s before the solver stop); T_min, theta_max,
%  motor saturation; mean tracking error when stable. No reading is applied here.
%  Saved to results/gd3/gd3_<stamp>.mat (summaries only) with the git hash.

opt = struct('Fixed5', false, 'Stages', {{'S1', 'S2a', 'S2b', 'S3', 'S4', 'S3p', 'S4p'}}, ...
             'Segments', {{'wind_real_t150_i0000.mat'}}, 'DryRun', false);
for i = 1:2:numel(varargin)
    % an unknown option is an error: silently adding it as a new field once turned a
    % 'DryRun' on an older copy of this file into a full 1-hour batch (2026-09-25)
    assert(isfield(opt, varargin{i}), 'run_gd3_stages: unknown option ''%s'' (known: %s).', ...
        varargin{i}, strjoin(fieldnames(opt).', ', '));
    opt.(varargin{i}) = varargin{i+1};
end
if ~opt.DryRun, setup_path(); end
if opt.Fixed5
    opt.Segments = strcat('wind_real_t150_', {'i0000', 'i0319', 'i0453', 'i0715', 'i0900'}, '.mat');
end
ST = struct( ...
    'S1',  {{'P2MotorLag', false, 'P2Discrete', false, 'P2Sensors', false}}, ...
    'S2a', {{'P2MotorLag', true,  'P2TauM', 0.017, 'P2Discrete', false, 'P2Sensors', false}}, ...
    'S2b', {{'P2MotorLag', true,  'P2TauM', 0.030, 'P2Discrete', false, 'P2Sensors', false}}, ...
    'S3',  {{'P2MotorLag', true,  'P2TauM', 0.030, 'P2Discrete', true,  'P2Sensors', false}}, ...
    'S4',  {{'P2MotorLag', true,  'P2TauM', 0.030, 'P2Discrete', true,  'P2Sensors', true, ...
             'SensorDelayMs', 50}}, ...
    'S3p', {{'P2MotorLag', true,  'P2TauM', 0.017, 'P2Discrete', true,  'P2Sensors', false}}, ...
    'S4p', {{'P2MotorLag', true,  'P2TauM', 0.017, 'P2Discrete', true,  'P2Sensors', true, ...
             'SensorDelayMs', 50}}, ...
    'S4t25', {{'P2MotorLag', true, 'P2TauM', 0.025, 'P2Discrete', true,  'P2Sensors', true, ...
             'SensorDelayMs', 50}});
bad = setdiff(opt.Stages, fieldnames(ST));
assert(isempty(bad), 'run_gd3_stages: unknown stage(s): %s', strjoin(bad, ', '));
cols = {'g_sens', 'g_psens'};  lab = {'L2', 'L3'};
logs = {'eta_log', 'p2_mon_log', 'p2_f_log', 'f_i_log'};
base = {'Grid', true, 'DoHarm', [0 1], 'PayloadModel', 1, 'PayloadWind', 0.5, 'Cond', 'Test 4', ...
        'PlantModel', 'p2', 'OnDiverge', 'flag', 'KeepLog', logs, 'Quiet', true};
[st, gh] = system('git rev-parse --short HEAD');  if st ~= 0, gh = 'unknown'; end
G = struct('git', strtrim(gh), 'stages', {opt.Stages}, 'segments', {opt.Segments}, 'rows', []);
rows = struct('stage', {}, 'segment', {}, 'col', {}, 'stable', {}, 't_stop', {}, 'block', {}, ...
              'f_phi', {}, 'f_theta', {}, 'grow_phi', {}, 'grow_theta', {}, 'T_min', {}, ...
              'theta_L_max', {}, 'sat', {}, 'mean_err_mm', {}, 'tilt_sat', {}, 'tilt_ge', {}, ...
              'tilt_ge95', {});
nCall = numel(opt.Stages) * numel(opt.Segments);
fprintf('\nGD3 stages | git %s | %d stage(s) x %d segment(s) x 2 columns = %d pa_configs calls\n', ...
    G.git, numel(opt.Stages), numel(opt.Segments), nCall);
if opt.DryRun
    fprintf('  DRY RUN - nothing is simulated. Every call: %s\n', strjoin(cellfun(@disp_arg, base, ...
        'UniformOutput', false), ' '));
    for s = 1:numel(opt.Stages)
        sw = ST.(opt.Stages{s});
        for g = 1:numel(opt.Segments)
            fprintf('  %-4s %s  Only {%s}  %s\n', opt.Stages{s}, opt.Segments{g}, strjoin(cols, ','), ...
                strjoin(cellfun(@disp_arg, sw, 'UniformOutput', false), ' '));
        end
    end
    fprintf('  + one re-run per diverged column, stopped 0.5 s before its solver stop\n');
    return
end
tAll = tic;  iCall = 0;
for s = 1:numel(opt.Stages)
    sw = ST.(opt.Stages{s});
    for g = 1:numel(opt.Segments)
        seg = opt.Segments{g};
        iCall = iCall + 1;
        fprintf('  %-4s %s ...', opt.Stages{s}, seg);
        tCall = tic;
        [R, M] = pa_configs(seg, base{:}, 'Only', cols, sw{:});
        Simulink.sdi.clear;
        fprintf(' done');
        for c = 1:2
            r = struct('stage', opt.Stages{s}, 'segment', seg, 'col', lab{c}, 'stable', true, ...
                't_stop', NaN, 'block', '', 'f_phi', NaN, 'f_theta', NaN, 'grow_phi', NaN, ...
                'grow_theta', NaN, 'T_min', NaN, 'theta_L_max', NaN, 'sat', NaN, 'mean_err_mm', NaN, ...
                'tilt_sat', NaN, 'tilt_ge', NaN, 'tilt_ge95', NaN);
            m = M.(cols{c});
            if isfield(m, 'crashed') && m.crashed
                r.stable = false;
                tk = regexp(m.crash_msg, 'at time ([0-9.eE+-]+)', 'tokens', 'once');
                bk = regexp(m.crash_msg, 'block ''([^'']+)''', 'tokens', 'once');
                if ~isempty(tk), r.t_stop = str2double(tk{1}); end
                if ~isempty(bk), r.block = bk{1}; end
                if isfinite(r.t_stop) && r.t_stop > 3.5
                    Tpre = floor((r.t_stop - 0.5) * 1000) / 1000;   % a whole number of 1 ms steps
                    [R2, M2] = pa_configs(seg, base{:}, 'Only', cols(c), sw{:}, ...
                        'Stop', Tpre, 'TStat', 0);
                    Simulink.sdi.clear;
                    if ~(isfield(M2, 'all_crashed') && M2.all_crashed)
                        r = fill(r, R2.(cols{c}).log, M2.(cols{c}), Tpre, M2.cond.p2.vars.f_max);
                    end
                end
            else
                r = fill(r, R.(cols{c}).log, m, 200, M.cond.p2.vars.f_max);
                r.mean_err_mm = 1000 * m.mean;
            end
            rows(end + 1) = r; %#ok<AGROW>
        end
        el = toc(tAll);
        fprintf('  (%.0f s this call incl. re-runs, %.1f min so far, ~%.0f min left at this rate)\n', ...
            toc(tCall), el / 60, el / iCall * (nCall - iCall) / 60);
    end
end
G.elapsed_s = toc(tAll);
G.rows = rows;

fprintf('\n  stage seg    col stable  t_stop[s] block                       f_phi f_theta [Hz]  grow phi/theta  T_min[N] thL_max[deg] sat   err[mm]  tilt_sat tilt_ge tilt_ge95\n');
for i = 1:numel(rows)
    r = rows(i);
    [~, sn] = fileparts(r.segment);
    fprintf('  %-5s %-6s %-3s %-6s  %8.3f  %-26s %5.2f %5.2f        %6.2f %6.2f  %7.3f  %7.1f     %5.3f %7.2f   %6.4f  %6.4f  %6.4f\n', ...
        r.stage, sn(end-4:end), r.col, tf(r.stable), r.t_stop, shortblk(r.block), r.f_phi, r.f_theta, ...
        r.grow_phi, r.grow_theta, r.T_min, r.theta_L_max, r.sat, r.mean_err_mm, r.tilt_sat, r.tilt_ge, ...
        r.tilt_ge95);
end
outd = fullfile(repo_root(), 'results', 'gd3');
if ~exist(outd, 'dir'), mkdir(outd); end
fn = fullfile(outd, sprintf('gd3_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
save(fn, 'G');
fprintf('\n  saved %s\n', fn);
end

%% ---------------------------------------------------------------------------
function r = fill(r, L, m, tEnd, fmax)
%FILL  Oscillation facts over the last 3 s before tEnd, plus the P2 monitor summary.
if isfield(m, 'p2')
    r.T_min = m.p2.T_min;  r.theta_L_max = m.p2.theta_max_deg;  r.sat = m.p2.sat_frac;
    if isfield(m.p2, 'tilt_sat_frac'), r.tilt_sat = m.p2.tilt_sat_frac; end
end
if ~isfield(L, 'eta_log') || ~L.eta_log.ok, return; end
t = L.eta_log.t;  w3 = t >= tEnd - 3;
TILT_MAX = 30*pi/180;                                  % thrust_attitude_ref, per axis
tl = max(abs(L.eta_log.v(t <= tEnd, 1:2)), [], 2);
r.tilt_ge = mean(tl >= TILT_MAX);  r.tilt_ge95 = mean(tl >= 0.95 * TILT_MAX);
x = L.eta_log.v(w3, 1:2);  x = x - mean(x, 1);
n = size(x, 1);  if n < 16, return; end
dt = median(diff(t));  f = (0:n - 1).' / (n * dt);
X = abs(fft(x));  half = 2:floor(n / 2);
[~, i1] = max(X(half, 1));  [~, i2] = max(X(half, 2));
r.f_phi = f(half(i1));  r.f_theta = f(half(i2));
tt = t(w3);
a1 = max(abs(x(tt >= tEnd - 1, :)), [], 1);  a0 = max(abs(x(tt < tEnd - 2, :)), [], 1);
g = a1 ./ max(a0, eps);  r.grow_phi = g(1);  r.grow_theta = g(2);
if ~isfield(m, 'p2') && isfield(L, 'p2_f_log') && L.p2_f_log.ok
    fv = L.p2_f_log.v;  r.sat = mean(any(fv <= 1e-9 | fv >= fmax - 1e-9, 2));
end
end

function s = disp_arg(a)
if ischar(a), s = ['''' a ''''];
elseif iscell(a), s = ['{' strjoin(cellfun(@disp_arg, a, 'UniformOutput', false), ',') '}'];
elseif islogical(a), s = mat2str(a);
else, s = mat2str(a); end
end

function s = tf(b)
if b, s = 'yes'; else, s = 'NO'; end
end

function s = shortblk(b)
s = strrep(b, 'baseline1/', '');
if numel(s) > 26, s = s(end-25:end); end
end
