function rerun_merge()
%RERUN_MERGE  Merge the parts written by parallel jobs into the files the runners and analysis scripts read.
%
%  (1) results/**/<name>__s<k>of<n>N<N>.mat (core/shard_files.m) -> results/**/<name>.mat: rows of parts 1..n
%      concatenated in order (= the order of one unsharded run); every part must carry the same key and exactly
%      its share of the N segments. A step with a missing or unfinished part is NOT merged (printed); a step
%      reusing it then stops on the missing file.
%  (2) results/gd6/n0p_p2__*.mat (run_p2_gd6 'OutFile') -> results/gd6/n0p_p2.mat: the rows T of every part,
%      one row per (mode, label).
%  Idempotent: run by rerun_run before its steps and by the report job.
root = fullfile(repo_root(), 'results');
if exist(root, 'dir') ~= 7, return; end
d = dir(fullfile(root, '**', '*__s*of*N*.mat'));
d = d(~cellfun(@isempty, regexp({d.name}, '__s\d+of\d+N\d+\.mat$', 'once')));
nm = arrayfun(@(x) fullfile(x.folder, regexprep(x.name, '__s\d+of\d+N\d+\.mat$', '.mat')), d, 'UniformOutput', false);
for u = unique(nm(:))'
    target = u{1};
    [fo, b] = fileparts(target);
    parts = d(strcmp(nm, target));
    tok = regexp({parts.name}, '__s(\d+)of(\d+)N(\d+)\.mat$', 'tokens', 'once');
    kn = cellfun(@(t) str2double(t), tok, 'UniformOutput', false);  kn = vertcat(kn{:});
    n = unique(kn(:, 2));  N = unique(kn(:, 3));
    if numel(n) ~= 1 || numel(N) ~= 1 || ~isequal(sort(kn(:, 1))', 1:n)
        fprintf('  rerun_merge: %s - parts %s of %s present, not merged\n', b, mat2str(sort(kn(:, 1))'), mat2str(n'));
        continue
    end
    rows = [];  key = [];  gits = {};  done = true;
    for k = 1:n
        Z = load(fullfile(fo, sprintf('%s__s%dof%dN%d.mat', b, k, n, N)), 'rows', 'key', 'git');
        want = floor(k * N / n) - floor((k - 1) * N / n);
        if numel(Z.rows) ~= want
            fprintf('  rerun_merge: %s part %d of %d holds %d of its %d segments - not merged\n', b, k, n, ...
                numel(Z.rows), want);
            done = false;  break
        end
        if k == 1, key = Z.key; rows = Z.rows; else
            assert(isequal(Z.key, key), 'rerun_merge: %s part %d has another key.', b, k);
            rows = [rows, Z.rows]; %#ok<AGROW>
        end
        if isfield(Z, 'git'), gits{end + 1} = Z.git; end %#ok<AGROW>
    end
    if ~done, continue; end
    git = strjoin(unique(gits), ',');
    assert(numel(unique({rows.file})) == numel(rows), 'rerun_merge: %s has a segment twice.', b);
    save(target, 'rows', 'key', 'git');
    fprintf('  rerun_merge: %s <- %d parts, %d segments\n', b, n, numel(rows));
end
p = dir(fullfile(root, 'gd6', 'n0p_p2__*.mat'));
if ~isempty(p)
    T = [];
    f0 = fullfile(root, 'gd6', 'n0p_p2.mat');
    if exist(f0, 'file') == 2, Z = load(f0, 'T'); T = Z.T; end
    for k = 1:numel(p)
        Z = load(fullfile(p(k).folder, p(k).name), 'T');
        for j = 1:numel(Z.T)
            if isempty(T), T = Z.T(j); continue; end
            i = find(strcmp({T.mode}, Z.T(j).mode) & strcmp({T.label}, Z.T(j).label), 1);
            if isempty(i), T(end + 1) = Z.T(j); %#ok<AGROW>
            else, assert(isequaln(T(i).tau_star, Z.T(j).tau_star), 'rerun_merge: n0p %s %s differs between parts.', ...
                    Z.T(j).mode, Z.T(j).label); end
        end
    end
    save(f0, 'T');
    fprintf('  rerun_merge: n0p_p2 <- %d part file(s), %d row(s): %s\n', numel(p), numel(T), ...
        strjoin(strcat({T.mode}, ':', {T.label}), ' '));
end
end
