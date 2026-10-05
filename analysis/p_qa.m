function Q = p_qa(varargin)
%P_QA  Checkpoint P-QA (REGISTER_P2 sec 21): quality of the exported PI-MoE series w_hat on every
%segment exported for P2. Offline, no simulation.
%
%   Q = p_qa                      % the registered population: 30 field_grid + 441 exploration
%   Q = p_qa('Files', {...})      % other files (tests only)
%
%  Quantities at the 20 Hz prediction samples t_k (horizontal norm, as A4 of sec 18.1):
%     dwh_k = |w_hat(t_k) - w_hat(t_{k-1})|, dw_k (w_plant), dm_k (w_meas, the predictor's input)
%  Thresholds (fixed in sec 21): T_norm = 5.139 m/s; T_phys = p99.9 of dw pooled over every
%  prediction sample of every segment; T_in = p99.9 of dm pooled likewise.
%  Every event dwh_k > T_phys is listed (CSV) with its location - d_start (t_k - t_valid_from),
%  d_end (t_end - t_k), d_file (distance to the raw 600 s M5 file's edges), held input (>= 3
%  identical consecutive w_meas samples, all channels, inside [t_k - window_s, t_k]), input step
%  at entry (max dm over t_k +- 1 sample) and at exit (max dm over t_k - window_s +- 1 sample) -
%  and its class: B (d_start, d_end or d_file <= 1 s, or held input), I (not B and an entry or
%  exit step > T_in), U (otherwise).
%  Reading (sec 21), on the events dwh > T_norm: B share >= 50 % -> EXPORT ERROR; otherwise
%  I share >= 50 % -> PI-MoE PROPERTY; otherwise NEITHER. Shares for dwh > T_phys: reported.
%  Output: results/pqa/p_qa_<stamp>.mat, p_qa_events_<stamp>.csv (every event > T_phys) and
%  p_qa_segments_<stamp>.csv (per-segment quantiles; the pooled ones are printed).
opt = struct('Files', {{}}, 'TNorm', 5.139, 'FileLen', 600, 'Edge', 1, 'Held', 3, ...
             'Diverging', {{'wind_expl_t150_i0290.mat', 'wind_expl_t150_i0293.mat'}}, 'Save', true);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'p_qa: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
setup_path();
[st, gh] = system('git rev-parse --short HEAD');  if st ~= 0, gh = 'unknown'; end
files = opt.Files;
if isempty(files), files = population(); end
n = numel(files);
fprintf('\np_qa | git %s | REGISTER_P2 sec 21 | %d segments\n', strtrim(gh), n);
S = cell(n, 1);
for i = 1:n, S{i} = one_segment(files{i}, opt); end
% ---- thresholds (computed first, then used unchanged) ----
all_dw = cell2mat(cellfun(@(s) s.dw, S, 'UniformOutput', false));
all_dm = cell2mat(cellfun(@(s) s.dm, S, 'UniformOutput', false));
all_dwh = cell2mat(cellfun(@(s) s.dwh, S, 'UniformOutput', false));
T = struct('norm', opt.TNorm, 'phys', pct(all_dw, 99.9), 'in', pct(all_dm, 99.9));
fprintf('  thresholds: T_norm %.3f m/s (literal) | T_phys = p99.9(dw) %.4f m/s | T_in = p99.9(dm) %.4f m/s\n', ...
    T.norm, T.phys, T.in);
fprintf('  (over %d prediction samples of %d segments)\n', numel(all_dw), n);
% ---- distributions ----
qs = [50 90 99 99.9];
fprintf('\n  pooled quantiles [m/s]      p50      p90      p99    p99.9      max\n');
row = @(nm, x) fprintf('  %-22s %8.4f %8.4f %8.4f %8.4f %8.4f\n', nm, pct(x, qs(1)), pct(x, qs(2)), ...
    pct(x, qs(3)), pct(x, qs(4)), max(x));
row('dw_hat (prediction)', all_dwh);  row('dw (true wind)', all_dw);  row('dm (measured input)', all_dm);
fprintf('  %-22s', 'ratio dw_hat / dw');
for q = qs, fprintf(' %8.3f', pct(all_dwh, q) / pct(all_dw, q)); end
fprintf(' %8.3f\n', max(all_dwh) / max(all_dw));
% per segment (saved, not printed): [dw_hat dw dm] x [p50 p90 p99 p99.9 max]
qx = @(x) [pct(x, qs), max(x)];
PS = cell2mat(cellfun(@(s) [qx(s.dwh), qx(s.dw), qx(s.dm)], S, 'UniformOutput', false));
% ---- events and classes ----
E = struct('file', {}, 't', {}, 'dwh', {}, 'gt_norm', {}, 'd_start', {}, 'd_end', {}, 'd_file', {}, ...
    'held', {}, 'entry', {}, 'exit', {}, 'cls', {});
nB = 0;  nAll = 0;
for i = 1:n
    s = S{i};
    inB = s.d_start <= opt.Edge | s.d_end <= opt.Edge | s.d_file <= opt.Edge | s.held;
    nB = nB + sum(inB);  nAll = nAll + numel(inB);
    for k = find(s.dwh > T.phys)'
        if inB(k), c = 'B';
        elseif s.entry(k) > T.in || s.exit(k) > T.in, c = 'I';
        else, c = 'U';
        end
        E(end + 1) = struct('file', s.file, 't', s.t(k), 'dwh', s.dwh(k), 'gt_norm', s.dwh(k) > T.norm, ...
            'd_start', s.d_start(k), 'd_end', s.d_end(k), 'd_file', s.d_file(k), 'held', s.held(k), ...
            'entry', s.entry(k), 'exit', s.exit(k), 'cls', c); %#ok<AGROW>
    end
end
rho = spearman(all_dwh, cell2mat(cellfun(@(s) s.entry, S, 'UniformOutput', false)));
fprintf('\n  base rate: %.2f %% of all prediction samples lie in a B zone\n', 100 * nB / nAll);
fprintf('  Spearman correlation dw_hat vs entry input step (all samples): %.3f\n', rho);
share = @(m) struct('n', sum(m), 'B', mean([E(m).cls] == 'B'), 'I', mean([E(m).cls] == 'I'), ...
    'U', mean([E(m).cls] == 'U'));
mP = true(1, numel(E));  mN = [E.gt_norm];
if isempty(E), mN = false(1, 0); end
sP = share(mP);  sN = share(mN);
fprintf('\n  events dw_hat > T_phys: %d in %d segments | B %.1f %%  I %.1f %%  U %.1f %%  (reported, not read)\n', ...
    sP.n, numel(unique({E.file})), 100 * sP.B, 100 * sP.I, 100 * sP.U);
fprintf('  events dw_hat > T_norm: %d in %d segments | B %.1f %%  I %.1f %%  U %.1f %%\n', sN.n, ...
    numel(unique({E(mN).file})), 100 * sN.B, 100 * sN.I, 100 * sN.U);
fprintf('\n  events > T_norm (all listed):\n  %-26s %8s %8s %8s %8s %8s %5s %8s %8s %s\n', 'segment', 't [s]', ...
    'dw_hat', 'd_start', 'd_end', 'd_file', 'held', 'entry', 'exit', 'class');
for e = E(mN)
    fprintf('  %-26s %8.2f %8.3f %8.2f %8.2f %8.2f %5d %8.3f %8.3f %s\n', e.file, e.t, e.dwh, e.d_start, ...
        e.d_end, e.d_file, e.held, e.entry, e.exit, e.cls);
end
fprintf('\n  the diverging segments (column P, sec 20) - every event > T_phys:\n');
for f = opt.Diverging
    m = strcmp({E.file}, f{1});
    if ~any(strcmp(files, f{1})), fprintf('    %s: not in the population\n', f{1}); continue; end
    fprintf('    %s: %d event(s)%s\n', f{1}, sum(m), tern(any(m), sprintf(', classes %s, max dw_hat %.3f m/s', ...
        [E(m).cls], max([E(m).dwh])), ''));
end
% ---- reading (sec 21) ----
if sN.n == 0
    v = 'NO EVENT > T_norm - the reading has nothing to classify; reported to the user';
elseif sN.B >= 0.5
    v = 'EXPORT ERROR (B share >= 50 %) -> fix the export, re-export w_hat, re-run column P of every group';
elseif sN.I >= 0.5
    v = 'PI-MoE PROPERTY (I share >= 50 %) - out-of-distribution response to noisy input; into the paper';
else
    v = 'NEITHER (large jumps neither at boundaries nor on input noise) - reported to the user';
end
fprintf('\n  READING (REGISTER_P2 sec 21, events > T_norm): %s\n', v);
Q = struct('T', T, 'events', E, 'share_phys', sP, 'share_norm', sN, 'base_rate', nB / nAll, 'rho', rho, ...
    'verdict', v, 'n_seg', n, 'git', strtrim(gh));
Q.per_seg = struct('file', {files(:)}, 'cols', {{'dwh', 'dw', 'dm'}}, 'q', qs, 'val', PS);
if opt.Save
    outd = fullfile(repo_root(), 'results', 'pqa');
    if ~exist(outd, 'dir'), mkdir(outd); end
    stamp = datestr(now, 'yyyymmdd_HHMMSS');
    save(fullfile(outd, ['p_qa_' stamp '.mat']), 'Q');
    fid = fopen(fullfile(outd, ['p_qa_events_' stamp '.csv']), 'w');
    fprintf(fid, 'file,t,dw_hat,gt_norm,d_start,d_end,d_file,held,entry,exit,class\n');
    for e = E
        fprintf(fid, '%s,%.2f,%.6f,%d,%.2f,%.2f,%.2f,%d,%.6f,%.6f,%s\n', e.file, e.t, e.dwh, e.gt_norm, ...
            e.d_start, e.d_end, e.d_file, e.held, e.entry, e.exit, e.cls);
    end
    fclose(fid);
    fid = fopen(fullfile(outd, ['p_qa_segments_' stamp '.csv']), 'w');
    hd = {};
    for a = {'dwh', 'dw', 'dm'}, for b = {'p50', 'p90', 'p99', 'p999', 'max'}, hd{end + 1} = [a{1} '_' b{1}]; end, end %#ok<AGROW>
    fprintf(fid, 'file,%s\n', strjoin(hd, ','));
    for i = 1:n
        fprintf(fid, '%s%s\n', files{i}, sprintf(',%.6f', PS(i, :)));
    end
    fclose(fid);
    fprintf('  saved results/pqa/p_qa_%s.mat, p_qa_events_%s.csv, p_qa_segments_%s.csv\n', stamp, stamp, stamp);
end
end

%% ---------------------------------------------------------------------
function files = population()
%POPULATION  REGISTER_P2 sec 6.2.1 / 21: field_grid_K050.mat's 30 segments + the exploration
%  manifest (wind_expl_t150_batch.json); uncapped. No held-out / CONFIRM / CONFIRM2 file.
Z = load('field_grid_K050.mat', 'T');
man = jsondecode(fileread('wind_expl_t150_batch.json'));
f2 = man.files(:);  if ~iscell(f2), f2 = cellstr(f2); end
f1 = Z.T.file(:);
assert(numel(f1) == 30 && all(startsWith(f1, 'wind_real_t150_i')), 'p_qa: field_grid part is not the registered 30.');
assert(all(startsWith(f2, 'wind_expl_t150_i')), 'p_qa: manifest lists a file outside the exploration export.');
files = [f1; f2];
assert(numel(files) == 471, 'p_qa: population has %d segments, registered 471.', numel(files));
end

function s = one_segment(fn, opt)
Z = load(fn, 't', 'w_meas', 't_plant', 'w_plant', 't_pred', 'w_hat', 't_valid_from', 'window_s', ...
    'real_offset_s');
fs = 20;  dt = 1 / fs;
t = Z.t(:);  n = numel(t);
idx = @(tt) round(tt / dt) + 1;                          % sample index on the 20 Hz grid
tp = Z.t_pred(:);  kp = idx(tp);
assert(all(abs(t(kp) - tp) < 1e-9), 'p_qa: %s - prediction times are not on the 20 Hz grid.', fn);
h = @(W) sqrt(sum(diff(W(:, 1:2), 1, 1).^2, 2));
dm_all = [0; h(Z.w_meas)];                               % dm at sample j = |m(j) - m(j-1)|
% w_plant at the prediction times, on its own grid (the plant rate may differ from 20 Hz)
tq = Z.t_plant(:);
jp = round((tp - tq(1)) / (tq(2) - tq(1))) + 1;
assert(all(jp >= 1 & jp <= numel(tq)) && all(abs(tq(min(max(jp, 1), numel(tq))) - tp) < 1e-9), ...
    'p_qa: %s - prediction times are not on the w_plant grid.', fn);
s.file = fn;  s.t = tp(2:end);
% all three between consecutive prediction samples t_{k-1}, t_k
s.dwh = h(Z.w_hat);  s.dw = h(Z.w_plant(jp, :));  s.dm = h(Z.w_meas(kp, :));
ws = double(Z.window_s);  tv = double(Z.t_valid_from);  t_end = t(end);
s.d_start = s.t - tv;  s.d_end = t_end - s.t;
raw = double(Z.real_offset_s) + s.t;
s.d_file = min(raw, opt.FileLen - raw);
% held input: >= Held identical consecutive samples (all channels) lying wholly inside
% [t_k - window_s, t_k], i.e. a sample j in [k0 + Held - 1, k] closing Held equal samples
same = [false; all(diff(Z.w_meas, 1, 1) == 0, 2)];
run = zeros(n, 1);
for j = 2:n, if same(j), run(j) = run(j - 1) + 1; end, end
ends = run >= opt.Held - 1;                              % Held samples = Held-1 equal differences
c = cumsum(ends);
k = idx(s.t);  k0 = max(idx(s.t - ws), 1);
cp = [0; c(1:end - 1)];
s.held = (c(k) - cp(min(k0 + opt.Held - 1, k))) > 0;
nb = @(j) max(dm_all(max(j - 1, 1):min(j + 1, n)));
s.entry = arrayfun(nb, k);
s.exit = arrayfun(nb, max(idx(s.t - ws), 1));
end

function v = pct(x, p)
%PCT  Percentile, MATLAB prctile's definition (midpoint interpolation), no toolbox needed.
x = sort(x(:));  n = numel(x);
if n == 0, v = NaN; return; end
v = zeros(size(p));
for i = 1:numel(p)
    r = n * p(i) / 100 + 0.5;
    if r <= 1, v(i) = x(1);
    elseif r >= n, v(i) = x(n);
    else, lo = floor(r);  v(i) = x(lo) + (r - lo) * (x(lo + 1) - x(lo));
    end
end
end

function r = spearman(a, b)
ra = tied_rank(a(:));  rb = tied_rank(b(:));
c = corrcoef(ra, rb);  r = c(1, 2);
end

function r = tied_rank(x)
[xs, o] = sort(x);  n = numel(x);  r = zeros(n, 1);  i = 1;
while i <= n
    j = i;
    while j < n && xs(j + 1) == xs(i), j = j + 1; end
    r(o(i:j)) = (i + j) / 2;  i = j + 1;
end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
