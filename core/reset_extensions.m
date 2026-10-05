function S = reset_extensions(varargin)
%RESET_EXTENSIONS  Turn EVERY extension off, and SAY which ones were on.
%
%   S = reset_extensions
%   S = reset_extensions('Keep', {'wind_series_on'})
%
%  ======================================================================
%  WHY THIS FUNCTION EXISTS
%  ======================================================================
%  On 2026-09-05 the Test 4 regression gate failed in a very characteristic
%  pattern:
%
%      Classical  0.0939 vs 0.0939  matches
%      ESO        0.1162 vs 0.0587  DOES NOT MATCH   (2.0x)
%      DO         0.0732 vs 0.0732  matches
%      MOBADC     0.0958 vs 0.0228  DOES NOT MATCH   (4.2x)
%
%  The two rows that MATCH are the two with Manual Switch1 = '0'. The two that
%  FAIL are the two with Manual Switch1 = '1'. And Manual Switch1 is the
%  dlf_hat switch, in front of which build_pa_mobadc inserts WD_Switch, opened
%  by wind_pred_on.
%
%  The cause: an earlier grid sweep had stopped part-way and left
%  wind_pred_on = 1 in the base workspace. run_baseline calls
%  init_MOBADC_params, but init does NOT set wind_pred_on - that variable was
%  born with build_pa_mobadc, after init was written. So the controller was
%  compensating for a wind that was NOT IN the plant (the leftover prediction
%  series of a U = 12.14 m/s segment, i.e. ~2.4 N of force), while the plant
%  had only the constant 1.0 N wind.
%
%  The clearest symptom: MOBADC (0.0958) WORSE than Classical (0.0939). A
%  controller that compensates a disturbance and does worse than one that does
%  not is not a result - it is a sign that something is broken.
%
%  ======================================================================
%  THE LESSON, AND WHY THE FIX IS NOT ONE MORE assignin
%  ======================================================================
%  init_MOBADC_params is Guo's original; every extension was born AFTER it, and
%  more will follow. Scattering assignin calls through the run scripts means the
%  next extension gets added in one place and forgotten in three others -
%  exactly what happened this time.
%
%  So the extension list lives HERE, in one place. A new extension is one new
%  line here, and every run script is protected at the same moment.
%
%  And this function PRINTS what was on. A silent reset is still better than
%  contamination, but it hides the fact that an earlier run left rubbish
%  behind - and that is the part worth knowing.

opt = struct('Keep', {{}}, 'Quiet', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
if ischar(opt.Keep), opt.Keep = {opt.Keep}; end

% Extension name -> its OFF value. Regenerate the list with:
%     grep -rho "<variable name>" build_*.m | sort -u
EXT = { ...
    'predictor_on',        0; ...   % PAYLOAD prediction    (build_payload_predictor)
    'wind_pred_on',        0; ...   % the WIND channel on/off (build_pa_mobadc)
    'wind_use_pred',       0; ...   % 0 sensor, 1 PI-MoE, 2 oracle
    'wind_series_on',      0; ...   % wind series replaces constant wind (build_wind_series)
    'payload_model',       0; ...   % 0 sinusoidal, 1 physical pendulum
    'payload_z_on',        0; ...   % the payload's vertical component
    'payload_wind_on',     0; ...   % wind acting on the PAYLOAD (build_payload_wind)
    'payload_K_ratio',     0; ...   % the payload's drag-area ratio
    'payload_inj_on',      0; ...   % the out-of-model component (build_payload_inject)
    'wind_meas_from_file', 0; ...   % w_meas read from a file (build_wind_sensor_noise)
    'tau_prev',            0; ...   % REFERENCE preview       (build_traj_preview)
    'im_est_online_on',    0; ...   % online IM-est A_do/B_do/l_gain/G_do
                                     % rebuild (build_im_est_online, docs/
                                     % REGISTER_C.md sec 4.46) - the SAME
                                     % Constant-from-workspace-variable idiom
                                     % every other extension here uses, not a
                                     % Manual Switch (sec 0.38's own lesson).
    'plant_model',         0; ...   % 0 = v1 plant, 1 = plant P2 (build_p2_plant,
                                     % docs/devlog/GD2B_DESIGN.md); Variant
                                     % controls, compile-time.
    'p2_n6',               0; ...   % N6 wind -> payload term on the payload channel
                                     % (REGISTER_P2 sec 15.4, build_p2_plant).
    'p2_cmp',              0; ...   % competitors H3 / H4 on the disturbance channels
                                     % (REGISTER_P2 sec 40, build_p2_plant).
    'p2_m3',               0; ...   % GD8 (iii) pendulum model on the payload channel
                                     % (REGISTER_P2 sec 45, build_p2_plant).
    'p2_trim_ff',          0; ...   % known payload weight pre-compensated
                                     % (REGISTER_P2 sec 47, build_p2_plant).
    'p2_poison',           0; ...   % B6 poison test only: 1 = NaN on every v1
                                     % plant output (GD2B_DESIGN sec 5).
    'traj_type',           1; ...   % 1 = circle, the baseline every saved
                                     % result ran at (build_traj5). NOT 0 like
                                     % the rows above it: this is a SELECTOR,
                                     % not an on/off flag, and 1 is what
                                     % "the extension is not doing anything
                                     % new" means for this one.
    'traj_par',   zeros(4,1)};      % *** THIS ROW WAS MISSING, AND IT WAS A
                                     % REAL BUG, NOT A HYPOTHETICAL. ***
                                     % The first version of this file left it
                                     % out with the reasoning "inert whenever
                                     % traj_type = 1, so nothing to
                                     % contaminate" - true of its VALUE, but
                                     % irrelevant to what broke: after
                                     % build_traj5, Traj_Ref reads traj_par
                                     % UNCONDITIONALLY, so model_contract's
                                     % existence check (not a value check)
                                     % fails the instant it is cleared and
                                     % nothing supplies it again. Found by
                                     % 'clear traj_type traj_par; run_baseline'
                                     % - exactly the check that line exists to
                                     % run - on the first real attempt.

S = struct('was_on', {{}}, 'kept', {opt.Keep});
for i = 1:size(EXT,1)
    nm = EXT{i,1};
    if any(strcmp(nm, opt.Keep)), continue; end
    cur = [];
    if evalin('base', sprintf('exist(''%s'',''var'')', nm))
        cur = evalin('base', nm);
    end
    if ~isempty(cur) && any(double(cur(:)) ~= EXT{i,2})
        S.was_on{end+1} = sprintf('%s = %g', nm, double(cur(1)));
    end
    % Set UNCONDITIONALLY, even when the variable does not exist yet. A spare
    % variable is harmless (its block is simply unused); a MISSING one makes the
    % model raise a clear error. "Set it only if it already exists" would leave
    % exactly the trap in place.
    assignin('base', nm, EXT{i,2});
end

if ~opt.Quiet
    if isempty(S.was_on)
        fprintf('  reset_extensions: every extension was already OFF.\n');
    else
        fprintf(['  reset_extensions: turned off %d extensions that were still ' ...
                 'on: %s\n    (an earlier run left this state in the base ' ...
                 'workspace)\n'], numel(S.was_on), strjoin(S.was_on, ', '));
    end
    if ~isempty(opt.Keep)
        fprintf('    kept as requested: %s\n', strjoin(opt.Keep, ', '));
    end
end
end
