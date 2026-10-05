function gd8_night18()
%GD8_NIGHT18  REGISTER_P2 sec 54.3 amended by sec 58 (DEVIATION D20, user decision 2026-09-30): robustness of the new C2, the static
%  (1 + K) body feed-forward (iii-0). After night 17 (INDI), before CONFIRM2. Run and leave.
%
%   gd8_night18
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged; night 17's H3-hover exists at omega_f = 32 Hz
%     (fixed, REGISTER_P2 sec 56 / D21)
%  1  static-hover-k (S40hover): L3 (F-hover), L3_iii0 (iii-hover) reused; K-hat x 0.7 / x 1.3 (factor 1.35 /
%     1.65, read) and the whole factor x 0.7 / x 1.3 (1.05 / 1.95, stress) run (sec 58.1)
%  2  static-indi-bias (S40hover): L3, L3_iii0, H3 reused; H3 with a horizontal accelerometer bias 0.086 / 0.17
%     m/s^2 run (sec 58.2, descriptive)
%  3  static-hover (N6_hover): L3 (N6), H3 (H3-hover) reused; L3_iii0 run -> the hover table L3 / INDI / (iii-0)
%     and the H-static eligibility line (sec 54.3 / 58.1)
%  4  static-circle (S40): L3 (D2) reused; L3_iii0 run -> the no-harm reading
%  Every step resumable; an error in one step is printed and the next one runs. Log results/gd8/night18_*.txt.
S40 = '1db1de02532a3896';
S40H = '53facf03712c81eef9ce2f82b2a054f263657818c5a55ad1e2f22be0249e3116';
N6H = '43226c02f081460607d5f98676c57cfa1207e98498ad2919c642af5d717144c7';
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd8');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night18_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD8_NIGHT18 (REGISTER_P2 sec 54.3 + 58: (iii-0) robustness, INDI bias, D20) | git %s | %s\n%s\n', ...
    repmat('=', 1, 80), strtrim(gh), datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7, rmdir(fullfile(here, 'slprj'), 's'); end
fprintf('\n  0/4 checks: verify_p2_repro, D2 row 1, H3-hover of night 17 at 32 Hz\n');
try
    load_system('baseline1');
    S = verify_p2_repro('Quick', true);
    assert(S.pass, 'verify_p2_repro did NOT reproduce');
    Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
    assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'D2 row 1 changed');
    wf = 32;                                            % REGISTER_P2 sec 56 / D21: omega_f fixed
    H = load(fullfile(here, 'results', 'gd7', 'H3-hover.mat'), 'key', 'rows');
    assert(H.key.H3Hz == wf, 'H3-hover was run at %g Hz, omega_f* is %g Hz', H.key.H3Hz, wf);
    fprintf('  omega_f* = %g Hz; H3-hover has %d segments at that omega_f\n', wf, numel(H.rows));
catch err
    fprintf('\n  STOPPED: %s - nothing else run\n', err.message);
    return
end
step(1, 'static-hover-k: S40hover, K-hat x 0.7 / x 1.3 (read) and factor x 0.7 / x 1.3 (stress)');
try
    run_p2_gd7('static-hover-k', 'TauW', 0.280, 'TauPred', 0, 'Sha', S40H);
catch err
    fprintf('\n  !!! static-hover-k error: %s (continuing)\n', err.message);
end
step(2, sprintf('static-indi-bias: S40hover, H3 with accelerometer bias 0.086 / 0.17 m/s^2 (%g Hz)', wf));
try
    run_p2_gd7('static-indi-bias', 'TauW', 0.280, 'TauPred', 0, 'H3Hz', wf, 'Sha', S40H);
catch err
    fprintf('\n  !!! static-indi-bias error: %s (continuing)\n', err.message);
end
step(3, sprintf('static-hover: N6_hover, L3 / H3 (%g Hz) / L3_iii0', wf));
try
    run_p2_gd7('static-hover', 'TauW', 0.280, 'TauPred', 0, 'H3Hz', wf, 'Sha', N6H);
catch err
    fprintf('\n  !!! static-hover error: %s (continuing)\n', err.message);
end
step(4, 'static-circle: no-harm of (iii-0) on the circle (S40)');
try
    run_p2_gd7('static-circle', 'TauW', 0.280, 'TauPred', 0.290, 'Sha', S40);
catch err
    fprintf('\n  !!! static-circle error: %s\n', err.message);
end
fprintf('\n%s\n GD8_NIGHT18 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, repmat('=', 1, 80));
end

function step(k, name)
fprintf('\n%s\n  %d/4 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end
