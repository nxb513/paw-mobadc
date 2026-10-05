function E = p2r_E(Z, cols, want)
%P2R_E  Per-segment registered metric (rows.E) of the named columns, n x numel(want).
n = numel(Z.rows);  E = nan(n, numel(want));
for c = 1:numel(want)
    j = find(strcmp(cols, want{c}), 1);
    assert(~isempty(j), 'p2r_E: column %s not in the file.', want{c});
    for i = 1:n, E(i, c) = Z.rows(i).E(j); end
end
end
