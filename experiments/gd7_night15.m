function gd7_night15()
%GD7_NIGHT15  REGISTER_P2 sec 46: wind-sensor noise 0.1 m/s (sec 43.3), the 2^2 payload x cable corners
%(S40), and Guo's four controllers on circle_main. Sensitivity / descriptive, not a gate. Run and leave.
%
%   gd7_night15                 % after the export of sec 43.3 (sn_export_cmds) into wind_sn010/
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged; wind_sn010/ holds
%     the 51 files of S40 + S40hover
%  1  SN: circle S40 (L0 L2 L3 V; L0 = D2 check) and S40hover (L3, L3_6), wind sensor sigma 0.1 m/s
%  2  corners: (m_p, L) = (0.25, 0.5) (0.25, 1.5) (0.65, 0.5) (0.65, 1.5), circle S40, TauPred tau*_L
%     (330 / 260 ms), TauPrev 180 ms; envelope of each corner's m_p; Weak / Medium split
%  3  GUO: Classical / ESO / DO / MOBADC on circle_main (MOBADC = D2 L0 check), Table 1 layout, error split by
%     axis (sec 46.5: horizontal / vertical RMS, mean e_z)
%  Every step resumable; an error in one step is printed and the next one runs.
%  Log results/gd7/night15_*.txt.
S40 = '1db1de02532a3896';
S40H = '53facf03712c81eef9ce2f82b2a054f263657818c5a55ad1e2f22be0249e3116';
CM = 'a227e9d87a2ac436';
SNDIR = 'wind_sn010';
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night15_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_NIGHT15 (REGISTER_P2 sec 46: SN sigma 0.1, 2^2 corners, Guo controllers) | git %s | %s\n%s\n', ...
    repmat('=', 1, 80), strtrim(gh), datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
fprintf('\n  0/3 checks: verify_p2_repro, D2 row 1 (i0000) unchanged, %s/ complete\n', SNDIR);
try
    S = verify_p2_repro('Quick', true);
    assert(S.pass, 'verify_p2_repro did NOT reproduce');
    Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
    got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
    fprintf('  D2 i0000 L0 L2 L3 V: got %s expected %s\n', mat2str(got), mat2str(want));
    assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'D2 row 1 changed');
    C = sn_export_cmds(SNDIR);
    need = [arrayfun(@(i) sprintf('wind_real_t150_i%04d.mat', i), C.real, 'UniformOutput', false), ...
            arrayfun(@(i) sprintf('wind_expl_t150_i%04d.mat', i), C.expl, 'UniformOutput', false)];
    miss = need(~cellfun(@(f) exist(fullfile(here, SNDIR, f), 'file') == 2, need));
    assert(isempty(miss), '%d of %d noisy files missing in %s/ (first: %s) - run the export first', ...
        numel(miss), numel(need), SNDIR, strjoin(miss(1:min(end, 1)), ''));
    fprintf('  %s/: all %d files present\n', SNDIR, numel(need));
catch err
    fprintf('\n  STOPPED: %s - nothing else run\n', err.message);
    return
end
step(1, 'SN: wind sensor sigma 0.1 m/s - circle S40 (L0 = D2 check) and S40hover');
try
    run_p2_gd6('TAB', 'Only', {'circle'}, 'DataDir', SNDIR, 'TauPred', 0.290, 'TauPrev', 0.180, 'Sha', S40);
catch err
    fprintf('\n  !!! SN circle error: %s (continuing)\n', err.message);
end
try
    run_p2_gd7('SN-hover', 'TauW', 0.280, 'TauPred', 0, 'Sha', S40H, 'DataDir', SNDIR);
catch err
    fprintf('\n  !!! SN hover error: %s (continuing)\n', err.message);
end
step(2, '2^2 corners m_p {0.25, 0.65} x L {0.5, 1.5}, circle S40');
K = {0.25, 0.5, 0.330; 0.25, 1.5, 0.260; 0.65, 0.5, 0.330; 0.65, 1.5, 0.260};
for k = 1:size(K, 1)
    try
        run_p2_gd6('TAB', 'Only', {'circle'}, 'MP', K{k, 1}, 'L', K{k, 2}, 'TauPred', K{k, 3}, 'TauPrev', 0.180, 'Sha', S40);
    catch err
        fprintf('\n  !!! corner m_p %.2f L %.1f error: %s (continuing)\n', K{k, 1}, K{k, 2}, err.message);
    end
end
step(3, 'GUO: Classical / ESO / DO / MOBADC on circle_main');
try
    run_p2_gd6('GUO', 'Sha', CM);
catch err
    fprintf('\n  !!! GUO error: %s\n', err.message);
end
fprintf('\n%s\n GD7_NIGHT15 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, repmat('=', 1, 80));
end

function step(k, name)
fprintf('\n%s\n  %d/3 %s   [%s]\n%s\n', repmat('-', 1, 80), k, name, datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
end
