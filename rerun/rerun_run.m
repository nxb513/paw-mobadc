function rerun_run(ids)
%RERUN_RUN  Run steps of rerun_steps() in this MATLAB process, in the given order.
%
%   rerun_run({'D2#1/4', 'D2#2/4'})     % step id, optionally #k/n = part k of n (core/shard_files.m)
%   rerun_run('N0P-circle')
%
%  Merges the parts already present (rerun_merge) first, so a step finds the files of earlier waves. The
%  process gets its own Simulink cache / code-generation folder (several processes can share one checkout)
%  and a log in logs/ (git-ignored). An error in one step is printed and the next step runs; the runners save
%  per segment and resume, so calling rerun_run again continues where it stopped. The model is never saved.
if ischar(ids) || isstring(ids), ids = cellstr(ids); end
here = fileparts(fileparts(mfilename('fullpath')));
cd(here);
setup_path;
tag = matlab.lang.makeValidName(strjoin(ids, '_'));
tag = tag(1:min(end, 60));
cdir = fullfile(tempdir, 'paw_cache', tag);
if ~exist(cdir, 'dir'), mkdir(cdir); end
Simulink.fileGenControl('set', 'CacheFolder', cdir, 'CodeGenFolder', cdir, 'createDir', true);
ldir = fullfile(here, 'logs');
if ~exist(ldir, 'dir'), mkdir(ldir); end
for d = {'gd6', 'gd7'}                                  % run_grid (N0H3) saves without creating its folder;
    rdir = fullfile(here, 'results', d{1});             %  a first-wave job has no results/ at all
    if ~exist(rdir, 'dir'), mkdir(rdir); end
end
diary(fullfile(ldir, sprintf('rerun_%s_%s.txt', tag, datestr(now, 'yyyymmdd_HHMMSS'))));
fprintf('rerun_run %s | MATLAB %s | %s\n', strjoin(ids, ' '), version, datestr(now));
rerun_merge();
T = rerun_steps();
nfail = 0;
for k = 1:numel(ids)
    id = ids{k};  sh = [];                              % 'id' or 'id#k/n' (no optional regexp groups:
    p = strfind(id, '#');                               %  MATLAB and Octave return their tokens differently)
    if ~isempty(p)
        sh = sscanf(id(p(end) + 1:end), '%d/%d').';
        assert(numel(sh) == 2, 'rerun_run: bad part spec in ''%s'' (use id#k/n).', ids{k});
        id = id(1:p(end) - 1);
    end
    j = find(strcmp({T.id}, id), 1);
    assert(~isempty(j), 'rerun_run: unknown step ''%s''.', id);
    fprintf('\n######## [%d/%d] %s | %s\n', k, numel(ids), ids{k}, datestr(now));
    tk = tic;
    try
        T(j).call(sh);
        fprintf('######## %s DONE in %.2f h\n', ids{k}, toc(tk) / 3600);
    catch err
        nfail = nfail + 1;
        fprintf(2, '######## %s FAILED after %.2f h: %s\n', ids{k}, toc(tk) / 3600, err.message);
        for s = 1:min(numel(err.stack), 6)
            fprintf(2, '           at %s:%d\n', err.stack(s).name, err.stack(s).line);
        end
    end
    try, Simulink.sdi.clear; catch, end
end
fprintf('\nrerun_run finished, %d failed | %s\n', nfail, datestr(now));
diary off
if nfail > 0 && ~usejava('desktop'), exit(1); end
end
