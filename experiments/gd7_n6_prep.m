function gd7_n6_prep()
%GD7_N6_PREP  After the N6 block is built (build_p2_plant('Save', true)): the bit-exact checks,
%then N0W-6 (REGISTER_P2 sec 18.2, 24). Run and leave; STOP (nothing else run) on any failure.
%
%   gd7_n6_prep
%
%  0  v1 unchanged: verify_p2_repro, D2 row 1 (i0000) - as every night
%  1  P2 with the N6 term OFF (p2_n6 = 0) unchanged at FULL precision: every column that was
%     run (not reused) re-run and compared with the saved results:
%       N5-H-StrongRel  wind_real_t150_i0384  (hover, K 0: L3 P O O0)
%       N4b-P2-base     wind_real_t150_i0000  (circle, K 0.5: P O O0 O150)
%     any |d| > 0 or changed flag -> STOP
%  2  N6 term ON, smoke test: run_p2_gd6('N0W6', 'TauPred', 0, 'DryRun', true) - 1 segment of the
%     fixed-5, tau 0 and 200 ms, nothing saved (the path runs end to end)
%  3  N0W-6: run_p2_gd6('N0W6', 'TauPred', 0) -> tau_6* (A4 fixed-5, ~130 column-runs, ~1 h)
%  results/gd7/n6prep_<stamp>.txt holds the whole log.
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('n6prep_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_N6_PREP | git %s | %s\n%s\n', repmat('=', 1, 80), strtrim(gh), ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
try
    fprintf('\n  0/3 v1: verify_p2_repro, D2 row 1 (i0000) unchanged\n');
    S = verify_p2_repro('Quick', true);
    assert(S.pass, 'verify_p2_repro did NOT reproduce');
    Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
    fprintf('  D2 i0000 L0 L2 L3 V: got %s expected %s\n', mat2str(got), mat2str(want));
    assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'D2 row 1 changed');

    fprintf('\n  1/3 P2 with the N6 term OFF: full-precision recheck against the saved results\n');
    R1 = run_p2_gd7('N5-H-StrongRel', 'Recheck', {'wind_real_t150_i0384.mat'});
    R2 = run_p2_gd7('N4b-P2-base', 'Recheck', {'wind_real_t150_i0000.mat'});
    assert(all([R1.same, R2.same]), 'P2 with p2_n6 = 0 is NOT bit-exact');

    fprintf('\n  2/3 N6 term ON: smoke test (dry run, nothing saved)\n');
    run_p2_gd6('N0W6', 'TauPred', 0, 'DryRun', true);
catch err
    fprintf('\n  STOPPED: %s - nothing else run\n', err.message);
    return
end
fprintf('\n%s\n  3/3 N0W-6 (REGISTER_P2 sec 18.2)   [%s]\n%s\n', repmat('-', 1, 80), datestr(now, 'HH:MM:SS'), ...
    repmat('-', 1, 80));
try
    run_p2_gd6('N0W6', 'TauPred', 0);
catch err
    fprintf('\n  !!! N0W-6 error: %s\n', err.message);
end
fprintf('\n%s\n GD7_N6_PREP done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end
