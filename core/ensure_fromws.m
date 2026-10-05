function [cl, made] = ensure_fromws(mdl)
%ENSURE_FROMWS  Temporary zero series for the model's From Workspace blocks.
%
%   cl = ensure_fromws('baseline1');   % keep cl alive until the sim is done
%   [cl, made] = ensure_fromws(mdl);   % made = the names that were created
%
%  The returned object deletes exactly the variables this function created, and
%  nothing else, as soon as it is cleared or the calling function returns. Keep
%  it in a variable; discard it and the variables are removed immediately.
%
%  ======================================================================
%  WHY IT IS NEEDED
%  ======================================================================
%  On a MATLAB just opened, baseline1 does NOT compile: PI_From reads
%  dmf_inj_ts and WM_From reads wind_meas_ts, two series that only come into
%  being after a data-loading script runs. Compile evaluates the VariableName
%  parameter of EVERY From Workspace block, including the ones whose switch is
%  turned off - so a model that will not read a signal still refuses to build
%  without it.
%
%  ======================================================================
%  WHY THEY ARE NOT PUT IN init_MOBADC_params
%  ======================================================================
%  That is the obvious place and it is WRONG. core/pa_configs.m branches on
%  exist() of exactly these variables (line 239 for wind_meas_ts, lines 305-310
%  for wind_ts and dmf_inj_ts). Creating them in init would send pa_configs down
%  a different branch - changing the behaviour of a LOCKED grid in order to make
%  a check run. That is a bad trade in the direction that matters.
%
%  So: create them temporarily, delete them afterwards, and delete ONLY the ones
%  this function made. A variable left behind in the base workspace is the exact
%  silent-failure shape that swallowed payload_K_ratio and payload_model.
%
%  ======================================================================
%  THE NAMES ARE READ FROM THE MODEL
%  ======================================================================
%  Not hard-coded as those two: another machine's model may carry extensions a
%  build_* script added that this one does not.
%
%  ----------------------------------------------------------------------
%  Lifted verbatim from build/build_traj_preview.m, which is where the problem
%  was first diagnosed and solved, and which now calls this copy. Two identical
%  private copies of a helper is how the numbers in this repository went stale
%  five times; there is one definition and it lives here.

made = {};
try
    blks = find_system(mdl, 'LookUnderMasks','all', 'FollowLinks','on', ...
                       'BlockType','FromWorkspace');
catch
    cl = onCleanup(@() drop_vars({}));
    return
end
for i = 1:numel(blks)
    vn = strtrim(get_param(blks{i}, 'VariableName'));
    if isempty(vn) || ~isvarname(vn) || any(strcmp(vn, made)), continue; end
    if evalin('base', sprintf('exist(''%s'',''var'')', vn)), continue; end
    assignin('base', vn, struct('time', [0;1], ...
             'signals', struct('values', zeros(2,3), 'dimensions', 3)));
    made{end+1} = vn; %#ok<AGROW>
end
if ~isempty(made)
    fprintf(['  (created %d temporary zero series for From Workspace: %s\n' ...
             '   - they are deleted again on return, and they are inert: the\n' ...
             '   switches that read them are off and the values are zero)\n'], ...
            numel(made), strjoin(made, ', '));
end
cl = onCleanup(@() drop_vars(made));
end

function drop_vars(names)
for i = 1:numel(names)
    try, evalin('base', ['clear ' names{i}]); catch, end
end
end
