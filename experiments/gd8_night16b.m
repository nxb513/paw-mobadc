function gd8_night16b()
%GD8_NIGHT16B  REGISTER_P2 sec 52 (DEVIATION D19, user decision 2026-09-30): the (iii) runs of night 16 again, with
%  tau_m = 0 fixed on hover and circle (night 16's N0M3 was EDGE-UNRESOLVED on both, sec 51). Run and leave.
%
%   gd8_night16b
%
%  0  checks (STOP on failure): the model holds the (iii) block; verify_p2_repro, D2 row 1
%     (i0000) unchanged; C2 + C3 = check_m3_offline (fixed-5)
%  1  iii-hover (S40hover): L3 (reused from F-hover) + (iii) nominal + the 8 variants of sec 45.3 + (iii-0)
%  2  iii-hover-sn (S40hover, wind_sn010/): the sigma 0.1 variant -> the sec 45.3 acceptance line
%  3  iii-circle (S40): the no-harm reading of sec 45.7, reported as it comes
%  Every step resumable; an error in one step is printed and the next one runs. Log results/gd8/night16b_*.txt.
TAUM = 0;                                               % sec 52 / D19: fixed, no search
S40 = '1db1de02532a3896';
S40H = '53facf03712c81eef9ce2f82b2a054f263657818c5a55ad1e2f22be0249e3116';
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd8');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night16b_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD8_NIGHT16B (REGISTER_P2 sec 52: (iii) at tau_m = 0, D19) | git %s | %s\n%s\n', ...
    repmat('=', 1, 80), strtrim(gh), datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
fprintf('\n  0/3 checks: (iii) block, verify_p2_repro, D2 row 1, C2 + C3\n');
try
    load_system('baseline1');
    for b = {'Position_Observers/P2_M3_Sel', 'Position_Observers/P2_M3_DoSel'}
        assert(getSimulinkBlockHandle(['baseline1/' b{1}]) > 0, '%s not in baseline1', b{1});
    end
    S = verify_p2_repro('Quick', true);
    assert(S.pass, 'verify_p2_repro did NOT reproduce');
    Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
    fprintf('  D2 i0000 L0 L2 L3 V: got %s expected %s\n', mat2str(got), mat2str(want));
    assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'D2 row 1 changed');
    C = check_m3_offline();
    assert(C.c2_pass, 'C2 (sec 45.3) FAILED - (iii) is not run');
    assert(C.c3_pass, 'C3 (sec 45.3) FAILED - (iii) is not run');
catch err
    fprintf('\n  STOPPED: %s - nothing else run\n', err.message);
    return
end
step(1, 'iii-hover: (iii) nominal + 8 parameter variants + (iii-0), tau_m 0 ms');
try
    run_p2_gd7('iii-hover', 'TauW', 0.280, 'TauPred', 0, 'TauM3', TAUM, 'Sha', S40H);
catch err
    fprintf('\n  !!! iii-hover error: %s (continuing)\n', err.message);
end
step(2, 'iii-hover-sn: the sigma 0.1 variant, tau_m 0 ms');
try
    run_p2_gd7('iii-hover-sn', 'TauW', 0.280, 'TauPred', 0, 'TauM3', TAUM, 'Sha', S40H, 'DataDir', 'wind_sn010');
catch err
    fprintf('\n  !!! iii-hover-sn error: %s (continuing)\n', err.message);
end
step(3, 'iii-circle: no-harm check (sec 45.7), tau_m 0 ms');
try
    run_p2_gd7('iii-circle', 'TauW', 0.280, 'TauPred', 0.290, 'TauM3', TAUM, 'Sha', S40);
catch err
    fprintf('\n  !!! iii-circle error: %s\n', err.message);
end
fprintf('\n%s\n GD8_NIGHT16B done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, repmat('=', 1, 80));
end

function step(k, name)
fprintf('\n%s\n  %d/3 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end
