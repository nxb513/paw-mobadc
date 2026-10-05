function gd7_night4(tau_w)
%GD7_NIGHT4  Night 4 (REGISTER_P2 sec 13.4, 15): run and leave.
%
%   gd7_night4(tau_w)        % tau_w = tau_w* [s] from N0W, as transcribed in REGISTER_P2
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged
%  1  N6-M0 offline model check (sec 15.4; no Simulink, a few minutes)
%  2  N4b-P2-base = circle_main (cap 4, SHA a227e9d87a2ac436): P, O(tau_w*), O(0), O(150);
%     L3 reused from D2 after a one-segment printed-digit spot check (sec 15.1); the sec 0.6
%     table and the extended D2 table (sec 7.2)
%  Each step in its own try/catch; results/gd7/night4_<stamp>.txt holds the whole log.
%  Resumable: re-running skips the segments already saved.
assert(nargin == 1 && isscalar(tau_w) && tau_w >= 0 && tau_w <= 1, ...
    'gd7_night4: give tau_w* in seconds, e.g. gd7_night4(0.170).');
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night4_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_NIGHT4 | git %s | tau_w* %.0f ms | %s\n%s\n', repmat('=', 1, 80), strtrim(gh), ...
    1000 * tau_w, datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
% 0 checks (baseline1.slx was re-laid out by build/tidy_layout - layout only): v1 and the
%   circle D2 row must be unchanged to the printed digit, otherwise STOP
fprintf('\n  0/2 checks: verify_p2_repro, D2 row 1 (i0000) unchanged\n');
try
    S = verify_p2_repro('Quick', true);
    assert(S.pass, 'verify_p2_repro did NOT reproduce');
    Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
    fprintf('  D2 i0000 L0 L2 L3 V: got %s expected %s\n', mat2str(got), mat2str(want));
    assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'D2 row 1 changed');
catch err
    fprintf('\n  STOPPED: %s - nothing else run\n', err.message);
    return
end
steps = {@() check_n6_model('TauMs', round(1000 * tau_w)), ...
         @() run_p2_gd7('N4b-P2-base', 'TauW', tau_w, 'TauPred', 0.290, 'Sha', 'a227e9d87a2ac436')};
names = {'N6-M0 offline model check', 'N4b-P2-base (circle_main: P, O, O(0), O(150))'};
for k = 1:numel(steps)
    fprintf('\n%s\n  %d/%d %s   [%s]\n%s\n', repmat('-', 1, 80), k, numel(steps), names{k}, ...
        datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
    try
        steps{k}();
    catch err
        fprintf('\n  !!! %s error: %s (continuing)\n', names{k}, err.message);
    end
end
fprintf('\n%s\n GD7_NIGHT4 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end
