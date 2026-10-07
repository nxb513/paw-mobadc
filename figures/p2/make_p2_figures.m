function S = make_p2_figures(varargin)
%MAKE_P2_FIGURES  GD11 figures 1-9 of plant P2 (REGISTER_P2 sec 62.1) -> paper/figures/p2_fig<k>_<name>.pdf / .png
%
%   make_p2_figures                          % all nine
%   make_p2_figures('Only', [1 2 4 5 6 7 8]) % saved results and wind files only (no Simulink)
%   make_p2_figures('Only', 3)               % Figure 3: re-simulates ONE CONFIRM2 segment (Simulink + wind_conf2/)
%   make_p2_figures('Only', 9)               % Figure 9: re-simulates ONE dev circle_main segment, six controllers
%   make_p2_figures('Only', [3 9], 'FromSaved', true)   % draw 3 / 9 from the time series kept in results/gd11/
%   make_p2_figures('Root', 'results/final', 'Save', false)   % preview from another result tree
%   HOANG_NOSAVE = true; make_p2_figures     % draw, write nothing (figures/nosave_on.m)
%
%  Content: every panel shows the sets and roles of docs/RESULTS_P2.md. Error bars: +-1.65 SE, paired day jackknife
%  (analysis/p2r_stat.m); subsets as analysis/p2r_subset.m ('one4' = the one set of the file, 'unsatL3' = A of
%  sec 60.3). Main configuration L 1.0 m, m_p 0.5 kg. Nothing is simulated except Figures 3 and 9, which follow the
%  rules fixed in sec 62.1 (3) and 63.5 and are saved only if every re-run column's mean error equals the stored
%  row to 1e-12; their time series are then kept in results/gd11/ ('FromSaved' redraws from those files). A figure
%  whose data are missing is not drawn, or shows "no data" in the affected row; the summary says why.
%
%  Presentation (2026-10-07, IJDC / Springer artwork rules): physical size 84 or 174 mm wide (figures/paper_size.m),
%  one sans-serif face (figures/paper_style.m), 8 pt text throughout, no titles inside the figures - only panel
%  labels (a), (b), ... with a few words; one fixed colour per controller (ctrl_colour); the paper's wording for sets
%  (development / held-out, trajectory names), never the repository codes; explanations live in the captions of
%  paper/manuscript.md.
opt = struct('Only', 1:9, 'Root', fullfile(repo_root(), 'results'), ...
    'Out', fullfile(repo_root(), 'paper', 'figures'), 'Conf2Dir', 'wind_conf2', ...
    'ExplManifest', 'wind_expl_t150_batch.json', 'Save', ~nosave_on(), 'Close', true, 'FromSaved', false);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'make_p2_figures: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
if opt.Save && exist(opt.Out, 'dir') ~= 7, mkdir(opt.Out); end
F = {@fig1_system, 'system'; @fig2_wind, 'wind'; @fig3_series, 'series'; @fig4_c1, 'c1'; ...
     @fig5_tau, 'tau'; @fig6_c2, 'c2'; @fig7_fast, 'fast'; @fig8_c3, 'c3'; @fig9_traj, 'traj'};
S = struct('fig', {}, 'drawn', {}, 'msg', {});
for k = opt.Only(:).'
    fprintf('\n  Figure %d (%s)\n', k, F{k, 2});
    fh = [];  msg = '';
    try
        [fh, msg] = F{k, 1}(opt);
    catch err
        msg = ['error: ' err.message];
    end
    if ~isempty(fh)
        save_p2(fh, opt, sprintf('p2_fig%d_%s', k, F{k, 2}));
        if opt.Close, close(fh); end
    end
    S(end + 1) = struct('fig', k, 'drawn', ~isempty(fh), 'msg', msg); %#ok<AGROW>
end
fprintf('\n  make_p2_figures summary:\n');
for k = 1:numel(S)
    fprintf('    Figure %d  %-9s %s\n', S(k).fig, tern(S(k).drawn, 'drawn', 'NOT DRAWN'), S(k).msg);
end
end

%% =====================================================================
%  1  plant and controller (schematic, no data)
%% =====================================================================
function [fh, msg] = fig1_system(~)
fh = newfig('double', 7.0);
ax = axes('Parent', fh, 'Units', 'normalized', 'Position', [0 0 1 1]);  hold(ax, 'on');
axis(ax, [0 174 0 70]);  set(ax, 'DataAspectRatio', [1 1 1]);  axis(ax, 'off');
K = [0.15 0.15 0.15];  BL = [0.00 0.45 0.70];  GR = [0.45 0.45 0.45];
% ---- (a) the plant: quadrotor, cable, payload, wind and forces (side view) ----
txt(ax, 1, 67.5, '(a)', 'FontWeight', 'bold');
yw = [60 52 44 36 28 20];  lw = [7 5.5 7.5 5 7 6];               % a gusty wind profile, drawn not measured
for i = 1:numel(yw), arr(ax, 2, yw(i), 2 + lw(i), yw(i), BL, 0.75); end
txt(ax, 2, 64.2, '\bfw\rm(t)', 'Color', BL);
plot(ax, [12 36], [53 53], '-', 'Color', K, 'LineWidth', 1.6);                       % arms
for xr = [13 35]
    plot(ax, [xr xr], [53 54.4], '-', 'Color', K, 'LineWidth', 0.75);
    t = linspace(0, 2 * pi, 60);
    patch(ax, xr + 6.5 * cos(t), 55.2 + 0.9 * sin(t), [0.86 0.86 0.86], 'EdgeColor', K, 'LineWidth', 0.5);
end
rectangle('Parent', ax, 'Position', [19 50.5 10 3], 'Curvature', [0.4 0.8], 'FaceColor', [0.35 0.35 0.35], ...
    'EdgeColor', K, 'LineWidth', 0.5);
arr(ax, 24, 54.2, 24, 63, K, 1.1);  txt(ax, 25.2, 61.6, '\bfF');
th = 20 * pi / 180;  p0 = [24 50.5];  pe = p0 + 26 * [sin(th), -cos(th)];
plot(ax, [p0(1) p0(1)], [p0(2) 19], ':', 'Color', K, 'LineWidth', 0.6);
plot(ax, [p0(1) pe(1)], [p0(2) pe(2)], '-', 'Color', K, 'LineWidth', 0.9);         % cable
t = linspace(0, th, 30);
plot(ax, p0(1) + 9 * sin(t), p0(2) - 9 * cos(t), '-', 'Color', K, 'LineWidth', 0.5);
txt(ax, p0(1) + 11.2 * sin(th / 2), p0(2) - 11.2 * cos(th / 2), '\theta', 'HorizontalAlignment', 'center');
txt(ax, 27.2, 46.2, '\bfq');
pm = p0 + 0.6 * (pe - p0) + 2.2 * [cos(th), sin(th)];
txt(ax, pm(1), pm(2), 'L', 'HorizontalAlignment', 'center');
ps = pe + 3.6 * [-sin(th), cos(th)] + 1.6 * [-cos(th), -sin(th)];
arr(ax, ps(1), ps(2), ps(1) - 7 * sin(th), ps(2) + 7 * cos(th), K, 0.9);
txt(ax, ps(1) - 4.0, ps(2) + 2.8, 'T', 'HorizontalAlignment', 'center');
t = linspace(0, 2 * pi, 80);
patch(ax, pe(1) + 3.4 * cos(t), pe(2) + 3.4 * sin(t), [0.55 0.55 0.55], 'EdgeColor', K, 'LineWidth', 0.5);
txt(ax, 18.5, 48.4, 'm_Q', 'HorizontalAlignment', 'right');
txt(ax, pe(1) + 4.2, pe(2) + 3.8, 'm_L');
arr(ax, 29.6, 51.6, 37.4, 51.6, BL, 0.9);  txt(ax, 38.0, 51.6, '\bfF\rm_{wQ}', 'Color', BL);
arr(ax, pe(1) + 3.7, pe(2), pe(1) + 11, pe(2), BL, 0.9);  txt(ax, pe(1) + 11.6, pe(2), '\bfF\rm_{wL}', 'Color', BL);
arr(ax, pe(1), pe(2) - 3.6, pe(1), pe(2) - 11, K, 0.9);  txt(ax, pe(1) + 1.2, pe(2) - 9.4, 'm_L g');
arr(ax, 5, 6, 12, 6, K, 0.6);  txt(ax, 12.6, 6, '\bfe\rm_1');
arr(ax, 5, 6, 5, 13, K, 0.6);  txt(ax, 5, 14.6, '\bfe\rm_3', 'HorizontalAlignment', 'center');
% ---- (b) the controller: baseline loop, C1 and C2 highlighted ----
C1F = [1.00 0.93 0.78];  C1E = ctrl_colour('PA-MOBADC');
C2F = [1.00 0.88 0.80];  C2E = ctrl_colour('PAW-MOBADC');
PF = [0.93 0.93 0.93];
txt(ax, 57, 67.5, '(b)', 'FontWeight', 'bold');
blk(ax, 57, 47.5, 16, 9, {'reference', '\gamma_d(t)'}, 'w', K);
arr(ax, 73, 52, 78, 52, K);
blk(ax, 78, 47.5, 20, 9, {'position law', '(Guo et al.)'}, 'w', K);
arr(ax, 98, 52, 104.6, 52, K);  txt(ax, 101.0, 55.0, 'm\bfa\rm_d', 'HorizontalAlignment', 'center');
t = linspace(0, 2 * pi, 60);
patch(ax, 107 + 2.4 * cos(t), 52 + 2.4 * sin(t), 'w', 'EdgeColor', K, 'LineWidth', 0.75);
txt(ax, 107, 52, '\Sigma', 'HorizontalAlignment', 'center');
arr(ax, 109.4, 52, 114, 52, K);  txt(ax, 111.7, 55.0, '\bfF', 'HorizontalAlignment', 'center');
blk(ax, 114, 47.5, 21, 9, {'attitude loop', '+ motor lag'}, 'w', K);
arr(ax, 135, 52, 140, 52, K);
blk(ax, 140, 47.5, 23, 9, {'quadrotor with', 'slung payload'}, PF, K);
polyarr(ax, [151.5 151.5 88 88], [56.5 62.5 62.5 56.5], K);
txt(ax, 119.75, 64.3, 'measured state', 'HorizontalAlignment', 'center');
blk(ax, 70, 29.5, 19, 9, {'disturbance', 'observer'}, 'w', K);
arr(ax, 61, 34, 70, 34, K);  txt(ax, 65.5, 36.2, 'state', 'HorizontalAlignment', 'center');
arr(ax, 89, 34, 96.6, 34, K);  txt(ax, 92.8, 36.2, '\xi', 'HorizontalAlignment', 'center');
blk(ax, 96.6, 29.5, 18.4, 9, {'prediction', '\bfB\rm e^{\bfA\rm\tau}\xi'}, C1F, C1E);
txt(ax, 115.0, 40.4, 'C1', 'FontWeight', 'bold', 'Color', C1E, 'HorizontalAlignment', 'right');
arr(ax, 105.8, 38.5, 105.8, 49.9, K);
txt(ax, 104.8, 44.6, [char(8722) '\bfd\rm_{mf}'], 'HorizontalAlignment', 'right');
blk(ax, 115, 29.5, 28, 9, {'wind feed-forward', ['\times (1 + ' khat() ')']}, C2F, C2E);
txt(ax, 143.0, 40.4, 'C2', 'FontWeight', 'bold', 'Color', C2E, 'HorizontalAlignment', 'right');
polyarr(ax, [129 129 108.2 108.2], [38.5 44.2 44.2 49.9], K);
txt(ax, 118.6, 46.9, [char(8722) '\bfd\rm_{lf}'], 'HorizontalAlignment', 'center');
blk(ax, 64, 8, 31, 12.5, {'INDI-DE (compared):', 'estimate from', 'acceleration'}, 'w', GR, '--');
arr(ax, 79.5, 20.5, 79.5, 29.5, GR, 0.75, '--');  txt(ax, 81, 25, 'replaces', 'Color', GR);
blk(ax, 115, 11.5, 28, 9, {'wind sensor', '20 Hz, 50 ms delay'}, 'w', K);
arr(ax, 129, 20.5, 129, 29.5, K);  txt(ax, 130.2, 25, '\bfw\rm_s');
blk(ax, 146.5, 11.5, 26, 9, {'wind \bfw\rm(t)', 'NREL M5 record'}, PF, K);
arr(ax, 151.5, 20.5, 151.5, 47.5, K);
arr(ax, 146.5, 16, 143, 16, K);
msg = 'schematic, no data';
end

function k = khat()
%KHAT  K with a circumflex (combining U+0302) - the TeX interpreter has no \hat.
k = char([75 770]);
end

%% =====================================================================
%  2  wind data: U and TI, development pool vs held-out days
%% =====================================================================
function [fh, msg] = fig2_wind(opt)
fh = [];
Zf = load('field_grid_K050.mat', 'T');
man = jsondecode(fileread(opt.ExplManifest));
fd = [cellstr(Zf.T.file(:)); cellstr(man.files(:))];
bj = fullfile(opt.Conf2Dir, 'wind_conf2_t150_batch.json');
if exist(bj, 'file') ~= 2, msg = sprintf('%s not found', bj); return; end
mc = jsondecode(fileread(bj));
fc = cellstr(mc.files(:));
fc = cellfun(@(f) fullfile(opt.Conf2Dir, f), fc, 'UniformOutput', false);
[Ud, Td, dd] = segwind(fd);  [Uc, Tc, dc] = segwind(fc);
CH = {'2024-01-18', '2024-04-15'};                       % D23: not in CONFIRM2
assert(~any(ismember(dc, CH)), 'fig2: a CONFIRM2 segment lies on a characterisation day (D23).');
ENV = [8.02 10.86 13.30];                                % sec 62.1 (2), A2 envelopes (named in the caption)
fprintf('    dev pool %d segments / %d days, CONFIRM2 %d segments / %d days\n', numel(Ud), numel(unique(dd)), ...
    numel(Uc), numel(unique(dc)));
CD = [0.55 0.55 0.55];  CC = [0.10 0.10 0.10];
fh = newfig('double', 5.6);
tl = tiledlayout(fh, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
ld = sprintf('development (%d segments)', numel(Ud));
lc = sprintf('held-out (%d segments)', numel(Uc));
ax = nexttile(tl);  hold(ax, 'on');  sty(ax);
e = 0:0.5:ceil(max([Ud; Uc]) + 0.5);
h1 = fracstairs(ax, Ud, e, CD, true);  h2 = fracstairs(ax, Uc, e, CC, false);
envlines(ax, ENV);
xlabel(ax, 'mean wind speed U [m/s]');  ylabel(ax, 'fraction of segments');  plab(ax, '(a)');
ax = nexttile(tl);  hold(ax, 'on');  sty(ax);
e = 0:0.025:max(0.6, ceil(40 * max([Td; Tc])) / 40);
fracstairs(ax, Td, e, CD, true);  fracstairs(ax, Tc, e, CC, false);
xlabel(ax, 'turbulence intensity \sigma_u / U');  ylabel(ax, 'fraction of segments');  plab(ax, '(b)');
ax = nexttile(tl);  hold(ax, 'on');  sty(ax);
plot(ax, Ud, Td, '.', 'Color', CD, 'MarkerSize', 5);
plot(ax, Uc, Tc, 'o', 'Color', CC, 'MarkerSize', 2.6, 'LineWidth', 0.5);
envlines(ax, ENV);
xlabel(ax, 'mean wind speed U [m/s]');  ylabel(ax, 'turbulence intensity');  plab(ax, '(c)');
hl = [plot(ax, NaN, NaN, 's', 'MarkerFaceColor', 0.65 + 0.35 * CD, 'MarkerEdgeColor', CD, 'MarkerSize', 6), ...
      plot(ax, NaN, NaN, 'o', 'Color', CC, 'MarkerSize', 3, 'LineWidth', 0.5)];
leg(ax, hl, {ld, lc}, 'Location', 'northeast', 'Token', [8 8]);
msg = sprintf('dev %d / CONFIRM2 %d segments; DESCRIPTIVE', numel(Ud), numel(Uc));
end

function [U, TI, day] = segwind(files)
%SEGWIND  U as p2_segset (norm of the mean horizontal plant wind, t >= 140 s); TI = std of the wind projected on
%  that mean direction / U, same window.
n = numel(files);  U = nan(n, 1);  TI = U;  day = cell(n, 1);
for i = 1:n
    M = load(files{i}, 't_plant', 'w_plant', 'real_file');
    w = M.w_plant(M.t_plant(:) >= 140, 1:2);
    mu = mean(w, 1);  U(i) = norm(mu);
    TI(i) = std(w * (mu(:) / U(i))) / U(i);
    rf = strtrim(char(M.real_file));
    day{i} = [rf(7:10) '-' rf(1:2) '-' rf(4:5)];
end
end

function h = fracstairs(ax, x, e, col, filled)
n = histc(x(:), e);  n = n(:).' / numel(x); %#ok<HISTC>
[xs, ys] = stairs(e, n);
if filled
    patch(ax, [xs(1); xs(:); xs(end)], [0; ys(:); 0], col, 'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
end
h = plot(ax, xs, ys, '-', 'Color', col, 'LineWidth', 0.9);
end

function envlines(ax, ENV)
yl = get(ax, 'YLim');
for k = 1:numel(ENV)
    plot(ax, ENV(k) * [1 1], yl, ':', 'Color', [0.25 0.25 0.25], 'LineWidth', 0.75, 'HandleVisibility', 'off');
end
set(ax, 'YLim', yl);
end

%% =====================================================================
%  3  illustrative time series (registered segment rule; re-simulated, agreement check)
%% =====================================================================
function [fh, msg] = fig3_series(opt)
fh = [];
Zs = load(fullfile(opt.Root, 'gd10', 'sets.mat'), 'Sets');
s = Zs.Sets.circle;
files = s.files(:);  U = s.U(:);  n = numel(files);
[~, o1] = sort(files);                                   % ties: file name
[~, o2] = sort(U(o1));                                   % stable sort by U
idx = o1(o2);
k = ceil(n / 2);                                         % lower median (28th of 56)
fn = files{idx(k)};
fprintf('    CONFIRM2 circle set: %d segments; lower median U = %.4f m/s (rank %d): %s\n', n, U(idx(k)), k, fn);
nm = p2_names({'L2', 'L3', 'L3_iii0', 'H3'});
saved = fullfile(opt.Root, 'gd11', ['series_' strrep(fn, '.mat', '') '.mat']);
if opt.FromSaved
    if exist(saved, 'file') ~= 2, msg = sprintf('%s not found (run once without FromSaved)', saved); return; end
    Z = load(saved, 'T');  T = Z.T;
    how = sprintf('%s; drawn from the saved time series %s (not re-simulated)', fn, saved);
else
    % the frozen model and code only (REGISTER_P2 sec 60.6 rule, sec 61.5): a local change stops before any simulation
    [st, out] = system(sprintf('git -C "%s" status --porcelain -- baseline1.slx core experiments', repo_root()));
    if st ~= 0
        msg = sprintf('git status failed (%d) - not run: %s', st, strtrim(out));
        return
    end
    if ~isempty(strtrim(out))
        msg = sprintf('local change in baseline1.slx / core / experiments - not run:%s%s', newline, out);
        return
    end
    D2 = load(fullfile(opt.Root, 'gd10', 'D2.mat'), 'rows');
    C2 = load(fullfile(opt.Root, 'gd10', 'C2-circle.mat'), 'rows', 'key');
    i2 = find(strcmp({D2.rows.file}, fn), 1);  ic = find(strcmp({C2.rows.file}, fn), 1);
    assert(~isempty(i2) && ~isempty(ic), 'fig3: %s not in the stored CONFIRM2 rows.', fn);
    stored = [D2.rows(i2).E(2), D2.rows(i2).E(3), C2.rows(ic).E(strcmp(C2.key.cols, 'L3_iii0')), ...
              C2.rows(ic).E(strcmp(C2.key.cols, 'H3'))];
    ff = fullfile(opt.Conf2Dir, fn);
    % the calls of run_p2_gd6 D2 (L2, L3) and run_p2_gd7 C2-circle (L3_iii0, H3), unchanged, + KeepTraj / KeepLog
    b6 = {'Grid', true, 'PlantModel', 'p2', 'SensorDelayMs', 50, 'PayloadModel', 1, 'PayloadWind', 0.5, ...
          'OnDiverge', 'flag', 'Quiet', true, 'PredDelay', true, 'Cond', 'Test 4'};
    b7 = [b6, {'L', 1.0, 'DoHarm', [0 1], 'TauPred', 0.290, 'TauPrev', 0, 'Only', {'g_psens'}, 'OracleTauMs', 280}];
    kl = {'KeepTraj', true, 'KeepLog', {'p2_mon_log'}};
    [~, A] = pa_configs(ff, b6{:}, 'DoHarm', [0 1], 'Only', {'g_sens', 'g_psens'}, 'TauPred', 0.290, 'TauPrev', 0, kl{:});
    try, Simulink.sdi.clear; catch, end
    [~, B] = pa_configs(ff, b7{:}, 'P2PredScale', [1 1 1 1.5], kl{:});
    try, Simulink.sdi.clear; catch, end
    [~, C] = pa_configs(ff, b7{:}, 'P2Cmp', 1, 'P2H3Hz', 32, kl{:});
    try, Simulink.sdi.clear; catch, end
    M = {A.g_sens, A.g_psens, B.g_psens, C.g_psens};
    re = cellfun(@(m) m.mean, M);
    d = abs(re - stored);
    for c = 1:4
        fprintf('    %-10s re-run %.15f  stored %.15f  |d| %.3g\n', nm{c}, re(c), stored(c), d(c));
        if isfield(M{c}, 'crash_msg') && ~isempty(M{c}.crash_msg)
            fprintf('               solver stopped: %s\n', M{c}.crash_msg);
        end
    end
    if ~all(d <= 1e-12)
        msg = sprintf('agreement check FAILED (max |d| %.3g > 1e-12) - figure not saved', max(d));
        return
    end
    T = struct('file', fn, 'U', U(idx(k)), 'names', {nm}, 'mean', re, ...
        't', {cellfun(@(m) m.t, M, 'UniformOutput', false)}, 'g', {cellfun(@(m) m.g, M, 'UniformOutput', false)}, ...
        'gd', {cellfun(@(m) m.gd, M, 'UniformOutput', false)}, ...
        'tl', {cellfun(@(m) m.log.p2_mon_log.t, M, 'UniformOutput', false)}, ...
        'theta', {cellfun(@(m) m.log.p2_mon_log.v(:, 5), M, 'UniformOutput', false)});
    od = fullfile(opt.Root, 'gd11');  if exist(od, 'dir') ~= 7, mkdir(od); end
    save(saved, 'T');
    how = sprintf('%s; re-run = stored to %.1g (max |d|); time series in results/gd11/', fn, max(d));
end
fh = newfig('double', 8.0);
tl = tiledlayout(fh, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl);  hold(ax1, 'on');  sty(ax1);
ax2 = nexttile(tl);  hold(ax2, 'on');  sty(ax2);
h = gobjects(1, 4);
for c = 1:4
    ms = T.t{c} >= 140;
    e = sqrt(sum((T.gd{c}(ms, :) - T.g{c}(ms, :)).^2, 2));
    h(c) = plot(ax1, T.t{c}(ms), 1000 * e, '-', 'Color', ctrl_colour(T.names{c}), 'LineWidth', 0.75);
    mt = T.tl{c}(:) >= 140;
    plot(ax2, T.tl{c}(mt), T.theta{c}(mt) * 180 / pi, '-', 'Color', ctrl_colour(T.names{c}), 'LineWidth', 0.75);
end
ylabel(ax1, 'position error [mm]');  ylabel(ax2, 'cable angle \theta [\circ]');  xlabel(ax2, 'time t [s]');
plab(ax1, '(a)');  plab(ax2, '(b)');
linkaxes([ax1 ax2], 'x');  xlim(ax1, [140 max(T.t{1})]);
yl = ylim(ax1);  ylim(ax1, [0 yl(2) * 1.25]);
leg(ax1, h, arrayfun(@(c) sprintf('%s (mean %s mm)', T.names{c}, num(1000 * T.mean(c), '%.1f')), 1:4, ...
    'UniformOutput', false), 'Location', 'north', 'Orientation', 'horizontal', 'NumColumns', 4, 'Box', 'off', ...
    'FontSize', 8, 'Token', [12 8]);
msg = how;
end

%% =====================================================================
%  9  six controllers on one dev circle_main segment, x-y (REGISTER_P2 sec 63.5; as Guo 2020 Fig. 10)
%% =====================================================================
function [fh, msg] = fig9_traj(opt)
fh = [];
S = p2_segset('circle_main', 'CapPerDay', 4, 'Quiet', true);
assert(strncmp(S.sha256, 'a227e9d87a2ac436', 16), 'fig9: circle_main is not the registered set.');
D2 = load(fullfile(opt.Root, 'gd6', 'd2_p2.mat'), 'rows');
U = nan(numel(D2.rows), 1);  ts = U;
for i = 1:numel(D2.rows)
    k = find(strcmp(S.files, D2.rows(i).file), 1);
    if ~isempty(k), U(i) = S.U(k); end
    p = D2.rows(i).p2{3};
    if isstruct(p) && isfield(p, 'tilt_sat_frac') && isfinite(D2.rows(i).E(3)), ts(i) = p.tilt_sat_frac; end
end
cand = find(ts < 0.01 & isfinite(U));                    % rule sec 63.5: PA-MOBADC tilt clamp < 1 %
md = median(U(cand));
dU = abs(U(cand) - md);
tie = cand(dU == min(dU));
[~, o] = sort({D2.rows(tie).file});                      % ties: smallest segment index (file name)
fn = D2.rows(tie(o(1))).file;
fprintf('    dev circle_main: %d of %d segments with PA-MOBADC tilt_sat < 1 %%; median U %.4f m/s; chosen %s (U %.4f)\n', ...
    numel(cand), numel(D2.rows), md, fn, U(strcmp({D2.rows.file}, fn)));
saved = fullfile(opt.Root, 'gd11', ['traj_' strrep(fn, '.mat', '') '.mat']);
if opt.FromSaved
    if exist(saved, 'file') ~= 2, msg = sprintf('%s not found (run once without FromSaved)', saved); return; end
    Z = load(saved, 'T');  T = Z.T;
    how = sprintf('%s; drawn from the saved time series %s (not re-simulated)', fn, saved);
else
    [st, out] = system(sprintf('git -C "%s" status --porcelain -- baseline1.slx core experiments', repo_root()));
    if st ~= 0 || ~isempty(strtrim(out))
        msg = sprintf('git status failed or local change in baseline1.slx / core / experiments - not run:%s%s', newline, out);
        return
    end
    % stored values: Guo's four (guo_p2), INDI-DE and PAW-MOBADC (six-circle-h3, sec 63.4)
    G = load(fullfile(opt.Root, 'gd6', 'guo_p2.mat'), 'rows', 'key');
    sx = fullfile(opt.Root, 'gd7', 'six-circle-h3.mat');      % sec 63.4: variant B
    X = load(sx, 'rows', 'key');
    ig = find(strcmp({G.rows.file}, fn), 1);  ix = find(strcmp({X.rows.file}, fn), 1);
    assert(~isempty(ig) && ~isempty(ix), 'fig9: %s not in guo_p2 / %s.', fn, sx);
    CT = {'Classical', {'0', '0', '0'}; 'DO', {'1', '0', '0'}; 'ESO', {'0', '1', '1'}; 'MOBADC', {'1', '1', '1'}};
    nm = [p2_names(CT(:, 1)'), {'INDI-DE', 'PAW-MOBADC (proposed)'}];
    stored = [arrayfun(@(c) G.rows(ig).E(strcmp(G.key.ctrl, CT{c, 1})), 1:4), ...
              X.rows(ix).E(strcmp(X.key.cols, 'H3')), X.rows(ix).E(strcmp(X.key.cols, 'L3_iii0'))];
    pa = {'Grid', true, 'PlantModel', 'p2', 'SensorDelayMs', 50, 'PayloadModel', 1, 'PayloadWind', 0.5, ...
          'OnDiverge', 'flag', 'Quiet', true, 'PredDelay', true, 'Cond', 'Test 4', 'L', 1.0};
    bg = [pa, {'DoHarm', 1, 'Only', {'g_base'}, 'TauPred', 0.290, 'TauPrev', 0, 'KeepTraj', true}];    % run_p2_gd6 GUO
    b7 = [pa, {'DoHarm', [0 1], 'TauPred', 0.290, 'TauPrev', 0, 'Only', {'g_psens'}, 'OracleTauMs', 280, ...
          'KeepTraj', true}];                                                                             % run_p2_gd7
    M = cell(1, 6);
    for c = 1:4
        [~, R] = pa_configs(fn, bg{:}, 'Switches', CT{c, 2});  M{c} = R.g_base;
        try, Simulink.sdi.clear; catch, end
    end
    [~, R] = pa_configs(fn, b7{:}, 'P2Cmp', 1, 'P2H3Hz', 32);  M{5} = R.g_psens;
    try, Simulink.sdi.clear; catch, end
    [~, R] = pa_configs(fn, b7{:}, 'P2PredScale', [1 1 1 1.5]);  M{6} = R.g_psens;
    try, Simulink.sdi.clear; catch, end
    re = cellfun(@(m) m.mean, M);  d = abs(re - stored);
    for c = 1:6
        fprintf('    %-22s re-run %.15f  stored %.15f  |d| %.3g\n', nm{c}, re(c), stored(c), d(c));
    end
    if ~all(d <= 1e-12)
        msg = sprintf('agreement check FAILED (max |d| %.3g > 1e-12) - figure not saved', max(d));
        return
    end
    T = struct('file', fn, 'names', {nm}, 't', {cellfun(@(m) m.t, M, 'UniformOutput', false)}, ...
        'g', {cellfun(@(m) m.g, M, 'UniformOutput', false)}, 'gd', {cellfun(@(m) m.gd, M, 'UniformOutput', false)}, ...
        'mean', re);
    od = fullfile(opt.Root, 'gd11');  if exist(od, 'dir') ~= 7, mkdir(od); end
    save(saved, 'T');
    how = sprintf('%s; re-run = stored to %.1g (max |d|); time series in results/gd11/', fn, max(d));
end
fh = newfig('double', 11.6);
tl = tiledlayout(fh, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
lim = 0;                                                 % one scale for the six panels
for c = 1:6
    ms = T.t{c} >= 140;
    lim = max([lim; abs(reshape(T.g{c}(ms, 1:2), [], 1)); abs(reshape(T.gd{c}(ms, 1:2), [], 1))]);
end
lim = 1.05 * lim;
L = 'abcdef';
for c = 1:6
    ax = nexttile(tl);  hold(ax, 'on');  sty(ax);
    ms = T.t{c} >= 140;
    plot(ax, T.gd{c}(ms, 1), T.gd{c}(ms, 2), '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.75);
    plot(ax, T.g{c}(ms, 1), T.g{c}(ms, 2), '-', 'Color', ctrl_colour(T.names{c}), 'LineWidth', 0.75);
    axis(ax, 'equal');  axis(ax, [-lim lim -lim lim]);
    plab(ax, sprintf('(%s) %s, mean %s mm', L(c), T.names{c}, num(1000 * T.mean(c), '%.1f')));
end
xlabel(tl, 'x [m]', 'FontSize', 8);  ylabel(tl, 'y [m]', 'FontSize', 8);
msg = how;
end

%% =====================================================================
%  4  C1: PA-MOBADC / MOBADC-W - 1 and preview per trajectory; per-segment scatter
%% =====================================================================
function [fh, msg] = fig4_c1(opt)
fh = [];
rel = @(p) p(1) / p(2) - 1;
G = {'circle\newlinedevelopment', 'gd6/d2_p2.mat';
     'circle\newlineheld-out', 'gd10/D2.mat';
     'figure-eight\newlinedevelopment', 'gd6/tab_T3b_p2.mat';
     'square\newlinedevelopment', 'gd6/tab_square_p2.mat'};
ng = size(G, 1);
R3 = cell(ng, 1);  RV = R3;
for i = 1:ng
    R3{i} = rstat(opt, G{i, 2}, {'L3', 'L2'}, rel, 'one4');
    RV{i} = rstat(opt, G{i, 2}, {'V', 'L2'}, rel, 'one4');
end
if all(cellfun(@isempty, R3)), msg = 'no D2 / TAB file found'; return; end
fh = newfig('double', 7.0);
tl = tiledlayout(fh, 1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl, [1 3]);  hold(ax, 'on');  sty(ax);
c3 = ctrl_colour('PA-MOBADC');  cv = ctrl_colour('MOBADC-W + preview');
h = gobjects(1, 2);
for i = 1:ng
    a = vpoint(ax, i - 0.14, R3{i}, c3, 'o', 'left');  if ~isempty(a), h(1) = a; end
    a = vpoint(ax, i + 0.14, RV{i}, cv, 's', 'right');  if ~isempty(a), h(2) = a; end
end
yl = get(ax, 'YLim');  yl = [yl(1) - 0.06 * diff(yl), max(yl(2), 0) + 0.16 * diff(yl)];
set(ax, 'YLim', yl);
for i = 1:ng
    if ~isempty(R3{i})
        text(ax, i, yl(2), sprintf('n = %d', R3{i}.n), 'FontSize', 8, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    else
        text(ax, i, mean(yl), 'no data', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);
    end
end
plot(ax, [0.25 ng + 0.6], [0 0], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
set(ax, 'XLim', [0.25 ng + 0.6], 'XTick', 1:ng, 'XTickLabel', G(:, 1), 'TickLabelInterpreter', 'tex', 'YGrid', 'on');
ylabel(ax, 'change of the pooled error [%]');  plab(ax, '(a)');
if all(isgraphics(h))
    leg(ax, h, {['PA-MOBADC / MOBADC-W ' char(8722) ' 1'], ['(MOBADC-W + preview) / MOBADC-W ' char(8722) ' 1']}, ...
        'Location', 'northoutside', 'Orientation', 'horizontal', 'Token', [8 8]);
end
ax = nexttile(tl, [1 2]);  hold(ax, 'on');  sty(ax);
SC = {'gd6/d2_p2.mat', [0.60 0.60 0.60], '.', 'development', 6;  'gd10/D2.mat', [0.10 0.10 0.10], 'o', 'held-out', 3};
hh = gobjects(0);  ll = {};  lo = Inf;  hi = 0;
for i = 1:2
    [Z, cols, ok] = p2r_load(opt.Root, SC{i, 1});
    if ~ok, continue; end
    [E, ~, ~, keep] = p2r_subset(Z, cols, {'L2', 'L3'}, 'one4');
    E = 1000 * E(keep, :);
    hh(end + 1) = plot(ax, E(:, 1), E(:, 2), SC{i, 3}, 'Color', SC{i, 2}, 'MarkerSize', SC{i, 5}, 'LineWidth', 0.5); %#ok<AGROW>
    ll{end + 1} = sprintf('%s (%d segments)', SC{i, 4}, size(E, 1)); %#ok<AGROW>
    lo = min(lo, min(E(:)));  hi = max(hi, max(E(:)));
end
if isfinite(lo)
    lim = [lo / 1.3, hi * 1.3];
    plot(ax, lim, lim, '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
    tk = [1 2 5 10 20 50 100 200 500];  tk = tk(tk >= lim(1) & tk <= lim(2));
    set(ax, 'XScale', 'log', 'YScale', 'log', 'XLim', lim, 'YLim', lim, 'XTick', tk, 'YTick', tk, ...
        'XTickLabel', arrayfun(@num2str, tk, 'UniformOutput', false), ...
        'YTickLabel', arrayfun(@num2str, tk, 'UniformOutput', false), 'XMinorTick', 'off', 'YMinorTick', 'off');
    axis(ax, 'square');
    leg(ax, hh, ll, 'Location', 'northwest', 'Box', 'off', 'FontSize', 8, 'Token', [8 8]);
end
xlabel(ax, 'MOBADC-W, error per segment [mm]');  ylabel(ax, 'PA-MOBADC, error per segment [mm]');
plab(ax, '(b)');
msg = 'C1; sets and roles on the axis';
end

%% =====================================================================
%  5  horizon tau: pooled error vs payload-prediction horizon (N0P)
%% =====================================================================
function [fh, msg] = fig5_tau(opt)
fh = [];
f = fullfile(opt.Root, 'gd6', 'n0p_p2.mat');
if exist(f, 'file') ~= 2, msg = sprintf('%s not found', f); return; end
Z = load(f, 'T');
T = Z.T(strcmp({Z.T.mode}, 'N0P'));
if isempty(T), msg = 'no N0P row in n0p_p2.mat'; return; end
ORD = {'circle', 'T3b', 'square', 'T5', 'hover', 'circle_L05', 'circle_L15'};   % the paper's order
[~, o] = sort(cellfun(@(l) tern(any(strcmp(ORD, l)), find(strcmp(ORD, l), 1), 99), {T.label}));
T = T(o);
NAME = {'circle', 'circle';  'T3b', 'figure-eight';  'square', 'square';  'hover', 'hover';  'T5', 'multisine';
        'circle_L15', 'circle, L = 1.5 m';  'circle_L05', 'circle, L = 0.5 m'};
n = numel(T);  nc = 4;  nr = ceil((n + 1) / nc);
fh = newfig('double', 4.3 * nr + 0.8);
tl = tiledlayout(fh, nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');
c3 = ctrl_colour('PA-MOBADC');  L = 'abcdefgh';
for j = 1:n
    ax = nexttile(tl);  hold(ax, 'on');  sty(ax);
    t = T(j);
    k = find(strcmp(NAME(:, 1), t.label), 1);
    assert(~isempty(k), 'fig5: no paper name for the N0P condition ''%s''.', t.label);
    hc = plot(ax, 1000 * t.coarse.tau, 1000 * t.coarse.R, '-o', 'Color', [0.45 0.45 0.45], 'MarkerSize', 2.5, ...
        'LineWidth', 0.75);
    hf = [];  hs = [];
    if isstruct(t.fine) && ~isempty(t.fine)
        hf = plot(ax, 1000 * t.fine.tau, 1000 * t.fine.R, 's', 'Color', c3, 'MarkerSize', 3, 'LineWidth', 0.75);
        kk = find(abs(t.fine.tau - t.tau_star) < 1e-9, 1);
        if ~isempty(kk)
            hs = plot(ax, 1000 * t.tau_star, 1000 * t.fine.R(kk), 'p', 'MarkerFaceColor', c3, 'Color', c3, ...
                'MarkerSize', 7);
        end
    end
    yl = ylim(ax);
    plot(ax, 1000 * t.tau_star * [1 1], yl, ':', 'Color', c3, 'LineWidth', 0.75);  ylim(ax, yl);
    set(ax, 'XLim', [0 400]);
    right = 1000 * t.tau_star < 200;
    text(ax, 1000 * t.tau_star + tern(right, 12, -12), yl(2) - 0.06 * diff(yl), ...
        sprintf('\\tau* = %.0f ms%s', 1000 * t.tau_star, tern(t.edge_ok, '', ' (edge)')), ...
        'HorizontalAlignment', tern(right, 'left', 'right'), 'VerticalAlignment', 'top', 'FontSize', 8);
    plab(ax, sprintf('(%s) %s', L(j), NAME{k, 2}));
end
ax = nexttile(tl);  axis(ax, 'off');  hold(ax, 'on');
p = [plot(ax, NaN, NaN, '-o', 'Color', [0.45 0.45 0.45], 'MarkerSize', 2.5, 'LineWidth', 0.75), ...
     plot(ax, NaN, NaN, 's', 'Color', c3, 'MarkerSize', 3, 'LineWidth', 0.75), ...
     plot(ax, NaN, NaN, 'p', 'MarkerFaceColor', c3, 'Color', c3, 'MarkerSize', 7)];
leg(ax, p, {'coarse grid', 'fine grid', 'chosen horizon \tau*'}, 'Location', 'west');
xlabel(tl, 'prediction horizon \tau [ms]', 'FontSize', 8);
ylabel(tl, 'pooled error of PA-MOBADC [mm]', 'FontSize', 8);
msg = sprintf('%d N0P condition(s); set: dev A4 fixed-5 (%d segments); tuning, DESCRIPTIVE', n, numel(T(1).files));
end

%% =====================================================================
%  6  C2: forest of h + control effort and payload swing
%% =====================================================================
function [fh, msg] = fig6_c2(opt)
fh = [];
hh = @(p) 1 - p(2) / p(1);
X = char(215);
FR = {'hover, development, unsaturated', 'gd7/static-hover.mat', {'L3', 'L3_iii0'}, 'unsatL3', false;
      'hover, development, all segments', 'gd7/static-hover.mat', {'L3', 'L3_iii0'}, 'one4', false;
      'hover, development, 1/day', 'gd7/static-hover-k.mat', {'L3', 'L3_iii0'}, 'one4', false;
      ['hover, development, 1/day, ' khat() ' ' X ' 0.7'], 'gd7/static-hover-k.mat', {'L3', 'L3_iii0_k070'}, 'one4', false;
      ['hover, development, 1/day, ' khat() ' ' X ' 1.3'], 'gd7/static-hover-k.mat', {'L3', 'L3_iii0_k130'}, 'one4', false;
      'hover, held-out, unsaturated (registered)', 'gd10/C2-hover.mat', {'L3', 'L3_iii0'}, 'unsatL3', true;
      'circle, development, 1/day', 'gd7/static-circle.mat', {'L3', 'L3_iii0'}, 'one4', false;
      'circle, held-out, unsaturated (registered)', 'gd10/C2-circle.mat', {'L3', 'L3_iii0'}, 'unsatL3', true};
n = size(FR, 1);  R = cell(n, 1);
for i = 1:n, R{i} = rstat(opt, FR{i, 2}, FR{i, 3}, hh, FR{i, 4}); end
if all(cellfun(@isempty, R)), msg = 'no C2 file found'; return; end
fh = newfig('double', 13.0);
ax = axes('Parent', fh, 'Units', 'normalized', 'Position', [0.335 0.635 0.645 0.335]);  hold(ax, 'on');  sty(ax);
cl = repmat([0.45 0.45 0.45], n, 1);  ic = [FR{:, 5}];  cl(ic, :) = repmat(ctrl_colour('PAW-MOBADC'), sum(ic), 1);
forest(ax, FR(:, 1), R, cl);
xlabel(ax, ['h = 1 ' char(8722) ' PAW-MOBADC / PA-MOBADC [%]']);  plab(ax, '(a)');
CF = {'MOBADC-W', 'gd10/D2.mat', 'L2', 'gd6/d2_p2.mat', 'L2';
      'PA-MOBADC', 'gd10/D2.mat', 'L3', 'gd6/d2_p2.mat', 'L3';
      'PAW-MOBADC', 'gd10/C2-circle.mat', 'L3_iii0', 'gd7/static-circle.mat', 'L3_iii0';
      'INDI-DE', 'gd10/C2-circle.mat', 'H3', 'gd7/H3-circle.mat', 'H3';
      'PA-MOBADC', 'gd10/C2-hover.mat', 'L3', 'gd7/static-hover.mat', 'L3';
      'PAW-MOBADC', 'gd10/C2-hover.mat', 'L3_iii0', 'gd7/static-hover.mat', 'L3_iii0';
      'INDI-DE', 'gd10/C2-hover.mat', 'H3', 'gd7/static-hover.mat', 'H3'};
x = [1 2 3 4 5.6 6.6 7.6];
Q = {'u_osc', 'theta_rms_stat_deg', 'theta_max_stat_deg'};
YL = {'rotor-force oscillation u_{osc} [N]', 'cable angle, RMS [\circ]', 'cable angle, maximum [\circ]'};
for q = 1:3
    ax = axes('Parent', fh, 'Units', 'normalized', 'Position', [0.075 + (q - 1) * 0.325, 0.135, 0.245, 0.37]);
    hold(ax, 'on');  sty(ax);
    for i = 1:size(CF, 1)
        col = ctrl_colour(CF{i, 1});
        v = colvals(opt, CF{i, 2}, CF{i, 3}, Q{q});
        if ~isempty(v)
            if q == 3, b = median(v); else, b = sqrt(mean(v.^2)); end
            if q == 3                                       % log axis: the median as a bar-wide tick
                plot(ax, x(i) + [-0.3 0.3], [b b], '-', 'Color', col, 'LineWidth', 2);
            else
                vbar(ax, x(i), b, 0.62, 0.65 + 0.35 * col, col);
            end
            jit = 0.2 * (mod((1:numel(v))', 7) / 6 - 0.5);
            plot(ax, x(i) + jit, v, '.', 'Color', 0.75 * col, 'MarkerSize', 4);
        end
        if q > 1
            w = colvals(opt, CF{i, 4}, CF{i, 5}, Q{q});
            if ~isempty(w)
                if q == 3, b = median(w); else, b = sqrt(mean(w.^2)); end
                plot(ax, x(i) + 0.42, b, 'd', 'Color', [0.1 0.1 0.1], 'MarkerSize', 3.5, 'LineWidth', 0.5);
            end
        end
    end
    set(ax, 'XTick', x, 'XTickLabel', CF(:, 1), 'XLim', [0.4 8.2], 'XTickLabelRotation', 40, 'YGrid', 'on');
    if q == 3, set(ax, 'YScale', 'log', 'YMinorGrid', 'off', 'YMinorTick', 'off'); end
    yl = get(ax, 'YLim');
    if q == 3, yl(2) = yl(2) * 1.35; else, yl(2) = yl(1) + 1.15 * diff(yl); end
    plot(ax, [4.8 4.8], yl, '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);  set(ax, 'YLim', yl);
    text(ax, 2.5, yl(2), 'circle', 'FontSize', 8, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(ax, 6.6, yl(2), 'hover', 'FontSize', 8, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    ylabel(ax, YL{q});  plab(ax, sprintf('(%s)', char('a' + q)));
end
msg = 'C2 forest (CLAIM on CONFIRM2, POST-HOC on dev) + descriptive effort / swing';
end

function v = colvals(opt, f, c, q)
%COLVALS  One stored per-segment quantity of one column on the file's one set: u_osc (rows.Q(5, :), CONFIRM2 rows
%  only) or a p2_summary field. Empty if the file, the column or the quantity is absent.
v = [];
[Z, cols, ok] = p2r_load(opt.Root, f);
if ~ok || ~any(strcmp(cols, c)), return; end
[~, ~, ~, keep] = p2r_subset(Z, cols, {c}, 'one4');
j = find(strcmp(cols, c), 1);
if strcmp(q, 'u_osc')
    if ~isfield(Z.rows, 'Q'), return; end
    v = arrayfun(@(r) r.Q(5, j), Z.rows(:));
else
    v = p2r_p2(Z, cols, {c}, q);
end
v = v(keep);  v = v(isfinite(v));
end

%% =====================================================================
%  7  fast measurement (INDI-DE) vs prediction (PA-MOBADC, PAW-MOBADC)
%% =====================================================================
function [fh, msg] = fig7_fast(opt)
fh = [];
G = {'circle\newlineheld-out', 'gd10/C2-circle.mat', {'L3', 'L3_iii0', 'H3'};
     'circle\newlinedev.', 'gd7/H3-circle.mat', {'L3', 'H3'};
     'circle\newlinedev.\newline1/day', 'gd7/static-circle.mat', {'L3', 'L3_iii0'};
     'hover\newlineheld-out', 'gd10/C2-hover.mat', {'L3', 'L3_iii0', 'H3'};
     'hover\newlinedev.', 'gd7/static-hover.mat', {'L3', 'L3_iii0', 'H3'}};
rel = @(p) p(1) / p(2) - 1;
RT = {'circle, development', 'gd7/H3-circle.mat', {'H3', 'L3'}, 1;
      'circle, held-out', 'gd10/C2-circle.mat', {'H3', 'L3'}, 1;
      'hover, development', 'gd7/H3-hover.mat', {'H3', 'L3'}, 1;
      'hover, held-out', 'gd10/C2-hover.mat', {'H3', 'L3'}, 1;
      'circle, held-out', 'gd10/C2-circle.mat', {'L3_iii0', 'H3'}, 2;
      'hover, development', 'gd7/static-hover.mat', {'L3_iii0', 'H3'}, 2;
      'hover, held-out', 'gd10/C2-hover.mat', {'L3_iii0', 'H3'}, 2};
R = cell(size(RT, 1), 1);
for i = 1:numel(R), R{i} = rstat(opt, RT{i, 2}, RT{i, 3}, rel, 'one4'); end
if all(cellfun(@isempty, R)), msg = 'no H3 / C2 file found'; return; end
fh = newfig('double', 7.5);
tl = tiledlayout(fh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
cn = {'L3', 'L3_iii0', 'H3'};  ln = p2_names(cn);
ax = nexttile(tl);  hold(ax, 'on');  sty(ax);
hb = gobjects(1, 3);  NT = nan(size(G, 1), 2);  lo = Inf;  hi = 0;
for g = 1:size(G, 1)
    [Z, cols, ok] = p2r_load(opt.Root, G{g, 2});
    if ~ok, continue; end
    [E, ~, ~, keep] = p2r_subset(Z, cols, G{g, 3}, 'one4');
    P = 1000 * sqrt(mean(E(keep, :).^2, 1));
    for c = 1:numel(G{g, 3})
        k = find(strcmp(cn, G{g, 3}{c}));
        hb(k) = plot(ax, g + (k - 2) * 0.24, P(c), 'o', 'MarkerFaceColor', ctrl_colour(ln{k}), ...
            'MarkerEdgeColor', ctrl_colour(ln{k}), 'MarkerSize', 5);
    end
    NT(g, :) = [sum(keep), max(P)];  lo = min(lo, min(P));  hi = max(hi, max(P));
end
if isfinite(lo)
    set(ax, 'YLim', [lo / 1.6, hi * 2.0]);
    tk = [1 2 5 10 20 50 100];  tk = tk(tk >= lo / 1.6 & tk <= hi * 2.0);
    set(ax, 'YTick', tk, 'YTickLabel', arrayfun(@num2str, tk, 'UniformOutput', false), 'YMinorTick', 'off', ...
        'YMinorGrid', 'off');
end
for g = 1:size(G, 1)
    if isfinite(NT(g, 1))
        text(ax, g, NT(g, 2) * 1.3, sprintf('n = %d', NT(g, 1)), 'FontSize', 8, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom');
    end
end
set(ax, 'YScale', 'log', 'XTick', 1:size(G, 1), 'XTickLabel', G(:, 1), 'TickLabelInterpreter', 'tex', ...
    'XLim', [0.5 size(G, 1) + 0.5], 'YGrid', 'on', 'XTickLabelRotation', 0);
ylabel(ax, 'pooled error [mm]');  plab(ax, '(a)');
k = isgraphics(hb);
leg(ax, hb(k), ln(k), 'Location', 'northoutside', 'Orientation', 'horizontal', 'Token', [8 8]);
ax = nexttile(tl);  hold(ax, 'on');  sty(ax);
cl = repmat(ctrl_colour('INDI-DE'), numel(R), 1);  cl([RT{:, 4}] == 2, :) = repmat(ctrl_colour('PAW-MOBADC'), 3, 1);
forest(ax, RT(:, 1), R, cl);
yl = get(ax, 'YLim');
plot(ax, get(ax, 'XLim'), [3.5 3.5], '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5, 'HandleVisibility', 'off');
set(ax, 'YLim', yl);
p = [plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', ctrl_colour('INDI-DE'), 'MarkerEdgeColor', ctrl_colour('INDI-DE')), ...
     plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', ctrl_colour('PAW-MOBADC'), 'MarkerEdgeColor', ctrl_colour('PAW-MOBADC'))];
leg(ax, p, {['INDI-DE / PA-MOBADC ' char(8722) ' 1'], ['PAW-MOBADC / INDI-DE ' char(8722) ' 1']}, ...
    'Location', 'southoutside', 'Box', 'off', 'FontSize', 8, 'Token', [8 8]);
xlabel(ax, 'relative difference [%]');  plab(ax, '(b)');
msg = 'DESCRIPTIVE; dev circle PAW-MOBADC only on S40, INDI-DE only on circle_main';
end

%% =====================================================================
%  8  C3: map of the 12 wind groups
%% =====================================================================
function [fh, msg] = fig8_c3(opt)
G = {'circle, K = 0, weak wind', 'N5-A-Weak';  'circle, K = 0, medium wind', 'N5-A-Medium';
     'circle, K = 0, strong wind', '';  'circle, K = 0.5, weak wind', 'N5-B-Weak';
     'circle, K = 0.5, medium wind', 'N5-B-Medium';  'circle, main set', 'N4b-P2-base';
     'circle, wind-sensor delay 200 ms', 'N4b-P2-d200';  'circle, L = 1.5 m', 'N4b-P2-L15';
     'circle, K = 1.0', 'N4b-P2-K10';  'hover, wind-to-payload term', 'N6';
     'circle, strong relative wind (post hoc)', 'N5-A-StrongRel';
     'hover, strong relative wind (post hoc)', 'N5-H-StrongRel'};
hh = @(p) 1 - p(2) / p(1);
n = size(G, 1);  R = cell(n, 1);  V = repmat({''}, n, 1);
for i = 1:n
    if isempty(G{i, 2}), V{i} = 'empty (outside the envelope)'; continue; end
    c = {'L3', 'O'};  if strcmp(G{i, 2}, 'N6'), c = {'L3_6', 'O_6'}; end
    R{i} = rstat(opt, ['gd7/' G{i, 2} '.mat'], c, hh, 'one4');
    r = R{i};
    if isempty(r), V{i} = 'no data'; continue; end
    if r.n < 15 || r.nd < 6
        V{i} = sprintf('%d seg., %d days: not evaluable', r.n, r.nd);
    else
        hr = r.val >= 0.10 && all(sign(r.loo) == sign(r.val)) && r.med >= 0.05;
        V{i} = sprintf('%d seg., %d days: %s', r.n, r.nd, tern(hr, 'headroom', 'no headroom'));
    end
end
fh = newfig('double', 8.6);
ax = axes('Parent', fh, 'Units', 'normalized', 'Position', [0.30 0.13 0.42 0.83]);  hold(ax, 'on');  sty(ax);
forest(ax, G(:, 1), R, repmat([0.30 0.30 0.30], n, 1));
yl = get(ax, 'YLim');
plot(ax, [10 10], yl, '--', 'Color', ctrl_colour('PAW-MOBADC'), 'LineWidth', 0.75, 'HandleVisibility', 'off');
text(ax, 10, yl(2), ' threshold', 'FontSize', 8, 'Color', ctrl_colour('PAW-MOBADC'), 'VerticalAlignment', 'top');
xl = get(ax, 'XLim');
for i = 1:n
    text(ax, xl(2) + 0.04 * diff(xl), n - i + 1, V{i}, 'FontSize', 8, 'Clipping', 'off');
end
xlabel(ax, ['h = 1 ' char(8722) ' oracle / PA-MOBADC [%]']);
msg = 'C3 map; rule sec 0.6 (h >= 10 %, LOO sign, by-day median >= 5 %; n >= 15, days >= 6)';
end

%% =====================================================================
%  helpers: statistics
%% =====================================================================
function r = rstat(opt, f, cols, fun, sub)
%RSTAT  p2r_stat on one file's subset, or [] if the file / column is missing or fewer than 2 segments.
r = [];
[Z, c, ok] = p2r_load(opt.Root, f);
if ~ok || ~all(ismember(cols, c)), return; end
[E, day, ~, keep] = p2r_subset(Z, c, cols, sub);
if sum(keep) < 2, return; end
r = p2r_stat(fun, E(keep, :), day(keep));
end

%% =====================================================================
%  helpers: drawing (one style for every figure)
%% =====================================================================
function c = ctrl_colour(name)
%CTRL_COLOUR  One colour per controller in every figure (Okabe-Ito palette, readable in grey and by colour-blind
%  readers): the proposed method vermillion, its delay-compensated predecessor orange, the measured-wind baseline
%  blue, the published baseline black, the acceleration-based comparison green.
name = regexprep(name, ' \(proposed\)$', '');
switch name
    case {'PID', 'PID + trim'},     c = [0.70 0.70 0.70];
    case {'DO', 'DO + trim'},       c = [0.80 0.47 0.65];
    case 'ESO',                     c = [0.40 0.40 0.40];
    case 'MOBADC',                  c = [0.00 0.00 0.00];
    case 'MOBADC-DC',               c = [0.30 0.30 0.30];
    case 'MOBADC-W',                c = [0.00 0.45 0.70];
    case 'MOBADC-W + preview',      c = [0.34 0.71 0.91];
    case 'PA-MOBADC',               c = [0.90 0.62 0.00];
    case 'PAW-MOBADC',              c = [0.84 0.37 0.00];
    case 'INDI-DE',                 c = [0.00 0.62 0.45];
    otherwise,                      c = [0.45 0.45 0.45];
end
end

function lg = leg(ax, h, labels, varargin)
%LEG  Legend of the paper: no box, 8 pt; 'Token', [w h] sets the length of the line samples.
tok = [];
k = find(strcmp(varargin, 'Token'), 1);
if ~isempty(k), tok = varargin{k + 1};  varargin(k:k + 1) = []; end
lg = legend(ax, h, labels, 'Box', 'off', 'FontSize', 8, varargin{:});
if ~isempty(tok), try, lg.ItemTokenSize = tok; catch, end, end
end

function fh = newfig(w, hcm)
fh = figure('Visible', 'off', 'Color', 'w');
paper_size(fh, w, hcm);
end

function sty(ax)
%STY  The axes style of the paper: 8 pt, thin axes, ticks outside, no box.
set(ax, 'FontSize', 8, 'LineWidth', 0.5, 'TickDir', 'out', 'TickLength', [0.012 0.012], 'Box', 'off', ...
    'XColor', [0.15 0.15 0.15], 'YColor', [0.15 0.15 0.15], 'Layer', 'top', 'LabelFontSizeMultiplier', 1, ...
    'TitleFontSizeMultiplier', 1, 'TitleFontWeight', 'bold', 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1);
try, set(ax, 'TitleHorizontalAlignment', 'left'); catch, end
end

function plab(ax, s)
%PLAB  Panel label "(a) a few words", left-aligned above the panel (the figure itself carries no title).
title(ax, s, 'FontSize', 8, 'FontWeight', 'bold');
end

function s = num(v, fmt)
%NUM  A number with a typographic minus sign.
s = strrep(sprintf(fmt, v), '-', char(8722));
end

function forest(ax, labels, R, cl)
%FOREST  value (percent) +-1.65 SE per row, top to bottom; a missing row is labelled.
n = numel(labels);
for i = 1:n
    y = n - i + 1;  r = R{i};
    if isempty(r)
        text(ax, 0, y, '  no data', 'FontSize', 8, 'Color', [0.5 0.5 0.5], 'VerticalAlignment', 'middle');
        continue
    end
    v = 100 * r.val;  e = 165 * r.se;
    if isfinite(e), plot(ax, [v - e, v + e], [y y], '-', 'Color', cl(i, :), 'LineWidth', 1.0); end
    plot(ax, v, y, 'o', 'MarkerFaceColor', cl(i, :), 'MarkerEdgeColor', cl(i, :), 'MarkerSize', 4);
    text(ax, v, y + 0.18, num(v, '%+.1f'), 'FontSize', 8, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom');
end
set(ax, 'YTick', 1:n, 'YTickLabel', labels(end:-1:1), 'YLim', [0.4 n + 0.75], 'XGrid', 'on', ...
    'TickLabelInterpreter', 'tex');
xl = get(ax, 'XLim');  xl = [min(xl(1), -5), max(xl(2), 5)];
plot(ax, [0 0], [0.4 n + 0.75], '-', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.5, 'HandleVisibility', 'off');
set(ax, 'XLim', xl);
end

function h = vpoint(ax, x, r, col, mk, side)
if nargin < 6, side = 'right'; end
h = [];
if isempty(r), return; end
v = 100 * r.val;  e = 165 * r.se;
if isfinite(e), plot(ax, [x x], [v - e, v + e], '-', 'Color', col, 'LineWidth', 1.0); end
h = plot(ax, x, v, mk, 'MarkerFaceColor', col, 'MarkerEdgeColor', col, 'MarkerSize', 4.5);
if strcmp(side, 'left')
    text(ax, x - 0.07, v, num(v, '%.1f'), 'FontSize', 8, 'HorizontalAlignment', 'right');
else
    text(ax, x + 0.07, v, num(v, '%.1f'), 'FontSize', 8, 'HorizontalAlignment', 'left');
end
end

function vbar(ax, x, y, w, fc, ec)
%VBAR  One bar from 0 (bar() with a scalar x ignores the width in Octave).
if ~(y > 0), return; end
rectangle('Parent', ax, 'Position', [x - w / 2, 0, w, y], 'FaceColor', fc, 'EdgeColor', ec, 'LineWidth', 0.5);
end

function save_p2(fh, opt, stem)
paper_style(fh, 'Sans', true);
if ~opt.Save
    fprintf('    [view only] %s not written\n', stem);
    return
end
f = fullfile(opt.Out, stem);
write_labels(fh, [f '.labels.txt']);                    % every displayed string (tools/check_names.py)
if exist('exportgraphics') > 0 %#ok<EXIST>
    exportgraphics(fh, [f '.pdf'], 'ContentType', 'vector');
    exportgraphics(fh, [f '.png'], 'Resolution', 300);
else
    print(fh, [f '.pdf'], '-dpdf');
    print(fh, [f '.png'], '-dpng', '-r300');
end
fprintf('    wrote %s.pdf / .png\n', f);
end

function write_labels(fh, fn)
%WRITE_LABELS  Every string the figure shows - text, titles, axis labels, legends, annotations, tick labels - one per
%  line, so that tools/check_names.py checks what is drawn (REGISTER_P2 sec 63.1), not the source code.
S = {};
h = findall(fh, '-property', 'String');
for k = 1:numel(h)
    try, v = get(h(k), 'String'); catch, continue; end
    S = [S; cellstr(v(:))]; %#ok<AGROW>
end
ax = findall(fh, 'Type', 'axes');
for k = 1:numel(ax)
    for pr = {'XTickLabel', 'YTickLabel', 'Title', 'XLabel', 'YLabel'}
        try
            v = get(ax(k), pr{1});
            if ~iscell(v) && ~ischar(v), v = get(v, 'String'); end   % Title / XLabel / YLabel are objects
            S = [S; cellstr(v)]; %#ok<AGROW>
        catch
        end
    end
end
tl = findall(fh, 'Type', 'tiledlayout');
for k = 1:numel(tl)
    for pr = {'XLabel', 'YLabel', 'Title'}
        try, S = [S; cellstr(get(get(tl(k), pr{1}), 'String'))]; catch, end %#ok<AGROW>
    end
end
fid = fopen(fn, 'w', 'n', 'UTF-8');
if fid < 0, return; end
fprintf(fid, '%s\n', S{:});
fclose(fid);
end

function txt(ax, x, y, s, varargin)
text(ax, x, y, s, 'FontSize', 8, 'VerticalAlignment', 'middle', 'Interpreter', 'tex', varargin{:});
end

function blk(ax, x, y, w, h, lines, fc, ec, ls)
%BLK  A block of the diagram: rounded box, centred lines of text (3.4 mm apart).
if nargin < 9, ls = '-'; end
rectangle('Parent', ax, 'Position', [x y w h], 'Curvature', [min(1, 2.4 / w), min(1, 2.4 / h)], ...
    'FaceColor', fc, 'EdgeColor', ec, 'LineWidth', 0.75, 'LineStyle', ls);
n = numel(lines);
for i = 1:n
    text(ax, x + w / 2, y + h / 2 + ((n + 1) / 2 - i) * 3.4, lines{i}, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontSize', 8, 'Interpreter', 'tex');
end
end

function arr(ax, x1, y1, x2, y2, col, lw, ls)
%ARR  Arrow from (x1, y1) to (x2, y2), any direction; filled head 1.8 mm long.
if nargin < 7, lw = 0.75; end
if nargin < 8, ls = '-'; end
d = [x2 - x1, y2 - y1];  L = norm(d);
if L == 0, return; end
u = d / L;  nv = [-u(2) u(1)];  hl = min(1.8, 0.6 * L);  hw = 0.65;
b = [x2 y2] - hl * u;
plot(ax, [x1 b(1)], [y1 b(2)], ls, 'Color', col, 'LineWidth', lw);
patch(ax, [x2, b(1) + hw * nv(1), b(1) - hw * nv(1)], [y2, b(2) + hw * nv(2), b(2) - hw * nv(2)], col, ...
    'EdgeColor', col, 'LineWidth', 0.3);
end

function polyarr(ax, xs, ys, col)
%POLYARR  A polyline whose last segment ends in an arrow head.
plot(ax, xs(1:end - 1), ys(1:end - 1), '-', 'Color', col, 'LineWidth', 0.75);
arr(ax, xs(end - 1), ys(end - 1), xs(end), ys(end), col);
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
