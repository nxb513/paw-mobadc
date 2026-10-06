function C = conf2_claims(Z, varargin)
%CONF2_CLAIMS  REGISTER_P2 sec 60.3: the four CONFIRM2 claims from the saved rows, as registered.
%
%   C = conf2_claims(Z)                     % Z.D2, Z.circle, Z.hover, Z.hhover: struct('rows', .., 'key', ..)
%   C = conf2_claims(Z, 'Dir', 'wind_conf2')   % directory of the segment files (U, spike count of listed ones)
%   C = conf2_claims(Z, 'Dir', 'wind_conf3', 'Title', 'CONFIRM3 CLAIMS (REGISTER_FINAL sec 6.1)')
%                                           % the same claims on CONFIRM3 (rerun/confirm3_steps.m)
%
%  Z.D2     results/gd10/D2.mat           (columns L0 L2 L3 V)
%  Z.circle results/gd10/C2-circle.mat    (L3 L3_iii0 H3)          -> H-static-circle (L3, L3_iii0)
%  Z.hover  results/gd10/C2-hover.mat     (L3 L3_iii0 H3 H3_b...)  -> H-static (L3, L3_iii0)
%  Z.hhover results/gd10/C2-hhover.mat    (L3 P O O0)              -> H-hover (sec 26.3)
%  A missing field (empty) is reported as NOT RUN. Outcomes: CONFIRMED / NOT CONFIRMED / NOT CONFIRMABLE.
%
%  Common (sec 60.3): pooled = sqrt(mean(m_i^2)); SE = paired delete-one-day jackknife over the days of
%  the scored set; by-day median from each day's own pooled columns; LOO [min, max] and the most
%  influential segment beside. Data sufficiency on the scored set: >= 15 segments AND >= 6 days, else
%  NOT CONFIRMABLE (numbers printed).
%   D2              full one set (finite in L0 L2 L3 V); Delta = L3/L2 - 1;
%                   CONFIRMED <=> Delta <= -15 % AND Delta + 1.65 SE < 0
%   H-static(-circle) F = every row; n_unsafe (on F) = L3_iii0 not finite while L3 finite; A = L3 and
%                   L3_iii0 finite AND tilt_sat_frac < 1 % in the L3 column only; h = 1 - L3_iii0/L3 on A;
%                   CONFIRMED <=> by-day median >= 10 % AND h - 1.65 SE > 0 AND n_unsafe <= 1;
%                   beside: the same on the full one set, the L3-saturated segments listed
%   H-hover         one set (finite in L3 P O O0), unsaturated subset (tilt_sat_frac < 1 % in EVERY
%                   column, sec 26.3); h = 1 - O/L3; CONFIRMED <=> by-day median >= 10 % AND h - 1.65 SE > 0;
%                   beside: c, h_sensor, h_pred, (L3 - P)/L3, h on the full one set
opt = struct('Dir', '', 'Title', 'CONFIRM2 CLAIMS (REGISTER_P2 sec 60.3)');
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'conf2_claims: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
C = struct();
fprintf('\n%s\n  %s\n%s\n', repmat('=', 1, 80), opt.Title, repmat('=', 1, 80));
C.D2 = claim_d2(getz(Z, 'D2'));
C.H_static = claim_static(getz(Z, 'hover'), '2. H-static (hover set)', opt);
C.H_static_circle = claim_static(getz(Z, 'circle'), '3. H-static-circle (circle set, D22 post hoc)', opt);
C.H_hover = claim_hhover(getz(Z, 'hhover'));
fprintf('\n  SUMMARY\n');
for f = fieldnames(C)'
    fprintf('    %-16s %s\n', strrep(f{1}, '_', '-'), C.(f{1}).verdict);
end
end

%% ---------------------------------------------------------------------
function z = getz(Z, f)
z = [];
if isfield(Z, f) && ~isempty(Z.(f)), z = Z.(f); end
end

function [E, day, fl] = cols_of(z, names)
cols = {'L0', 'L2', 'L3', 'V'};                          % D2's key has no cols
if isfield(z.key, 'cols'), cols = z.key.cols; end
n = numel(z.rows);
E = nan(n, numel(names));
for c = 1:numel(names)
    j = find(strcmp(cols, names{c}), 1);
    assert(~isempty(j), 'conf2_claims: column %s missing.', names{c});
    for i = 1:n, E(i, c) = z.rows(i).E(j); end
end
day = {z.rows.day}';  fl = {z.rows.file}';
end

function T = tilt_of(z, names)
cols = z.key.cols;
n = numel(z.rows);
T = nan(n, numel(names));
for c = 1:numel(names)
    j = find(strcmp(cols, names{c}), 1);
    for i = 1:n, T(i, c) = z.rows(i).Q(7, j); end
end
end

function s = verdict_suff(n, nd)
s = n >= 15 && nd >= 6;
end

%% ---------------------------------------------------------------------
function R = claim_d2(z)
fprintf('\n  1. D2 (circle set, full one set): Delta = pooled(L3)/pooled(L2) - 1\n');
R = struct('verdict', 'NOT RUN');
if isempty(z), fprintf('     not run\n'); return; end
[E, day, fl] = cols_of(z, {'L0', 'L2', 'L3', 'V'});
ok = all(isfinite(E), 2);
list_removed(z, ok);
s = stat(@(p) p(3) / p(2) - 1, E(ok, :), day(ok), fl(ok), 'Delta = L3/L2 - 1');
R = res(s, sum(ok), numel(unique(day(ok))));
P = sqrt(mean(E(ok, :).^2, 1));
fprintf('     pooled L0 %.5f  L2 %.5f  L3 %.5f  V %.5f\n', P);
if ~verdict_suff(R.n, R.n_days)
    R.verdict = 'NOT CONFIRMABLE';
else
    t1 = s.val <= -0.15;  t2 = s.val + 1.65 * s.se < 0;
    fprintf('     Delta <= -15 %%: %s;  Delta + 1.65 SE = %+.2f %% < 0: %s\n', yn(t1), 100 * (s.val + 1.65 * s.se), yn(t2));
    R.verdict = tern(t1 && t2, 'CONFIRMED', 'NOT CONFIRMED');
end
fprintf('     n %d, days %d -> D2: %s\n', R.n, R.n_days, R.verdict);
end

function R = claim_static(z, label, opt)
fprintf('\n  %s: h = 1 - pooled_A(L3_iii0)/pooled_A(L3)\n', label);
R = struct('verdict', 'NOT RUN');
if isempty(z), fprintf('     not run\n'); return; end
[E, day, fl] = cols_of(z, {'L3', 'L3_iii0'});
T = tilt_of(z, {'L3'});
fin = all(isfinite(E), 2);
unsafe = isfinite(E(:, 1)) & ~isfinite(E(:, 2));
A = fin & T < 0.01;                                     % NaN tilt -> not in A
nF = numel(fin);
fprintf('     full set F: %d segments, %d days; one set (L3, L3_iii0 finite): %d\n', nF, numel(unique(day)), sum(fin));
fprintf('     n_unsafe (L3_iii0 not finite while L3 finite, counted on F): %d\n', sum(unsafe));
j = find(strcmp(z.key.cols, 'L3_iii0'), 1);
for i = find(unsafe)'
    [U, ns, nj] = seg_info(fl{i}, opt);
    fprintf('       UNSAFE %-28s %-10s flag %-9s U %6.2f  spikes %d / jumps %d  (L3 %.4f)\n', fl{i}, day{i}, ...
        z.rows(i).F{j}, U, ns, nj, E(i, 1));
end
for i = find(~fin & ~unsafe)'
    fl2 = z.rows(i).F;  fl2 = fl2(~cellfun(@isempty, fl2));
    fprintf('       not finite in L3 (not in A, not unsafe) %-28s %s\n', fl{i}, strjoin(fl2, ','));
end
for i = find(fin & ~A)'
    fprintf('       L3-saturated / no tilt (not in A) %-28s tilt_sat(L3) %.4f  L3 %.4f  L3_iii0 %.4f\n', fl{i}, T(i), E(i, :));
end
f = @(p) 1 - p(2) / p(1);
fprintf('     scoring subset A (tilt_sat_frac < 1 %% in L3 only): %d segments, %d days\n', sum(A), numel(unique(day(A))));
if sum(A) >= 1
    s = stat(f, E(A, :), day(A), fl(A), 'h on A');
else
    s = struct('val', NaN, 'se', NaN, 'loo', NaN, 'day_median', NaN, 'most_influential', '');
end
R = res(s, sum(A), numel(unique(day(A))));
R.n_unsafe = sum(unsafe);  R.unsafe = fl(unsafe);
if sum(fin) >= 1
    R.full = stat(f, E(fin, :), day(fin), fl(fin), 'beside: h on the full one set');
end
if ~verdict_suff(R.n, R.n_days)
    R.verdict = 'NOT CONFIRMABLE';
else
    t1 = s.day_median >= 0.10;  t2 = s.val - 1.65 * s.se > 0;  t3 = R.n_unsafe <= 1;
    fprintf('     by-day median >= 10 %%: %s;  h - 1.65 SE = %+.2f %% > 0: %s;  n_unsafe <= 1: %s\n', yn(t1), ...
        100 * (s.val - 1.65 * s.se), yn(t2), yn(t3));
    R.verdict = tern(t1 && t2 && t3, 'CONFIRMED', 'NOT CONFIRMED');
end
fprintf('     -> %s: %s\n', label, R.verdict);
end

function R = claim_hhover(z)
fprintf('\n  4. H-hover (sec 26.3): h = 1 - pooled(O)/pooled(L3) on the unsaturated subset (every column)\n');
R = struct('verdict', 'NOT RUN');
if isempty(z), fprintf('     not run\n'); return; end
c = {'L3', 'P', 'O', 'O0'};
[E, day, fl] = cols_of(z, c);
T = tilt_of(z, c);
ok = all(isfinite(E), 2);
list_removed(z, ok);
U = ok & all(T < 0.01, 2);
fprintf('     one set %d of %d; unsaturated subset %d segments, %d days\n', sum(ok), numel(ok), sum(U), ...
    numel(unique(day(U))));
for i = find(ok & ~U)'
    fprintf('       saturated (not scored) %-28s max tilt_sat %.4f\n', fl{i}, max(T(i, :)));
end
s = struct('val', NaN, 'se', NaN, 'loo', NaN, 'day_median', NaN, 'most_influential', '');
B = struct();
if sum(U) >= 1
    fprintf('     pooled on the subset: L3 %.5f  P %.5f  O %.5f  O0 %.5f [m]\n', sqrt(mean(E(U, :).^2, 1)));
    s = stat(@(p) 1 - p(3) / p(1), E(U, :), day(U), fl(U), 'h = 1 - O/L3');
    B.c = stat(@(p) (p(1) - p(2)) / (p(1) - p(3)), E(U, :), day(U), fl(U), 'beside: c = (L3 - P)/(L3 - O)');
    B.h_sensor = stat(@(p) 1 - p(4) / p(1), E(U, :), day(U), fl(U), 'beside: h_sensor = 1 - O0/L3');
    B.h_pred = stat(@(p) 1 - p(3) / p(4), E(U, :), day(U), fl(U), 'beside: h_pred = 1 - O/O0');
    B.gap_rel = stat(@(p) (p(1) - p(2)) / p(1), E(U, :), day(U), fl(U), 'beside: (L3 - P)/L3');
end
if sum(ok) >= 1
    B.full = stat(@(p) 1 - p(3) / p(1), E(ok, :), day(ok), fl(ok), 'beside: h on the full one set');
end
R = merge(res(s, sum(U), numel(unique(day(U)))), B);
if ~verdict_suff(R.n, R.n_days)
    R.verdict = 'NOT CONFIRMABLE';
else
    t1 = s.day_median >= 0.10;  t2 = s.val - 1.65 * s.se > 0;
    fprintf('     by-day median >= 10 %%: %s;  h - 1.65 SE = %+.2f %% > 0: %s\n', yn(t1), 100 * (s.val - 1.65 * s.se), yn(t2));
    R.verdict = tern(t1 && t2, 'CONFIRMED', 'NOT CONFIRMED');
end
fprintf('     -> H-hover: %s\n', R.verdict);
end

%% ---------------------------------------------------------------------
function R = res(s, n, nd)
R = struct('verdict', '', 'n', n, 'n_days', nd, 'val', s.val, 'se', s.se, 'day_median', s.day_median, ...
    'loo', [min(s.loo), max(s.loo)], 'most_influential', s.most_influential);
if ~verdict_suff(n, nd)
    fprintf('     data sufficiency: %d segments, %d days (< 15 or < 6) -> NOT CONFIRMABLE (numbers printed)\n', n, nd);
end
end

function R = merge(R, B)
for f = fieldnames(B)'
    if ~strcmp(f{1}, 'verdict'), R.(f{1}) = B.(f{1}); end
end
end

function list_removed(z, ok)
for i = find(~ok)'
    fl = z.rows(i).F;  fl = fl(~cellfun(@isempty, fl));
    fprintf('       removed (one-set rule) %-28s %s\n', z.rows(i).file, strjoin(fl, ','));
end
end

function s = stat(f, E, day, fl, label)
%STAT  pooled value, SE (paired delete-one-day jackknife), by-day median, LOO, most influential (sec 0.2).
pool = @(e) sqrt(mean(e.^2, 1));
n = size(E, 1);
s = struct('label', label, 'val', f(pool(E)));
loo = nan(n, 1);
for i = 1:n
    if n > 1, loo(i) = f(pool(E([1:i-1, i+1:n], :))); end
end
ud = unique(day);  nd = numel(ud);  jd = nan(nd, 1);  dd = nan(nd, 1);
for j = 1:nd
    m = strcmp(day, ud{j});
    if nd > 1, jd(j) = f(pool(E(~m, :))); end
    dd(j) = f(pool(E(m, :)));
end
s.se = NaN;
if nd > 1, s.se = sqrt((nd - 1) / nd * sum((jd - mean(jd)).^2)); end
s.day_median = median(dd);
s.loo = loo;
s.most_influential = fl{1};
if n > 1
    [~, iw] = max(abs(loo - s.val));
    s.most_influential = fl{iw};
else
    s.loo = s.val;
end
fprintf('     %-32s %+8.2f %%  SE %.2f  LOO [%+.2f, %+.2f] %%  by-day median %+.2f %%  most influential %s\n', ...
    label, 100 * s.val, 100 * s.se, 100 * min(s.loo), 100 * max(s.loo), 100 * s.day_median, s.most_influential);
end

function [U, ns, nj] = seg_info(fn, opt)
%SEG_INFO  U (as p2_segset) and the P-QA spike / jump counts (sec 36 rule, analysis/pqa_spikes.m) of a segment.
ff = fn;
if ~isempty(opt.Dir), ff = fullfile(opt.Dir, fn); end
U = NaN;  ns = -1;  nj = -1;
if exist(ff, 'file') ~= 2, return; end
Z = load(ff, 't_plant', 'w_plant');
t = double(Z.t_plant(:));  w = double(Z.w_plant(:, 1:2));
U = norm(mean(w(t >= 140, :), 1));
n = size(w, 1);  ns = 0;  nj = 0;  j = 2;
while j <= n
    d = norm(w(j, :) - w(j - 1, :));
    if d >= 5
        nj = nj + 1;  ret = 0;
        for k = 1:2
            if j + k <= n && norm(w(j + k, :) - w(j - 1, :)) <= 0.5 * d, ret = k; break; end
        end
        if ret > 0, ns = ns + 1;  j = j + ret + 1;  continue; end
    end
    j = j + 1;
end
end

function s = yn(c)
s = tern(c, 'yes', 'NO');
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
