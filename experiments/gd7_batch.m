function gd7_batch(tag, G)
%GD7_BATCH  One unattended GĐ7 night: step 0 checks, then the CỔNG G groups in G, in order.
%
%   gd7_batch('night6', {'N5-A-Weak', 0.290, 'a051c6fdcf0a6be2'; ...})
%
%  G rows: {group, TauPred [s], SHA-256 prefix of the group's set (REGISTER_P2 sec 6.3.1)};
%  tau_w* = 0.020 s (sec 16.1). 0: verify_p2_repro, D2 row 1 unchanged to
%  the printed digit (STOP on failure). Each group in its own try/catch; the log is
%  results/gd7/<tag>_<stamp>.txt. Resumable (the runner skips saved segments).
tau_w = 0.020;
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('%s_%s.txt', tag, datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7 %s | git %s | tau_w* %.0f ms | %s\n%s\n', repmat('=', 1, 80), upper(tag), strtrim(gh), ...
    1000 * tau_w, datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
fprintf('\n  0/%d checks: verify_p2_repro, D2 row 1 (i0000) unchanged\n', size(G, 1));
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
for k = 1:size(G, 1)
    fprintf('\n%s\n  %d/%d %s (TauPred %.0f ms)   [%s]\n%s\n', repmat('-', 1, 80), k, size(G, 1), G{k, 1}, ...
        1000 * G{k, 2}, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
    try
        run_p2_gd7(G{k, 1}, 'TauW', tau_w, 'TauPred', G{k, 2}, 'Sha', G{k, 3});
    catch err
        fprintf('\n  !!! %s error: %s (continuing)\n', G{k, 1}, err.message);
    end
end
fprintf('\n%s\n GD7 %s done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), upper(tag), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end
