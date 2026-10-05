function gd7_night8(tau6)
%GD7_NIGHT8  CỔNG G #10 N6 (REGISTER_P2 sec 15.4, 18.2, 24, 25): run and leave.
%
%   gd7_night8(0.280)        % tau_6* from N0W-6, as transcribed in REGISTER_P2 sec 25
%
%  0  checks (STOP on failure): verify_p2_repro, D2 row 1 unchanged
%  1  N6-M0 e2 re-reported at tau_6* (sec 18.2; offline, no Simulink, a few minutes)
%  2  N6 group: N6_hover (cap 4, SHA 43226c02...), hover K 0.5, TauPred 0, columns L3_6 P_6 O_6
%     O6_0 L3 (~139 x 5 column-runs, ~5 h). Resumable (results/gd7/N6.mat).
%  results/gd7/night8_<stamp>.txt holds the whole log.
assert(nargin == 1 && isscalar(tau6) && tau6 > 0 && tau6 <= 1, ...
    'gd7_night8: give tau_6* in seconds, e.g. gd7_night8(0.280).');
here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd7');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night8_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD7_NIGHT8 (N6) | git %s | tau_6* %.0f ms | %s\n%s\n', repmat('=', 1, 80), strtrim(gh), ...
    1000 * tau6, datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end
fprintf('\n  0/2 checks: verify_p2_repro, D2 row 1 (i0000) unchanged\n');
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
steps = {@() check_n6_model('TauMs', round(1000 * tau6)), ...
         @() run_p2_gd7('N6', 'TauW', tau6, 'TauPred', 0, ...
             'Sha', '43226c02f081460607d5f98676c57cfa1207e98498ad2919c642af5d717144c7')};
names = {'N6-M0 e2 at tau_6* (offline)', 'N6 group (CỔNG G #10)'};
for k = 1:numel(steps)
    fprintf('\n%s\n  %d/%d %s   [%s]\n%s\n', repmat('-', 1, 80), k, numel(steps), names{k}, ...
        datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
    try
        steps{k}();
    catch err
        fprintf('\n  !!! %s error: %s (continuing)\n', names{k}, err.message);
    end
end
fprintf('\n%s\n GD7_NIGHT8 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end
