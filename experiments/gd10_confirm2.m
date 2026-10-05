function gd10_confirm2(varargin)
%GD10_CONFIRM2  REGISTER_P2 sec 60: CONFIRM2, run ONCE. Run and leave; resumable, nothing is re-run.
%
%   gd10_confirm2                         % CONFIRM2 (only after sec 60.9: ticks + APPROVED line)
%   gd10_confirm2('DevTest', true)        % the whole chain on the first 2 DEV segments of each rule's
%                                         % dev set, results/gd10_devtest/ - plumbing test, no CONFIRM2
%
%  0  opening condition (sec 60.9): every check box of docs/MOBADC_FIDELITY.md and docs/INDI_FIDELITY.md
%     ticked once, none SAI; an "APPROVED yyyy-mm-dd ... commit <hash>" line in REGISTER_P2 sec 60 whose
%     commit is an ancestor of HEAD with no code change since; no local code change (sec 60.6)
%  1  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged (dev data);
%     E0 (sec 60.6): python/check_export_same.py wind_e0check . must PASS
%  2  OPENING: the three sets by rule (p2_segset ... 'Confirm2', Dir) - their SHA-256 printed FIRST,
%     lists saved to results/gd10/sets.mat (on a resume: must equal the saved ones)
%  3  D2 (circle), 4 C2-circle (L3_iii0, H3; L3 from D2), 5 C2-hover, 6 C2-hhover (H-hover)
%  7  the claims of sec 60.3 (analysis/conf2_claims.m), saved to results/gd10/claims.mat
%  Incidents (sec 60.7): run the SAME command again - every step resumes per segment; never edit code or
%  parameters in between. Log results/gd10/confirm2_*.txt.
opt = struct('DevTest', false, 'Dir', 'wind_conf2', 'NDev', 2);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'gd10_confirm2: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
% ---- frozen configuration, REGISTER_P2 sec 60.6 (nothing here is tuned on CONFIRM2) ----
TAU_CIRCLE = 0.290;  TAU_PREV = 0.180;  TAU_HOVER = 0;  TAUW = 0.280;  TAUW_HH = 0.020;  WF = 32;  CAP = 4;
here = repo_root();
cd(here);
setup_path();
outd = fullfile(here, 'results', tern(opt.DevTest, 'gd10_devtest', 'gd10'));
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('confirm2_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse HEAD');  gh = strtrim(gh);
t0 = tic;
fprintf('\n%s\n GD10_CONFIRM2 (REGISTER_P2 sec 60)%s | git %s | %s\n%s\n', repmat('=', 1, 80), ...
    tern(opt.DevTest, ' - DEV TEST, no CONFIRM2 file is read', ''), gh, datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
    repmat('=', 1, 80));
% ---- 0 opening condition ----
fprintf('\n  0 opening condition (sec 60.9) and code state (sec 60.6)\n');
c0 = true;
c0 = fidelity_ticks(fullfile(here, 'docs', 'MOBADC_FIDELITY.md'), 17) && c0;
c0 = fidelity_ticks(fullfile(here, 'docs', 'INDI_FIDELITY.md'), 13) && c0;
c0 = approved_line(here, gh) && c0;
c0 = code_clean() && c0;
if ~c0 && ~opt.DevTest
    fprintf('\n  STOPPED: the opening condition of sec 60.9 / 60.6 is not met - CONFIRM2 not opened.\n');
    return
end
if ~c0, fprintf('  (dev test: carrying on - the condition is checked, not required)\n'); end
% ---- 1 checks ----
fprintf('\n  1 checks: verify_p2_repro, D2 row 1, E0\n');
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7, rmdir(fullfile(here, 'slprj'), 's'); end
try
    load_system('baseline1');
    S = verify_p2_repro('Quick', true);
    assert(S.pass, 'verify_p2_repro did NOT reproduce');
    Gd = run_p2_gd6('D2', 'TauPred', TAU_CIRCLE, 'TauPrev', TAU_PREV, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
    fprintf('  D2 i0000 L0 L2 L3 V: got %s expected %s\n', mat2str(got), mat2str(want));
    assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'D2 row 1 changed');
    e0 = exist(fullfile(here, 'wind_e0check'), 'dir') == 7;
    if e0 || ~opt.DevTest
        assert(e0, 'wind_e0check/ not found - run the E0 re-export of sec 60.6 first');
        st = system('python python/check_export_same.py wind_e0check .');
        assert(st == 0, 'E0 FAILED: the export pipeline is not the dev one (sec 60.6)');
    else
        fprintf('  E0: wind_e0check/ not present - skipped in the dev test\n');
    end
catch err
    fprintf('\n  STOPPED: %s - nothing opened\n', err.message);
    return
end
% ---- 2 OPENING: sets by rule ----
rules = {'circle', 'circle_main'; 'hover', 'N6_hover'; 'hhover', 'N5-H-StrongRel'};
sarg = {'CapPerDay', CAP, 'Quiet', true};
if ~opt.DevTest, sarg = [sarg, {'Confirm2', opt.Dir}]; end
try
    for k = 1:3, Sets.(rules{k, 1}) = p2_segset(rules{k, 2}, sarg{:}); end
catch err
    fprintf('\n  STOPPED while building the sets: %s\n', err.message);
    return
end
fprintf('\n  2 SETS (sec 60.2) - SHA-256 of each list:\n');
for k = 1:3
    s = Sets.(rules{k, 1});
    fprintf('  SHA %-7s %-15s %s  (%d segments, %d days)\n', rules{k, 1}, rules{k, 2}, s.sha256, s.n_seg, s.n_days);
end
setf = fullfile(outd, 'sets.mat');
if exist(setf, 'file') == 2
    Z = load(setf, 'Sets');
    for k = 1:3
        assert(strcmp(Z.Sets.(rules{k, 1}).sha256, Sets.(rules{k, 1}).sha256), ...
            'gd10_confirm2: the %s set differs from the saved one - STOP (sec 60.7).', rules{k, 1});
    end
    fprintf('  resume: the three sets equal results/%s/sets.mat\n', tern(opt.DevTest, 'gd10_devtest', 'gd10'));
else
    git = gh; %#ok<NASGU>
    save(setf, 'Sets', 'git');
end
for k = 1:3
    s = Sets.(rules{k, 1});
    fprintf('\n  %s set (%s): %d segments, %d days, U %.2f-%.2f m/s\n', rules{k, 1}, rules{k, 2}, s.n_seg, ...
        s.n_days, s.U_lo, s.U_hi);
    for i = 1:s.n_seg, fprintf('    %-28s %-10s U %6.2f\n', s.files{i}, s.day{i}, s.U(i)); end
end
% ---- 3-6 runs ----
cm = tern(opt.DevTest, {'DevTest', true, 'NDev', opt.NDev}, {'Conf2', opt.Dir});
step(3, 'D2 (circle set): L0 L2 L3 V');
if Sets.circle.n_seg > 0
    try
        run_p2_gd6('D2', 'TauPred', TAU_CIRCLE, 'TauPrev', TAU_PREV, 'Sha', Sets.circle.sha256, cm{:});
    catch err
        fprintf('\n  !!! D2 error: %s (continuing; re-run the same command to resume)\n', err.message);
    end
end
step(4, sprintf('C2-circle (circle set): L3_iii0, H3 (%g Hz); L3 from D2', WF));
if Sets.circle.n_seg > 0
    try
        run_p2_gd7('C2-circle', 'TauW', TAUW, 'TauPred', TAU_CIRCLE, 'H3Hz', WF, 'Sha', Sets.circle.sha256, cm{:});
    catch err
        fprintf('\n  !!! C2-circle error: %s (continuing)\n', err.message);
    end
end
step(5, sprintf('C2-hover (hover set): L3, L3_iii0, H3, H3_b086, H3_b170 (%g Hz)', WF));
if Sets.hover.n_seg > 0
    try
        run_p2_gd7('C2-hover', 'TauW', TAUW, 'TauPred', TAU_HOVER, 'H3Hz', WF, 'Sha', Sets.hover.sha256, cm{:});
    catch err
        fprintf('\n  !!! C2-hover error: %s (continuing)\n', err.message);
    end
end
step(6, 'C2-hhover (H-hover set, sec 26.3): L3, P, O, O0 at tau_w* 20 ms');
if Sets.hhover.n_seg > 0
    try
        run_p2_gd7('C2-hhover', 'TauW', TAUW_HH, 'TauPred', TAU_HOVER, 'Sha', Sets.hhover.sha256, cm{:});
    catch err
        fprintf('\n  !!! C2-hhover error: %s (continuing)\n', err.message);
    end
end
% ---- 7 claims ----
step(7, 'claims (sec 60.3)');
src = {'D2', 'D2'; 'circle', 'C2-circle'; 'hover', 'C2-hover'; 'hhover', 'C2-hhover'};
Z = struct();
for k = 1:size(src, 1)
    f = fullfile(outd, [src{k, 2} '.mat']);
    Z.(src{k, 1}) = [];
    if exist(f, 'file') == 2, Z.(src{k, 1}) = load(f, 'rows', 'key'); end
end
C = conf2_claims(Z, 'Dir', tern(opt.DevTest, '', opt.Dir));
git = gh; %#ok<NASGU>
save(fullfile(outd, 'claims.mat'), 'C', 'Sets', 'git');
fprintf('\n%s\n GD10_CONFIRM2 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, repmat('=', 1, 80));
end

%% ---------------------------------------------------------------------
function ok = fidelity_ticks(f, nmin)
%FIDELITY_TICKS  sec 60.9: every line with check boxes "[ ]" / "[x]" has exactly one ticked; a review
%  line ("... [ ] DUNG [ ] SAI - ghi chu") ticked in its second box (SAI) stops the opening.
%  ASCII patterns only (the file is UTF-8; the box and dash characters are ASCII).
txt = fileread(f);
L = regexp(txt, '\r?\n', 'split');
nb = 0;  bad = {};  sai = {};
for i = 1:numel(L)
    b = regexp(L{i}, '\[([ xX])\]', 'tokens');
    if numel(b) < 2, continue; end
    nb = nb + 1;
    t = cellfun(@(c) c{1} ~= ' ', b);
    if sum(t) ~= 1
        bad{end + 1} = sprintf('line %d: %d box(es) ticked', i, sum(t)); %#ok<AGROW>
    elseif ~isempty(strfind(L{i}, '- ghi ch')) && find(t) == 2
        sai{end + 1} = sprintf('line %d', i); %#ok<AGROW>
    end
end
[~, nm] = fileparts(f);
ok = nb >= nmin && isempty(bad) && isempty(sai);
fprintf('  %-16s %d box lines (expected >= %d), %d not ticked once, %d SAI -> %s\n', nm, nb, nmin, numel(bad), ...
    numel(sai), tern(ok, 'OK', 'NOT MET'));
for k = 1:numel(bad), fprintf('      %s\n', bad{k}); end
for k = 1:numel(sai), fprintf('      SAI at %s - the user decides (sec 60.9)\n', sai{k}); end
end

function ok = approved_line(here, head)
%APPROVED_LINE  sec 60.9: a line starting "APPROVED" with a date yyyy-mm-dd and "commit <hash>" in REGISTER_P2 sec 60
%  (e.g. "APPROVED: Huyhoang   ngay: 2026-10-05 - runner commit abc1234"); that commit an ancestor
%  of HEAD and no change to the code since it.
txt = fileread(fullfile(here, 'docs', 'REGISTER_P2.md'));
k = strfind(txt, '## 60. CONFIRM2');
ok = false;
if isempty(k), fprintf('  APPROVED line: REGISTER_P2 sec 60 not found -> NOT MET\n'); return; end
sec = txt(k(1):end);
m = regexp(sec, '^\**APPROVED[^\n]*?(\d{4}-\d{2}-\d{2})[^\n]*?commit `?([0-9a-f]{7,40})', 'tokens', 'once', ...
    'lineanchors');
if isempty(m), fprintf('  APPROVED line in sec 60: none -> NOT MET\n'); return; end
c = m{2};
s1 = system(sprintf('git merge-base --is-ancestor %s %s', c, head));
s2 = system(sprintf('git diff --quiet %s %s -- core experiments analysis python baseline1.slx', c, head));
ok = s1 == 0 && s2 == 0;
fprintf('  APPROVED %s, runner commit %s: ancestor of HEAD %s, code unchanged since %s -> %s\n', m{1}, c, ...
    tern(s1 == 0, 'yes', 'NO'), tern(s2 == 0, 'yes', 'NO'), tern(ok, 'OK', 'NOT MET'));
end

function ok = code_clean()
[st, out] = system('git status --porcelain -- core experiments analysis python baseline1.slx');
ok = st == 0 && isempty(strtrim(out));
fprintf('  local code changes: %s\n', tern(ok, 'none -> OK', ['PRESENT -> NOT MET' newline out]));
end

function step(k, name)
fprintf('\n%s\n  %d/7 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
