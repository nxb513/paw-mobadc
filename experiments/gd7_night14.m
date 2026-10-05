function gd7_night14()
%GD7_NIGHT14  REGISTER_P2 sec 42: the F3 diagnostic (S40hover), then E3, D2-thrust and B3 on S40.
%Sensitivity / diagnostic, not a gate. Run and leave.
%
%   gd7_night14
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged
%  1  F3-diag: S40hover, hover K 0.5, TauPred 0, N6 horizon 280 ms; C_D*A of payload / body scaled
%     separately (0.7, 1.3), L3 with the body part only; DC share and mean N6 delta per column;
%     reproduction of F-hover; reading sec 42.2 - pure diagnosis, no fix tried
%  2  E3: circle on S40, IMU noise x 0 and x 3 (x 1 = D2's rows, printed, nothing run)
%  3  D2-thrust: circle on S40, plant max thrust 20.44 N (F_TOT_MAX 18.396 N)
%  4  B3: circle on S40, plant zeta_s 0.02 and 0.12 (0.05 = D2's rows)
%  Every step resumable; an error in one step is printed and the next one runs.
%  Log results/gd7/night14_*.txt.
S40 = '1db1de02532a3896';
S40H = '53facf03712c81eef9ce2f82b2a054f263657818c5a55ad1e2f22be0249e3116';   % sec 39.1 / 41
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night14_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_NIGHT14 (REGISTER_P2 sec 42: F3 diagnostic, E3, D2-thrust, B3) | git %s | %s\n%s\n', ...
    repmat('=', 1, 80), strtrim(gh), datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
fprintf('\n  0/4 checks: verify_p2_repro, D2 row 1 (i0000) unchanged\n');
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
step(1, 'F3-diag: S40hover, C_D*A payload / body separately, DC share, mean N6 delta');
try
    run_p2_gd7('F3-diag', 'TauW', 0.280, 'TauPred', 0, 'Sha', S40H);
catch err
    fprintf('\n  !!! F3-diag error: %s (continuing)\n', err.message);
end
tab = @(varargin) run_p2_gd6('TAB', 'Only', {'circle'}, 'TauPred', 0.290, 'TauPrev', 0.180, 'Sha', S40, varargin{:});
step(2, 'E3: circle on S40, IMU noise x 0 / x 1 (D2 rows) / x 3');
calls = {{'FromD2', true}, {'Imu', 0}, {'Imu', 3}};
run_calls(tab, calls, 'E3');
step(3, 'D2-thrust: circle on S40, plant max thrust 20.44 N');
run_calls(tab, {{'ThrustMax', 20.44}}, 'D2-thrust');
step(4, 'B3: circle on S40, plant zeta_s 0.02 / 0.05 (D2 rows) / 0.12');
run_calls(tab, {{'Zeta', 0.02}, {'Zeta', 0.12}}, 'B3');
fprintf('\n%s\n GD7_NIGHT14 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end

function run_calls(tab, calls, name)
for k = 1:numel(calls)
    try
        tab(calls{k}{:});
    catch err
        fprintf('\n  !!! %s %s error: %s (continuing)\n', name, strjoin(cellfun(@num2str, calls{k}, ...
            'UniformOutput', false), ' '), err.message);
    end
end
end

function step(k, name)
fprintf('\n%s\n  %d/4 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end
