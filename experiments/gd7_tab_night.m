function gd7_tab_night(traj)
%GD7_TAB_NIGHT  One trajectory table (REGISTER_P2 sec 6.4; T3b sec 32): run and leave. Not a gate.
%
%   gd7_tab_night('T3b')        % night 10 (sec 32)
%   gd7_tab_night('square')     % night 11 (sec 33)
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged
%  1  N0V <traj>: tau_prev* of column V on the A4 fixed-5 (the N0P procedure, g_sens, TauPrev)
%  2  square only (sec 33): N0M square - tau_m* of the N6 term (column L3_6, measured wind) on the
%     A4 fixed-5, TauPred = tau*_square
%  3  TAB <traj>: <traj>_main, cap 4, SHA checked; L0 L2 L3 V (+ L3_6 at tau_m*, square);
%     TauPred = tau*_<traj> (sec 9.2); TauPrev = tau_prev*(<traj>) from step 1, or - if step 1 is
%     EDGE-UNRESOLVED / failed - the circle's 180 ms, printed as such (sec 32). L3_6 (sec 33): at
%     tau_m* if resolved and > 0; tau_m* = 0 -> L3_6 = L3 by construction, not run; unresolved /
%     failed -> not run; either printed as such.
%  Resumable (N0V row in results/gd6/n0p_p2.mat; table in results/gd6/tab_<traj>_p2.mat).
%  Log results/gd7/tab_<traj>_*.txt.
R = struct('T3b', struct('pred', 0.340, 'sha', '35bed7710bf224ee', 'sec', '32', 'n6', false), ...
           'square', struct('pred', 0.120, 'sha', 'a227e9d87a2ac436', 'sec', '33', 'n6', true));
assert(isfield(R, traj), 'gd7_tab_night: %s has no registered block.', traj);
r = R.(traj);
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('tab_%s_%s.txt', traj, datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_TAB_NIGHT %s (REGISTER_P2 sec %s, descriptive) | git %s | %s\n%s\n', repmat('=', 1, 80), ...
    traj, r.sec, strtrim(gh), datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
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
step(1, sprintf('N0V %s (tau_prev* of column V, A4 fixed-5)', traj));
tprev = NaN;
try
    G = run_p2_gd6('N0V', 'Only', {traj});
    j = find(strcmp({G.T.mode}, 'N0V') & strcmp({G.T.label}, traj), 1);
    if ~isempty(j) && G.T(j).edge_ok && isfinite(G.T(j).tau_star), tprev = G.T(j).tau_star; end
catch err
    fprintf('\n  !!! N0V %s error: %s (continuing)\n', traj, err.message);
end
if isfinite(tprev)
    fprintf('\n  -> TauPrev for V = tau_prev*(%s) = %.0f ms\n', traj, 1000 * tprev);
else
    tprev = 0.180;
    fprintf('\n  -> tau_prev*(%s) not resolved: V runs at the circle''s 180 ms (sec 32), reported as such\n', traj);
end
tm = [];
if r.n6
    step(2, sprintf('N0M %s (tau_m* of the N6 term, TauPred %.0f ms)', traj, 1000 * r.pred));
    try
        G = run_p2_gd6('N0M', 'Only', {traj}, 'TauPred', r.pred);
        if G.W.edge_ok && isfinite(G.W.tau_star) && G.W.tau_star > 0
            tm = G.W.tau_star;
            fprintf('\n  -> L3_6 at tau_m* = %.0f ms\n', 1000 * tm);
        elseif G.W.edge_ok && G.W.tau_star == 0
            fprintf('\n  -> tau_m* = 0: L3_6 = L3 by construction - not run (h_model = 0 by construction, sec 33)\n');
        else
            fprintf('\n  -> tau_m* not resolved - L3_6 not run (sec 33)\n');
        end
    catch err
        fprintf('\n  !!! N0M %s error: %s - L3_6 not run (continuing)\n', traj, err.message);
    end
else
    step(2, sprintf('(no N6 column for %s - sec %s)', traj, r.sec));
end
step(3, sprintf('TAB %s (TauPred %.0f ms, TauPrev %.0f ms%s)', traj, 1000 * r.pred, 1000 * tprev, ...
    tern(isempty(tm), '', sprintf(', TauN6 %.0f ms', 1000 * tm))));
try
    run_p2_gd6('TAB', 'Only', {traj}, 'TauPred', r.pred, 'TauPrev', tprev, 'TauN6', tm, 'Sha', r.sha);
catch err
    fprintf('\n  !!! TAB %s error: %s\n', traj, err.message);
end
fprintf('\n%s\n GD7_TAB_NIGHT %s done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), traj, toc(t0) / 3600, ...
    logf, repmat('=', 1, 80));
end

function step(k, name)
fprintf('\n%s\n  %d/3 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
