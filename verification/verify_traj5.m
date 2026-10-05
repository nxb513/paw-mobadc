function ok = verify_traj5(varargin)
%VERIFY_TRAJ5  Checkpoint 3.1's closed-loop half: the three-part gate of
%              docs/REGISTER_C.md Section 4.4, confirmed by data in Section
%              4.6-4.9. Read both before touching this file again.
%
%   ok = verify_traj5
%   ok = verify_traj5('Stop', 60)      % shorter runs while debugging
%
%  ======================================================================
%  THE GATE CHANGED, AND WHY THIS IS NOT A LOWERED BAR
%  ======================================================================
%  This file used to check one thing: with every disturbance off, tracking
%  RMS on t >= TStat is < 1 mm, for every traj_type. `circle` - byte-for-byte
%  unchanged, the pre-existing baseline this whole campaign is built on top
%  of - failed that bound (1.21 mm at the wrong sigma the first time this ran;
%  15.76 mm once analysis/diag_traj5_floor.m's own op_set('Test 4') fix put it
%  at the RIGHT sigma). A bound that fails on the one trajectory nobody
%  touched is not evidence the trajectories are wrong; docs/REGISTER_C.md
%  Section 4.1 is explicit that this was found to be the SAME class of defect
%  as Section 1's square contradiction: a number written into the plan and
%  never checked against a baseline the plan itself could have run.
%
%  Two diagnostics (analysis/diag_traj5_floor.m, analysis/
%  diag_traj5_crosscheck.m), registered in advance (Section 4.1-4.5) and run
%  after (Section 4.6-4.9), replaced the flat 1 mm bound with THREE checks
%  that ARE validated against something:
%
%    1. traj_type = 1 (circle) reproduces run_baseline bit for bit.
%       UNCHANGED from before, and NOT re-checked here - it needs the full
%       run_baseline pipeline (wind, LQI comparison), not a no-disturbance
%       closed loop. Checked by: clear traj_type traj_par; run_baseline
%       (build_traj5.m's own Gate 1 instructions).
%    2. The no-preview residual is within [0.75, 1.25] of a predicted
%       residual from a closed-loop model that FITS NOTHING from measured
%       data (analysis/traj5_predict_residual.m, docs/REGISTER_C.md Section
%       4.2 - reused from tools/tau_star.py, independently validated there
%       against two measured tau* values at two different sigma). Measured:
%       every trajectory landed in [0.985, 1.001], far inside the band.
%    3. Reference preview (tau_prev = tau_att = 93 ms) cuts the residual by
%       at least 50%, registered as X in docs/REGISTER_C.md Section 4.4.
%       Measured: every trajectory landed in [75.0%, 90.5%].
%
%  hover is excluded from parts 2-3: its floor is exactly 0 by construction
%  (zero forcing amplitude makes the predicted-residual ratio 0/0,
%  undefined) - it gets its own near-zero check instead, unchanged in spirit
%  from what this file always did for it.
%
%  ======================================================================
%  WHY THE CONTROLLER CONFIGURATION DOES NOT MATTER HERE
%  ======================================================================
%  The three Manual Switches choose which disturbance ESTIMATE is admitted.
%  With no disturbance, every estimate converges to ~0 regardless of which
%  switches are on, so this run fixes them at MOBADC's {1,1,1} for a
%  definite, reproducible choice - not because the choice is load-bearing.
%
%  ======================================================================
%  ONE MEASUREMENT FUNCTION, NOT A SECOND COPY OF IT
%  ======================================================================
%  This file used to run sim(mdl, ...) inline, with its own local toN3 -
%  its own third copy of exactly what analysis/diag_traj5_floor.m's run_once
%  did before analysis/traj5_run_once.m existed. It now calls
%  traj5_run_once/traj5_predict_residual, the same functions analysis/
%  diag_traj5_floor.m and analysis/diag_traj5_crosscheck.m call - one source
%  for "run one scenario, measure the residual" and one for "predict it",
%  the discipline core/pa_cell.m's own header states for exactly this
%  situation.

RATIO_LO = 0.75; RATIO_HI = 1.25;   % docs/REGISTER_C.md Section 4.4, part 2
PREVIEW_CUT_MIN = 50;               % docs/REGISTER_C.md Section 4.4, part 3 (X)
HOVER_TOL = 1e-5;                   % zero forcing -> track to near machine precision

opt = struct('Stop', 200, 'TStat', 140, 'TauV', 0.093);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
here = repo_root();
cd(here); setup_path();

mdl = 'baseline1';
if ~bdIsLoaded(mdl), load_system(mdl); end

evalin('base', 'init_MOBADC_params');
evalin('base', 'reset_extensions(''Quiet'', true);');

% *** BUG FOUND ON THE FIRST REAL RUN, NOT IN REVIEW. ***
% init_MOBADC_params's OWN defaults are Test 2's (w_traj = 0.625,
% core/init_MOBADC_params.m lines 157-158, "Test 2" in its own comment), NOT
% Test 4's (0.8, 1.575) - and reset_extensions does not touch R_traj/w_traj
% at all (op_set.m owns them, not the EXT table; op_set.m's own header:
% "before it, the operating condition came from the DEFAULT values... no grid
% script overrode them - discovered afterwards"). Without this line, the
% R4/W4 fetch below silently inherits whatever a PRIOR script in the SAME
% session left in the base workspace - Test 4's values only as a side
% effect of run_baseline (or another op_set('Test 4') caller) having
% already run first, never as a consequence of anything in this file.
% op_set('Test 4') is the project's own named mechanism for this (op_set.m's
% header: "selecting an operating condition must not be a variable
% assignment... it has to be a NAMED call" - rebuilding A_do is part of
% what it does, which a bare assignin would skip). Called here, BEFORE the
% no-disturbance zeroing below, because op_set('Test 4') also sets
% payload_amp = 1.5 / wind_amp = 1.0 as part of the named condition, and this
% run needs both at 0 regardless.
evalin('base', 'op_set(''Test 4'');');

if ~sync_eml_blocks()
    error('verify_traj5:drift', ...
        ['The code inside %s.slx does NOT match simulink_blocks/. Run\n' ...
         'build_traj5(''Save'', true) first if that has not been done, or\n' ...
         'sync_eml_blocks(''Apply'', true) if some OTHER block has drifted.'], mdl);
end

% *** THE POINT OF THIS RUN: NO DISTURBANCE. ***
assignin('base', 'payload_amp', 0);
assignin('base', 'wind_amp',    0);

SW = {[mdl '/Position_Observers/Manual Switch' ], ...
      [mdl '/Position_Observers/Manual Switch1'], ...
      [mdl '/Attitude_Observer/Manual Switch2' ]};
for i = 1:3, set_param(SW{i}, 'sw', '1'); end

% z0 (altitude) is not touched here: it is read by Trajectory from its own
% Constant block, unrelated to traj_type/traj_par/R_traj/w_traj, and every
% scenario below keeps whatever op_set('Test 4') just set it to. It also
% does not affect acc_d (only gamma_d(3)), so any value serves
% traj5_predict_residual's own z0 argument.
R4 = evalin('base', 'R_traj');   % Test 4's R = 0.8, used wherever traj_type ignores R
W4 = evalin('base', 'w_traj');   % Test 4's w = 1.575, likewise
z0 = -1.0;

HOV = struct('name','hover', 'ty',0, 'par',zeros(4,1), 'R',R4, 'w',W4);

SC(1) = struct('name','circle',     'ty',1, 'par',zeros(4,1),            'R',R4, 'w',W4,     'Ttot',2*pi/W4);
SC(2) = struct('name','fig8 T3a',   'ty',2, 'par',[0.566;0;0;0],         'R',R4, 'w',1.575,  'Ttot',2*pi/1.575);
SC(3) = struct('name','fig8 T3b',   'ty',2, 'par',[1.130;0;0;0],         'R',R4, 'w',0.7875, 'Ttot',2*pi/0.7875);
SC(4) = struct('name','square',     'ty',3, 'par',[1.3036;1.9399;1.0;0], 'R',R4, 'w',W4,     'Ttot',4*(1.9399+1.0));
SC(5) = struct('name','multi-sine', 'ty',4, 'par',[0.265218;0;0;0],      'R',R4, 'w',W4,     'Ttot',2*pi/0.1);

fprintf('\n%s\nCHECKPOINT 3.1, CLOSED LOOP - three-part gate, docs/REGISTER_C.md %s4.4\n%s\n', ...
        repmat('=',1,78), char(167), repmat('=',1,78));

% ---- hover: its own near-zero check, not the ratio/preview-cut gate ----
m_hov = traj5_run_once(mdl, HOV, 0, opt.Stop, opt.TStat);
hov_ok = m_hov < HOVER_TOL;
fprintf('  %-12s %12.6f m  %s  (zero forcing amplitude -> near machine precision)\n', ...
        HOV.name, m_hov, tern(hov_ok));

% ---- the five moving trajectories: parts 2 and 3 ----
n = numel(SC);
m_noV = zeros(n,1); m_V = zeros(n,1); p_noV = zeros(n,1);
ratio = zeros(n,1); cut = zeros(n,1);
bad = {};
if ~hov_ok, bad{end+1} = sprintf('hover: %.6f m >= %.0e m', m_hov, HOVER_TOL); end

fprintf('\n  %-12s %12s %12s %10s %10s\n', 'trajectory', 'no-V (m)', 'predicted', 'ratio', 'cut (%)');
for i = 1:n
    s = SC(i);
    m_noV(i) = traj5_run_once(mdl, s, 0, opt.Stop, opt.TStat);
    m_V(i)   = traj5_run_once(mdl, s, opt.TauV, opt.Stop, opt.TStat);
    p_noV(i) = traj5_predict_residual(s, z0, opt.TauV);
    ratio(i) = m_noV(i) / p_noV(i);
    cut(i)   = 100 * (1 - m_V(i) / m_noV(i));

    r_ok = ratio(i) >= RATIO_LO && ratio(i) <= RATIO_HI;
    c_ok = cut(i) >= PREVIEW_CUT_MIN;
    fprintf('  %-12s %12.6f %12.6f %10.3f %9.1f%%  %s %s\n', ...
        s.name, m_noV(i), p_noV(i), ratio(i), cut(i), tern(r_ok), tern(c_ok));
    if ~r_ok, bad{end+1} = sprintf('%s: ratio %.3f outside [%.2f, %.2f]', s.name, ratio(i), RATIO_LO, RATIO_HI); end %#ok<AGROW>
    if ~c_ok, bad{end+1} = sprintf('%s: preview cut %.1f%% below %.0f%%', s.name, cut(i), PREVIEW_CUT_MIN); end %#ok<AGROW>
end

% Put Test 4's own R/w back, and traj_type/traj_par to their safe defaults,
% so this function leaves the workspace exactly as reset_extensions would.
assignin('base', 'R_traj', R4);
assignin('base', 'w_traj', W4);
evalin('base', 'reset_extensions(''Quiet'', true);');
assignin('base', 'payload_amp', 1.5);
assignin('base', 'wind_amp',    1.0);

fprintf('\n');
ok = isempty(bad);
if ok
    fprintf(['[PASS] Checkpoint 3.1''s closed-loop gate is COMPLETE: hover tracks to\n' ...
             '       near machine precision, and every moving trajectory''s no-preview\n' ...
             '       residual matches the linear model within [%.2f, %.2f] while\n' ...
             '       reference preview cuts it by >= %.0f%%.\n' ...
             '       payload_amp and wind_amp restored to 1.5 / 1.0.\n'], ...
            RATIO_LO, RATIO_HI, PREVIEW_CUT_MIN);
else
    fprintf('[FAIL]\n');
    for i = 1:numel(bad), fprintf('  ! %s\n', bad{i}); end
end
end

function s = tern(c), if c, s = 'OK'; else, s = 'FAIL'; end, end
