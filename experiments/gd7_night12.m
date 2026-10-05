function gd7_night12(sha_hover)
%GD7_NIGHT12  REGISTER_P2 sec 39: F1-F3 on hover (S40hover), then B1 (m_p) and B2 (L) on S40.
%Sensitivity / descriptive, not a gate. Run and leave.
%
%   S = p2_segset('S40hover');      % prints the set and its SHA-256 (dry-run step, sec 39)
%   gd7_night12(S.sha256)            % the night; the runner asserts the set against this SHA
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged
%  1  F-hover: S40hover, hover K 0.5, TauPred 0, N6 horizon 280 ms; L3 and L3_6 reused from N6
%     (spot check), 8 x L3_6 with the controller-side L / m_L / C_D*A scaled (plant nominal)
%  2  B1: circle on S40, m_p 0.25 and 0.65 (TauPred 290, TauPrev 180 ms) + the nominal level (D2's rows)
%  3  B2: circle on S40, L 1.5 (TauPred 260 ms, sec 16.2); N0P circle L 0.5 -> tau*_L0.5; L 0.5 at it
%     (EDGE-UNRESOLVED / failed -> L 0.5 not run, printed)
%  Every step resumable; an error in one step is printed and the next one runs.
%  Log results/gd7/night12_*.txt.
assert(nargin == 1 && numel(sha_hover) >= 16, ['gd7_night12: pass the S40hover SHA printed by ' ...
    'p2_segset(''S40hover'') (sec 39).']);
S40 = '1db1de02532a3896';
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night12_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_NIGHT12 (REGISTER_P2 sec 39: F1-F3 hover, B1, B2) | git %s | %s\n%s\n', repmat('=', 1, 80), ...
    strtrim(gh), datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
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
step(1, 'F-hover (F1-F3): S40hover, L3_6 with scaled controller-side parameters');
try
    run_p2_gd7('F-hover', 'TauW', 0.280, 'TauPred', 0, 'Sha', sha_hover);
catch err
    fprintf('\n  !!! F-hover error: %s (continuing)\n', err.message);
end
step(2, 'B1: circle on S40, m_p 0.25 / 0.5 (nominal, D2 rows) / 0.65');
tab = @(varargin) run_p2_gd6('TAB', 'Only', {'circle'}, 'TauPrev', 0.180, 'Sha', S40, varargin{:});
calls = {{'FromD2', true, 'TauPred', 0.290}, {'MP', 0.25, 'TauPred', 0.290}, {'MP', 0.65, 'TauPred', 0.290}};
for k = 1:numel(calls)
    try
        tab(calls{k}{:});
    catch err
        fprintf('\n  !!! B1 %s error: %s (continuing)\n', strjoin(cellfun(@num2str, calls{k}, 'UniformOutput', false), ' '), ...
            err.message);
    end
end
step(3, 'B2: circle on S40, L 1.5 (tau* 260 ms), N0P L 0.5, L 0.5 at tau*_L0.5');
try
    tab('L', 1.5, 'TauPred', 0.260);
catch err
    fprintf('\n  !!! B2 L 1.5 error: %s (continuing)\n', err.message);
end
tp = NaN;
try
    G = run_p2_gd6('N0P', 'Only', {'circle_L05'});
    j = find(strcmp({G.T.mode}, 'N0P') & strcmp({G.T.label}, 'circle_L05'), 1);
    if ~isempty(j) && G.T(j).edge_ok && isfinite(G.T(j).tau_star), tp = G.T(j).tau_star; end
catch err
    fprintf('\n  !!! N0P circle_L05 error: %s\n', err.message);
end
if isfinite(tp)
    fprintf('\n  -> tau*_L0.5 = %.0f ms\n', 1000 * tp);
    try
        tab('L', 0.5, 'TauPred', tp);
    catch err
        fprintf('\n  !!! B2 L 0.5 error: %s\n', err.message);
    end
else
    fprintf('\n  -> tau*_L0.5 not resolved - L 0.5 not run (sec 39)\n');
end
fprintf('\n%s\n GD7_NIGHT12 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end

function step(k, name)
fprintf('\n%s\n  %d/3 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end
