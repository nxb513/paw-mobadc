function P = results_provenance(out)
%RESULTS_PROVENANCE  READ ONLY: for each result file of the paper (data/SHA256SUMS.txt), the git revision(s) stored
%  in it and its last-write time - the input of the table "result -> model" (REGISTER_P2 sec 66). The runners save
%  'git' = the commit at the time of the LAST save (rows are saved one by one), so a file resumed across commits
%  shows the last one; any 'git' field found deeper (rows, T, W, G, key) is listed as well.
%
%   P = results_provenance                         % print
%   P = results_provenance('E:\provenance.tsv')    % also write a TSV (file, last write, git revisions)
%
%  Python maps each revision to the baseline1.slx committed at it: tools/model_at_commit.py.
root = repo_root();
L = splitlines(strtrim(fileread(fullfile(root, 'data', 'SHA256SUMS.txt'))));
L = L(~startsWith(L, '#'));
P = struct('file', {}, 'written', {}, 'git', {});
for i = 1:numel(L)
    parts = strsplit(strtrim(L{i}));
    rel = parts{end};                                     % results/gdN/x.mat
    f = fullfile(root, strrep(rel, '/', filesep));
    d = dir(f);
    S = load(f);
    g = unique(find_git(S, 0));
    P(end + 1) = struct('file', rel, 'written', datestr(d.datenum, 'yyyy-mm-dd HH:MM'), ...
                        'git', strjoin(g, ' ')); %#ok<AGROW>
end
fprintf('\nresults_provenance: %d result files of the paper\n', numel(P));
for i = 1:numel(P)
    fprintf('  %-42s  %s  %s\n', P(i).file, P(i).written, P(i).git);
end
if nargin > 0 && ~isempty(out)
    fid = fopen(out, 'w');
    fprintf(fid, 'file\twritten\tgit\n');
    for i = 1:numel(P), fprintf(fid, '%s\t%s\t%s\n', P(i).file, P(i).written, P(i).git); end
    fclose(fid);
    fprintf('  wrote %s\n', out);
end
end

function g = find_git(x, depth)
%FIND_GIT  Every char value of a field named 'git' in x (structs, struct arrays, cells), to depth 4.
g = {};
if depth > 4, return; end
if isstruct(x)
    fn = fieldnames(x);
    for j = 1:numel(x)
        for k = 1:numel(fn)
            v = x(j).(fn{k});
            if strcmp(fn{k}, 'git') && (ischar(v) || isstring(v))
                g{end + 1} = char(v); %#ok<AGROW>
            else
                g = [g, find_git(v, depth + 1)]; %#ok<AGROW>
            end
        end
    end
elseif iscell(x)
    for j = 1:numel(x), g = [g, find_git(x{j}, depth + 1)]; end %#ok<AGROW>
end
end
