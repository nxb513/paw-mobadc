function [files, rows] = p2_fixed5(varargin)
%P2_FIXED5  The 5 fixed segments for P2 blocks (REGISTER_P2 sec 5.3, amendment A4).
%
%   [files, rows] = p2_fixed5()                 % A4: T.stable AND T.U <= U_max(circle, K 0.5)
%   [files, rows] = p2_fixed5('Umax', Inf)      % no filter = REGISTER_ROBUST sec 18.6 exactly
%
%  REGISTER_ROBUST sec 18.3 rule, unchanged: the first T.stable segment of each of 5 stable
%  days at ranks round(linspace(1, n, 5)), in T's own row order, from field_grid_K050.mat -
%  here applied after the stable set is filtered by the A2 circle envelope at K 0.5
%  (U_max = p2_umax(0.5, 0.5, 0.8*1.575^2) = 8.02 m/s). Uses no tracking error.
%  Prints the list, and for every day of the old list that changed, why.
opt = struct('Umax', [], 'Quiet', false, 'T', []);
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'p2_fixed5: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
if isempty(opt.Umax), opt.Umax = p2_umax(0.5, 0.5, 0.8 * 1.575^2); end
if isempty(opt.T)
    Z = load('field_grid_K050.mat', 'T');
    T = Z.T;
else
    T = opt.T;                                      % tests only
end
[files, rows] = pick(T, opt.Umax);
% the rule with the filter off must reproduce REGISTER_ROBUST sec 18.6 (built-in check)
old = pick(T, Inf);
if isempty(opt.T)
    ref = strcat('wind_real_t150_', {'i0000'; 'i0319'; 'i0453'; 'i0715'; 'i0900'}, '.mat');
    assert(isequal(old(:), ref), 'p2_fixed5: the unfiltered rule no longer gives the sec 18.6 list.');
end
if ~opt.Quiet
    fprintf('\n  P2 fixed 5 (REGISTER_P2 sec 5.3): T.stable AND T.U <= %.2f m/s (A2 circle, K 0.5)\n', opt.Umax);
    fprintf('  %d stable days with such a segment -> ranks %s\n', rows(1).n_days, mat2str([rows.day_rank]));
    for j = 1:numel(rows)
        fprintf('    %-30s day %-12s U %5.2f m/s  theta %6.2f deg\n', rows(j).file, rows(j).day, ...
            rows(j).U, rows(j).theta);
    end
    gone = setdiff(old, files);
    for j = 1:numel(gone)
        k = find(strcmp(T.file, gone{j}), 1);
        if T.U(k) > opt.Umax
            why = sprintf('U %.2f > %.2f (outside the A2 circle envelope)', T.U(k), opt.Umax);
        else
            why = 'inside the envelope; the day ranks moved because other days lost all their segments';
        end
        fprintf('  replaced: %-30s %s\n', gone{j}, why);
    end
end
end

function [files, rows] = pick(T, umax)
d = T.day;
if ~iscell(d), d = cellstr(string(d)); end
st = find(logical(T.stable(:)) & T.U(:) <= umax);
ds = d(st);
[~, first] = unique(ds, 'first');
ud = ds(sort(first));                               % days in T's own order ('stable')
assert(numel(ud) >= 5, 'p2_fixed5: only %d days left - cannot spread 5 segments.', numel(ud));
pk = round(linspace(1, numel(ud), 5));
idx = zeros(5, 1);
for j = 1:5
    idx(j) = st(find(strcmp(ds, ud{pk(j)}), 1));
end
files = T.file(idx);
files = files(:);
rows = struct('file', files, 'day', d(idx), 'theta', num2cell(T.theta_deg(idx)), ...
    'U', num2cell(T.U(idx)), 'day_rank', num2cell(pk(:)), 'n_days', numel(ud));
end
