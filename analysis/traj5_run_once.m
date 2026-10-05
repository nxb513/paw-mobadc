function m = traj5_run_once(mdl, s, tau_prev, Stop, TStat)
%TRAJ5_RUN_ONCE  One Simulink run of the 7-input Traj_Ref, mean of the
%                 Euclidean tracking-error norm over t >= TStat.
%
%   m = traj5_run_once(mdl, s, tau_prev, Stop, TStat)
%
%   s : struct with fields ty (traj_type), par (traj_par, 4x1), R (R_traj),
%       w (w_traj) - the SC(i) scenario structs diag_traj5_floor.m and
%       diag_traj5_crosscheck.m both build.
%
%  Extracted out of analysis/diag_traj5_floor.m (where it started as a local
%  function) when analysis/diag_traj5_crosscheck.m needed the identical
%  measurement for two more scenarios (double-amplitude circle and fig8
%  T3a). Two copies of "run one scenario, measure the residual" is exactly
%  the defect class core/pa_cell.m's own header warns about - one source,
%  not a careful copy - so this file is that one source, and both callers
%  use it.

assignin('base', 'traj_type', s.ty);
assignin('base', 'traj_par',  s.par);
assignin('base', 'R_traj',    s.R);
assignin('base', 'w_traj',    s.w);
assignin('base', 'tau_prev',  tau_prev);

% *** BUG FOUND ON diag_traj5_floor.m's FIRST COLD-WORKSPACE RUN. ***
% On a MATLAB session that has not run anything else first, PI_From and
% WM_From (Disturbances/Position_Observers) refuse to compile: they read
% dmf_inj_ts/wind_meas_ts, which only exist after a data-loading script has
% run, and compile evaluates every From Workspace block's VariableName
% regardless of whether its switch is on (core/ensure_fromws.m's own header).
% This function is called once per scenario/tau_prev pair by its callers,
% and every call needs this, not just the first - so it is inside this
% function, not hoisted to the caller. Safe to call every time: this
% function is a separate function call each time, so its local cl is fully
% torn down when one call returns, before the next call's ensure_fromws
% runs - no reassignment race (see verify_traj5.m's commit message for the
% race this avoids by NOT hoisting it there).
cl = ensure_fromws(mdl); %#ok<NASGU>
o = sim(mdl, 'StopTime', num2str(Stop), 'Solver','ode4', 'FixedStep','1e-3');
t  = o.gamma_log.time;
ga = toN3(o.gamma_log.signals.values);
gd = toN3(o.gammad_log.signals.values);
msk = t >= TStat;
e   = sqrt(sum((ga(msk,:) - gd(msk,:)).^2, 2));
m   = mean(e);
end

function A = toN3(V)
if isstruct(V) && isfield(V,'signals'), V = V.signals.values; end
if isa(V,'timeseries'), V = V.Data; end
A = squeeze(V);
if size(A,2) ~= 3, A = A.'; end
end
