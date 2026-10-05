function rerun_summary()
%RERUN_SUMMARY  Print every result file of the final run with its row count, and re-print each step's report
%  from the saved rows (the runners' 'Report' modes; no simulation). Used by the report job of final.yml.
root = fullfile(repo_root(), 'results');
f = dir(fullfile(root, '**', '*.mat'));
f = f(cellfun(@isempty, regexp({f.name}, '__s\d+of\d+N\d+\.mat$', 'once')));
fprintf('\n==== result files (%d) ====\n', numel(f));
for k = 1:numel(f)
    p = fullfile(f(k).folder, f(k).name);
    w = whos('-file', p);
    n = NaN;
    if any(strcmp({w.name}, 'rows')), Z = load(p, 'rows'); n = numel(Z.rows);
    elseif any(strcmp({w.name}, 'T')), Z = load(p, 'T'); n = numel(Z.T); end
    fprintf('  %-46s %5s rows\n', strrep(p, [root filesep], ''), num2str(n));
end
fprintf('\n==== horizons ====\n');
for w = {'circle', 'hover', 'T3b', 'square', 'T5', 'circle_L15', 'circle_L05', 'V:circle', 'V:T3b', 'V:square', ...
        'w', 'w6', 'm:square', 'h3'}
    try, final_tau(w{1}); catch err, fprintf('  %-10s not available (%s)\n', w{1}, err.message); end
end
fprintf('\n==== step reports ====\n');
if exist(fullfile(root, 'gd6', 'd2_p2.mat'), 'file') == 2
    try, run_p2_gd6('D2REPORT'); catch err, fprintf('  D2REPORT: %s\n', err.message); end
end
T = rerun_steps();
for k = 1:numel(T)
    if exist(fullfile(root, 'gd7', [T(k).id '.mat']), 'file') == 2
        try, run_p2_gd7(T(k).id, 'Report', true); catch err, fprintf('  %s report: %s\n', T(k).id, err.message); end
    end
end
end
