function S = make_ijdc_figures(varargin)
%MAKE_IJDC_FIGURES  The figures of the IJDC manuscript (REGISTER_P2 sec 68.1) -> paper/figures/ijdc_<name>.pdf / .png
%
%   make_ijdc_figures                                   % every figure (re-simulates the two 'response' segments)
%   make_ijdc_figures('Only', {'compare', 'sensitivity'})   % some of them
%   make_ijdc_figures('Only', {'response'}, 'FromSaved', true)   % redraw 'response' from <Root>/gd11/flight.mat
%
%  One figure per step of the argument, in the forms of the control literature (time responses, bar charts of the
%  error, error against a parameter); Figure 1 of the paper (the system) is p2_fig1_system of make_p2_figures.
%    wind         the measured wind of the development pool and of the held-out days, with the trajectory envelopes
%    compare      pooled position error of MOBADC, MOBADC-W, PA-MOBADC (C1), PAW-MOBADC (C2) and INDI-DE, circle and
%                 hover, development and held-out
%    response     time responses on one circle and one hover segment: wind speed, and the tracking error along the
%                 path and outward (circle; the loop-delay signature) or east and north (hover)
%    horizon      why the delay matters: the lag term of eq. lag-err for one harmonic, and the registered horizon sweeps
%    windspeed    error per segment against the mean wind speed (development circle and hover)
%    sensitivity  the payload-drag term against the assumed drag ratio, trajectory, payload mass and cable length, and
%                 wind-sensor noise
%    oracle       C3: what perfect advance knowledge of the wind adds, per registered wind group
%    measure      (Discussion) hover: INDI-DE with accelerometer bias against PA-MOBADC and PAW-MOBADC
%
%  Numbers: held-out (CONFIRM2) values are read from the generated docs/RESULTS_P2.md and paper/tables/tables_p2.md,
%  development values from those files or from the final run (results/final), so every number drawn is a number of
%  the paper. Nothing is simulated except 'response', whose re-run means are checked against the stored final-run
%  rows to 'Tol' (sec 68). Style: 129 mm wide (84 mm for 'measure'), Arial 8 pt, panel letters a, b, c.
opt = struct('Only', {{'wind', 'compare', 'response', 'horizon', 'windspeed', 'sensitivity', 'oracle', 'measure'}}, ...
    'Root', fullfile(repo_root(), 'results', 'final'), 'Out', fullfile(repo_root(), 'paper', 'figures'), ...
    'Conf2Dir', 'wind_conf2', 'ExplManifest', 'wind_expl_t150_batch.json', 'Save', true, 'Close', true, ...
    'Tol', 5e-5, 'FromSaved', false);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'make_ijdc_figures: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
if ischar(opt.Only), opt.Only = {opt.Only}; end
opt.P2 = fullfile(repo_root(), 'docs', 'RESULTS_P2.md');
opt.FIN = fullfile(repo_root(), 'docs', 'RESULTS_FINAL.md');
opt.TAB = fullfile(repo_root(), 'paper', 'tables', 'tables_p2.md');
S = struct('fig', {}, 'drawn', {}, 'msg', {});
for k = 1:numel(opt.Only)
    nm = opt.Only{k};
    fprintf('\n  %s\n', nm);
    fh = [];  msg = '';
    try
        [fh, msg] = feval(['fig_' nm], opt);
    catch err
        msg = sprintf('error: %s (%s, line %d)', err.message, err.stack(1).name, err.stack(1).line);
    end
    if ~isempty(fh)
        save_fig(fh, opt, ['ijdc_' nm]);
        if opt.Close, close(fh); end
    end
    S(end + 1) = struct('fig', nm, 'drawn', ~isempty(fh), 'msg', msg); %#ok<AGROW>
end
fprintf('\n  make_ijdc_figures summary:\n');
for k = 1:numel(S), fprintf('    %-10s %-9s %s\n', S(k).fig, tern(S(k).drawn, 'drawn', 'NOT DRAWN'), S(k).msg); end
end

%% =====================================================================
%  wind: the test conditions
%% =====================================================================
function [fh, msg] = fig_wind(opt)
Zf = load('field_grid_K050.mat', 'T');
man = jsondecode(fileread(opt.ExplManifest));
fd = [cellstr(Zf.T.file(:)); cellstr(man.files(:))];
mc = jsondecode(fileread(fullfile(opt.Conf2Dir, 'wind_conf2_t150_batch.json')));
fc = cellfun(@(f) fullfile(opt.Conf2Dir, f), cellstr(mc.files(:)), 'UniformOutput', false);
[Ud, Td] = segwind(fd);  [Uc, Tc] = segwind(fc);
ENV = {8.02, 'circle';  10.86, 'hover'};                % A2 envelopes (sec 62.1 (2)), K 0.5
fh = newfig(12.9, 5.9);
a = newax(fh, [1.15 0.95 5.0 4.0]);
e = 0:1:ceil(max([Ud; Uc]));
stairsfrac(a, Ud, e, C('dev'), true);  stairsfrac(a, Uc, e, C('held'), false);
yl = [0 0.27];  set(a, 'YLim', yl, 'XLim', [0 e(end)]);
envmark(a, ENV, yl);
xlabel(a, 'mean wind speed {\itU} (m s^{-1})');  ylabel(a, 'fraction of segments');
panel(a, 'a', '');
b = newax(fh, [7.6 0.95 5.0 4.0]);
plot(b, Ud, Td, 'o', 'MarkerSize', 2.2, 'MarkerFaceColor', mix(C('dev'), 0.35), 'MarkerEdgeColor', 'none');
plot(b, Uc, Tc, 'o', 'MarkerSize', 2.6, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', C('held'), 'LineWidth', 0.5);
set(b, 'XLim', [0 e(end)], 'YLim', [0 0.6]);
envmark(b, ENV, [0 0.6]);
xlabel(b, 'mean wind speed {\itU} (m s^{-1})');  ylabel(b, 'turbulence intensity \sigma_u / {\itU}');
panel(b, 'b', '');
h = [patch(a, NaN, NaN, mix(C('dev'), 0.55), 'EdgeColor', C('dev')), plot(a, NaN, NaN, '-', 'Color', C('held'))];
topleg(fh, h, {sprintf('development pool, %d segments', numel(Ud)), sprintf('held-out days, %d segments', numel(Uc))});
msg = sprintf('dev %d / held-out %d segments', numel(Ud), numel(Uc));
end

function [U, TI] = segwind(files)
%SEGWIND  U as p2_segset (norm of the mean horizontal plant wind, t >= 140 s); TI = std of the wind projected on
%  that mean direction / U, same window (sec 62.1 (2)).
n = numel(files);  U = nan(n, 1);  TI = U;
for i = 1:n
    M = load(files{i}, 't_plant', 'w_plant');
    w = M.w_plant(M.t_plant(:) >= 140, 1:2);
    mu = mean(w, 1);  U(i) = norm(mu);
    TI(i) = std(w * (mu(:) / U(i))) / U(i);
end
end

function stairsfrac(ax, x, e, col, filled)
n = histcounts(x, e) / numel(x);
xs = reshape([e(1:end - 1); e(2:end)], 1, []);  ys = reshape([n; n], 1, []);
if filled
    patch(ax, [xs(1) xs xs(end)], [0 ys 0], mix(col, 0.55), 'EdgeColor', 'none');
    plot(ax, xs, ys, '-', 'Color', col, 'LineWidth', 0.6);
else
    plot(ax, [xs(1) xs xs(end)], [0 ys 0], '-', 'Color', col, 'LineWidth', 0.9);
end
end

function envmark(ax, ENV, yl)
for k = 1:size(ENV, 1)
    plot(ax, ENV{k, 1} * [1 1], yl, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.6);
    text(ax, ENV{k, 1}, yl(2), [' ' ENV{k, 2}], 'FontSize', 7, 'Color', [0.35 0.35 0.35], ...
        'Rotation', 90, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
end
end

%% =====================================================================
%  compare: pooled error of every controller, development and held-out
%% =====================================================================
function [fh, msg] = fig_compare(opt)
% circle: the one sets of Tables 5 and 6 (development 133 segments, held-out 56)
cd = md_pooled(opt.P2, 'dev circle_main, one4 (n 133');
ch = md_pooled(opt.P2, 'CONFIRM2 circle, one4 (n 56, 14 days; `gd10/C2-circle.mat + gd10/D2.mat`');
ci = md_pooled(opt.P2, 'CONFIRM2 circle, one4 (n 56, 14 days; `gd10/C2-circle.mat`)');
td = md_tab6(opt.TAB, 'circle, dev circle_main');  th = md_tab6(opt.TAB, 'circle, CONFIRM2');
nm = {'MOBADC', 'MOBADC-W', 'PA-MOBADC', 'PAW-MOBADC', 'INDI-DE'};
Pc = 1000 * [cd('MOBADC'), td, md_tab5(opt.TAB, 'INDI-DE');  ch('MOBADC'), th, ci('INDI-DE')];
% hover: the registered scoring set (PA-MOBADC below its tilt clamp): development 124, held-out 52
hd = md_tab6(opt.TAB, 'hover, dev N6_hover, subset A');  hh = md_pooled(opt.P2, 'CONFIRM2 hover, unsat4 (n 52');
Ph = 1000 * [hd(2:3); hh('PA-MOBADC'), hh('PAW-MOBADC')];
fh = newfig(12.9, 6.6);
a = newax(fh, [1.2 1.25 7.4 4.2]);
set(a, 'YLim', [0 54], 'YTick', 0:10:50, 'YGrid', 'on');
gbars(a, Pc, nm, {'development', 'held-out'}, {'n = 133', 'n = 56'});
ylabel(a, 'pooled position error (mm)');
panel(a, 'a', 'circle');
b = newax(fh, [9.6 1.25 3.0 4.2]);
set(b, 'YLim', [0 10.8], 'YTick', 0:2:10, 'YGrid', 'on');
gbars(b, Ph, nm(3:4), {'development', 'held-out'}, {'n = 124', 'n = 52'});
panel(b, 'b', 'hover');
h = gobjects(1, numel(nm));
for c = 1:numel(nm), h(c) = patch(a, NaN, NaN, ctrl(nm{c}), 'EdgeColor', 'none'); end
topleg(fh, h, nm);
msg = 'circle one sets 133 / 56; hover scoring set 124 / 52';
end

function gbars(ax, P, nm, grp, sub)
%GBARS  Grouped bars: rows of P = groups, columns = controllers; the value above each bar.
[ng, nc] = size(P);  w = 0.82 / nc;
for g = 1:ng
    for c = 1:nc
        x = g + (c - (nc + 1) / 2) * w;
        rectangle('Parent', ax, 'Position', [x - 0.42 * w, 0, 0.84 * w, P(g, c)], 'FaceColor', ctrl(nm{c}), ...
            'EdgeColor', 'none');
        text(ax, x, P(g, c), [' ' num(P(g, c), tern(P(g, c) < 10, '%.2f', '%.1f'))], 'FontSize', 6.5, ...
            'Rotation', 90, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
    end
end
set(ax, 'XLim', [0.5 ng + 0.5], 'XTick', 1:ng, 'XTickLabel', '', 'TickLength', [0 0]);
undertick(ax, 1:ng, grp, sub);
end

function undertick(ax, x, l1, l2)
%UNDERTICK  Two-line labels under the x axis (the tick labels of MATLAB take one line each).
p = get(ax, 'Position');  yl = get(ax, 'YLim');  lg = strcmp(get(ax, 'YScale'), 'log');
for k = 1:numel(x)
    for j = 1:2
        if j == 1, s = l1{k}; else, s = l2{k}; end
        if isempty(s), continue; end
        off = (0.12 + 0.33 * (j - 1)) / p(4);              % cm below the axis, as a fraction of the axes height
        if lg, y = 10 ^ (log10(yl(1)) - off * diff(log10(yl))); else, y = yl(1) - off * diff(yl); end
        text(ax, x(k), y, s, 'FontSize', 7.5 - 0.5 * (j - 1), 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', 'Color', tern(j == 1, [0.15 0.15 0.15], [0.4 0.4 0.4]), 'Clipping', 'off');
    end
end
end

%% =====================================================================
%  response: the two gaps in the time responses of one circle and one hover segment
%% =====================================================================
function [fh, msg] = fig_response(opt)
fh = [];
saved = fullfile(opt.Root, 'gd11', 'flight.mat');
if opt.FromSaved && exist(saved, 'file') == 2
    Z = load(saved, 'T');  T = Z.T;  how = 'drawn from the saved time series';
else
    [st, out] = system(sprintf('git -C "%s" status --porcelain -- baseline1.slx core experiments', repo_root()));
    if st ~= 0 || ~isempty(strtrim(out))
        msg = sprintf('git status failed or local change in baseline1.slx / core / experiments - not run:%s%s', newline, out);
        return
    end
    [T, d] = sim_flight(opt);
    if ~all(d <= opt.Tol)
        msg = sprintf('agreement check FAILED (max |d| %.3g > %.3g) - figure not saved', max(d), opt.Tol);
        return
    end
    od = fullfile(opt.Root, 'gd11');  if exist(od, 'dir') ~= 7, mkdir(od); end
    save(saved, 'T');
    how = sprintf('re-run = stored to %.1g (max |d|); time series in %s', max(d), saved);
end
fh = newfig(12.9, 10.1);
X = [1.3 7.65];  Wd = 4.95;  Hw = 1.6;  He = 2.3;  Y = [7.2 4.15 1.2];
dk = 20;                                                 % every 20th sample (20 ms) is drawn
% ---- wind ----
for s = 1:2
    if s == 1, fn = T.c.file; else, fn = T.h.file; end
    M = load(fn, 't_plant', 'w_plant');  k = M.t_plant(:) >= 140;
    ax = newax(fh, [X(s) Y(1) Wd Hw]);
    plot(ax, M.t_plant(k), vecnorm(M.w_plant(k, 1:2), 2, 2), '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.6);
    set(ax, 'XLim', [140 200], 'XTickLabel', '');
    ylabel(ax, 'wind (m s^{-1})');
    panel(ax, char('a' + s - 1), tern(s == 1, 'circle: wind speed', 'hover: wind speed'));
end
% ---- circle: along-track and radial error ----
E = cell(1, numel(T.c.names));
for c = 1:numel(T.c.names)
    [al, ra] = pathframe(T.c.t{c}, T.c.g{c}, T.c.gd{c});
    E{c} = 1000 * [al ra];
end
tc = T.c.t{1}(T.c.t{1} >= 140);
YL = {'circle: tracking error along the path', 'circle: tracking error outward (radial)'};
for r = 1:2
    ax = newax(fh, [X(1) Y(r + 1) Wd He]);
    plot(ax, [140 200], [0 0], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.4);
    for c = 1:numel(T.c.names)
        plot(ax, tc(1:dk:end), E{c}(1:dk:end, r), '-', 'Color', ctrl(T.c.names{c}), 'LineWidth', 0.7);
    end
    set(ax, 'XLim', [140 200]);
    if r == 1, set(ax, 'XTickLabel', ''); else, xlabel(ax, 'time (s)'); end
    ylabel(ax, 'error (mm)');
    panel(ax, char('c' + 2 * (r - 1)), YL{r});
end
% ---- hover: east and north error ----
th = T.h.t{1};  kh = th >= 140;
YL = {'hover: tracking error east', 'hover: tracking error north'};
for r = 1:2
    ax = newax(fh, [X(2) Y(r + 1) Wd He]);
    plot(ax, [140 200], [0 0], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.4);
    for c = 1:numel(T.h.names)
        d = 1000 * (T.h.g{c}(kh, r) - T.h.gd{c}(kh, r));
        plot(ax, th(kh), d, '-', 'Color', ctrl(T.h.names{c}), 'LineWidth', 0.7);
    end
    set(ax, 'XLim', [140 200]);
    if r == 1, set(ax, 'XTickLabel', ''); else, xlabel(ax, 'time (s)'); end
    ylabel(ax, 'error (mm)');
    panel(ax, char('d' + 2 * (r - 1)), YL{r});
end
nm = T.c.names;
h = gobjects(1, numel(nm));
for c = 1:numel(nm), h(c) = plot(ax, NaN, NaN, '-', 'Color', ctrl(nm{c}), 'LineWidth', 1.2); end
topleg(fh, h, nm);
msg = sprintf('circle %s, hover %s; %s', T.c.file, T.h.file, how);
end

%% =====================================================================
%  sensitivity: what the payload-drag term depends on
%% =====================================================================
function [fh, msg] = fig_sensitivity(opt)
F = opt.FIN;  k7 = ['K' char(770)];
fh = newfig(12.9, 10.8);
% ---- a: assumed drag ratio, pooled error ----
a = newax(fh, [1.25 6.25 4.6 3.6]);
cc = {'L3', 'L3_iii0_k070', 'L3_iii0', 'L3_iii0_k130'};
kc = pooled_cols(opt, 'gd7/static-circle-k.mat', cc);  kh = pooled_cols(opt, 'gd7/static-hover-k.mat', cc);
x = [0.7 1 1.3];
plot(a, [0.62 1.38], kc.P(1) * [1 1], '-', 'Color', ctrl('PA-MOBADC'), 'LineWidth', 0.9);
plot(a, x, kc.P(2:4), '-o', 'Color', ctrl('PAW-MOBADC'), 'MarkerFaceColor', ctrl('PAW-MOBADC'), ...
    'MarkerEdgeColor', 'w', 'MarkerSize', 4.5, 'LineWidth', 0.9);
plot(a, [0.62 1.38], kh.P(1) * [1 1], '--', 'Color', ctrl('PA-MOBADC'), 'LineWidth', 0.9);
plot(a, x, kh.P(2:4), '--s', 'Color', ctrl('PAW-MOBADC'), 'MarkerFaceColor', 'w', 'MarkerSize', 4, 'LineWidth', 0.9);
set(a, 'XLim', [0.62 1.38], 'XTick', x, 'XTickLabel', {['0.7 ' k7], k7, ['1.3 ' k7]}, 'YLim', [0 18], 'YGrid', 'on');
text(a, 0.64, kc.P(1) + 0.5, sprintf('PA-MOBADC, circle (%d)', kc.n), 'FontSize', 6.5, 'Color', ctrl('PA-MOBADC'), ...
    'VerticalAlignment', 'bottom');
text(a, 0.64, kh.P(1) + 0.5, sprintf('PA-MOBADC, hover (%d)', kh.n), 'FontSize', 6.5, 'Color', ctrl('PA-MOBADC'), ...
    'VerticalAlignment', 'bottom');
text(a, 1.0, kc.P(3) - 0.55, 'PAW-MOBADC, circle', 'FontSize', 6.5, 'Color', ctrl('PAW-MOBADC'), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
text(a, 1.0, kh.P(3) - 0.55, 'PAW-MOBADC, hover', 'FontSize', 6.5, 'Color', ctrl('PAW-MOBADC'), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
xlabel(a, 'drag ratio assumed by the controller');  ylabel(a, 'pooled position error (mm)');
panel(a, 'a', 'assumed drag ratio');
% ---- b: trajectory, prediction and preview ----
b = newax(fh, [7.75 6.25 4.85 3.6]);
V = [rowval(F, {'E4-circle-C2', 'E4-T3b-C2', 'E4-square-C2'}); rowval(F, {'E4-circle-C2V', 'E4-T3b-C2V', 'E4-square-C2V'})];
ebars(b, V, {ctrl('PAW-MOBADC'), mix(ctrl('PAW-MOBADC'), 0.55)}, {'circle', 'figure-eight', 'square'});
set(b, 'YLim', [0 100], 'YTick', 0:20:80, 'YGrid', 'on');
ylabel(b, 'error reduction by C2 (%)');
panel(b, 'b', 'trajectory');
lb = legend(b, [patch(b, NaN, NaN, ctrl('PAW-MOBADC'), 'EdgeColor', 'none'), ...
    patch(b, NaN, NaN, mix(ctrl('PAW-MOBADC'), 0.55), 'EdgeColor', 'none')], ...
    {'added to PA-MOBADC', 'added to MOBADC-W + preview'}, 'Box', 'off', 'FontSize', 6.5, 'Location', 'north');
lb.ItemTokenSize = [10 8];
% ---- c: payload mass and cable length ----
c3 = newax(fh, [1.25 1.25 4.6 3.6]);
V = [rowval(F, {'E4-mp025-L050-C2-env', 'E4-mp025-C2-env', 'E4-mp025-L150-C2-env'});   % series: payload mass
     rowval(F, {'E4-L050-C2', 'E4-circle-C2', 'E4-L150-C2'});                        % groups: cable length
     rowval(F, {'E4-mp065-L050-C2', 'E4-mp065-C2', 'E4-mp065-L150-C2'})];
ebars(c3, V, {mix(ctrl('PAW-MOBADC'), 0.65), ctrl('PAW-MOBADC'), 0.6 * ctrl('PAW-MOBADC')}, {'0.5 m', '1.0 m', '1.5 m'});
set(c3, 'YLim', [0 100], 'YTick', 0:20:80, 'YGrid', 'on');
xlabel(c3, 'cable length');  ylabel(c3, 'error reduction by C2 (%)');
panel(c3, 'c', 'payload mass and cable length, circle');
lc = legend(c3, [patch(c3, NaN, NaN, mix(ctrl('PAW-MOBADC'), 0.65), 'EdgeColor', 'none'), ...
    patch(c3, NaN, NaN, ctrl('PAW-MOBADC'), 'EdgeColor', 'none'), patch(c3, NaN, NaN, 0.6 * ctrl('PAW-MOBADC'), 'EdgeColor', 'none')], ...
    {'0.25 kg', '0.5 kg', '0.65 kg'}, 'Box', 'off', 'FontSize', 6.5, 'Orientation', 'horizontal', 'Location', 'north');
lc.ItemTokenSize = [10 8];
% ---- d: wind-sensor noise ----
d = newax(fh, [7.75 1.25 4.85 3.6]);
V = [rowval(F, {'E1-c0', 'E1-h0'}); rowval(F, {'E1-c', 'E1-h'})];
ebars(d, V, {ctrl('PAW-MOBADC'), mix(ctrl('PAW-MOBADC'), 0.55)}, {'circle', 'hover'});
set(d, 'YLim', [0 105], 'YTick', 0:20:100, 'YGrid', 'on');
ylabel(d, 'error reduction by C2 (%)');
panel(d, 'd', 'wind-sensor noise');
ld = legend(d, [patch(d, NaN, NaN, ctrl('PAW-MOBADC'), 'EdgeColor', 'none'), ...
    patch(d, NaN, NaN, mix(ctrl('PAW-MOBADC'), 0.55), 'EdgeColor', 'none')], ...
    {'no noise', '0.1 m s^{-1} noise'}, 'Box', 'off', 'FontSize', 6.5, 'Orientation', 'horizontal', 'Location', 'north');
ld.ItemTokenSize = [10 8];
msg = sprintf('K-hat on S40 (%d) / S40hover (%d); E1, E4 of RESULTS_FINAL', kc.n, kh.n);
end

function V = rowval(file, ids)
%ROWVAL  [values; SEs] (percent) of the rows IDS of a generated results table; values as h (positive = gain).
V = zeros(2, numel(ids));
for k = 1:numel(ids)
    r = md_row(file, ids{k});  V(:, k) = 100 * [r.val; r.se];
end
V = reshape(V, 1, []);
end

function ebars(ax, V, cols, grp)
%EBARS  Grouped bars with +-1.65 SE whiskers. V: one row per series, entries [value SE value SE ...] per group.
ns = size(V, 1);  ng = size(V, 2) / 2;  w = 0.78 / ns;
for s = 1:ns
    for g = 1:ng
        v = V(s, 2 * g - 1);  e = 1.65 * V(s, 2 * g);  x = g + (s - (ns + 1) / 2) * w;
        rectangle('Parent', ax, 'Position', [x - 0.42 * w, 0, 0.84 * w, v], 'FaceColor', cols{s}, 'EdgeColor', 'none');
        plot(ax, [x x], v + [-e e], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.6);
        text(ax, x, v + e, [' ' num(v, '%.1f')], 'FontSize', 6, 'Rotation', 90, 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle');
    end
end
set(ax, 'XLim', [0.5 ng + 0.5], 'XTick', 1:ng, 'XTickLabel', grp, 'TickLength', [0 0]);
end

function R = pooled_cols(opt, f, cols)
%POOLED_COLS  Pooled error [mm] of COLS on the file's one set (finite in every column of the file).
[Z, c] = p2r_load(opt.Root, f);
[E, ~, ~, keep] = p2r_subset(Z, c, cols, 'one4');
R.P = 1000 * sqrt(mean(E(keep, :).^2, 1));  R.n = sum(keep);
end

%% =====================================================================
%  oracle: C3
%% =====================================================================
function [fh, msg] = fig_oracle(opt)
G = {'circle, K = 0, weak wind', 'grp-N5-A-Weak';  'circle, K = 0, medium wind', 'grp-N5-A-Medium';
     'circle, K = 0.5, weak wind', 'grp-N5-B-Weak';  'circle, K = 0.5, medium wind', 'grp-N5-B-Medium';
     'circle, main set', 'grp-N4b-P2-base';  'circle, wind sensor 200 ms late', 'grp-N4b-P2-d200';
     'circle, L = 1.5 m', 'grp-N4b-P2-L15';  'circle, K = 1.0', 'grp-N4b-P2-K10';
     'circle, strong relative wind*', 'grp-N5-A-StrongRel';
     'hover, wind-to-payload term', 'grp-N6';  'hover, strong relative wind*', 'grp-N5-H-StrongRel'};
n = size(G, 1);  dy = 0.36;
fh = newfig(12.9, n * dy + 1.55);
a = newax(fh, [4.25 0.95 6.1 n * dy]);
col = [0.45 0.45 0.45];
for i = 1:n
    y = n - i + 1;  r = md_row(opt.P2, G{i, 2});
    v = 100 * r.val;  e = 165 * r.se;
    rectangle('Parent', a, 'Position', [min(v, 0), y - 0.32, abs(v), 0.64], 'FaceColor', col, 'EdgeColor', 'none');
    plot(a, v + [-e e], [y y], '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 0.6);
    text(a, -0.6, y, G{i, 1}, 'FontSize', 7, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
        'Clipping', 'off');
    text(a, 25.8, y, sprintf('%s   %d (%d d)', num(v, '%+.1f'), r.n, r.nd), 'FontSize', 7, ...
        'VerticalAlignment', 'middle', 'Clipping', 'off');
end
plot(a, [10 10], [0.4 n + 0.6], '--', 'Color', ctrl('PAW-MOBADC'), 'LineWidth', 0.8);
text(a, 10.4, n + 0.55, 'registered threshold', 'FontSize', 7, 'Color', ctrl('PAW-MOBADC'), 'VerticalAlignment', 'top');
set(a, 'YLim', [0.4 n + 0.6], 'YTick', [], 'XLim', [0 25], 'XTick', 0:5:25, 'YColor', 'none', 'XGrid', 'on');
text(a, 25.8, n + 0.95, 'h (%)   segments', 'FontSize', 7, 'Clipping', 'off');
xlabel(a, ['improvement with perfect wind foresight {\ith} = 1 ' char(8722) ' oracle / PA-MOBADC (%)']);
msg = sprintf('%d groups (group 3 had no segment)', n);
end

%% =====================================================================
%  the two re-simulated segments
%% =====================================================================
function [T, d] = sim_flight(opt)
%SIM_FLIGHT  The two segments of sec 68.1, re-simulated with the final-run configurations (run_p2_gd6 D2,
%  run_p2_gd7 six-circle-h3 and static-hover) + KeepTraj; d = |re-run mean - stored mean| per column.
% ---- circle: the segment rule of sec 63.5 ----
Sc = p2_segset('circle_main', 'CapPerDay', 4, 'Quiet', true);
D2 = load(fullfile(opt.Root, 'gd6', 'd2_p2.mat'), 'rows');
U = nan(numel(D2.rows), 1);  ts = U;
for i = 1:numel(D2.rows)
    k = find(strcmp(Sc.files, D2.rows(i).file), 1);
    if ~isempty(k), U(i) = Sc.U(k); end
    p = D2.rows(i).p2{3};
    if isstruct(p) && isfield(p, 'tilt_sat_frac') && isfinite(D2.rows(i).E(3)), ts(i) = p.tilt_sat_frac; end
end
cand = find(ts < 0.01 & isfinite(U));
dU = abs(U(cand) - median(U(cand)));  tie = cand(dU == min(dU));
[~, o] = sort({D2.rows(tie).file});  fc = D2.rows(tie(o(1))).file;
X = load(fullfile(opt.Root, 'gd7', 'six-circle-h3.mat'), 'rows', 'key');
i2 = find(strcmp({D2.rows.file}, fc), 1);  ix = find(strcmp({X.rows.file}, fc), 1);
stc = [D2.rows(i2).E(2), D2.rows(i2).E(3), X.rows(ix).E(strcmp(X.key.cols, 'L3_iii0')), ...
       X.rows(ix).E(strcmp(X.key.cols, 'H3'))];
fprintf('    circle: %s (U %.3f m/s)\n', fc, U(i2));
b6 = {'Grid', true, 'PlantModel', 'p2', 'SensorDelayMs', 50, 'PayloadModel', 1, 'PayloadWind', 0.5, ...
      'OnDiverge', 'flag', 'Quiet', true, 'PredDelay', true, 'Cond', 'Test 4'};
b7 = [b6, {'L', 1.0, 'DoHarm', [0 1], 'TauPred', 0.290, 'TauPrev', 0, 'Only', {'g_psens'}, 'OracleTauMs', 280}];
[~, A] = pa_configs(fc, b6{:}, 'DoHarm', [0 1], 'Only', {'g_sens', 'g_psens'}, 'TauPred', 0.290, 'TauPrev', 0, ...
    'KeepTraj', true);
try, Simulink.sdi.clear; catch, end
[~, Bq] = pa_configs(fc, b7{:}, 'P2PredScale', [1 1 1 1.5], 'KeepTraj', true);
try, Simulink.sdi.clear; catch, end
[~, Cq] = pa_configs(fc, b7{:}, 'P2Cmp', 1, 'P2H3Hz', 32, 'KeepTraj', true);
try, Simulink.sdi.clear; catch, end
Mc = {A.g_sens, A.g_psens, Bq.g_psens, Cq.g_psens};
T.c = struct('file', fc, 'names', {{'MOBADC-W', 'PA-MOBADC', 'PAW-MOBADC', 'INDI-DE'}}, ...
    'mean', cellfun(@(m) m.mean, Mc), 'stored', stc, 'wind', meanwind(fc), ...
    't', {cellfun(@(m) m.t, Mc, 'UniformOutput', false)}, 'g', {cellfun(@(m) m.g, Mc, 'UniformOutput', false)}, ...
    'gd', {cellfun(@(m) m.gd, Mc, 'UniformOutput', false)});
% ---- hover: the rule of sec 68.1 ----
Sh = p2_segset('N6_hover', 'CapPerDay', 4, 'Quiet', true);
G = load(fullfile(opt.Root, 'gd7', 'static-hover.mat'), 'rows', 'key');
j3 = find(strcmp(G.key.cols, 'L3'));  j0 = find(strcmp(G.key.cols, 'L3_iii0'));
U = nan(numel(G.rows), 1);  ts = U;
for i = 1:numel(G.rows)
    k = find(strcmp(Sh.files, G.rows(i).file), 1);
    if ~isempty(k), U(i) = Sh.U(k); end
    p = G.rows(i).p2{j3};
    if isstruct(p) && isfield(p, 'tilt_sat_frac') && all(isfinite(G.rows(i).E([j3 j0]))), ts(i) = p.tilt_sat_frac; end
end
cand = find(ts < 0.01 & isfinite(U));
dU = abs(U(cand) - median(U(cand)));  tie = cand(dU == min(dU));
[~, o] = sort({G.rows(tie).file});  ih = tie(o(1));  fhv = G.rows(ih).file;
sth = G.rows(ih).E([j3 j0]);
fprintf('    hover: %s (U %.3f m/s; %d candidates, median U %.3f)\n', fhv, U(ih), numel(cand), median(U(cand)));
evalc('evalin(''base'', ''init_MOBADC_params'')');
Cs = op_set('Hover');
im = {'DoWAxis', im_oracle_axis(Cs.traj_type, Cs.traj_par, Cs.w_traj, 1.0)};
bh = [{'Grid', true, 'PlantModel', 'p2', 'SensorDelayMs', 50, 'PayloadModel', 1, 'PayloadWind', 0.5, ...
       'OnDiverge', 'flag', 'Quiet', true, 'PredDelay', true, 'Cond', 'Hover', 'L', 1.0}, im, ...
      {'TauPred', G.key.TauPred, 'TauPrev', 0, 'Only', {'g_psens'}, 'OracleTauMs', round(1000 * G.key.TauW)}];
[~, H1] = pa_configs(fhv, bh{:}, 'KeepTraj', true);
try, Simulink.sdi.clear; catch, end
[~, H2] = pa_configs(fhv, bh{:}, 'P2PredScale', [1 1 1 1.5], 'KeepTraj', true);
try, Simulink.sdi.clear; catch, end
Mh = {H1.g_psens, H2.g_psens};
T.h = struct('file', fhv, 'names', {{'PA-MOBADC', 'PAW-MOBADC'}}, 'mean', cellfun(@(m) m.mean, Mh), ...
    'stored', sth, 'wind', meanwind(fhv), 't', {cellfun(@(m) m.t, Mh, 'UniformOutput', false)}, ...
    'g', {cellfun(@(m) m.g, Mh, 'UniformOutput', false)}, 'gd', {cellfun(@(m) m.gd, Mh, 'UniformOutput', false)});
d = abs([T.c.mean - T.c.stored, T.h.mean - T.h.stored]);
nm = [T.c.names, T.h.names];  re = [T.c.mean, T.h.mean];  so = [T.c.stored, T.h.stored];
for k = 1:numel(nm)
    fprintf('    %-11s re-run %.15f  stored %.15f  |d| %.3g\n', nm{k}, re(k), so(k), d(k));
end
end

function w = meanwind(fn)
M = load(fn, 't_plant', 'w_plant');
w = mean(M.w_plant(M.t_plant(:) >= 140, 1:2), 1);
end

function [al, ra] = pathframe(t, g, gd)
%PATHFRAME  Deviation from the reference (flown - desired) along the path and outward from its centre.
ms = t >= 140;
p = g(ms, 1:2);  q = gd(ms, 1:2);  tt = t(ms);
c0 = (max(q, [], 1) + min(q, [], 1)) / 2;
r = q - c0;  rh = r ./ vecnorm(r, 2, 2);
v = [gradient(q(:, 1), tt), gradient(q(:, 2), tt)];  th = v ./ vecnorm(v, 2, 2);
dv = p - q;
al = sum(dv .* th, 2);  ra = sum(dv .* rh, 2);
end

%% =====================================================================
%  horizon: why the delay matters, and where the sweep puts the horizon
%% =====================================================================
function [fh, msg] = fig_horizon(opt)
Z = load(fullfile(opt.Root, 'gd6', 'n0p_p2.mat'), 'T');
T = Z.T(strcmp({Z.T.mode}, 'N0P'));
fh = newfig(12.9, 5.9);
% ---- a: the lag term for one harmonic ----
a = newax(fh, [1.15 0.95 4.45 4.0]);
sg = 1.575;  td = linspace(0, 0.9, 400);  f = 2 * abs(sin(sg * td / 2));
x1 = 2 * asin(0.5) / sg;                                 % 2|sin| = 1: late cancellation as large as none
patch(a, 1000 * [x1 0.9 0.9 x1], [0 0 1.4 1.4], [0.94 0.94 0.94], 'EdgeColor', 'none');
plot(a, 1000 * [0 0.9], [1 1], ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.6);
plot(a, 1000 * td, f, '-', 'Color', ctrl('MOBADC-W'), 'LineWidth', 1.1);
f0 = 2 * abs(sin(sg * 0.290 / 2));
plot(a, [290 290], [0 f0], '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.5);
plot(a, [0 290], [f0 f0], '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.5);
plot(a, 290, f0, 'o', 'MarkerSize', 4.5, 'MarkerFaceColor', ctrl('MOBADC-W'), 'MarkerEdgeColor', 'w');
text(a, 305, f0 - 0.04, sprintf('290 ms: %s', num(f0, '%.2f')), 'FontSize', 7, 'VerticalAlignment', 'top');
text(a, 1000 * (x1 + 0.9) / 2, 0.55, {'late', 'cancellation', 'adds error'}, 'FontSize', 7, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Color', [0.35 0.35 0.35]);
set(a, 'XLim', [0 900], 'YLim', [0 1.4], 'XTick', 0:300:900, 'YTick', 0:0.5:1.5);
xlabel(a, 'loop delay \tau_d (ms)');  ylabel(a, 'uncancelled fraction of the force');
panel(a, 'a', 'lag term 2|sin(\sigma\tau_d/2)|, \sigma = 1.575 rad s^{-1}');
% ---- b: the registered sweeps ----
b = newax(fh, [7.0 0.95 3.55 4.0]);
LB = {'circle', 'circle', [0.10 0.10 0.10], '-';  'T3b', 'figure-eight', [0.47 0.33 0.62], '-';
      'square', 'square', [0.80 0.47 0.65], '-';  'T5', 'multisine', [0.60 0.60 0.60], '-';
      'hover', 'hover', [0.60 0.60 0.60], '--'};
yy = [];
for k = 1:size(LB, 1)
    t = T(strcmp({T.label}, LB{k, 1}));
    if isempty(t), continue; end
    tau = t.coarse.tau(:);  R = t.coarse.R(:);
    if isstruct(t.fine) && ~isempty(t.fine), tau = [tau; t.fine.tau(:)]; R = [R; t.fine.R(:)]; end
    [tau, o] = unique(tau);  R = R(o);
    r = R / R(tau == 0);
    plot(b, 1000 * tau, r, LB{k, 4}, 'Color', LB{k, 3}, 'LineWidth', 0.9);
    [~, ks] = min(abs(tau - t.tau_star));
    plot(b, 1000 * t.tau_star, r(ks), 'o', 'MarkerSize', 4.2, 'MarkerFaceColor', LB{k, 3}, 'MarkerEdgeColor', 'w');
    yy(end + 1, :) = [r(end), k]; %#ok<AGROW>
end
yl = [0.5 1.3];
set(b, 'XLim', [0 400], 'YLim', yl, 'XTick', 0:100:400, 'YTick', 0.5:0.1:1.3);
[~, o] = sort(yy(:, 1));  ys = min(yy(o, 1), yl(2) - 0.03);
for i = 2:numel(ys), ys(i) = max(ys(i), ys(i - 1) + 0.115); end   % labels at the right end, not overlapping
for i = 1:numel(o)
    k = yy(o(i), 2);  t = T(strcmp({T.label}, LB{k, 1}));
    text(b, 410, ys(i), {LB{k, 2}, sprintf('\\tau* = %s ms', num(1000 * t.tau_star, '%.0f'))}, 'FontSize', 6.5, ...
        'Color', LB{k, 3}, 'VerticalAlignment', 'middle', 'Clipping', 'off');
end
plot(b, [0 400], [1 1], ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.6);
xlabel(b, 'prediction horizon \tau (ms)');  ylabel(b, 'pooled error relative to \tau = 0');
panel(b, 'b', 'PA-MOBADC, registered sweep');
msg = sprintf('%d sweeps; dev fixed-5', size(yy, 1));
end

%% =====================================================================
%  windspeed: error per segment against the mean wind speed
%% =====================================================================
function [fh, msg] = fig_windspeed(opt)
Sc = p2_segset('circle_main', 'CapPerDay', 4, 'Quiet', true);
[Z1, c1] = p2r_load(opt.Root, 'gd6/d2_p2.mat');  [Z2, c2] = p2r_load(opt.Root, 'gd7/six-circle-h3.mat');
f1 = {Z1.rows.file}';  f2 = {Z2.rows.file}';
[f, i1, i2] = intersect(f1, f2, 'stable');
E1 = p2r_E(Z1, c1, {'L2', 'L3'});  E2 = p2r_E(Z2, c2, {'L3_iii0', 'H3'});
E = [E1(i1, :), E2(i2, :)];                              % one set: finite in the four columns
keep = all(isfinite(E), 2);
U = cellfun(@(x) Sc.U(strcmp(Sc.files, x)), f(keep));  E = 1000 * E(keep, :);
nm = {'MOBADC-W', 'PA-MOBADC', 'PAW-MOBADC', 'INDI-DE'};
fh = newfig(12.9, 6.3);
a = newax(fh, [1.2 0.95 5.3 4.3]);
for c = 1:4, binned(a, U, E(:, c), ctrl(nm{c})); end
set(a, 'YScale', 'log', 'YLim', [3 200], 'YTick', [5 10 20 50 100], 'YTickLabel', string([5 10 20 50 100]), ...
    'XLim', [0 8.5], 'YGrid', 'on', 'YMinorGrid', 'off');
xlabel(a, 'mean wind speed {\itU} (m s^{-1})');  ylabel(a, 'mean error per segment (mm)');
panel(a, 'a', sprintf('circle, development, %d segments', numel(U)));
% ---- hover ----
Sh = p2_segset('N6_hover', 'CapPerDay', 4, 'Quiet', true);
[Zh, ch] = p2r_load(opt.Root, 'gd7/static-hover.mat');
Eh = p2r_E(Zh, ch, {'L3', 'L3_iii0'});  fhv = {Zh.rows.file}';
tsat = p2r_p2(Zh, ch, {'L3'}, 'tilt_sat_frac');
kh = all(isfinite(Eh), 2);
Uh = cellfun(@(x) Sh.U(strcmp(Sh.files, x)), fhv(kh));  Eh = 1000 * Eh(kh, :);  sat = tsat(kh) >= 0.01;
b = newax(fh, [7.55 0.95 5.0 4.3]);
nh = {'PA-MOBADC', 'PAW-MOBADC'};
for c = 1:2, binned(b, Uh(~sat), Eh(~sat, c), ctrl(nh{c})); end
for c = 1:2
    plot(b, Uh(sat), Eh(sat, c), 'o', 'MarkerSize', 3, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', ctrl(nh{c}), ...
        'LineWidth', 0.5);
end
set(b, 'YScale', 'log', 'YLim', [0.3 400], 'YTick', [1 2 5 10 20 50 100 200], ...
    'YTickLabel', string([1 2 5 10 20 50 100 200]), 'XLim', [0 11], 'YGrid', 'on', 'YMinorGrid', 'off');
xlabel(b, 'mean wind speed {\itU} (m s^{-1})');
panel(b, 'b', sprintf('hover, development, %d segments', numel(Uh)));
text(b, 0.3, 300, sprintf('open: PA-MOBADC at its tilt clamp (%d)', sum(sat)), 'FontSize', 7, ...
    'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'top');
h = gobjects(1, 4);
for c = 1:4, h(c) = plot(a, NaN, NaN, 'o-', 'MarkerSize', 3.5, 'Color', ctrl(nm{c}), 'MarkerFaceColor', ctrl(nm{c}), 'LineWidth', 1); end
topleg(fh, h, nm);
msg = sprintf('circle %d, hover %d (%d at the tilt clamp)', numel(U), numel(Uh), sum(sat));
end

function binned(ax, U, y, col)
%BINNED  Segments as small dots; the median per wind-speed bin (equal counts, 8 bins) as a line.
plot(ax, U, y, 'o', 'MarkerSize', 2.0, 'MarkerFaceColor', mix(col, 0.45), 'MarkerEdgeColor', 'none');
[Us, o] = sort(U);  ys = y(o);  n = numel(Us);  nb = 8;  ed = round(linspace(0, n, nb + 1));
xm = nan(nb, 1);  ym = xm;
for k = 1:nb
    j = ed(k) + 1:ed(k + 1);
    xm(k) = median(Us(j));  ym(k) = median(ys(j));
end
plot(ax, xm, ym, '-', 'Color', col, 'LineWidth', 1.1);
plot(ax, xm, ym, 'o', 'MarkerSize', 3.2, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'w', 'LineWidth', 0.4);
end

%% =====================================================================
%  measure (Discussion): INDI-DE in hover and its accelerometer
%% =====================================================================
function [fh, msg] = fig_measure(opt)
ho = md_pooled(opt.P2, 'CONFIRM2 hover, one4 (n 56');
yh = 1000 * [ho('INDI-DE'), ho('INDI-DE (bias 0.086)'), ho('INDI-DE (bias 0.17)')];
ph = 1000 * [ho('PA-MOBADC'), ho('PAW-MOBADC')];
[Z, c] = p2r_load(opt.Root, 'gd7/static-indi-bias.mat');
E = p2r_E(Z, c, {'L3', 'L3_iii0', 'H3', 'H3_b086', 'H3_b170'});  k = all(isfinite(E), 2);
Pd = 1000 * sqrt(mean(E(k, :).^2, 1));
fh = newfig(8.4, 6.3);
a = newax(fh, [1.15 1.55 4.9 4.0]);
xb = [0 0.086 0.17];
plot(a, [0 0.17], ph(1) * [1 1], '-', 'Color', ctrl('PA-MOBADC'), 'LineWidth', 1.0);
plot(a, [0 0.17], ph(2) * [1 1], '-', 'Color', ctrl('PAW-MOBADC'), 'LineWidth', 1.0);
plot(a, [0 0.17], Pd(1) * [1 1], '--', 'Color', ctrl('PA-MOBADC'), 'LineWidth', 0.7);
plot(a, [0 0.17], Pd(2) * [1 1], '--', 'Color', ctrl('PAW-MOBADC'), 'LineWidth', 0.7);
plot(a, xb, yh, '-o', 'Color', ctrl('INDI-DE'), 'LineWidth', 1.0, 'MarkerSize', 4, 'MarkerFaceColor', ctrl('INDI-DE'), ...
    'MarkerEdgeColor', 'w');
plot(a, xb, Pd(3:5), '--o', 'Color', ctrl('INDI-DE'), 'LineWidth', 0.7, 'MarkerSize', 3.5, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', ctrl('INDI-DE'));
yl = [0 1.12 * max([yh Pd ph])];
set(a, 'XLim', [-0.008 0.178], 'XTick', xb, 'YLim', yl, 'XTickLabel', '');
undertick(a, xb, {'0', '0.086', '0.17'}, {'', '(0.5\circ)', '(1.0\circ)'});
xlabel(a, 'accelerometer bias (m s^{-2}), equivalent attitude error', 'Units', 'centimeters', ...
    'Position', [2.45 -0.85]);
ylabel(a, 'pooled error, hover (mm)');
lb = {'INDI-DE', 'PA-MOBADC', 'PAW-MOBADC'};  yy = [yh(3), ph(1), ph(2)];  cc = {ctrl('INDI-DE'), ctrl('PA-MOBADC'), ctrl('PAW-MOBADC')};
for i = 1:3, text(a, 0.181, yy(i), lb{i}, 'FontSize', 7, 'Color', cc{i}, 'Clipping', 'off'); end
hl = [plot(a, NaN, NaN, '-', 'Color', [0.2 0.2 0.2]), plot(a, NaN, NaN, '--', 'Color', [0.2 0.2 0.2])];
lg = legend(a, hl, {'held-out, 56 segments', sprintf('development, %d segments', sum(k))}, 'Box', 'off', ...
    'FontSize', 7, 'Location', 'northwest');
lg.ItemTokenSize = [14 8];
msg = sprintf('held-out one set 56; dev S40hover %d', sum(k));
end

%% =====================================================================
%  numbers from the generated documents
%% =====================================================================
function r = md_row(file, id)
%MD_ROW  The row `id` of a generated results table: value, SE (fractions), by-day median, n, days.
L = readlines(file);
k = find(startsWith(L, "| `" + id + "` |"), 1);
assert(~isempty(k), 'md_row: %s not in %s', id, file);
c = strtrim(split(L(k), '|'));
r.val = pct(c(4));  r.se = str2double(c(5)) / 100;  r.med = pct(c(7));
t = regexp(char(c(8)), '(\d+) \((\d+)\)', 'tokens', 'once');
r.n = str2double(t{1});  r.nd = str2double(t{2});
end

function v = pct(s)
v = str2double(regexprep(char(s), '[ %+]', '')) / 100;
end

function P = md_pooled(file, hdr)
%MD_POOLED  The "Pooled mean position error [m]" block whose header starts with HDR: column -> value [m].
L = readlines(file);
k = find(startsWith(L, "Pooled mean position error [m] - " + hdr), 1);
assert(~isempty(k), 'md_pooled: "%s" not in %s', hdr, file);
j = k + 1;
while ~startsWith(L(j), "|"), j = j + 1; end
nm = strtrim(split(L(j), '|'));  v = strtrim(split(L(j + 2), '|'));
P = containers.Map(cellstr(nm(2:end - 1)), num2cell(str2double(v(2:end - 1))));
end

function v = md_tab6(file, block)
%MD_TAB6  MOBADC-W, PA-MOBADC, PAW-MOBADC [m] of one block of Table 6 (ablation) of tables_p2.md.
L = readlines(file);
k = find(startsWith(L, "| " + block + " |"), 1);
assert(~isempty(k), 'md_tab6: %s not in %s', block, file);
c = strtrim(split(L(k), '|'));
v = str2double(c(4:6)).';
end

function v = md_tab5(file, name)
%MD_TAB5  Pooled mean [m] of one controller in Table 5 (main comparison, dev circle_main) of tables_p2.md.
L = readlines(file);
i0 = find(startsWith(L, "## Table 5"), 1);
k = i0 - 1 + find(startsWith(L(i0:end), "| " + name + " |"), 1);
c = strtrim(split(L(k), '|'));
t = regexp(char(c(3)), '^([0-9.]+)', 'tokens', 'once');
v = str2double(t{1});
end

%% =====================================================================
%  drawing
%% =====================================================================
function c = C(name)
switch name
    case 'dev',  c = [0.55 0.55 0.55];
    case 'held', c = [0.10 0.10 0.10];
end
end

function c = ctrl(name)
%CTRL  One colour per controller (Okabe-Ito): the chain MOBADC -> MOBADC-W -> PA-MOBADC in black and blues, the
%  proposed PAW-MOBADC the only warm colour, the acceleration-based comparison green.
switch regexprep(name, ' \(proposed\)$', '')
    case 'MOBADC',     c = [0.15 0.15 0.15];
    case 'MOBADC-W',   c = [0.34 0.71 0.91];
    case 'PA-MOBADC',  c = [0.00 0.45 0.70];
    case 'PAW-MOBADC', c = [0.84 0.37 0.00];
    case 'INDI-DE',    c = [0.00 0.62 0.45];
    otherwise,         c = [0.45 0.45 0.45];
end
end

function m = mix(c, w)
%MIX  The colour C lightened towards white (W = 0: C, W = 1: white).
m = c + (1 - c) * w;
end

function fh = newfig(w, h)
fh = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', 'Position', [2 2 w h], ...
    'PaperUnits', 'centimeters', 'PaperSize', [w h], 'PaperPosition', [0 0 w h], 'InvertHardcopy', 'off');
end

function ax = newax(fh, pos)
ax = axes('Parent', fh, 'Units', 'centimeters', 'Position', pos);
hold(ax, 'on');
set(ax, 'FontName', 'Arial', 'FontSize', 7.5, 'LineWidth', 0.5, 'TickDir', 'out', 'TickLength', [0.018 0.018], ...
    'Box', 'off', 'XColor', [0.2 0.2 0.2], 'YColor', [0.2 0.2 0.2], 'Layer', 'bottom', ...
    'GridColor', [0.90 0.90 0.90], 'GridAlpha', 1, 'LabelFontSizeMultiplier', 8 / 7.5, ...
    'XMinorTick', 'off', 'YMinorTick', 'off', 'TickLabelInterpreter', 'tex');
end

function panel(ax, letter, ttl, dx)
%PANEL  Panel letter (bold) and a few words above the top-left corner of the axes.
if nargin < 4, dx = 0.95; end
p = get(ax, 'Position');
text(ax, -dx / p(3), 1 + 0.22 / p(4), letter, 'Units', 'normalized', 'FontName', 'Arial', 'FontSize', 9, ...
    'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
if ~isempty(ttl)
    text(ax, (-dx + 0.32) / p(3), 1 + 0.22 / p(4), ttl, 'Units', 'normalized', 'FontName', 'Arial', ...
        'FontSize', 8, 'VerticalAlignment', 'bottom');
end
end

function topleg(fh, h, labels)
lg = legend(h, labels, 'Box', 'off', 'FontSize', 7.5, 'Orientation', 'horizontal', 'FontName', 'Arial');
lg.ItemTokenSize = [12 8];
lg.Units = 'centimeters';
fp = get(fh, 'Position');
lg.Position(1:2) = [(fp(3) - lg.Position(3)) / 2, fp(4) - lg.Position(4) - 0.05];
end

function s = num(v, fmt)
s = strrep(sprintf(fmt, v), '-', char(8722));
end

function s = numl(v)
s = arrayfun(@(x) num(x, '%g'), v, 'UniformOutput', false);
end

function t = ticks3(lim)
st = lim / 2;  t = [-lim -st 0 st lim];
end

function v = niceup(x)
c = [1 1.5 2 2.5 3 4 5 6 8 10];  e = 10 ^ floor(log10(x));
v = e * c(find(c * e >= x, 1));
end

function save_fig(fh, opt, stem)
set(findall(fh, '-property', 'FontName'), 'FontName', 'Arial');
if ~opt.Save, fprintf('    [view only] %s not written\n', stem); return; end
f = fullfile(opt.Out, stem);
labels(fh, [f '.labels.txt']);
exportgraphics(fh, [f '.pdf'], 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fh, [f '.png'], 'Resolution', 300, 'BackgroundColor', 'white');
fprintf('    wrote %s.pdf / .png\n', f);
end

function labels(fh, fn)
%LABELS  Every string the figure shows, one per line (read by tools/check_names.py).
S = {};
h = findall(fh, '-property', 'String');
for k = 1:numel(h)
    try, v = get(h(k), 'String'); catch, continue; end
    if isstring(v), v = cellstr(v); end
    S = [S; cellstr(v(:))]; %#ok<AGROW>
end
ax = findall(fh, 'Type', 'axes');
for k = 1:numel(ax)
    for pr = {'XTickLabel', 'YTickLabel'}
        try, S = [S; cellstr(get(ax(k), pr{1}))]; catch, end %#ok<AGROW>
    end
    for pr = {'Title', 'XLabel', 'YLabel'}
        try, S = [S; cellstr(get(get(ax(k), pr{1}), 'String'))]; catch, end %#ok<AGROW>
    end
end
fid = fopen(fn, 'w', 'n', 'UTF-8');
if fid < 0, return; end
fprintf(fid, '%s\n', S{:});
fclose(fid);
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
