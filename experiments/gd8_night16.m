function gd8_night16()
%GD8_NIGHT16  REGISTER_P2 sec 50 (the fixed scope, user 2026-09-30): after the rebuild with (iii) (sec 45) and the
%  weight trim (sec 47); H4 is not built. Run and leave.
%
%   gd8_night16
%
%  0  checks (STOP on failure): the model holds the (iii) and trim blocks; C1 = verify_p2_repro,
%     D2 row 1 (i0000) unchanged, N6 recheck (first N6 segment) bit-exact; C2 + C3 = check_m3_offline (fixed-5)
%  1  N0M3 hover (TauPred 0) -> tau_m*,hover, read from the saved result (EDGE-UNRESOLVED -> steps 2-3 not run)
%  2  iii-hover (S40hover): L3 (reused from F-hover, spot-checked) + (iii) nominal + L +-20 %, m_L +-20 %,
%     payload C_D*A +-30 %, body C_D*A +-30 %
%  3  iii-hover-sn (S40hover, wind_sn010/): the sigma 0.1 variant -> the sec 45.3 acceptance line
%  4  N0M3 circle (TauPred 290 ms) -> tau_m*,circle (EDGE-UNRESOLVED -> step 5 not run)
%  5  iii-circle (S40): no-harm reading of sec 45.7
%  6  GUOTRIM: Classical+trim, DO+trim on circle_main (sec 47)
%  Every step resumable; an error in one step is printed and the next one runs.
%  Log results/gd8/night16_*.txt. tau_m* values are printed and transcribed into REGISTER_P2 afterwards.
S40 = '1db1de02532a3896';
S40H = '53facf03712c81eef9ce2f82b2a054f263657818c5a55ad1e2f22be0249e3116';
CM = 'a227e9d87a2ac436';
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd8');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night16_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD8_NIGHT16 (REGISTER_P2 sec 50: (iii) acceptance, no-harm, weight trim) | git %s | %s\n%s\n', ...
    repmat('=', 1, 80), strtrim(gh), datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
fprintf('\n  0/6 checks: model rebuilt, C1 (verify_p2_repro, D2 row 1, N6 recheck), C2 + C3\n');
try
    load_system('baseline1');
    for b = {'Position_Observers/P2_M3_Sel', 'Position_Observers/P2_M3_DoSel', 'Position_Observers/P2_TRIM_Sel'}
        assert(getSimulinkBlockHandle(['baseline1/' b{1}]) > 0, ['%s not in baseline1 - run ' ...
            'build_p2_plant(''Save'', true) and B1 first'], b{1});
    end
    S = verify_p2_repro('Quick', true);
    assert(S.pass, 'verify_p2_repro did NOT reproduce');
    Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
    fprintf('  D2 i0000 L0 L2 L3 V: got %s expected %s\n', mat2str(got), mat2str(want));
    assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'D2 row 1 changed');
    Z = load(fullfile(here, 'results', 'gd7', 'N6.mat'), 'rows');
    R = run_p2_gd7('N6', 'Recheck', {Z.rows(1).file});
    assert(all([R.same]), 'N6 recheck not bit-exact');
    C = check_m3_offline();
    assert(C.c2_pass, 'C2 (sec 45.3) FAILED - (iii) is not run');
    assert(C.c3_pass, 'C3 (sec 45.3) FAILED - (iii) is not run');
catch err
    fprintf('\n  STOPPED: %s - nothing else run\n', err.message);
    return
end
tmh = tau_m(1, 'hover', 0, here);
if ~isnan(tmh)
    step(2, sprintf('iii-hover: (iii) nominal + 8 parameter variants, tau_m %.0f ms', 1000 * tmh));
    try
        run_p2_gd7('iii-hover', 'TauW', 0.280, 'TauPred', 0, 'TauM3', tmh, 'Sha', S40H);
    catch err
        fprintf('\n  !!! iii-hover error: %s (continuing)\n', err.message);
    end
    step(3, 'iii-hover-sn: the sigma 0.1 variant');
    try
        run_p2_gd7('iii-hover-sn', 'TauW', 0.280, 'TauPred', 0, 'TauM3', tmh, 'Sha', S40H, 'DataDir', 'wind_sn010');
    catch err
        fprintf('\n  !!! iii-hover-sn error: %s (continuing)\n', err.message);
    end
end
tmc = tau_m(4, 'circle', 0.290, here);
if ~isnan(tmc)
    step(5, sprintf('iii-circle: no-harm check, tau_m %.0f ms', 1000 * tmc));
    try
        run_p2_gd7('iii-circle', 'TauW', 0.280, 'TauPred', 0.290, 'TauM3', tmc, 'Sha', S40);
    catch err
        fprintf('\n  !!! iii-circle error: %s (continuing)\n', err.message);
    end
end
step(6, 'GUOTRIM: Classical+trim, DO+trim on circle_main (sec 47)');
try
    run_p2_gd6('GUOTRIM', 'Sha', CM);
catch err
    fprintf('\n  !!! GUOTRIM error: %s\n', err.message);
end
fprintf('\n%s\n GD8_NIGHT16 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, repmat('=', 1, 80));
end

function tm = tau_m(k, traj, tp, here)
%TAU_M  Step k: N0M3 on traj (sec 45.1, the sec 7.1 procedure), then tau_m* from the saved result; NaN (and the
%  dependent step is not run) when the run failed or the minimum is EDGE-UNRESOLVED.
step(k, sprintf('N0M3 %s: tau_m* of the (iii) model, TauPred %.0f ms', traj, 1000 * tp));
tm = NaN;
try
    run_p2_gd6('N0M3', 'Only', {traj}, 'TauPred', tp);
    Z = load(fullfile(here, 'results', 'gd6', sprintf('n0m3_%s_p2.mat', traj)), 'W');
    if Z.W.edge_ok
        tm = Z.W.tau_star;
        fprintf('\n  tau_m*,%s = %.0f ms (from results/gd6/n0m3_%s_p2.mat)\n', traj, 1000 * tm, traj);
    else
        fprintf('\n  !!! N0M3 %s is EDGE-UNRESOLVED - the dependent step is not run\n', traj);
    end
catch err
    fprintf('\n  !!! N0M3 %s error: %s - the dependent step is not run\n', traj, err.message);
end
end

function step(k, name)
fprintf('\n%s\n  %d/6 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end
