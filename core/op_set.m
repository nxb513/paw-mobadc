function C = op_set(name)
%OP_SET  Set the operating condition BY NAME, rebuild A_do, then verify.
%
%   C = op_set('Test 4')
%   C = op_set('Test 2')
%
%  ======================================================================
%  WHY THIS FUNCTION EXISTS - AND WHY IT MUST REBUILD A_do
%  ======================================================================
%  Before it, the operating condition came from the DEFAULT values in
%  core/init_MOBADC_params.m (the assignments to payload_sigma and w_traj), and
%  no grid script overrode them. So every closed-loop result in W6 ran at
%  Test 2 without anyone having chosen that - it was DISCOVERED afterwards, by
%  re-reading the source (§0.47).
%
%  Selecting an operating condition must therefore not be a variable
%  assignment. It has to be a NAMED call, because changing payload_sigma
%  without rebuilding A_do leaves the DO internal model oscillating at the old
%  frequency; DO then estimates ~0, and MOBADC silently degrades to Classical
%  with no warning at all. run_baseline had to remember to do it by hand, which
%  is exactly the kind of thing that gets forgotten.
%
%  ======================================================================
%  TWO CONDITIONS, AND WHAT DIFFERS BETWEEN THEM
%  ======================================================================
%             R (m)   v (m/s)   sigma (rad/s)   T_orbit (s)   |H(j*sigma)|
%    Test 2    0.8      0.50       0.6250          10.05        0.07911
%    Test 4    0.8      1.26       1.5750           3.99        0.06332
%
%  R is the same; only the SPEED differs, so sigma differs by a factor 2.52.
%  The payload amplitude (1.5 N) and the wind force (1.0 N) are held at both -
%  if those changed too, the two tables could no longer separate the effect of
%  sigma from the effect of amplitude.
%
%  Guo et al. publish numbers for Test 4 (Table 1). They publish NONE for
%  Test 2.
%
%  ======================================================================
%  MUST BE CALLED AFTER init_MOBADC_params
%  ======================================================================
%  init overwrites every one of these variables. Calling op_set before init
%  means init swallows it - the same trap that swallowed payload_model in
%  §0.38. This function asserts that do_harm and l_axis already exist, i.e.
%  that init has run.

assert(nargin >= 1 && (ischar(name) || isstring(name)), ...
    'op_set: a condition name is required, e.g. op_set(''Test 4'').');
name = strtrim(char(name));

% traj_type/traj_par travel WITH the condition too, same reason tau_pred
% does (§ below, "THE PREDICTION HORIZON TRAVELS WITH THE CONDITION"): a
% scenario loop that ran 'Square' and then called op_set('Test 4') without
% this would leave traj_type = 3 sitting in the base workspace, and
% op_condition (Part 3.2's own naming, below) would read the condition
% back as 'Square' even though R/w now say Test 4 - the exact contamination
% class wind_pred_on and payload_model have each caused once already
% (core/reset_extensions.m's own header). Every case sets tt/tpar
% explicitly; Test 2/Test 4/A4 default to tt = 1 (circle), tpar = zeros(4,1)
% - the baseline every one of them ran at before traj_type existed, per
% Rule 4: a new default must reproduce the old digit for digit.
tt = 1; tpar = zeros(4,1);

switch lower(regexprep(name, '[\s/]', ''))
    case {'test2','t2'}
        R = 0.8;  V = 0.50;  tp = 0.12;   % [PAPER 4.2.2]
    case {'test4','t4','test34','test3','t3'}
        R = 0.8;  V = 1.26;  tp = 0.22;   % [PAPER 4.2.4] "flight speeds ... around 1.26 m/s"

    % ---- A4 series: breaking the sigma = w_traj confound
    %      (docs/REGISTER_TAU.md §A4) ----
    %
    % These three are NOT conditions of the reference work and produce no
    % number for any main table. They exist to answer one question: is 220 ms
    % about the payload disturbance, or about the trajectory force that
    % happens to share its frequency?
    %
    % They live HERE rather than in scattered assignin calls, exactly as this
    % function's header demands - and because changing payload_sigma without
    % rebuilding A_do is how MOBADC silently degrades to Classical.
    case {'a4hover'}
        % *** 'hover' (bare) is NOT an alias here any more. *** It moved to
        % the robustness campaign's own 'Hover' condition below when Part
        % 3.2 needed the exact name 'Hover' and the two would otherwise
        % collide (both canonicalise to the string 'hover' - this switch is
        % case-insensitive). Checked before removing it: nothing in this
        % repository ever called op_set('hover') bare - every real call
        % site (experiments/sweep_a4.m, docs/REGISTER_TAU.md) already
        % spells out 'A4 hover' in full, so this removes an unused
        % shorthand, not a working call site.
        %
        % R = 0: no centripetal force left. w_traj is held at 1.575 so that
        % payload_sigma still equals it, so op_condition need not warn and
        % A_do does not change. acc_d == 0, i.e. preview is mathematically
        % inert - that is gate A4-1a, not a limitation.
        R = 0.0;  V = 0.0;  tp = 0.22;  sg = 1.575;  wt = 1.575;
    case {'a4detunelow','detunelow','a4d08'}
        % Keep the Test 4 trajectory UNCHANGED, move only the payload
        % frequency. The trajectory force stays at 1.575 while the payload
        % sits at 0.8, so the predictor - which only rotates the component at
        % payload_sigma - can no longer reach the trajectory force.
        R = 0.8;  V = 1.26;  tp = 0.093; sg = 0.8;    wt = 1.575;
    case {'a4detunehigh','detunehigh','a4d32'}
        R = 0.8;  V = 1.26;  tp = 0.093; sg = 3.2;    wt = 1.575;

    % ---- Robustness campaign, Part 3.2 (TEST_PLAN_PROMPT.md): the five
    %      new traj_type conditions, named BEFORE the generic Test 3/4
    %      branch reads them by R/w coincidence, same placement rule A4
    %      used above. R/w/tp are Test 4's own values throughout (R = 0.8,
    %      tp = 0.22) except where the shape itself demands a different w -
    %      these are the exact scenario parameters already established and
    %      verified in analysis/diag_traj5_floor.m's SC array and
    %      docs/REGISTER_C.md.
    %
    %      payload_sigma (sg) defaults to w here - IM-single's own
    %      convention (every axis at {0, w_traj}, docs/REGISTER_C.md's
    %      Part 3.3 table calls this "sai (như hiện tại)" - wrong, as
    %      currently built). It is NOT yet the physically correct
    %      frequency for every shape (Square/Multisine's real forcing does
    %      not come from w_traj at all, and Hover's has no w_traj to speak
    %      of). Part 3.3's do_w_axis replaces this with the per-axis
    %      IM-oracle table; until it exists, this is the same single-sigma
    %      approximation every condition already used.
    case {'hover'}
        R = 0.8;  V = 1.26;  tp = 0.22;  wt = 1.575;   % w_traj: Test 4's default, unused by traj_type=0
        tt = 0; tpar = zeros(4,1);
    case {'fig8res','fig8resonant'}
        R = 0.8;  V = 1.26;  tp = 0.22;  wt = 1.575;
        tt = 2; tpar = [0.566; 0; 0; 0];
    case {'fig8off-res','fig8offres','fig8offresonant'}
        R = 0.8;  V = 1.26;  tp = 0.22;  wt = 0.7875;
        tt = 2; tpar = [1.130; 0; 0; 0];
    case {'square'}
        R = 0.8;  V = 1.26;  tp = 0.22;  wt = 1.575;   % w_traj unused by traj_type=3
        tt = 3; tpar = [1.3036; 1.9399; 1.0; 0];
    case {'multisine'}
        R = 0.8;  V = 1.26;  tp = 0.22;  wt = 1.575;   % w_traj unused by traj_type=4
        tt = 4; tpar = [0.265218; 0; 0; 0];

    otherwise
        error('op_set:name', '%s', sprintf( ...
            ['op_set: unknown condition ''%s''.\n' ...
             'Only ''Test 2'', ''Test 4'', the A4 series (''A4 hover'',\n' ...
             '''A4 detune low'', ''A4 detune high''), and the robustness\n' ...
             'campaign''s five (''Hover'', ''Fig8 res'', ''Fig8 off-res'',\n' ...
             '''Square'', ''Multisine''). A new condition must be added here\n' ...
             'WITH A NAME; it may not be set by scattered assignin calls.'], name));
end

% Default: the payload swings at EXACTLY the orbit frequency (§0.35). The three
% A4 conditions above set sg/wt themselves in order to break that assumption -
% which is their whole purpose.
if ~exist('sg','var'), sg = []; end
if ~exist('wt','var'), wt = []; end

% init must already have run: op_set reads do_harm and l_axis to rebuild A_do.
for f = {'do_harm','l_axis','m'}
    assert(logical(evalin('base', sprintf('exist(''%s'',''var'')', f{1}))), ...
        'op_set: %s is not in base. Run init_MOBADC_params BEFORE op_set.', f{1});
end

% sigma = v/R for circular flight. Hover has R = 0, so the quotient is
% undefined - the A4 conditions declare w_traj themselves, and that is why they
% have to be named.
if isempty(wt)
    w = V/R;                  % [DERIVED] sigma = v/R, circular flight
else
    w = wt;                   % [A4] declared explicitly
end
if isempty(sg), sg = w; end   % default: payload at EXACTLY the orbit frequency (§0.35)
assignin('base', 'R_traj',        R);
assignin('base', 'V_traj',        V);
assignin('base', 'w_traj',        w);
assignin('base', 'payload_sigma', sg);
% traj_type/traj_par: see the comment above the switch. Set for every
% condition, not just the five new ones, so nothing can leak from whatever
% condition ran before this call.
assignin('base', 'traj_type',     tt);
assignin('base', 'traj_par',      tpar);
% The amplitudes are HELD at both conditions - see the header. Set explicitly
% rather than left at a default, so that the two tables differ in EXACTLY one
% variable.
assignin('base', 'payload_amp',   1.5);
assignin('base', 'wind_amp',      1.0);

% *** THE PREDICTION HORIZON TRAVELS WITH THE CONDITION. ***
%
% Measured in §0.54: tau* = 120 ms at Test 2 and 220 ms at Test 4. Sigma
% changes by 2.52 and tau* by 1.83 - so it is NOT a constant of the system as
% the old claim had it, and not a constant phase either. It is a
% CONDITION-DEPENDENT correction, and its right home is here, beside R/V/sigma.
%
% Why not leave it to the caller: init_MOBADC_params sets tau_pred = 0.12
% UNCONDITIONALLY, and pa_configs calls init for EVERY segment. So
%     assignin('base','tau_pred',0.22)
% issued before sweep_pa_grid is wiped on the first segment. This actually
% happened: all 210 runs of the Test 4 development grid on 2026-09-08 ran at
% tau = 0.12, while the summary line printed "tau_pred 0.12 s" and the header
% line printed "0.22". That was the THIRD instance of the same trap - after
% payload_model (§0.38) and w_traj (§0.47). Set here, it cannot be lost and it
% cannot be set wrongly.
assignin('base', 'tau_pred',      tp);

% *** MANDATORY. See the header. ***
evalin('base', ['[A_do, B_do, l_gain, do_info] = build_do_matrices(' ...
                'payload_sigma, do_harm, l_axis); ' ...
                'do_w = [do_info.do_w_axis{1}(:); do_info.do_w_axis{2}(:); ' ...
                'do_info.do_w_axis{3}(:)]; ' ...
                'n_state_axis = do_info.n_ax_state(:); ' ...
                'A_blk = [0 payload_sigma; -payload_sigma 0];']);

C = op_condition('Quiet', true);        % asserts A_do matches sigma
assert(strcmpi(strrep(C.name,'/',''), strrep(canon(name),'/','')), 'op_set:mismatch', ...
    'op_set(''%s'') but op_condition reads back ''%s''. %s', name, C.name, C.tag);
end

%% =====================================================================
function s = canon(name)
switch lower(regexprep(name, '[\s/]', ''))
    case {'test2','t2'},                          s = 'Test 2';
    case {'a4hover'},                             s = 'A4 hover';
    case {'a4detunelow','detunelow','a4d08'},     s = 'A4 detune low';
    case {'a4detunehigh','detunehigh','a4d32'},   s = 'A4 detune high';
    % Robustness campaign, Part 3.2 - see the matching case list in the
    % main switch above for why 'hover' (bare) moved here from A4's list.
    case {'hover'},                               s = 'Hover';
    case {'fig8res','fig8resonant'},              s = 'Fig8 res';
    case {'fig8off-res','fig8offres','fig8offresonant'}, s = 'Fig8 off-res';
    case {'square'},                              s = 'Square';
    case {'multisine'},                           s = 'Multisine';
    otherwise,                                    s = 'Test 34';
end
end
