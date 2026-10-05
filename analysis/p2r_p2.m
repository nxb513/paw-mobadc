function V = p2r_p2(Z, cols, want, field)
%P2R_P2  A p2_summary field (e.g. tilt_sat_frac, theta_rms_stat_deg) per segment and column; NaN where absent.
n = numel(Z.rows);  V = nan(n, numel(want));
for c = 1:numel(want)
    j = find(strcmp(cols, want{c}), 1);
    if isempty(j), continue; end
    for i = 1:n
        p = Z.rows(i).p2;  if iscell(p), p = p{j}; end
        if isstruct(p) && isfield(p, field) && isscalar(p.(field)), V(i, c) = p.(field); end
    end
end
end
