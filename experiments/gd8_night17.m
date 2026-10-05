function gd8_night17(varargin)
%GD8_NIGHT17  REGISTER_P2 sec 50: INDI (competitor H3, "acceleration-based disturbance estimation of the INDI type
%  (outer loop of Smeur 2018)", sec 40.1) - tuning and the two tables. After night 16, before CONFIRM2. Run and leave.
%
%   gd8_night17
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged; the model holds the H3 block
%  1  N0H3 circle: omega_f in {1 2 4 8 16} Hz on the A4 fixed-5 (one edge extension), argmin -> frozen,
%     read from the saved result (EDGE-UNRESOLVED -> nothing else run)
%  2  H3-circle (circle_main): L1 (no wind sensor, run), L3 (D2, spot-checked), H3
%  3  hover (N6_hover): L3 (N6, spot-checked), H3, and L3_iii (tau_m = 0, sec 52 / D19) only if (iii) was
%     ACCEPTED at night 16b (sec 45.3, both iii-hover and iii-hover-sn); one set + unsaturated subset
%  Log results/gd8/night17_*.txt. omega_f* is printed and transcribed into REGISTER_P2 afterwards.
%
%   gd8_night17('H3Hz', 32)     % REGISTER_P2 sec 56 / D21: omega_f fixed, step 1 skipped (the saved N0H3 grid
%                               % result, EDGE-UNRESOLVED, is kept unchanged)
opt = struct('H3Hz', []);
for k = 1:2:numel(varargin), opt.(varargin{k}) = varargin{k + 1}; end
CM = 'a227e9d87a2ac436';
N6H = '43226c02f081460607d5f98676c57cfa1207e98498ad2919c642af5d717144c7';
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd8');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night17_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD8_NIGHT17 (REGISTER_P2 sec 50: INDI tuning + tables) | git %s | %s\n%s\n', ...
    repmat('=', 1, 80), strtrim(gh), datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7, rmdir(fullfile(here, 'slprj'), 's'); end
fprintf('\n  0/3 checks: verify_p2_repro, D2 row 1, H3 block present\n');
try
    load_system('baseline1');
    assert(getSimulinkBlockHandle('baseline1/Position_Observers/P2_CMP_Sel') > 0, 'P2_CMP_Sel (H3) not in baseline1');
    S = verify_p2_repro('Quick', true);
    assert(S.pass, 'verify_p2_repro did NOT reproduce');
    Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
    assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'D2 row 1 changed');
catch err
    fprintf('\n  STOPPED: %s - nothing else run\n', err.message);
    return
end
if ~isempty(opt.H3Hz)                                   % sec 56 / D21: omega_f fixed by the user, no search
    wf = opt.H3Hz;
    step(1, sprintf('N0H3 skipped: omega_f fixed at %g Hz (REGISTER_P2 sec 56, D21)', wf));
else
    step(1, 'N0H3 circle: omega_f grid {1 2 4 8 16} Hz on the fixed-5');
    try
        run_p2_gd6('N0H3', 'Only', {'circle'});
        Z = load(fullfile(here, 'results', 'gd6', 'n0h3_circle_p2.mat'), 'W');
        assert(Z.W.edge_ok && isfinite(Z.W.best), 'N0H3 is EDGE-UNRESOLVED or has no argmin');
        wf = Z.W.best;
        fprintf('\n  omega_f* = %g Hz (from results/gd6/n0h3_circle_p2.mat) - frozen for both tables\n', wf);
    catch err
        fprintf('\n  STOPPED after step 1: %s\n', err.message);
        return
    end
end
step(2, sprintf('H3-circle: circle_main, L1 / L3 / H3 at %g Hz', wf));
try
    run_p2_gd7('H3-circle', 'TauW', 0.280, 'TauPred', 0.290, 'H3Hz', wf, 'Sha', CM);
catch err
    fprintf('\n  !!! H3-circle error: %s (continuing)\n', err.message);
end
acc = false;
try
    A1 = run_p2_gd7('iii-hover', 'Report', true);        % re-printed from night 16's saved rows
    A2 = run_p2_gd7('iii-hover-sn', 'Report', true);
    acc = isfield(A1, 'holds') && A1.holds && isfield(A2, 'holds') && A2.holds;
catch err
    fprintf('\n  (iii) acceptance not readable (%s) - the (iii) column is left out\n', err.message);
end
grp = 'H3-hover';  xa = {};
if acc
    grp = 'H3-hover-iii';  xa = {'TauM3', 0};          % REGISTER_P2 sec 52 / D19: tau_m = 0, fixed
end
step(3, sprintf('%s: N6_hover, L3 / %sH3 at %g Hz ((iii) %s at night 16)', grp, tern(acc, 'L3_iii / ', ''), wf, ...
    tern(acc, 'ACCEPTED', 'NOT accepted')));
try
    run_p2_gd7(grp, 'TauW', 0.280, 'TauPred', 0, 'H3Hz', wf, 'Sha', N6H, xa{:});
catch err
    fprintf('\n  !!! %s error: %s\n', grp, err.message);
end
fprintf('\n%s\n GD8_NIGHT17 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, repmat('=', 1, 80));
end

function step(k, name)
fprintf('\n%s\n  %d/3 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
