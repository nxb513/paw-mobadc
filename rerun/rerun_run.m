function rerun_run(ids)
%RERUN_RUN  Run the given steps of rerun_steps() in this MATLAB process, in the given order.
%
%   rerun_run({'D2', 'six-circle-h3'})      % ids of rerun_steps
%   rerun_run('D2')
%
%  The process gets its own Simulink cache / code-generation folder (several processes can share one
%  checkout), and a log in logs/ (git-ignored). An error in one step is printed and the next step runs;
%  the runners save per segment and resume, so calling rerun_run again continues where it stopped.
%  The model is never saved.
if ischar(ids) || isstring(ids), ids = cellstr(ids); end
here = fileparts(fileparts(mfilename('fullpath')));
cd(here);
setup_path;
tag = matlab.lang.makeValidName(strjoin(ids, '_'));
cdir = fullfile(tempdir, 'paw_cache', tag);
if ~exist(cdir, 'dir'), mkdir(cdir); end
Simulink.fileGenControl('set', 'CacheFolder', cdir, 'CodeGenFolder', cdir, 'createDir', true);
ldir = fullfile(here, 'logs');
if ~exist(ldir, 'dir'), mkdir(ldir); end
diary(fullfile(ldir, sprintf('rerun_%s_%s.txt', tag(1:min(end, 60)), datestr(now, 'yyyymmdd_HHMMSS'))));
fprintf('rerun_run %s | MATLAB %s | %s\n', strjoin(ids, ' '), version, datestr(now));
T = rerun_steps();
nfail = 0;
for k = 1:numel(ids)
    j = find(strcmp({T.id}, ids{k}), 1);
    assert(~isempty(j), 'rerun_run: unknown step ''%s''.', ids{k});
    fprintf('\n######## [%d/%d] %s | %s\n', k, numel(ids), ids{k}, datestr(now));
    tk = tic;
    try
        T(j).call();
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
