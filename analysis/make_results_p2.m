function T = make_results_p2(varargin)
%MAKE_RESULTS_P2  GD11a: docs/RESULTS_P2.md generated from the saved result files - every number with its SET and
%  ROLE. No simulation; reads results/gd6, results/gd7, results/gd10 only.
%
%   make_results_p2                      % writes docs/RESULTS_P2.md, prints the self-check against REGISTER_P2
%   T = make_results_p2('Out', '')       % no file, returns the rows
%
%  Every statistic is recomputed from the per-segment rows with the definitions of REGISTER_P2 sec 0.2: pooled =
%  sqrt(mean(m_i^2)); SE = paired delete-one-day jackknife; LOO [min, max]; by-day median from each day's own pooled
%  columns. Subsets: 'one' = finite in the listed columns (one-set rule); 'unsatL3' = one set AND tilt_sat_frac < 1 %
%  in the L3 column only (CONFIRM2 rule of sec 60.3); 'unsatAll' = one set AND tilt_sat_frac < 1 % in every listed
%  column (side reports, sec 26). tilt_sat_frac is read from rows.p2{c}.tilt_sat_frac (whole run).
%  Roles: CLAIM (registered confirmatory claim), CLAIM-dev (the registered dev gate/reading), POST-HOC (found on dev
%  after seeing data, D20/D22), DESCRIPTIVE (no test), NEGATIVE (registered test failed). The self-check compares the
%  recomputed values with the numbers written in REGISTER_P2 (printed MATCH / DIFF; nothing is changed).
opt = struct('Out', fullfile(repo_root(), 'docs', 'RESULTS_P2.md'), 'Root', fullfile(repo_root(), 'results'));
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'make_results_p2: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
[st, gh] = system('git rev-parse --short HEAD');  if st ~= 0, gh = 'unknown'; end
S = specs();
T = struct('sec', {}, 'id', {}, 'label', {}, 'val', {}, 'se', {}, 'loo', {}, 'med', {}, 'n', {}, 'nd', {}, ...
    'set', {}, 'role', {}, 'src', {}, 'unit', {}, 'note', {});
P = struct('sec', {}, 'set', {}, 'sub', {}, 'cols', {}, 'pooled', {}, 'n', {}, 'nd', {}, 'src', {});
for k = 1:numel(S)
    s = S(k);
    if strcmp(s.kind, 'join')                             % two files, matched by segment (headline vs MOBADC)
        [E, day, nk] = joinfiles(opt.Root, s.file, s.cols, s.sub);
        if nk < 2
            T(end + 1) = row(s, NaN, NaN, [NaN NaN], NaN, nk, 0, 'MISSING FILE / < 2 segments'); %#ok<AGROW>
            continue
        end
        r = p2r_stat(s.fun, E, day);
        T(end + 1) = row(s, r.val, r.se, r.loo, r.med, size(E, 1), numel(unique(day)), ''); %#ok<AGROW>
        P(end + 1) = struct('sec', s.sec, 'set', s.set, 'sub', s.sub, 'cols', {s.cols}, ...
            'pooled', sqrt(mean(E.^2, 1)), 'n', size(E, 1), 'nd', numel(unique(day)), ...
            'src', strjoin(s.file, ' + ')); %#ok<AGROW>
        continue
    end
    [Z, cols, ok] = p2r_load(opt.Root, s.file);
    if ~ok
        T(end + 1) = row(s, NaN, NaN, [NaN NaN], NaN, 0, 0, 'MISSING FILE'); %#ok<AGROW>
        continue
    end
    switch s.kind
        case 'stat'
            [E, day, ~, keep] = p2r_subset(Z, cols, s.cols, s.sub);
            if size(E, 1) < 1
                T(end + 1) = row(s, NaN, NaN, [NaN NaN], NaN, 0, 0, 'empty subset'); %#ok<AGROW>
                continue
            end
            r = p2r_stat(s.fun, E(keep, :), day(keep));
            T(end + 1) = row(s, r.val, r.se, r.loo, r.med, sum(keep), numel(unique(day(keep))), ''); %#ok<AGROW>
        case 'unsafe'                                     % C2 safety count: col 2 not finite while col 1 finite
            E = p2r_E(Z, cols, s.cols);
            nu = sum(isfinite(E(:, 1)) & ~isfinite(E(:, 2)));
            T(end + 1) = row(s, nu, NaN, [NaN NaN], NaN, size(E, 1), numel(unique({Z.rows.day})), ''); %#ok<AGROW>
        case 'pooled'
            [E, day, ~, keep] = p2r_subset(Z, cols, s.cols, s.sub);
            P(end + 1) = struct('sec', s.sec, 'set', s.set, 'sub', s.sub, 'cols', {s.cols}, ...
                'pooled', sqrt(mean(E(keep, :).^2, 1)), 'n', sum(keep), 'nd', numel(unique(day(keep))), ...
                'src', s.file); %#ok<AGROW>
    end
end
check(T);
if ~isempty(opt.Out), write_md(opt.Out, T, P, strtrim(gh), opt.Root); end
end

%% ---------------------------------------------------------------------
function S = specs()
%SPECS  The numbers of the paper. kind 'stat': fun on the pooled vector of the listed columns (ratio statistics).
S = struct('sec', {}, 'id', {}, 'kind', {}, 'file', {}, 'cols', {}, 'fun', {}, 'sub', {}, 'label', {}, ...
    'set', {}, 'role', {}, 'unit', {});
rel = @(p) p(1) / p(2) - 1;                               % a/b - 1
hh = @(p) 1 - p(2) / p(1);                                % 1 - b/a  (a = reference)
add = @(sec, id, kind, file, cols, fun, sub, label, set, role) struct('sec', sec, 'id', id, 'kind', kind, ...
    'file', {file}, 'cols', {cols}, 'fun', fun, 'sub', sub, 'label', label, 'set', set, 'role', role, 'unit', '%');
D2d = 'gd6/d2_p2.mat';  D2c = 'gd10/D2.mat';
S = [S
    % ---- headline: the proposed method against Guo's MOBADC (reviewer, 2026-10-04); files joined by segment ----
    add('HEAD', 'head-dev', 'join', {'gd7/six-circle-h3.mat', 'gd6/guo_p2.mat'}, {'L3_iii0', 'MOBADC'}, rel, 'one4', 'PAW-MOBADC / MOBADC - 1', 'dev circle_main', 'DESCRIPTIVE')
    add('HEAD', 'head-c2', 'join', {'gd10/C2-circle.mat', D2c}, {'L3_iii0', 'L0'}, rel, 'one4', 'PAW-MOBADC / MOBADC - 1', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('HEAD', 'head-c2-A', 'join', {'gd10/C2-circle.mat', D2c}, {'L3_iii0', 'L0'}, rel, 'unsatL3', 'PAW-MOBADC / MOBADC - 1 (A: PA-MOBADC unsaturated)', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('C1', 'D2-dev-pool', 'pooled', D2d, {'L0', 'L2', 'L3', 'V'}, [], 'one4', 'pooled mean error', 'dev circle_main', 'DESCRIPTIVE')
    add('C1', 'D2-dev', 'stat', D2d, {'L3', 'L2'}, rel, 'one4', 'D2: PA-MOBADC / MOBADC-W - 1', 'dev circle_main', 'CLAIM-dev')
    add('C1', 'V-dev', 'stat', D2d, {'V', 'L2'}, rel, 'one4', '(MOBADC-W + preview) / MOBADC-W - 1', 'dev circle_main', 'DESCRIPTIVE')
    add('C1', 'D2-c2-pool', 'pooled', D2c, {'L0', 'L2', 'L3', 'V'}, [], 'one4', 'pooled mean error', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('C1', 'D2-c2', 'stat', D2c, {'L3', 'L2'}, rel, 'one4', 'D2: PA-MOBADC / MOBADC-W - 1', 'CONFIRM2 circle', 'CLAIM')
    add('C1', 'V-c2', 'stat', D2c, {'V', 'L2'}, rel, 'one4', '(MOBADC-W + preview) / MOBADC-W - 1', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('C1', 'T3b', 'stat', 'gd6/tab_T3b_p2.mat', {'L3', 'L2'}, rel, 'one4', 'T3b: PA-MOBADC / MOBADC-W - 1', 'dev T3b_main', 'DESCRIPTIVE')
    add('C1', 'T3b-V', 'stat', 'gd6/tab_T3b_p2.mat', {'V', 'L2'}, rel, 'one4', 'T3b: (MOBADC-W + preview) / MOBADC-W - 1', 'dev T3b_main', 'DESCRIPTIVE')
    add('C1', 'sq', 'stat', 'gd6/tab_square_p2.mat', {'L3', 'L2'}, rel, 'one4', 'square: PA-MOBADC / MOBADC-W - 1', 'dev square_main', 'DESCRIPTIVE')
    add('C1', 'sq-V', 'stat', 'gd6/tab_square_p2.mat', {'V', 'L2'}, rel, 'one4', 'square: (MOBADC-W + preview) / MOBADC-W - 1', 'dev square_main', 'DESCRIPTIVE')
    % ---- C2: (iii-0) ----
    add('C2', 'Hs-N6', 'stat', 'gd7/static-hover.mat', {'L3', 'L3_iii0'}, hh, 'unsatL3', 'H-static rule: h = 1 - PAW-MOBADC / PA-MOBADC (A: PA-MOBADC unsaturated)', 'dev N6_hover', 'POST-HOC')
    add('C2', 'Hs-N6-full', 'stat', 'gd7/static-hover.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h on the full one set (registered dev reading, sec 59.3)', 'dev N6_hover', 'POST-HOC')
    add('C2', 'Hs-N6-unsafe', 'unsafe', 'gd7/static-hover.mat', {'L3', 'L3_iii0'}, [], '', 'n_unsafe (PAW-MOBADC not finite, PA-MOBADC finite)', 'dev N6_hover', 'POST-HOC')
    add('C2', 'Hs-S40h', 'stat', 'gd7/static-hover-k.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h, K-hat nominal', 'dev S40hover', 'POST-HOC')
    add('C2', 'Hs-S40h-k070', 'stat', 'gd7/static-hover-k.mat', {'L3', 'L3_iii0_k070'}, hh, 'one4', 'h, K-hat x 0.7 (factor 1.35)', 'dev S40hover', 'POST-HOC')
    add('C2', 'Hs-S40h-k130', 'stat', 'gd7/static-hover-k.mat', {'L3', 'L3_iii0_k130'}, hh, 'one4', 'h, K-hat x 1.3 (factor 1.65)', 'dev S40hover', 'POST-HOC')
    add('C2', 'Hs-c2', 'stat', 'gd10/C2-hover.mat', {'L3', 'L3_iii0'}, hh, 'unsatL3', 'H-static: h = 1 - PAW-MOBADC / PA-MOBADC (A: PA-MOBADC unsaturated)', 'CONFIRM2 hover', 'CLAIM')
    add('C2', 'Hs-c2-full', 'stat', 'gd10/C2-hover.mat', {'L3', 'L3_iii0'}, hh, 'one', 'h on the full one set (beside)', 'CONFIRM2 hover', 'DESCRIPTIVE')
    add('C2', 'Hs-c2-unsafe', 'unsafe', 'gd10/C2-hover.mat', {'L3', 'L3_iii0'}, [], '', 'n_unsafe', 'CONFIRM2 hover', 'CLAIM')
    add('C2', 'Hsc-S40', 'stat', 'gd7/static-circle.mat', {'L3', 'L3_iii0'}, hh, 'one4', 'h_c = 1 - PAW-MOBADC / PA-MOBADC (registered dev reading, sec 59.5)', 'dev S40', 'POST-HOC')
    add('C2', 'Hsc-S40-A', 'stat', 'gd7/static-circle.mat', {'L3', 'L3_iii0'}, hh, 'unsatL3', 'h_c, CONFIRM2 rule applied to dev (A: PA-MOBADC unsaturated)', 'dev S40', 'POST-HOC')
    add('C2', 'Hsc-c2', 'stat', 'gd10/C2-circle.mat', {'L3', 'L3_iii0'}, hh, 'unsatL3', 'H-static-circle: h_c (A: PA-MOBADC unsaturated)', 'CONFIRM2 circle', 'CLAIM')
    add('C2', 'Hsc-c2-full', 'stat', 'gd10/C2-circle.mat', {'L3', 'L3_iii0'}, hh, 'one', 'h_c on the full one set (beside)', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('C2', 'Hsc-c2-unsafe', 'unsafe', 'gd10/C2-circle.mat', {'L3', 'L3_iii0'}, [], '', 'n_unsafe', 'CONFIRM2 circle', 'CLAIM')
    add('C2', 'iii-hover', 'stat', 'gd7/iii-hover.mat', {'L3', 'L3_iii'}, hh, 'one4', 'MBP (model-based payload predictor): h = 1 - MBP / PA-MOBADC', 'dev S40hover', 'NEGATIVE')
    add('C2', 'iii-hover-u', 'stat', 'gd7/iii-hover.mat', {'L3', 'L3_iii'}, hh, 'unsat4', 'MBP on the unsaturated subset', 'dev S40hover', 'NEGATIVE')
    add('C2', 'iii-circle', 'stat', 'gd7/iii-circle.mat', {'L3_iii', 'L3'}, rel, 'one4', 'MBP on the circle: MBP / PA-MOBADC - 1', 'dev S40', 'NEGATIVE')
    % ---- INDI-type estimate (H3), descriptive ----
    add('INDI', 'H3c-L1', 'stat', 'gd7/H3-circle.mat', {'H3', 'L1'}, rel, 'one4', 'INDI-DE / MOBADC-DC - 1 (no wind sensor)', 'dev circle_main', 'DESCRIPTIVE')
    add('INDI', 'H3c-L3', 'stat', 'gd7/H3-circle.mat', {'H3', 'L3'}, rel, 'one4', 'INDI-DE / PA-MOBADC - 1', 'dev circle_main', 'DESCRIPTIVE')
    add('INDI', 'H3h', 'stat', 'gd7/H3-hover.mat', {'H3', 'L3'}, rel, 'one4', 'INDI-DE / PA-MOBADC - 1', 'dev N6_hover', 'DESCRIPTIVE')
    add('INDI', 'H3h-u', 'stat', 'gd7/H3-hover.mat', {'H3', 'L3'}, rel, 'unsat4', 'INDI-DE / PA-MOBADC - 1, unsaturated', 'dev N6_hover', 'DESCRIPTIVE')
    add('INDI', 'iii0-H3-N6', 'stat', 'gd7/static-hover.mat', {'L3_iii0', 'H3'}, rel, 'one4', 'PAW-MOBADC / INDI-DE - 1', 'dev N6_hover', 'DESCRIPTIVE')
    add('INDI', 'b086', 'stat', 'gd7/static-indi-bias.mat', {'H3_b086', 'L3_iii0'}, rel, 'one4', 'INDI-DE with bias 0.086: INDI-DE (bias) / PAW-MOBADC - 1', 'dev S40hover', 'DESCRIPTIVE')
    add('INDI', 'b170', 'stat', 'gd7/static-indi-bias.mat', {'H3_b170', 'L3_iii0'}, rel, 'one4', 'INDI-DE with bias 0.17: INDI-DE (bias) / PAW-MOBADC - 1', 'dev S40hover', 'DESCRIPTIVE')
    add('INDI', 'c2-H3c', 'stat', 'gd10/C2-circle.mat', {'H3', 'L3'}, rel, 'one4', 'INDI-DE / PA-MOBADC - 1', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('INDI', 'c2-H3c-u', 'stat', 'gd10/C2-circle.mat', {'H3', 'L3'}, rel, 'unsat4', 'INDI-DE / PA-MOBADC - 1, unsaturated', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('INDI', 'c2-iii0-H3c', 'stat', 'gd10/C2-circle.mat', {'L3_iii0', 'H3'}, rel, 'one4', 'PAW-MOBADC / INDI-DE - 1', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('INDI', 'c2-H3h', 'stat', 'gd10/C2-hover.mat', {'H3', 'L3'}, rel, 'one4', 'INDI-DE / PA-MOBADC - 1', 'CONFIRM2 hover', 'DESCRIPTIVE')
    add('INDI', 'c2-H3h-u', 'stat', 'gd10/C2-hover.mat', {'H3', 'L3'}, rel, 'unsat4', 'INDI-DE / PA-MOBADC - 1, unsaturated', 'CONFIRM2 hover', 'DESCRIPTIVE')
    add('INDI', 'c2-iii0-H3', 'stat', 'gd10/C2-hover.mat', {'L3_iii0', 'H3'}, rel, 'one4', 'PAW-MOBADC / INDI-DE - 1', 'CONFIRM2 hover', 'DESCRIPTIVE')
    add('INDI', 'c2-iii0-H3-u', 'stat', 'gd10/C2-hover.mat', {'L3_iii0', 'H3'}, rel, 'unsat4', 'PAW-MOBADC / INDI-DE - 1, unsaturated', 'CONFIRM2 hover', 'DESCRIPTIVE')
    add('INDI', 'c2-b086', 'stat', 'gd10/C2-hover.mat', {'H3_b086', 'L3_iii0'}, rel, 'one4', 'INDI-DE with bias 0.086: INDI-DE (bias) / PAW-MOBADC - 1', 'CONFIRM2 hover', 'DESCRIPTIVE')
    add('INDI', 'c2-b170', 'stat', 'gd10/C2-hover.mat', {'H3_b170', 'L3_iii0'}, rel, 'one4', 'INDI-DE with bias 0.17: INDI-DE (bias) / PAW-MOBADC - 1', 'CONFIRM2 hover', 'DESCRIPTIVE')
    add('INDI', 'c2-circle-pool', 'pooled', 'gd10/C2-circle.mat', {'L3', 'L3_iii0', 'H3'}, [], 'one4', 'pooled', 'CONFIRM2 circle', 'DESCRIPTIVE')
    add('INDI', 'c2-hover-pool', 'pooled', 'gd10/C2-hover.mat', {'L3', 'L3_iii0', 'H3', 'H3_b086', 'H3_b170'}, [], 'one4', 'pooled', 'CONFIRM2 hover', 'DESCRIPTIVE')
    add('INDI', 'c2-hover-pool-u', 'pooled', 'gd10/C2-hover.mat', {'L3', 'L3_iii0', 'H3', 'H3_b086', 'H3_b170'}, [], 'unsat4', 'pooled', 'CONFIRM2 hover', 'DESCRIPTIVE')
    % ---- C3: wind preview (CONG G) ----
    add('C3', 'N4b', 'stat', 'gd7/N4b-P2-base.mat', {'L3', 'O'}, hh, 'one4', 'h = 1 - oracle / PA-MOBADC', 'dev circle_main', 'NEGATIVE')
    add('C3', 'N6', 'stat', 'gd7/N6.mat', {'L3_6', 'O_6'}, hh, 'one4', 'h_6 = 1 - oracle / PA-MOBADC, both with the N6 term', 'dev N6_hover', 'NEGATIVE')
    add('C3', 'Hh-dev', 'stat', 'gd7/N5-H-StrongRel.mat', {'L3', 'O'}, hh, 'unsat4', 'H-hover: h = 1 - oracle / PA-MOBADC, unsaturated', 'dev N5-H-StrongRel', 'POST-HOC')
    add('C3', 'Hh-c2', 'stat', 'gd10/C2-hhover.mat', {'L3', 'O'}, hh, 'unsat4', 'H-hover: h = 1 - oracle / PA-MOBADC, unsaturated', 'CONFIRM2 H-hover band', 'CLAIM')
    ];
% ---- C3: the twelve registered wind groups of Figure 8 (sec 0.6, 0.8); #3 N5-A-Strong is empty under A2 ----
G3 = {'#1 N5-A-Weak', 'N5-A-Weak', 'NEGATIVE';  '#2 N5-A-Medium', 'N5-A-Medium', 'NEGATIVE';
      '#4 N5-B-Weak', 'N5-B-Weak', 'NEGATIVE';  '#5 N5-B-Medium', 'N5-B-Medium', 'NEGATIVE';
      '#6 N4b-P2-base', 'N4b-P2-base', 'NEGATIVE';  '#7 N4b-P2-d200', 'N4b-P2-d200', 'NEGATIVE';
      '#8 N4b-P2-L15', 'N4b-P2-L15', 'NEGATIVE';  '#9 N4b-P2-K10', 'N4b-P2-K10', 'NEGATIVE';
      '#10 N6', 'N6', 'NEGATIVE';  '#11 N5-A-StrongRel', 'N5-A-StrongRel', 'POST-HOC';
      '#12 N5-H-StrongRel', 'N5-H-StrongRel', 'POST-HOC'};
for g = 1:size(G3, 1)
    c = {'L3', 'O'};  if strcmp(G3{g, 2}, 'N6'), c = {'L3_6', 'O_6'}; end
    S = [S; add('C3g', ['grp-' G3{g, 2}], 'stat', ['gd7/' G3{g, 2} '.mat'], c, hh, 'one4', ...
        ['group ' G3{g, 1} ': h = 1 - oracle / PA-MOBADC'], 'dev', G3{g, 3})]; %#ok<AGROW>
end
end

function r = row(s, v, se, loo, med, n, nd, note)
src = s.file;  if iscell(src), src = strjoin(src, ' + '); end
r = struct('sec', s.sec, 'id', s.id, 'label', s.label, 'val', v, 'se', se, 'loo', loo, 'med', med, 'n', n, ...
    'nd', nd, 'set', s.set, 'role', s.role, 'src', src, 'unit', tern(strcmp(s.kind, 'unsafe'), '#', '%'), ...
    'note', note);
end

%% ---------------------------------------------------------------------
function check(T)
%CHECK  Recomputed values against the numbers written in REGISTER_P2 (percent, 2 decimals).
want = {'D2-dev', -50.33; 'D2-c2', -58.30; 'Hs-c2', 63.00; 'Hsc-c2', 37.18; 'Hs-N6-full', 20.27; ...
        'Hsc-S40', 43.67; 'H3c-L1', 19.31; 'H3c-L3', 112.93; 'H3h', -22.48; 'H3h-u', -79.13; ...
        'iii0-H3-N6', 2.61; 'b086', 116.72; 'b170', 316.31; 'Hs-S40h-k070', 55.81; 'Hs-S40h-k130', 59.00};
fprintf('\n  make_results_p2 self-check against REGISTER_P2 (percent, 2 decimals):\n');
nb = 0;
for k = 1:size(want, 1)
    i = find(strcmp({T.id}, want{k, 1}), 1);
    if isempty(i) || ~isfinite(T(i).val)
        fprintf('    %-14s register %+8.2f  recomputed  missing\n', want{k, 1}, want{k, 2});  nb = nb + 1;  continue
    end
    v = round(100 * T(i).val * 100) / 100;
    okk = abs(v - want{k, 2}) < 0.006;
    nb = nb + ~okk;
    fprintf('    %-14s register %+8.2f  recomputed %+8.2f  %s\n', want{k, 1}, want{k, 2}, v, tern(okk, 'MATCH', 'DIFF'));
end
fprintf('  %d of %d differ or are missing\n', nb, size(want, 1));
end

function write_md(fn, T, P, gh, root)
fid = fopen(fn, 'w');
assert(fid > 0, 'make_results_p2: cannot write %s.', fn);
w = @(varargin) fprintf(fid, varargin{:});
w('# RESULTS_P2 - every number of the paper, with its set and role (generated)\n\n');
w('> Generated by `analysis/make_results_p2.m` at git `%s` on %s from `results/gd6`, `results/gd7`, `results/gd10`.\n', ...
    gh, datestr(now, 'yyyy-mm-dd HH:MM'));
w('> Do not edit by hand: re-run the script. Definitions: REGISTER_P2 sec 0.2 (pooled, day-jackknife SE, LOO, by-day\n');
w('> median); subsets: *one* = one-set rule, *A* = PA-MOBADC unsaturated (sec 60.3), *unsat* = unsaturated in every listed column.\n');
w('> Roles: **CLAIM** (registered confirmatory, CONFIRM2), **CLAIM-dev** (registered dev gate), **POST-HOC** (found on\n');
w('> dev after seeing data: D20, D22, D12), **DESCRIPTIVE** (no test), **NEGATIVE** (registered test failed / result\n');
w('> reported as negative). CONFIRM2 = 14 days (D23).\n');
secs = {'HEAD', 'Headline - the proposed method (PAW-MOBADC) against MOBADC of Guo et al., circle'; ...
        'C1', 'C1 - payload-force prediction (D2 and per-trajectory tables)'; ...
        'C2', 'C2 - PAW-MOBADC: static (1 + K-hat) payload-wind feed-forward, and the negative MBP result'; ...
        'INDI', 'INDI-DE (INDI-type acceleration-based disturbance estimation) - descriptive comparisons'; ...
        'C3', 'C3 - advance knowledge of the wind (CONG G) and H-hover'; ...
        'C3g', 'C3 - the twelve registered wind groups (Figure 8; #3 is empty under A2)'};
for s = 1:size(secs, 1)
    w('\n## %s\n\n', secs{s, 2});
    w('| id | quantity | value | SE | LOO [min, max] | by-day median | n (days) | set | role | source |\n|---|---|---|---|---|---|---|---|---|---|\n');
    for k = find(strcmp({T.sec}, secs{s, 1}))
        t = T(k);
        if strcmp(t.unit, '#')
            vs = sprintf('%d', t.val);  ses = '-';  ls = '-';  ms = '-';
        else
            vs = sprintf('%+.2f %%', 100 * t.val);  ses = sprintf('%.2f', 100 * t.se);
            ls = sprintf('[%+.2f, %+.2f]', 100 * t.loo);  ms = sprintf('%+.2f %%', 100 * t.med);
        end
        if ~isempty(t.note), vs = t.note;  ses = '-';  ls = '-';  ms = '-'; end
        if ~isfinite(t.se), ses = '-'; end
        w('| `%s` | %s | %s | %s | %s | %s | %d (%d) | %s | %s | `%s` |\n', t.id, t.label, vs, ses, ls, ms, t.n, t.nd, ...
            t.set, t.role, t.src);
    end
    pk = find(strcmp({P.sec}, secs{s, 1}));
    for k = pk
        p = P(k);
        w('\nPooled mean position error [m] - %s, %s (n %d, %d days; `%s`):\n\n| %s |\n|%s\n| %s |\n', p.set, ...
            p.sub, p.n, p.nd, p.src, strjoin(p2_names(p.cols), ' | '), repmat('---|', 1, numel(p.cols)), ...
            strjoin(arrayfun(@(v) sprintf('%.5f', v), p.pooled, 'UniformOutput', false), ' | '));
        w('| %s |\n', strjoin(arrayfun(@(v) sprintf('%.2f mm', 1000 * v), p.pooled, 'UniformOutput', false), ' | '));
    end
    if strcmp(secs{s, 1}, 'INDI')
        w(['\nAccelerometer bias as an equivalent attitude error, atan(b / g): b = 0.086 m/s^2 -> %.2f deg; ' ...
           'b = 0.17 m/s^2 -> %.2f deg.\n'], atand(0.086 / 9.81), atand(0.17 / 9.81));
    end
    if strcmp(secs{s, 1}, 'C3g')
        g3_md(w, T);
    end
end
safety_md(w, root);
effort_md(w, root);
w('\n## Not generated here (still from REGISTER_P2 text)\n\n');
w('- C4 (Guo''s gains unstable at motor lag > 17-25 ms): GD3 results (REGISTER_P2 sec 3, D1).\n');
w('- Guo baselines (PID / DO / ESO / MOBADC, + trim): sec 49, sec 51 (`gd6/guo_p2.mat`, `gd6/guo_trim_p2.mat`).\n');
w('- CONFIRM2 p95 and sat_p2: printed by `gd10_confirm2` (sec 61.3); u_osc and swing: section above.\n');
fclose(fid);
fprintf('  wrote %s\n', fn);
end

function safety_md(w, root)
%SAFETY_MD  REGISTER_P2 sec 59.3, 59.5, 61.2, 64: every segment on which PAW-MOBADC is not finite while PA-MOBADC is,
%  per set, with the other columns of the same segment (MOBADC from guo_p2 on circle_main). Generated, not typed.
w('\n## Safety - segments where PAW-MOBADC stopped and PA-MOBADC ran\n\n');
w('| set | n | stopped | segment | PAW-MOBADC flag | PA-MOBADC [m] | INDI-DE [m] | MOBADC [m] |\n|---|---|---|---|---|---|---|---|\n');
S = {'dev circle_main', 'gd7/six-circle-h3.mat';  'dev S40', 'gd7/static-circle.mat';
     'dev N6_hover', 'gd7/static-hover.mat';  'CONFIRM2 circle', 'gd10/C2-circle.mat';
     'CONFIRM2 hover', 'gd10/C2-hover.mat'};
[G, gc, gok] = p2r_load(root, 'gd6/guo_p2.mat');
for k = 1:size(S, 1)
    [Z, cols, ok] = p2r_load(root, S{k, 2});
    if ~ok || ~all(ismember({'L3', 'L3_iii0'}, cols)), w('| %s | - | `%s` not found | | | | | |\n', S{k, 1}, S{k, 2}); continue; end
    E = p2r_E(Z, cols, {'L3', 'L3_iii0'});
    bad = find(isfinite(E(:, 1)) & ~isfinite(E(:, 2)));
    if isempty(bad), w('| %s | %d | 0 | - | | | | |\n', S{k, 1}, numel(Z.rows)); continue; end
    jp = find(strcmp(cols, 'L3_iii0'), 1);  jh = find(strcmp(cols, 'H3'), 1);
    for i = bad(:)'
        fl = Z.rows(i).F{jp};  h = '-';  mo = '-';
        if ~isempty(jh) && isfinite(Z.rows(i).E(jh)), h = sprintf('%.4f', Z.rows(i).E(jh)); end
        if gok
            ig = find(strcmp({G.rows.file}, Z.rows(i).file), 1);
            if ~isempty(ig), mo = sprintf('%.4f', G.rows(ig).E(strcmp(gc, 'MOBADC'))); end
        end
        w('| %s | %d | %d | `%s` | %s | %.4f | %s | %s |\n', S{k, 1}, numel(Z.rows), numel(bad), Z.rows(i).file, ...
            tern(isempty(fl), 'not finite', fl), E(i, 1), h, mo);
    end
end
w(['\nBoth dev segments are spiked segments of the wind data (REGISTER_P2 sec 60.0); PAW-MOBADC multiplies the ' ...
   'measured body wind force by 1 + K-hat = 1.5, so a single-sample sensor spike enters the force command amplified ' ...
   '(LIMITATIONS G15: spike filter). MOBADC is shown only where it was run on the same segment.\n']);
end

function [E, day, nk] = joinfiles(root, f, c, sub)
%JOINFILES  Column c{1} of file f{1} and c{2} of file f{2} on the segments of both (matched by file name), each
%  file on its own one set ('one4': every column of the file finite). 'unsatL3' also requires PA-MOBADC (L3 of f{1})
%  below the tilt clamp (< 1 %), the CONFIRM2 rule of sec 60.3.
E = zeros(0, 2);  day = {};  nk = 0;
[Za, ca, oka] = p2r_load(root, f{1});  [Zb, cb, okb] = p2r_load(root, f{2});
if ~oka || ~okb || ~any(strcmp(ca, c{1})) || ~any(strcmp(cb, c{2})), return; end
[~, ia, ib] = intersect({Za.rows.file}, {Zb.rows.file});
Ea = p2r_E(Za, ca, ca);  Eb = p2r_E(Zb, cb, cb);
k = all(isfinite(Ea(ia, :)), 2) & all(isfinite(Eb(ib, :)), 2);
if strcmp(sub, 'unsatL3')
    ts = p2r_p2(Za, ca, {'L3'}, 'tilt_sat_frac');
    k = k & ts(ia) < 0.01;
end
E = [Ea(ia(k), strcmp(ca, c{1})), Eb(ib(k), strcmp(cb, c{2}))];
day = {Za.rows(ia(k)).day}';  nk = size(E, 1);
end

function g3_md(w, T)
%G3_MD  The largest h among the groups that are evaluable under the registered rule (n >= 15, >= 6 days).
k = find(strcmp({T.sec}, 'C3g') & [T.n] >= 15 & [T.nd] >= 6 & isfinite([T.val]));
if isempty(k), w('\nNo C3 group is evaluable.\n'); return; end
[~, j] = max([T(k).val]);  t = T(k(j));
w(['\nEvaluable groups (n >= 15 segments, >= 6 days): %d of %d with data. Largest h among them: %+.2f %% ' ...
   '(%s; registered headroom threshold 10 %%).\n'], numel(k), sum(strcmp({T.sec}, 'C3g') & [T.n] > 0), ...
   100 * t.val, t.label);
end

function effort_md(w, root)
%EFFORT_MD  Control effort and payload swing on CONFIRM2 (descriptive; the quantities of Figure 6): u_osc
%  (rows.Q(5, :)), theta RMS and theta max (p2_summary, t >= 140 s), each column on its file's one set.
%  u_osc and theta RMS: quadratic mean over segments; theta max: median. No theta oscillation about the cone angle
%  is stored, so on the circle theta RMS is mostly the steady cone angle.
w('\n## Control effort and payload swing - CONFIRM2 (descriptive)\n\n');
w('| set | controller | n | u_osc [N] | theta RMS [deg] | theta max, median [deg] | source |\n|---|---|---|---|---|---|---|\n');
C = {'circle', 'MOBADC', 'gd10/D2.mat', 'L0';  'circle', 'MOBADC-W', 'gd10/D2.mat', 'L2';
     'circle', 'PA-MOBADC', 'gd10/D2.mat', 'L3';  'circle', 'PAW-MOBADC', 'gd10/C2-circle.mat', 'L3_iii0';
     'circle', 'INDI-DE', 'gd10/C2-circle.mat', 'H3';  'hover', 'PA-MOBADC', 'gd10/C2-hover.mat', 'L3';
     'hover', 'PAW-MOBADC', 'gd10/C2-hover.mat', 'L3_iii0';  'hover', 'INDI-DE', 'gd10/C2-hover.mat', 'H3'};
U = nan(size(C, 1), 1);
for i = 1:size(C, 1)
    [Z, cols, ok] = p2r_load(root, C{i, 3});
    if ~ok || ~any(strcmp(cols, C{i, 4})), w('| %s | %s | - | `%s` not found | | | |\n', C{i, 1}, C{i, 2}, C{i, 3}); continue; end
    [~, ~, ~, keep] = p2r_subset(Z, cols, {C{i, 4}}, 'one4');
    j = find(strcmp(cols, C{i, 4}), 1);
    u = nan(numel(Z.rows), 1);
    if isfield(Z.rows, 'Q'), u = arrayfun(@(r) r.Q(5, j), Z.rows(:)); end
    th = p2r_p2(Z, cols, {C{i, 4}}, 'theta_rms_stat_deg');  tm = p2r_p2(Z, cols, {C{i, 4}}, 'theta_max_stat_deg');
    u = u(keep);  th = th(keep);  tm = tm(keep);
    uu = u(isfinite(u));  if ~isempty(uu), U(i) = sqrt(mean(uu.^2)); end
    w('| %s | %s | %d | %s | %s | %s | `%s` |\n', C{i, 1}, C{i, 2}, sum(keep), qm(u, '%.3f'), qm(th, '%.2f'), ...
        md(tm, '%.2f'), C{i, 3});
end
w(['\nControl-effort ratio (quadratic means above): PAW-MOBADC / MOBADC - 1 on the circle = %+.2f %%; ' ...
   'PAW-MOBADC / PA-MOBADC - 1 in hover = %+.2f %%.\n'], 100 * (U(4) / U(1) - 1), 100 * (U(7) / U(6) - 1));
w(['\nOn the circle the payload rides at a steady cone angle (about 15 deg for R 0.8 m, w 1.575 rad/s, L 1.0 m), ' ...
   'so theta RMS there is mostly that angle; the swing about it is not stored.\n']);
end

function s = qm(v, f)
v = v(isfinite(v));  if isempty(v), s = '-'; else, s = sprintf(f, sqrt(mean(v.^2))); end
end

function s = md(v, f)
v = v(isfinite(v));  if isempty(v), s = '-'; else, s = sprintf(f, median(v)); end
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
