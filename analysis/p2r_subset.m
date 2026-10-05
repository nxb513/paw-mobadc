function [E, day, fl, keep] = p2r_subset(Z, cols, want, sub)
%P2R_SUBSET  Rows of the listed columns and the registered subset (REGISTER_P2 sec 0.2, 26, 60.3):
%  'one' finite in the listed columns; 'one4' finite in every column of the file; 'unsatL3' = 'one' + tilt_sat_frac
%  < 1 % in L3; 'unsatAll' = 'one' + < 1 % in the listed columns; 'unsat4' = 'one4' + < 1 % in every file column.
E = p2r_E(Z, cols, want);
day = {Z.rows.day}';  fl = {Z.rows.file}';
if any(strcmp(sub, {'one4', 'unsat4'}))
    keep = all(isfinite(p2r_E(Z, cols, cols)), 2);
else
    keep = all(isfinite(E), 2);
end
if strncmp(sub, 'unsat', 5)
    tw = want;
    if strcmp(sub, 'unsatL3'), tw = {'L3'}; end
    if strcmp(sub, 'unsat4'), tw = cols; end
    keep = keep & all(p2r_p2(Z, cols, tw, 'tilt_sat_frac') < 0.01, 2);
end
end
