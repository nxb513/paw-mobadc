function e = pa_cell(fn, cfg, opt)
%PA_CELL  ONE segment, ONE outdoor-grid configuration, returns mean||e||.
%
%   e = pa_cell(fn, 'g_psens', opt)
%
%   opt : struct with fields K, Cond, Stop, TStat, and optionally
%         TauPrev, TauPred, DoHarm, PayloadModel, WindOff.
%
%  ======================================================================
%  WHY sweep_preview IS NOT REFACTORED TO USE THIS
%  ======================================================================
%  experiments/sweep_preview.m holds a COPY of this logic (its one_cell). The
%  technically clean move is to delete the copy and have both call here.
%
%  Not done, and the reason is not laziness: the A2 result has ALREADY been
%  scored and written into docs/REGISTER_TAU.md §A2.4 by that very file. Editing
%  it now would mean the recorded number is no longer produced by the version
%  sitting in git - a break in provenance, hard to see and hard to explain
%  later.
%
%  So: this function MUST behave exactly like sweep_preview's one_cell. If the
%  logic ever has to change, change BOTH and re-run gate A2-0.

p = {'Grid', true, 'Only', {cfg}, 'PayloadWind', opt.K, 'Cond', opt.Cond, ...
     'Stop', opt.Stop, 'TStat', opt.TStat, 'OnDiverge', 'flag', 'Quiet', true};

% Fields that carry a main-grid default; the caller may override them.
p = [p, {'DoHarm', getdef(opt, 'DoHarm', [0 1])}];
p = [p, {'PayloadModel', getdef(opt, 'PayloadModel', 1)}];

% tau_prev is ALWAYS set explicitly, even when it is zero. A value left over
% from a previous call makes a whole column run in a different mode with no
% warning - the trap that swallowed payload_K_ratio on the wind branch of
% sweep_tau_eff.
p = [p, {'TauPrev', getdef(opt, 'TauPrev', 0)}];

% tau_pred is DIFFERENT: a default of [] means "keep the operating condition's
% value" (op_set sets 0.22 at Test 4). Hard-coding 0 here would silently switch
% prediction off in every column.
tp = getdef(opt, 'TauPred', []);
if ~isempty(tp), p = [p, {'TauPred', tp}]; end

% Default false, matching pa_configs.m's own default: a caller that never
% mentions WindOff gets exactly the unconditional series_on = 1 every call
% before this option existed.
p = [p, {'WindOff', getdef(opt, 'WindOff', false)}];

[~, A] = pa_configs(fn, p{:});
try, Simulink.sdi.clear; catch, end
e = A.(cfg).mean;
if A.(cfg).diverged, e = NaN; end
end

function v = getdef(s, f, d)
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
