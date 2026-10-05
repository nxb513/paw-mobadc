function S = verify_p2_repro(varargin)
%VERIFY_P2_REPRO  Re-simulate a few stored P2 results and compare them with the stored values. Replaces the v1 step-0
%  checks (verify_repro, check_results_numbers) of the night scripts after the v1 study was removed (2026-10-04).
%
%  Criteria (REGISTER_P2 sec 65):
%   (a) D2 row 1: UNCHANGED TO THE PRINTED DIGIT (4 decimals in m), the criterion every step 0 used ("D2 row 1
%       unchanged"). results/gd6/d2_p2.mat was written on 2026-09-25 by an earlier build of baseline1.slx; the
%       current build reproduces it to |d| <= 1.04e-7 m in the wind-fed columns (MOBADC exactly), below every
%       printed digit. The largest |d| is printed.
%   (b), (c) Figures 9 and 3: BIT FOR BIT (|d| = 0) - their stored rows were written by the current build.
%
%   S = verify_p2_repro                  % (a) + (b) + (c): 14 simulations, a few minutes
%   S = verify_p2_repro('Quick', true)   % (a) only: 4 simulations (the step 0 of the night scripts)
%
%  (a) D2 row 1: the first development segment of results/gd6/d2_p2.mat, MOBADC, MOBADC-W, PA-MOBADC and
%      MOBADC-W + preview, re-run with the call of run_p2_gd6 D2 (TauPred 0.290 s, TauPrev 0.180 s).
%  (b) Table 5 cells: the Figure 9 segment (REGISTER_P2 sec 63.5), PID, DO, ESO, MOBADC (gd6/guo_p2.mat), INDI-DE and
%      PAW-MOBADC (gd7/six-circle-h3.mat) - the re-run of make_p2_figures, Figure 9.
%  (c) one CONFIRM2 segment: the Figure 3 segment (sec 62.1), MOBADC-W, PA-MOBADC (gd10/D2.mat), PAW-MOBADC and
%      INDI-DE (gd10/C2-circle.mat) - the re-run of make_p2_figures, Figure 3.
%  (b) and (c) call make_p2_figures('Only', [3 9], 'Save', false): the same code that checks the published figures,
%  not a second copy. Their summary line carries the largest |d|; it must read 0. Nothing is written except the
%  Figure 9 time series that make_p2_figures always keeps in results/gd11/ (the same content).
%  check_all runs no simulation, so this is a separate command.
opt = struct('Quick', false, 'Root', fullfile(repo_root(), 'results'));
for i = 1:2:numel(varargin)
    assert(isfield(opt, varargin{i}), 'verify_p2_repro: unknown option ''%s''.', varargin{i});
    opt.(varargin{i}) = varargin{i+1};
end
fprintf('\nverify_p2_repro: stored P2 results re-simulated (D2 row 1 to the printed digit; Figures 3, 9 |d| = 0)\n');
S = struct('pass', false, 'd2', NaN(1, 4), 'fig3', NaN, 'fig9', NaN);

% (a) D2 row 1
Z = load(fullfile(opt.Root, 'gd6', 'd2_p2.mat'), 'rows');
Gd = run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'DryRun', true);
i = find(strcmp({Z.rows.file}, Gd.rows(1).file), 1);
assert(~isempty(i), 'verify_p2_repro: %s is not in gd6/d2_p2.mat.', Gd.rows(1).file);
S.d2 = abs(Gd.rows(1).E - Z.rows(i).E);
nm = p2_names({'L0', 'L2', 'L3', 'V'});
for c = 1:4
    fprintf('  (a) D2 %-20s re-run %.15f  stored %.15f  |d| %.3g\n', nm{c}, Gd.rows(1).E(c), Z.rows(i).E(c), S.d2(c));
end
ok = isequal(round(Gd.rows(1).E, 4), round(Z.rows(i).E, 4));
fprintf('  (a) D2 row 1 to the printed digit (4 decimals): %s; largest |d| %.3g m\n', ...
        char(string(ok)), max(S.d2));

% (b) and (c)
if ~opt.Quick
    F = make_p2_figures('Only', [3 9], 'Save', false);
    for f = F
        dmax = NaN;
        t = regexp(f.msg, 'stored to (\S+) \(max', 'tokens', 'once');
        if f.drawn && ~isempty(t), dmax = str2double(t{1}); end
        if f.fig == 3, S.fig3 = dmax; else, S.fig9 = dmax; end
        lab = 'b';  if f.fig == 3, lab = 'c'; end
        fprintf('  (%s) Figure %d: max |d| = %g  (%s)\n', lab, f.fig, dmax, f.msg);
    end
    ok = ok && S.fig3 == 0 && S.fig9 == 0;
end
S.pass = ok;
if ok
    if opt.Quick
        fprintf('verify_p2_repro: PASS (Quick) - D2 row 1 unchanged to the printed digit; Figures 3 and 9 not run.\n');
    else
        fprintf('verify_p2_repro: PASS - D2 row 1 unchanged to the printed digit; Figures 3 and 9 bit for bit.\n');
    end
else
    fprintf('verify_p2_repro: FAIL - a stored P2 result is not reproduced (or a figure was not drawn).\n');
end
end
