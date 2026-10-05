function G = run_p2_gd6(mode, varargin)
%RUN_P2_GD6  GĐ6 on plant P2 (docs/REGISTER_P2.md sec 7): N0P, N0V, D2 first pass.
%
%   run_p2_gd6('N0P')                          % night 1: payload tau* on P2, 5 conditions, A4 fixed-5
%   run_p2_gd6('N0P', 'Only', {'circle'})      % one or more conditions, in the given order
%   run_p2_gd6('N0V')                          % night 1: preview tau_prev* for column V (circle)
%   run_p2_gd6('D2', 'TauPred', t1, 'TauPrev', t2, 'Sha', '<sha256 of circle_main, cap 4>')
%   run_p2_gd6(<mode>, ..., 'DryRun', true)    % 1 segment, 2 tau points (N0P/N0V), nothing saved
%   run_p2_gd6('ICDIAG')                       % sec 8.2: hover, T5 with the standard IC, L2/L3, tau 0/200 ms
%   run_p2_gd6('D2REPORT')                     % re-print the D2 report (+ sec 10.1 tilt) from d2_p2.mat
%   run_p2_gd6('I0251', 'TauPred', t)          % sec 10.2: i0251 tilt clamp, real wind vs wind = 0
%   run_p2_gd6('N0W', 'TauPred', t)            % sec 0.3.1 / 13.1: oracle wind horizon tau_w* (A4 fixed-5)
%   run_p2_gd6('N0P', 'Only', {'circle_L15'})  % sec 13.3: payload tau* for circle, L = 1.5
%   run_p2_gd6('N0W6', 'TauPred', 0)          % sec 18.2: N0W-6, horizon tau_6* of O_6 (hover, K 0.5,
%                                              %   N6 term on; oracle AND propagation horizon = tau)
%   run_p2_gd6('N0M', 'Only', {'circle'}, 'TauPred', 0.290)   % sec 28.2: horizon of the N6 term with
%   run_p2_gd6('N0M', 'Only', {'T5'}, 'TauPred', 0.170)       %   the MEASURED wind, column L3_6 (N6X)
%   run_p2_gd6('N0M3', 'Only', {'hover'}, 'TauPred', 0)        % sec 45.1: tau_m* of the (iii) model,
%   run_p2_gd6('N0M3', 'Only', {'circle'}, 'TauPred', 0.290)   %   column L3 + (iii), horizon tau_m = tau
%   run_p2_gd6('GUOTRIM', 'Sha', 'a227e9d87a2ac436')           % sec 47: Classical+trim, DO+trim (circle_main)
%   run_p2_gd6('REPOOL025', 'Sha', '1db1de02532a3896')          % sec 50.1: the m_p 0.25 rows (B1, two corners)
%                                              %   re-pooled on U <= 7.38 m/s (A2 circle envelope), no run
%   run_p2_gd6('N0V', 'Only', {'T3b'})         % sec 32: tau_prev* for column V of the T3b table
%   run_p2_gd6('TAB', 'Only', {'T3b'}, 'TauPred', 0.340, 'TauPrev', tp, 'Sha', '35bed7710bf224ee')
%                                              % sec 32: one table per trajectory (sec 6.4), L0 L2 L3 V
%   run_p2_gd6('N0M', 'Only', {'square'}, 'TauPred', 0.120)   % sec 33: tau_m* of the N6 term, square
%   run_p2_gd6('TAB', 'Only', {'square'}, 'TauPred', 0.120, 'TauPrev', tp, 'TauN6', tm, 'Sha', 'a227e9d87a2ac436')
%                                              % sec 33: + column L3_6 (N6 term, measured wind, horizon
%                                              %   TauN6), h_model and the corner / edge windows
%   run_p2_gd6('TAB', 'Only', {'circle'}, 'MP', 0.25, 'TauPred', 0.290, 'TauPrev', 0.180, 'Sha', '1db1de02532a3896')
%   run_p2_gd6('TAB', 'Only', {'circle'}, 'L', 1.5, 'TauPred', 0.260, 'TauPrev', 0.180, 'Sha', '1db1de02532a3896')
%                                              % sec 39 (B1, B2): circle on S40 at another m_p / L
%   run_p2_gd6('TAB', 'Only', {'circle'}, 'FromD2', true, 'TauPred', 0.290, 'TauPrev', 0.180, 'Sha', '1db1de02532a3896')
%                                              %   the nominal level: D2's rows on S40 (nothing run)
%   run_p2_gd6('TAB', 'Only', {'circle'}, 'Imu', 3, 'TauPred', 0.290, 'TauPrev', 0.180, 'Sha', '1db1de02532a3896')
%   run_p2_gd6('TAB', 'Only', {'circle'}, 'ThrustMax', 20.44, ...)   % sec 42: E3 (IMU noise x k),
%   run_p2_gd6('TAB', 'Only', {'circle'}, 'Zeta', 0.02, ...)         %   D2-thrust, B3 (plant zeta_s)
%   run_p2_gd6('TAB', 'Only', {'circle'}, 'DataDir', 'wind_sn010', 'TauPred', 0.290, 'TauPrev', 0.180, 'Sha', S40)
%                                              % sec 43: the same S40 segments re-exported with the
%                                              %   wind sensor noise 0.1 m/s (files of the same name in
%                                              %   DataDir); L0 must equal D2's rows (it reads no w_meas)
%   run_p2_gd6('N0P', 'Only', {'circle_L05'})  % sec 39: payload tau* for circle, L = 0.5
%   run_p2_gd6('TAB', 'Only', {'circle'}, 'MP', 0.25, 'L', 0.5, 'TauPred', 0.330, 'TauPrev', 0.180, 'Sha', S40)
%                                              % sec 46.2: a corner of the 2^2 payload x cable design;
%                                              %   + envelope of the corner's m_p and the Weak / Medium split
%   run_p2_gd6('GUO', 'Sha', 'a227e9d87a2ac436')   % sec 46.3: Classical / ESO / DO / MOBADC as Guo 2020
%                                              %   defines them (Remark 9; switches), circle_main, Table 1 layout
%   run_p2_gd6('N0H3', 'Only', {'circle'})     % sec 40.1: H3 cut-off w_f on {1 2 4 8 16} Hz, A4 fixed-5
%  (The H4 modes N0H4 / GH4 of sec 40.2 were removed on 2026-10-04: H4 was dropped in sec 50 before any run on
%   wind data; the code is at tag paper-results-p2.)
%
%  Every simulation goes through pa_configs with the nominal P2 (PlantModel 'p2', tau_m from
%  p2_params = 17 ms, discrete, sensors, wind-sensor delay 50 ms), PayloadModel 1, K 0.5,
%  OnDiverge 'flag'. A segment value counts only if the column neither crashed nor diverged
%  and raised neither P2 flag (physical divergence, numerical flag - REGISTER_P2 sec 0.4).
%
%  N0P / N0V: REGISTER_ROBUST sec 12 procedure, unchanged - coarse 0:20:400 ms, one bounded
%  edge extension (+3 points), fine +-20 ms at 10 ms; tau = 0 is a physical floor. Results
%  (per tau and segment) in results/gd6/n0p_p2.mat, resumable per condition.
%  D2 with 'Conf2', 'wind_conf2' (REGISTER_P2 sec 60.8, GD10 only): the circle_main rule on the CONFIRM2
%  export, files read from that directory, rows (+ the sec 60.4 indices, rows.Q, nq x 4) in
%  results/gd10/D2.mat; 'DevTest', true: the first NDev dev segments, results/gd10_devtest/D2.mat.
%  D2: set = p2_segset('circle_main', 'CapPerDay', 4) checked against 'Sha'; columns L0, L2,
%  L3, V (sec 7.2); per-segment rows checkpointed in results/gd6/d2_p2.mat; D2 scored on
%  L2/L3 over the set common to every column run (sec 0.2 statistics).

opt = struct('Only', {{}}, 'DryRun', false, 'TauPred', [], 'TauPrev', [], 'Sha', '', ...
             'CapPerDay', 4, 'DryRunTau', [0 0.2], 'TauN6', [], 'MP', [], 'L', [], 'FromD2', false, ...
             'Imu', [], 'ThrustMax', [], 'Zeta', [], 'DataDir', '', ...
             'Conf2', '', 'DevTest', false, 'NDev', 2);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'run_p2_gd6: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
setup_path();
[st, gh] = system('git rev-parse --short HEAD');  if st ~= 0, gh = 'unknown'; end
git = strtrim(gh);
fprintf('\nrun_p2_gd6 %s | git %s%s\n', mode, git, tern(opt.DryRun, ' | DRY RUN - nothing saved', ''));
switch upper(mode)
    case 'N0P', G = run_sweep('N0P', opt, git);
    case 'N0H3', G = run_grid('N0H3', opt, git);      % sec 40.1: H3 filter cut-off grid
    case 'N0V', G = run_sweep('N0V', opt, git);
    case 'D2',  G = run_d2(opt, git);
    case 'ICDIAG', G = run_icdiag(opt, git);
    case 'I0251', G = run_i0251(opt, git);
    case 'N0W',   G = run_n0w(opt, git, 'N0W');
    case 'N0W6',  G = run_n0w(opt, git, 'N0W6');
    case 'N0M',   G = run_n0w(opt, git, 'N0M');
    case 'N0M3',  G = run_n0w(opt, git, 'N0M3');      % sec 45.1: tau_m* of the (iii) model (hover, circle)
    case 'GUOTRIM', G = run_guo(opt, git, true);     % sec 47: Classical+trim, DO+trim
    case 'REPOOL025', G = run_repool025(opt, git);   % sec 49.4 / 50.1: m_p 0.25 rows on the A2 circle envelope
    case 'TAB',   G = run_tab(opt, git);
    case 'GUO',   G = run_guo(opt, git);        % sec 46.3: Guo's four controllers on circle_main
    case 'D2REPORT'                          % re-print the D2 report from results/gd6/d2_p2.mat
        Z = load(fullfile(repo_root(), 'results', 'gd6', 'd2_p2.mat'), 'rows', 'key');
        fprintf('  from d2_p2.mat: %d segment(s), TauPred %.3f s, TauPrev %.3f s, set %s\n', numel(Z.rows), ...
            Z.key.TauPred, Z.key.TauPrev, Z.key.sha(1:16));
        cols = {'L0', 'L2', 'L3', 'V'};
        st = d2_stats(Z.rows, cols);  d2_tilt_report(Z.rows, cols, st);
        G = struct('rows', Z.rows, 'key', Z.key, 'stats', st);
    otherwise,  error('run_p2_gd6: unknown mode ''%s'' (N0P, N0V, N0W, N0W6, N0M, D2, D2REPORT, ICDIAG, I0251).', mode);
end
end

%% =====================================================================
function a = p2_args()
%P2_ARGS  The nominal P2 for every GĐ6 call (REGISTER_P2 sec 7). PredDelay (sec 13.2): the
%  sensor delay also reaches the PI-MoE prediction; it changes only columns that read what_ts
%  (P = g_both), none of which ran before sec 13.2.
a = {'Grid', true, 'PlantModel', 'p2', 'SensorDelayMs', 50, 'PayloadModel', 1, ...
     'PayloadWind', 0.5, 'OnDiverge', 'flag', 'Quiet', true, 'PredDelay', true};
end

function C = conditions(mode)
%CONDITIONS  sec 7.1: order circle, hover, T3b, square, T5; L = 1.0. circle_L15 (sec 13.3):
%  circle at L = 1.5, for N4b-P2-L15 (CONG G #8).
if any(strcmp(mode, {'N0V', 'N0W'}))
    C = struct('label', {'circle'}, 'cond', {'Test 4'}, 'L', {1.0});
elseif strcmp(mode, 'N0W6')                              % sec 18.2: hover, K 0.5, L 1.0
    C = struct('label', {'hover'}, 'cond', {'Hover'}, 'L', {1.0});
elseif strcmp(mode, 'N0M3')                              % sec 45.1: (iii), hover first, then circle
    C = struct('label', {'hover', 'circle'}, 'cond', {'Hover', 'Test 4'}, 'L', {1.0, 1.0});
elseif strcmp(mode, 'N0M')                               % sec 28.2: circle, T5; sec 33: square
    C = struct('label', {'circle', 'T5', 'square'}, 'cond', {'Test 4', 'Multisine', 'Square'}, ...
        'L', {1.0, 1.0, 1.0});
else
    C = struct('label', {'circle', 'hover', 'T3b', 'square', 'T5', 'circle_L15', 'circle_L05'}, ...
               'cond',  {'Test 4', 'Hover', 'Fig8 off-res', 'Square', 'Multisine', 'Test 4', 'Test 4'}, ...
               'L',     {1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 0.5});
end
end

function im = im_args(c)
%IM_ARGS  Internal model: circle = DoHarm [0 1] (the D2 table's own IM; = im_oracle_axis
%  circle {0, w}); every other condition = its exact-frequency table (im_oracle_axis).
if strncmp(c.label, 'circle', 6)                        % circle and circle_L15
    im = {'DoHarm', [0 1]};
    return
end
evalc('evalin(''base'', ''init_MOBADC_params'')');     % op_set needs init's variables
C = op_set(c.cond);
im = {'DoWAxis', im_oracle_axis(C.traj_type, C.traj_par, C.w_traj, c.L)};
end

function [v, fl] = one_value(M, col)
%ONE_VALUE  Mean error of one column, or NaN with the reason.
m = M.(col);
fl = '';
if isfield(m, 'crashed') && m.crashed
    fl = 'crash';
    if isfield(m, 'crash_msg') && ~isempty(m.crash_msg)       % say WHY (dry-run 2026-09-25: hover, T5)
        fprintf('         crash: %s\n', m.crash_msg(1:min(end, 400)));
    end
elseif isfield(m, 'diverged') && m.diverged, fl = 'diverged';
elseif isfield(m, 'p2') && m.p2.phys_div, fl = 'phys_div';
elseif isfield(m, 'p2') && m.p2.num_flag, fl = 'num_flag';
end
if isempty(fl), v = m.mean; else, v = NaN; end
end

%% =====================================================================
%  N0P / N0V
%% =====================================================================
function G = run_sweep(mode, opt, git)
[files, rows5] = p2_fixed5('Quiet', true);
C = conditions(mode);
if ~isempty(opt.Only)
    if strcmp(mode, 'N0V'), C = conditions('N0P'); end   % sec 32: N0V for the T3b / square tables
    k = cellfun(@(s) find(strcmp({C.label}, s), 1), cellstr(opt.Only));
    C = C(k);
end
xa = {};  lab = '';
if strcmp(mode, 'N0P'), col = 'g_psens'; par = 'TauPred'; else, col = 'g_sens'; par = 'TauPrev'; end
fprintf('  %s: %d condition(s) x %d segment(s) (A4 fixed-5: %s), column %s, sweep %s\n', mode, ...
    numel(C), numel(files), strjoin(cellfun(@(f) f(end-8:end-4), files(:)', 'UniformOutput', false), ' '), ...
    col, par);
if opt.DryRun
    files = files(1);
    fprintf('  DryRun: 1 segment, %s = %s ms only\n', par, mat2str(1000 * opt.DryRunTau));
end
outf = fullfile(repo_root(), 'results', 'gd6', 'n0p_p2.mat');
T = struct('mode', {}, 'label', {}, 'cond', {}, 'L', {}, 'tau_star', {}, 'edge_ok', {}, ...
           'coarse', {}, 'fine', {}, 'files', {}, 'git', {}, 'time', {});
if exist(outf, 'file') == 2 && ~opt.DryRun, Z = load(outf, 'T'); T = Z.T; end
dry = struct('label', {}, 'tau', {}, 'R', {});      % DryRun values (gd6_tonight compares them)
t0 = tic;
for i = 1:numel(C)
    c = C(i);
    rl = [c.label lab];
    j = find(strcmp({T.mode}, mode) & strcmp({T.label}, rl), 1);
    if ~isempty(j)
        assert(isequal(T(j).files(:), files(:)), ['run_p2_gd6: %s %s in %s was measured on another ' ...
            'segment set - not resumed; remove the row deliberately.'], mode, c.label, outf);
        fprintf('  [%s %s] already in %s (tau* %.1f ms) - skipped\n', mode, rl, outf, 1000 * T(j).tau_star);
        continue
    end
    im = im_args(c);
    fprintf('\n  [%s %s] Cond %s, L %.1f, %s\n', mode, c.label, c.cond, c.L, im_text(im));
    run = @(taus) sweep(files, c, im, col, par, taus, xa);
    if opt.DryRun
        [Rd, Vd, Fd] = run(opt.DryRunTau); %#ok<ASGLU>
        dry(end + 1) = struct('label', rl, 'tau', opt.DryRunTau, 'R', Rd); %#ok<AGROW>
        continue
    end
    taus = 0:0.020:0.400;
    [Rc, Vc, Fc] = run(taus);
    row = struct('mode', mode, 'label', rl, 'cond', c.cond, 'L', c.L, 'tau_star', NaN, ...
        'edge_ok', true, 'coarse', [], 'fine', [], 'files', {files}, 'git', git, ...
        'time', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    if ~any(isfinite(Rc))
        fprintf('     !!! every coarse tau diverged - tau* = NaN\n');
        row.coarse = struct('tau', taus, 'R', Rc, 'V', Vc, 'F', {Fc});
        T(end + 1) = row; %#ok<AGROW>
        save_rows(outf, T);
        continue
    end
    [~, kc] = min(Rc);
    at_floor = kc == 1 && taus(1) <= 0;
    if (kc == 1 || kc == numel(taus)) && ~at_floor
        dirn = tern(kc == 1, -1, 1);
        ext = taus(tern(dirn > 0, numel(taus), 1)) + dirn * (0.020:0.020:0.060);
        ext = ext(ext > 0);
        fprintf('     ! coarse minimum at the grid edge (%.0f ms) - extending by %d point(s)\n', 1000 * taus(kc), numel(ext));
        [Re, Ve, Fe] = run(ext);
        taus = [taus, ext];  Rc = [Rc, Re];  Vc = [Vc; Ve];  Fc = [Fc; Fe];
        [taus, o] = sort(taus);  Rc = Rc(o);  Vc = Vc(o, :);  Fc = Fc(o, :);
        [~, kc] = min(Rc);
        at_floor = kc == 1 && taus(1) <= 0;
        if (kc == 1 || kc == numel(taus)) && ~at_floor
            row.edge_ok = false;
            fprintf('     !!! still at the edge after one extension - EDGE-UNRESOLVED, not usable\n');
        end
    end
    row.coarse = struct('tau', taus, 'R', Rc, 'V', Vc, 'F', {Fc});
    tauc = taus(kc);
    fine = max(0, tauc - 0.020):0.010:(tauc + 0.020);
    [Rf, Vf, Ff] = run(fine);
    row.fine = struct('tau', fine, 'R', Rf, 'V', Vf, 'F', {Ff});
    if any(isfinite(Rf))
        [~, kf] = min(Rf);
        row.tau_star = fine(kf);
        if (kf == 1 || kf == numel(fine)) && ~(kf == 1 && fine(1) <= 0)
            row.edge_ok = false;
            fprintf('     ! fine minimum at its grid edge - EDGE-UNRESOLVED, not usable\n');
        end
    end
    fprintf('     -> %s %s: coarse min %.0f ms, tau* = %.1f ms%s\n', mode, c.label, 1000 * tauc, ...
        1000 * row.tau_star, tern(row.edge_ok, '', '  [EDGE-UNRESOLVED]'));
    T(end + 1) = row; %#ok<AGROW>
    save_rows(outf, T);
end
fprintf('\n  done in %.1f min\n', toc(t0) / 60);
if ~opt.DryRun
    fprintf('\n  %-5s %-8s %12s  %s\n', 'mode', 'cond', 'tau* [ms]', 'edge');
    for j = 1:numel(T)
        fprintf('  %-5s %-8s %12.1f  %s\n', T(j).mode, T(j).label, 1000 * T(j).tau_star, tern(T(j).edge_ok, 'ok', 'UNRESOLVED'));
    end
    fprintf('  saved %s - transcribe into REGISTER_P2 sec 7.1 and commit BEFORE night 2\n', outf);
end
G = struct('T', T, 'fixed5', rows5, 'dry', dry);
end

function [R, V, F] = sweep(files, c, im, col, par, taus, xa)
%SWEEP  Pooled column error at each tau over files; V/F = per (tau, segment) value / flag.
n = numel(taus);
R = nan(1, n);  V = nan(n, numel(files));  F = repmat({''}, n, numel(files));
other = tern(strcmp(par, 'TauPred'), 'TauPrev', 'TauPred');
for k = 1:n
    for f = 1:numel(files)
        tc = tic;
        args = [p2_args(), {'Only', {col}, 'Cond', c.cond, 'L', c.L}, im, {par, taus(k)}];
        if strcmp(other, 'TauPrev'), args = [args, {'TauPrev', 0}]; end   %#ok<AGROW> % N0P: no preview
        [~, M] = pa_configs(files{f}, args{:});
        try, Simulink.sdi.clear; catch, end
        [V(k, f), F{k, f}] = one_value(M, col);
        fprintf('       %s %5.0f ms  %s  %8.4f %-8s (%.0f s)\n', par, 1000 * taus(k), files{f}(end-8:end-4), ...
            V(k, f), F{k, f}, toc(tc));
    end
    m = isfinite(V(k, :));
    if any(m), R(k) = sqrt(mean(V(k, m).^2)); end
    fprintf('     %s %5.0f ms  pooled %.4f (%d/%d)\n', par, 1000 * taus(k), R(k), sum(m), numel(files));
end
end

%% =====================================================================
%  sec 40: competitor tuning grid (H3 cut-off) on the A4 fixed-5
%% =====================================================================
function G = run_grid(mode, opt, git)
%RUN_GRID  N0H3 (sec 40.1): column H3 (g_base + P2Cmp 1) at w_f in {1 2 4 8 16} Hz, a grid-edge
%  minimum -> one extension (0.5 Hz below / 32 Hz above). Argmin of the pooled error over the segments
%  finite at every grid value. results/gd6/<mode>_<cond>_p2.mat (resumable).
assert(numel(opt.Only) == 1, 'run_p2_gd6 %s: give one trajectory, ''Only'', {''circle''}.', mode);
C = conditions('N0P');  c = C(strcmp({C.label}, opt.Only{1}));
assert(numel(c) == 1, 'run_p2_gd6 %s: unknown trajectory %s.', mode, opt.Only{1});
[files, rows5] = p2_fixed5('Quiet', true);
if opt.DryRun, files = files(1); end
im = im_args(c);
grid = [1 2 4 8 16];  col = 'g_psens';                % the wind channel is zeroed by H3 anyway
xa = @(v) {'P2Cmp', 1, 'P2H3Hz', v, 'TauPred', 0, 'TauPrev', 0};
unit = 'Hz';  ext = {0.5, 32};
if opt.DryRun, grid = grid(1:2); end
outf = fullfile(repo_root(), 'results', 'gd6', sprintf('%s_%s_p2.mat', lower(mode), c.label));
key = struct('mode', mode, 'label', c.label, 'files', {files(:)}, 'TauPred', opt.TauPred);
cache = struct('v', zeros(1, 0), 'V', zeros(0, numel(files)), 'F', {cell(0, numel(files))});
if exist(outf, 'file') == 2 && ~opt.DryRun
    Z = load(outf, 'cache', 'key');
    assert(isequal(Z.key, key), 'run_p2_gd6 %s: %s belongs to another set - not resumed.', mode, outf);
    cache = Z.cache;
end
fprintf('  %s: %s, %s, column %s, grid %s %s, %d segment(s)\n', mode, c.label, im_text(im), col, mat2str(grid), unit, ...
    numel(files));
    function V = at(vals)
        V = nan(numel(vals), numel(files));
        for q = 1:numel(vals)
            j = find(abs(cache.v - vals(q)) < 1e-12, 1);
            if isempty(j)
                v = nan(1, numel(files));  fl = repmat({''}, 1, numel(files));
                for f = 1:numel(files)
                    tc = tic;
                    args = [p2_args(), {'Only', {col}, 'Cond', c.cond, 'L', c.L}, im, xa(vals(q))];
                    [~, M] = pa_configs(files{f}, args{:});
                    try, Simulink.sdi.clear; catch, end
                    [v(f), fl{f}] = one_value(M, col);
                    fprintf('       %s %8.4g %s  %s  %8.4f %-8s (%.0f s)\n', mode, vals(q), unit, files{f}(end-8:end-4), ...
                        v(f), fl{f}, toc(tc));
                end
                cache.v(end + 1) = vals(q);  cache.V(end + 1, :) = v;  cache.F(end + 1, :) = fl;
                if ~opt.DryRun, save(outf, 'cache', 'key', 'git'); end
                j = numel(cache.v);
                m = isfinite(v);
                fprintf('     %s %8.4g %s  pooled %.4f (%d/%d)\n', mode, vals(q), unit, sqrt(mean(v(m).^2)), sum(m), numel(files));
            end
            V(q, :) = cache.V(j, :);
        end
    end
V = at(grid);
sc = all(isfinite(V), 1);
pool = @(V) sqrt(mean(V(:, sc).^2, 2)).';
edge_ok = true;
if any(sc)
    [~, k] = min(pool(V));
    if ~isempty(ext) && (k == 1 || k == numel(grid)) && ~opt.DryRun
        e = ext{1 + (k == numel(grid))};
        fprintf('     ! minimum at the grid edge (%g %s) - one extension to %g %s\n', grid(k), unit, e, unit);
        grid = sort([grid, e]);  V = at(grid);  sc = all(isfinite(V), 1);  pool = @(V) sqrt(mean(V(:, sc).^2, 2)).';
        [~, k] = min(pool(V));
        if k == 1 || k == numel(grid), edge_ok = false; end
    end
    best = grid(k);  R = pool(V);
else
    best = NaN;  R = nan(1, numel(grid));  edge_ok = false;
end
fprintf('\n     -> %s %s: argmin %g %s%s (pooled over %d/%d segments)\n', mode, c.label, best, unit, ...
    tern(edge_ok, '', '  [EDGE-UNRESOLVED]'), sum(sc), numel(files));
for q = 1:numel(grid), fprintf('        %8.4g %s  %.4f\n', grid(q), unit, R(q)); end
G = struct('best', best, 'edge_ok', edge_ok, 'grid', grid, 'pooled', R, 'V', V, 'files', {files}, 'git', git, ...
    'fixed5', rows5);
if ~opt.DryRun
    W = G;  save(outf, 'cache', 'key', 'git', 'W');
    fprintf('  saved %s - transcribe the argmin into REGISTER_P2 sec 40 before the tables\n', outf);
end
end

%% =====================================================================
%  N0W - oracle wind horizon tau_w* (REGISTER_P2 sec 0.3.1, sec 13.1)
%% =====================================================================
function G = run_n0w(opt, git, mode)
%RUN_N0W  Column O(tau_w) = g_orac with the time-shifted true wind (OracleTauMs), circle,
%  K 0.5, L 1.0, payload TauPred = tau*_circle (explicit), A4 fixed-5. Coarse 0:20:400 ms,
%  one bounded edge extension, fine +-20 ms at 10 ms; tau_w = 0 is a floor (O(0) = current
%  wind). tau_w* = argmin over coarse + fine of pooled O on S_c = the segments finite and
%  unflagged at EVERY tau_w evaluated. O(150) is run as one extra report-only point when
%  150 ms is not on the grid. Resumable per tau_w (results/gd6/n0w_p2_partial.mat).
%  mode 'N0W6' (REGISTER_P2 sec 18.2): the same procedure for O_6(tau) = hover, K 0.5, L 1.0,
%  TauPred 0 (tau*_hover), N6 term ON with the true wind w(t + tau) held AND the pendulum model
%  propagated over the same tau (P2N6TauMs = tau) -> tau_6*. No O(150) point. Files
%  results/gd6/n0w6_p2[_partial].mat.
%  mode 'N0M' (sec 28.2): column L3_6 = g_psens + N6 term with the MEASURED wind, propagation
%  horizon tau (tau = 0: the plain L3); one trajectory per call ('Only', {'circle'} or {'T5'}),
%  its payload TauPred explicit -> tau_m*. Files results/gd6/n0m_<traj>_p2[_partial].mat.
%  mode 'N0M3' (sec 45.1): column L3 + the (iii) model (commanded acceleration), model horizon tau_m = tau
%  (tau = 0: the model's present force), one trajectory per call ('Only', {'hover'} or {'circle'}), its
%  payload TauPred explicit -> tau_m*. Files results/gd6/n0m3_<traj>_p2[_partial].mat.
m3 = strcmp(mode, 'N0M3');
n6 = any(strcmp(mode, {'N0W6', 'N0M'}));
nm = any(strcmp(mode, {'N0M', 'N0M3'}));
assert(~isempty(opt.TauPred), 'run_p2_gd6 %s: TauPred (the condition''s payload tau*) must be given explicitly.', mode);
[files, rows5] = p2_fixed5('Quiet', true);
c = conditions(mode);
if nm
    assert(numel(opt.Only) == 1, 'run_p2_gd6 %s: give one trajectory with ''Only'' (%s).', mode, strjoin({c.label}, ', '));
    c = c(strcmp({c.label}, opt.Only{1}));
    assert(numel(c) == 1, 'run_p2_gd6 %s: unknown trajectory %s.', mode, opt.Only{1});
end
im = im_args(c);
col = tern(nm, 'g_psens', 'g_orac');
if m3
    what = ' + (iii) model (commanded acceleration, horizon = tau)';
elseif nm
    what = ' + N6 term (measured wind, propagation horizon = tau)';
elseif n6
    what = ' + N6 term (oracle and propagation horizon = tau)';
else
    what = '';
end
fprintf('  %s: %s, L %.1f, %s, column O = %s%s, TauPred %.0f ms, %d segments (A4 fixed-5: %s)\n', mode, ...
    c.label, c.L, im_text(im), col, what, 1000 * opt.TauPred, numel(files), strjoin(cellfun(@(f) f(end-8:end-4), files(:)', 'UniformOutput', false), ' '));
if opt.DryRun
    files = files(1);
    fprintf('  DryRun: 1 segment, tau_w = %s ms only\n', mat2str(1000 * opt.DryRunTau));
end
if ~nm, oracle_check(files); end              % sec 0.3.1 printed check (STOP if not exact)
outd = fullfile(repo_root(), 'results', 'gd6');
stem = tern(m3, ['n0m3_' c.label '_p2'], tern(nm, ['n0m_' c.label '_p2'], tern(n6, 'n0w6_p2', 'n0w_p2')));
outf = fullfile(outd, [stem '.mat']);
partf = fullfile(outd, [stem '_partial.mat']);
key = struct('files', {files(:)}, 'TauPred', opt.TauPred, 'col', col);
if n6 || m3, key.mode = mode;  key.cond = c.cond; end
if ~opt.DryRun && exist(outf, 'file') == 2
    Z = load(outf, 'W');
    fprintf('  N0W already in %s: tau_w* = %.1f ms - nothing run (remove the file deliberately to re-run)\n', ...
        outf, 1000 * Z.W.tau_star);
    G = struct('W', Z.W);
    return
end
cache = struct('tau_ms', zeros(1, 0), 'V', zeros(0, numel(files)), 'F', {cell(0, numel(files))});
if ~opt.DryRun && exist(partf, 'file') == 2
    Z = load(partf, 'cache', 'key');
    assert(isequal(Z.key, key), 'run_p2_gd6 N0W: %s belongs to another set/TauPred - not resumed.', partf);
    cache = Z.cache;
    fprintf('  resuming: %d tau_w point(s) already in %s\n', numel(cache.tau_ms), partf);
end
t0 = tic;
    function [V, F] = at(taus)
        %AT  Per-segment O(tau_w) at each tau (s), from the cache or by running it.
        V = nan(numel(taus), numel(files));  F = repmat({''}, numel(taus), numel(files));
        for k = 1:numel(taus)
            tm = round(1000 * taus(k));
            j = find(cache.tau_ms == tm, 1);
            if isempty(j)
                v = nan(1, numel(files));  fl = repmat({''}, 1, numel(files));
                for f = 1:numel(files)
                    tc = tic;
                    args = [p2_args(), {'Only', {col}, 'Cond', c.cond, 'L', c.L}, im, ...
                        {'TauPred', opt.TauPred, 'TauPrev', 0, 'OracleTauMs', tm}];
                    if n6, args = [args, {'P2N6', true, 'P2N6TauMs', tm}]; end   %#ok<AGROW>
                    if m3, args = [args, {'P2M3', true, 'P2M3TauMs', tm}]; end   %#ok<AGROW>
                    [~, M] = pa_configs(files{f}, args{:});
                    try, Simulink.sdi.clear; catch, end
                    [v(f), fl{f}] = one_value(M, col);
                    fprintf('       tau_w %4d ms  %s  %8.4f %-8s (%.0f s)\n', tm, files{f}(end-8:end-4), ...
                        v(f), fl{f}, toc(tc));
                end
                cache.tau_ms(end + 1) = tm;  cache.V(end + 1, :) = v;  cache.F(end + 1, :) = fl;
                if ~opt.DryRun, save(partf, 'cache', 'key', 'git'); end
                j = numel(cache.tau_ms);
                m = isfinite(v);
                fprintf('     tau_w %4d ms  pooled %.4f (%d/%d)\n', tm, sqrt(mean(v(m).^2)), sum(m), numel(files));
            end
            V(k, :) = cache.V(j, :);  F(k, :) = cache.F(j, :);
        end
    end
if opt.DryRun
    [Vd, Fd] = at(opt.DryRunTau);
    G = struct('dry', struct('tau', opt.DryRunTau, 'V', Vd, 'F', {Fd}), 'fixed5', rows5);
    fprintf('\n  done in %.1f min (dry run, nothing saved)\n', toc(t0) / 60);
    return
end
pool = @(V, m) sqrt(mean(V(:, m).^2, 2)).';          % pooled per tau over the segments m
taus = 0:0.020:0.400;
Vc = at(taus);
sc = all(isfinite(Vc), 1);
edge_ok = true;
if ~any(sc)
    fprintf('     !!! no segment is finite at every coarse tau_w - tau_w* = NaN\n');
    W = struct('tau_star', NaN, 'edge_ok', false, 'files', {files}, 'git', git);
    save(outf, 'W');  G = struct('W', W);  return
end
[~, kc] = min(pool(Vc, sc));
if kc == numel(taus)                          % tau_w = 0 is a floor, not an edge
    ext = taus(end) + (0.020:0.020:0.060);
    fprintf('     ! coarse minimum at the grid edge (%.0f ms) - extending by %d point(s)\n', 1000 * taus(kc), numel(ext));
    taus = [taus, ext];
    Vc = at(taus);  sc = all(isfinite(Vc), 1);
    [~, kc] = min(pool(Vc, sc));
    if kc == numel(taus)
        edge_ok = false;
        fprintf('     !!! still at the edge after one extension - EDGE-UNRESOLVED, not usable\n');
    end
end
tauc = taus(kc);
fine = max(0, tauc - 0.020):0.010:(tauc + 0.020);
at(fine);
tg = unique(round(1000 * [taus, fine])) / 1000;     % coarse (+ extension) + fine, sorted
if n6 || m3
    V150 = zeros(1, numel(files));                   % N0W-6 / N0M / N0M3: no O(150) point (sec 18.2)
else
    V150 = at(0.150);                                 % report-only (from the cache if on the grid)
end
Vall = at(tg);
Sc = all(isfinite(Vall), 1) & all(isfinite(V150), 1);
if any(~Sc)
    for f = find(~Sc), fprintf('     dropped from S_c: %s\n', files{f}); end
end
Rg = pool(Vall, Sc);
[~, kg] = min(Rg);
tau_star = tg(kg);
if kg == numel(tg) && tau_star > 0, edge_ok = false; end
kf = find(abs(fine - tau_star) < 1e-9, 1);
if ~isempty(kf) && kf == numel(fine) && tau_star > 0 && ~any(abs(taus - tau_star) < 1e-9)
    edge_ok = false;
    fprintf('     ! minimum at the fine grid''s edge - EDGE-UNRESOLVED, not usable\n');
end
R0 = pool(at(0), Sc);  R150 = pool(V150, Sc);
if n6 || m3, R150 = NaN;  V150 = nan(1, numel(files)); end
fprintf('\n     -> %s %s: coarse min %.0f ms, %s = %.1f ms%s\n', mode, c.label, 1000 * tauc, ...
    tern(nm, 'tau_m*', tern(n6, 'tau_6*', 'tau_w*')), 1000 * tau_star, tern(edge_ok, '', '  [EDGE-UNRESOLVED]'));
fprintf('\n  %s table (pooled over S_c = %d/%d segments):\n', mode, sum(Sc), numel(files));
fprintf('     O(0)       %.4f\n', R0);
if ~(n6 || m3), fprintf('     O(150)     %.4f\n', R150); end
fprintf('     O(tau*)    %.4f   (tau* = %.0f ms)\n', Rg(kg), 1000 * tau_star);
fprintf('  per segment [m]: %-10s %8s %8s %8s\n', 'seg', 'O(0)', 'O(150)', 'O(tau*)');
v0 = at(0);  vs = at(tau_star);
for f = 1:numel(files)
    fprintf('                   %-10s %8.4f %8.4f %8.4f\n', files{f}(end-8:end-4), v0(f), V150(f), vs(f));
end
W = struct('tau_star', tau_star, 'edge_ok', edge_ok, 'tau_coarse_min', tauc, 'grid', tg, ...
    'V', Vall, 'pooled', Rg, 'Sc', Sc, 'O0', R0, 'O150', R150, 'V150', V150, 'files', {files}, ...
    'TauPred', opt.TauPred, 'col', col, 'git', git, 'time', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
    'cache', cache);
save(outf, 'W', 'key');
fprintf('\n  done in %.1f min | saved %s - transcribe %s into REGISTER_P2 and commit BEFORE the next block\n', ...
    toc(t0) / 60, outf, tern(nm, 'tau_m*', tern(n6, 'tau_6*', 'tau_w*')));
G = struct('W', W, 'fixed5', rows5);
end

function oracle_check(files)
%ORACLE_CHECK  REGISTER_P2 sec 0.3.1: the time-shift construction at the checkpoint's own
%  horizon reproduces wind_sim_load's w_oracle_ts, and O(0) equals wind_ts - both exactly.
for f = 1:numel(files)
    evalc('wind_sim_load(files{f}, 1)');
    wts = evalin('base', 'wind_ts');  wor = evalin('base', 'w_oracle_ts');
    S = load(files{f}, 'tau_ms');  th = double(S.tau_ms);
    oh = p2_oracle_ts(wts, th);  o0 = p2_oracle_ts(wts, 0);
    d1 = max(abs(oh.signals.values(:) - wor.signals.values(:)));
    d0 = max(abs(o0.signals.values(:) - wts.signals.values(:)));
    fprintf('  oracle check %s: O(%g) time-shift vs w_oracle_ts max|d| %.3g; O(0) vs wind_ts max|d| %.3g\n', ...
        files{f}(end-8:end-4), th, d1, d0);
    assert(d1 == 0 && d0 == 0, 'run_p2_gd6 N0W: oracle construction check failed (sec 0.3.1) - not run.');
end
end

%% =====================================================================
%  D2 first pass
%% =====================================================================
function G = run_d2(opt, git)
assert(~isempty(opt.TauPred) && ~isempty(opt.TauPrev), ['run_p2_gd6 D2: TauPred (tau*_circle) and ' ...
    'TauPrev (tau_prev*) must be given explicitly, as transcribed in REGISTER_P2 sec 7.1.']);
cm = ~isempty(opt.Conf2) || opt.DevTest;             % sec 60.8: CONFIRM2 (or its dev test)
assert(~(~isempty(opt.Conf2) && opt.DevTest), 'run_p2_gd6 D2: Conf2 and DevTest exclude each other.');
sarg = {'CapPerDay', opt.CapPerDay, 'Quiet', true};
if ~isempty(opt.Conf2), sarg = [sarg, {'Confirm2', opt.Conf2}]; end
S = p2_segset('circle_main', sarg{:});
fprintf('  set circle_main%s, cap %d/day: %d segments, %d days, sha256 %s\n', ...
    tern(isempty(opt.Conf2), '', ' (CONFIRM2)'), opt.CapPerDay, S.n_seg, S.n_days, S.sha256);
if ~opt.DryRun && ~opt.DevTest
    sh = lower(strtrim(opt.Sha));                    % the full SHA-256 or its registered 16-hex prefix
    assert(numel(sh) >= 16 && strncmp(S.sha256, sh, numel(sh)), ['run_p2_gd6 D2: the set''s SHA-256 ' ...
        '(%s) does not match the registered one (REGISTER_P2 sec 6.3.1) - not run.'], S.sha256);
end
files = S.files;  days = S.day;
if opt.DryRun, files = files(1); days = days(1); end
if opt.DevTest, files = files(1:min(opt.NDev, end)); days = days(1:numel(files)); end
cols = {'L0', 'L2', 'L3', 'V'};
outf = fullfile(repo_root(), 'results', 'gd6', 'd2_p2.mat');
key = struct('sha', S.sha256, 'TauPred', opt.TauPred, 'TauPrev', opt.TauPrev);
rows = struct('file', {}, 'day', {}, 'E', {}, 'F', {}, 'p2', {});
if cm                                                % sec 60.8 (absent on the dev key and rows)
    outf = fullfile(repo_root(), 'results', tern(opt.DevTest, 'gd10_devtest', 'gd10'), 'D2.mat');
    if opt.DevTest, key.DevTest = opt.NDev; else, key.Conf2 = opt.Conf2; end
    rows = struct('file', {}, 'day', {}, 'E', {}, 'F', {}, 'p2', {}, 'Q', {});
end
if exist(outf, 'file') == 2 && ~opt.DryRun
    Z = load(outf, 'rows', 'key');
    assert(isequal(Z.key, key), 'run_p2_gd6 D2: %s belongs to another set/tau - not resumed.', outf);
    rows = Z.rows;
end
fprintf('  columns %s | TauPred %.1f ms (L3) | TauPrev %.1f ms (V) | %d segment(s), %d done\n', ...
    strjoin(cols, ' '), 1000 * opt.TauPred, 1000 * opt.TauPrev, numel(files), numel(rows));
base = [p2_args(), {'Cond', 'Test 4'}];
t0 = tic;  nNew = 0;
for i = 1:numel(files)
    fn = files{i};
    if any(strcmp({rows.file}, fn)), continue; end
    tc = tic;
    ff = fn;
    if ~isempty(opt.Conf2), ff = fullfile(opt.Conf2, fn); end   % sec 60.8
    [~, A] = pa_configs(ff, base{:}, 'DoHarm', [0 1], 'Only', {'g_sens', 'g_psens'}, ...
        'TauPred', opt.TauPred, 'TauPrev', 0);
    try, Simulink.sdi.clear; catch, end
    [~, B] = pa_configs(ff, base{:}, 'DoHarm', [0 1], 'Only', {'g_sens'}, ...
        'TauPred', opt.TauPred, 'TauPrev', opt.TauPrev);
    try, Simulink.sdi.clear; catch, end
    [~, Z0] = pa_configs(ff, base{:}, 'DoHarm', 1, 'Only', {'g_base'}, ...
        'TauPred', opt.TauPred, 'TauPrev', 0);
    try, Simulink.sdi.clear; catch, end
    src = {Z0, 'g_base'; A, 'g_sens'; A, 'g_psens'; B, 'g_sens'};
    E = nan(1, 4);  F = cell(1, 4);  p2 = cell(1, 4);
    for c = 1:4
        [E(c), F{c}] = one_value(src{c, 1}, src{c, 2});
        m = src{c, 1}.(src{c, 2});
        if isfield(m, 'p2'), p2{c} = m.p2; end
    end
    r = struct('file', fn, 'day', days{i}, 'E', E, 'F', {F}, 'p2', {p2});
    if cm                                            % sec 60.4 indices per column (nq x 4)
        [~, qn] = p2_indices([]);
        Q = nan(numel(qn), 4);
        for c = 1:4, Q(:, c) = p2_indices(src{c, 1}.(src{c, 2})).'; end
        r.Q = Q;
    end
    rows(end + 1) = r; %#ok<AGROW>
    nNew = nNew + 1;
    el = toc(t0);
    fprintf('  [%3d/%3d] %-26s L0 %.4f L2 %.4f L3 %.4f V %.4f %s (%.0f s, ~%.0f min left)\n', i, numel(files), ...
        fn, E, strjoin(F(~cellfun(@isempty, F)), ','), toc(tc), el / nNew * (numel(files) - i) / 60);
    if ~opt.DryRun
        if ~exist(fileparts(outf), 'dir'), mkdir(fileparts(outf)); end
        save(outf, 'rows', 'key', 'git');
    end
end
st = d2_stats(rows, cols);
d2_tilt_report(rows, cols, st);       % sec 10.1, secondary
if cm, fprintf(['  (CONFIRM2 / dev test: the PASS/FAIL line above is the dev gate of sec 0.5; the CONFIRM2 ' ...
    'rule of REGISTER_P2 sec 60.3 is applied by gd10_confirm2 / conf2_claims)\n']); end
G = struct('rows', rows, 'key', key, 'stats', st);
end

%% =====================================================================
%  sec 32: one table per trajectory (sec 6.4) - T3b / square, columns L0 L2 L3 V
%% =====================================================================
function G = run_tab(opt, git)
%RUN_TAB  The D2 columns on another trajectory's own set (REGISTER_P2 sec 6.4, 32): L0 = Guo
%  MOBADC as published (g_base, DoHarm 1 = one harmonic at the condition's payload_sigma); L2 =
%  g_sens, L3 = g_psens at TauPred (tau* of the trajectory), V = g_sens at TauPrev - the three at
%  the trajectory's exact-frequency IM table (im_oracle_axis, as N0P). The same three pa_configs
%  calls per segment as D2. Descriptive (not a gate). results/gd6/tab_<traj>_p2.mat, resumable.
%  'TauN6' given (sec 33, square): + column L3_6 = L3 with the N6 term (measured wind, propagation
%  horizon TauN6) - a fourth call; h_model = 1 - L3_6/L3 on the one set and on the unsaturated
%  subset; for the square also the corner / edge half-cycle windows (side report, sec 33).
assert(numel(opt.Only) == 1, 'run_p2_gd6 TAB: give one trajectory, ''Only'', {''T3b''} or {''square''}.');
C = conditions('N0P');
c = C(strcmp({C.label}, opt.Only{1}));
sets = struct('T3b', 'T3b_main', 'square', 'square_main', 'circle', 'S40');   % circle: sec 39 (B1, B2)
assert(numel(c) == 1 && isfield(sets, c.label), 'run_p2_gd6 TAB: trajectory %s has no registered table.', opt.Only{1});
assert(~isempty(opt.TauPred) && ~isempty(opt.TauPrev), ['run_p2_gd6 TAB: TauPred (tau* of the trajectory) ' ...
    'and TauPrev (tau_prev* of V) must be given explicitly, as registered.']);
lev = {opt.MP, opt.L, opt.Imu, opt.ThrustMax, opt.Zeta};
sn = ~isempty(opt.DataDir);                             % sec 43: noisy wind-sensor files
assert(~sn || (strcmp(c.label, 'circle') && all(cellfun(@isempty, lev)) && ~opt.FromD2), ...
    'run_p2_gd6 TAB: DataDir is registered for circle on S40 at the nominal level only (sec 43).');
if sn
    assert(exist(opt.DataDir, 'dir') == 7, 'run_p2_gd6 TAB: DataDir %s not found.', opt.DataDir);
    sn_check_dir(opt.DataDir);
end
assert(strcmp(c.label, 'circle') || (all(cellfun(@isempty, lev)) && ~opt.FromD2), ...
    'run_p2_gd6 TAB: MP / L / Imu / ThrustMax / Zeta / FromD2 are registered for circle on S40 only (sec 39, 42).');
corner = ~isempty(opt.MP) && ~isempty(opt.L);         % sec 46: a corner of the 2^2 payload x cable design
nlev = sum(~cellfun(@isempty, lev)) - corner + opt.FromD2;
assert(nlev <= 1, 'run_p2_gd6 TAB: one level option per table (sec 39, 42); MP + L together = one corner (sec 46).');
if ~isempty(opt.L), c.L = opt.L; end
tag = '';
if ~isempty(opt.MP), tag = sprintf('_mp%03d', round(100 * opt.MP)); end
if ~isempty(opt.L), tag = sprintf('%s_L%03d', tag, round(100 * opt.L)); end
if ~isempty(opt.Imu), tag = sprintf('_imu%03d', round(100 * opt.Imu)); end
if ~isempty(opt.ThrustMax), tag = sprintf('_thr%04d', round(100 * opt.ThrustMax)); end
if ~isempty(opt.Zeta), tag = sprintf('_zeta%03d', round(100 * opt.Zeta)); end
if opt.FromD2, tag = '_nominal'; end
if sn, tag = '_sn010'; end
S = p2_segset(sets.(c.label), 'CapPerDay', opt.CapPerDay, 'Quiet', true);
fprintf('  set %s, cap %d/day: %d segments, %d days, sha256 %s\n', sets.(c.label), opt.CapPerDay, ...
    S.n_seg, S.n_days, S.sha256);
if ~opt.DryRun
    sh = lower(strtrim(opt.Sha));
    assert(numel(sh) >= 16 && strncmp(S.sha256, sh, numel(sh)), ['run_p2_gd6 TAB: the set''s SHA-256 ' ...
        '(%s) does not match the registered one (REGISTER_P2 sec 6.3.1) - not run.'], S.sha256);
end
files = S.files;  days = S.day;
if opt.DryRun, files = files(1); days = days(1); end
cols = {'L0', 'L2', 'L3', 'V'};
n6 = ~isempty(opt.TauN6);
if n6, cols{end + 1} = 'L3_6'; end
im = im_args(c);
evalc('evalin(''base'', ''init_MOBADC_params'')');     % op_set needs init's variables
Cs = op_set(c.cond);
sq = Cs.traj_type == 3;                                 % square: corner / edge windows (sec 33)
outf = fullfile(repo_root(), 'results', 'gd6', ['tab_' c.label tag '_p2.mat']);
key = struct('traj', c.label, 'cond', c.cond, 'sha', S.sha256, 'TauPred', opt.TauPred, 'TauPrev', opt.TauPrev);
if n6, key.TauN6 = opt.TauN6; end
if ~isempty(opt.MP), key.MP = opt.MP; end
if ~isempty(opt.L), key.L = opt.L; end
if ~isempty(opt.Imu), key.Imu = opt.Imu; end
if ~isempty(opt.ThrustMax), key.ThrustMax = opt.ThrustMax; end
if ~isempty(opt.Zeta), key.Zeta = opt.Zeta; end
if sn, key.DataDir = opt.DataDir; end
if opt.FromD2                                          % sec 39: the nominal level = D2's rows on S40
    Z = load(fullfile(repo_root(), 'results', 'gd6', 'd2_p2.mat'), 'rows', 'key');
    assert(strncmp(Z.key.sha, 'a227e9d87a2ac436', 16) && Z.key.TauPred == opt.TauPred && ...
        Z.key.TauPrev == opt.TauPrev, 'run_p2_gd6 TAB FromD2: d2_p2.mat has another set or tau - not used.');
    [tf, loc] = ismember(files, {Z.rows.file});
    assert(all(tf), 'run_p2_gd6 TAB FromD2: %d S40 segment(s) missing from d2_p2.mat.', sum(~tf));
    rows = Z.rows(loc);
    fprintf('  nominal level (m_p 0.5, L 1.0): D2''s rows (sec 7.2, same configuration) on the %d S40 segments - nothing run\n', ...
        numel(rows));
    st = tab_stats(rows, cols);
    G = struct('rows', rows, 'key', key, 'stats', st);
    return
end
rows = struct('file', {}, 'day', {}, 'E', {}, 'F', {}, 'p2', {});
if sq, rows = struct('file', {}, 'day', {}, 'E', {}, 'F', {}, 'p2', {}, 'Ec', {}, 'Ee', {}); end
if exist(outf, 'file') == 2 && ~opt.DryRun
    Z = load(outf, 'rows', 'key');
    assert(isequal(Z.key, key), 'run_p2_gd6 TAB: %s belongs to another set/tau - not resumed.', outf);
    rows = Z.rows;
end
fprintf('  %s (Cond %s, L %.1f%s%s) | columns %s | L0 DoHarm 1, L2/L3/V %s | TauPred %.1f ms | TauPrev %.1f ms | %d segment(s), %d done\n', ...
    c.label, c.cond, c.L, tern(isempty(opt.MP), '', sprintf(', m_p %.2f', opt.MP)), lev_text(opt), strjoin(cols, ' '), ...
    im_text(im), 1000 * opt.TauPred, 1000 * opt.TauPrev, numel(files), numel(rows));
if n6, fprintf('  L3_6 = L3 + N6 term (measured wind), horizon TauN6 %.0f ms\n', 1000 * opt.TauN6); end
if sn, fprintf('  wind-sensor files from %s (sec 43: sigma 0.1 m/s, PI-MoE recomputed on the noisy input)\n', opt.DataDir); end
if sq
    fprintf(['  square: edge T %.4f s, dwell %.4f s, cycle %.4f s; corner window = the half cycle centred on ' ...
        'each dwell, edge window = the other half (sec 33)\n'], Cs.traj_par(2), Cs.traj_par(3), sum(Cs.traj_par(2:3)));
end
base = [p2_args(), {'Cond', c.cond, 'L', c.L}];
if ~isempty(opt.MP), base = [base, {'MP', opt.MP}]; end
if ~isempty(opt.Imu), base = [base, {'P2ImuScale', opt.Imu}]; end
if ~isempty(opt.ThrustMax), base = [base, {'P2ThrustMax', opt.ThrustMax}]; end
if ~isempty(opt.Zeta), base = [base, {'P2ZetaS', opt.Zeta}]; end
t0 = tic;  nNew = 0;
for i = 1:numel(files)
    fn = files{i};
    if any(strcmp({rows.file}, fn)), continue; end
    tc = tic;
    ff = fn;
    if sn, ff = fullfile(opt.DataDir, fn); end          % sec 43: same segment, noisy w_meas
    [~, A] = pa_configs(ff, base{:}, im{:}, 'Only', {'g_sens', 'g_psens'}, 'TauPred', opt.TauPred, 'TauPrev', 0);
    try, Simulink.sdi.clear; catch, end
    [~, B] = pa_configs(ff, base{:}, im{:}, 'Only', {'g_sens'}, 'TauPred', opt.TauPred, 'TauPrev', opt.TauPrev);
    try, Simulink.sdi.clear; catch, end
    [~, Z0] = pa_configs(ff, base{:}, 'DoHarm', 1, 'Only', {'g_base'}, 'TauPred', opt.TauPred, 'TauPrev', 0);
    try, Simulink.sdi.clear; catch, end
    src = {Z0, 'g_base'; A, 'g_sens'; A, 'g_psens'; B, 'g_sens'};
    if n6
        [~, D] = pa_configs(ff, base{:}, im{:}, 'Only', {'g_psens'}, 'TauPred', opt.TauPred, 'TauPrev', 0, ...
            'P2N6', true, 'P2N6TauMs', round(1000 * opt.TauN6));
        try, Simulink.sdi.clear; catch, end
        src(end + 1, :) = {D, 'g_psens'};
    end
    nc = numel(cols);
    E = nan(1, nc);  F = cell(1, nc);  p2 = cell(1, nc);  Ec = nan(1, nc);  Ee = nan(1, nc);
    for k = 1:nc
        [E(k), F{k}] = one_value(src{k, 1}, src{k, 2});
        m = src{k, 1}.(src{k, 2});
        if isfield(m, 'p2'), p2{k} = m.p2; end
        if sq && isfinite(E(k)), [Ec(k), Ee(k)] = sq_windows(m.e_t, Cs.traj_par); end
    end
    r = struct('file', fn, 'day', days{i}, 'E', E, 'F', {F}, 'p2', {p2});
    if sq, r.Ec = Ec;  r.Ee = Ee; end
    rows(end + 1) = r; %#ok<AGROW>
    nNew = nNew + 1;
    el = toc(t0);
    ce = [cols; num2cell(E)];
    fprintf('  [%3d/%3d] %-26s%s %s (%.0f s, ~%.0f min left)\n', i, numel(files), fn, ...
        sprintf(' %s %.4f', ce{:}), strjoin(F(~cellfun(@isempty, F)), ','), toc(tc), ...
        el / nNew * (numel(files) - i) / 60);
    if ~opt.DryRun
        if ~exist(fileparts(outf), 'dir'), mkdir(fileparts(outf)); end
        save(outf, 'rows', 'key', 'git');
    end
end
st = tab_stats(rows, cols);
if n6, st.h_model = hmodel_report(rows, cols, sq); end
if corner, st.bins = bin_report(rows, cols, S, opt.MP); end
if sn && ~opt.DryRun, st.sn = sn_report(rows, cols, opt); end
G = struct('rows', rows, 'key', key, 'stats', st);
end

function B = bin_report(rows, cols, S, mp)
%BIN_REPORT  REGISTER_P2 sec 46.2 (2^2 corners): the envelope of the corner's own m_p (sec 0.10 table, K 0.5)
%  against the set's U, then the table split by wind bin (Weak U < 6, Medium 6 <= U <= 12 m/s, the bins of
%  REGISTER_P2 sec 7 / N5): per bin n, pooled per column, L3/L2 - 1 and V/L2 - 1 with SE / LOO / by-day
%  (descriptive, not a gate), on the corner's one set restricted to its envelope.
UMAX = [0.25 9.99; 0.50 10.86; 0.65 11.35];              % sec 0.10, K 0.5
k = find(abs(UMAX(:, 1) - mp) < 1e-9, 1);
[tf, loc] = ismember({rows.file}, S.files);
assert(all(tf), 'bin_report: a row is not in the set.');
U = S.U(loc);  U = U(:);
nc = numel(cols);
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
if isempty(k)
    fprintf('\n  envelope: m_p %.2f not in the sec 0.10 table - not checked\n', mp);
else
    fprintf('\n  envelope (sec 0.10, K 0.5, m_p %.2f): U_max %.2f m/s; set U max %.2f -> %d of %d segments inside\n', ...
        mp, UMAX(k, 2), max(U), sum(U <= UMAX(k, 2)), numel(U));
    ok = ok & U <= UMAX(k, 2);
end
bins = {'Weak (U < 6)', U < 6; 'Medium (6 <= U <= 12)', U >= 6 & U <= 12};
pool = @(e) sqrt(mean(e.^2, 1));
B = struct();
for b = 1:2
    m = ok & bins{b, 2};
    day = {rows(m).day}';  Ek = E(m, :);
    fprintf('  -- %s: n %d, days %d\n', bins{b, 1}, sum(m), numel(unique(day)));
    if sum(m) < 2, fprintf('     fewer than 2 segments - not computed\n'); continue; end
    ce = [cols; num2cell(pool(Ek))];
    fprintf('     pooled %s\n', sprintf('%s %.5f  ', ce{:}));
    qs = {'L3/L2 - 1', 3; 'V/L2 - 1', 4};
    for q = 1:2
        cq = qs{q, 2};
        f = @(e) pool(e(:, cq)) / pool(e(:, 2)) - 1;
        [se, med, loo] = jk(f, Ek, day);
        fprintf('     %-9s %+7.2f %%  SE %.2f  LOO [%+.2f, %+.2f] %%  by-day %+.2f %%\n', qs{q, 1}, 100 * f(Ek), ...
            100 * se, 100 * min(loo), 100 * max(loo), 100 * med);
    end
    B.(tern(b == 1, 'weak', 'medium')) = struct('n', sum(m), 'E', Ek);
end
end

function R = sn_report(rows, cols, opt)
%SN_REPORT  REGISTER_P2 sec 43.2 (wind-sensor-noise sensitivity, not a gate): (1) check - L0 reads no
%  measured wind, so it must equal D2's row on every segment (|d| = 0); a difference = the noisy files are
%  not the same segments -> printed, reading not made. (2) reading: L3/L2 - 1 and V/L2 - 1 at sigma 0.1
%  keep the sign of every LOO value (< 0) -> SIGN KEPT, otherwise NOT KEPT; (3) paired change vs sigma 0
%  (D2's rows) per column, pooled on the common one set.
Z = load(fullfile(repo_root(), 'results', 'gd6', 'd2_p2.mat'), 'rows', 'key');
assert(strncmp(Z.key.sha, 'a227e9d87a2ac436', 16) && Z.key.TauPred == opt.TauPred && ...
    Z.key.TauPrev == opt.TauPrev, 'sn_report: d2_p2.mat has another set or tau.');
[tf, loc] = ismember({rows.file}, {Z.rows.file});
assert(all(tf), 'sn_report: %d segment(s) missing from d2_p2.mat.', sum(~tf));
E1 = reshape([rows.E], numel(cols), []).';
E0 = reshape([Z.rows(loc).E], 4, []).';
d0 = abs(E1(:, 1) - E0(:, 1));
same = all(d0 == 0 | (isnan(E1(:, 1)) & isnan(E0(:, 1))));
fprintf('\n  SEC 43.2 WIND-SENSOR NOISE 0.1 m/s - S40 circle [sensitivity, not a gate]\n');
fprintf('  check L0 (reads no measured wind) = D2 row on every segment: %s (max |d| %.3g)\n', ...
    tern(same, 'YES', 'NO - the noisy files are not the same segments; reading not made'), max(d0));
R = struct('l0_same', same);
if ~same, return; end
ok = all(isfinite(E1), 2) & all(isfinite(E0), 2);
day = {rows(ok).day}';  fl = {rows(ok).file}';
pool = @(e) sqrt(mean(e.^2, 1));
A = [E1(ok, :), E0(ok, :)];
fprintf('  common one set (valid at sigma 0 and 0.1): n %d, days %d\n', sum(ok), numel(unique(day)));
for c = 2:4
    fprintf('     %-3s pooled sigma 0.1 %.5f  sigma 0 %.5f  change %+.2f %%\n', cols{c}, pool(A(:, c)), ...
        pool(A(:, 4 + c)), 100 * (pool(A(:, c)) / pool(A(:, 4 + c)) - 1));
end
qs = {'L3/L2 - 1', @(p) p(3) / p(2) - 1; 'V/L2 - 1', @(p) p(4) / p(2) - 1};
for k = 1:2
    st = sn_stat(qs{k, 2}, A(:, 1:4), day, fl);
    st0 = qs{k, 2}(pool(A(:, 5:8)));
    rd = tern(st.val < 0 && all(st.loo < 0), 'SIGN KEPT', 'NOT KEPT');
    fprintf('     %-10s sigma 0.1 %+.2f %%  LOO [%+.2f, %+.2f] %%  by-day %+.2f %%  (sigma 0: %+.2f %%)  -> %s\n', ...
        qs{k, 1}, 100 * st.val, 100 * min(st.loo), 100 * max(st.loo), 100 * st.byday, 100 * st0, rd);
    R.(tern(k == 1, 'L3', 'V')) = struct('val', st.val, 'loo', st.loo, 'reading', rd, 'val0', st0);
end
end

function s = sn_stat(f, E, day, fl) %#ok<INUSD>
pool = @(e) sqrt(mean(e.^2, 1));
n = size(E, 1);
s.val = f(pool(E));
s.loo = arrayfun(@(i) f(pool(E([1:i-1, i+1:n], :))), (1:n)');
ud = unique(day);
s.byday = median(cellfun(@(d) f(pool(E(strcmp(day, d), :))), ud));
end

function G = run_guo(opt, git, trim)
%RUN_GUO  REGISTER_P2 sec 46.3: Guo et al. (2020) four controllers on plant P2, circle_main (cap 4), as the
%  paper defines them (Remark 9 and the switch table of pa_configs): Classical {0,0,0} = (9),(16),(18) with
%  every estimate off; ESO {0,1,1}; DO {1,0,0}; MOBADC {1,1,1}; Guo's internal model DoHarm 1, no measured-
%  wind feed-forward (g_base). One pa_configs call per controller per segment. Per segment: mean and
%  within-segment STD of ||gamma - gamma_d|| over t >= 140 s (= Guo's ybar and s, Table 1, p. 9).
%  Sec 46.5: the split by axis from the same run (KeepTraj only exposes gamma / gamma_d; not stored):
%  horizontal RMS, vertical RMS and the mean vertical error of e = gamma_d - gamma over t >= 140 s.
%  Check: MOBADC must equal D2's L0 on every segment (|d| = 0). results/gd6/guo_p2.mat, resumable.
%  trim = true (sec 47, GUOTRIM): Classical+trim and DO+trim - the known payload weight -m_L g e3 added to
%  dmf_hat after the Remark 9 switch (P2TrimFF); results/gd6/guo_trim_p2.mat; report against the untrimmed
%  rows of guo_p2.mat (night 15).
if nargin < 3, trim = false; end
CT = {'Classical', {'0', '0', '0'}; 'ESO', {'0', '1', '1'}; 'DO', {'1', '0', '0'}; 'MOBADC', {'1', '1', '1'}};
if trim, CT = {'Classical+trim', {'0', '0', '0'}; 'DO+trim', {'1', '0', '0'}}; end
nc = size(CT, 1);
S = p2_segset('circle_main', 'CapPerDay', opt.CapPerDay, 'Quiet', true);
fprintf('  set circle_main, cap %d/day: %d segments, %d days, sha256 %s\n', opt.CapPerDay, S.n_seg, S.n_days, S.sha256);
if ~opt.DryRun
    sh = lower(strtrim(opt.Sha));
    assert(numel(sh) >= 16 && strncmp(S.sha256, sh, numel(sh)), 'run_p2_gd6 GUO: set SHA mismatch - not run.');
end
files = S.files;  days = S.day;
if opt.DryRun, files = files(1); days = days(1); end
tp = 0.290;  if ~isempty(opt.TauPred), tp = opt.TauPred; end   % not read: g_base has the predictor off
outf = fullfile(repo_root(), 'results', 'gd6', tern(trim, 'guo_trim_p2.mat', 'guo_p2.mat'));
key = struct('mode', tern(trim, 'GUOTRIM', 'GUO'), 'sha', S.sha256, 'ctrl', {CT(:, 1)'});
rows = struct('file', {}, 'day', {}, 'E', {}, 'SD', {}, 'EH', {}, 'EV', {}, 'EZ', {}, 'F', {}, 'p2', {});
if exist(outf, 'file') == 2 && ~opt.DryRun
    Z = load(outf, 'rows', 'key');
    assert(isequal(Z.key, key), 'run_p2_gd6 GUO: %s belongs to another set - not resumed.', outf);
    assert(isfield(Z.rows, 'EH'), 'run_p2_gd6 GUO: %s has no axis split (sec 46.5) - not resumed.', outf);
    rows = Z.rows;
end
fprintf('  Guo 2020 controllers %s | circle (Test 4), K 0.5, L 1.0, DoHarm 1, no wind feed-forward | %d segment(s), %d done\n', ...
    strjoin(CT(:, 1)', ' / '), numel(files), numel(rows));
base = [p2_args(), {'Cond', 'Test 4', 'L', 1.0, 'DoHarm', 1, 'Only', {'g_base'}, 'TauPred', tp, 'TauPrev', 0, ...
    'KeepTraj', true}];
if trim, base = [base, {'P2TrimFF', true}]; end
t0 = tic;  nNew = 0;
for i = 1:numel(files)
    fn = files{i};
    if any(strcmp({rows.file}, fn)), continue; end
    tc = tic;
    E = nan(1, nc);  SD = nan(1, nc);  EH = nan(1, nc);  EV = nan(1, nc);  EZ = nan(1, nc);
    F = cell(1, nc);  p2 = cell(1, nc);
    for c = 1:nc
        [~, M] = pa_configs(fn, base{:}, 'Switches', CT{c, 2});
        try, Simulink.sdi.clear; catch, end
        [E(c), F{c}] = one_value(M, 'g_base');
        m = M.g_base;
        if isfinite(E(c)) && isfield(m, 'std'), SD(c) = m.std; end
        if isfinite(E(c)) && isfield(m, 'gd'), [EH(c), EV(c), EZ(c)] = axis_split(m, 140); end
        if isfield(m, 'p2'), p2{c} = m.p2; end
    end
    rows(end + 1) = struct('file', fn, 'day', days{i}, 'E', E, 'SD', SD, 'EH', EH, 'EV', EV, 'EZ', EZ, ...
        'F', {F}, 'p2', {p2}); %#ok<AGROW>
    nNew = nNew + 1;
    ce = [CT(:, 1)'; num2cell(E)];
    fprintf('  [%3d/%3d] %-26s%s %s (%.0f s, ~%.0f min left)\n', i, numel(files), fn, sprintf(' %s %.4f', ce{:}), ...
        strjoin(F(~cellfun(@isempty, F)), ','), toc(tc), toc(t0) / nNew * (numel(files) - i) / 60);
    ce = [CT(:, 1)'; num2cell(EH); num2cell(EV); num2cell(EZ)];
    fprintf('            xy / z RMS, mean e_z:%s\n', sprintf('  %s %.4f / %.4f, %+.4f', ce{:}));
    if ~opt.DryRun
        if ~exist(fileparts(outf), 'dir'), mkdir(fileparts(outf)); end
        save(outf, 'rows', 'key', 'git');
    end
end
if trim
    G = struct('rows', rows, 'key', key, 'stats', guo_trim_report(rows, CT(:, 1)', opt));
else
    G = struct('rows', rows, 'key', key, 'stats', guo_report(rows, CT(:, 1)', opt));
end
end

function G = run_repool025(opt, git) %#ok<INUSD>
%RUN_REPOOL025  REGISTER_P2 sec 49.4 / 50.1 (user decision 2026-09-30): the m_p 0.25 tables on S40 (B1 at L 1.0,
%  sec 41.4; the corners (0.25, 0.5) and (0.25, 1.5), sec 49.2) re-pooled on the segments inside the A2 circle
%  envelope at K 0.5, m_p 0.25 (U <= 7.38 m/s, sec 4.4; python/p2_envelope.py --traj), from the saved per-segment
%  rows - nothing is simulated. Segments above 7.38 m/s are listed per segment (all four columns). The rows as
%  recorded stay; this is printed beside them ("static envelope used in error").
UMAX = 7.38;
S = p2_segset('S40', 'CapPerDay', 4, 'Quiet', true);
sh = lower(strtrim(opt.Sha));
assert(numel(sh) >= 16 && strncmp(S.sha256, sh, numel(sh)), 'run_p2_gd6 REPOOL025: S40 SHA mismatch - not run.');
out = find(S.U > UMAX);
fprintf('  S40 (sha %s): %d segments; A2 circle envelope K 0.5, m_p 0.25: U_max %.2f m/s -> %d segment(s) above:\n', ...
    S.sha256(1:16), S.n_seg, UMAX, numel(out));
for k = out(:)', fprintf('     %-28s U %.2f m/s  day %s\n', S.files{k}, S.U(k), S.day{k}); end
cols = {'L0', 'L2', 'L3', 'V'};
T = {'B1 m_p 0.25, L 1.0 (sec 41.4)', 'tab_circle_mp025_p2.mat'; ...
     'corner (0.25, 0.5) (sec 49.2)', 'tab_circle_mp025_L050_p2.mat'; ...
     'corner (0.25, 1.5) (sec 49.2)', 'tab_circle_mp025_L150_p2.mat'};
G = struct('umax', UMAX, 'above', {S.files(out)});
for t = 1:size(T, 1)
    f = fullfile(repo_root(), 'results', 'gd6', T{t, 2});
    fprintf('\n  ==== %s - %s\n', T{t, 1}, T{t, 2});
    if exist(f, 'file') ~= 2, fprintf('     not found - skipped\n'); continue; end
    Z = load(f, 'rows', 'key');
    assert(strncmp(Z.key.sha, S.sha256, 16) && isfield(Z.key, 'MP') && abs(Z.key.MP - 0.25) < 1e-9, ...
        'run_p2_gd6 REPOOL025: %s is not an m_p 0.25 table on S40.', T{t, 2});
    [tf, loc] = ismember({Z.rows.file}, S.files);
    assert(all(tf), 'run_p2_gd6 REPOOL025: a row of %s is not in S40.', T{t, 2});
    U = S.U(loc);  U = U(:);
    for i = find(U > UMAX)'
        ce = [cols; num2cell(Z.rows(i).E)];
        fprintf('     per segment (outside the envelope): %-28s U %.2f  %s\n', Z.rows(i).file, U(i), sprintf('%s %.4f  ', ce{:}));
    end
    fprintf('  -- inside the envelope (U <= %.2f): %d of %d rows\n', UMAX, sum(U <= UMAX), numel(U));
    G.(sprintf('t%d', t)) = tab_stats(Z.rows(U <= UMAX), cols);
end
end

function st = guo_trim_report(rows, cols, opt)
%GUO_TRIM_REPORT  sec 47 (descriptive): Classical+trim and DO+trim next to the night-15 rows (guo_p2.mat)
%  on the one set valid in all six columns; pooled norm, xy and z, mean e_z; each +trim row against its
%  untrimmed row and against MOBADC (pooled ratio - 1; SE; LOO; by-day).
st = struct();
f0 = fullfile(repo_root(), 'results', 'gd6', 'guo_p2.mat');
if exist(f0, 'file') ~= 2 || opt.DryRun
    E = reshape([rows.E], numel(cols), []).';  EZ = reshape([rows.EZ], numel(cols), []).';
    ce = [cols; num2cell(E(1, :)); num2cell(EZ(1, :))];
    fprintf('\n  sec 47 (guo_p2.mat not read%s): %s\n', tern(opt.DryRun, ', dry run', ' - not found'), ...
        sprintf('%s %.4f (mean e_z %+.4f)  ', ce{:}));
    return
end
Z = load(f0, 'rows', 'key');
[tf, loc] = ismember({rows.file}, {Z.rows.file});
assert(all(tf), 'guo_trim_report: %d segment(s) not in guo_p2.mat.', sum(~tf));
Z.rows = Z.rows(loc);
all6 = [Z.key.ctrl, cols];
cat6 = @(f) [reshape([Z.rows.(f)], 4, []).', reshape([rows.(f)], numel(cols), []).'];
E = cat6('E');  EH = cat6('EH');  EV = cat6('EV');  EZ = cat6('EZ');
ok = all(isfinite(E), 2);  day = {rows(ok).day}';
pool = @(e) sqrt(mean(e.^2, 1));
fprintf('\n  SEC 47 GUO CONTROLLERS WITH THE KNOWN PAYLOAD WEIGHT PRE-COMPENSATED - circle_main [descriptive]\n');
fprintf('  one set: %d of %d segments valid in all six columns\n', sum(ok), numel(ok));
P = pool(E(ok, :));  PH = pool(EH(ok, :));  PV = pool(EV(ok, :));  MZ = mean(EZ(ok, :), 1);
fprintf('  %-15s %10s %10s %10s %10s\n', 'controller', 'pooled', 'xy', 'z', 'mean e_z');
for c = 1:6, fprintf('  %-15s %10.5f %10.5f %10.5f %+10.5f\n', all6{c}, P(c), PH(c), PV(c), MZ(c)); end
pairs = {5, 1, 'Classical+trim vs Classical'; 6, 3, 'DO+trim vs DO'; 5, 4, 'Classical+trim vs MOBADC'; ...
    6, 4, 'DO+trim vs MOBADC'};
Ek = E(ok, :);
for k = 1:size(pairs, 1)
    a = pairs{k, 1};  b = pairs{k, 2};
    f = @(e) pool(e(:, a)) / pool(e(:, b)) - 1;
    [se, med, loo] = jk(f, Ek, day);
    fprintf('  %-28s %+7.2f %%  SE %.2f  LOO [%+.2f, %+.2f]  by-day %+.2f\n', pairs{k, 3}, 100 * f(Ek), 100 * se, ...
        100 * min(loo), 100 * max(loo), 100 * med);
end
st.P = P;  st.PH = PH;  st.PV = PV;  st.MZ = MZ;  st.ok = ok;
end

function st = guo_report(rows, cols, opt)
%GUO_REPORT  sec 46.3 report: check MOBADC = D2 L0; one set; Guo Table 1 layout (Mean +- STD) next to the
%  pooled RMS; each controller against Classical (pooled ratio, SE / LOO / by-day); tilt / motor saturation.
nc = numel(cols);
E = reshape([rows.E], nc, []).';  SD = reshape([rows.SD], nc, []).';
fd = fullfile(repo_root(), 'results', 'gd6', 'd2_p2.mat');
if exist(fd, 'file') == 2 && ~opt.DryRun
    Z = load(fd, 'rows');
    [tf, loc] = ismember({rows.file}, {Z.rows.file});
    L0 = nan(numel(rows), 1);  L0(tf) = arrayfun(@(k) Z.rows(k).E(1), loc(tf));
    d = abs(E(:, 4) - L0);
    same = all(d(tf) == 0 | (isnan(E(tf, 4)) & isnan(L0(tf))));
    fprintf('\n  check MOBADC = D2 L0 (same configuration) on %d shared segments: %s (max |d| %.3g)\n', sum(tf), ...
        tern(same, 'IDENTICAL', 'DIFFERS - recorded'), max(d(tf)));
end
ok = all(isfinite(E), 2);
day = {rows.day}';
fprintf('\n  SEC 46.3 GUO 2020 CONTROLLERS ON P2 - circle_main [descriptive, not a gate]\n');
fprintf('  one set: %d of %d segments valid in every column (%d removed)\n', sum(ok), numel(ok), sum(~ok));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
st = struct('n', sum(ok));
if sum(ok) < 2, fprintf('  fewer than 2 valid segments - statistics not computed\n'); return; end
Ek = E(ok, :);  dk = day(ok);
pool = @(e) sqrt(mean(e.^2, 1));
P = pool(Ek);
fprintf('  %-10s %10s %20s %s\n', 'controller', 'pooled', 'Mean +- STD (Guo)', '  vs Classical (pooled ratio - 1: value, SE, LOO, by-day)');
for c = 1:nc
    txt = '';
    if c > 1
        f = @(e) pool(e(:, c)) / pool(e(:, 1)) - 1;
        [se, med, loo] = jk(f, Ek, dk);
        txt = sprintf('%+7.2f %%  SE %.2f  LOO [%+.2f, %+.2f]  by-day %+.2f', 100 * f(Ek), 100 * se, 100 * min(loo), ...
            100 * max(loo), 100 * med);
    end
    fprintf('  %-10s %10.5f   %.4f +- %.4f   %s\n', cols{c}, P(c), mean(Ek(:, c)), mean(SD(ok, c)), txt);
end
fprintf('  (Guo 2020 Table 1, Test 4, indoor flight, for the layout only: Classical 0.1502 +- 0.0700, ESO 0.2054 +- 0.0205,\n');
fprintf('   DO 0.0725 +- 0.0480, MOBADC 0.0350 +- 0.0202 - different experiment, see docs/MOBADC_FIDELITY.md)\n');
TS = nan(numel(rows), nc);
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), TS(i, c) = p.tilt_sat_frac; end
    end
end
fprintf('  tilt_sat_frac max %s | segments > 1 %% %s\n', sprintf('%.4f ', max(TS(ok, :), [], 1)), ...
    sprintf('%d ', sum(TS(ok, :) > 0.01, 1)));
st.P = P;  st.mean = mean(Ek, 1);  st.std = mean(SD(ok, :), 1);  st.ok = ok;
% sec 46.5: the split by axis (descriptive)
EH = reshape([rows.EH], nc, []).';  EV = reshape([rows.EV], nc, []).';  EZ = reshape([rows.EZ], nc, []).';
H = EH(ok, :);  PH = pool(H);  PV = pool(EV(ok, :));  MZ = mean(EZ(ok, :), 1);
fprintf('\n  sec 46.5 split by axis (e = gamma_d - gamma, t >= 140 s; + e_z = UAV below its reference)\n');
fprintf('  %-10s %12s %12s %12s   %s\n', 'controller', 'pooled xy', 'pooled z', 'mean e_z', 'xy vs Classical (ratio - 1: value, SE, LOO, by-day)');
for c = 1:nc
    txt = '';
    if c > 1
        f = @(e) pool(e(:, c)) / pool(e(:, 1)) - 1;
        [se, med, loo] = jk(f, H, dk);
        txt = sprintf('%+7.2f %%  SE %.2f  LOO [%+.2f, %+.2f]  by-day %+.2f', 100 * f(H), 100 * se, 100 * min(loo), ...
            100 * max(loo), 100 * med);
    end
    fprintf('  %-10s %12.5f %12.5f %+12.5f   %s\n', cols{c}, PH(c), PV(c), MZ(c), txt);
end
fprintf('  (sec 46.3 prediction for Classical and DO: mean e_z ~ +0.125 m = m_L g / (m K_gamma,z))\n');
st.PH = PH;  st.PV = PV;  st.MZ = MZ;
end

function [eh, ev, ez] = axis_split(m, tstat)
%AXIS_SPLIT  sec 46.5: horizontal RMS, vertical RMS and mean vertical error of e = gamma_d - gamma over
%  t >= tstat, from the series pa_configs exposes with 'KeepTraj' (the same mask as its norm metric).
k = m.t(:) >= tstat;
e = m.gd(k, :) - m.g(k, :);
eh = sqrt(mean(e(:, 1).^2 + e(:, 2).^2));
ev = sqrt(mean(e(:, 3).^2));
ez = mean(e(:, 3));
end

function s = lev_text(opt)
%LEV_TEXT  The sec 42 level of a TAB call, for the header line.
s = '';
if ~isempty(opt.Imu), s = sprintf(', IMU noise x %g', opt.Imu); end
if ~isempty(opt.ThrustMax), s = sprintf(', plant max thrust %.2f N (F_TOT_MAX %.3f N)', opt.ThrustMax, 0.9 * opt.ThrustMax); end
if ~isempty(opt.Zeta), s = sprintf(', plant zeta_s %.2f', opt.Zeta); end
end

function [ec, ee] = sq_windows(et, par)
%SQ_WINDOWS  Mean tracking error in the corner and the edge half-cycle windows (REGISTER_P2 sec 33).
%  Square cycle Tc = T + T_h per corner (edge T from phase 0, dwell T_h at the corner reached); the
%  corner window is the half cycle centred on the dwell's middle (phase T + T_h/2 +- Tc/4), the edge
%  window the other half (centred on the edge's middle). et = pa_configs' e_t (t >= TStat, 10 ms).
T = par(2);  Th = par(3);  Tc = T + Th;
ph = mod(et.t(:) - (T + Th / 2), Tc);                  % 0 at the dwell's middle
d = min(ph, Tc - ph);                                   % circular distance to it
cw = d < Tc / 4;
ec = mean(et.v(cw));  ee = mean(et.v(~cw));
end

function st = tab_stats(rows, cols)
%TAB_STATS  REGISTER_P2 sec 0.2 / 6.6 on the one set (valid in every column): per column pooled,
%  SE (paired delete-one-day jackknife), by-day median, LOO [min, max], most influential segment;
%  the ratios L3/L2, V/L2, L2/L0 (descriptive, not a gate); tilt_sat_frac and motor sat_frac.
nc = numel(cols);
E = reshape([rows.E], nc, []).';
day = {rows.day}';
ok = all(isfinite(E), 2);
fprintf('\n  one set: %d of %d segments valid in every column (%d removed: crash / diverged / P2 flag)\n', ...
    sum(ok), numel(ok), sum(~ok));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
st = struct('n', sum(ok), 'n_days', numel(unique(day(ok))));
if st.n < 2, fprintf('  fewer than 2 valid segments - statistics not computed\n'); return; end
Ek = E(ok, :);  dk = day(ok);  fk = {rows(ok).file};
pooled = @(e) sqrt(mean(e.^2, 1));
q = {'pooled [m]', @(e) pooled(e); ...
     'L3/L2 - 1', @(e) pooled(e(:, 3)) / pooled(e(:, 2)) - 1; ...
     'V/L2 - 1', @(e) pooled(e(:, 4)) / pooled(e(:, 2)) - 1; ...
     'L2/L0 - 1', @(e) pooled(e(:, 2)) / pooled(e(:, 1)) - 1};
fprintf('  %d segments, %d days\n', st.n, st.n_days);
fprintf('  %-12s %-4s %9s %9s %9s %19s  %s\n', 'quantity', 'col', 'value', 'SE', 'by-day', 'LOO [min, max]', 'most influential');
for r = 1:size(q, 1)
    f = q{r, 2};  v = f(Ek);
    [se, med, loo, mi] = jk(f, Ek, dk);
    for j = 1:numel(v)
        lab = tern(numel(v) > 1, cols{j}, '');
        sc = tern(r == 1, 1, 100);
        fprintf('  %-12s %-4s %9.5f %9.5f %9.5f [%8.5f, %8.5f]  %s\n', q{r, 1}, lab, sc * v(j), sc * se(j), ...
            sc * med(j), sc * min(loo(:, j)), sc * max(loo(:, j)), fk{mi(j)});
    end
    nm = {'pooled', 'L3_L2', 'V_L2', 'L2_L0'};
    st.(nm{r}) = struct('v', v, 'se', se, 'day_median', med, 'loo', [min(loo, [], 1); max(loo, [], 1)]);
end
fprintf('  (ratios in %%; descriptive, not a gate)\n');
TS = nan(numel(rows), nc);  SF = TS;
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), TS(i, c) = p.tilt_sat_frac; end
        if isstruct(p) && isfield(p, 'sat_frac'), SF(i, c) = p.sat_frac; end
    end
end
fprintf('\n  per column over the one set: %s\n', sprintf(' %-9s', cols{:}));
fprintf('  tilt_sat_frac median       %s\n', sprintf('%-9.4f ', median(TS(ok, :), 1)));
fprintf('  tilt_sat_frac max          %s\n', sprintf('%-9.4f ', max(TS(ok, :), [], 1)));
fprintf('  segments with tilt_sat > 1%%%s\n', sprintf(' %-9d', sum(TS(ok, :) > 0.01, 1)));
fprintf('  motor sat_frac median      %s\n', sprintf('%-9.4f ', median(SF(ok, :), 1)));
fprintf('  motor sat_frac max         %s\n', sprintf('%-9.4f ', max(SF(ok, :), [], 1)));
st.tilt_sat = TS;  st.sat_frac = SF;  st.ok = ok;
end

function H = hmodel_report(rows, cols, sq)
%HMODEL_REPORT  sec 33: h_model = 1 - L3_6/L3 (pooled sqrt(mean(m^2))) on the table's one set and
%  on its unsaturated subset (tilt_sat_frac < 1 % in both L3 and L3_6), with SE (day jackknife),
%  by-day median, LOO, most influential segment and the registered reading; payload swing theta
%  RMS; square: the same h_model in the corner and the edge windows (side report, not read).
nc = numel(cols);
i3 = find(strcmp(cols, 'L3'));  i6 = find(strcmp(cols, 'L3_6'));
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
TS = nan(numel(rows), nc);  TH = TS;
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), TS(i, c) = p.tilt_sat_frac; end
        if isstruct(p) && isfield(p, 'theta_rms_stat_deg'), TH(i, c) = p.theta_rms_stat_deg; end
    end
end
uns = ok & TS(:, i3) < 0.01 & TS(:, i6) < 0.01;
fprintf('\n  h_model = 1 - L3_6/L3 (sec 33, exploratory; reading fixed before the run)\n');
fprintf('  one set %d segments; unsaturated subset (tilt_sat_frac < 1 %% in L3 and L3_6): %d\n', sum(ok), sum(uns));
for i = find(ok & ~uns)'
    fprintf('    left out (saturated): %-28s L3 %.4f L3_6 %.4f\n', rows(i).file, TS(i, i3), TS(i, i6));
end
H = struct();
sets = {'full', ok; 'unsaturated', uns};
for s = 1:2
    H.(sets{s, 1}) = hm_one(E(:, [i3 i6]), rows, sets{s, 2}, sets{s, 1}, true);
end
th = TH(ok, [i3 i6]);
fprintf('  payload swing theta RMS [deg], t >= TStat, pooled over the one set:  L3 %.2f  L3_6 %.2f\n', ...
    sqrt(mean(th(:, 1).^2)), sqrt(mean(th(:, 2).^2)));
fprintf('\n  READING (sec 33): full one set - %s | unsaturated subset - %s\n', H.full.reading, H.unsaturated.reading);
if sq
    fprintf('\n  side report (sec 33, not read): corner / edge half-cycle windows\n');
    Ec = reshape([rows.Ec], nc, []).';  Ee = reshape([rows.Ee], nc, []).';
    for s = 1:2
        H.([sets{s, 1} '_corner']) = hm_one(Ec(:, [i3 i6]), rows, sets{s, 2}, [sets{s, 1} ', corner window'], false);
        H.([sets{s, 1} '_edge']) = hm_one(Ee(:, [i3 i6]), rows, sets{s, 2}, [sets{s, 1} ', edge window'], false);
    end
end
end

function h = hm_one(E2, rows, m, label, rd)
%HM_ONE  h_model on the segments m of the two-column matrix [L3 L3_6], with the sec 0.2 statistics.
m = m & all(isfinite(E2), 2);
h = struct('n', sum(m), 'v', NaN, 'reading', 'not evaluable');
if sum(m) < 2, fprintf('  -- %s: fewer than 2 segments\n', label); return; end
e = E2(m, :);  day = {rows(m).day}';  fk = {rows(m).file};
f = @(x) 1 - sqrt(mean(x(:, 2).^2)) / sqrt(mean(x(:, 1).^2));
[se, med, loo, mi] = jk(f, e, day);
h = struct('n', sum(m), 'n_days', numel(unique(day)), 'L3', sqrt(mean(e(:, 1).^2)), ...
    'L3_6', sqrt(mean(e(:, 2).^2)), 'v', f(e), 'se', se, 'day_median', med, 'loo', [min(loo), max(loo)], ...
    'most_influential', fk{mi});
if h.v <= 0
    h.reading = 'DOES NOT ADD';
elseif all(loo > 0) && med > 0
    h.reading = 'ADDS';
else
    h.reading = 'UNCLEAR';
end
fprintf('  -- %s: n %d, days %d | L3 %.5f  L3_6 %.5f\n', label, h.n, h.n_days, h.L3, h.L3_6);
if ~rd, h.reading = 'side report, not read'; end
fprintf('     h_model %+8.2f%%  SE %.2f  LOO [%+.2f, %+.2f]%%  by-day median %+.2f%%  most influential %s%s\n', ...
    100 * h.v, 100 * se, 100 * h.loo, 100 * med, h.most_influential, tern(rd, ['  -> ' h.reading], ''));
end

function [se, med, loo, mi] = jk(f, E, day)
%JK  Delete-one-day jackknife SE, by-day median, leave-one-segment-out values, most influential.
v = f(E);  n = size(E, 1);
loo = nan(n, numel(v));
for i = 1:n, loo(i, :) = f(E([1:i-1, i+1:n], :)); end
ud = unique(day);  nd = numel(ud);  jd = nan(nd, numel(v));  dd = jd;
for j = 1:nd
    m = strcmp(day, ud{j});
    jd(j, :) = f(E(~m, :));  dd(j, :) = f(E(m, :));
end
se = sqrt((nd - 1) / nd * sum((jd - mean(jd, 1)).^2, 1));
med = median(dd, 1);
[~, mi] = max(abs(loo - v), [], 1);
end

function st = d2_stats(rows, cols)
%D2_STATS  REGISTER_P2 sec 0.2 / 0.5 on the set common to every column run.
E = reshape([rows.E], 4, []).';
day = {rows.day}';
ok = all(isfinite(E), 2);
fprintf('\n  one set: %d of %d segments valid in every column (%d removed: crash / diverged / P2 flag)\n', ...
    sum(ok), numel(ok), sum(~ok));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
E = E(ok, :);  day = day(ok);
st = struct('n', sum(ok), 'n_days', numel(unique(day)));
if st.n == 0, fprintf('  nothing to pool\n'); return; end
P = sqrt(mean(E.^2, 1));
for c = 1:numel(cols), fprintf('  %-3s pooled %.5f\n', cols{c}, P(c)); end
dfun = @(e) sqrt(mean(e(:, 3).^2)) / sqrt(mean(e(:, 2).^2)) - 1;   % Delta = L3/L2 - 1
Dl = dfun(E);
n = size(E, 1);  loo = nan(n, 1);
for i = 1:n, loo(i) = dfun(E([1:i-1, i+1:n], :)); end
ud = unique(day);  nd = numel(ud);  jd = nan(nd, 1);  dd = nan(nd, 1);
for j = 1:nd
    m = strcmp(day, ud{j});
    jd(j) = dfun(E(~m, :));
    dd(j) = dfun(E(m, :));
end
se = sqrt((nd - 1) / nd * sum((jd - mean(jd)).^2));
[~, iw] = max(abs(loo - Dl));
st.pooled = P;  st.Delta = Dl;  st.SE = se;  st.LOO = [min(loo), max(loo)];
ik = find(ok);
st.day_median = median(dd);  st.most_influential = rows(ik(iw)).file;
st.pass = Dl <= -0.30 && all(loo < 0);
if n < 2, st.pass = NaN; end                             % one segment (dry run): not evaluable
fprintf('\n  D2: Delta = L3/L2 - 1 = %+.1f%%  SE (day jackknife) %.1f pts  LOO [%+.1f, %+.1f]%%  by-day median %+.1f%%\n', ...
    100 * Dl, 100 * se, 100 * st.LOO, 100 * st.day_median);
fprintf('      most influential segment: %s\n', st.most_influential);
if isnan(st.pass), v = 'not evaluable (< 2 segments)'; else, v = tern(st.pass, 'PASS', 'FAIL'); end
fprintf('      D2 (sec 0.5: Delta <= -30%% AND every LOO Delta < 0): %s\n', v);
end

function d2_tilt_report(rows, cols, st)
%D2_TILT_REPORT  REGISTER_P2 sec 10.1 (secondary; the D2 gate above is unchanged):
%  tilt_sat_frac per segment and column, flag > 1 %, Delta on the one set minus flagged.
n = numel(rows);
TS = nan(n, 4);
for i = 1:n
    for c = 1:4
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), TS(i, c) = p.tilt_sat_frac; end
    end
end
E = reshape([rows.E], 4, []).';
ok = all(isfinite(E), 2);
flag = any(TS > 0.01, 2);
fprintf('\n  sec 10.1 (secondary) - tilt command at the 30 deg clamp, fraction of the run:\n');
fprintf('  %-28s %-10s %8s %8s %8s %8s  %s\n', 'segment', 'day', cols{:}, 'flag');
for i = 1:n
    fprintf('  %-28s %-10s %8.4f %8.4f %8.4f %8.4f  %s\n', rows(i).file, rows(i).day, TS(i, :), ...
        tern(flag(i), 'FLAG (> 1 %)', ''));
end
fprintf('  flagged: %d of %d segments (%d of them in the one set)\n', sum(flag), n, sum(flag & ok));
k = ok & ~flag;
if sum(k) < 2
    fprintf('  secondary Delta: fewer than 2 unflagged segments - not computed\n');
    return
end
Ek = E(k, :);
dfun = @(e) sqrt(mean(e(:, 3).^2)) / sqrt(mean(e(:, 2).^2)) - 1;
D = dfun(Ek);  m = size(Ek, 1);  loo = nan(m, 1);
for i = 1:m, loo(i) = dfun(Ek([1:i-1, i+1:m], :)); end
fprintf(['  secondary (not the gate): Delta without flagged segments = %+.1f%% (n = %d, LOO [%+.1f, %+.1f]%%)' ...
    ' vs registered %+.1f%% (n = %d)\n'], 100 * D, m, 100 * min(loo), 100 * max(loo), ...
    100 * getfield_or(st, 'Delta', NaN), getfield_or(st, 'n', NaN));
end

function v = getfield_or(s, f, d)
if isstruct(s) && isfield(s, f), v = s.(f); else, v = d; end
end

%% =====================================================================
%  sec 10.2 - i0251 tilt clamp: real wind vs wind = 0, i0000 for comparison
%% =====================================================================
function G = run_i0251(opt, git)
assert(~isempty(opt.TauPred), 'run_p2_gd6 I0251: TauPred (tau*_hover from N0P) must be given explicitly.');
C = conditions('N0P');  c = C(strcmp({C.label}, 'hover'));
im = im_args(c);
segs = {'wind_real_t150_i0251.mat', 'wind_real_t150_i0000.mat'};
winds = [false true];                                    % WindZero off / on
cols = {'g_sens', 'g_psens'};  lab = {'L2', 'L3'};
pa = p2_args();
fprintf('  sec 10.2: hover, %s, TauPred %.0f ms, segments i0251 / i0000, real wind vs wind = 0\n', ...
    im_text(im), 1000 * opt.TauPred);
rows = struct('seg', {}, 'wind', {}, 'col', {}, 'stable', {}, 'tilt_sat', {}, 'tilt_sat_stat', {}, ...
    'tilt_ge', {}, 'amp_deg', {}, 'rms_deg', {}, 'f_hz', {}, 'err', {});
for s = 1:numel(segs)
    for w = 1:numel(winds)
        tc = tic;
        [R, M] = pa_configs(segs{s}, pa{:}, 'Only', cols, 'Cond', c.cond, 'L', c.L, im{:}, ...
            'TauPred', opt.TauPred, 'TauPrev', 0, 'KeepLog', {'eta_log'}, 'WindZero', winds(w));
        try, Simulink.sdi.clear; catch, end
        for j = 1:2
            [v, fl] = one_value(M, cols{j});
            r = struct('seg', segs{s}(end-8:end-4), 'wind', tern(winds(w), 'zero', 'real'), 'col', lab{j}, ...
                'stable', isempty(fl), 'tilt_sat', NaN, 'tilt_sat_stat', NaN, 'tilt_ge', NaN, ...
                'amp_deg', [NaN NaN], 'rms_deg', [NaN NaN], 'f_hz', [NaN NaN], 'err', v);
            m = M.(cols{j});
            if isfield(m, 'p2') && isfield(m.p2, 'tilt_sat_frac')
                r.tilt_sat = m.p2.tilt_sat_frac;  r.tilt_sat_stat = m.p2.tilt_sat_frac_stat;
            end
            if isfield(R, cols{j}) && isfield(R.(cols{j}), 'log') && isfield(R.(cols{j}).log, 'eta_log') ...
                    && R.(cols{j}).log.eta_log.ok
                [r.tilt_ge, r.amp_deg, r.rms_deg, r.f_hz] = att_osc(R.(cols{j}).log.eta_log, 140);
            end
            rows(end + 1) = r; %#ok<AGROW>
        end
        fprintf('    %s wind %-4s done (%.0f s)\n', segs{s}(end-8:end-4), tern(winds(w), 'zero', 'real'), toc(tc));
    end
end
fprintf('\n  seg    wind col stable tilt_sat  (t>=140)  tilt>=30  amp roll/pitch [deg]  rms roll/pitch  f roll/pitch [Hz]  err[m]\n');
for r = rows
    fprintf('  %s  %-4s %-3s %-6s %7.4f  %7.4f   %7.4f   %6.2f %6.2f         %5.2f %5.2f     %5.3f %5.3f      %7.4f\n', ...
        r.seg, r.wind, r.col, tern(r.stable, 'yes', 'NO'), r.tilt_sat, r.tilt_sat_stat, r.tilt_ge, ...
        r.amp_deg, r.rms_deg, r.f_hz, r.err);
end
k = strcmp({rows.seg}, 'i0251') & strcmp({rows.wind}, 'zero');
ts = max([rows(k).tilt_sat]);
if ts < 0.001
    v = '(a) the clamp comes from the wind (gusts): with wind = 0 it is gone (< 0.1 %)';
elseif ts >= 0.01
    v = '(b) the attitude loop oscillates on its own, held by the 30 deg clamp (>= 1 % with wind = 0) -> STOP before GD7, report to the user';
else
    v = 'between 0.1 % and 1 % with wind = 0 - not decided by this round; report to the user';
end
fprintf('\n  Reading (REGISTER_P2 sec 10.2): i0251, wind = 0, max tilt_sat over L2/L3 = %.4f\n    -> %s\n', ts, v);
G = struct('rows', rows, 'reading', v, 'git', git, 'TauPred', opt.TauPred);
if ~opt.DryRun
    outf = fullfile(repo_root(), 'results', 'gd6', 'i0251_diag.mat');
    if ~exist(fileparts(outf), 'dir'), mkdir(fileparts(outf)); end
    save(outf, 'G');
    fprintf('  saved %s\n', outf);
end
end

function [ge, amp, rmsd, f] = att_osc(L, tw)
%ATT_OSC  Actual tilt >= 30 deg fraction (whole run); roll/pitch oscillation about the mean
%  in t >= tw: peak amplitude and RMS [deg], dominant frequency [Hz] (FFT peak, DC excluded).
t = L.t(:);  x = L.v(:, 1:2);
ge = mean(max(abs(x), [], 2) >= 30 * pi / 180);
w = t >= tw;
y = x(w, :) - mean(x(w, :), 1);
amp = rad2deg(max(abs(y), [], 1));
rmsd = rad2deg(sqrt(mean(y.^2, 1)));
n = size(y, 1);  dt = median(diff(t(w)));
F = abs(fft(y));  fr = (0:n - 1).' / (n * dt);  h = 2:floor(n / 2);
[~, i1] = max(F(h, 1));  [~, i2] = max(F(h, 2));
f = [fr(h(i1)), fr(h(i2))];
end


%% =====================================================================
%  sec 8.2 - hover / T5 with the standard initial condition
%% =====================================================================
function G = run_icdiag(opt, git)
files = p2_fixed5('Quiet', true);
C = conditions('N0P');
C = C(ismember({C.label}, {'hover', 'T5'}));
taus = [0 0.200];
cols = {'g_sens', 'g_psens'};  lab = {'L2', 'L3'};
fprintf('  sec 8.2: %s x %d segments x TauPred %s ms x columns L2/L3, nominal P2, standard IC\n', ...
    strjoin({C.label}, '/'), numel(files), mat2str(1000 * taus));
rows = struct('cond', {}, 'file', {}, 'tau', {}, 'col', {}, 'stable', {}, 't_stop', {}, 'block', {}, ...
              'err', {}, 'T_min', {}, 'tilt_sat', {}, 'sat', {});
pa = p2_args();
for i = 1:numel(C)
    c = C(i);  im = im_args(c);
    fprintf('\n  [%s] Cond %s, %s\n', c.label, c.cond, im_text(im));
    for k = 1:numel(taus)
        for f = 1:numel(files)
            tc = tic;
            [~, M] = pa_configs(files{f}, pa{:}, 'Only', cols, 'Cond', c.cond, 'L', c.L, im{:}, ...
                'TauPred', taus(k), 'TauPrev', 0);
            try, Simulink.sdi.clear; catch, end
            for j = 1:2
                m = M.(cols{j});
                [v, fl] = one_value(M, cols{j});
                r = struct('cond', c.label, 'file', files{f}, 'tau', taus(k), 'col', lab{j}, ...
                    'stable', isempty(fl), 't_stop', NaN, 'block', '', 'err', v, 'T_min', NaN, ...
                    'tilt_sat', NaN, 'sat', NaN);
                if isfield(m, 'crash_msg') && ~isempty(m.crash_msg)
                    tk = regexp(m.crash_msg, 'at time ([0-9.eE+-]+)', 'tokens', 'once');
                    bk = regexp(m.crash_msg, 'block ''([^'']+)''', 'tokens', 'once');
                    if ~isempty(tk), r.t_stop = str2double(tk{1}); end
                    if ~isempty(bk), r.block = strrep(bk{1}, 'baseline1/', ''); end
                end
                if isfield(m, 'p2')
                    r.T_min = m.p2.T_min;  r.sat = m.p2.sat_frac;
                    if isfield(m.p2, 'tilt_sat_frac'), r.tilt_sat = m.p2.tilt_sat_frac; end
                end
                if ~r.stable && isempty(r.block), r.block = fl; end
                rows(end + 1) = r; %#ok<AGROW>
            end
            fprintf('    tau %3.0f ms  %s  L2 %-10s L3 %-10s (%.0f s)\n', 1000 * taus(k), files{f}(end-8:end-4), ...
                cell_text(rows(end-1)), cell_text(rows(end)), toc(tc));
        end
    end
end
fprintf('\n  cond   seg    tau  col stable  t_stop  block                      err[m]   T_min  tilt_sat  sat\n');
for r = rows
    fprintf('  %-6s %s %4.0f  %-3s %-6s %7.2f  %-24s %8.4f  %6.3f  %6.4f  %5.3f\n', r.cond, r.file(end-8:end-4), ...
        1000 * r.tau, r.col, tern(r.stable, 'yes', 'NO'), r.t_stop, r.block, r.err, r.T_min, r.tilt_sat, r.sat);
end
fprintf('\n  Reading (REGISTER_P2 sec 8.2, fixed before the run):\n');
for i = 1:numel(C)
    m = strcmp({rows.cond}, C(i).label);
    ns = sum([rows(m).stable]);
    if ns == sum(m)
        v = 'no divergence in any run -> cause = start-up (IC error); standard IC stays, condition enters GD6';
    else
        v = sprintf('%d of %d runs diverged -> steady-state instability of Guo''s gains on P2 -> direction 2', ...
            sum(m) - ns, sum(m));
    end
    fprintf('    %-6s %s\n', C(i).label, v);
end
G = struct('rows', rows, 'git', git);
if ~opt.DryRun
    outf = fullfile(repo_root(), 'results', 'gd6', 'icdiag.mat');
    if ~exist(fileparts(outf), 'dir'), mkdir(fileparts(outf)); end
    save(outf, 'G');
    fprintf('  saved %s\n', outf);
end
end

function s = cell_text(r)
if r.stable, s = sprintf('%.4f', r.err); else, s = sprintf('stop %.1f', r.t_stop); end
end

%% =====================================================================
function save_rows(outf, T) %#ok<INUSD>
if ~exist(fileparts(outf), 'dir'), mkdir(fileparts(outf)); end
save(outf, 'T');
end

function s = im_text(im)
if strcmp(im{1}, 'DoHarm'), s = sprintf('DoHarm %s', mat2str(im{2}));
else, s = ['DoWAxis {' strjoin(cellfun(@(w) mat2str(w, 4), im{2}, 'UniformOutput', false), ', ') '}']; end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
