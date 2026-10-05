function S = make_p2_figures(varargin)
%MAKE_P2_FIGURES  GD11 figures 1-8 of plant P2 (REGISTER_P2 sec 62.1) -> paper/figures/p2_fig<k>_<name>.pdf / .png
%
%   make_p2_figures                          % all eight
%   make_p2_figures('Only', [1 2 4 5 6 7 8]) % saved results and wind files only (no Simulink)
%   make_p2_figures('Only', 3)               % Figure 3: re-simulates ONE CONFIRM2 segment (Simulink + wind_conf2/)
%   make_p2_figures('Only', 9)               % Figure 9: re-simulates ONE dev circle_main segment, six controllers
%   HOANG_NOSAVE = true; make_p2_figures     % draw, write nothing (figures/nosave_on.m)
%
%  Every panel names its set and role (as docs/RESULTS_P2.md). Error bars: +-1.65 SE, paired day jackknife
%  (analysis/p2r_stat.m); subsets as analysis/p2r_subset.m ('one4' = the one set of the file, 'unsatL3' = A of
%  sec 60.3). Main configuration L 1.0 m, m_p 0.5 kg. Nothing is simulated except Figure 3, which follows the rule
%  fixed in sec 62.1 (3) and is saved only if every re-run column's mean error equals the stored CONFIRM2 row to
%  1e-12. A figure whose data are missing is not drawn; the summary says why.
opt = struct('Only', 1:9, 'Root', fullfile(repo_root(), 'results'), ...
    'Out', fullfile(repo_root(), 'paper', 'figures'), 'Conf2Dir', 'wind_conf2', ...
    'ExplManifest', 'wind_expl_t150_batch.json', 'Save', ~nosave_on(), 'Close', true);
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
%  1  system and block diagram (schematic, no data)
%% =====================================================================
function [fh, msg] = fig1_system(~)
P = p2_params();
fh = newfig(11.5);
ax = axes('Parent', fh, 'Position', [0.005 0.005 0.99 0.99]);  hold(ax, 'on');
axis(ax, [0 100 0 64]);  axis(ax, 'off');
K = [0.25 0.25 0.25];  FS = 6;  FK = 5.4;
PL = [0.93 0.93 0.93];  OB = [0.87 0.90 0.95];  OP = [0.97 0.91 0.88];
% ---- (a) the plant ----
text(1, 62, '(a) plant P2 (side view)', 'Parent', ax, 'FontSize', FS + 1, 'FontWeight', 'bold');
c = [16 50];                                              % body centre
rectangle('Parent', ax, 'Position', [c(1) - 4, c(2) - 0.8, 8, 1.6], 'FaceColor', [0.6 0.6 0.6], 'EdgeColor', K);
plot(ax, [c(1) - 11, c(1) + 11], [c(2) c(2)], '-', 'Color', K, 'LineWidth', 1.2);
for xr = c(1) + [-10 10]
    plot(ax, [xr xr], [c(2), c(2) + 1.3], '-', 'Color', K);
    t = linspace(0, 2 * pi, 40);
    plot(ax, xr + 4 * cos(t), c(2) + 1.5 + 0.45 * sin(t), '-', 'Color', K);
end
th = 18 * pi / 180;  Lc = 16;  p0 = [c(1), c(2) - 0.8];
pe = p0 + Lc * [sin(th), -cos(th)];
plot(ax, [p0(1) pe(1)], [p0(2) pe(2)], '-', 'Color', K, 'LineWidth', 0.8);
plot(ax, [p0(1) p0(1)], [p0(2), pe(2) - 2], ':', 'Color', K);
t = linspace(0, th, 20);
plot(ax, p0(1) + 6 * sin(t), p0(2) - 6 * cos(t), '-', 'Color', K);
text(p0(1) + 0.6, p0(2) - 7.6, '\theta', 'Parent', ax, 'FontSize', FS);
t = linspace(0, 2 * pi, 50);
patch('Parent', ax, 'XData', pe(1) + 2.2 * cos(t), 'YData', pe(2) + 2.2 * sin(t), 'FaceColor', [0.75 0.75 0.75], ...
    'EdgeColor', K);
text(c(1) - 9, c(2) + 4.2, sprintf('quadrotor  m_Q = %g kg', P.m_Q), 'Parent', ax, 'FontSize', FK);
text(pe(1) - 3.2, (p0(2) + pe(2)) / 2 + 1, sprintf('cable L = %g m', P.L), 'Parent', ax, 'FontSize', FK, ...
    'HorizontalAlignment', 'left');
text(pe(1) - 7, pe(2) - 4, sprintf('payload  m_p = %g kg', P.m_L), 'Parent', ax, 'FontSize', FK);
for y = [c(2) - 2, c(2) + 1, pe(2) - 1, pe(2) + 2]
    arrow(ax, 0.6, y, 3.6, y, [0.2 0.4 0.7]);
end
text(0.6, c(2) - 4.2, 'wind', 'Parent', ax, 'FontSize', FK, 'Color', [0.2 0.4 0.7]);
L = {'wind: measured NREL M5 series (20 Hz), acting on airframe and payload';
     'quadratic drag on the velocity relative to the air:';
     sprintf('   F = K_w |v| v / U_{ref},  K_w = %g N s/m,  U_{ref} = %g m/s', P.K_w, P.U_ref);
     sprintf('payload drag area (C_DA)_L = K (C_DA)_Q, K = %g', P.K);
     sprintf('wind sensor %g Hz, delay %g ms; motors: first-order lag %g ms', P.fs_wind, 1000 * P.delay_wind, 1000 * P.tau_m);
     sprintf('limits: f_i \\leq %.4g N per rotor, total \\leq %.4g N, tilt \\leq 30\\circ', P.f_max, P.F_TOT_MAX)};
for i = 1:numel(L), text(1, 19 - 3.0 * (i - 1), L{i}, 'Parent', ax, 'FontSize', FK - 0.4); end
% ---- (b) the controller and the compared estimates ----
text(37, 62, '(b) controller and the compared estimates', 'Parent', ax, 'FontSize', FS + 1, 'FontWeight', 'bold');
bx(ax, 37, 47, 10, 8, {'reference', 'circle / hover', 'V: + preview \tau_{prev}'}, [1 1 1], FK);
bx(ax, 49, 47, 15, 8, {'Guo law (9)', 'a_d = K_\gamma e_\gamma + K_\nu e_\nu', '+ g e_3 + a_{ref}'}, [1 1 1], FK);
sumnode(ax, 67, 51, FS);
bx(ax, 70, 47, 11, 8, {'thrust / tilt', 'limits', '(clamp)'}, [0.90 0.88 0.84], FK);
bx(ax, 83, 47, 16, 8, {'attitude loop', '+ motors (lag)'}, [1 1 1], FK);
bx(ax, 83, 31, 16, 9, {'P2: quadrotor', '+ slung payload', '(pendulum, drag)'}, PL, FK);
bx(ax, 83, 18, 16, 7, {'wind w(t)', 'NREL M5, 20 Hz'}, PL, FK);
bx(ax, 64, 18, 16, 7, {'wind sensor', '20 Hz, 50 ms delay'}, OB, FK);
arrow(ax, 47, 51, 49, 51, K);  arrow(ax, 64, 51, 65.2, 51, K);  arrow(ax, 68.8, 51, 70, 51, K);
arrow(ax, 81, 51, 83, 51, K);  arrow(ax, 91, 47, 91, 40, K);   arrow(ax, 91, 25, 91, 31, K);
arrow(ax, 83, 21.5, 80, 21.5, K);
text(68.2, 53.6, 'F', 'Parent', ax, 'FontSize', FK);
text(64.6, 55.4, 'm a_d', 'Parent', ax, 'FontSize', FK);
% measured state back to the law (dashed)
plot(ax, [99 99.6 99.6 56.5 56.5], [35.5 35.5 57.5 57.5 55], '--', 'Color', K, 'LineWidth', 0.5);
arrow(ax, 56.5, 56, 56.5, 55, K);
text(70, 58.8, 'measured state (position, velocity, attitude, rates; accelerometer for INDI-DE)', 'Parent', ax, ...
    'FontSize', FK - 0.4);
% estimates
bx(ax, 37, 29, 22, 11, {'payload estimate  d_{mf}', 'disturbance observer (DO)', ...
    'PA-MOBADC: predicted \tau ahead, B e^{A\tau}\xi', '\tau = 290 ms circle, 0 hover'}, OB, FK);
bx(ax, 61, 29, 20, 11, {'wind estimate  d_{lf}', 'MOBADC: position ESO', ...
    '-W variants: sensor, K_w|w|w/U_{ref}', 'PAW-MOBADC: \times (1 + K-hat) = 1.5'}, OB, FK);
plot(ax, [48 48 66.4], [40 43.5 43.5], '-', 'Color', K);  arrow(ax, 66.4, 43.5, 66.4, 49.2, K);
plot(ax, [71 71 67.6], [40 42 42], '-', 'Color', K);      arrow(ax, 67.6, 42, 67.6, 49.2, K);
text(56, 45, '- d_{mf}', 'Parent', ax, 'FontSize', FK);   text(72, 43.4, '- d_{lf}', 'Parent', ax, 'FontSize', FK);
arrow(ax, 72, 25, 72, 29, K);
bx(ax, 37, 11, 26, 9, {'INDI-DE (INDI-type estimate), compared', 'd_{mf} = H(z)[m a_{meas} - F_{thr} + m g e_3]', ...
    '\omega_f = 32 Hz;  d_{lf} = 0'}, OP, FK);
plot(ax, [48 48], [20 29], '--', 'Color', K);  arrow(ax, 48, 28, 48, 29, K);
text(48.6, 24.5, 'replaces (INDI-DE)', 'Parent', ax, 'FontSize', FK - 0.4);
KEY = {'controllers (circle; hover uses its exact-frequency DO table):', ...
       'MOBADC: wind ESO, DO harmonics \{1\}    MOBADC-W: wind sensor, DO \{0, 1\}    + preview: \tau_{prev} = 180 ms', ...
       'PA-MOBADC: MOBADC-W + payload estimate predicted \tau ahead (C1)', ...
       'PAW-MOBADC (proposed): PA-MOBADC + static (1 + K-hat) payload-wind feed-forward (C2)    INDI-DE: wind channel 0'};
for i = 1:numel(KEY), text(37, 7.6 - 2.3 * (i - 1), KEY{i}, 'Parent', ax, 'FontSize', FK - 0.4); end
msg = 'schematic, no data (labels from core/p2_params.m)';
end

%% =====================================================================
%  2  wind data: U and TI, dev pool vs CONFIRM2
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
ENV = [8.02 10.86 13.30];  ENVL = {'circle K 0.5', 'hover K 0.5', 'hover K 0'};   % sec 62.1 (2), A2 envelopes
fprintf('    dev pool %d segments / %d days, CONFIRM2 %d segments / %d days\n', numel(Ud), numel(unique(dd)), ...
    numel(Uc), numel(unique(dc)));
CD = [0.35 0.35 0.35];  CC = [0.85 0.33 0.10];
fh = newfig(6.8);
ld = sprintf('dev pool (%d seg., %d days)', numel(Ud), numel(unique(dd)));
lc = sprintf('CONFIRM2 (%d seg., %d days)', numel(Uc), numel(unique(dc)));
ax = subplot(1, 3, 1, 'Parent', fh);  hold(ax, 'on');
e = 0:0.5:ceil(max([Ud; Uc]) + 0.5);
h1 = fracstairs(ax, Ud, e, CD);  h2 = fracstairs(ax, Uc, e, CC);
xlabel(ax, 'U [m/s] (mean horizontal wind, t \geq 140 s)');  ylabel(ax, 'fraction of segments');
title(ax, '(a) mean wind U');
envlines(ax, ENV, ENVL);
ax = subplot(1, 3, 2, 'Parent', fh);  hold(ax, 'on');
e = 0:0.025:max(0.6, ceil(40 * max([Td; Tc])) / 40);
fracstairs(ax, Td, e, CD);  fracstairs(ax, Tc, e, CC);
xlabel(ax, 'TI = \sigma_u / U');  ylabel(ax, 'fraction of segments');
title(ax, '(b) turbulence intensity');
ax = subplot(1, 3, 3, 'Parent', fh);  hold(ax, 'on');
plot(ax, Ud, Td, '.', 'Color', CD, 'MarkerSize', 5);
plot(ax, Uc, Tc, 'o', 'Color', CC, 'MarkerSize', 2.5);
xlabel(ax, 'U [m/s]');  ylabel(ax, 'TI');  title(ax, '(c) TI vs U, per segment');
envlines(ax, ENV, {});
legend(ax, [h1 h2], {ld, lc}, 'Location', 'best', 'FontSize', 5);
style_axes(fh);
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

function h = fracstairs(ax, x, e, col)
n = histc(x(:), e);  n = n(:).' / numel(x);
h = stairs(ax, e, n, '-', 'Color', col, 'LineWidth', 1);
end

function envlines(ax, ENV, ENVL)
yl = get(ax, 'YLim');
for k = 1:numel(ENV)
    plot(ax, ENV(k) * [1 1], yl, ':', 'Color', [0.2 0.4 0.7], 'LineWidth', 0.8, 'HandleVisibility', 'off');
    if ~isempty(ENVL)
        text(ENV(k), yl(2) * (0.97 - 0.08 * (k - 1)), sprintf(' %s %.2f', ENVL{k}, ENV(k)), 'Parent', ax, ...
            'FontSize', 4.6, 'Color', [0.2 0.4 0.7]);
    end
end
set(ax, 'YLim', yl);
end

%% =====================================================================
%  3  illustrative time series (registered segment rule; re-simulated, agreement check)
%% =====================================================================
function [fh, msg] = fig3_series(opt)
fh = [];
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
Zs = load(fullfile(opt.Root, 'gd10', 'sets.mat'), 'Sets');
s = Zs.Sets.circle;
files = s.files(:);  U = s.U(:);  n = numel(files);
[~, o1] = sort(files);                                   % ties: file name
[~, o2] = sort(U(o1));                                   % stable sort by U
idx = o1(o2);
k = ceil(n / 2);                                         % lower median (28th of 56)
fn = files{idx(k)};
fprintf('    CONFIRM2 circle set: %d segments; lower median U = %.4f m/s (rank %d): %s\n', n, U(idx(k)), k, fn);
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
nm = p2_names({'L2', 'L3', 'L3_iii0', 'H3'});
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
fh = newfig(8.5);
col = colcols();
ax1 = subplot(2, 1, 1, 'Parent', fh);  hold(ax1, 'on');
ax2 = subplot(2, 1, 2, 'Parent', fh);  hold(ax2, 'on');
h = zeros(1, 4);
for c = 1:4
    m = M{c};
    ms = m.t >= 140;
    e = sqrt(sum((m.gd(ms, :) - m.g(ms, :)).^2, 2));
    h(c) = plot(ax1, m.t(ms), e, '-', 'Color', col(c, :), 'LineWidth', 0.6);
    L = m.log.p2_mon_log;  mt = L.t(:) >= 140;
    plot(ax2, L.t(mt), L.v(mt, 5) * 180 / pi, '-', 'Color', col(c, :), 'LineWidth', 0.6);
end
ylabel(ax1, '||e_\gamma|| [m]');  ylabel(ax2, '\theta [deg]');  xlabel(ax2, 't [s]');
title(ax1, sprintf(['(a) position error - CONFIRM2 circle, lower-median-U segment %s (U = %.2f m/s); ' ...
    'illustration only'], strrep(fn, '_', '\_'), U(idx(k))));
title(ax2, '(b) payload swing angle');
legend(ax1, h, arrayfun(@(c) sprintf('%s  mean %.4f m', nm{c}, re(c)), 1:4, 'UniformOutput', false), ...
    'Location', 'northeast', 'FontSize', 5);
style_axes(fh);
msg = sprintf('%s; re-run = stored to %.1g (max |d|)', fn, max(d));
end

%% =====================================================================
%  9  six controllers on one dev circle_main segment, x-y (REGISTER_P2 sec 63.5; as Guo 2020 Fig. 10)
%% =====================================================================
function [fh, msg] = fig9_traj(opt)
fh = [];
[st, out] = system(sprintf('git -C "%s" status --porcelain -- baseline1.slx core experiments', repo_root()));
if st ~= 0 || ~isempty(strtrim(out))
    msg = sprintf('git status failed or local change in baseline1.slx / core / experiments - not run:%s%s', newline, out);
    return
end
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
    'mean', re); %#ok<NASGU>
od = fullfile(opt.Root, 'gd11');  if exist(od, 'dir') ~= 7, mkdir(od); end
save(fullfile(od, ['traj_' strrep(fn, '.mat', '') '.mat']), 'T');
fh = newfig(12.0);
lim = 0;                                                 % one scale for the six panels
for c = 1:6
    ms = M{c}.t >= 140;
    lim = max([lim; abs(reshape(M{c}.g(ms, 1:2), [], 1)); abs(reshape(M{c}.gd(ms, 1:2), [], 1))]);
end
lim = 1.05 * lim;
for c = 1:6
    ax = subplot(2, 3, c, 'Parent', fh);  hold(ax, 'on');
    ms = M{c}.t >= 140;
    plot(ax, M{c}.gd(ms, 1), M{c}.gd(ms, 2), '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
    plot(ax, M{c}.g(ms, 1), M{c}.g(ms, 2), '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 0.6);
    axis(ax, 'equal');  axis(ax, [-lim lim -lim lim]);
    title(ax, sprintf('%s: mean %.4f m', nm{c}, re(c)), 'FontSize', 6);
    xlabel(ax, 'x [m]');  if mod(c, 3) == 1, ylabel(ax, 'y [m]'); end
end
annotation(fh, 'textbox', [0.05 0.0 0.9 0.04], 'String', sprintf(['dev circle\\_main segment %s (rule REGISTER\\_P2 ' ...
    'sec 63.5), t >= 140 s; dashed: desired circle (R 0.8 m), solid: flown. L 1.0 m, m_p 0.5 kg, K 0.5. Illustration ' ...
    'only.'], strrep(fn, '_', '\_')), 'EdgeColor', 'none', 'FontSize', 5);
style_axes(fh);
msg = sprintf('%s; re-run = stored to %.1g (max |d|); time series in results/gd11/', fn, max(d));
end

%% =====================================================================
%  4  C1: L3/L2 - 1 and V/L2 - 1 per trajectory; scatter L3 vs L2
%% =====================================================================
function [fh, msg] = fig4_c1(opt)
fh = [];
rel = @(p) p(1) / p(2) - 1;
G = {'circle_main dev', 'gd6/d2_p2.mat', 'CLAIM-dev';
     'circle CONFIRM2', 'gd10/D2.mat', 'CLAIM';
     'T3b_main dev', 'gd6/tab_T3b_p2.mat', 'DESCR.';
     'square_main dev', 'gd6/tab_square_p2.mat', 'DESCR.'};
ng = size(G, 1);
R3 = cell(ng, 1);  RV = R3;
for i = 1:ng
    R3{i} = rstat(opt, G{i, 2}, {'L3', 'L2'}, rel, 'one4');
    RV{i} = rstat(opt, G{i, 2}, {'V', 'L2'}, rel, 'one4');
end
if all(cellfun(@isempty, R3)), msg = 'no D2 / TAB file found'; return; end
fh = newfig(8.0);
col = colcols();
ax = subplot(1, 2, 1, 'Parent', fh);  hold(ax, 'on');
h = zeros(1, 2);
for i = 1:ng
    a = vpoint(ax, i - 0.13, R3{i}, col(2, :), 'o');  if a ~= 0, h(1) = a; end
    a = vpoint(ax, i + 0.13, RV{i}, [0.45 0.45 0.45], 's');  if a ~= 0, h(2) = a; end
end
yl = get(ax, 'YLim');  yl = [yl(1) - 0.08 * diff(yl), max(yl(2), 0) + 0.12 * diff(yl)];
set(ax, 'YLim', yl);
for i = 1:ng
    if ~isempty(R3{i})
        text(i, yl(2) - 0.05 * diff(yl), sprintf('n %d (%d d)', R3{i}.n, R3{i}.nd), 'Parent', ax, ...
            'FontSize', 4.6, 'HorizontalAlignment', 'center');
    end
end
plot(ax, [0.5 ng + 0.5], [0 0], ':', 'Color', [0.4 0.4 0.4]);
set(ax, 'XLim', [0.5 ng + 0.5], 'XTick', 1:ng, 'XTickLabel', ...
    cellfun(@(a, b) sprintf('%s [%s]', strrep(a, '_', '\_'), b), G(:, 1), G(:, 3), 'UniformOutput', false));
try, set(ax, 'XTickLabelRotation', 15); catch, end
ylabel(ax, 'relative change of the pooled error [%]  (\pm1.65 SE)');
title(ax, '(a) prediction (PA-MOBADC / MOBADC-W - 1) and preview (MOBADC-W + preview / MOBADC-W - 1)');
hl = h(h ~= 0);
if numel(hl) == 2, legend(ax, hl, {'PA-MOBADC / MOBADC-W - 1', '(MOBADC-W + preview) / MOBADC-W - 1'}, 'Location', 'southeast', 'FontSize', 5); end
ax = subplot(1, 2, 2, 'Parent', fh);  hold(ax, 'on');
SC = {'gd6/d2_p2.mat', [0.35 0.35 0.35], '.', 'dev circle\_main';  'gd10/D2.mat', [0.85 0.33 0.10], 'o', 'CONFIRM2 circle'};
hh = [];  ll = {};  lo = Inf;  hi = 0;
for i = 1:2
    [Z, cols, ok] = p2r_load(opt.Root, SC{i, 1});
    if ~ok, continue; end
    [E, ~, ~, keep] = p2r_subset(Z, cols, {'L2', 'L3'}, 'one4');
    E = E(keep, :);
    hh(end + 1) = plot(ax, E(:, 1), E(:, 2), SC{i, 3}, 'Color', SC{i, 2}, 'MarkerSize', 3 + 2 * (i == 1)); %#ok<AGROW>
    ll{end + 1} = sprintf('%s (%d)', SC{i, 4}, size(E, 1)); %#ok<AGROW>
    lo = min(lo, min(E(:)));  hi = max(hi, max(E(:)));
end
if isfinite(lo)
    lim = [lo / 1.3, hi * 1.3];
    plot(ax, lim, lim, '-', 'Color', [0.5 0.5 0.5]);
    set(ax, 'XScale', 'log', 'YScale', 'log', 'XLim', lim, 'YLim', lim);
    legend(ax, hh, ll, 'Location', 'southeast', 'FontSize', 5);
end
xlabel(ax, 'MOBADC-W mean error per segment [m]');  ylabel(ax, 'PA-MOBADC mean error per segment [m]');
title(ax, '(b) per segment, one set (identity line)');
style_axes(fh);
msg = 'C1; sets and roles on the axis';
end

%% =====================================================================
%  5  horizon tau: pooled error vs payload-prediction horizon (N0P)
%% =====================================================================
function [fh, msg] = fig5_tau(opt)
fh = [];
f = fullfile(opt.Root, 'gd6', 'n0p_p2.mat');
if exist(f, 'file') ~= 2, msg = 'results/gd6/n0p_p2.mat not found'; return; end
Z = load(f, 'T');
T = Z.T(strcmp({Z.T.mode}, 'N0P'));
if isempty(T), msg = 'no N0P row in n0p_p2.mat'; return; end
n = numel(T);  nc = min(4, n);  nr = ceil(n / nc);
fh = newfig(4.2 * nr + 1.2);
for j = 1:n
    ax = subplot(nr, nc, j, 'Parent', fh);  hold(ax, 'on');
    t = T(j);
    plot(ax, 1000 * t.coarse.tau, t.coarse.R, '-o', 'Color', [0.35 0.35 0.35], 'MarkerSize', 2.5);
    if isstruct(t.fine) && ~isempty(t.fine)
        plot(ax, 1000 * t.fine.tau, t.fine.R, 's', 'Color', [0.85 0.33 0.10], 'MarkerSize', 3);
        k = find(abs(t.fine.tau - t.tau_star) < 1e-9, 1);
        if ~isempty(k)
            plot(ax, 1000 * t.tau_star, t.fine.R(k), 'p', 'MarkerFaceColor', [0.85 0.33 0.10], ...
                'Color', [0.85 0.33 0.10], 'MarkerSize', 7);
        end
    end
    title(ax, sprintf('%s (%s, L %.1f): \\tau* = %.0f ms%s', strrep(t.label, '_', '\_'), t.cond, t.L, ...
        1000 * t.tau_star, tern(t.edge_ok, '', ' [EDGE]')), 'FontSize', 6);
    xlabel(ax, '\tau [ms]');
    if mod(j - 1, nc) == 0, ylabel(ax, 'pooled mean error [m]'); end
end
annotation(fh, 'textbox', [0.05 0.0 0.9 0.04], 'String', sprintf(['N0P: PA-MOBADC, pooled over the dev A4 ' ...
    'fixed-5 segments (%d) at each tau; circles coarse grid, squares fine grid, star tau*. DESCRIPTIVE (tuning).'], ...
    numel(T(1).files)), 'EdgeColor', 'none', 'FontSize', 5);
style_axes(fh);
msg = sprintf('%d N0P condition(s); set: dev A4 fixed-5 (%d segments); tuning, DESCRIPTIVE', n, numel(T(1).files));
end

%% =====================================================================
%  6  C2: forest of h + control effort and payload swing
%% =====================================================================
function [fh, msg] = fig6_c2(opt)
fh = [];
hh = @(p) 1 - p(2) / p(1);
FR = {'hover', 'dev N6\_hover, A (PA-MOBADC unsat.)', 'gd7/static-hover.mat', {'L3', 'L3_iii0'}, 'unsatL3', 'POST-HOC';
      'hover', 'dev N6\_hover, full one set', 'gd7/static-hover.mat', {'L3', 'L3_iii0'}, 'one4', 'POST-HOC';
      'hover', 'dev S40hover, K-hat nominal', 'gd7/static-hover-k.mat', {'L3', 'L3_iii0'}, 'one4', 'POST-HOC';
      'hover', 'dev S40hover, K-hat \times 0.7', 'gd7/static-hover-k.mat', {'L3', 'L3_iii0_k070'}, 'one4', 'POST-HOC';
      'hover', 'dev S40hover, K-hat \times 1.3', 'gd7/static-hover-k.mat', {'L3', 'L3_iii0_k130'}, 'one4', 'POST-HOC';
      'hover', 'CONFIRM2 hover, A', 'gd10/C2-hover.mat', {'L3', 'L3_iii0'}, 'unsatL3', 'CLAIM';
      'circle', 'dev S40, one set', 'gd7/static-circle.mat', {'L3', 'L3_iii0'}, 'one4', 'POST-HOC';
      'circle', 'CONFIRM2 circle, A', 'gd10/C2-circle.mat', {'L3', 'L3_iii0'}, 'unsatL3', 'CLAIM'};
n = size(FR, 1);  R = cell(n, 1);
for i = 1:n, R{i} = rstat(opt, FR{i, 3}, FR{i, 4}, hh, FR{i, 5}); end
if all(cellfun(@isempty, R)), msg = 'no C2 file found'; return; end
fh = newfig(12.0);
ax = axes('Parent', fh, 'Position', [0.30 0.60 0.66 0.35]);  hold(ax, 'on');
lab = cellfun(@(a, b, c) sprintf('%s: %s [%s]', a, b, c), FR(:, 1), FR(:, 2), FR(:, 6), 'UniformOutput', false);
cl = repmat([0.35 0.35 0.35], n, 1);  ic = strcmp(FR(:, 6), 'CLAIM');  cl(ic, :) = repmat([0.85 0.33 0.10], sum(ic), 1);
forest(ax, lab, R, cl);
xlabel(ax, 'h = 1 - PAW-MOBADC / PA-MOBADC  [%]  (\pm1.65 SE)');
title(ax, '(a) PAW-MOBADC: gain of the static (1 + K-hat) payload-wind feed-forward over PA-MOBADC');
% effort and swing: CONFIRM2 (bars = pooled / median, dots = segments), dev (open diamonds, theta only)
CF = {'circle', 'MOBADC-W', 'gd10/D2.mat', 'L2', 'gd6/d2_p2.mat', 'L2';
      'circle', 'PA-MOBADC', 'gd10/D2.mat', 'L3', 'gd6/d2_p2.mat', 'L3';
      'circle', 'PAW-MOBADC', 'gd10/C2-circle.mat', 'L3_iii0', 'gd7/static-circle.mat', 'L3_iii0';
      'circle', 'INDI-DE', 'gd10/C2-circle.mat', 'H3', 'gd7/H3-circle.mat', 'H3';
      'hover', 'PA-MOBADC', 'gd10/C2-hover.mat', 'L3', 'gd7/static-hover.mat', 'L3';
      'hover', 'PAW-MOBADC', 'gd10/C2-hover.mat', 'L3_iii0', 'gd7/static-hover.mat', 'L3_iii0';
      'hover', 'INDI-DE', 'gd10/C2-hover.mat', 'H3', 'gd7/static-hover.mat', 'H3'};
x = [1 2 3 4 5.6 6.6 7.6];
col = colcols();  ci = [1 2 3 4 2 3 4];
Q = {'u_osc', 'theta_rms_stat_deg', 'theta_max_stat_deg'};
YL = {'u_{osc} [N]', '\theta RMS [deg]', '\theta max [deg]'};
TT = {'(b) control effort u_{osc} (CONFIRM2 only: not stored on dev)', '(c) payload swing, RMS', ...
      '(d) payload swing, max'};
for q = 1:3
    ax = axes('Parent', fh, 'Position', [0.07 + (q - 1) * 0.325, 0.09, 0.26, 0.36]);  hold(ax, 'on');
    for i = 1:size(CF, 1)
        v = colvals(opt, CF{i, 3}, CF{i, 4}, Q{q});
        if ~isempty(v)
            if q == 3, b = median(v); else, b = sqrt(mean(v.^2)); end
            if q == 3                                       % log axis: the median as a bar-wide tick
                plot(ax, x(i) + [-0.3 0.3], [b b], '-', 'Color', col(ci(i), :), 'LineWidth', 2);
            else
                vbar(ax, x(i), b, 0.6, 0.45 + 0.55 * col(ci(i), :), col(ci(i), :));
            end
            jit = 0.18 * (mod((1:numel(v))', 7) / 6 - 0.5);
            plot(ax, x(i) + jit, v, '.', 'Color', col(ci(i), :), 'MarkerSize', 3);
        end
        if q > 1
            w = colvals(opt, CF{i, 5}, CF{i, 6}, Q{q});
            if ~isempty(w)
                if q == 3, b = median(w); else, b = sqrt(mean(w.^2)); end
                plot(ax, x(i) + 0.38, b, 'd', 'Color', [0.2 0.2 0.2], 'MarkerSize', 4);
            end
        end
    end
    set(ax, 'XTick', x, 'XTickLabel', CF(:, 2), 'XLim', [0.4 8.2]);
    if q == 3, set(ax, 'YScale', 'log'); end
    yl = get(ax, 'YLim');
    text(2.5, yl(2), 'circle', 'Parent', ax, 'FontSize', 5, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(6.6, yl(2), 'hover', 'Parent', ax, 'FontSize', 5, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    ylabel(ax, YL{q});  title(ax, TT{q}, 'FontSize', 5.6);
end
annotation(fh, 'textbox', [0.07 0.0 0.9 0.04], 'String', ['bars: CONFIRM2, one set of each file, quadratic mean ' ...
    '(max: median); dots: CONFIRM2 segments; diamonds: dev where the swing is stored (circle PAW-MOBADC S40, INDI-DE ' ...
    'circle\_main; hover N6\_hover; the dev D2 rows carry no swing field); MOBADC-W not run on hover in CONFIRM2. ' ...
    'DESCRIPTIVE.'], 'EdgeColor', 'none', 'FontSize', 4.8);
style_axes(fh);
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
%  7  fast measurement (H3) vs prediction (L3, (iii-0))
%% =====================================================================
function [fh, msg] = fig7_fast(opt)
fh = [];
G = {'circle CONFIRM2', 'gd10/C2-circle.mat', {'L3', 'L3_iii0', 'H3'};
     'circle dev (circle\_main)', 'gd7/H3-circle.mat', {'L3', 'H3'};
     'circle dev (S40)', 'gd7/static-circle.mat', {'L3', 'L3_iii0'};
     'hover CONFIRM2', 'gd10/C2-hover.mat', {'L3', 'L3_iii0', 'H3'};
     'hover dev (N6\_hover)', 'gd7/static-hover.mat', {'L3', 'L3_iii0', 'H3'}};
rel = @(p) p(1) / p(2) - 1;
RT = {'INDI-DE / PA-MOBADC - 1, dev circle\_main', 'gd7/H3-circle.mat', {'H3', 'L3'};
      'INDI-DE / PA-MOBADC - 1, CONFIRM2 circle', 'gd10/C2-circle.mat', {'H3', 'L3'};
      'INDI-DE / PA-MOBADC - 1, dev N6\_hover', 'gd7/H3-hover.mat', {'H3', 'L3'};
      'INDI-DE / PA-MOBADC - 1, CONFIRM2 hover', 'gd10/C2-hover.mat', {'H3', 'L3'};
      'PAW-MOBADC / INDI-DE - 1, CONFIRM2 circle', 'gd10/C2-circle.mat', {'L3_iii0', 'H3'};
      'PAW-MOBADC / INDI-DE - 1, dev N6\_hover', 'gd7/static-hover.mat', {'L3_iii0', 'H3'};
      'PAW-MOBADC / INDI-DE - 1, CONFIRM2 hover', 'gd10/C2-hover.mat', {'L3_iii0', 'H3'}};
R = cell(size(RT, 1), 1);
for i = 1:numel(R), R{i} = rstat(opt, RT{i, 2}, RT{i, 3}, rel, 'one4'); end
if all(cellfun(@isempty, R)), msg = 'no H3 / C2 file found'; return; end
fh = newfig(7.5);
col = colcols();  cn = {'L3', 'L3_iii0', 'H3'};  cc = [2 3 4];
ax = axes('Parent', fh, 'Position', [0.07 0.22 0.40 0.68]);  hold(ax, 'on');
hb = zeros(1, 3);  NT = nan(size(G, 1), 2);  lo = Inf;  hi = 0;
for g = 1:size(G, 1)
    [Z, cols, ok] = p2r_load(opt.Root, G{g, 2});
    if ~ok, continue; end
    [E, ~, ~, keep] = p2r_subset(Z, cols, G{g, 3}, 'one4');
    P = sqrt(mean(E(keep, :).^2, 1));
    for c = 1:numel(G{g, 3})
        k = find(strcmp(cn, G{g, 3}{c}));
        hb(k) = plot(ax, g + (k - 2) * 0.26, P(c), 's', 'MarkerFaceColor', col(cc(k), :), 'Color', col(cc(k), :), ...
            'MarkerSize', 5);
    end
    NT(g, :) = [sum(keep), max(P)];  lo = min(lo, min(P));  hi = max(hi, max(P));
end
if isfinite(lo), set(ax, 'YLim', [lo / 1.6, hi * 2.2]); end
for g = find(isfinite(NT(:, 1)))'
    text(g, NT(g, 2) * 1.35, sprintf('n %d', NT(g, 1)), 'Parent', ax, 'FontSize', 4.6, 'HorizontalAlignment', 'center');
end
set(ax, 'YScale', 'log', 'XTick', 1:size(G, 1), 'XTickLabel', G(:, 1), 'XLim', [0.5 size(G, 1) + 0.5]);
try, set(ax, 'XTickLabelRotation', 25); catch, end
ylabel(ax, 'pooled mean error [m] (one set of each file)');
title(ax, '(a) pooled mean error: PA-MOBADC, PAW-MOBADC, INDI-DE');
k = hb ~= 0;
ln = p2_names({'L3', 'L3_iii0', 'H3'});
legend(ax, hb(k), ln(k), 'Location', 'southwest', 'FontSize', 5);
ax = axes('Parent', fh, 'Position', [0.68 0.22 0.29 0.68]);  hold(ax, 'on');
forest(ax, RT(:, 1), R, repmat([0.35 0.35 0.35], numel(R), 1));
xlabel(ax, 'relative difference [%]  (\pm1.65 SE)');
title(ax, '(b) ratios (DESCRIPTIVE)');
style_axes(fh);
msg = 'DESCRIPTIVE; dev circle PAW-MOBADC only on S40, INDI-DE only on circle_main';
end

%% =====================================================================
%  8  C3: map of the 12 wind groups
%% =====================================================================
function [fh, msg] = fig8_c3(opt)
G = {'#1 N5-A-Weak', 'N5-A-Weak';  '#2 N5-A-Medium', 'N5-A-Medium';  '#3 N5-A-Strong', '';
     '#4 N5-B-Weak', 'N5-B-Weak';  '#5 N5-B-Medium', 'N5-B-Medium';  '#6 N4b-P2-base', 'N4b-P2-base';
     '#7 N4b-P2-d200', 'N4b-P2-d200';  '#8 N4b-P2-L15', 'N4b-P2-L15';  '#9 N4b-P2-K10', 'N4b-P2-K10';
     '#10 N6', 'N6';  '#11 N5-A-StrongRel (post hoc)', 'N5-A-StrongRel';  '#12 N5-H-StrongRel (post hoc)', 'N5-H-StrongRel'};
hh = @(p) 1 - p(2) / p(1);
n = size(G, 1);  R = cell(n, 1);  V = repmat({''}, n, 1);
for i = 1:n
    if isempty(G{i, 2}), V{i} = 'empty under A2'; continue; end
    c = {'L3', 'O'};  if strcmp(G{i, 2}, 'N6'), c = {'L3_6', 'O_6'}; end
    R{i} = rstat(opt, ['gd7/' G{i, 2} '.mat'], c, hh, 'one4');
    r = R{i};
    if isempty(r), V{i} = 'no file / < 2 segments'; continue; end
    if r.n < 15 || r.nd < 6
        V{i} = sprintf('n %d (%d d): not evaluable', r.n, r.nd);
    else
        hr = r.val >= 0.10 && all(sign(r.loo) == sign(r.val)) && r.med >= 0.05;
        V{i} = sprintf('n %d (%d d): %s', r.n, r.nd, tern(hr, 'HEADROOM', 'no headroom'));
    end
end
fh = newfig(8.5);
ax = axes('Parent', fh, 'Position', [0.24 0.11 0.50 0.82]);  hold(ax, 'on');
forest(ax, G(:, 1), R, repmat([0.35 0.35 0.35], n, 1));
yl = get(ax, 'YLim');
plot(ax, [10 10], yl, '--', 'Color', [0.2 0.4 0.7], 'HandleVisibility', 'off');
xl = get(ax, 'XLim');
for i = 1:n
    text(xl(2) + 0.03 * diff(xl), n - i + 1, V{i}, 'Parent', ax, 'FontSize', 5, 'Clipping', 'off');
end
xlabel(ax, 'h = 1 - oracle(\tau_w*) / PA-MOBADC  [%]  (\pm1.65 SE); group N6: both with the N6 term');
title(ax, 'C3: headroom of advance wind knowledge, 12 registered groups (sec 0.6, 0.8); dashed: 10 %');
style_axes(fh);
msg = 'C3 map; rule sec 0.6 (h >= 10 %, LOO sign, by-day median >= 5 %; n >= 15, days >= 6)';
end

%% =====================================================================
%  helpers
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

function forest(ax, labels, R, cl)
%FOREST  value (percent) +-1.65 SE per row, top to bottom; a missing row is labelled.
n = numel(labels);
for i = 1:n
    y = n - i + 1;  r = R{i};
    if isempty(r)
        text(0, y, ' no data', 'Parent', ax, 'FontSize', 5, 'Color', [0.5 0.5 0.5]);
        continue
    end
    v = 100 * r.val;  e = 165 * r.se;
    if isfinite(e), plot(ax, [v - e, v + e], [y y], '-', 'Color', cl(i, :), 'LineWidth', 1.1); end
    plot(ax, v, y, 'o', 'MarkerFaceColor', cl(i, :), 'Color', cl(i, :), 'MarkerSize', 3.5);
    text(v, y + 0.32, sprintf('%+.1f', v), 'Parent', ax, 'FontSize', 4.6, 'HorizontalAlignment', 'center');
end
set(ax, 'YTick', 1:n, 'YTickLabel', labels(end:-1:1), 'YLim', [0.4 n + 0.6]);
xl = get(ax, 'XLim');  xl = [min(xl(1), -5), max(xl(2), 5)];
plot(ax, [0 0], [0.4 n + 0.6], ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
set(ax, 'XLim', xl);
end

function h = vpoint(ax, x, r, col, mk)
h = 0;
if isempty(r), return; end
v = 100 * r.val;  e = 165 * r.se;
if isfinite(e), plot(ax, [x x], [v - e, v + e], '-', 'Color', col, 'LineWidth', 1.1); end
h = plot(ax, x, v, mk, 'MarkerFaceColor', col, 'Color', col, 'MarkerSize', 4);
text(x + 0.05, v, sprintf(' %+.1f', v), 'Parent', ax, 'FontSize', 4.6);
end

function vbar(ax, x, y, w, fc, ec)
%VBAR  One bar from 0 (bar() with a scalar x ignores the width in Octave).
if ~(y > 0), return; end
rectangle('Parent', ax, 'Position', [x - w / 2, 0, w, y], 'FaceColor', fc, 'EdgeColor', ec);
end

function c = colcols()
%COLCOLS  L2, L3, (iii-0), H3.
c = [0.25 0.45 0.75; 0.85 0.33 0.10; 0.20 0.60 0.30; 0.50 0.30 0.65];
end

function fh = newfig(hcm)
fh = figure('Visible', 'off', 'Color', 'w');
paper_size(fh, 'double', hcm);
end

function style_axes(fh)
ax = findall(fh, 'Type', 'axes');
for k = 1:numel(ax)
    try, set(ax(k), 'FontSize', 5.6, 'Box', 'on', 'TickDir', 'out'); catch, end
end
end

function save_p2(fh, opt, stem)
paper_style(fh);
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
fid = fopen(fn, 'w');
if fid < 0, return; end
fprintf(fid, '%s\n', S{:});
fclose(fid);
end

function bx(ax, x, y, w, h, lines, col, fs)
rectangle('Parent', ax, 'Position', [x y w h], 'FaceColor', col, 'EdgeColor', [0.25 0.25 0.25], 'LineWidth', 0.6);
n = numel(lines);
for i = 1:n
    text(x + w / 2, y + h - h * (i - 0.5) / n, lines{i}, 'Parent', ax, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontSize', fs, 'Interpreter', 'tex');
end
end

function sumnode(ax, x, y, fs)
t = linspace(0, 2 * pi, 60);
patch('Parent', ax, 'XData', x + 1.8 * cos(t), 'YData', y + 1.8 * sin(t), 'FaceColor', 'w', 'EdgeColor', [0.25 0.25 0.25]);
text(x, y, '\Sigma', 'Parent', ax, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', fs);
end

function arrow(ax, x1, y1, x2, y2, col)
plot(ax, [x1 x2], [y1 y2], '-', 'Color', col, 'LineWidth', 0.6);
d = [x2 - x1, y2 - y1];
if all(d == 0), return; end
if abs(d(1)) >= abs(d(2))
    s = sign(d(1));
    patch('Parent', ax, 'XData', [x2, x2 - s * 1.1, x2 - s * 1.1], 'YData', [y2, y2 + 0.6, y2 - 0.6], ...
        'FaceColor', col, 'EdgeColor', col);
else
    s = sign(d(2));
    patch('Parent', ax, 'XData', [x2 - 0.45, x2 + 0.45, x2], 'YData', [y2 - s * 1.2, y2 - s * 1.2, y2], ...
        'FaceColor', col, 'EdgeColor', col);
end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
