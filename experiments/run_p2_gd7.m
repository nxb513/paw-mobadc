function G = run_p2_gd7(group, varargin)
%RUN_P2_GD7  GĐ7 = CỔNG G on plant P2 (docs/REGISTER_P2.md sec 0.6, 0.8, 13.4, 15).
%
%   run_p2_gd7('N4b-P2-base', 'TauW', tw, 'TauPred', 0.290, 'Sha', 'a227e9d87a2ac436')
%   run_p2_gd7(<group>, ..., 'DryRun', true)     % 1 segment, every column run, nothing saved
%   run_p2_gd7(<group>, 'Report', true)           % re-print the group from results/gd7/<group>.mat
%   run_p2_gd7(<group>, 'Recheck', {files})       % re-run the given segments with today's model and
%                                                 % compare with results/gd7/<group>.mat at FULL
%                                                 % precision (N6 block: N6 term off must be bit-exact)
%   run_p2_gd7('N6', 'TauW', tau6, 'TauPred', 0, 'Sha', '43226c02...')   % group #10 (sec 15.4, 18.2)
%   run_p2_gd7('N6X-circle', 'TauW', 0.020, 'TauPred', 0.290, 'TauN6', 0.290, 'Sha', 'a227e9d87a2ac436')
%   run_p2_gd7('N6X-T5', 'TauW', 0.020, 'TauPred', 0.170, 'TauN6', 0.170, 'Sha', '4a933e516acfcb10')
%                                                 % sec 28.2 exploratory: L3 vs L3_6 (N6 term with the
%                                                 % measured wind on top of the DO prediction), h_model
%   run_p2_gd7('F-hover', 'TauW', 0.280, 'TauPred', 0, 'Sha', <S40hover sha>)
%                                                 % sec 39 (F1-F3): L3_6 with the controller-side
%                                                 % parameters scaled (L, m_L, C_D*A), plant nominal;
%                                                 % L3, L3_6 reused from N6; h_model per variant
%   run_p2_gd7('F3-diag', 'TauW', 0.280, 'TauPred', 0, 'Sha', '53facf03712c81ee')
%                                                 % sec 42 (F3 diagnostic, one round): C_D*A of the
%                                                 % payload (N6 kL) and of the body (p2_prm_w) scaled
%                                                 % separately; DC share of the error and mean N6 delta
%                                                 % per column; reproduction of F-hover; reading sec 42.2
%   run_p2_gd7('SN-hover', 'TauW', 0.280, 'TauPred', 0, 'Sha', '53facf03712c81ee', 'DataDir', 'wind_sn010')
%                                                 % sec 43.2: L3, L3_6 on S40hover with the wind sensor
%                                                 % noise 0.1 m/s (noisy files in DataDir); h_model + the
%                                                 % change against N6's sigma-0 values; reading sec 43.2
%   run_p2_gd7('C2-circle', 'TauW', 0.280, 'TauPred', 0.290, 'H3Hz', 32, 'Sha', <sha>, 'Conf2', 'wind_conf2')
%                                                 % sec 60.8 (GD10, CONFIRM2 only): C2-circle / C2-hover /
%                                                 % C2-hhover on the CONFIRM2 sets, results/gd10/; indices
%                                                 % of sec 60.4 stored per column (rows.Q)
%   run_p2_gd7('C2-circle', ..., 'DevTest', true) % the same chain on the first NDev dev segments of the
%                                                 % rule's dev set, results/gd10_devtest/ (plumbing test)
%   run_p2_gd7('six-circle', 'TauW', 0.280, 'TauPred', 0.290, 'H3Hz', 32, 'Sha', 'a227e9d87a2ac436')
%                                                 % sec 63.1 (dev circle_main only): L3_iii0 run, L3 from
%                                                 % D2 and H3 from H3-circle (spot-checked); within-segment
%                                                 % STD (rows.SD) and sec 60.4 indices (rows.Q) stored;
%                                                 % 'six-circle-h3': H3 re-run too (its STD / indices)
%   run_p2_gd7(<group>, 'Side', true)             % sec 26 side report from the saved results: the
%                                                 % unsaturated subset (tilt_sat_frac < 1 % in every
%                                                 % column); N6: h_6, c_6, h_model; #11/#12: "post hoc"
%
%  One group = one registered set (core/p2_segset.m, cap 4 per day, SHA checked) and one
%  configuration; columns (sec 0.3):
%     L3   g_psens  measured wind (50 ms late, noisy) + payload prediction at TauPred
%     P    g_both   PI-MoE w_hat(t + 150 | t), input as late as the sensor (PredDelay, sec 13.2)
%     O    g_orac   true wind w(t + tau_w*)  (OracleTauMs = TauW, from N0W)
%     O0   g_orac   true current wind w(t)   (report only)
%     O150 g_orac   true wind w(t + 150 ms)  (report only; N4b-P2-base only, amendment sec 15.2)
%  Group N6 (sec 15.4, 18.2; hover, K 0.5): the same wind signals with the N6 term ON, horizon
%  TauW = tau_6*:  L3_6 (sensor), P_6 (PI-MoE), O_6 (w(t + tau_6*)), O6_0 (w(t), report only);
%  and L3 (no N6 term, report only). Gate on h_6 = 1 - O_6/L3_6, c_6 (sec 0.6 tests).
%  Everything else identical across columns (nominal P2, K, L, sensor delay, IM, TauPred).
%
%  Reuse (sec 15.1): values already run for the SAME segment and the SAME configuration are
%  taken from the source (D2's L3 for N4b-P2-base; N4b-P2-base's O/O0 for d200; N4b-P2-base's
%  L3/P/O/O0 for the N5-B segments shared with circle_main). Before any reuse the runner
%  re-runs the first shared segment's reused columns: every printed digit (%.4f) must match
%  the source, otherwise that source is not used and every column is run.
%
%  Output per segment and the sec 0.6 table: pooled per column on the one set, h, c,
%  h_sensor, h_pred (+ h(150), c(150) where O150 exists), each with SE (paired delete-one-day
%  jackknife), by-day median, LOO [min, max], most influential segment; headroom / capture /
%  data sufficiency verdicts and the two sec 0.6 reading notes.
opt = struct('TauW', [], 'TauPred', [], 'Sha', '', 'CapPerDay', 4, 'DryRun', false, 'Report', false, ...
             'Recheck', {{}}, 'Side', false, 'TauN6', [], 'DataDir', '', 'TauM3', [], 'H3Hz', [], ...
             'Conf2', '', 'DevTest', false, 'NDev', 2, 'Shard', []);   % Shard: rerun/ (2026-10-05)
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'run_p2_gd7: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
setup_path();
[st, gh] = system('git rev-parse --short HEAD');  if st ~= 0, gh = 'unknown'; end
git = strtrim(gh);
g = group_def(group);
cm = ~isempty(opt.Conf2) || opt.DevTest;                % sec 60.8: CONFIRM2 (or its dev test)
assert(g.c2 == cm && ~(~isempty(opt.Conf2) && opt.DevTest), ['run_p2_gd7: the C2-* groups run only with ' ...
    'Conf2 or DevTest, and Conf2 / DevTest only with them (REGISTER_P2 sec 60.8).']);
outd = fullfile(repo_root(), 'results', 'gd7');
cn = '';
if ~isempty(opt.Conf2)                                  % gd10 (CONFIRM2) / gd12 (CONFIRM3, REGISTER_FINAL sec 6)
    cs = confirm_set(opt.Conf2);  cn = [' (' cs.name ')'];
    outd = fullfile(repo_root(), 'results', cs.outdir);
end
if opt.DevTest, outd = fullfile(repo_root(), 'results', 'gd10_devtest'); end
outf = fullfile(outd, [g.name '.mat']);
fprintf('\nrun_p2_gd7 %s | git %s%s\n', g.name, git, tern(opt.DryRun, ' | DRY RUN - nothing saved', ''));
if opt.Report
    Z = load(outf, 'rows', 'key');
    G = report(g, Z.rows, Z.key);
    return
end
if ~isempty(opt.Recheck)
    G = recheck(g, outf, opt.Recheck);
    return
end
if opt.Side
    Z = load(outf, 'rows', 'key');
    G = side_report(g, Z.rows, Z.key);
    return
end
if isempty(opt.TauN6), opt.TauN6 = opt.TauW; end      % N6: horizon = tau_6* (sec 18.2)
assert(~isempty(opt.TauW) && ~isempty(opt.TauPred), ['run_p2_gd7: TauW (tau_w* from N0W) and TauPred ' ...
    '(payload tau* of this condition) must be given explicitly, as transcribed in REGISTER_P2.']);
sarg = {'CapPerDay', opt.CapPerDay, 'Quiet', true};
if ~isempty(opt.Conf2), sarg = [sarg, {'Confirm2', opt.Conf2}]; end
S = p2_segset(g.set, sarg{:});
fprintf('  group %s: set %s%s, cap %d/day: %d segments, %d days, sha256 %s\n', g.name, g.set, ...
    cn, opt.CapPerDay, S.n_seg, S.n_days, S.sha256);
if ~opt.DryRun && ~opt.DevTest
    sh = lower(strtrim(opt.Sha));
    assert(numel(sh) >= 16 && strncmp(S.sha256, sh, numel(sh)), ['run_p2_gd7: the set''s SHA-256 (%s) ' ...
        'does not match the registered one (REGISTER_P2 sec 6.3.1) - not run.'], S.sha256);
end
key = struct('group', g.name, 'sha', S.sha256, 'TauW', opt.TauW, 'TauPred', opt.TauPred, 'K', g.K, ...
    'L', g.L, 'delay', g.delay, 'cond', g.cond, 'cols', {g.cols});
assert(isempty(opt.DataDir) == ~(g.sn || g.spk), ['run_p2_gd7: DataDir is required by, and only by, the ' ...
    'wind-sensor-noise groups (sec 43) and the spike-filter groups (rerun/).']);
if g.sn || g.spk
    assert(exist(opt.DataDir, 'dir') == 7, 'run_p2_gd7: DataDir %s not found.', opt.DataDir);
    if g.sn, sn_check_dir(opt.DataDir); else, spk_check_dir(opt.DataDir); end
    key.DataDir = opt.DataDir;
end
if ~isempty(opt.Conf2), key.Conf2 = opt.Conf2; end      % sec 60.8 (absent on every dev key)
if opt.DevTest, key.DevTest = opt.NDev; end
if g.explore, key.TauN6 = opt.TauN6; end              % sec 28.2 (N6 itself: TauN6 = TauW)
if g.m3                                                 % sec 45: tau_m* from N0M3, explicit
    assert(~isempty(opt.TauM3), 'run_p2_gd7 %s: TauM3 (tau_m* of N0M3, REGISTER_P2 sec 45.1) must be given.', g.name);
    key.TauM3 = opt.TauM3;
end
if g.h3                                                 % sec 50: omega_f* from N0H3, explicit
    assert(~isempty(opt.H3Hz), 'run_p2_gd7 %s: H3Hz (omega_f* of N0H3, REGISTER_P2 sec 50) must be given.', g.name);
    key.H3Hz = opt.H3Hz;
end
files = S.files;  days = S.day;
if opt.DryRun, files = files(1); days = days(1); end
if opt.DevTest, files = files(1:min(opt.NDev, end)); days = days(1:numel(files)); end
[files, days, outf] = shard_files(files, days, outf, opt.Shard);
im = im_args(g);
fprintf(['  %s, K %.2f, L %.1f, sensor delay %d ms, %s | columns %s | TauPred %.0f ms, tau_w* %.0f ms | ' ...
    '%d segment(s)\n'], g.cond, g.K, g.L, g.delay, im_text(im), strjoin(g.cols, ' '), 1000 * opt.TauPred, ...
    1000 * opt.TauW, numel(files));
nc = numel(g.cols);
rows = struct('file', {}, 'day', {}, 'E', {}, 'F', {}, 'p2', {}, 'src', {});
if g.diag, rows = struct('file', {}, 'day', {}, 'E', {}, 'F', {}, 'p2', {}, 'src', {}, 'X', {}); end
if g.c2, rows = struct('file', {}, 'day', {}, 'E', {}, 'F', {}, 'p2', {}, 'src', {}, 'Q', {}); end
if g.six, rows = struct('file', {}, 'day', {}, 'E', {}, 'F', {}, 'p2', {}, 'src', {}, 'Q', {}, 'SD', {}); end   % sec 63.1
if exist(outf, 'file') == 2 && ~opt.DryRun
    Z = load(outf, 'rows', 'key');
    assert(isequal(Z.key, key), 'run_p2_gd7: %s belongs to another set/configuration - not resumed.', outf);
    rows = Z.rows;
    fprintf('  resuming: %d segment(s) already in %s\n', numel(rows), outf);
end
% ---- reuse sources (sec 15.1), each spot-checked once ----
R = struct('name', {}, 'cols', {}, 'val', {});
if ~opt.DryRun
    R = load_sources(g, key, files, outd);
    pend = setdiff(files, {rows.file});               % segments still to run
    for r = 1:numel(R)
        if ~any(ismember(pend, R(r).val.file))
            R(r).ok = false;                          % nothing left that would use it
            continue
        end
        R(r) = spot_check(R(r), g, files, days, opt, im);
    end
end
t0 = tic;  nNew = 0;
[~, qn] = p2_indices([]);  nq = numel(qn);              % sec 60.4 index count
for i = 1:numel(files)
    fn = files{i};
    if any(strcmp({rows.file}, fn)), continue; end
    tc = tic;
    E = nan(1, nc);  F = repmat({''}, 1, nc);  p2 = cell(1, nc);  src = repmat({'run'}, 1, nc);
    Q = nan(nq, nc);                                    % sec 60.4 indices (C2 groups)
    SD = nan(1, nc);                                    % sec 63.1: within-segment STD (six-circle groups)
    for r = 1:numel(R)                                  % reused values
        if ~R(r).ok, continue; end
        k = find(strcmp(R(r).val.file, fn), 1);
        if isempty(k), continue; end
        for c = find(ismember(g.cols, R(r).cols))
            j = strcmp(R(r).val.cols, g.cols{c});
            E(c) = R(r).val.E(k, j);  F{c} = R(r).val.F{k, j};  p2{c} = R(r).val.p2{k, j};
            if isfield(R(r).val, 'Q'), Q(:, c) = R(r).val.Q(:, k, j); end
            src{c} = R(r).name;
        end
    end
    need = g.cols(strcmp(src, 'run'));
    [Er, Fr, Pr, Xr, Qr, SDr] = run_cols(fn, need, g, opt, im);
    X = nan(4, nc);
    for c = find(strcmp(src, 'run'))
        j = strcmp(need, g.cols{c});
        E(c) = Er(j);  F{c} = Fr{j};  p2{c} = Pr{j};  X(:, c) = Xr(:, j);  Q(:, c) = Qr(:, j);  SD(c) = SDr(j);
    end
    r = struct('file', fn, 'day', days{i}, 'E', E, 'F', {F}, 'p2', {p2}, 'src', {src});
    if g.diag, r.X = X; end
    if g.c2 || g.six, r.Q = Q; end
    if g.six, r.SD = SD; end
    rows(end + 1) = r; %#ok<AGROW>
    nNew = nNew + 1;
    el = toc(t0);
    nre = sum(~strcmp(src, 'run'));
    fprintf('  [%3d/%3d] %-26s %s%s (%.0f s, ~%.0f min left)\n', i, numel(files), fn, vals_text(g.cols, E, F), ...
        tern(nre > 0, sprintf(' [%d reused]', nre), ''), toc(tc), el / nNew * (numel(files) - i) / 60);
    if ~opt.DryRun
        if ~exist(outd, 'dir'), mkdir(outd); end
        save(outf, 'rows', 'key', 'git');
    end
end
G = report(g, rows, key);
G.rows = rows;  G.key = key;
if strcmp(g.name, 'N4b-P2-base') && ~opt.DryRun, d2_combined(rows, key); end
end

%% =====================================================================
function g = group_def(name)
%GROUP_DEF  The registered CỔNG G groups (sec 0.8, A3 sec 5.2; columns sec 13.4, 15.2).
d = struct('name', name, 'set', name, 'cond', 'Test 4', 'K', 0.5, 'L', 1.0, 'delay', 50, ...
    'cols', {{'L3', 'P', 'O', 'O0'}}, 'reuse', {{}}, 'hover', false, 'n6', false, 'imtable', false, ...
    'explore', false, 'fsens', false, 'diag', false, 'sn', false, 'm3', false, 'd2sub', false, 'h3', false, ...
    'st', false, 'c2', false, 'six', false, 'spk', false);
switch name
    % ---- rerun/ (2026-10-05): checks of the static (1 + K-hat) feed-forward (iii-0), descriptive ----
    case 'static-circle-k'                             % K-hat x 0.7 / x 1.3 on the circle (S40), as static-hover-k
        d.set = 'S40';  d.d2sub = true;  d.st = true;
        d.cols = {'L3', 'L3_iii0', 'L3_iii0_k070', 'L3_iii0_k130'};
        d.reuse = {{'D2', {'L3'}}, {'static-circle', {'L3_iii0'}}};
    case {'static-circle-sn', 'static-hover-sn'}       % wind-sensor noise 0.1 m/s (files of sec 43.3 in DataDir)
        d.st = true;  d.sn = true;  d.cols = {'L3', 'L3_iii0'};
        d.set = 'S40';
        if strcmp(name, 'static-hover-sn'), d.set = 'S40hover';  d.cond = 'Hover';  d.hover = true; end
    case {'static-circle-spk', 'static-hover-spk'}     % spike filter on the measured wind (files in DataDir)
        d.st = true;  d.spk = true;  d.cols = {'L3', 'L3_iii0'};
        d.set = 'circle_main';
        if strcmp(name, 'static-hover-spk'), d.set = 'N6_hover';  d.cond = 'Hover';  d.hover = true; end
    case 'N4b-P2-base'
        d.set = 'circle_main';  d.cols = {'L3', 'P', 'O', 'O0', 'O150'};
        d.reuse = {{'D2', {'L3'}}};
    case 'N4b-P2-d200'
        d.set = 'circle_main';  d.delay = 200;
        d.reuse = {{'N4b-P2-base', {'O', 'O0'}}};        % the O columns do not read the sensor
    case 'N4b-P2-L15'
        d.set = 'circle_main';  d.L = 1.5;
    case 'N4b-P2-K10'
        d.K = 1.0;
    case {'N5-A-Weak', 'N5-A-Medium', 'N5-A-StrongRel'}
        d.K = 0;
    case {'N5-B-Weak', 'N5-B-Medium'}
        d.reuse = {{'N4b-P2-base', {'L3', 'P', 'O', 'O0'}}};   % shared segments only
    case 'N5-H-StrongRel'
        d.K = 0;  d.cond = 'Hover';  d.hover = true;
    case 'N6'                                          % group #10, sec 15.4 / 18.2
        d.set = 'N6_hover';  d.cond = 'Hover';  d.hover = true;  d.n6 = true;
        d.cols = {'L3_6', 'P_6', 'O_6', 'O6_0', 'L3'};
    case {'N6X-circle', 'N6X-circle-tm'}               % sec 28.2, exploratory (not a gate)
        d.set = 'circle_main';  d.explore = true;  d.cols = {'L3', 'L3_6'};
        d.reuse = {{'N4b-P2-base', {'L3'}}};
        if strcmp(name, 'N6X-circle-tm'), d.reuse = {{'N6X-circle', {'L3'}}}; end
    case 'F-hover'                                     % sec 39, F1-F3 (sensitivity, not a gate)
        d.set = 'S40hover';  d.cond = 'Hover';  d.hover = true;  d.n6 = true;  d.fsens = true;
        d.cols = [{'L3', 'L3_6'}, strcat('L3_6_', {'L080', 'L090', 'L110', 'L120', 'm080', 'm120', 'c070', 'c130'})];
        d.reuse = {{'N6', {'L3', 'L3_6'}}};
    case 'SN-hover'                                    % sec 43.2: wind-sensor noise 0.1 m/s (no gate)
        d.set = 'S40hover';  d.cond = 'Hover';  d.hover = true;  d.n6 = true;  d.sn = true;
        d.cols = {'L3', 'L3_6'};
    case 'F3-diag'                                     % sec 42, the one F3 diagnostic round (no gate)
        d.set = 'S40hover';  d.cond = 'Hover';  d.hover = true;  d.n6 = true;  d.diag = true;
        d.cols = [{'L3', 'L3_6'}, strcat('L3_6_', {'c070', 'c130', 'cP070', 'cP130', 'cB070', 'cB130'}), ...
            {'L3_cB070', 'L3_cB130'}];                  % every column run (DC share needs the time series)
    case 'iii-hover'                                   % sec 45.3: acceptance of (iii) + comparison variants
        d.set = 'S40hover';  d.cond = 'Hover';  d.hover = true;  d.m3 = true;
        d.cols = [{'L3', 'L3_iii'}, strcat('L3_iii_', {'L080', 'L120', 'm080', 'm120', 'cP070', 'cP130', ...
            'cB070', 'cB130'}), {'L3_iii0'}];         % sec 50: the 9 + sigma variants; sec 52: + (iii-0) (comparison)
        d.reuse = {{'F-hover', {'L3'}}};
    case 'iii-hover-sn'                                % sec 45.3: the sigma 0.1 variant (files of sec 43.3)
        d.set = 'S40hover';  d.cond = 'Hover';  d.hover = true;  d.m3 = true;  d.sn = true;
        d.cols = {'L3', 'L3_iii'};
        d.reuse = {{'SN-hover', {'L3'}}};
    case 'iii-circle'                                  % sec 45.7: no-harm check on the circle (S40)
        d.set = 'S40';  d.m3 = true;  d.d2sub = true;
        d.cols = {'L3', 'L3_iii'};
        d.reuse = {{'D2', {'L3'}}};
    case 'static-hover'                                % sec 54.3: (iii-0) on N6_hover; the hover table L3 / H3 / (iii-0)
        d.set = 'N6_hover';  d.cond = 'Hover';  d.hover = true;  d.h3 = true;  d.st = true;
        d.cols = {'L3', 'H3', 'L3_iii0'};
        d.reuse = {{'N6', {'L3'}}, {'H3-hover', {'H3'}}};
    case 'static-hover-k'                              % sec 54.3: (1 + K-hat) x 0.7 / x 1.3 on S40hover
        d.set = 'S40hover';  d.cond = 'Hover';  d.hover = true;  d.st = true;
        d.cols = {'L3', 'L3_iii0', 'L3_iii0_k070', 'L3_iii0_k130', 'L3_iii0_s070', 'L3_iii0_s130'};   % sec 58.1
        d.reuse = {{'F-hover', {'L3'}}, {'iii-hover', {'L3_iii0'}}};
    case 'static-indi-bias'                            % sec 58.2: INDI with a horizontal accelerometer bias
        d.set = 'S40hover';  d.cond = 'Hover';  d.hover = true;  d.h3 = true;  d.st = true;
        d.cols = {'L3', 'L3_iii0', 'H3', 'H3_b086', 'H3_b170'};
        d.reuse = {{'F-hover', {'L3'}}, {'iii-hover', {'L3_iii0'}}, {'H3-hover', {'H3'}}};
    case 'static-circle'                               % sec 54.3: no-harm of (iii-0) on the circle (S40)
        d.set = 'S40';  d.d2sub = true;  d.st = true;
        d.cols = {'L3', 'L3_iii0'};
        d.reuse = {{'D2', {'L3'}}};
    case 'H3-circle'                                   % sec 50: INDI (H3), circle_main, two levels
        d.set = 'circle_main';  d.h3 = true;
        d.cols = {'L1', 'L3', 'H3'};                   % no wind sensor: L1 vs H3; measured wind: L3 vs H3
        d.reuse = {{'D2', {'L3'}}};
    case {'H3-hover', 'H3-hover-iii'}                  % sec 50: INDI (H3) on N6_hover (+ (iii) if accepted)
        d.set = 'N6_hover';  d.cond = 'Hover';  d.hover = true;  d.h3 = true;
        d.cols = {'L3', 'H3'};
        if strcmp(name, 'H3-hover-iii'), d.cols = {'L3', 'L3_iii', 'H3'};  d.m3 = true; end
        d.reuse = {{'N6', {'L3'}}};
    % ---- REGISTER_P2 sec 60.8: CONFIRM2 groups (Conf2 / DevTest only); configurations of the dev groups ----
    case {'six-circle', 'six-circle-h3'}               % sec 63.1 (dev only): the six-controller table, circle_main
        d.set = 'circle_main';  d.h3 = true;  d.six = true;
        d.cols = {'L3', 'H3', 'L3_iii0'};              % run: L3_iii0 (+ H3 in six-circle-h3); STD and indices stored
        d.reuse = {{'D2', {'L3'}}, {'H3-circle', {'H3'}}};
        if strcmp(name, 'six-circle-h3'), d.reuse = {{'D2', {'L3'}}}; end
    case 'C2-circle'                                   % D2 circle + static-circle (L3_iii0) + H3-circle (H3)
        d.set = 'circle_main';  d.h3 = true;  d.c2 = true;
        d.cols = {'L3', 'L3_iii0', 'H3'};
        d.reuse = {{'D2', {'L3'}}};                    % the CONFIRM2 D2 run (results/gd10/D2.mat)
    case 'C2-hover'                                    % static-hover + static-indi-bias, N6_hover rule
        d.set = 'N6_hover';  d.cond = 'Hover';  d.hover = true;  d.h3 = true;  d.c2 = true;
        d.cols = {'L3', 'L3_iii0', 'H3', 'H3_b086', 'H3_b170'};
    case 'C2-hhover'                                   % H-hover (sec 26.3) = N5-H-StrongRel
        d.set = 'N5-H-StrongRel';  d.K = 0;  d.cond = 'Hover';  d.hover = true;  d.c2 = true;
        d.cols = {'L3', 'P', 'O', 'O0'};
    case {'N6X-T5', 'N6X-T5-tm'}
        d.set = 'T5_main';  d.cond = 'Multisine';  d.imtable = true;  d.explore = true;
        d.cols = {'L3', 'L3_6'};
        if strcmp(name, 'N6X-T5-tm'), d.reuse = {{'N6X-T5', {'L3'}}}; end
    otherwise
        error('run_p2_gd7: unknown group ''%s''.', name);
end
g = d;
end

function a = p2_args(g)
%P2_ARGS  Nominal P2 as run_p2_gd6 (REGISTER_P2 sec 7), with this group's K and sensor delay.
a = {'Grid', true, 'PlantModel', 'p2', 'SensorDelayMs', g.delay, 'PayloadModel', 1, ...
     'PayloadWind', g.K, 'OnDiverge', 'flag', 'Quiet', true, 'PredDelay', true};
end

function im = im_args(g)
%IM_ARGS  circle: DoHarm [0 1] (the D2 table's own IM); hover: its exact-frequency table.
if ~g.hover && ~g.imtable
    im = {'DoHarm', [0 1]};
    return
end
evalc('evalin(''base'', ''init_MOBADC_params'')');     % op_set needs init's variables
C = op_set(g.cond);
im = {'DoWAxis', im_oracle_axis(C.traj_type, C.traj_par, C.w_traj, g.L)};
end

function [E, F, P, X, Q, SD] = run_cols(fn, cols, g, opt, im)
%RUN_COLS  The requested columns on one segment. Columns sharing the oracle horizon and the N6
%  switch run in one pa_configs call (L3/P/O at OracleTauMs = tau_w*; O0 at 0; O150 at 150 - the
%  same calls as before N6 existed); a column identical to one already run (same configuration,
%  horizon and N6 switch) is copied, not re-run. N6 columns: P2N6 on, horizon P2N6TauMs = TauW.
%  F3 diagnostic (g.diag, sec 42): X(:, k) = [mean position error vector over t >= TStat (3); |mean N6
%  delta| over t >= TStat (N6 columns; NaN otherwise)] - read from the run's own time series.
%  SD (sec 63.1): within-segment STD of the position-error norm over t >= TStat (pa_configs' std; Guo's s).
E = nan(1, numel(cols));  F = repmat({''}, 1, numel(cols));  P = cell(1, numel(cols));  X = nan(4, numel(cols));
[~, qn] = p2_indices([]);
Q = nan(numel(qn), numel(cols));                        % sec 60.4 indices (p2_indices), read by the C2 groups
SD = nan(1, numel(cols));
if isempty(cols), return; end
base = [p2_args(g), {'Cond', g.cond, 'L', g.L}, im, {'TauPred', opt.TauPred, 'TauPrev', 0}];
twms = round(1000 * opt.TauW);
n6ms = twms;                                            % N6 propagation horizon: TauN6 (default TauW)
if isfield(opt, 'TauN6') && ~isempty(opt.TauN6), n6ms = round(1000 * opt.TauN6); end
sp = cellfun(@(c) col_spec(c, twms), cols, 'UniformOutput', false);  sp = [sp{:}];
for k = 1:numel(cols)                                   % sec 52: a variant column must differ from its nominal
    if ~isempty(regexp(cols{k}, '_(L|m|cP|cB)\d{3}$', 'once'))
        assert(any(sp(k).ps ~= 1), 'run_p2_gd7: column %s parsed with nominal parameters.', cols{k});
    end
end
done = false(1, numel(cols));
for k = 1:numel(cols)                                   % copies of a column already specified
    j = find(arrayfun(@(q) strcmp(sp(q).cfg, sp(k).cfg) && sp(q).h == sp(k).h && sp(q).n6 == sp(k).n6 && ...
        isequal(sp(q).ps, sp(k).ps) && strcmp(sp(q).m3, sp(k).m3) && isequal(sp(q).bias, sp(k).bias) && ...
        sp(q).cmp == sp(k).cmp, 1:k - 1), 1);
    if ~isempty(j), sp(k).copy_of = j; end
end
for k = 1:numel(cols)
    if done(k) || sp(k).copy_of > 0, continue; end
    b = find(~done & [sp.copy_of] == 0 & [sp.h] == sp(k).h & [sp.n6] == sp(k).n6 & ...
        arrayfun(@(q) isequal(q.ps, sp(k).ps) && strcmp(q.m3, sp(k).m3) && isequal(q.bias, sp(k).bias) && ...
        q.cmp == sp(k).cmp, sp));
    only = {sp(b).cfg};
    args = [base, {'Only', only, 'OracleTauMs', sp(k).h}];
    if sp(k).n6, args = [args, {'P2N6', true, 'P2N6TauMs', n6ms}]; end   %#ok<AGROW>
    if any(sp(k).ps ~= 1), args = [args, {'P2PredScale', sp(k).ps}]; end %#ok<AGROW>
    if ~isempty(sp(k).m3)                               % sec 45: (iii), horizon tau_m* (TauM3)
        args = [args, {'P2M3', true, 'P2M3TauMs', round(1000 * opt.TauM3), 'P2M3Acc', sp(k).m3}]; %#ok<AGROW>
    end
    if sp(k).cmp == 1                                   % sec 50: INDI (H3) at the frozen omega_f*
        args = [args, {'P2Cmp', 1, 'P2H3Hz', opt.H3Hz}]; %#ok<AGROW>
    end
    if ~isempty(sp(k).bias)                             % sec 45.6 (1): 0.086 / 0.17 horizontal, 0.39 three axes
        args = [args, {'P2AccBias', sp(k).bias, 'P2AccBiasAxes', tern(sp(k).bias < 0.3, 'xy', 'xyz')}]; %#ok<AGROW>
    end
    if isfield(g, 'diag') && g.diag, args = [args, {'KeepTraj', true, 'KeepLog', {'p2_n6_log'}}]; end %#ok<AGROW>
    ff = fn;
    if isfield(opt, 'DataDir') && ~isempty(opt.DataDir), ff = fullfile(opt.DataDir, fn); end   % sec 43
    if isfield(opt, 'Conf2') && ~isempty(opt.Conf2), ff = fullfile(opt.Conf2, fn); end         % sec 60.8
    [~, M] = pa_configs(ff, args{:});
    try, Simulink.sdi.clear; catch, end
    for q = b
        [E(q), F{q}, P{q}] = one_value(M, sp(q).cfg);
        Q(:, q) = p2_indices(M.(sp(q).cfg)).';
        if isfinite(E(q)) && isfield(M.(sp(q).cfg), 'std'), SD(q) = M.(sp(q).cfg).std; end
        if isfield(g, 'diag') && g.diag && isfinite(E(q)), X(:, q) = diag_x(M.(sp(q).cfg), sp(q).n6); end
    end
    done(b) = true;
end
for k = find([sp.copy_of] > 0)
    j = sp(k).copy_of;  E(k) = E(j);  F{k} = F{j};  P{k} = P{j};  X(:, k) = X(:, j);  Q(:, k) = Q(:, j);  SD(k) = SD(j);
end
end

function x = diag_x(m, n6)
%DIAG_X  sec 42: [mean of (gamma_d - gamma) over t >= TStat, per axis; |mean N6 delta| over t >= TStat].
TSTAT = 140;                                            % pa_configs' TStat (every GĐ7 call uses the default)
x = nan(4, 1);
if isfield(m, 't') && ~isempty(m.t)
    ms = m.t >= TSTAT;
    x(1:3) = mean(m.gd(ms, :) - m.g(ms, :), 1).';
end
if n6 && isfield(m, 'log') && isfield(m.log, 'p2_n6_log') && m.log.p2_n6_log.ok
    L = m.log.p2_n6_log;
    ms = L.t(:) >= TSTAT;
    if size(L.v, 2) ~= 5 && size(L.v, 1) == 5, L.v = L.v.'; end   % [theta_x theta_y delta_x delta_y gate]
    x(4) = norm(mean(L.v(ms, 3:4), 1));
end
end

function s = col_spec(name, twms)
%COL_SPEC  Configuration, oracle horizon [ms] and N6 switch of a column (sec 0.3, 15.2, 15.4).
t = {'L3', 'g_psens', twms, false;  'P', 'g_both', twms, false;  'O', 'g_orac', twms, false; ...
     'L1', 'g_pay', twms, false;       'H3', 'g_psens', twms, false; ...
     'O0', 'g_orac', 0, false;      'O150', 'g_orac', 150, false; ...
     'L3_6', 'g_psens', twms, true; 'P_6', 'g_both', twms, true;  'O_6', 'g_orac', twms, true; ...
     'O6_0', 'g_orac', 0, true};
ps = [1 1 1 1];                                         % [s_L s_mL s_CdA_payload s_CdA_body]
v = regexp(name, '^L3_6_([Lmc])(\d{3})$', 'tokens', 'once');   % sec 39: L3_6 with scaled parameters
if ~isempty(v)
    ix = find('Lmc' == v{1});
    if ix == 3, ix = [3 4]; end                         % c = payload and body together (sec 39.2)
    ps(ix) = str2double(v{2}) / 100;
    name = 'L3_6';
end
v = regexp(name, '^(L3|L3_6)_c([PB])(\d{3})$', 'tokens', 'once');  % sec 42: payload / body part only
if ~isempty(v)
    ps(2 + find('PB' == v{2})) = str2double(v{3}) / 100;
    name = v{1};
end
% sec 45: (iii) columns. L3_iii = L3 + the model (commanded acceleration); L3_iii_<L|m|cP|cB><pct> =
% the model (and, for cB, the body feed-forward) with that controller-side parameter scaled;
% L3_iii0 = (iii-0), static (1 + K) body feed-forward = PredScale body 1.5, no model;
% L3_iiim = (iii-m), measured acceleration; L3_iiim_b<mm/s^2> = with the accelerometer bias of sec 45.6 (1)
m3 = '';  bias = [];
if strcmp(name, 'L3_iii0')
    ps(4) = 1.5;  name = 'L3';
end
v = regexp(name, '^L3_iii0_s(\d{3})$', 'tokens', 'once');   % sec 54.3 / 58.1: the (1 + K-hat) factor scaled (stress)
if ~isempty(v)
    ps(4) = 1.5 * str2double(v{1}) / 100;  name = 'L3';
end
v = regexp(name, '^L3_iii0_k(\d{3})$', 'tokens', 'once');   % sec 58.1: K-hat scaled, factor 1 + 0.5 s (read)
if ~isempty(v)
    ps(4) = 1 + 0.5 * str2double(v{1}) / 100;  name = 'L3';
end
v = regexp(name, '^H3_b(\d{3})$', 'tokens', 'once');        % sec 58.2: H3 with a horizontal accelerometer bias
if ~isempty(v)
    bias = str2double(v{1}) / 1000;  name = 'H3';
end
% Parsed without optional or empty-matching groups: MATLAB and Octave differ in the tokens they return
% for those, and the first form of this parser left every variant at its nominal parameters in MATLAB
% (the 8 iii-hover variants equal to L3_iii in every digit, dry run 2026-09-30, sec 52).
if ~isempty(regexp(name, '^L3_iiim?(_(L|m|cP|cB)\d{3})?$', 'once'))
    m3 = tern(strncmp(name, 'L3_iiim', 7), 'meas', 'cmd');
    v = regexp(name, '_(L|m|cP|cB)(\d{3})$', 'tokens', 'once');
    if ~isempty(v)
        ix = find(strcmp({'L', 'm', 'cP', 'cB'}, v{1}), 1);
        assert(~isempty(ix), 'run_p2_gd7: bad variant %s.', name);
        ps(ix) = str2double(v{2}) / 100;
    end
    name = 'L3';
end
v = regexp(name, '^L3_iiim_b(\d{3})$', 'tokens', 'once');
if ~isempty(v)
    m3 = 'meas';  bias = str2double(v{1}) / 1000;  name = 'L3';
end
i = find(strcmp(t(:, 1), name), 1);
assert(~isempty(i), 'run_p2_gd7: unknown column %s.', name);
s = struct('cfg', t{i, 2}, 'h', t{i, 3}, 'n6', t{i, 4}, 'copy_of', 0, 'ps', ps, 'm3', m3, 'bias', bias, ...
    'cmp', double(strcmp(name, 'H3')));              % sec 50: H3 = g_psens + p2_cmp 1 (the wind channel is zeroed)
end

function [v, fl, p2] = one_value(M, col)
%ONE_VALUE  Mean error of one column, or NaN with the reason (REGISTER_P2 sec 0.4 flags).
m = M.(col);
fl = '';  p2 = [];
if isfield(m, 'p2'), p2 = m.p2; end
if isfield(m, 'crashed') && m.crashed
    fl = 'crash';
    if isfield(m, 'crash_msg') && ~isempty(m.crash_msg)
        fprintf('         crash: %s\n', m.crash_msg(1:min(end, 400)));
    end
elseif isfield(m, 'diverged') && m.diverged, fl = 'diverged';
elseif isfield(m, 'p2') && m.p2.phys_div, fl = 'phys_div';
elseif isfield(m, 'p2') && m.p2.num_flag, fl = 'num_flag';
end
if isempty(fl), v = m.mean; else, v = NaN; end
end

%% =====================================================================
%  reuse (sec 15.1)
%% =====================================================================
function R = load_sources(g, key, files, outd)
R = struct('name', {}, 'cols', {}, 'val', {}, 'ok', {});
for s = 1:numel(g.reuse)
    nm = g.reuse{s}{1};  cols = g.reuse{s}{2};
    if strcmp(nm, 'D2')
        f = fullfile(repo_root(), 'results', 'gd6', 'd2_p2.mat');
        if g.c2, f = fullfile(outd, 'D2.mat'); end      % sec 60.8: the D2 run on the same CONFIRM2 set
        assert(exist(f, 'file') == 2, 'run_p2_gd7: %s not found - the L3 reuse needs D2''s results.', f);
        Z = load(f, 'rows', 'key');
        assert((strcmp(Z.key.sha, key.sha) || (g.d2sub && all(ismember(files, {Z.rows.file})))) && ...
            Z.key.TauPred == key.TauPred, ['run_p2_gd7: D2 was run on another set or TauPred - L3 is not reused.']);
        n = numel(Z.rows);
        val = struct('file', {{Z.rows.file}'}, 'cols', {{'L3'}}, 'E', nan(n, 1), 'F', {cell(n, 1)}, ...
            'p2', {cell(n, 1)});
        for i = 1:n
            val.E(i) = Z.rows(i).E(3);  val.F{i} = Z.rows(i).F{3};  val.p2{i} = Z.rows(i).p2{3};
        end
        if isfield(Z.rows, 'Q')                          % sec 60.8: indices of D2's L3 (nq x n x 1)
            val.Q = nan(size(Z.rows(1).Q, 1), n, 1);
            for i = 1:n, val.Q(:, i, 1) = Z.rows(i).Q(:, 3); end
        end
    else
        f = fullfile(outd, [nm '.mat']);                % results/gd7 (dev) - unchanged
        assert(exist(f, 'file') == 2, 'run_p2_gd7: %s not found - run %s first.', f, nm);
        Z = load(f, 'rows', 'key');
        k = Z.key;
        same = k.TauW == key.TauW && k.TauPred == key.TauPred && k.K == key.K && k.L == key.L && ...
            strcmp(k.cond, key.cond);
        if ~all(ismember(cols, {'O', 'O0', 'O150'}))      % a sensor column: the delay must match too
            same = same && k.delay == key.delay;
        end
        if any(strcmp(cols, 'H3'))                      % sec 54.3: a reused H3 column needs the same omega_f
            same = same && isfield(k, 'H3Hz') && isfield(key, 'H3Hz') && k.H3Hz == key.H3Hz;
        end
        assert(same, 'run_p2_gd7: %s was run with another configuration - not reused.', f);
        n = numel(Z.rows);
        val = struct('file', {{Z.rows.file}'}, 'cols', {cols}, 'E', nan(n, numel(cols)), ...
            'F', {cell(n, numel(cols))}, 'p2', {cell(n, numel(cols))});
        for i = 1:n
            for c = 1:numel(cols)
                j = strcmp(k.cols, cols{c});
                val.E(i, c) = Z.rows(i).E(j);  val.F{i, c} = Z.rows(i).F{j};  val.p2{i, c} = Z.rows(i).p2{j};
            end
        end
    end
    nsh = sum(ismember(files, val.file));
    fprintf('  reuse source %s: columns %s, %d of this set''s %d segments shared\n', nm, strjoin(cols, ' '), ...
        nsh, numel(files));
    R(end + 1) = struct('name', nm, 'cols', {cols}, 'val', val, 'ok', nsh > 0); %#ok<AGROW>
end
end

function r = spot_check(r, g, files, days, opt, im) %#ok<INUSL>
%SPOT_CHECK  Re-run the reused columns on the first shared segment: every printed digit must match.
if ~r.ok, return; end
i = find(ismember(files, r.val.file), 1);
fn = files{i};  k = find(strcmp(r.val.file, fn), 1);
[E, F] = run_cols(fn, r.cols, g, opt, im);
pr = @(v) sprintf('%.4f', v);
okc = arrayfun(@(c) strcmp(pr(E(c)), pr(r.val.E(k, c))) && strcmp(F{c}, r.val.F{k, c}), 1:numel(r.cols));
fprintf('  spot check %s on %s:\n', r.name, fn);
for c = 1:numel(r.cols)
    fprintf('     %-5s re-run %s%-9s source %s%-9s |d| %.3g  %s\n', r.cols{c}, pr(E(c)), [' ' F{c}], ...
        pr(r.val.E(k, c)), [' ' r.val.F{k, c}], abs(E(c) - r.val.E(k, c)), tern(okc(c), 'OK', 'MISMATCH'));
end
if all(okc)
    fprintf('     -> reuse %s: ON\n', r.name);
else
    r.ok = false;
    fprintf('     -> reuse %s: OFF (a printed digit differs) - every column is run\n', r.name);
end
end

%% =====================================================================
%  sec 0.6 report
%% =====================================================================
function G = report(g, rows, key)
if isfield(g, 'six') && g.six
    G = six_report(g, rows, key);                       % sec 63.1: descriptive; the table is make_p2_tables (5)
    return
end
if isfield(g, 'c2') && g.c2
    c2_report(g, rows, key);                            % sec 60.4: descriptive indices per column
    G = struct('group', g.name);                        % the sec 60.3 claims: gd10_confirm2 / conf2_claims
    return
end
if isfield(g, 'explore') && g.explore
    G = side_report(g, rows, key);                      % sec 28.2: descriptive, no gate
    return
end
if isfield(g, 'diag') && g.diag
    G = d3_report(g, rows, key);                        % sec 42: F3 diagnostic, fixed reading
    return
end
if isfield(g, 'st') && g.st
    G = static_report(g, rows, key);                    % sec 54.3: (iii-0) robustness, descriptive readings
    return
end
if isfield(g, 'h3') && g.h3
    G = h3_report(g, rows, key);                        % sec 50: INDI tables, descriptive
    return
end
if isfield(g, 'm3') && g.m3
    G = m3_report(g, rows, key);                        % sec 45.3 / 45.7: (iii) acceptance, no-harm
    return
end
if isfield(g, 'sn') && g.sn
    G = sn_report(g, rows, key);                        % sec 43.2: wind-sensor noise, fixed reading
    return
end
if isfield(g, 'fsens') && g.fsens
    G = f_report(g, rows, key);                         % sec 39: F1-F3 sensitivity, no gate
    return
end
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
day = {rows.day}';
ok = all(isfinite(E), 2);
fprintf('\n  %s - one set: %d of %d segments valid in every column (%d removed)\n', g.name, sum(ok), ...
    numel(ok), sum(~ok));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
nre = sum(cellfun(@(s) sum(~strcmp(s, 'run')), {rows.src}));
fprintf('  reused values: %d of %d\n', nre, nc * numel(rows));
E = E(ok, :);  day = day(ok);  fl = {rows(ok).file}';
n = size(E, 1);  nd = numel(unique(day));
G = struct('group', g.name, 'n', n, 'n_days', nd, 'evaluable', n >= 15 && nd >= 6);
if n == 0, fprintf('  nothing to pool\n'); return; end
P = sqrt(mean(E.^2, 1));
for c = 1:nc, fprintf('  %-5s pooled %.5f\n', cols{c}, P(c)); end
ci = @(nm) find(strcmp(cols, nm), 1);
if isfield(g, 'n6') && g.n6                                % group N6: the gate columns are *_6
    iL = ci('L3_6');  iP = ci('P_6');  iO = ci('O_6');  i0 = ci('O6_0');  i150 = [];  sx = '_6';
else
    iL = ci('L3');  iP = ci('P');  iO = ci('O');  i0 = ci('O0');  i150 = ci('O150');  sx = '';
end
st = struct();
st.h = stat(@(p) 1 - p(iO) / p(iL), E, day, fl, sprintf('h%s = 1 - O%s/L3%s', sx, sx, sx));
st.c = stat(@(p) (p(iL) - p(iP)) / (p(iL) - p(iO)), E, day, fl, sprintf('c%s = (L3 - P)/(L3 - O)', sx));
st.gap = stat(@(p) p(iL) - p(iP), E, day, fl, sprintf('L3%s - P%s [m]', sx, sx));
st.h_sensor = stat(@(p) 1 - p(i0) / p(iL), E, day, fl, sprintf('h%s,sensor = 1 - O%s(0)/L3%s', sx, sx, sx));
st.h_pred = stat(@(p) 1 - p(iO) / p(i0), E, day, fl, sprintf('h%s,pred = 1 - O%s/O%s(0)', sx, sx, sx));
if ~isempty(sx)
    iB = ci('L3');                                      % report only: the N6 term alone, sensor wind
    st.n6_effect = stat(@(p) 1 - p(iL) / p(iB), E, day, fl, 'report: h_model = 1 - L3_6/L3');
    th_report(rows(ok), cols);
end
if ~isempty(i150)
    st.h150 = stat(@(p) 1 - p(i150) / p(iL), E, day, fl, 'h(150) = 1 - O(150)/L3');
    st.c150 = stat(@(p) (p(iL) - p(iP)) / (p(iL) - p(i150)), E, day, fl, 'c(150)');
end
fprintf('  identity check: (1 - h) - (1 - h_sensor)(1 - h_pred) = %.2g\n', ...
    (1 - st.h.val) - (1 - st.h_sensor.val) * (1 - st.h_pred.val));
% ---- sec 0.6 verdicts ----
h = st.h;
head = h.val >= 0.10 && all(sign(h.loo) == sign(h.val) & h.loo ~= 0) && h.day_median >= 0.05;
cap = NaN;
if head
    cap = st.c.val >= 0.5 && all(st.gap.loo > 0);
end
G.stats = st;  G.pooled = P;  G.headroom = head;  G.captured = cap;
G.yes = G.evaluable && head && isequal(cap, true);
fprintf('\n  sec 0.6 %s: n %d, days %d -> %s\n', g.name, n, nd, tern(G.evaluable, 'evaluable', ...
    'NOT EVALUABLE (< 15 segments or < 6 days): reported, cannot make the gate YES'));
fprintf('     headroom (h >= 10%% AND LOO sign kept AND by-day median >= 5%%): %s\n', tern(head, 'YES', 'NO'));
if head
    fprintf('     captured (c >= 0.5 AND L3 - P > 0 under LOO): %s\n', tern(cap, 'YES', 'NO'));
else
    fprintf('     captured: c not evaluated (no headroom)\n');
end
fprintf('     group counts for CỔNG G: %s\n', tern(G.yes, 'YES', 'NO'));
if G.yes && st.h_sensor.val > 0.5 * h.val
    fprintf('     note: headroom mainly from sensor quality, not from prediction (h_sensor > h/2)\n');
end
if head && isequal(cap, false) && abs(1000 * key.TauW - 150) >= 50
    fprintf('     note: may be due to the predictor''s horizon / input distribution (sec 0.3)\n');
end
end

function c2_report(g, rows, key)
%C2_REPORT  REGISTER_P2 sec 60.4 (descriptive, no claim): every index per column, on the group's one set
%  (finite in every column) and on its unsaturated subset (tilt_sat_frac < 1 % in every column). The
%  registered claims of sec 60.3 are computed by gd10_confirm2 / conf2_claims, not here.
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
fprintf('\n  %s (sec 60.4, descriptive) - one set %d of %d segments, %d days\n', g.name, sum(ok), numel(ok), ...
    numel(unique({rows(ok).day})));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
if ~any(ok), return; end
Q = cat(3, rows.Q);                                     % nq x nc x n
ts = reshape(Q(7, :, :), nc, []);                       % tilt_sat_frac, nc x n
uns = ok & all(ts < 0.01, 1).';
c2_table('one set', Q(:, :, ok), cols, sum(ok));
c2_table('unsaturated subset', Q(:, :, uns), cols, sum(uns));
end

function G = six_report(g, rows, key)
%SIX_REPORT  REGISTER_P2 sec 63.1 (descriptive): the run's columns on its one set - pooled mean, pooled
%  within-segment STD, h = 1 - L3_iii0/L3 and L3_iii0/H3 - 1 (sec 0.2 statistics). six-circle-h3: H3 re-run
%  against the stored H3-circle row on every shared segment (|d|). The six-controller table itself is
%  analysis/make_p2_tables.m (table 5), with Guo's four controllers from guo_p2.mat / guo_trim_p2.mat.
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
SD = reshape([rows.SD], nc, []).';
ok = all(isfinite(E), 2);
day = {rows(ok).day}';  fl = {rows(ok).file}';
fprintf('\n  %s (sec 63.1, descriptive) - one set %d of %d segments, %d days\n', g.name, sum(ok), numel(ok), ...
    numel(unique(day)));
G = struct('group', g.name, 'n', sum(ok));
if sum(ok) < 2, return; end
P = sqrt(mean(E(ok, :).^2, 1));  S = sqrt(mean(SD(ok, :).^2, 1));
for c = 1:nc
    fprintf('    %-8s pooled mean %.5f m   pooled STD %s\n', cols{c}, P(c), tern(isfinite(S(c)), sprintf('%.5f m', S(c)), ...
        '- (reused column: not stored)'));
end
ci = @(nm) find(strcmp(cols, nm), 1);
G.h = stat(@(p) 1 - p(2) / p(1), E(ok, [ci('L3') ci('L3_iii0')]), day, fl, 'h = 1 - L3_iii0/L3');
G.r = stat(@(p) p(1) / p(2) - 1, E(ok, [ci('L3_iii0') ci('H3')]), day, fl, 'L3_iii0/H3 - 1');
if strcmp(g.name, 'six-circle-h3')
    f = fullfile(repo_root(), 'results', 'gd7', 'H3-circle.mat');
    if exist(f, 'file') == 2
        Z = load(f, 'rows', 'key');
        [~, ia, ib] = intersect({rows.file}, {Z.rows.file});
        a = arrayfun(@(i) rows(i).E(ci('H3')), ia);  b = arrayfun(@(i) Z.rows(i).E(strcmp(Z.key.cols, 'H3')), ib);
        m = isfinite(a) & isfinite(b);
        fprintf('    H3 re-run vs H3-circle.mat: %d shared, max |d| %.3g, %d finite in one only\n', numel(ia), ...
            max([0; abs(a(m) - b(m))]), sum(isfinite(a) ~= isfinite(b)));
    end
end
end

function c2_table(label, Q, cols, n)
[~, nm] = p2_indices([]);
fprintf('  %s (n %d):\n  %-22s', label, n, '');
fprintf(' %10s', cols{:});  fprintf('\n');
if n == 0, return; end
rd = {'pooled mean [m]', 1, @(v) sqrt(mean(v.^2)); 'pooled RMS [m]', 2, @(v) sqrt(mean(v.^2)); ...
      'median max [m]', 3, @median; 'max max [m]', 3, @max; 'median p95 [m]', 4, @median; ...
      'max p95 [m]', 4, @max; 'pooled u_osc [N]', 5, @(v) sqrt(mean(v.^2)); 'mean sat_p2', 6, @mean; ...
      'max sat_p2', 6, @max; 'mean sat_rotor', 10, @mean; 'max sat_rotor', 10, @max; ...
      'mean tilt_sat_frac', 7, @mean; 'pooled theta RMS [deg]', 8, @(v) sqrt(mean(v.^2)); ...
      'max theta max [deg]', 9, @max};
for r = 1:size(rd, 1)
    fprintf('  %-22s', rd{r, 1});
    for c = 1:numel(cols)
        v = squeeze(Q(rd{r, 2}, c, :));
        fprintf(' %10.5f', rd{r, 3}(v(:)));
    end
    fprintf('\n');
end
assert(strcmp(nm{4}, 'e_p95') && strcmp(nm{5}, 'u_osc') && strcmp(nm{6}, 'sat_p2') && strcmp(nm{10}, 'sat_rotor'));
end

function s = stat(f, E, day, fl, label)
%STAT  sec 0.2: pooled value, SE (paired delete-one-day jackknife), by-day median (per-day
%  value from the day's own pooled columns), LOO [min, max], most influential segment.
pool = @(e) sqrt(mean(e.^2, 1));
n = size(E, 1);
s = struct('label', label, 'val', f(pool(E)));
loo = nan(n, 1);
for i = 1:n, loo(i) = f(pool(E([1:i-1, i+1:n], :))); end
ud = unique(day);  nd = numel(ud);  jd = nan(nd, 1);  dd = nan(nd, 1);
for j = 1:nd
    m = strcmp(day, ud{j});
    if nd > 1, jd(j) = f(pool(E(~m, :))); end
    dd(j) = f(pool(E(m, :)));
end
s.se = sqrt((nd - 1) / nd * sum((jd - mean(jd)).^2));
s.loo = loo;  s.day_median = median(dd);
[~, iw] = max(abs(loo - s.val));
s.most_influential = fl{iw};
if n < 2, s.loo = s.val; end
if isempty(strfind(label, '[m]'))
    sc = 100;  u = '%%';  nf = '%+8.2f';  sf = '%.2f';
else
    sc = 1;  u = '';  nf = '%+.5f';  sf = '%.5f';    % a difference in metres
end
fmt = ['  %-26s ' nf u '  SE ' sf '  LOO [' nf ', ' nf ']' u '  by-day median ' nf u '  most influential %s\n'];
fprintf(fmt, label, sc * s.val, sc * s.se, sc * min(s.loo), sc * max(s.loo), sc * s.day_median, s.most_influential);
end

function d2_combined(rows, key)
%D2_COMBINED  sec 7.2 one-set rule over the final table's columns: D2 (Delta = L3/L2 - 1) on
%  the segments valid in L0 L2 L3 V AND in this group's columns, beside the registered D2.
f = fullfile(repo_root(), 'results', 'gd6', 'd2_p2.mat');
if exist(f, 'file') ~= 2, return; end
Z = load(f, 'rows');
[sh, ia, ib] = intersect({Z.rows.file}, {rows.file}, 'stable');
E1 = reshape([Z.rows(ia).E], 4, []).';
E2 = reshape([rows(ib).E], numel(key.cols), []).';
E = [E1, E2];  cols = [{'L0', 'L2', 'L3(D2)', 'V'}, key.cols];
ok = all(isfinite(E), 2);
n1 = sum(all(isfinite(reshape([Z.rows.E], 4, []).'), 2));
fprintf('\n  D2 table extended (sec 7.2): %d segments in both, %d valid in every column (D2 alone: %d)\n', ...
    numel(sh), sum(ok), n1);
P = sqrt(mean(E(ok, :).^2, 1));
for c = 1:numel(cols), fprintf('    %-7s pooled %.5f\n', cols{c}, P(c)); end
dfun = @(e) sqrt(mean(e(:, 3).^2)) / sqrt(mean(e(:, 2).^2)) - 1;
Ek = E(ok, :);  m = size(Ek, 1);  loo = nan(m, 1);
for i = 1:m, loo(i) = dfun(Ek([1:i-1, i+1:m], :)); end
if m > 0
    fprintf('    D2 on this one set: Delta %+.1f%% (n %d, LOO [%+.1f, %+.1f]%%) - reported beside the registered D2\n', ...
        100 * dfun(Ek), m, 100 * min(loo), 100 * max(loo));
end
end

function G = side_report(g, rows, key)
%SIDE_REPORT  REGISTER_P2 sec 26: the sec 0.6 quantities on the UNSATURATED subset of the one set
%  (tilt_sat_frac < 1 % over the whole run in every column), descriptive (c printed without
%  headroom), beside the full one set. N6: h_6, c_6 and h_model = 1 - L3_6/L3 (sec 26.1).
%  N5-A-StrongRel / N5-H-StrongRel: labelled POST HOC (sec 26.2). Nothing is run.
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
ts = nan(numel(rows), nc);
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), ts(i, c) = p.tilt_sat_frac; end
    end
end
unsat = ok & all(ts < 0.01, 2);
ph = any(strcmp(g.name, {'N5-A-StrongRel', 'N5-H-StrongRel'}));
tag = tern(ph, ' [POST HOC, sec 26.2]', ' [sec 26.1, registered before the run]');
ex = isfield(g, 'explore') && g.explore;
if ex, tag = sprintf(' [EXPLORATORY sec 28.2, tau_m %.0f ms]', 1000 * key.TauN6); end
fprintf('\n  SIDE REPORT %s%s - not part of CỔNG G\n', g.name, tag);
fprintf('  one set: %d segments; unsaturated subset (tilt_sat_frac < 1%% in every column): %d segments\n', ...
    sum(ok), sum(unsat));
for i = find(ok & ~unsat)'
    fprintf('    left out (saturated): %-28s max tilt_sat_frac %.4f\n', rows(i).file, max(ts(i, :)));
end
if any(ok & any(isnan(ts), 2))
    fprintf('    !!! %d segment(s) without tilt_sat_frac - treated as saturated\n', sum(ok & any(isnan(ts), 2)));
end
ci = @(nm) find(strcmp(cols, nm), 1);
if isfield(g, 'n6') && g.n6
    iL = ci('L3_6');  iP = ci('P_6');  iO = ci('O_6');  iB = ci('L3');  sx = '_6';
elseif ex
    iL = ci('L3_6');  iP = [];  iO = [];  iB = ci('L3');  sx = '_6';
else
    iL = ci('L3');  iP = ci('P');  iO = ci('O');  iB = [];  sx = '';
end
sets = {'full one set', ok; 'unsaturated subset', unsat};
G = struct('group', g.name, 'posthoc', ph);
for k = 1:2
    m = sets{k, 2};
    Ek = E(m, :);  day = {rows(m).day}';  fl = {rows(m).file}';
    nd = numel(unique(day));
    fprintf('\n  -- %s: n %d, days %d%s\n', sets{k, 1}, size(Ek, 1), nd, ...
        tern(size(Ek, 1) >= 15 && nd >= 6, '', '  (below the sec 0.6 data-sufficiency rule)'));
    if size(Ek, 1) < 2, fprintf('     fewer than 2 segments - not computed\n'); continue; end
    P = sqrt(mean(Ek.^2, 1));
    for c = 1:nc, fprintf('     %-5s pooled %.5f\n', cols{c}, P(c)); end
    st = struct();
    if ~isempty(iO)
        st.h = stat(@(p) 1 - p(iO) / p(iL), Ek, day, fl, sprintf('h%s = 1 - O%s/L3%s', sx, sx, sx));
        st.c = stat(@(p) (p(iL) - p(iP)) / (p(iL) - p(iO)), Ek, day, fl, sprintf('c%s (descriptive)', sx));
        st.gap = stat(@(p) p(iL) - p(iP), Ek, day, fl, sprintf('L3%s - P%s [m]', sx, sx));
    end
    if ~isempty(iB)
        st.h_model = stat(@(p) 1 - p(iL) / p(iB), Ek, day, fl, 'h_model = 1 - L3_6/L3');
    end
    G.(tern(k == 1, 'full', 'unsat')) = st;
end
if ex, th_report(rows(ok), cols); end
end

function G = f_report(g, rows, key)
%F_REPORT  REGISTER_P2 sec 39 (F1-F3, sensitivity, not a gate): h_model = 1 - L3_6/L3 for the
%  nominal predictor and for every scaled variant (L3_6_<p><pct>, L3 = the nominal, unscaled column),
%  on the one set (valid in every column) and on its unsaturated subset (tilt_sat_frac < 1 % in every
%  column); reading per variant: h_model > 0 AND every LOO value > 0 -> HOLDS, otherwise FAILS.
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
ts = nan(numel(rows), nc);
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), ts(i, c) = p.tilt_sat_frac; end
    end
end
unsat = ok & all(ts < 0.01, 2);
fprintf('\n  F1-F3 SENSITIVITY %s [sec 39, not a gate] - one set %d of %d (%d removed); unsaturated subset %d\n', ...
    g.name, sum(ok), numel(ok), sum(~ok), sum(unsat));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
for i = find(ok & ~unsat)'
    fprintf('    left out (saturated): %-28s max tilt_sat_frac %.4f\n', rows(i).file, max(ts(i, :)));
end
nre = sum(cellfun(@(s) sum(~strcmp(s, 'run')), {rows.src}));
fprintf('  reused values: %d of %d\n', nre, nc * numel(rows));
iB = find(strcmp(cols, 'L3'), 1);
v = find(strncmp(cols, 'L3_6', 4));
sets = {'one set', ok; 'unsaturated subset', unsat};
G = struct('group', g.name);
for k = 1:2
    m = sets{k, 2};
    Ek = E(m, :);  day = {rows(m).day}';  fl = {rows(m).file}';
    fprintf('\n  -- %s: n %d, days %d\n', sets{k, 1}, size(Ek, 1), numel(unique(day)));
    if size(Ek, 1) < 2, fprintf('     fewer than 2 segments - not computed\n'); continue; end
    P = sqrt(mean(Ek.^2, 1));
    fprintf('     L3 pooled %.5f\n', P(iB));
    for c = v
        st = stat(@(p) 1 - p(c) / p(iB), Ek, day, fl, sprintf('h_model %-10s (%.5f)', cols{c}, P(c)));
        st.reading = tern(st.val > 0 && all(st.loo > 0), 'HOLDS', 'FAILS');
        fprintf('     %30s -> %s\n', '', st.reading);
        G.(tern(k == 1, 'full', 'unsat')).(strrep(cols{c}, 'L3_6', 'h')) = st;
    end
end
end

function G = sn_report(g, rows, key)
%SN_REPORT  REGISTER_P2 sec 43.2 (wind-sensor noise 0.1 m/s on S40hover; sensitivity, not a gate):
%  h_model = 1 - L3_6/L3 on the one set and on its unsaturated subset (tilt_sat_frac < 1 % in both
%  columns), SE / LOO / by-day as sec 39; reading per set: h_model > 0 AND every LOO value > 0 ->
%  HOLDS, otherwise FAILS. Plus the paired change against the sigma-0 values of group N6 (same segments,
%  same configuration: results/gd7/N6.mat) per column.
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
ts = nan(numel(rows), nc);
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), ts(i, c) = p.tilt_sat_frac; end
    end
end
unsat = ok & all(ts < 0.01, 2);
fprintf('\n  SEC 43.2 WIND-SENSOR NOISE 0.1 m/s - %s [sensitivity, not a gate] - one set %d of %d; unsaturated %d\n', ...
    g.name, sum(ok), numel(ok), sum(unsat));
f0 = fullfile(repo_root(), 'results', 'gd7', 'N6.mat');
E0 = nan(size(E));
if exist(f0, 'file') == 2
    Z = load(f0, 'rows', 'key');
    for i = 1:numel(rows)
        k = find(strcmp({Z.rows.file}, rows(i).file), 1);
        if isempty(k), continue; end
        for c = 1:nc, E0(i, c) = Z.rows(k).E(strcmp(Z.key.cols, cols{c})); end
    end
end
sets = {'one set', ok; 'unsaturated subset', unsat};
G = struct('group', g.name);
for k = 1:2
    m = sets{k, 2};
    Ek = E(m, :);  day = {rows(m).day}';  fl = {rows(m).file}';
    fprintf('\n  -- %s: n %d, days %d\n', sets{k, 1}, size(Ek, 1), numel(unique(day)));
    if size(Ek, 1) < 2, fprintf('     fewer than 2 segments - not computed\n'); continue; end
    P = sqrt(mean(Ek.^2, 1));
    m0 = m & all(isfinite(E0), 2);
    P0 = sqrt(mean(E0(m0, :).^2, 1));  P1 = sqrt(mean(E(m0, :).^2, 1));
    for c = 1:nc
        fprintf('     %-5s pooled %.5f   vs sigma 0 (N6, n %d): %.5f -> %.5f (%+.2f %%)\n', cols{c}, P(c), ...
            sum(m0), P0(c), P1(c), 100 * (P1(c) / P0(c) - 1));
    end
    st = stat(@(p) 1 - p(2) / p(1), Ek, day, fl, 'h_model (sigma 0.1)');
    st.reading = tern(st.val > 0 && all(st.loo > 0), 'HOLDS', 'FAILS');
    fprintf('     %30s -> %s   (sigma 0 on the same segments: h_model %+.2f %%)\n', '', st.reading, ...
        100 * (1 - P0(2) / P0(1)));
    G.(tern(k == 1, 'full', 'unsat')) = st;
end
end

function G = m3_report(g, rows, key, accept)
%M3_REPORT  REGISTER_P2 sec 45.3 / 45.7 ((iii) FULL; fixed readings, written before any (iii) run).
%  iii-hover (S40hover): h_model = 1 - L3_iii*/L3 for the nominal model and the 8 scaled variants,
%    on the one set (valid in EVERY column of the group) and on its unsaturated subset (tilt_sat_frac
%    < 1 % in every column; printed, not read); per variant HOLDS iff h_model > 0 AND every LOO value
%    > 0. Comparison columns (iii-0, iii-m, iii-m with bias): h_model printed, no reading.
%  iii-hover-sn: the sigma 0.1 variant, h_model = 1 - L3_iii/L3 at sigma 0.1 (L3 of SN-hover), same rule.
%  Acceptance (sec 45.3): (iii) ACCEPTED iff all 9 variants of iii-hover AND the sigma variant HOLD on
%    the one set; printed when both groups exist.
%  iii-circle (S40, no-harm, sec 45.7): Delta = L3_iii/L3 - 1; Delta > 0 AND every LOO value > 0 ->
%    WORSE ON THE CIRCLE (a limitation of the regime of (iii)), otherwise NOT WORSE.
if nargin < 4, accept = true; end
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
acc = {'L3_iii', 'L3_iii_L080', 'L3_iii_L120', 'L3_iii_m080', 'L3_iii_m120', 'L3_iii_cP070', 'L3_iii_cP130', ...
    'L3_iii_cB070', 'L3_iii_cB130'};
if strcmp(g.name, 'iii-hover-sn'), acc = {'L3_iii'}; end
rd_cols = ismember(cols, [{'L3'}, acc]);              % sec 52: the one set is defined by L3 + the read columns only
if strcmp(g.name, 'iii-circle'), rd_cols = true(1, nc); end
ok = all(isfinite(E(:, rd_cols)), 2);
ts = nan(numel(rows), nc);
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), ts(i, c) = p.tilt_sat_frac; end
    end
end
unsat = ok & all(ts(:, rd_cols) < 0.01, 2);
fprintf('\n  SEC 45 (iii) - %s, tau_m %.0f ms - one set %d of %d (%d removed); unsaturated subset %d\n', ...
    g.name, 1000 * key.TauM3, sum(ok), numel(ok), sum(~ok), sum(unsat));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
nre = sum(cellfun(@(s) sum(~strcmp(s, 'run')), {rows.src}));
fprintf('  reused values: %d of %d\n', nre, nc * numel(rows));
iB = find(strcmp(cols, 'L3'), 1);
G = struct('group', g.name);
if strcmp(g.name, 'iii-circle')
    Ek = E(ok, :);  day = {rows(ok).day}';  fl = {rows(ok).file}';
    if size(Ek, 1) < 2, fprintf('  fewer than 2 segments - not computed\n'); return; end
    P = sqrt(mean(Ek.^2, 1));
    fprintf('  L3 pooled %.5f   L3_iii pooled %.5f\n', P(1), P(2));
    st = stat(@(p) p(2) / p(1) - 1, Ek, day, fl, 'Delta = L3_iii/L3 - 1');
    st.reading = tern(st.val > 0 && all(st.loo > 0), 'WORSE ON THE CIRCLE', 'NOT WORSE');
    fprintf('  sec 45.7 no-harm reading: %s\n', st.reading);
    ce = [cols; num2cell(sum(ts(ok, :) > 0.01, 1))];
    fprintf('  tilt_sat_frac > 1 %%: %s\n', sprintf('%s %d  ', ce{:}));
    G.noharm = st;
    return
end
sets = {'one set', ok; 'unsaturated subset', unsat};
for k = 1:2
    m = sets{k, 2};
    Ek = E(m, :);  day = {rows(m).day}';  fl = {rows(m).file}';
    fprintf('\n  -- %s: n %d, days %d%s\n', sets{k, 1}, size(Ek, 1), numel(unique(day)), ...
        tern(k == 1, ' (read)', ' (printed, not read)'));
    if size(Ek, 1) < 2, fprintf('     fewer than 2 segments - not computed\n'); continue; end
    P = sqrt(mean(Ek.^2, 1));
    fprintf('     L3 pooled %.5f\n', P(iB));
    R = struct();
    for c = find(~strcmp(cols, 'L3'))
        isacc = any(strcmp(acc, cols{c}));
        if ~isacc                                        % sec 52: a comparison column, on the set's rows where it is finite
            mc = m & isfinite(E(:, c));
            if sum(mc) < 2, fprintf('     %s: fewer than 2 finite segments - not computed\n', cols{c}); continue; end
            if sum(mc) < sum(m), fprintf('     %s: %d of %d segments finite\n', cols{c}, sum(mc), sum(m)); end
            Ec = E(mc, :);  Pc = sqrt(mean(Ec(:, c).^2));
            st = stat(@(p) 1 - p(c) / p(iB), Ec, {rows(mc).day}', {rows(mc).file}', ...
                sprintf('h_model %-13s (%.5f)', cols{c}, Pc));
            st.reading = 'comparison (no reading)';
            R.(matlab.lang.makeValidName(cols{c})) = st;
            continue
        end
        st = stat(@(p) 1 - p(c) / p(iB), Ek, day, fl, sprintf('h_model %-13s (%.5f)', cols{c}, P(c)));
        if isacc
            st.reading = tern(st.val > 0 && all(st.loo > 0), 'HOLDS', 'FAILS');
            fprintf('     %30s -> %s\n', '', st.reading);
        else
            st.reading = 'comparison (no reading)';
        end
        R.(matlab.lang.makeValidName(cols{c})) = st;
    end
    G.(tern(k == 1, 'full', 'unsat')) = R;
end
if isfield(G, 'full')
    rd = cellfun(@(c) G.full.(matlab.lang.makeValidName(c)).reading, acc, 'UniformOutput', false);
    G.holds = all(strcmp(rd, 'HOLDS'));
    fprintf('\n  %s: %d of %d acceptance variant(s) HOLD on the one set\n', g.name, sum(strcmp(rd, 'HOLDS')), numel(acc));
    if accept, m3_accept(); end
end
end

function G = static_report(g, rows, key)
%STATIC_REPORT  REGISTER_P2 sec 54.3 (night 18). One set = valid in every column of the group; unsaturated
%  subset (tilt_sat_frac < 1 % in every column) printed, not read.
%  static-hover (N6_hover): h_static = 1 - L3_iii0/L3 (HOLDS iff > 0 AND every LOO > 0); H3/L3 - 1 and
%    L3_iii0/H3 - 1 printed (the hover table L3 / INDI / (iii-0)).
%  static-hover-k (S40hover): h_static for L3_iii0, _k070, _k130 (each HOLDS / FAILS; sec 58.1) and _s070, _s130
%    (stress, printed, not read).
%  static-indi-bias (S40hover, sec 58.2): H3_b/L3_iii0 - 1 and H3_b/L3 - 1 per bias level; H3/L3_iii0 - 1 via
%    L3_iii0/H3 - 1 (descriptive).
%  static-circle (S40): Delta = L3_iii0/L3 - 1; > 0 AND every LOO > 0 -> WORSE ON THE CIRCLE, else NOT WORSE.
%  Eligibility for H-static printed when both hover groups exist (static_eligible).
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
ts = nan(numel(rows), nc);
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), ts(i, c) = p.tilt_sat_frac; end
    end
end
unsat = ok & all(ts < 0.01, 2);
fprintf('\n  SEC 54.3 (iii-0) - %s - one set %d of %d (%d removed); unsaturated subset %d\n', g.name, sum(ok), ...
    numel(ok), sum(~ok), sum(unsat));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
nre = sum(cellfun(@(s) sum(~strcmp(s, 'run')), {rows.src}));
fprintf('  reused values: %d of %d\n', nre, nc * numel(rows));
iB = find(strcmp(cols, 'L3'), 1);
G = struct('group', g.name);
sets = {'one set', ok; 'unsaturated subset', unsat};
for k = 1:2
    m = sets{k, 2};
    Ek = E(m, :);  day = {rows(m).day}';  fl = {rows(m).file}';
    fprintf('\n  -- %s: n %d, days %d%s\n', sets{k, 1}, size(Ek, 1), numel(unique(day)), ...
        tern(k == 1, ' (read)', ' (printed, not read)'));
    if size(Ek, 1) < 2, fprintf('     fewer than 2 segments - not computed\n'); continue; end
    P = sqrt(mean(Ek.^2, 1));
    ce = [cols; num2cell(P)];
    fprintf('     pooled:%s\n', sprintf('  %s %.5f', ce{:}));
    R = struct();
    if strcmp(g.name, 'static-circle')
        st = stat(@(p) p(2) / p(1) - 1, Ek, day, fl, 'Delta = L3_iii0/L3 - 1');
        st.reading = tern(st.val > 0 && all(st.loo > 0), 'WORSE ON THE CIRCLE', 'NOT WORSE');
        fprintf('     sec 54.3 no-harm reading: %s\n', st.reading);
        R.circle = st;
    else
        for c = find(strncmp(cols, 'L3_iii0', 7))
            st = stat(@(p) 1 - p(c) / p(iB), Ek, day, fl, sprintf('h_static %-13s', cols{c}));
            if ~isempty(regexp(cols{c}, '_s\d{3}$', 'once'))
                st.reading = 'stress (not read)';        % sec 58.1
            else
                st.reading = tern(st.val > 0 && all(st.loo > 0), 'HOLDS', 'FAILS');
            end
            fprintf('     %30s -> %s\n', '', st.reading);
            R.(matlab.lang.makeValidName(cols{c})) = st;
        end
        iS = find(strcmp(cols, 'L3_iii0'), 1);
        for c = find(strncmp(cols, 'H3_b', 4))           % sec 58.2, descriptive
            R.([cols{c} '_vs_iii0']) = stat(@(p) p(c) / p(iS) - 1, Ek, day, fl, sprintf('%s/L3_iii0 - 1', cols{c}));
            R.([cols{c} '_vs_L3']) = stat(@(p) p(c) / p(iB) - 1, Ek, day, fl, sprintf('%s/L3 - 1', cols{c}));
        end
        iH = find(strcmp(cols, 'H3'), 1);
        if ~isempty(iH)                                  % the hover table, descriptive
            R.H3_vs_L3 = stat(@(p) p(iH) / p(iB) - 1, Ek, day, fl, 'H3/L3 - 1 (INDI)');
            R.iii0_vs_H3 = stat(@(p) p(iS) / p(iH) - 1, Ek, day, fl, 'L3_iii0/H3 - 1');
        end
    end
    ce = [cols; num2cell(sum(ts(m, :) > 0.01, 1))];
    fprintf('     tilt_sat_frac > 1 %%: %s\n', sprintf('%s %d  ', ce{:}));
    G.(tern(k == 1, 'full', 'unsat')) = R;
end
if ~strcmp(g.name, 'static-circle'), static_eligible(); end
end

function static_eligible()
%STATIC_ELIGIBLE  sec 54.3: eligible for H-static iff h_static HOLDS (> 0 AND every LOO > 0, one set) for the
%  nominal on N6_hover (static-hover) AND for the nominal and the K-hat +-30 % columns (_k070, _k130; sec 58.1) on
%  S40hover (static-hover-k); the whole-factor _s columns are stress only.
d = fullfile(repo_root(), 'results', 'gd7');
nm = {'static-hover', 'static-hover-k'};
acc = {{'L3_iii0'}, {'L3_iii0', 'L3_iii0_k070', 'L3_iii0_k130'}};   % sec 58.1: the K-hat columns are read
if exist(fullfile(d, [nm{1} '.mat']), 'file') ~= 2 || exist(fullfile(d, [nm{2} '.mat']), 'file') ~= 2
    fprintf('  sec 54.3 H-static eligibility: needs both static-hover and static-hover-k - not yet decided\n');
    return
end
pool = @(e) sqrt(mean(e.^2, 1));
h = true;  txt = {};
for k = 1:2
    Z = load(fullfile(d, [nm{k} '.mat']), 'rows', 'key');
    cols = Z.key.cols;  E = reshape([Z.rows.E], numel(cols), []).';
    E = E(all(isfinite(E), 2), :);  n = size(E, 1);
    iB = find(strcmp(cols, 'L3'), 1);
    for c = acc{k}
        j = find(strcmp(cols, c{1}), 1);
        f = @(e) 1 - pool(e(:, j)) / pool(e(:, iB));
        loo = arrayfun(@(i) f(E([1:i-1, i+1:n], :)), 1:n);
        hk = n >= 2 && f(E) > 0 && all(loo > 0);
        h = h && hk;
        txt{end + 1} = sprintf('%s %s %s', nm{k}, c{1}, tern(hk, 'HOLDS', 'FAILS')); %#ok<AGROW>
    end
end
fprintf('  sec 54.3 H-STATIC ELIGIBILITY: %s -> %s\n', strjoin(txt, '; '), tern(h, ['ELIGIBLE (register H-static ' ...
    'before CONFIRM2, sec 54.4)'], 'NOT ELIGIBLE (H-static is not registered; C2 does not stand)'));
end

function G = h3_report(g, rows, key)
%H3_REPORT  REGISTER_P2 sec 50 (INDI, descriptive, not a gate). circle_main: the one set valid in L1, L3, H3;
%  no wind sensor: H3/L1 - 1; measured wind: H3/L3 - 1 (SE day jackknife, LOO, by-day). N6_hover: H3/L3 - 1 (and
%  L3_iii/L3 - 1 when the (iii) column is in), on the one set and on the unsaturated subset (tilt_sat_frac < 1 %
%  in every column); tilt_sat per column.
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
ts = nan(numel(rows), nc);
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), ts(i, c) = p.tilt_sat_frac; end
    end
end
unsat = ok & all(ts < 0.01, 2);
fprintf('\n  SEC 50 INDI (H3, omega_f %g Hz) - %s [descriptive, not a gate] - one set %d of %d (%d removed); unsaturated %d\n', ...
    key.H3Hz, g.name, sum(ok), numel(ok), sum(~ok), sum(unsat));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
nre = sum(cellfun(@(s) sum(~strcmp(s, 'run')), {rows.src}));
fprintf('  reused values: %d of %d\n', nre, nc * numel(rows));
ci = @(nm) find(strcmp(cols, nm), 1);
if strcmp(g.name, 'H3-circle')
    Q = {'no wind sensor: H3/L1 - 1', ci('H3'), ci('L1'); 'measured wind: H3/L3 - 1', ci('H3'), ci('L3')};
    sets = {'one set', ok};
else
    Q = {'H3/L3 - 1', ci('H3'), ci('L3')};
    if any(strcmp(cols, 'L3_iii')), Q(end + 1, :) = {'(iii) L3_iii/L3 - 1', ci('L3_iii'), ci('L3')}; end
    sets = {'one set', ok; 'unsaturated subset', unsat};
end
G = struct('group', g.name);
for k = 1:size(sets, 1)
    m = sets{k, 2};
    Ek = E(m, :);  day = {rows(m).day}';  fl = {rows(m).file}';
    fprintf('\n  -- %s: n %d, days %d\n', sets{k, 1}, size(Ek, 1), numel(unique(day)));
    if size(Ek, 1) < 2, fprintf('     fewer than 2 segments - not computed\n'); continue; end
    P = sqrt(mean(Ek.^2, 1));
    for c = 1:nc, fprintf('     %-7s pooled %.5f   tilt_sat > 1 %%: %d\n', cols{c}, P(c), sum(ts(m, c) > 0.01)); end
    for q = 1:size(Q, 1)
        a = Q{q, 2};  b = Q{q, 3};
        G.(sprintf('s%d_q%d', k, q)) = stat(@(p) p(a) / p(b) - 1, Ek, day, fl, Q{q, 1});
    end
end
end

function m3_accept()
%M3_ACCEPT  sec 45.3: (iii) is accepted iff every variant of iii-hover AND the sigma 0.1 variant
%  (iii-hover-sn) hold on their one sets (h_model > 0 AND every LOO value > 0; the same computation as
%  m3_report). Printed when both result files exist.
d = fullfile(repo_root(), 'results', 'gd7');
nm = {'iii-hover', 'iii-hover-sn'};
if exist(fullfile(d, [nm{1} '.mat']), 'file') ~= 2 || exist(fullfile(d, [nm{2} '.mat']), 'file') ~= 2
    fprintf('  sec 45.3 acceptance: needs both iii-hover and iii-hover-sn - not yet decided\n');
    return
end
acc = {{'L3_iii', 'L3_iii_L080', 'L3_iii_L120', 'L3_iii_m080', 'L3_iii_m120', 'L3_iii_cP070', 'L3_iii_cP130', ...
    'L3_iii_cB070', 'L3_iii_cB130'}, {'L3_iii'}};
h = [false false];
pool = @(e) sqrt(mean(e.^2, 1));
for k = 1:2
    Z = load(fullfile(d, [nm{k} '.mat']), 'rows', 'key');
    cols = Z.key.cols;  E = reshape([Z.rows.E], numel(cols), []).';
    rc = ismember(cols, [{'L3'}, acc{k}]);              % sec 52: the one set over L3 + the read columns only
    E = E(all(isfinite(E(:, rc)), 2), :);  n = size(E, 1);
    iB = find(strcmp(cols, 'L3'), 1);
    hk = n >= 2;
    for c = acc{k}
        j = find(strcmp(cols, c{1}), 1);
        f = @(e) 1 - pool(e(:, j)) / pool(e(:, iB));
        loo = arrayfun(@(i) f(E([1:i-1, i+1:n], :)), 1:n);
        hk = hk && f(E) > 0 && all(loo > 0);
    end
    h(k) = hk;
end
fprintf('  sec 45.3 ACCEPTANCE of (iii): iii-hover %s, sigma 0.1 %s -> %s\n', tern(h(1), 'all HOLD', 'NOT all'), ...
    tern(h(2), 'HOLDS', 'FAILS'), tern(all(h), 'ACCEPTED', ['NOT ACCEPTED (not reported as a contribution, ' ...
    'sec 42.0; (iii-obs) may be registered separately, sec 45.7)']));
end

function G = d3_report(g, rows, key)
%D3_REPORT  REGISTER_P2 sec 42 (the one F3 diagnostic round; descriptive, no gate, no fix tried).
%  Per column (one set, then the unsaturated subset): pooled error; excess over its nominal
%  counterpart (L3_6_* -> L3_6, L3_cB* -> L3); DC share = pooled |mean error vector| / pooled error;
%  DC shift = pooled |mean error vector - that of the nominal counterpart|; pooled |mean N6 delta|;
%  h_model = 1 - L3_6_*/L3 (information). Reproduction of F-hover (L3, L3_6, c070, c130: identical
%  values expected). Reading sec 42.2 on the one set: (i) L3_cB - L3 < 0.25 (L3_6_cB - L3_6) at both s;
%  (ii) DC shift(L3_6_cB) / DC shift(L3_6_cP) in [1.5, 3.0] at both s; (iii) DC share of L3_6_c070 and
%  L3_6_c130 > 0.5 -> all three: SUPPORTED (sec 41.3), otherwise NOT SUPPORTED (which failed printed).
cols = key.cols;  nc = numel(cols);
E = reshape([rows.E], nc, []).';
ok = all(isfinite(E), 2);
ts = nan(numel(rows), nc);
for i = 1:numel(rows)
    for c = 1:nc
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'tilt_sat_frac'), ts(i, c) = p.tilt_sat_frac; end
    end
end
unsat = ok & all(ts < 0.01, 2);
fprintf('\n  F3 DIAGNOSTIC %s [sec 42, one round, not a gate] - one set %d of %d (%d removed); unsaturated subset %d\n', ...
    g.name, sum(ok), numel(ok), sum(~ok), sum(unsat));
for i = find(~ok)'
    fl = rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('    removed %-28s %s\n', rows(i).file, strjoin(fl, ','));
end
% ---- reproduction of F-hover (sec 42.1) ----
f = fullfile(repo_root(), 'results', 'gd7', 'F-hover.mat');
rc = {'L3', 'L3_6', 'L3_6_c070', 'L3_6_c130'};
if exist(f, 'file') == 2
    Z = load(f, 'rows', 'key');
    nsame = 0;  ntot = 0;  dmax = 0;
    for i = 1:numel(rows)
        k = find(strcmp({Z.rows.file}, rows(i).file), 1);
        if isempty(k), continue; end
        for c = 1:numel(rc)
            a = rows(i).E(strcmp(cols, rc{c}));  b = Z.rows(k).E(strcmp(Z.key.cols, rc{c}));
            ntot = ntot + 1;
            same = isequal(a, b) || (isnan(a) && isnan(b));
            nsame = nsame + same;
            if ~same, dmax = max(dmax, abs(a - b)); end
        end
    end
    fprintf('  reproduction of F-hover (%s): %d of %d values identical, max |d| %.3g -> %s\n', strjoin(rc, ' '), ...
        nsame, ntot, dmax, tern(nsame == ntot, 'REPRODUCED', 'NOT REPRODUCED (recorded; the reading is still printed)'));
else
    fprintf('  reproduction of F-hover: %s not found - not checked\n', f);
end
% ---- nominal counterpart of each column ----
nom = zeros(1, nc);
for c = 1:nc
    if strncmp(cols{c}, 'L3_6', 4), nom(c) = find(strcmp(cols, 'L3_6'));
    else, nom(c) = find(strcmp(cols, 'L3'));
    end
end
iL3 = find(strcmp(cols, 'L3'));  iL36 = find(strcmp(cols, 'L3_6'));
ix = @(nm) find(strcmp(cols, nm));
sets = {'one set', ok; 'unsaturated subset', unsat};
G = struct('group', g.name);
for k = 1:2
    m = find(sets{k, 2});
    fprintf('\n  -- %s: n %d, days %d\n', sets{k, 1}, numel(m), numel(unique({rows(m).day})));
    if numel(m) < 2
        fprintf('     fewer than 2 segments - statistics not computed; raw values (dry-run check of the time-series reads):\n');
        for a = 1:numel(m)
            for c = 1:nc
                fprintf('       %-11s E %.5f  mean error [%+.5f %+.5f %+.5f] m  |mean delta| %s\n', cols{c}, ...
                    rows(m(a)).E(c), rows(m(a)).X(1:3, c), tern(isfinite(rows(m(a)).X(4, c)), ...
                    sprintf('%.4f N', rows(m(a)).X(4, c)), '-'));
            end
        end
        continue
    end
    n = numel(m);
    DC = nan(n, nc);  SH = nan(n, nc);  DL = nan(n, nc);
    for a = 1:n
        X = rows(m(a)).X;
        for c = 1:nc
            DC(a, c) = norm(X(1:3, c));
            SH(a, c) = norm(X(1:3, c) - X(1:3, nom(c)));
            DL(a, c) = X(4, c);
        end
    end
    A = [E(m, :), DC, SH, DL];                          % pooled column-wise by stat()
    day = {rows(m).day}';  fl = {rows(m).file}';
    pool = sqrt(mean(A.^2, 1));
    fprintf('     %-11s %9s %10s %9s %10s %11s %9s\n', 'column', 'pooled', 'excess', 'DC share', 'DC shift', '|mean dlt|', 'h_model');
    for c = 1:nc
        hm = NaN;
        if strncmp(cols{c}, 'L3_6', 4), hm = 1 - pool(c) / pool(iL3); end
        fprintf('     %-11s %9.5f %+10.5f %9.3f %10.5f %11s %9s\n', cols{c}, pool(c), pool(c) - pool(nom(c)), ...
            pool(nc + c) / pool(c), pool(2 * nc + c), tern(isfinite(pool(3 * nc + c)), sprintf('%.4f N', pool(3 * nc + c)), '-'), ...
            tern(isfinite(hm), sprintf('%+.1f%%', 100 * hm), '-'));
    end
    fprintf('     (ratios below printed x 100 %%: (i) < 25 %%, (ii) in [150, 300] %%, (iii) > 50 %%)\n');
    R = struct();
    for sv = {'070', '130'}
        s_ = sv{1};
        cB = ix(['L3_cB' s_]);  qB = ix(['L3_6_cB' s_]);  qP = ix(['L3_6_cP' s_]);  qc = ix(['L3_6_c' s_]);
        st1 = stat(@(p) (p(cB) - p(iL3)) / (p(qB) - p(iL36)), A, day, fl, sprintf('(i)   (L3_cB%s - L3)/(L3_6_cB%s - L3_6)', s_, s_));
        st2 = stat(@(p) p(2 * nc + qB) / p(2 * nc + qP), A, day, fl, sprintf('(ii)  DC shift cB%s / cP%s', s_, s_));
        st3 = stat(@(p) p(nc + qc) / p(qc), A, day, fl, sprintf('(iii) DC share L3_6_c%s', s_));
        R.(['s' s_]) = struct('i', st1, 'ii', st2, 'iii', st3, ...
            'ok', [st1.val < 0.25, st2.val >= 1.5 && st2.val <= 3.0, st3.val > 0.5]);
    end
    okv = [R.s070.ok; R.s130.ok];                       % rows s, columns (i) (ii) (iii)
    lab = {'(i)', '(ii)', '(iii)'};
    for q = 1:3
        fprintf('     %-6s s 0.7 %s, s 1.3 %s\n', lab{q}, tern(okv(1, q), 'met', 'NOT met'), tern(okv(2, q), 'met', 'NOT met'));
    end
    if k == 1
        R.reading = tern(all(okv(:)), 'SUPPORTED (sec 41.3)', 'NOT SUPPORTED');
        fprintf('     -> reading sec 42.2 (one set): %s', R.reading);
        if ~all(okv(:)), fprintf(' - failed: %s', strjoin(lab(~all(okv, 1)), ' ')); end
        fprintf('\n');
    else
        fprintf('     (unsaturated subset: printed, not the reading)\n');
    end
    G.(tern(k == 1, 'full', 'unsat')) = R;
end
end

function th_report(rows, cols)
%TH_REPORT  sec 15.4: payload swing theta RMS (t >= TStat) per column, pooled (RMS) over the one set.
th = nan(numel(rows), numel(cols));
for i = 1:numel(rows)
    for c = 1:numel(cols)
        p = rows(i).p2{c};
        if isstruct(p) && isfield(p, 'theta_rms_stat_deg'), th(i, c) = p.theta_rms_stat_deg; end
    end
end
fprintf('  payload swing theta RMS [deg], t >= TStat, pooled:');
for c = 1:numel(cols), fprintf('  %s %.2f', cols{c}, sqrt(mean(th(isfinite(th(:, c)), c).^2))); end
fprintf('\n');
end

function G = recheck(g, outf, files)
%RECHECK  Re-run the columns that were RUN (not reused) for the given segments with today's model
%  and the stored configuration; compare with the stored values at full precision. The N6 block
%  must leave every existing column bit-exact (|d| = 0, same flag).
Z = load(outf, 'rows', 'key');
k = Z.key;
opt = struct('TauW', k.TauW, 'TauPred', k.TauPred);
if isfield(k, 'TauN6'), opt.TauN6 = k.TauN6; end
im = im_args(g);
fprintf('  recheck %s (stored: TauW %.0f ms, TauPred %.0f ms) at full precision:\n', g.name, 1000 * k.TauW, ...
    1000 * k.TauPred);
G = struct('file', {}, 'col', {}, 'stored', {}, 'rerun', {}, 'd', {}, 'same', {});
for f = 1:numel(files)
    i = find(strcmp({Z.rows.file}, files{f}), 1);
    assert(~isempty(i), 'run_p2_gd7 recheck: %s is not in %s.', files{f}, outf);
    r = Z.rows(i);
    cols = k.cols(strcmp(r.src, 'run'));
    [E, F] = run_cols(files{f}, cols, g, opt, im);
    for c = 1:numel(cols)
        j = strcmp(k.cols, cols{c});
        d = abs(E(c) - r.E(j));
        same = (isequal(E(c), r.E(j)) || (isnan(E(c)) && isnan(r.E(j)))) && strcmp(F{c}, r.F{j});
        fprintf('    %-26s %-5s stored %.17g %-8s re-run %.17g %-8s |d| %.3g  %s\n', files{f}, cols{c}, r.E(j), ...
            r.F{j}, E(c), F{c}, d, tern(same, 'BIT-EXACT', 'DIFFERS'));
        G(end + 1) = struct('file', files{f}, 'col', cols{c}, 'stored', r.E(j), 'rerun', E(c), 'd', d, ...
            'same', same); %#ok<AGROW>
    end
end
fprintf('  -> %s: %d of %d values bit-exact\n', tern(all([G.same]), 'BIT-EXACT', 'NOT BIT-EXACT'), ...
    sum([G.same]), numel(G));
end

%% =====================================================================
function s = vals_text(cols, E, F)
s = '';
for c = 1:numel(cols)
    s = [s sprintf('%s %.4f%s ', cols{c}, E(c), tern(isempty(F{c}), '', ['(' F{c} ')']))]; %#ok<AGROW>
end
s = strtrim(s);
end

function s = im_text(im)
if strcmp(im{1}, 'DoHarm'), s = sprintf('DoHarm %s', mat2str(im{2}));
else, s = sprintf('DoWAxis {%s}', strjoin(cellfun(@mat2str, im{2}, 'UniformOutput', false), ', '));
end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
