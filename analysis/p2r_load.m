function [Z, cols, ok] = p2r_load(root, f)
%P2R_LOAD  One saved result file (rows + key) and its column names; ok = false if the file is missing.
%  Column names: key.cols (run_p2_gd7 groups), key.ctrl (GUO / GUOTRIM), else L0 L2 L3 V (D2 / TAB rows).
p = fullfile(root, f);
ok = exist(p, 'file') == 2;  Z = [];  cols = {};
if ~ok, return; end
Z = load(p, 'rows', 'key');
if isfield(Z.key, 'cols'), cols = Z.key.cols;
elseif isfield(Z.key, 'ctrl'), cols = Z.key.ctrl;
else, cols = {'L0', 'L2', 'L3', 'V'};
    if isfield(Z.key, 'TauN6'), cols{end + 1} = 'L3_6'; end            % run_p2_gd6 TAB with the N6 term (square)
    if isfield(Z.key, 'Paw') && Z.key.Paw, cols = [cols, {'L3_iii0', 'V_iii0'}]; end   % TAB 'Paw' (rerun/)
end
end
