function gd6_night2()
%GD6_NIGHT2  Night 2 of GD6 (REGISTER_P2 sec 7.2, sec 9.2): run and leave.
%
%   gd6_night2
%
%  1  D2 main table, first pass: circle_main (cap 4, SHA a227e9d87a2ac436), columns
%     L0 L2 L3 V, TauPred 0.290 s (tau*_circle, sec 9.2), TauPrev 0.180 s (N0V) -
%     the values transcribed in REGISTER_P2 sec 9.2, written here literally
%  2  N0P hover, then N0P T5 (both enter GD6, sec 9.1)
%  Each step in its own try/catch (an error is logged, the next step still runs);
%  results/gd6/night2_<stamp>.txt holds the whole log. Resumable: re-running skips the
%  D2 segments and N0P conditions already saved.

here = repo_root();
cd(here);
outd = fullfile(here, 'results', 'gd6');
if ~exist(outd, 'dir'), mkdir(outd); end
logf = fullfile(outd, sprintf('night2_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
diary(logf);
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
[~, gh] = system('git rev-parse --short HEAD');
t0 = tic;
fprintf('\n%s\n GD6_NIGHT2 | git %s | %s\n%s\n', repmat('=', 1, 80), strtrim(gh), ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), repmat('=', 1, 80));
% generated Simulink cache only (git-ignored): a power cut left a corrupt file in it
bdclose('all');
if exist(fullfile(here, 'slprj'), 'dir') == 7
    rmdir(fullfile(here, 'slprj'), 's');
    fprintf('  cleared slprj/ (generated cache)\n');
end

steps = {{'D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'Sha', 'a227e9d87a2ac436'}, ...
         {'N0P', 'Only', {'hover'}}, ...
         {'N0P', 'Only', {'T5'}}};
names = {'D2 first pass (L0 L2 L3 V, circle_main cap 4)', 'N0P hover', 'N0P T5'};
for k = 1:numel(steps)
    fprintf('\n%s\n  %d/%d %s   [%s]\n%s\n', repmat('-', 1, 80), k, numel(steps), names{k}, ...
        datestr(now, 'HH:MM:SS'), repmat('-', 1, 80));
    try
        run_p2_gd6(steps{k}{:});
    catch err
        fprintf('\n  !!! %s error: %s (continuing)\n', names{k}, err.message);
    end
end
fprintf('\n%s\n GD6_NIGHT2 done in %.1f h | log %s\n%s\n', repmat('=', 1, 80), toc(t0) / 3600, logf, ...
    repmat('=', 1, 80));
end
