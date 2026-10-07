function T = make_results_final(varargin)
%MAKE_RESULTS_FINAL  docs/RESULTS_FINAL.md from the result files of the final run (docs/REGISTER_FINAL.md, GitHub
%  runs 37343938016 / 37481942029 / 37494235578, merged by 37565806130; artifact "final-results" in results/final/).
%  No simulation. Definitions as make_results_p2 (REGISTER_P2 sec 0.2): pooled = sqrt(mean(m_i^2)), SE = paired
%  delete-one-day jackknife, LOO [min, max], by-day median; subsets one4 / unsatL3 (p2r_subset).
%
%   make_results_final                    % writes docs/RESULTS_FINAL.md
%   T = make_results_final('Out', '')     % rows only
%
%  Sections: REPRO - every development-set number of docs/RESULTS_P2.md recomputed from the final run (same
%  definitions, same rows of make_results_p2) beside the stored value; E1-E6 - the additional checks of REGISTER_FINAL
%  sec 5 (descriptive). The m_p 0.25 rows of E4 are re-pooled on U <= 7.38 m/s (A2 circle envelope at m_p 0.25,
%  REGISTER_P2 sec 50.1) as in the paper's Table 4; the full one set is printed beside.
opt = struct('Out', fullfile(repo_root(), 'docs', 'RESULTS_FINAL.md'), 'Root', fullfile(repo_root(), 'results', 'final'), ...
    'Stored', fullfile(repo_root(), 'docs', 'RESULTS_P2.md'));
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'make_results_final: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
[st, gh] = system('git rev-parse --short HEAD');  if st ~= 0, gh = 'unknown'; end
% ---- REPRO: the rows of make_results_p2 on the final files (gd10 = CONFIRM2 is not part of the final run) ----
R = make_results_p2('Root', opt.Root, 'Out', '');
stored = read_stored(opt.Stored);
% the T3b / square tables of the final run carry the PAW columns; their one set (finite in every column) is smaller
% than the stored one, so those four rows are recomputed on the stored columns L0 L2 L3 V for a like-for-like check
orig = {'T3b', 'gd6/tab_T3b_p2.mat', {'L3', 'L2'}; 'T3b-V', 'gd6/tab_T3b_p2.mat', {'V', 'L2'}; ...
        'sq', 'gd6/tab_square_p2.mat', {'L3', 'L2'}; 'sq-V', 'gd6/tab_square_p2.mat', {'V', 'L2'}};
for k = 1:size(orig, 1)
    j = find(strcmp({R.id}, orig{k, 1}), 1);
    [Z, c] = p2r_load(opt.Root, orig{k, 2});
    E4 = p2r_E(Z, c, {'L0', 'L2', 'L3', 'V'});  keep = all(isfinite(E4), 2);
    E = p2r_E(Z, c, orig{k, 3});  day = {Z.rows.day}';
    s = p2r_stat(@(p) p(1) / p(2) - 1, E(keep, :), day(keep));
    R(j).val = s.val;  R(j).se = s.se;  R(j).loo = s.loo;  R(j).med = s.med;  R(j).n = sum(keep);
    R(j).nd = numel(unique(day(keep)));  R(j).label = [R(j).label ' (one set of L0 L2 L3 V)'];
end
% ---- E1-E6 ----
rel = @(p) p(1) / p(2) - 1;
hh = @(p) 1 - p(2) / p(1);
T = struct('sec', {}, 'id', {}, 'label', {}, 'val', {}, 'se', {}, 'loo', {}, 'med', {}, 'n', {}, 'nd', {}, ...
    'set', {}, 'src', {}, 'note', {});
add = @(T, sec, id, file, cols, fun, sub, label, set, varargin) [T, one(opt.Root, sec, id, file, cols, fun, sub, ...
    label, set, varargin{:})];
% E1 - wind-sensor noise 0.1 m/s (references: sigma 0 on the same sets)
T = add(T, 'E1', 'E1-c', 'gd7/static-circle-sn.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h = 1 - PAW-MOBADC / PA-MOBADC, sensor noise 0.1 m/s', 'S40');
T = add(T, 'E1', 'E1-c0', 'gd7/static-circle.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h, no sensor noise (reference)', 'S40');
T = add(T, 'E1', 'E1-h', 'gd7/static-hover-sn.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h, sensor noise 0.1 m/s', 'S40hover');
T = add(T, 'E1', 'E1-h0', 'gd7/static-hover-k.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h, no sensor noise (reference)', 'S40hover');
% E2 - causal spike filter on the measured wind (references: no filter on the same sets)
T = add(T, 'E2', 'E2-c', 'gd7/static-circle-spk.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h, spike filter', 'circle_main');
T = add(T, 'E2', 'E2-c-A', 'gd7/static-circle-spk.mat', {'L3', 'L3_iii0'}, hh, 'unsatL3', 'h, spike filter (A: PA-MOBADC unsaturated)', 'circle_main');
T = add(T, 'E2', 'E2-c0', 'gd7/six-circle-h3.mat', {'L3', 'L3_iii0'}, hh, 'one', 'h, no filter (reference)', 'circle_main');
T = add(T, 'E2', 'E2-c0-A', 'gd7/six-circle-h3.mat', {'L3', 'L3_iii0'}, hh, 'unsatL3', 'h, no filter (reference, A)', 'circle_main');
T = add(T, 'E2', 'E2-h', 'gd7/static-hover-spk.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h, spike filter', 'N6_hover');
T = add(T, 'E2', 'E2-h-A', 'gd7/static-hover-spk.mat', {'L3', 'L3_iii0'}, hh, 'unsatL3', 'h, spike filter (A: PA-MOBADC unsaturated)', 'N6_hover');
T = add(T, 'E2', 'E2-h0-A', 'gd7/static-hover.mat', {'L3', 'L3_iii0'}, hh, 'unsatL3', 'h, no filter (reference, A)', 'N6_hover');
% E3 - K-hat x 0.7 / 1.3 on the circle
T = add(T, 'E3', 'E3-c', 'gd7/static-circle-k.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h, K-hat nominal (factor 1.5)', 'S40');
T = add(T, 'E3', 'E3-c070', 'gd7/static-circle-k.mat', {'L3', 'L3_iii0_k070'}, hh, 'one4', 'h, K-hat x 0.7 (factor 1.35)', 'S40');
T = add(T, 'E3', 'E3-c130', 'gd7/static-circle-k.mat', {'L3', 'L3_iii0_k130'}, hh, 'one4', 'h, K-hat x 1.3 (factor 1.65)', 'S40');
% E4-E6 - PAW columns of the TAB tables
tabs = {'circle', 'gd6/tab_circle_p2.mat', 'S40, m_p 0.5, L 1.0', '';
        'L050', 'gd6/tab_circle_L050_p2.mat', 'S40, L 0.5', '';
        'L150', 'gd6/tab_circle_L150_p2.mat', 'S40, L 1.5', '';
        'mp025', 'gd6/tab_circle_mp025_p2.mat', 'S40, m_p 0.25', 'env';
        'mp025-L050', 'gd6/tab_circle_mp025_L050_p2.mat', 'S40, m_p 0.25, L 0.5', 'env';
        'mp025-L150', 'gd6/tab_circle_mp025_L150_p2.mat', 'S40, m_p 0.25, L 1.5', 'env';
        'mp065', 'gd6/tab_circle_mp065_p2.mat', 'S40, m_p 0.65', '';
        'mp065-L050', 'gd6/tab_circle_mp065_L050_p2.mat', 'S40, m_p 0.65, L 0.5', '';
        'mp065-L150', 'gd6/tab_circle_mp065_L150_p2.mat', 'S40, m_p 0.65, L 1.5', '';
        'T3b', 'gd6/tab_T3b_p2.mat', 'T3b_main (figure-eight)', '';
        'square', 'gd6/tab_square_p2.mat', 'square_main', ''};
q = {'C2', {'L3', 'L3_iii0'}, hh, '1 - PAW-MOBADC / PA-MOBADC';
     'C2V', {'V', 'V_iii0'}, hh, '1 - (PAW + preview) / (MOBADC-W + preview)';
     'C1', {'L3', 'L2'}, rel, 'PA-MOBADC / MOBADC-W - 1';
     'fair', {'L3_iii0', 'L2'}, rel, 'PAW-MOBADC / MOBADC-W - 1';
     'fairV', {'V_iii0', 'L2'}, rel, '(PAW + preview) / MOBADC-W - 1';
     'head', {'L3_iii0', 'L0'}, rel, 'PAW-MOBADC / MOBADC - 1'};
env = s40_envelope(0.25);
for t = 1:size(tabs, 1)
    for k = 1:size(q, 1)
        id = sprintf('E4-%s-%s', tabs{t, 1}, q{k, 1});
        T = add(T, 'E4', id, tabs{t, 2}, q{k, 2}, q{k, 3}, 'one4', q{k, 4}, tabs{t, 3});
        if strcmp(tabs{t, 4}, 'env')
            T = add(T, 'E4', [id '-env'], tabs{t, 2}, q{k, 2}, q{k, 3}, 'one4', [q{k, 4} ' (U <= 7.38 m/s)'], ...
                tabs{t, 3}, env);
        end
    end
end
if ~isempty(opt.Out), write_md(opt.Out, R, stored, T, strtrim(gh), opt.Root); end
end

%% ---------------------------------------------------------------------
function r = one(root, sec, id, file, cols, fun, sub, label, set, keepfiles)
r = struct('sec', sec, 'id', id, 'label', label, 'val', NaN, 'se', NaN, 'loo', [NaN NaN], 'med', NaN, 'n', 0, ...
    'nd', 0, 'set', set, 'src', file, 'note', '');
[Z, c, ok] = p2r_load(root, file);
if ~ok, r.note = 'MISSING FILE'; return; end
[E, day, fl, keep] = p2r_subset(Z, c, cols, sub);
if nargin >= 10 && ~isempty(keepfiles), keep = keep & ismember(fl, keepfiles); end
if sum(keep) < 2, r.note = 'fewer than 2 segments'; return; end
s = p2r_stat(fun, E(keep, :), day(keep));
r.val = s.val;  r.se = s.se;  r.loo = s.loo;  r.med = s.med;  r.n = sum(keep);  r.nd = numel(unique(day(keep)));
end

function f = s40_envelope(mp)
%S40_ENVELOPE  S40 segments inside the A2 circle envelope at K 0.5 and the given m_p (REGISTER_P2 sec 50.1).
assert(mp == 0.25, 'make_results_final: only the m_p 0.25 envelope (7.38 m/s) is registered.');
S = p2_segset('S40', 'CapPerDay', 4, 'Quiet', true);
f = S.files(S.U <= 7.38);
end

function M = read_stored(fn)
%READ_STORED  id -> value text of the stored RESULTS_P2.md table rows.
M = containers.Map();
L = regexp(fileread(fn), '\r?\n', 'split');
for i = 1:numel(L)
    t = regexp(L{i}, '^\| `([^`]+)` \| [^|]+ \| ([^|]+) \| ([^|]+) \|', 'tokens', 'once');
    if ~isempty(t), M(t{1}) = {strtrim(t{2}), strtrim(t{3})}; end
end
end

function write_md(fn, R, stored, T, gh, root)
fid = fopen(fn, 'w');
assert(fid > 0, 'make_results_final: cannot write %s.', fn);
w = @(varargin) fprintf(fid, varargin{:});
w('# RESULTS_FINAL - the final run of the paper (generated)\n\n');
w('> Generated by `analysis/make_results_final.m` at git `%s` on %s from `%s` (artifact `final-results` of\n', gh, ...
    datestr(now, 'yyyy-mm-dd HH:MM'), strrep(root, [repo_root() filesep], ''));
w('> GitHub run 37565806130; docs/REGISTER_FINAL.md sec 8). Do not edit by hand. Definitions: REGISTER_P2 sec 0.2;\n');
w('> subsets *one4* (finite in every column of the file), *A* = PA-MOBADC unsaturated (tilt clamp < 1 %% of the run).\n');
w('> Every E1-E6 number is descriptive (REGISTER_FINAL sec 5).\n');
% REPRO
w('\n## Reproduction - every development-set number of RESULTS_P2 recomputed from the final run\n\n');
w('| id | quantity | stored (RESULTS_P2) | final run | SE stored / final | n (days) | set |\n|---|---|---|---|---|---|---|\n');
nsame = 0;  ncmp = 0;
for k = 1:numel(R)
    t = R(k);
    if contains(t.set, 'CONFIRM2') || ~isempty(t.note) || ~isKey(stored, t.id), continue; end
    sv = stored(t.id);
    if strcmp(t.unit, '#'), fv = sprintf('%d', t.val); fse = '-';
    else, fv = sprintf('%+.2f %%', 100 * t.val); fse = sprintf('%.2f', 100 * t.se); end
    ncmp = ncmp + 1;  same = strcmp(sv{1}, fv);  nsame = nsame + same;
    w('| `%s` | %s | %s | %s%s | %s / %s | %d (%d) | %s |\n', t.id, t.label, sv{1}, fv, tern(same, '', ' **(differs)**'), ...
        sv{2}, fse, t.n, t.nd, t.set);
end
w('\n%d of %d development-set numbers identical to the printed digit.\n', nsame, ncmp);
secs = {'E1', 'E1 - wind-sensor noise 0.1 m/s on PAW-MOBADC (descriptive)';
        'E2', 'E2 - causal spike filter on the measured wind (5 m/s step, hold <= 2 samples; descriptive)';
        'E3', 'E3 - assumed drag ratio K-hat x 0.7 / x 1.3 on the circle (descriptive)';
        'E4', 'E4-E6 - PAW-MOBADC across payload mass, cable length, trajectory and with the reference preview (descriptive)'};
for s = 1:size(secs, 1)
    w('\n## %s\n\n', secs{s, 2});
    w('| id | quantity | value | SE | LOO [min, max] | by-day median | n (days) | set | source |\n|---|---|---|---|---|---|---|---|---|\n');
    for k = find(strcmp({T.sec}, secs{s, 1}))
        t = T(k);
        if ~isempty(t.note)
            w('| `%s` | %s | %s | - | - | - | %d (%d) | %s | `%s` |\n', t.id, t.label, t.note, t.n, t.nd, t.set, t.src);
            continue
        end
        w('| `%s` | %s | %+.2f %% | %.2f | [%+.2f, %+.2f] | %+.2f %% | %d (%d) | %s | `%s` |\n', t.id, t.label, ...
            100 * t.val, 100 * t.se, 100 * t.loo, 100 * t.med, t.n, t.nd, t.set, t.src);
    end
end
E2 = {'gd7/static-circle-spk.mat', 'circle_main'; 'gd7/static-hover-spk.mat', 'N6_hover'; ...
      'gd7/six-circle-h3.mat', 'circle_main (no filter)'; 'gd7/static-hover.mat', 'N6_hover (no filter)'};
w('\nE2 - segments not finite in PA-MOBADC (L3) or PAW-MOBADC (L3_iii0):\n\n| set | file | segment | PA-MOBADC | PAW-MOBADC |\n|---|---|---|---|---|\n');
for k = 1:size(E2, 1)
    [Z, c, ok] = p2r_load(root, E2{k, 1});
    if ~ok, continue; end
    j3 = find(strcmp(c, 'L3'));  jp = find(strcmp(c, 'L3_iii0'));
    for i = 1:numel(Z.rows)
        e = Z.rows(i).E;  F = Z.rows(i).F;
        if all(isfinite(e([j3 jp]))), continue; end
        w('| %s | `%s` | `%s` | %s | %s |\n', E2{k, 2}, E2{k, 1}, Z.rows(i).file, flag(e(j3), F{j3}), flag(e(jp), F{jp}));
    end
end
fclose(fid);
fprintf('  wrote %s\n', fn);
end

function s = flag(v, f)
if isfinite(v), s = sprintf('%.4f m', v); elseif isempty(f), s = 'not finite'; else, s = f; end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
