function gd7_night5()
%GD7_NIGHT5  Night 5 (REGISTER_P2 sec 13.4, 15.3; tau values from sec 9.2, 16): run and leave.
%
%   gd7_night5
%
%  tau_w* = 0.020 s (sec 16.1), TauPred 0.290 s (circle, sec 9.2), 0.260 s (L 1.5, sec 16.2)
%  - written here literally, as transcribed in REGISTER_P2.
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged
%  1  N4b-P2-d200  circle_main, sensor delay 200 ms: L3, P run; O, O(0) reused from
%     N4b-P2-base after a one-segment spot check (sec 15.1)            ~268 runs
%  2  N4b-P2-L15   circle_main, L 1.5, TauPred 0.260: L3, P, O, O(0)   ~536 runs
%  3  N4b-P2-K10   set N4b-P2-K10 (132 segments), K 1.0: L3, P, O, O(0)  ~528 runs
%  Each step in its own try/catch; results/gd7/night5_<stamp>.txt holds the whole log.
%  Resumable: re-running skips the segments already saved (stop in the morning, resume later).
tau_w = 0.020;
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night5_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_NIGHT5 | git %s | tau_w* %.0f ms | %s\n%s\n', repmat('=', 1, 80), strtrim(gh), ...
    1000 * tau_w, datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
% 0 checks (baseline1.slx was re-laid out by build/tidy_layout - layout only): v1 and the
%   circle D2 row must be unchanged to the printed digit, otherwise STOP
fprintf('\n  0/3 checks: verify_p2_repro, D2 row 1 (i0000) unchanged\n');
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
sha_main = 'a227e9d87a2ac436';  sha_k10 = '03fae8f8a845cb5b';     % REGISTER_P2 sec 6.3.1
steps = {@() run_p2_gd7('N4b-P2-d200', 'TauW', tau_w, 'TauPred', 0.290, 'Sha', sha_main), ...
         @() run_p2_gd7('N4b-P2-L15',  'TauW', tau_w, 'TauPred', 0.260, 'Sha', sha_main), ...
         @() run_p2_gd7('N4b-P2-K10',  'TauW', tau_w, 'TauPred', 0.290, 'Sha', sha_k10)};
names = {'N4b-P2-d200 (sensor delay 200 ms)', 'N4b-P2-L15 (L 1.5, TauPred 260 ms)', ...
         'N4b-P2-K10 (K 1.0)'};
for k = 1:numel(steps)
    fprintf('\n%s\n  %d/%d %s   [%s]\n%s\n', repmat('-', 1, 80), k, numel(steps), names{k}, ...
        datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
    try
        steps{k}();
    catch err
        fprintf('\n  !!! %s error: %s (continuing)\n', names{k}, err.message);
    end
end
fprintf('\n%s\n GD7_NIGHT5 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end
