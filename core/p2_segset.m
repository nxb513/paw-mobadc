function S = p2_segset(name, varargin)
%P2_SEGSET  The registered segment set of a P2 table or CỔNG G group (GĐ5, X-segset).
%
%   S = p2_segset('circle_main')            % one set (struct: files, U, day, n_seg, n_days, ...)
%   A = p2_segset('all')                    % every registered set, printed as one table
%   A = p2_segset('all', 'CapPerDay', 4)    % the same with at most 4 segments per day (option)
%   p2_segset('all', 'Save', true)          % + results/gd5/segsets_<stamp>.mat with SHA-256 per list
%   S = p2_segset('S40')                    % sensitivity set S40 (REGISTER_P2 sec 30.1): 40 segments of
%                                           % circle_main (cap 4), one per day, times of day spread evenly
%   S = p2_segset('S40hover')               % sec 39: the same rule on N6_hover (cap 4), EVERY day of it
%   S = p2_segset('circle_main', 'CapPerDay', 4, 'Confirm2', 'wind_conf2')
%                                           % sec 60.2 / 60.8 (GD10 ONLY): the same rule on the CONFIRM2
%                                           % export in that directory (never read otherwise)
%   S = p2_segset('circle_main', 'CapPerDay', 4, 'Confirm2', 'wind_conf3')
%                                           % REGISTER_FINAL sec 6: the same on the CONFIRM3 export
%                                           % (core/confirm_set.m tells the two apart by the batch file)
%
%  REGISTER_P2 sec 6 (GĐ5 protocol). The P2 dev set is
%     field_grid_K050.mat's 30 segments (T.file, wind_real_t150_i*.mat)
%   + every exploration segment (wind_expl_t150_i*.mat, the 32 exploration days, all
%     segments through QC; listed in wind_expl_t150_batch.json)
%  - never CONFIRM2 (except with the option 'Confirm2', sec 60.8), never the old confirm set. A set = the dev segments of the table's
%  trajectory inside its A2 envelope (core/p2_umax.m) and its U range.
%
%  U of a segment = norm(mean(w_plant(t_plant >= 140, 1:2))) - read from the segment file
%  itself, the same arithmetic as T.U (sweep_field_grid.m); for the 30 field_grid segments
%  it is checked against T.U (must agree to 1e-9). Day = from real_file (yyyy-mm-dd).
%  Uses no tracking error and no controller output.
opt = struct('CapPerDay', Inf, 'Save', false, 'Quiet', false, 'ExplManifest', 'wind_expl_t150_batch.json', ...
             'TStat', 140, 'Pool', [], 'Confirm2', '', 'Manifest2', '');
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'p2_segset: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
if ~isempty(opt.Confirm2)                                  % sec 60.8: the CONFIRM2 pool, GD10 only
    assert(~any(strcmp(name, {'S40', 'S40hover', 'all'})), ['p2_segset: ''%s'' is not a CONFIRM2 set ' ...
        '(REGISTER_P2 sec 60.2: circle_main / N6_hover / N5-H-StrongRel rules).'], name);
    D = conf2_pool(opt);
elseif isempty(opt.Pool), D = dev_pool(opt); else, D = opt.Pool; end   % Pool: tests only
R = registry();
if strcmp(name, 'S40')
    C = one_set(R(strcmp({R.name}, 'circle_main')), D, setfield(opt, 'CapPerDay', 4)); %#ok<SFLD>
    assert(~isempty(opt.Pool) || strncmp(C.sha256, 'a227e9d87a2ac436', 16), ['p2_segset S40: circle_main ' ...
        '(cap 4) has SHA %s, not the registered a227e9d87a2ac436 - S40 not built.'], C.sha256(1:16));
    S = s40(C, opt);
    return
end
if strcmp(name, 'S40hover')                                % sec 39: F1-F3 on hover
    C = one_set(R(strcmp({R.name}, 'N6_hover')), D, setfield(opt, 'CapPerDay', 4)); %#ok<SFLD>
    assert(~isempty(opt.Pool) || strncmp(C.sha256, '43226c02', 8), ['p2_segset S40hover: N6_hover ' ...
        '(cap 4) has SHA %s, not the registered 43226c02... - S40hover not built.'], C.sha256(1:16));
    S = s40(C, opt, numel(unique(C.day)), 'S40hover');
    return
end
if strcmp(name, 'all')
    S = struct([]);
    for k = 1:numel(R)
        s = one_set(R(k), D, opt);
        if isempty(S), S = s; else, S(end + 1) = s; end %#ok<AGROW>
    end
    if ~opt.Quiet, print_table(S, D, opt); end
    if opt.Save, save_sets(S, D, opt); end
else
    k = find(strcmp({R.name}, name), 1);
    assert(~isempty(k), 'p2_segset: unknown set ''%s'' (known: %s).', name, strjoin({R.name}, ', '));
    S = one_set(R(k), D, opt);
end
end

%% ---------------------------------------------------------------------
function R = registry()
%REGISTRY  Every registered set: REGISTER_P2 sec 0.5 (D2), 0.8 + A3 (CONG G), sec 6 (tables).
%  a = largest horizontal reference acceleration of the trajectory (A2, sec 4.4). Every set
%  is also cut at U <= U_max(K, m_p, a). Bounds: lo < U (lo_strict) or lo <= U; U < hi
%  (hi_strict) or U <= hi; rel = true: lo = 0.8 * U_max (A3 "relatively strong").
a_c = 0.8 * 1.575^2;  a_t3b = 1.48915;  a_sq = 1.3036 * (10 / sqrt(3)) / 1.9399^2;  a_t5 = 1.82991;
r = @(name, traj, K, a, lo, los, hi, his, rel, what) struct('name', name, 'traj', traj, 'K', K, ...
    'm_p', 0.5, 'a', a, 'lo', lo, 'lo_strict', los, 'hi', hi, 'hi_strict', his, 'rel', rel, 'what', what);
R = [ ...
    r('circle_main',    'circle', 0.5, a_c,   0,  false, Inf, false, false, 'D2 main table; N4b-P2-base/-d200/-L15')
    r('T3b_main',       'T3b',    0.5, a_t3b, 0,  false, Inf, false, false, 'T3b table')
    r('square_main',    'square', 0.5, a_sq,  0,  false, Inf, false, false, 'square table')
    r('T5_main',        'T5',     0.5, a_t5,  0,  false, Inf, false, false, 'T5 table')
    r('N5-A-Weak',      'circle', 0,   a_c,   0,  false, 6,   true,  false, 'CONG G #1, U < 6')
    r('N5-A-Medium',    'circle', 0,   a_c,   6,  false, 12,  false, false, 'CONG G #2, 6 <= U <= 12')
    r('N5-A-Strong',    'circle', 0,   a_c,   12, true,  Inf, false, false, 'CONG G #3, U > 12 (empty under A2)')
    r('N5-B-Weak',      'circle', 0.5, a_c,   0,  false, 6,   true,  false, 'CONG G #4, U < 6')
    r('N5-B-Medium',    'circle', 0.5, a_c,   6,  false, 12,  false, false, 'CONG G #5, 6 <= U <= 12')
    r('N4b-P2-K10',     'circle', 1.0, a_c,   0,  false, Inf, false, false, 'CONG G #9, K = 1.0')
    r('N5-A-StrongRel', 'circle', 0,   a_c,   0,  false, Inf, false, true,  'CONG G #11 (A3), 80-100% U_max')
    r('N5-H-StrongRel', 'hover',  0,   0,     0,  false, Inf, false, true,  'CONG G #12 (A3), 80-100% U_max')
    r('N6_hover',       'hover',  0.5, 0,     0,  false, Inf, false, false, 'CONG G #10 N6 (sec 14), hover K 0.5')];
end

function s = one_set(r, D, opt)
umax = p2_umax(r.K, r.m_p, r.a);
lo = r.lo;  if r.rel, lo = 0.8 * umax; end
hi = min(r.hi, umax);
if r.lo_strict, inr = D.U > lo; else, inr = D.U >= lo; end
if r.hi_strict && r.hi <= umax, inr = inr & D.U < hi; else, inr = inr & D.U <= hi; end
idx = find(inr);
idx = cap_per_day(idx, D, opt.CapPerDay);
s = struct('name', r.name, 'traj', r.traj, 'K', r.K, 'm_p', r.m_p, 'what', r.what, ...
    'U_lo', lo, 'U_hi', hi, 'U_max', umax, 'files', {D.file(idx)}, 'U', D.U(idx), ...
    'day', {D.day(idx)}, 'src', {D.src(idx)}, 'n_seg', numel(idx), ...
    'n_days', numel(unique(D.day(idx))), 'cap_per_day', opt.CapPerDay);
s.sufficient = s.n_seg >= 15 && s.n_days >= 6;       % sec 0.6 data-sufficiency rule
s.sha256 = sha256(strjoin(sort(s.files(:)).', newline));
end

function S = s40(C, opt, ns, nm)
%S40  REGISTER_P2 sec 30.1. From circle_main (cap 4 per day, its registered SHA): the days sorted by
%  date, 40 of them taken at round(linspace(1, n_days, 40)); the j-th taken day contributes the
%  one segment whose start time of day (real_t0 + real_offset_s, from the segment file) is nearest
%  (circular distance on the 24 h clock) to (j - 0.5)/40 * 24 h; ties -> lower measurement height, then file name. Uses no wind value
%  and no result. ns / nm (sec 39, S40hover): ns days (= every day of the source) instead of 40.
if nargin < 3, ns = 40;  nm = 'S40'; end
ud = unique(C.day);                                        % sorted yyyy-mm-dd
nd = numel(ud);
assert(nd >= ns, 'p2_segset %s: the source has %d days (< %d).', nm, nd, ns);
take = ud(round(linspace(1, nd, ns)));
n = numel(C.files);  tod = nan(n, 1);  hgt = nan(n, 1);
for i = 1:n
    M = load(C.files{i}, 'real_t0', 'real_offset_s', 'real_height_m');
    t0 = strtrim(char(M.real_t0));                         % 'yyyy-mm-ddTHH:MM:SS'
    hms = sscanf(t0(12:19), '%d:%d:%d');
    tod(i) = mod(3600 * hms(1) + 60 * hms(2) + hms(3) + double(M.real_offset_s), 86400);
    hgt(i) = double(M.real_height_m);
end
pick = zeros(ns, 1);  target = ((1:ns)' - 0.5) / ns * 86400;
for j = 1:ns
    k = find(strcmp(C.day, take{j}));
    [~, ~, fo] = unique(C.files(k));                       % file-name rank (last tie-break)
    dt = abs(tod(k) - target(j));  dt = min(dt, 86400 - dt);  % circular distance on the 24 h clock
    [~, o] = sortrows([dt, hgt(k), fo(:)]);
    pick(j) = k(o(1));
end
S = C;
S.name = nm;  S.what = sprintf('sensitivity set (sec 30.1/39): %s, 1 segment/day, times of day spread', C.name);
S.files = C.files(pick);  S.U = C.U(pick);  S.day = C.day(pick);  S.src = C.src(pick);
S.n_seg = ns;  S.n_days = numel(unique(S.day));  S.cap_per_day = 1;
S.tod_h = tod(pick) / 3600;  S.target_h = target / 3600;  S.from_sha = C.sha256;
S.sufficient = true;
S.sha256 = sha256(strjoin(sort(S.files(:)).', newline));
if ~opt.Quiet
    fprintf('  %s from %s (%d seg, %d days, sha %s): %d segments, %d days, sha256 %s\n', nm, C.name, ...
        C.n_seg, nd, C.sha256(1:16), ns, S.n_days, S.sha256);
    fprintf('  %-26s %-10s %6s %8s %8s\n', 'segment', 'day', 'U', 'tod [h]', 'target');
    for j = 1:ns
        fprintf('  %-26s %-10s %6.2f %8.2f %8.2f\n', S.files{j}, S.day{j}, S.U(j), S.tod_h(j), S.target_h(j));
    end
end
end

function idx = cap_per_day(idx, D, cap)
%CAP_PER_DAY  At most cap segments per day, evenly spaced in the pool's own order.
if ~isfinite(cap), return; end
keep = false(size(idx));
days = D.day(idx);
ud = unique(days);
for j = 1:numel(ud)
    k = find(strcmp(days, ud{j}));
    if numel(k) <= cap
        keep(k) = true;
    else
        keep(k(round(linspace(1, numel(k), cap)))) = true;
    end
end
idx = idx(keep);
end

function D = dev_pool(opt)
%DEV_POOL  The 30 field_grid segments + every exploration segment, with U and day.
Z = load('field_grid_K050.mat', 'T');
T = Z.T;
f1 = T.file(:);
assert(exist(opt.ExplManifest, 'file') == 2, ['p2_segset: %s not found - export the exploration ' ...
    'segments first (REGISTER_P2 sec 6.1).'], opt.ExplManifest);
man = jsondecode(fileread(opt.ExplManifest));
f2 = man.files(:);
if ~iscell(f2), f2 = cellstr(f2); end
assert(all(startsWith(f2, 'wind_expl_t150_i')), 'p2_segset: manifest lists a file outside the exploration export.');
file = [f1; f2];
src = [repmat({'field_grid'}, numel(f1), 1); repmat({'exploration'}, numel(f2), 1)];
n = numel(file);
U = nan(n, 1);  day = cell(n, 1);
for i = 1:n
    assert(exist(file{i}, 'file') == 2, 'p2_segset: %s is not on the path.', file{i});
    M = load(file{i}, 't_plant', 'w_plant', 'real_file');
    m = M.t_plant(:) >= opt.TStat;
    U(i) = norm(mean(M.w_plant(m, 1:2), 1));
    rf = strtrim(char(M.real_file));
    day{i} = [rf(7:10) '-' rf(1:2) '-' rf(4:5)];
end
dU = max(abs(U(1:numel(f1)) - T.U(:)));
assert(dU < 1e-9, 'p2_segset: U from the files differs from field_grid T.U by %.3g.', dU);
dd = unique(day(numel(f1) + 1:end));
assert(isempty(intersect(dd, unique(day(1:numel(f1))))), ...
    'p2_segset: an exploration day is also a field_grid day.');
% fingerprint of the exploration part (REGISTER_P2 sec 6.1): sorted "file U day" lines, U to 1e-9
ie = numel(f1) + 1:n;
[~, o] = sort(file(ie));
ln = arrayfun(@(k) sprintf('%s %.9f %s', file{ie(k)}, U(ie(k)), day{ie(k)}), o(:), 'UniformOutput', false);
D = struct('file', {file}, 'U', U, 'day', {day}, 'src', {src}, 'dU_T', dU, ...
    'n_fg', numel(f1), 'n_ex', numel(f2), 'manifest', opt.ExplManifest, ...
    'fp_expl', sha256(strjoin(ln.', newline)));
end

function D = conf2_pool(opt)
%CONF2_POOL  REGISTER_P2 sec 60.1 / 60.8: the CONFIRM2 export in directory opt.Confirm2, after checking
%  the manifest (file SHA-256 on its committed bytes, CR removed; sha256_days; 16 days), every segment's
%  day in the manifest, every file named wind_conf2_t150_i*.mat, and no manifest day in the dev pool.
%  REGISTER_FINAL sec 6: the same checks on a CONFIRM3 export (58 days, wind_conf3_t150_i*.mat, its own
%  registered SHA-256), chosen by core/confirm_set.m.
cs = confirm_set(opt.Confirm2);
FILE_SHA = cs.file_sha;
DAYS_SHA = cs.days_sha;
mf = opt.Manifest2;
if isempty(mf), mf = fullfile(repo_root(), cs.manifest); end
fid = fopen(mf, 'r');
assert(fid > 0, 'p2_segset Confirm2: %s not found.', mf);
b = fread(fid, Inf, 'uint8=>char').';
fclose(fid);
b = b(b ~= char(13));                                       % a Windows checkout may add CR (autocrlf)
fs = sha256(b);
assert(strcmp(fs, FILE_SHA), 'p2_segset Confirm2: manifest SHA-256 %s, registered %s - STOP.', fs, FILE_SHA);
man = jsondecode(b);
days = man.days(:);
if ~iscell(days), days = cellstr(days); end
assert(numel(days) == cs.n_days && man.n_days == cs.n_days, 'p2_segset Confirm2: the manifest does not list %d days.', ...
    cs.n_days);
ds = sha256(strjoin(days.', newline));
assert(strcmp(ds, DAYS_SHA) && strcmp(man.sha256_days, DAYS_SHA), ...
    'p2_segset Confirm2: sha256_days %s, registered %s - STOP.', ds, DAYS_SHA);
dir2 = opt.Confirm2;
bj = fullfile(dir2, cs.batch);
assert(exist(bj, 'file') == 2, 'p2_segset Confirm2: %s not found - export first (REGISTER_P2 sec 60.6).', bj);
bm = jsondecode(fileread(bj));
file = bm.files(:);
if ~iscell(file), file = cellstr(file); end
assert(~isempty(file) && all(strncmp(file, cs.prefix, numel(cs.prefix))), ...
    'p2_segset Confirm2: the batch lists a file outside the %s export.', cs.name);
n = numel(file);
U = nan(n, 1);  day = cell(n, 1);
for i = 1:n
    ff = fullfile(dir2, file{i});
    assert(exist(ff, 'file') == 2, 'p2_segset Confirm2: %s missing.', ff);
    M = load(ff, 't_plant', 'w_plant', 'real_file');
    m = M.t_plant(:) >= opt.TStat;
    U(i) = norm(mean(M.w_plant(m, 1:2), 1));
    rf = strtrim(char(M.real_file));
    day{i} = [rf(7:10) '-' rf(1:2) '-' rf(4:5)];
end
assert(all(ismember(day, days)), 'p2_segset Confirm2: a segment''s day is not in the manifest - STOP.');
if isempty(opt.Pool), Dd = dev_pool(opt); else, Dd = opt.Pool; end   % Pool: tests only
assert(isempty(intersect(days, Dd.day)), 'p2_segset Confirm2: a manifest day is in the dev pool - STOP.');
D = struct('file', {file}, 'U', U, 'day', {day}, 'src', {repmat({lower(cs.name)}, n, 1)}, ...
    'n_conf2', n, 'n_days_found', numel(unique(day)), 'manifest_sha', fs, 'dir', dir2);
end

function print_table(S, D, opt)
fprintf('\n  P2 dev set (REGISTER_P2 sec 6.1): %d field_grid + %d exploration segments, %d days; U vs T.U max diff %.1e\n', ...
    D.n_fg, D.n_ex, numel(unique(D.day)), D.dU_T);
if isfield(D, 'fp_expl'), fprintf('  exploration fingerprint %s\n', D.fp_expl); end
if isfinite(opt.CapPerDay), fprintf('  at most %d segments per day per set\n', opt.CapPerDay); end
fprintf('  %-16s %-7s %4s %11s  %7s %6s  %-6s %-16s %s\n', 'set', 'traj', 'K', 'U range', 'n_seg', 'n_days', ...
    'enough', 'sha256 (16)', 'what');
for k = 1:numel(S)
    s = S(k);
    fprintf('  %-16s %-7s %4.1f %5.2f-%5.2f  %7d %6d  %-6s %-16s %s\n', s.name, s.traj, s.K, s.U_lo, s.U_hi, ...
        s.n_seg, s.n_days, tern(s.sufficient, 'yes', 'NO'), s.sha256(1:16), s.what);
end
end

function save_sets(S, D, opt) %#ok<INUSD>
outd = fullfile(repo_root(), 'results', 'gd5');
if ~exist(outd, 'dir'), mkdir(outd); end
fn = fullfile(outd, sprintf('segsets_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
[st, gh] = system('git rev-parse --short HEAD');  if st ~= 0, gh = 'unknown'; end
git = strtrim(gh); %#ok<NASGU>
save(fn, 'S', 'D', 'git');
fprintf('  saved %s\n', fn);
end

function h = sha256(s)
if exist('OCTAVE_VERSION', 'builtin')                 % Octave (tests): built-in hash
    h = hash('sha256', s);
    return
end
md = java.security.MessageDigest.getInstance('SHA-256');
if isempty(s)
    % an EMPTY set (N5-A-Strong under A2): MATLAB passes an empty uint8 to Java as null,
    % so digest(uint8('')) fails - digest() with no input is the SHA-256 of zero bytes
    d = md.digest();
else
    d = md.digest(uint8(s));
end
h = lower(reshape(dec2hex(typecast(d(:), 'uint8'), 2).', 1, []));
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
