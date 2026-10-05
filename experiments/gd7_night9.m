function gd7_night9()
%GD7_NIGHT9  Exploratory block N6X (REGISTER_P2 sec 28.2): run and leave. Not a gate.
%
%   gd7_night9
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged
%  1  N0M circle: L3_6(tau) on the A4 fixed-5, TauPred 0.290      -> tau_m*(circle)
%  2  N0M T5:     L3_6(tau) on the A4 fixed-5, TauPred 0.170      -> tau_m*(T5)
%  3  N6X-circle: circle_main (SHA a227e9d87a2ac436), L3 (reused from N4b-P2-base after the spot
%     check) + L3_6 at tau_m = 290 ms
%  4  N6X-T5: T5_main (SHA 4a933e516acfcb10), L3 + L3_6 at tau_m = 170 ms
%  5  only where |tau_m* - tau_m| >= 50 ms (sec 28.2): N6X-<traj>-tm, L3_6 at tau_m* (L3 reused)
%  ~260 + 134 + 268 column-runs (~5 h) + step 5 if it applies. Resumable. Log results/gd7/night9_*.txt.
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night9_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_NIGHT9 (N6X, exploratory) | git %s | %s\n%s\n', repmat('=', 1, 80), strtrim(gh), ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
fprintf('\n  0/5 checks: verify_p2_repro, D2 row 1 (i0000) unchanged\n');
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
T = struct('traj', {'circle', 'T5'}, 'pred', {0.290, 0.170}, 'taum', {0.290, 0.170}, ...
    'sha', {'a227e9d87a2ac436', '4a933e516acfcb10'}, 'star', {NaN, NaN});
k = 0;
for i = 1:2
    k = k + 1;
    step(k, sprintf('N0M %s (TauPred %.0f ms)', T(i).traj, 1000 * T(i).pred));
    try
        G = run_p2_gd6('N0M', 'Only', {T(i).traj}, 'TauPred', T(i).pred);
        if G.W.edge_ok, T(i).star = G.W.tau_star; end
    catch err
        fprintf('\n  !!! N0M %s error: %s (continuing)\n', T(i).traj, err.message);
    end
end
for i = 1:2
    k = k + 1;
    grp = ['N6X-' T(i).traj];
    step(k, sprintf('%s (tau_m %.0f ms)', grp, 1000 * T(i).taum));
    try
        run_p2_gd7(grp, 'TauW', 0.020, 'TauPred', T(i).pred, 'TauN6', T(i).taum, 'Sha', T(i).sha);
    catch err
        fprintf('\n  !!! %s error: %s (continuing)\n', grp, err.message);
    end
end
step(5, 'second pass where |tau_m* - tau_m| >= 50 ms (sec 28.2)');
for i = 1:2
    if ~isfinite(T(i).star)
        fprintf('  %s: tau_m* not resolved - no second pass\n', T(i).traj);
    elseif abs(T(i).star - T(i).taum) < 0.050 - 1e-9
        fprintf('  %s: tau_m* %.0f ms within 50 ms of %.0f ms - no second pass\n', T(i).traj, ...
            1000 * T(i).star, 1000 * T(i).taum);
    else
        grp = ['N6X-' T(i).traj '-tm'];
        fprintf('  %s: tau_m* %.0f ms vs %.0f ms -> %s\n', T(i).traj, 1000 * T(i).star, 1000 * T(i).taum, grp);
        try
            run_p2_gd7(grp, 'TauW', 0.020, 'TauPred', T(i).pred, 'TauN6', T(i).star, 'Sha', T(i).sha);
        catch err
            fprintf('\n  !!! %s error: %s (continuing)\n', grp, err.message);
        end
    end
end
fprintf('\n%s\n GD7_NIGHT9 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end

function step(k, name)
fprintf('\n%s\n  %d/5 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end
