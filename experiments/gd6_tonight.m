function gd6_tonight(varargin)
%GD6_TONIGHT  One unattended batch for 2026-09-25 (REGISTER_P2 sec 7-8): run and leave.
%
%   gd6_tonight
%   gd6_tonight('SkipBuild', true)     % steps 1-2 already done by hand (same commit): start at 3
%
%  1  rebuild baseline1.slx (standard P2 initial condition, sec 8)        STOP on error
%  2  B1: verify_p2_repro('Quick', true) (when this night ran: v1 verify_repro 32 cells and check_results_numbers),
%     extract_eml --check                                                 STOP on any failure
%  3  commit + push baseline1.slx (a failure here is logged, not fatal)
%  4  circle unchanged, to every printed digit (sec 8.1):                 STOP on any mismatch
%       GD3 S4' i0000 33.37 / 15.24 mm; N0P circle dry-run 0.0334 / 0.0163;
%       D2 dry-run L0 0.0414 L2 0.0334 L3 0.0152 V 0.0152
%  5  sec 8.2 diagnostic: hover and T5 with the standard IC (reading printed)
%  6  night 1: N0P circle, N0V, N0P T3b + square (each step logged; an error in one
%     step is logged and the next step still runs)
%  Everything goes to results/gd6/tonight_<stamp>.txt. Nothing is decided here: the
%  reading of step 5 and the tau* of step 6 are for the user and for REGISTER_P2.

opt = struct('SkipBuild', false);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'gd6_tonight: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd6');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('tonight_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD6_TONIGHT | git %s | %s\n%s\n', repmat('=', 1, 80), strtrim(gh), ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));

if opt.SkipBuild
    fprintf('\n  steps 1-2 skipped (SkipBuild): rebuild + B1 were run by hand at this commit\n');
else
%% 1 rebuild
banner('1/6 rebuild baseline1.slx (build_p2_plant)');
% a power cut (2026-09-25) left a corrupt Simulink cache file in slprj/ ("not a valid
% Simulink cache info file"): slprj/ is generated cache only (git-ignored), so clear it
% before building - Simulink regenerates it
if exist(fullfile(here, 'slprj'), 'dir') == 7
    bdclose('all');
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache, rebuilt by Simulink)\n');
end
try
    build_p2_plant('Save', true);
catch err
    stop_here(sprintf('build failed: %s', err.message), t0);  return
end

%% 2 B1
banner('2/6 B1: verify_p2_repro, extract_eml');
try
    S = verify_p2_repro('Quick', true);
    if ~S.pass, stop_here('verify_p2_repro did NOT reproduce', t0);  return; end
catch err
    stop_here(sprintf('B1 failed: %s', err.message), t0);  return
end
[st, out] = system(sprintf('python "%s" "%s" --check "%s"', fullfile(here, 'tools', 'extract_eml.py'), ...
    fullfile(here, 'baseline1.slx'), fullfile(here, 'simulink_blocks')));
fprintf('%s\n', out);
if st ~= 0, stop_here('extract_eml --check failed', t0);  return; end
end

%% 3 push the model
banner('3/6 commit + push baseline1.slx');
[st, out] = system(['git add baseline1.slx && git commit -m "GD6: P2 standard initial condition ' ...
    '(REGISTER_P2 sec 8) - rebuilt, B1 PASS" && git push origin claude/main-vulnerability-check-hd94m7']);
fprintf('%s\n  (exit %d%s)\n', out, st, tern(st ~= 0, ' - NOT pushed; push by hand later', ''));

%% 4 circle unchanged
banner('4/6 circle unchanged to every printed digit (REGISTER_P2 sec 8.1)');
bad = {};
try
    G3 = run_gd3_stages('Stages', {'S4p'});
    e = [G3.rows.mean_err_mm];
    bad = chk(bad, 'GD3 S4'' i0000 L2/L3 [mm]', e, [33.37 15.24], 2);
    Gn = run_p2_gd6('N0P', 'Only', {'circle'}, 'DryRun', true);
    bad = chk(bad, 'N0P circle dry-run 0/200 ms', Gn.dry(1).R, [0.0334 0.0163], 4);
    Gd = run_p2_gd6('D2', 'TauPred', 0.22, 'TauPrev', 0.12, 'DryRun', true);
    bad = chk(bad, 'D2 dry-run L0 L2 L3 V', Gd.rows(1).E, [0.0414 0.0334 0.0152 0.0152], 4);
catch err
    stop_here(sprintf('circle check could not run: %s', err.message), t0);  return
end
if ~isempty(bad)
    stop_here(sprintf('CIRCLE CHANGED - %s', strjoin(bad, '; ')), t0);  return
end
fprintf('\n  circle: every number reproduced to the printed digit\n');

%% 5 sec 8.2
banner('5/6 sec 8.2 diagnostic: hover and T5 with the standard IC');
try
    run_p2_gd6('ICDIAG');
catch err
    fprintf('\n  !!! ICDIAG error: %s (continuing with night 1)\n', err.message);
end

%% 6 night 1
steps = {{'N0P', 'Only', {'circle'}}, {'N0V'}, {'N0P', 'Only', {'T3b', 'square'}}};
names = {'N0P circle', 'N0V circle', 'N0P T3b + square'};
for k = 1:numel(steps)
    banner(sprintf('6/6 night 1 - %s', names{k}));
    try
        run_p2_gd6(steps{k}{:});
    catch err
        fprintf('\n  !!! %s error: %s (continuing)\n', names{k}, err.message);
    end
end
fprintf('\n%s\n GD6_TONIGHT done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end

%% ---------------------------------------------------------------------
function bad = chk(bad, what, got, want, nd)
%CHK  Equal to the printed digit: round(got, nd) == want.
r = round(got(:)' * 10^nd) / 10^nd;              % printed digits (round(x, n) is MATLAB-only)
ok = numel(got) == numel(want) && all(abs(r - want) < 10^(-nd - 3));
fprintf('  %-32s got %s  expected %s  %s\n', what, mat2str(r), mat2str(want), ...
    tern(ok, 'OK', 'MISMATCH'));
if ~ok, bad{end + 1} = what; end
end

function banner(s)
fprintf('\n%s\n  %s   [%s]\n%s\n', repmat('-', 1, 80), s, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end

function stop_here(msg, t0)
fprintf('\n%s\n  STOPPED: %s\n  nothing after this step was run (%.1f min in)\n%s\n', repmat('!', 1, 80), msg, ...
    toc(t0) / 60, repmat('!', 1, 80));
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
