function gd6_night3()
%GD6_NIGHT3  Night 3 (REGISTER_P2 sec 13.1, 13.3): run and leave.
%
%   gd6_night3
%
%  0  checks (STOP on failure): verify_p2_repro('Quick', true) (when this night ran: the v1 checks verify_repro +
%     check_results_numbers, removed with v1 on 2026-10-04); D2 dry-run on i0000 reproduces night 2's first row
%     to the printed digit (L0 0.0414 L2 0.0334 L3 0.0140 V 0.0136) with PredDelay on
%  1  N0W: oracle wind horizon tau_w*, A4 fixed-5, TauPred 0.290 s (sec 9.2, written here
%     literally), oracle construction check first
%  2  N0P circle L 1.5 (tau* for N4b-P2-L15)
%  Steps 1-2 each in its own try/catch; results/gd6/night3_<stamp>.txt holds the whole log.
%  Resumable: re-running skips the tau_w points and N0P conditions already saved.

here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd6');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night3_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD6_NIGHT3 | git %s | %s\n%s\n', repmat('=', 1, 80), strtrim(gh), ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end

%% 0 checks
banner('0/2 checks: verify_p2_repro, D2 row 1 unchanged');
try
    S = verify_p2_repro('Quick', true);
    if ~S.pass, stop_here('verify_p2_repro did NOT reproduce', t0);  return; end
    Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;       % printed digits (round(x, n) is MATLAB-only)
    want = [0.0414 0.0334 0.0140 0.0136];
    fprintf('  D2 i0000 L0 L2 L3 V: got %s expected %s\n', mat2str(got), mat2str(want));
    if ~(numel(got) == 4 && all(abs(got - want) < 1e-7))
        stop_here('D2 row 1 changed with PredDelay on', t0);  return
    end
catch err
    stop_here(sprintf('checks could not run: %s', err.message), t0);  return
end

steps = {{'N0W', 'TauPred', 0.290}, {'N0P', 'Only', {'circle_L15'}}};
names = {'N0W (tau_w*, A4 fixed-5)', 'N0P circle L 1.5'};
for k = 1:numel(steps)
    banner(sprintf('%d/2 %s', k, names{k}));
    try
        run_p2_gd6(steps{k}{:});
    catch err
        fprintf('\n  !!! %s error: %s (continuing)\n', names{k}, err.message);
    end
end
fprintf('\n%s\n GD6_NIGHT3 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end

function banner(s)
fprintf('\n%s\n  %s   [%s]\n%s\n', repmat('-', 1, 80), s, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end

function stop_here(msg, t0)
fprintf('\n%s\n  STOPPED: %s\n  nothing after this step was run (%.1f min in)\n%s\n', repmat('!', 1, 80), msg, ...
    toc(t0) / 60, repmat('!', 1, 80));
end
