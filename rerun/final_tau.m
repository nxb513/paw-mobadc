function [v, info] = final_tau(what)
%FINAL_TAU  A horizon of the final run, read from the sweep saved by an earlier step (docs/REGISTER_FINAL.md sec 3).
%
%   final_tau('circle')       % N0P payload tau* [s]; also 'hover', 'T3b', 'square', 'T5', 'circle_L15', 'circle_L05'
%   final_tau('V:circle')     % N0V preview tau_prev* [s]; also 'V:T3b', 'V:square'
%   final_tau('w')            % N0W oracle wind horizon tau_w* [s]
%   final_tau('w6')           % N0W-6 horizon tau_6* [s]
%   final_tau('m:square')     % N0M horizon of the N6 term on the square [s]
%   final_tau('h3')           % N0H3 INDI filter cut-off omega_f* [Hz]
%
%  Rule, fixed before any sweep ran: the value the registered procedure returns (REGISTER_P2 sec 7.1 / 13.1 / 18.2 /
%  33 / 40.1). If the procedure leaves it EDGE-UNRESOLVED or NaN, the evaluated value with the smallest pooled error
%  (the best value tried - the choice of D21) is used and the flag is printed. A sweep that has not run is an error.
d = fullfile(repo_root(), 'results', 'gd6');
info = struct('what', what, 'rule', 'procedure', 'edge_ok', true);
if any(strcmp(what, {'w', 'w6', 'm:square'}))
    f = fullfile(d, [tern(strcmp(what, 'w'), 'n0w_p2', tern(strcmp(what, 'w6'), 'n0w6_p2', 'n0m_square_p2')) '.mat']);
    assert(exist(f, 'file') == 2, 'final_tau %s: %s not found - run the sweep first.', what, f);
    Z = load(f, 'W');  W = Z.W;
    v = W.tau_star;  info.edge_ok = W.edge_ok;
    if ~(isfinite(v) && W.edge_ok), [~, k] = min(W.pooled);  v = W.grid(k);  info.rule = 'best tried'; end
elseif strcmp(what, 'h3')
    f = fullfile(d, 'n0h3_circle_p2.mat');
    assert(exist(f, 'file') == 2, 'final_tau h3: %s not found - run N0H3 first.', f);
    Z = load(f, 'W');  W = Z.W;
    v = W.best;  info.edge_ok = W.edge_ok;
    if ~(isfinite(v) && W.edge_ok), [~, k] = min(W.pooled);  v = W.grid(k);  info.rule = 'best tried'; end
else
    f = fullfile(d, 'n0p_p2.mat');
    assert(exist(f, 'file') == 2, 'final_tau %s: %s not found - run N0P / N0V first.', what, f);
    Z = load(f, 'T');  T = Z.T;
    mode = 'N0P';  lab = what;
    if strncmp(what, 'V:', 2), mode = 'N0V';  lab = what(3:end); end
    j = find(strcmp({T.mode}, mode) & strcmp({T.label}, lab), 1);
    assert(~isempty(j), 'final_tau %s: no %s row for %s in %s.', what, mode, lab, f);
    v = T(j).tau_star;  info.edge_ok = T(j).edge_ok;
    if ~(isfinite(v) && T(j).edge_ok)
        tt = [T(j).coarse.tau, T(j).fine.tau];  R = [T(j).coarse.R, T(j).fine.R];
        [~, k] = min(R);  v = tt(k);  info.rule = 'best tried';
    end
end
assert(isfinite(v), 'final_tau %s: no finite value.', what);
fprintf('  final_tau %-10s = %g (%s%s)\n', what, v, info.rule, tern(info.edge_ok, '', ', EDGE-UNRESOLVED'));
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
