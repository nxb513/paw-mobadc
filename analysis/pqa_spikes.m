function K = pqa_spikes(varargin)
%PQA_SPIKES  REGISTER_P2 sec 36: are the class-I steps of P-QA (sec 35) single-sample spikes of the
%sonic record or real gusts? Offline, no simulation; changes nothing, re-runs nothing.
%
%   K = pqa_spikes                 % the registered population (471 segments), reading, and - only
%                                  % if SENSOR SPIKES - the POST HOC sensitivity from saved results
%   K = pqa_spikes('Files', {...}, 'Results', dir)   % tests only
%
%  jump at sample j: d_j = |w(j) - w(j-1)| >= 5 m/s (horizontal, w_plant, whole 0-200 s);
%  spike = a jump with min_{k=1,2} |w(j+k) - w(j-1)| <= 0.5 d_j (its return is not a new jump);
%  raw M5 file = one (real_file, real_height_m) pair, seen through its exported windows.
%  A = spikes / jumps; C = (fewest raw files holding >= 80 % of spikes) / (raw files).
%  Reading: A >= 0.8 & C <= 0.05 -> SENSOR SPIKES; A < 0.5 | C > 0.2 -> REAL GUSTS; else UNCLEAR.
opt = struct('Files', {{}}, 'Results', '', 'Jump', 5, 'Ret', 0.5, 'Share', 0.8, 'Save', true, ...
    'Twelve', {{'wind_real_t150_i0060.mat', 'wind_expl_t150_i0127.mat', 'wind_expl_t150_i0130.mat', ...
    'wind_expl_t150_i0131.mat', 'wind_expl_t150_i0132.mat', 'wind_expl_t150_i0288.mat', ...
    'wind_expl_t150_i0289.mat', 'wind_expl_t150_i0290.mat', 'wind_expl_t150_i0291.mat', ...
    'wind_expl_t150_i0292.mat', 'wind_expl_t150_i0293.mat', 'wind_expl_t150_i0402.mat'}});
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'pqa_spikes: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
setup_path();
[st, gh] = system('git rev-parse --short HEAD');  if st ~= 0, gh = 'unknown'; end
if isempty(opt.Results), opt.Results = fullfile(repo_root(), 'results'); end
files = opt.Files;
if isempty(files), files = population(); end
n = numel(files);
fprintf('\npqa_spikes | git %s | REGISTER_P2 sec 36 | %d segments | jump >= %g m/s, return <= %g x jump in 1-2 samples\n', ...
    strtrim(gh), n, opt.Jump, opt.Ret);
S = struct('file', files(:), 'raw', '', 'height', NaN, 'day', '', 'offset', NaN, 'dur', NaN, ...
    'n_spike', 0, 'n_jump', 0, 't_spike', []);
for i = 1:n, S(i) = one_segment(files{i}, opt); end
% ---- the 12 segments of sec 35 ----
fprintf('\n  the 12 segments with events > T_norm (sec 35):\n  %-26s %-24s %6s %-10s %6s %6s %6s\n', 'segment', ...
    'real_file', 'h [m]', 'day', 'offset', 'spikes', 'jumps');
for f = opt.Twelve
    i = find(strcmp({S.file}, f{1}), 1);
    if isempty(i), fprintf('  %-26s not in the population\n', f{1}); continue; end
    fprintf('  %-26s %-24s %6.0f %-10s %6.0f %6d %6d\n', S(i).file, S(i).raw, S(i).height, S(i).day, ...
        S(i).offset, S(i).n_spike, S(i).n_jump);
end
% ---- per raw file ----
key = arrayfun(@(s) sprintf('%s|%g', s.raw, s.height), S, 'UniformOutput', false);
[uk, ~, g] = unique(key);
nf = numel(uk);
R = struct('key', uk(:), 'n_seg', 0, 'cov_s', 0, 'spikes', 0, 'jumps', 0, 'rate_h', 0, 'twelve', false);
for k = 1:nf
    m = g == k;
    R(k).n_seg = sum(m);  R(k).cov_s = sum([S(m).dur]);
    R(k).spikes = sum([S(m).n_spike]);  R(k).jumps = sum([S(m).n_jump]);
    R(k).rate_h = 3600 * R(k).spikes / R(k).cov_s;
    R(k).twelve = any(ismember({S(m).file}, opt.Twelve));
end
[~, o] = sort([R.spikes], 'descend');
fprintf('\n  raw M5 files (real_file | height): %d, coverage %.1f h in total\n', nf, sum([R.cov_s]) / 3600);
fprintf('  the %d with most spikes:\n  %-4s %-32s %5s %8s %7s %6s %9s  %s\n', min(20, nf), '#', 'raw file', 'segs', ...
    'cover s', 'spikes', 'jumps', 'spikes/h', '');
for r = 1:min(20, nf)
    q = R(o(r));
    fprintf('  %-4d %-32s %5d %8.0f %7d %6d %9.1f  %s\n', r, q.key, q.n_seg, q.cov_s, q.spikes, q.jumps, q.rate_h, ...
        tern(q.twelve, '<- holds one of the 12', ''));
end
rt = [R.rate_h];
fprintf('  spikes per hour over the raw files: p50 %.2f  p90 %.2f  p99 %.2f  max %.2f; files with >= 1 spike: %d of %d\n', ...
    pct(rt, 50), pct(rt, 90), pct(rt, 99), max(rt), sum([R.spikes] > 0), nf);
rank = zeros(1, nf);  rank(o) = 1:nf;
tw = find([R.twelve]);
fprintf('  rank (by spikes) of the raw files holding the 12: %s\n', mat2str(sort(rank(tw))));
% ---- A, C and the reading ----
ns = sum([S.n_spike]);  nj = sum([S.n_jump]);
A = ns / max(nj, 1);
cs = cumsum(sort([R.spikes], 'descend'));
nC = find(cs >= opt.Share * ns, 1);
if isempty(nC) || ns == 0, nC = NaN; end
C = nC / nf;
fprintf('\n  jumps >= %g m/s: %d; spikes: %d; non-spike jumps: %d; spiked segments: %d of %d\n', opt.Jump, nj, ...
    ns, nj - ns, sum([S.n_spike] > 0), n);
fprintf('  A = spikes / jumps = %.3f;  C = %d of %d raw files hold >= %.0f %% of the spikes = %.3f\n', A, nC, nf, ...
    100 * opt.Share, C);
if nj == 0
    v = 'NO JUMP >= 5 m/s - nothing to classify; reported to the user';
elseif A >= 0.8 && C <= 0.05
    v = 'SENSOR SPIKES (sonic-anemometer spikes; a data limitation)';
elseif A < 0.5 || C > 0.2
    v = 'REAL GUSTS';
else
    v = 'UNCLEAR - reported to the user, who decides';
end
fprintf('\n  READING (REGISTER_P2 sec 36): %s\n', v);
K = struct('seg', S, 'raw', R, 'A', A, 'C', C, 'nC', nC, 'n_spike', ns, 'n_jump', nj, 'reading', v, ...
    'git', strtrim(gh));
% ---- POST HOC sensitivity, only if SENSOR SPIKES ----
if strncmp(v, 'SENSOR SPIKES', 13)
    spiked = {S([S.n_spike] > 0).file};
    fprintf('\n  POST HOC sensitivity (sec 36; not a gate; no re-run) - without the %d spiked segments\n', numel(spiked));
    K.posthoc = posthoc(opt.Results, spiked);
end
if opt.Save
    outd = fullfile(opt.Results, 'pqa');
    if ~exist(outd, 'dir'), mkdir(outd); end
    stamp = datestr(now, 'yyyymmdd_HHMMSS');
    save(fullfile(outd, ['pqa_spikes_' stamp '.mat']), 'K');
    fprintf('  saved results/pqa/pqa_spikes_%s.mat\n', stamp);
end
end

%% ---------------------------------------------------------------------
function files = population()
%POPULATION  As p_qa (REGISTER_P2 sec 21): field_grid_K050's 30 + the exploration manifest.
Z = load('field_grid_K050.mat', 'T');
man = jsondecode(fileread('wind_expl_t150_batch.json'));
f2 = man.files(:);  if ~iscell(f2), f2 = cellstr(f2); end
f1 = Z.T.file(:);
assert(numel(f1) == 30 && all(startsWith(f1, 'wind_real_t150_i')), 'pqa_spikes: field_grid part is not the registered 30.');
assert(all(startsWith(f2, 'wind_expl_t150_i')), 'pqa_spikes: manifest lists a file outside the exploration export.');
files = [f1; f2];
assert(numel(files) == 471, 'pqa_spikes: population has %d segments, registered 471.', numel(files));
end

function s = one_segment(fn, opt)
Z = load(fn, 't_plant', 'w_plant', 'real_file', 'real_height_m', 'real_offset_s');
w = double(Z.w_plant(:, 1:2));  t = double(Z.t_plant(:));  n = size(w, 1);
rf = strtrim(char(Z.real_file));
s = struct('file', fn, 'raw', rf, 'height', double(Z.real_height_m), 'day', [rf(7:10) '-' rf(1:2) '-' rf(4:5)], ...
    'offset', double(Z.real_offset_s), 'dur', t(end) - t(1) + (t(2) - t(1)), 'n_spike', 0, 'n_jump', 0, ...
    't_spike', []);
j = 2;
while j <= n
    d = norm(w(j, :) - w(j - 1, :));
    if d >= opt.Jump
        s.n_jump = s.n_jump + 1;
        ret = 0;
        for k = 1:2
            if j + k <= n && norm(w(j + k, :) - w(j - 1, :)) <= opt.Ret * d, ret = k; break; end
        end
        if ret > 0
            s.n_spike = s.n_spike + 1;  s.t_spike(end + 1) = t(j);
            j = j + ret + 1;                              % the returning step is not a new jump
            continue
        end
    end
    j = j + 1;
end
end

function P = posthoc(rd, spiked)
%POSTHOC  REGISTER_P2 sec 36: D2, T3b and N6 h_model on the saved results, with and without the
%  spiked segments; statistics as sec 0.2 (day jackknife SE, LOO, by-day median).
P = struct();
rat = @(a, b) @(e) sqrt(mean(e(:, a).^2)) / sqrt(mean(e(:, b).^2)) - 1;
hm = @(a, b) @(e) 1 - sqrt(mean(e(:, a).^2)) / sqrt(mean(e(:, b).^2));
Q = {'D2 (circle_main)', fullfile(rd, 'gd6', 'd2_p2.mat'), {'L0', 'L2', 'L3', 'V'}, ...
        {'L3/L2 - 1', rat(3, 2)}, false; ...
     'T3b table', fullfile(rd, 'gd6', 'tab_T3b_p2.mat'), {'L0', 'L2', 'L3', 'V'}, ...
        {'L3/L2 - 1', rat(3, 2); 'V/L2 - 1', rat(4, 2)}, false; ...
     'N6 (group #10, hover)', fullfile(rd, 'gd7', 'N6.mat'), {}, {'h_model = 1 - L3_6/L3', []}, true};
for q = 1:size(Q, 1)
    fprintf('\n  -- %s: %s\n', Q{q, 1}, Q{q, 2});
    if exist(Q{q, 2}, 'file') ~= 2, fprintf('     not found - skipped\n'); continue; end
    Z = load(Q{q, 2});
    rows = Z.rows;  cols = Q{q, 3};
    if isempty(cols), cols = Z.key.cols; end
    nc = numel(cols);
    E = reshape([rows.E], nc, []).';
    ok = all(isfinite(E), 2);
    fs = Q{q, 4};
    if Q{q, 5}                                        % N6: h_model on the one set and the unsaturated subset
        fs{1, 2} = hm(find(strcmp(cols, 'L3_6')), find(strcmp(cols, 'L3')));
        ts = nan(numel(rows), nc);
        for i = 1:numel(rows)
            for c = 1:nc
                p = rows(i).p2{c};
                if isstruct(p) && isfield(p, 'tilt_sat_frac'), ts(i, c) = p.tilt_sat_frac; end
            end
        end
        sets = {'one set', ok; 'unsaturated subset', ok & all(ts < 0.01, 2)};
    else
        sets = {'one set', ok};
    end
    drop = ismember({rows.file}', spiked);
    for s = 1:size(sets, 1)
        for r = 1:size(fs, 1)
            for w = 1:2
                m = sets{s, 2};
                if w == 2, m = m & ~drop; end
                lab = sprintf('%s, %s%s', fs{r, 1}, sets{s, 1}, tern(w == 2, ' WITHOUT spiked', ' (as registered)'));
                P.(sprintf('q%d_s%d_r%d_w%d', q, s, r, w)) = stat(fs{r, 2}, E(m, :), {rows(m).day}', {rows(m).file}', lab);
            end
        end
    end
    fprintf('     spiked segments in this set: %d (%s)\n', sum(ok & drop), strjoin({rows(ok & drop).file}, ', '));
end
end

function s = stat(f, E, day, fl, label)
n = size(E, 1);
s = struct('label', label, 'n', n, 'n_days', numel(unique(day)), 'val', NaN);
if n < 2, fprintf('     %-58s n %d - not computed\n', label, n); return; end
s.val = f(E);
loo = nan(n, 1);
for i = 1:n, loo(i) = f(E([1:i-1, i+1:n], :)); end
ud = unique(day);  nd = numel(ud);  jd = nan(nd, 1);  dd = nan(nd, 1);
for j = 1:nd
    m = strcmp(day, ud{j});
    if nd > 1, jd(j) = f(E(~m, :)); end
    dd(j) = f(E(m, :));
end
s.se = sqrt((nd - 1) / nd * sum((jd - mean(jd)).^2));
s.loo = [min(loo), max(loo)];  s.day_median = median(dd);
[~, iw] = max(abs(loo - s.val));  s.most_influential = fl{iw};
fprintf('     %-58s n %3d (%2d d)  %+7.2f %%  SE %.2f  LOO [%+.2f, %+.2f]  by-day %+.2f  %s\n', label, n, ...
    s.n_days, 100 * s.val, 100 * s.se, 100 * s.loo, 100 * s.day_median, s.most_influential);
end

function v = pct(x, p)
x = sort(x(:));  n = numel(x);
if n == 0, v = NaN; return; end
r = n * p / 100 + 0.5;
if r <= 1, v = x(1); elseif r >= n, v = x(n); else, lo = floor(r); v = x(lo) + (r - lo) * (x(lo + 1) - x(lo)); end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
