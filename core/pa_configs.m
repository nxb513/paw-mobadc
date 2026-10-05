function [R, M] = pa_configs(matfile, varargin)
%PA_CONFIGS  Run FOUR wind-channel configurations on one segment; return
%            signals and metrics.
%
%   [R, M] = pa_configs('wind_real_t150_i0000.mat')
%   [R, M] = pa_configs(..., 'Quiet', true)
%
%  ======================================================================
%  ONE SOURCE OF TRUTH FOR BOTH VERIFY AND SWEEP
%  ======================================================================
%  verify_pa_mobadc examines one segment closely; sweep_pa_mobadc runs 30 and
%  pools them. If each computed its own metric they would sooner or later
%  diverge - in the statistics window, in the mask, or in the definition of the
%  error - and when the paper's table stops matching the check's table, nobody
%  can tell which side is right.
%
%  So "run the configurations and compute the standard metric" lives here and
%  both callers come through it. verify's own additional checks stay in verify.
%
%  EVERY NUMBER IN THE PAPER PASSES THROUGH THIS FILE. That is why
%  verification/verify_repro.m exists: it re-runs two exact calls from
%  sweep_field_grid and compares against the stored columns with a threshold of
%  ZERO, so a change here that alters any result cannot pass unnoticed.
%
%  ======================================================================
%  THE FOUR CONFIGURATIONS
%  ======================================================================
%    p_obs   wind_pred_on=0                   MOBADC, observer only
%    p_sens  wind_pred_on=1, wind_use_pred=0  20 Hz wind sensor, NO prediction
%    p_pred  wind_pred_on=1, wind_use_pred=1  PA-MOBADC
%    p_orac  wind_pred_on=1, wind_use_pred=2  ORACLE d(t+tau) - the CEILING
%
%  p_sens is the control without which any improvement would be misattributed
%  to PI-MoE. p_orac is the CEILING: it says how much room is left at all, and
%  on segment #0 it showed that on the MEAN the ceiling is about zero. That
%  measurement is why the learned wind predictor is reported as a negative
%  ablation rather than as a contribution.

opt = struct('Stop', 200, 'TStat', 140, 'Quiet', false, 'Grid', false, ...
             'Only', {{}}, 'PayloadModel', [], ...
             'SensorNoise', [], 'SensorBias', [], 'SensorSeed', 20240601, ...
             'SensorFilterFc', [], 'OnDiverge', 'error', 'InjectK', [], ...
             'InjectRatio', [], 'Cond', '', 'DoHarm', [], 'MeanOnly', false, ...
             'TauPred', [], 'PayloadWind', [], 'Switches', {{}}, ...
             'KeepTraj', false, 'TauPrev', [], 'KeepLog', {{}}, 'WindOff', false, 'WindZero', false, ...
             'Step', '1e-3', 'L', [], 'MP', [], 'DoWAxis', [], 'LAxis', [], ...
             'ImEstOnline', [], 'ZetaP', [], 'SensorDelayMs', [], ...
             'PlantModel', 'v1', 'P2Cold', false, 'P2Poison', false, 'P2SensorNoise', true, ...
             'P2ZetaS', [], 'P2TauM', [], 'OracleTauMs', [], 'PredDelay', false, ...
             'P2MotorLag', true, 'P2Discrete', true, 'P2Sensors', true, 'P2N6', false, 'P2N6TauMs', 0, ...
             'P2PredScale', [], 'P2Cmp', 0, 'P2H3Hz', 4, ...
             'P2ImuScale', 1, 'P2ThrustMax', [], 'P2AccBias', [], 'P2AccBiasAxes', '', ...
             'P2M3', false, 'P2M3TauMs', 0, 'P2M3Acc', 'cmd', 'P2TrimFF', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
if opt.Quiet, say = @(varargin) []; else, say = @(v) fprintf('%s', v); end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end
po = [mdl '/Position_Observers'];
assert(getSimulinkBlockHandle([po '/WSEL']) > 0, ...
    'pa_configs: WSEL is missing. Run build_pa_mobadc first.');
if opt.Grid
    % The 2x2 table uses both channels. Without PP_Switch the "payload
    % PREDICTED" column silently returns exactly the "payload ESTIMATED"
    % numbers, and the table looks like a real result: payload prediction buys
    % nothing. This nearly happened at §0.30.
    assert(getSimulinkBlockHandle([po '/PP_Switch']) > 0, ...
        'pa_configs: ''Grid'' needs PP_Switch. Run build_payload_predictor first.');
end

S = load(matfile);
for f = {'tau_ms','fs','t_valid_from'}
    if isfield(S,f{1}), S.(f{1}) = double(S.(f{1})); end
end
% The SCENARIO set by the CALLER, which has to survive init_MOBADC_params.
%
% init assigns payload_model = 0 unconditionally. So
%     assignin('base','payload_model',1)
% issued before calling sweep_pa_grid is OVERWRITTEN on the very first segment,
% and all 210 runs execute in sinusoidal mode. This actually happened: the
% pendulum grid returned SEVEN numbers identical to the sinusoidal grid DIGIT
% FOR DIGIT, which cannot be right, because d_mf differs by 20% RMS between the
% two modes. It cost 3522 s to re-measure what had already been measured.
%
% Capture before init, restore after init. And PRINT it - staying silent is how
% this bug survived the first time.
scen = struct();
for f = {'payload_model','payload_z_on'}
    if evalin('base', sprintf('exist(''%s'',''var'')', f{1}))
        scen.(f{1}) = evalin('base', f{1});
    end
end
if ~isempty(opt.PayloadModel), scen.payload_model = opt.PayloadModel; end

% TURN EVERY EXTENSION OFF, AFTER capturing the caller's intent (scen) and
% BEFORE wind_sim_load/init - so the normal sequence below sets back whatever it
% needs. This function sets wind_pred_on/wind_use_pred/predictor_on per
% configuration so those three are safe, but payload_wind_on, payload_K_ratio
% and wind_meas_from_file are set by NOBODY - they would survive from the
% previous experiment. See core/reset_extensions.m: this is the trap that made
% the Test 4 regression gate slip.
rx = reset_extensions('Quiet', true);
if ~isempty(rx.was_on)
    % Printed EVEN under Quiet: leftover state matters more than any number.
    fprintf('    ! turned off extensions that were still on: %s\n', strjoin(rx.was_on, ', '));
end

% 'MeanOnly': replace the wind series on the BODY with its own mean vector.
% The body wind keeps its direction and magnitude UNCHANGED (so the tilt angle
% is unchanged) and loses only its time variation. This is the control that
% separates TILT from TURBULENCE INTENSITY - two things U drags along together,
% and which §0.73 needed to separate.
% Note: the injected component (make_payload_inject) also reads wind_ts, so
% with MeanOnly on it becomes a constant force too. That is DELIBERATE: the
% control must change BOTH paths, otherwise it is no longer the same
% realisation.
%
% 'WindOff': series_on passed to wind_sim_load, guarded so the DEFAULT (false)
% gives EXACTLY the unconditional 1 every call before this option existed -
% no already-published number may move by a digit. series_on = ~opt.WindOff,
% not opt.WindOff itself: wind_sim_load's own docstring is explicit that 0
% does not mean "zero wind" but "off - reproduce the baseline" (the model
% falls back to a CONSTANT wind, not an absent one - wind_ts is still built
% and assigned either way; only wind_series_on, the Simulink switch reading
% it, changes). docs/REGISTER_C.md Section 4.8.1 registers what this is for
% and is explicit about that distinction - do not read 'WindOff' as
% synonymous with zero disturbance.
%
% VERIFIED: default false is bit-exact. verify_repro (32/32 cells, max
% delta 0.00e+00), check_results_numbers (146/146), and check_all all ran
% with this option present and unused; check_all's one failure
% (check_retracted's SNAPSHOT.md/Section-4.0-attribution mismatches) is
% baseline1.slx drift from build_traj5.m earlier in this campaign, already
% flagged as deferred in that file's own output, and unrelated to this
% change. docs/REGISTER_C.md Section 4.8.1 has the full record.
series_on = double(~(opt.WindOff || opt.WindZero));
wl = {'MeanOnly', opt.MeanOnly};
if opt.Quiet
    evalc('wind_sim_load(matfile, series_on, wl{:}); evalin(''base'',''init_MOBADC_params'');');
else
    wind_sim_load(matfile, series_on, wl{:});
    evalin('base','init_MOBADC_params');
end

fn = fieldnames(scen);
for i = 1:numel(fn), assignin('base', fn{i}, scen.(fn{i})); end
pm = evalin('base','payload_model');
say(sprintf('    payload disturbance: %s\n', pm_name(pm)));

% 'L'/'MP': init_MOBADC_params sets L = 1.0, m_p = 0.5 UNCONDITIONALLY (the
% same trap documented above for payload_model), so an assignin('base','L',...)
% issued before this call would already have been overwritten by the time
% control reaches here. Override AFTER init, same rule as payload_model.
% Default [] leaves init's own L = 1.0 / m_p = 0.5 untouched - no published
% number depends on either option being passed.
if ~isempty(opt.L),  assignin('base', 'L',   opt.L);  end
if ~isempty(opt.MP), assignin('base', 'm_p', opt.MP); end

% 'ZetaP': same trap, same rule. init_MOBADC_params sets zeta_p = 0.12
% UNCONDITIONALLY (its own comment: "A FREE PARAMETER, with no source
% and no ablation" - docs/REGISTER_ROBUST.md sec 6, N4a, is exactly
% that ablation). Default [] leaves init's own zeta_p = 0.12 untouched
% - no published number depends on this option.
if ~isempty(opt.ZetaP), assignin('base', 'zeta_p', opt.ZetaP); end

% 'LAxis': same trap, same rule. init_MOBADC_params sets l_axis =
% [0.10 0.08 0.10] (Guo's own DO gain) UNCONDITIONALLY, so an override
% issued before this call is already gone. Read by build_do_matrices via
% the DoHarm/DoWAxis block below (both branches evalin('base','...
% l_axis)'), which is why this must land here, after init and before
% that block - not a new code path, the same base-workspace variable
% every existing call already reads. Default [] leaves init's own
% l_axis untouched - no published number depends on this option.
% docs/REGISTER_C.md sec 4.40 (P2): tests whether a larger DO gain
% flattens the observer's sensitivity to a frequency mismatch between
% the assumed and the true disturbance frequency.
if ~isempty(opt.LAxis), assignin('base', 'l_axis', opt.LAxis(:).'); end

% 'ImEstOnline': same trap, same rule - reset_extensions sets
% im_est_online_on back to 0 on every call, so this must land here, after
% init/reset. Default [] leaves it at reset_extensions's own 0 (off) -
% bit-exact for every existing call. docs/REGISTER_C.md sec 4.46.
if ~isempty(opt.ImEstOnline)
    assignin('base', 'im_est_online_on', double(opt.ImEstOnline));
end

% THE OPERATING CONDITION. Must be set AFTER init (init overwrites it), AFTER
% the scenario is restored, and BEFORE make_payload_inject (which reads
% payload_sigma/payload_amp) - i.e. it must be what the model is ABOUT TO RUN,
% not what the caller intended to run.
%
% Before this block existed, w_traj = payload_sigma = 0.625 came from init's
% own defaults and no grid script overrode them - so EVERY closed-loop result
% in W6 was at Test 2, and no table recorded that. It was found by re-reading
% the source after everything had already run. See op_condition.m and op_set.m.
%
% An empty 'Cond' = leave whatever is already set. That default is DELIBERATE:
% every old script must still produce exactly its old numbers, otherwise there
% is no way to tell "the condition changed" from "something else broke".
if ~isempty(opt.Cond)
    M0_cond = op_set(opt.Cond);
else
    M0_cond = op_condition('Quiet', true);
end
say(sprintf('    condition: %s\n', M0_cond.tag));

% *** THE INTERNAL-MODEL STRUCTURE. Must be set AFTER init and AFTER op_set. ***
%
% init_MOBADC_params assigns do_harm = 1 UNCONDITIONALLY, and pa_configs calls
% init for EVERY segment. So assignin('base','do_harm',[0 1]) issued before
% calling a grid is wiped on the first segment - the same trap that swallowed
% payload_model (§0.38), w_traj (§0.47) and tau_pred (§0.59). This was the
% FOURTH instance. Its correct home is here, and it must rebuild A_do exactly
% as op_set does.
%
% Default [] = keep the Guo original (do_harm = 1), so the regression gate
% changes no number unless someone asks for it. The paper's columns L1..L3 pass
% [0 1] through here; PROTOCOL_LOCK records that as do_harm_pa.
if ~isempty(opt.DoHarm)
    assignin('base', 'do_harm', opt.DoHarm(:).');
    evalin('base', ['[A_do, B_do, l_gain, do_info] = build_do_matrices(' ...
                    'payload_sigma, do_harm, l_axis); ' ...
                    'do_w = [do_info.do_w_axis{1}(:); do_info.do_w_axis{2}(:); ' ...
                    'do_info.do_w_axis{3}(:)]; ' ...
                    'n_state_axis = do_info.n_ax_state(:);']);
    say(sprintf('    internal model: harm = %s -> %d states, Re max %+.5f\n', ...
        mat2str(opt.DoHarm(:).'), evalin('base','do_info.n_state'), ...
        evalin('base','do_info.re_max')));
end

% 'DoWAxis': the NEW per-axis form (build_do_matrices(do_w_axis, l_axis)),
% for IM-phys/IM-oracle (docs/REGISTER_C.md sec 4.27) - 'DoHarm' above
% only wires the OLD (sigma, harm, l_axis) form, which cannot express a
% different frequency set per axis (figure-8's y-axis at 2x its x-axis
% frequency, hover/square's wn_p instead of any trajectory sigma at
% all - see build/im_oracle_axis.m). Mutually exclusive with 'DoHarm':
% both configure the same do_w/n_state_axis/A_do triple, and passing
% both would let one silently overwrite the other depending on option
% order - exactly the class of silent bug this file's header repeatedly
% warns about. Default [] = untouched, bit-exact for every existing
% call. build_do_matrices.m's own docstring already guarantees
% do_w_axis={[0 sigma],[0 sigma],[0 sigma]} reproduces the old form's
% numbers bit-exact - that equivalence is exercised through here, not
% re-implemented.
if ~isempty(opt.DoWAxis)
    assert(isempty(opt.DoHarm), ...
        'pa_configs: ''DoWAxis'' and ''DoHarm'' are mutually exclusive - pass one.');
    assignin('base', 'do_w_axis_arg', opt.DoWAxis);
    evalin('base', ['[A_do, B_do, l_gain, do_info] = build_do_matrices(' ...
                    'do_w_axis_arg, l_axis); ' ...
                    'do_w = [do_info.do_w_axis{1}(:); do_info.do_w_axis{2}(:); ' ...
                    'do_info.do_w_axis{3}(:)]; ' ...
                    'n_state_axis = do_info.n_ax_state(:);']);
    dwstr = strjoin(cellfun(@mat2str, opt.DoWAxis, 'UniformOutput', false), ', ');
    say(sprintf('    internal model: do_w_axis = {%s} -> %d states, Re max %+.5f\n', ...
        dwstr, evalin('base','do_info.n_state'), evalin('base','do_info.re_max')));
end

% 'ImEstOnline' placeholder 25-slot layout (docs/REGISTER_C.md sec
% 4.49): with the Switch -> Variant Source redesign, DO_12's own
% Variant Source input for im_est_online_on=1 is the Enabled
% Subsystem's fixed 25-state construction (sec 4.47's own fixed-slot
% layout: DC + 4 harmonics + wn_p per x/y axis, DC + sigma_z for z) -
% but Int_z (baseline1.slx's own DO state integrator, confirmed by its
% XML wiring, sec 4.49) and payload_predictor's n_state_axis BOTH size
% themselves from base-workspace A_do/B_do/l_gain/G_do/n_state_axis
% directly, independent of which Variant branch is active. So when
% im_est_online_on=1, those base-workspace variables must ALSO be the
% 25-slot layout, or Int_z/payload_predictor would compile at whatever
% size the CURRENT scenario's own DoHarm/DoWAxis happens to be instead
% - a mismatch against DO_12's own 25-state Variant Source branch.
%
% Must be placed AFTER 'Cond' (needs the ACTUAL condition's own
% w_traj, not init's unconditional default) and AFTER the DoHarm/
% DoWAxis block above (this IS the internal-model-structure section,
% same place, same reason as both of those).
%
% Built by calling im_est_do_rebuild.m ITSELF, once, interpreted, with
% every harmonic slot untrusted (PLACEHOLDER=0.3, matching
% im_est_estimator.m's own constant) - bit-consistent with the online
% estimator's own actual first tick, not a second hand-written copy of
% the same construction that could drift from it (sec 4.47's own
% fixed-slot decoupling: untrusted -> l=0, excluded from B).
%
% Skipped, with a printed note, if the caller ALSO passed an explicit
% DoHarm/DoWAxis - trusting that choice rather than silently
% overwriting it, the same rule as DoHarm's own mutual exclusivity
% with DoWAxis just above.
if ~isempty(opt.ImEstOnline) && opt.ImEstOnline
    if ~isempty(opt.DoHarm) || ~isempty(opt.DoWAxis)
        say(sprintf(['    ImEstOnline=1: caller also set DoHarm/DoWAxis ' ...
            'explicitly - leaving it, NOT auto-building the 25-slot layout.\n']));
    else
        L_now      = evalin('base', 'L');
        wn_p_now   = sqrt(9.81 / L_now);
        w_traj_now = evalin('base', 'w_traj');
        l_axis_now = evalin('base', 'l_axis');
        PLACEHOLDER = 0.3;
        trust4 = [false false false false];
        w4     = [PLACEHOLDER PLACEHOLDER PLACEHOLDER PLACEHOLDER];
        [A0, B0, L0, G0, fb0] = im_est_do_rebuild(w4, trust4, w4, trust4, ...
            wn_p_now, w_traj_now, l_axis_now, false);
        assert(~fb0, ['pa_configs: unexpected fallback building the placeholder ' ...
            '25-slot init layout - im_est_do_rebuild should never fall back on an ' ...
            'all-untrusted, freshly-placeholder input.']);
        assignin('base', 'A_do', A0);
        assignin('base', 'B_do', B0);
        assignin('base', 'l_gain', L0);
        assignin('base', 'G_do', G0);
        assignin('base', 'n_state_axis', [11; 11; 3]);
        assignin('base', 'do_w', [0; w4(:); wn_p_now; 0; w4(:); wn_p_now; 0; w_traj_now]);
        say(sprintf('    ImEstOnline=1: placeholder 25-slot layout built (n_state=25, wn_p=%.4f rad/s).\n', ...
            wn_p_now));
    end
end

% *** THE PREDICTION HORIZON. Must be set AFTER op_set. ***
%
% op_set sets tau_pred per condition (0.12 at Test 2, 0.22 at Test 4, §0.54),
% and init sets 0.12 unconditionally before that. So an assignin issued before
% calling a grid is wiped - the FIFTH instance of the trap. Its correct home is
% here.
%
% Default [] = keep the condition's value, so no old result changes.
if ~isempty(opt.TauPred)
    assignin('base', 'tau_pred', opt.TauPred);
    say(sprintf('    tau_pred = %.0f ms (set by the caller)\n', 1000*opt.TauPred));
end

% *** REFERENCE PREVIEW (§0.119, registered as §A2). Same place, same reason. ***
%
% reset_extensions sets tau_prev back to 0 on every call - exactly as it should,
% because a value left over from a previous experiment would make a WHOLE grid
% run in preview mode with no warning. That is the trap that swallowed
% payload_K_ratio. So the only way to turn it on is through here, and the
% default [] leaves it at 0.
if ~isempty(opt.TauPrev)
    assignin('base', 'tau_prev', opt.TauPrev);
    say(sprintf('    tau_prev = %.0f ms (REFERENCE PREVIEW)\n', ...
                1000*opt.TauPrev));
end

% *** COUPLING THE PAYLOAD TO THE REAL WIND. AFTER reset_extensions and op_set. ***
%
% reset_extensions turns payload_wind_on and payload_K_ratio OFF on every call -
% exactly as it should, because neither may survive from a previous experiment.
% So the only way to turn them on is through here.
%
% This is the switch that takes the study from the LABORATORY to the OUTDOORS:
% the slung load feels the same wind series that is blowing on the body, under
% the linear law
%     F_wp = K * K_w * w_xy(t)
% with K = the effective payload/UAV drag-area ratio (§0.37). With it on, the
% payload channel's model mismatch arises FROM THE PHYSICS rather than from an
% injected component.
%
% Default [] = off, so no old result changes by a single digit.
if ~isempty(opt.PayloadWind)
    % *** REFUSAL: F_wp REACHES d_mf ONLY WHEN payload_model = 1. ***
    %
    % payload_model drives a Switch between Dist_Gen (the sinusoid) and
    % Payload_Pendulum (build_payload_pendulum, diagram at the head of that
    % file). With payload_model = 0 the pendulum output is NOT selected, so
    % F_wp feeds a block whose output is discarded - and 'PayloadWind' becomes
    % an instruction that DOES NOTHING, silently.
    %
    % This actually happened: the 25468 s run of 2026-09-09 (§0.79) had
    % PayloadWind = 0.5 with payload_model = 0, so the payload-wind coupling did
    % not exist at all. The four-stage table from that run measured something
    % quite different from what its own header claimed.
    pmn = evalin('base','payload_model');
    assert(pmn == 1, 'pa_configs:payloadwind', '%s', sprintf( ...
        ['''PayloadWind'' needs payload_model = 1 (physical pendulum); it is %g.\n' ...
         'With payload_model = 0 the Switch selects the sinusoid and the F_wp\n' ...
         'port is left dangling - this option would DO NOTHING, with no error.\n' ...
         'Call it as:  pa_configs(..., ''PayloadModel'', 1, ''PayloadWind'', %g)'], ...
        pmn, opt.PayloadWind));
    assignin('base', 'payload_wind_on',  1);
    assignin('base', 'payload_K_ratio',  opt.PayloadWind);
    say(sprintf('    payload-wind coupling: K = %.2f (F_wp = K*K_w*w), physical pendulum\n', ...
                opt.PayloadWind));
end

% The MEASURED wind series. Must come AFTER wind_sim_load, because
% wind_sim_load recreates wind_ts for every segment - the same trap that
% swallowed payload_model at §0.38.
%
% The seed is per segment: with one shared seed the 30 noise realisations would
% be correlated with each other and would pool to an artificially similar
% number.
from_file = evalin('base','exist(''wind_meas_from_file'',''var'')') && ...
            evalin('base','wind_meas_from_file') > 0.5;
if from_file
    % E1b: the file carries its own w_meas, and the PI-MoE INSIDE THE FILE was
    % fed exactly that series. Adding noise here would feed the two branches
    % two different series and break exactly the fairness E1b was built to
    % provide.
    assert(isempty(opt.SensorNoise) && isempty(opt.SensorBias), ...
        ['pa_configs: %s already carries a MEASURED wind series (E1b). Do not ' ...
         'add SensorNoise/SensorBias - the PI-MoE in the file has already ' ...
         'seen that series.'], matfile);
    ni = struct('sigma', evalin('base','0'), 'bias', 0, 'from_file', true);
    if isfield(S,'sensor_noise'), ni.sigma = double(S.sensor_noise); end
    if isfield(S,'sensor_bias'),  ni.bias  = double(S.sensor_bias);  end
    say(sprintf('    sensor (FROM FILE): sigma %.3f, bias %.3f m/s\n', ...
                ni.sigma, ni.bias));
elseif ~isempty(opt.SensorNoise) || ~isempty(opt.SensorBias)
    sg = 0; if ~isempty(opt.SensorNoise), sg = opt.SensorNoise; end
    bi = 0; if ~isempty(opt.SensorBias),  bi = opt.SensorBias;  end
    ni = make_wind_meas(sg, bi, opt.SensorSeed + seg_seed(matfile));
    ni.from_file = false;
    say(sprintf('    sensor: sigma %.3f, bias %.3f m/s\n', sg, bi));
elseif evalin('base','exist(''wind_meas_ts'',''var'')')
    % WM_From may be reading wind_meas_ts. Without resetting it, it keeps the
    % noisy series of the PREVIOUS segment - a classic silent error.
    ni = make_wind_meas(0, 0, opt.SensorSeed);
    ni.from_file = false;
else
    ni = struct('sigma',0,'bias',0,'from_file',false);
end
% A CAUSAL low-pass filter on the sensor path. This is the fair control:
% PI-MoE is being compared against a RAW measurement, and nobody feeds a noisy
% anemometer straight into a controller. See core/filter_wind_meas.m.
%
% Must come after wind_meas_ts exists, and the base workspace holds its own raw
% copy so that repeated calls do not filter an already-filtered series.
%
% The RAW copy is of THIS segment. It is reset for EVERY segment, not created
% "just once": a raw copy frozen at the first segment would be re-filtered for
% every later one, and would also leak into runs that use no filter at all.
% That mistake cost 45 minutes - four cut-off frequencies returning four
% identical numbers.
evalin('base', 'wind_meas_raw_ts = wind_meas_ts;');
ni.fc = inf;
if ~isempty(opt.SensorFilterFc)
    fi = filter_wind_meas(opt.SensorFilterFc);
    ni.fc = fi.fc;  ni.filter_delay_ms = fi.delay_ms;
    say(sprintf('    sensor filter: fc %.2f Hz (delay ~%.0f ms), RMS %.3f -> %.3f\n', ...
                fi.fc, fi.delay_ms, fi.rms_in, fi.rms_out));
end

% A pure transport delay on the sensor path, AFTER any noise/bias/filter
% above - docs/REGISTER_ROBUST.md sec 7 (N4b), core/delay_wind_meas.m.
% Default [] = 0 ms = an EXACT COPY, bit-exact for every existing call.
ni.delay_ms = 0;
if ~isempty(opt.SensorDelayMs) && opt.SensorDelayMs > 0
    di = delay_wind_meas(opt.SensorDelayMs);
    ni.delay_ms = di.delay_ms;
    say(sprintf('    sensor delay: %.0f ms (%d samples)\n', di.delay_ms, di.n_shift));
end
% 'PredDelay' (docs/REGISTER_P2.md sec 13.2): the PI-MoE prediction is computed from the
% MEASURED wind (sec 0.3), so the same sensor delay reaches it - the prediction made from
% w_meas(<= t - d) is available at t. Shifts the time base of the held series what_ts (and
% its validity signal) by the sensor delay. Default false = what_ts untouched - bit-exact
% for every existing call; it only matters to columns that read what_ts (wind_use_pred 1).
ni.pred_delay_ms = 0;
if opt.PredDelay && ni.delay_ms > 0 && evalin('base', 'exist(''what_ts'',''var'')')
    pdi = delay_pred_ts(ni.delay_ms);
    ni.pred_delay_ms = pdi.delay_ms;
    say(sprintf('    prediction delay: %.0f ms (what_ts time base shifted)\n', pdi.delay_ms));
end
M0_sensor = ni;

% 'OracleTauMs' (docs/REGISTER_P2.md sec 0.3.1, N0W): the wind oracle w(t + tau) by
% shifting the TIME BASE of the true wind (core/p2_oracle_ts.m), any tau, including
% 0 (= O(0)). Default [] keeps wind_sim_load's own w_oracle_ts (whole-sample shift at
% the checkpoint horizon) - bit-exact for every existing call. Placed before the
% WindOff/WindZero block so that those still zero it.
if ~isempty(opt.OracleTauMs)
    assignin('base', 'w_oracle_ts', p2_oracle_ts(evalin('base', 'wind_ts'), opt.OracleTauMs));
    say(sprintf('    oracle: time-shifted true wind, tau = %g ms\n', opt.OracleTauMs));
end

% 'WindOff' only switches the AIRFRAME wind to the constant baseline; the
% controller-side wind inputs are not gated by wind_series_on in the model,
% so without this they kept feeding forward the file's wind (docs/
% REGISTER_ROBUST.md sec 18.7). Zeroed here, after the sensor chain above
% (their last write before sim). wind_ts (payload-wind path, K) untouched.
% Default WindOff=false never enters this block.
% 'WindZero' (docs/REGISTER_ROBUST.md sec 18.9): zero wind on EVERY path -
% airframe (wind_amp = 0 after op_set, series off), payload (wind_ts), and
% the controller inputs below. Default false never enters.
if opt.WindZero
    assignin('base', 'wind_amp', 0);
    M0_cond.wind_amp = 0;
    wz_s = evalin('base', 'wind_ts');
    wz_s.signals.values = zeros(size(wz_s.signals.values));
    assignin('base', 'wind_ts', wz_s);
end
if opt.WindOff || opt.WindZero
    for wz_v = {'wind_meas_ts', 'what_ts', 'w_oracle_ts'}
        if evalin('base', sprintf('exist(''%s'', ''var'')', wz_v{1}))
            wz_s = evalin('base', wz_v{1});
            wz_s.signals.values = zeros(size(wz_s.signals.values));
            assignin('base', wz_v{1}, wz_s);
        end
    end
    if opt.WindZero
        say(sprintf('    WindZero: zero wind on airframe, payload and controller inputs\n'));
    else
        say(sprintf('    WindOff: airframe = constant baseline wind; controller wind inputs zeroed\n'));
    end
end

% The OUT-OF-MODEL component of the payload disturbance (P0, §0.47). Must come
% AFTER wind_sim_load (it needs wind_ts) and AFTER init (it needs m_p, L,
% zeta_p, K_w) - the same trap that swallowed payload_model at §0.38. With no
% parameter it is turned off EXPLICITLY and a zero series is installed, so the
% next segment cannot eat the previous segment's series.
% 'InjectRatio' sets the MISMATCH RATIO directly instead of setting K and
% hoping.
%
% NOTE ON SCOPE. This injection path belongs to the P0 validity analysis, which
% synthesises mismatch artificially. The paper's main grid does NOT use it:
% sweep_field_grid turns on the physical payload-wind coupling instead, so the
% mismatch arises from the plant. Both still exist because P0 is what
% established the r axis that D0's intervals were derived from.
%
% Why no search is needed to find K: F_wp = K*K_w*w/(m_p*L), and
% make_payload_inject uses a DELIBERATELY LINEARISED AUXILIARY PENDULUM, so th
% is exactly proportional to K and so is d_inj = m_p*g*th. Hence
%     rms_inj(K) = K * rms_inj(1)
% EXACTLY, not approximately. One call to make_payload_inject(1) is enough to
% derive K for any target r; bisection here would be wasted work.
%
% That linearisation is a property of the ANALYSIS MODEL, not of the plant. The
% simulated pendulum (simulink_blocks/payload_pendulum_derivative.m) integrates
% sin/cos and uses the full tether tension, and any claim that IT linearises has
% been withdrawn - see pool_rule.m (L1) and Section 6, R6.2. The superposition
% make_payload_inject relies on is justified separately, by measurement: §0.35
% found the pendulum response on a circular orbit to be 99.98% a single sinusoid
% at sigma.
%
% Why r is the right axis: Guo's exosystem assumption (eq. 6) states d_mf = B*xi
% with xi' = A*xi. Model mismatch is "how much of d_mf is NOT generated by that
% exosystem", and r = rms(out-of-model)/rms(in-model) measures exactly that. The
% alternative, o, measures it indirectly through harmonic content, and at Test 4
% it collapses because the pendulum resonance (3.132) coincides with the second
% harmonic (3.150) - see §0.62.
kinj = opt.InjectK;
if ~isempty(opt.InjectRatio)
    assert(isempty(opt.InjectK), ...
        'pa_configs: both InjectK and InjectRatio were given - choose one.');
    if opt.InjectRatio <= 0
        kinj = 0;
    else
        i1 = make_payload_inject(1, 'TStat', opt.TStat);
        assert(i1.rms_inj > 0, 'pa_configs: rms_inj(K=1) = 0, cannot derive K.');
        kinj = opt.InjectRatio * i1.rms_sine / i1.rms_inj;
    end
end
if ~isempty(kinj) && kinj > 0
    inj = make_payload_inject(kinj, 'TStat', opt.TStat);
    inj.ratio = inj.rms_inj / max(inj.rms_sine, eps);
    assignin('base', 'payload_inj_on', 1);
    say(sprintf(['    out-of-model: r = %.3f (K = %.3f) | RMS %.4f N | ' ...
                 'o = %.2f%%\n'], inj.ratio, inj.K, inj.rms_inj, 100*inj.o));
else
    inj = struct('K', 0, 'o', 0, 'rms_inj', 0, 'rms_sine', NaN, 'ratio', 0);
    assignin('base', 'payload_inj_on', 0);
    if evalin('base','exist(''wind_ts'',''var'')')
        try, make_payload_inject(0); catch, end       % zero series on the right grid
    elseif ~evalin('base','exist(''dmf_inj_ts'',''var'')')
        assignin('base','dmf_inj_ts', struct('time',[0;1], ...
                 'signals',struct('values',zeros(2,3),'dimensions',3)));
    end
end
M0_inject = inj;
[~, K_w] = wind_to_force([]);

% *** PLANT P2 (GD2b, docs/devlog/GD2B_DESIGN.md). LAST, after every variable it
% reads is final (m_p, L, payload_K_ratio, do_info, the condition). ***
% Default 'v1' = nothing here runs; init_MOBADC_params has already set
% plant_model = 0 and zero trims, so every existing call is unchanged.
p2info = [];
switch lower(opt.PlantModel)
    case 'v1'
    case 'p2'
        p2info = p2_setup(matfile, 'Cold', opt.P2Cold, 'Poison', opt.P2Poison, ...
            'SensorNoise', opt.P2SensorNoise, 'ZetaS', opt.P2ZetaS, 'TauM', opt.P2TauM, ...
            'MotorLag', opt.P2MotorLag, 'Discrete', opt.P2Discrete, 'Sensors', opt.P2Sensors, ...
            'N6', opt.P2N6, 'N6TauMs', opt.P2N6TauMs, 'PredScale', opt.P2PredScale, ...
            'Cmp', opt.P2Cmp, 'H3Hz', opt.P2H3Hz, ...
            'ImuScale', opt.P2ImuScale, 'ThrustMax', opt.P2ThrustMax, 'AccBias', opt.P2AccBias, ...
            'AccBiasAxes', opt.P2AccBiasAxes, 'M3', opt.P2M3, 'M3TauMs', opt.P2M3TauMs, 'M3Acc', opt.P2M3Acc, ...
            'TrimFF', opt.P2TrimFF);
        say(sprintf(['    PLANT P2: f_max %.4f N, F_TOT_MAX %.3f N, K %.2f, m_L %.2f, L %.2f, ' ...
            'zeta_s %.3f, tau_m %.0f ms, trim: %s%s%s\n'], ...
            evalin('base','f_max'), evalin('base','F_TOT_MAX'), p2info.params.K, ...
            p2info.params.m_L, p2info.params.L, p2info.params.zeta_s, 1000*p2info.params.tau_m, ...
            p2info.trim_target, tern(~opt.P2SensorNoise, ', sensor noise OFF', ''), ...
            tern(opt.P2Poison, ', POISON (B6)', '')));
        say(sprintf('    P2 stage switches (GD3): motor lag %d, discrete %d, sensors %d\n', ...
            opt.P2MotorLag, opt.P2Discrete, opt.P2Sensors));
        if opt.P2N6
            say(sprintf('    N6 wind -> payload term ON, horizon %g ms (REGISTER_P2 sec 15.4)\n', opt.P2N6TauMs));
        end
        if opt.P2M3
            say(sprintf('    (iii) pendulum model ON, tau_m %g ms, acceleration %s; DO on the residual (REGISTER_P2 sec 45)\n', ...
                opt.P2M3TauMs, opt.P2M3Acc));
        end
        if opt.P2TrimFF
            say(sprintf('    known payload weight pre-compensated in dmf_hat (REGISTER_P2 sec 47)\n'));
        end
        if opt.P2Cmp == 1
            say(sprintf('    competitor H3 (sec 40.1): INDI-type estimate, filter %g Hz; wind channel 0\n', opt.P2H3Hz));
        end
        if ~isempty(opt.P2PredScale)
            ps_ = opt.P2PredScale(:).';  if numel(ps_) == 3, ps_(4) = ps_(3); end
            say(sprintf(['    controller-side parameter scale (sec 39, 42): L %g, m_L %g, C_D*A payload %g, ' ...
                'body %g (plant nominal)\n'], ps_));
        end
        if opt.P2ImuScale ~= 1
            say(sprintf('    IMU noise sigma x %g (sec 42, E3)\n', opt.P2ImuScale));
        end
    otherwise
        error('pa_configs: PlantModel must be ''v1'' or ''p2''.');
end

SW = {[po '/Manual Switch'], [po '/Manual Switch1'], ...
      [mdl '/Attitude_Observer/Manual Switch2']};
old = cellfun(@(b) get_param(b,'sw'), SW, 'UniformOutput', false);
oldv = pa_grab({'wind_pred_on','wind_use_pred','predictor_on'});
restore = onCleanup(@() pa_restore(SW, old, oldv)); %#ok<NASGU>
% *** THE THREE MANUAL SWITCHES THAT SELECT THE CONTROLLER ***
%
%     Position_Observers/Manual Switch    d_mf_hat   (DO)
%     Position_Observers/Manual Switch1   d_lf_hat   (position ESO)
%     Attitude_Observer/Manual Switch2    d_ltau_hat (ESO tu the)
%     Classical {0,0,0} | ESO {0,1,1} | DO {1,0,0} | MOBADC {1,1,1}
%
% This line ALREADY forced {1,1,1} unconditionally - i.e. pa_configs ALWAYS ran
% MOBADC, which was correct for everything before the benchmark. The onCleanup
% above restores the previous state, so there is no leakage risk (§0.83a stated
% that wrongly; see §0.85).
%
% 'Switches' selects a different controller. It must be applied HERE and
% nowhere else in the function: a block that sets them earlier would be
% overwritten by this very line, and the whole benchmark grid would silently
% run MOBADC four times. That actually happened, at a cost of 2850 s (§0.85).
if isempty(opt.Switches)
    for i = 1:3, set_param(SW{i}, 'sw', '1'); end
else
    assert(numel(opt.Switches) == 3, 'pa_configs: ''Switches'' must have 3 elements.');
    for i = 1:3, set_param(SW{i}, 'sw', opt.Switches{i}); end
    say(sprintf('    controller: switch = %s\n', strjoin(opt.Switches, ',')));
end

% Columns: name | predictor_on (PAYLOAD) | wind_pred_on | wind_use_pred | label
%
% 'Grid' = the paper's 2x2 table: two channels, each either estimated or
% predicted, plus the two existing controls - wind sensor without prediction,
% and the oracle on both channels. The default keeps the original four
% configurations so that no old verify/sweep result changes by a digit.
%
% The labels are for display and become M.labels. Result files written before
% the English conversion keep the labels they were written with - the same rule
% as G.rule; see fig_data.m.
if opt.Grid
    CFG = {'g_base',  0, 0, 0, 'MOBADC'; ...
           'g_pay',   1, 0, 0, '+ PAYLOAD prediction'; ...
           'g_wind',  0, 1, 1, '+ WIND prediction'; ...
           'g_both',  1, 1, 1, 'PA-MOBADC'; ...
           'g_sens',  0, 1, 0, '(wind sensor)'; ...
           'g_psens', 1, 1, 0, '(sensor + PAYLOAD)'; ...
           'g_orac',  1, 1, 2, '(CEILING, both channels)'};
else
    CFG = {'p_obs',  0, 0, 0, 'MOBADC'; ...
           'p_sens', 0, 1, 0, '+ sensor'; ...
           'p_pred', 0, 1, 1, '+ PI-MoE'; ...
           'p_orac', 0, 1, 2, '+ ORACLE'};
end

% 'Only' runs a subset. It exists to MEASURE ONE MORE configuration on top of
% an existing result set without re-running the whole grid: the metric computed
% in this function depends only on the .mat file and the configuration, not on
% which other configurations ran alongside. The mask and dt come from the FIRST
% run, and t is identical across configurations, so a single added row still
% produces exactly the right number.
if ~isempty(opt.Only)
    sel = ismember(CFG(:,1), opt.Only);
    assert(any(sel), 'pa_configs: ''Only'' matched no configuration name.');
    CFG = CFG(sel,:);
end

R = struct();
crashed = false(size(CFG,1), 1);
crash_msg = repmat({''}, size(CFG,1), 1);
for c = 1:size(CFG,1)
    assignin('base', 'predictor_on',  CFG{c,2});
    assignin('base', 'wind_pred_on',  CFG{c,3});
    assignin('base', 'wind_use_pred', CFG{c,4});
    say(sprintf('    %-14s ', CFG{c,5}));
    % SOLVER DIVERGENCE, which is not the same as TRACKING-ERROR divergence.
    %
    % The divergence detector below measures mean(||e||) > 1 m over the log. It
    % cannot run when Simulink STOPS by itself midway - "Derivative of state ...
    % is not finite" throws an exception and there is no log at all. This
    % happened at Test 4, segment i0006 (U = 12.14 m/s), t = 196.3 s, in the
    % attitude ESO's Int_za block,
    % because the Test 4 trajectory demands 6.4 times the horizontal force of
    % Test 2 (R*w^2 = 1.98 against 0.31 m/s^2), and together with strong wind
    % the thrust vector tilts far enough to hit Fz_min or f_max.
    %
    % That is a PHYSICAL OUTCOME and must be CLASSIFIED, not allowed to bring
    % down a 30-segment sweep on its third segment. Catch it, flag it, carry on -
    % and sweep_pa_grid then counts and excludes SYMMETRICALLY across every
    % configuration.
    % 'Step' default '1e-3' reproduces every existing call bit-exact - added
    % only to let a step-size sensitivity check (docs/REGISTER_C.md sec
    % 4.14's N3) run the SAME grid machinery every published number goes
    % through, rather than a separate hand-rolled sim() call that could
    % silently diverge from what pa_configs actually does.
    try
        o = sim(mdl,'StopTime',num2str(opt.Stop),'Solver','ode4','FixedStep',opt.Step);
    catch err
        if ~strcmpi(opt.OnDiverge, 'flag')
            error('pa_configs:solver', '%s', sprintf( ...
                ['THE SOLVER STOPPED in configuration %s, segment %s:\n  %s\n\n' ...
                 'This is usually physical saturation (Fz_min or f_max), not a\n' ...
                 'numerical fault - do NOT reduce the step size to push it\n' ...
                 'through, because that is adjusting the experiment to fit the\n' ...
                 'result.\n' ...
                 'Use ''OnDiverge'',''flag'' to classify it and carry on.'], ...
                CFG{c,5}, matfile, err.message));
        end
        crashed(c) = true;  crash_msg{c} = one_line(err.message);
        say(sprintf('SOLVER STOPPED\n'));
        continue
    end
    say('.');
    nm = CFG{c,1};
    % Check the LOG LENGTH on the spot.
    %
    % The Simulink Data Inspector can delete a run by itself when the disk
    % fills ("automatically deleting run"), and the log is then TRUNCATED -
    % 174762 samples were measured instead of 200001. The indices i and j are
    % computed from the FIRST run and applied to all four, so a shorter run
    % dies at the line "q.dh(i,:) - q.d(j,:)" with "Index exceeds array
    % bounds", which says nothing about the disk or about SDI. Catch it here,
    % and say what to do about it.
    nexp = round(opt.Stop/str2double(opt.Step)) + 1;
    if numel(o.dlf_log.time) ~= nexp
        error('pa_configs:truncated', ...
            ['The log was TRUNCATED in configuration %s: %d samples, expected %d.\n\n' ...
             'Usually the Simulink Data Inspector deleted the run because the\n' ...
             'disk filled ("automatically deleting run"). Fix:\n' ...
             '    Simulink.sdi.clear\n' ...
             '    Simulink.sdi.setAutoArchiveMode(false)\n' ...
             'then re-run. sweep_pa_mobadc calls Simulink.sdi.clear after every\n' ...
             'segment, but a single segment run has to clean up for itself.'], ...
            CFG{c,5}, numel(o.dlf_log.time), nexp);
    end
    R.(nm).t  = o.dlf_log.time;
    R.(nm).d  = pa_sq3(o.dlf_log.signals.values);
    R.(nm).dh = pa_sq3(o.dlfhat_log.signals.values);
    R.(nm).ob = pa_sq3(o.dlf_obs_log.signals.values);
    R.(nm).g  = pa_sq3(o.gamma_log.signals.values);
    R.(nm).gd = pa_sq3(o.gammad_log.signals.values);
    % The PAYLOAD channel - OPTIONAL, and it has to be optional. dmf_tot_log is
    % created by build_payload_inject and dmf_pred_log by
    % build_payload_predictor; a model that has not been through both build
    % steps does not have them, and that is not an error. They are needed to
    % measure the DO residual on the payload channel DIRECTLY - see
    % probe_dc_mode: "the energy is DC" does not by itself imply "performance is
    % recovered", so both have to be measured rather than one inferred from the
    % other.
    R.(nm).dm  = pa_opt_log(o, 'dmf_tot_log');
    R.(nm).dmh = pa_opt_log(o, 'dmf_pred_log');
    % Part 3.8 (docs/REGISTER_C.md sec 4.26) fields, read UNCONDITIONALLY -
    % unlike KeepLog below, which is opt-in per caller. theta_log is logged
    % off Payload_Pendulum/2, upstream of PL_Switch, so it is always present
    % once build_payload_pendulum has run; eta_d_log/f_i_log/f_act_log/
    % tau_act_log are the same four logs analysis/probe_saturation.m already
    % reads via KeepLog for docs/RESULTS.md R6.2.1 - read with pa_raw_log
    % (not pa_opt_log) so a model without them yet (or an interrupted run)
    % gives {ok:false}, not a hard error, and the metrics loop below can skip
    % the fields that depend on them rather than fail the whole call.
    R.(nm).theta   = pa_raw_log(o, 'theta_log');
    R.(nm).eta_d   = pa_raw_log(o, 'eta_d_log');
    R.(nm).f_i     = pa_raw_log(o, 'f_i_log');
    R.(nm).f_act   = pa_raw_log(o, 'f_act_log');
    R.(nm).tau_act = pa_raw_log(o, 'tau_act_log');
    if ~isempty(p2info)
        R.(nm).p2 = p2_summary(pa_raw_log(o, 'p2_mon_log'), pa_raw_log(o, 'p2_f_log'), ...
            opt.TStat, evalin('base', 'f_max'), R.(nm).eta_d);   % + tilt clamp (REGISTER_P2 sec 4.1)
    end
    % RAW LOGS on request (KeepLog). The model's To Workspace blocks do NOT
    % reach the base workspace: sim() returns a SimulationOutput and the logs
    % live inside it. Anyone reading them with evalin('base', ...) gets
    % "Unrecognized function or variable" even though the log block ran
    % perfectly - which is exactly what happened with probe_saturation. So they
    % are read HERE, the one place where they are still alive, and carried out.
    for kk = 1:numel(opt.KeepLog)
        R.(nm).log.(opt.KeepLog{kk}) = pa_raw_log(o, opt.KeepLog{kk});
    end
end
say(sprintf('\n'));

% The SURVIVING runs must be the same length before they can share one index set.
ok = find(~crashed);
% EVERY configuration died. With OnDiverge='error' this stops outright; with
% 'flag' it is simply a STRESS point outside the flight envelope, and a stress
% sweep must RECORD it and continue rather than collapse. It did collapse P0 at
% K = 2, segment i0264.
if isempty(ok)
    if ~strcmpi(opt.OnDiverge, 'flag')
        error('pa_configs:allcrash', '%s', sprintf( ...
            ['EVERY configuration stopped the solver on segment %s.\n' ...
             'This segment is outside the flight envelope at the condition being\n' ...
             'run - no metric can be computed at all. Use ''OnDiverge'',''flag''\n' ...
             'to classify it and carry on.'], matfile));
    end
    % real_file / split MUST be present even when every configuration crashed
    % (§0.94c). Without them day_of(M) returns empty, the segment disappears
    % from the 'day' column, and dump_used_days does NOT record that day - even
    % though the segment DID RUN and the day WAS SPENT. That is a used day that
    % could come back as a candidate for the confirmation set. Measured: the
    % K = 1.0 grid lost exactly one day this way (16 instead of 17).
    M = struct('file', matfile, 'all_crashed', true, ...
               'n_force', 0, 'n_track', 0, 'idx_force', [], 'idx_target', [], ...
               'dt', NaN, 'payload_model', pm, 'sensor', M0_sensor, ...
               'inject', M0_inject, 'cond', M0_cond, ...
               'labels', {CFG(:,5)'}, 'names', {CFG(:,1)'});
    % plant P2 (GD2b): the set-up travels with the result even when every column
    % stopped, so the stop can be diagnosed against the exact P2 parameters.
    M.cond.PlantModel = lower(opt.PlantModel);
    if ~isempty(p2info), M.cond.p2 = p2info; end
    for fq = {'real_file','split'}
        if isfield(S, fq{1}), M.(fq{1}) = strtrim(char(S.(fq{1}))); end
    end
    for c = 1:size(CFG,1)
        M.(CFG{c,1}) = struct('diverged', true, 'crashed', true, ...
            'crash_msg', crash_msg{c}, 'max_dlfhat', NaN, 'mean', NaN, ...
            'std', NaN, 'max', NaN, 'sse_track', NaN, 'rms_force', NaN, ...
            'sse_force', NaN, 'dc_force', NaN, 'mean_filt', NaN, 'max_filt', NaN, 'e_p95', NaN, ...
            'sat_p2', NaN, 'sat_rotor', NaN, 'u_osc', NaN);
    end
    R = struct();
    fprintf('    ! EVERY configuration diverged on %s - recorded, carrying on\n', matfile);
    return
end
n0 = numel(R.(CFG{ok(1),1}).t);
for c = ok(:)'
    assert(numel(R.(CFG{c,1}).t) == n0, 'pa_configs:len', ...
        'Configuration %s has %d samples, unlike the first run (%d).', ...
        CFG{c,5}, numel(R.(CFG{c,1}).t), n0);
end

%% ---------------- the locked metric ----------------
t   = R.(CFG{ok(1),1}).t;
dt  = t(2) - t(1);
tau = S.tau_ms * 1e-3;
ktau = round(tau/dt);
tp  = S.t_pred(:);

% The FORCE-channel mask: identical to diag_wind_channel (isfinite(dhat) bounds
% it above at tp(end), not at Stop - tau).
dhat = K_w * interp1(tp, S.w_hat, t, 'previous', NaN);
mk = (t >= opt.TStat) & (t <= opt.Stop - tau) & all(isfinite(dhat), 2);
i = find(mk); j = i + ktau;

% The TRACKING-error mask: the whole steady-state window. The two masks differ
% DELIBERATELY - the tracking error is not constrained by the prediction
% horizon.
ms = (t >= opt.TStat);

M = struct('file', matfile, 'tau_ms', S.tau_ms, 'n_force', numel(i), ...
           'n_track', sum(ms));
% Exported so that other functions recompute EXACTLY the force-error residual
% this metric used. spectrum_pa needs precisely this; if it derived its own, the
% two would drift apart without anyone noticing.
M.idx_force = i;  M.idx_target = j;  M.dt = dt;
% Peak of the TRUE and the PREDICTED wind force, computed from the file, not
% from the log. When a configuration stops the solver there is no log at all and
% max_dlfhat is NaN; these two fields still exist, so the question "did the
% predictor spike?" can still be answered from the result set that was actually
% produced. See analysis/diag_pred_spike.m.
M.peak_pred_N = NaN;  M.peak_true_N = NaN;
if isfield(S,'w_hat') && size(S.w_hat,2) >= 2
    M.peak_pred_N = K_w * max(sqrt(sum(double(S.w_hat(:,1:2)).^2, 2)));
end
if isfield(S,'w_plant') && size(S.w_plant,2) >= 2
    M.peak_true_N = K_w * max(sqrt(sum(double(S.w_plant(:,1:2)).^2, 2)));
end
for f = {'real_height_m','real_U','real_I','skill_check', ...
         'skill_check_noisy_ref','sensor_noise','sensor_bias'}
    if isfield(S,f{1}), M.(f{1}) = double(S.(f{1})); end
end
for f = {'real_file','split'}
    if isfield(S,f{1}), M.(f{1}) = strtrim(char(S.(f{1}))); end
end

% Closed-loop parameters for the filter. Taken from the base workspace
% (init_MOBADC_params); the fallback is the value run_baseline uses in its
% analytic cross-check.
m_  = pa_base('m',  1.121);
f_max_     = pa_base('f_max', 6.0);                 % sec 60.4: limits of the plant in use (P2 via p2_setup)
F_TOT_MAX_ = pa_base('F_TOT_MAX', 21.6);
Ky_ = pa_base('Ky', 12);
Kv_ = pa_base('Kv', 8);
M.m = m_; M.Ky = Ky_(1,1); M.Kv = Kv_(1,1);

nmv = CFG(:,1)';
for c = 1:numel(nmv)
    % A configuration that stopped the solver: the metric is NaN, with both
    % diverged and crashed set. It must NOT be set to 0 or skipped - a 0 would
    % pool in as a perfect run, and that is how a divergence turns into a good
    % result.
    if crashed(c)
        M.(nmv{c}) = struct('diverged', true, 'crashed', true, ...
            'crash_msg', crash_msg{c}, 'max_dlfhat', NaN, ...
            'mean', NaN, 'std', NaN, 'max', NaN, 'sse_track', NaN, ...
            'rms_force', NaN, 'sse_force', NaN, 'dc_force', NaN, ...
            'mean_filt', NaN, 'max_filt', NaN, ...
            'div', true, 'e_rms', NaN, 'e_max', NaN, 'e_t', struct('t',[],'v',[]), ...
            'ef_pay', NaN, 'ef_wind', NaN, 'th_rms', NaN, 'th_max', NaN, ...
            'sat_frac', NaN, 'u_rms', NaN, 'e_p95', NaN, 'sat_p2', NaN, 'sat_rotor', NaN, 'u_osc', NaN);
        continue
    end
    q  = R.(nmv{c});
    en = sqrt(sum((q.gd(ms,:) - q.g(ms,:)).^2, 2));
    r  = q.dh(i,:) - q.d(j,:);
    % Tracking error PREDICTED from the residual force error, through the
    % closed-loop dynamics. This is the residual energy WEIGHTED by |H(jw)|^2 -
    % the quantity §0.29 was missing. The first half is dropped so the filter's
    % own transient does not enter the statistic. See core/pa_track_filt.m.
    ef = pa_track_filt(r, m_, Ky_, Kv_, dt);
    q0 = max(1, round(numel(ef)/2));
    % DIVERGENCE. A tracking error of several metres is not a control result,
    % and pooling it into an RMS destroys the whole row (measured: one segment
    % at 4.92 m pulled the pooled value from ~0.003 to 7.69).
    %
    % But stopping outright is also wrong, and DROPPING the segment is worse
    % still - that is selecting segments on the result. Divergence is a
    % CLASSIFIED OUTCOME: it must be COUNTED and REPORTED, and the pooling then
    % happens on the set of segments stable in EVERY configuration. That rule
    % lives in core/pool_rule.m, (L2).
    %
    % Measured on segment i0006 (U = 12.14 m/s, I = 43.4%): sensor noise of
    % 0.6 m/s adds only K_w*0.6 = 0.12 N = 1.1% of hover thrust - it cannot
    % cause divergence by AMPLITUDE. That segment was already close to a LIMIT
    % (f_max = 6 N per motor, or Fz_min) and the noise merely pushed it over. So
    % it is reported with a saturation diagnosis rather than just as
    % "divergence".
    %
    % Note that saturation was later measured across 29 segments and REJECTED as
    % the general mechanism of divergence (docs/RESULTS.md R6.2.1): the tilt
    % clamp is the only limit that ever activates, and two non-diverged segments
    % sat at 49.2% and 63.5% activation. The reading above is about this one
    % segment, not a general explanation.
    dv = ~isfinite(mean(en)) || mean(en) > 1.0;
    if dv && strcmpi(opt.OnDiverge, 'error')
        error('pa_configs:diverged', ...
            ['DIVERGED in %s, segment %s: mean tracking error %.3f m.\n' ...
             'Use ''OnDiverge'',''flag'' to record it and carry on.'], ...
            nmv{c}, matfile, mean(en));
    end
    rms_force_ = sqrt(mean(sum(r.^2, 2)));

    % ---- Part 3.8 (docs/REGISTER_C.md sec 4.26) ----
    % e_rms/e_t: 'en' is ALREADY restricted to the ms (t>=TStat) window
    % above (en = ||gd-g|| computed from q.gd(ms,:)/q.g(ms,:)) - no further
    % masking here, re-indexing 'en' by 'ms' would be wrong (ms is a mask
    % over the FULL t, en already has length sum(ms)).
    e_rms = sqrt(mean(en.^2));
    e_max = max(en);
    % e_p95 (REGISTER_P2 sec 60.4, additive): nearest rank, the ceil(0.95 n)-th
    % smallest error norm over t >= TStat - no prctile (toolbox, interpolation).
    es = sort(en);
    e_p95 = NaN;
    if ~isempty(es), e_p95 = es(max(1, ceil(0.95 * numel(es)))); end
    tms = t(ms);
    e_t = struct('t', tms(1:10:end), 'v', en(1:10:end));

    % ef_pay: the PAYLOAD channel's own delay (base workspace tau_pred),
    % NOT the wind file's S.tau_ms/ktau used for i/j above - see sec 4.26.
    tau_pred_ = pa_base('tau_pred', 0.22);
    ktau_pay  = round(tau_pred_/dt);
    idxp = find(ms & (t <= opt.Stop - tau_pred_));
    if isempty(idxp) || isempty(q.dm) || isempty(q.dmh)
        ef_pay = NaN;
    else
        ef_pay = sqrt(mean(sum((q.dmh(idxp,:) - q.dm(idxp+ktau_pay,:)).^2, 2)));
    end

    % th_rms/th_max: theta_log, its own mask (same t, but built independently
    % since it comes from a separate raw-log struct, not the R.(nm).t used above).
    if q.theta.ok
        thn = sqrt(sum(q.theta.v.^2, 2));
        mst = q.theta.t >= opt.TStat;
        th_rms = sqrt(mean(thn(mst).^2));
        th_max = max(thn(mst));
    else
        th_rms = NaN; th_max = NaN;
    end

    % sat_frac/u_rms: the same four logs analysis/probe_saturation.m already
    % reads, same limit constants, unconditionally combined here (its own
    % four-way breakdown stays there for R6.2.1-style reporting).
    if q.eta_d.ok && q.f_i.ok && q.f_act.ok && q.tau_act.ok
        TILT = 30*pi/180; FMAX = 6.0; FTOT = 21.6; TAUM = 0.5; etol = 1e-3;
        mse = q.eta_d.t >= opt.TStat;
        tiltf  = any(abs(q.eta_d.v(mse,1:2)) >= TILT - etol, 2);
        rotorf = any(q.f_i.v(mse,:) >= FMAX - etol | q.f_i.v(mse,:) <= etol, 2);
        ftotf  = q.f_act.v(mse) >= FTOT - etol;
        torqf  = any(abs(q.tau_act.v(mse,:)) >= TAUM - etol, 2);
        sat_frac = mean(tiltf | rotorf | ftotf | torqf);
        f_hover  = m_*9.81/4;
        u_rms    = sqrt(mean(sum((q.f_i.v(mse,:) - f_hover).^2, 2)));
    else
        sat_frac = NaN; u_rms = NaN;
    end
    % REGISTER_P2 sec 60.4 (additive; sat_frac / u_rms above keep their v1 definition and constants):
    % saturation with the limits of the plant in use (base f_max, F_TOT_MAX) on the commanded rotor
    % forces f_i, and the effort as the RMS oscillation of f_i about its own mean - core/p2_cmd_sat.m.
    [sat_p2, sat_rotor, u_osc] = p2_cmd_sat(q.f_i, q.f_act, opt.TStat, f_max_, F_TOT_MAX_);

    M.(nmv{c}) = struct( ...
        'diverged', dv, 'crashed', false, 'crash_msg', '', ...
        'max_dlfhat', max(sqrt(sum(q.dh.^2, 2))), ...
        'mean', mean(en), 'std', std(en), 'max', max(en), ...
        'sse_track', sum(en.^2), ...
        'rms_force', rms_force_, ...
        'sse_force', sum(r(:).^2), ...
        'dc_force',  norm(mean(r, 1)), ...
        'mean_filt', mean(ef(q0:end)), ...
        'max_filt',  max(ef(q0:end)), ...
        'div', dv, 'e_rms', e_rms, 'e_max', e_max, 'e_t', e_t, ...
        'ef_pay', ef_pay, 'ef_wind', rms_force_, ...
        'th_rms', th_rms, 'th_max', th_max, ...
        'sat_frac', sat_frac, 'u_rms', u_rms, 'e_p95', e_p95, ...
        'sat_p2', sat_p2, 'sat_rotor', sat_rotor, 'u_osc', u_osc);
    % TRAJECTORIES for the figure. Off by default: keeping the time series of
    % every configuration on every segment bloats the result file and nobody
    % reads it. But q.g / q.gd have ALREADY been computed above, so exposing
    % them is just an assignment - it costs no extra run.
    %
    % The x-y trajectory plot is what Guo's Fig. 10 has and no table can
    % replace: a control reviewer wants to SEE it track. It is the paper's only
    % figure (figures/fig6_trajectory.m).
    if opt.KeepTraj
        M.(nmv{c}).t  = q.t(:);
        M.(nmv{c}).g  = q.g;
        M.(nmv{c}).gd = q.gd;
    end
    if isfield(q, 'log'), M.(nmv{c}).log = q.log; end
end
M.labels = CFG(:,5)';
M.names  = nmv;
% Record the mode in the result: two .mat sets from two modes must be
% distinguishable without anyone remembering what was run.
M.payload_model = pm;
M.sensor = M0_sensor;
M.inject = M0_inject;
% The operating condition travels WITH the result, not in someone's memory.
% Every .mat written from MM describes for itself where it was run.
M.cond = M0_cond;
% 'WindOff' is not part of what op_set names a condition - it is this
% function's own switch, so it travels separately rather than being folded
% into M0_cond's own fields (which op_set, not pa_configs, owns).
M.cond.WindOff = opt.WindOff;
M.cond.WindZero = opt.WindZero;
% Plant P2 (GD2b): the plant, its parameters, trims and noise seeds travel with the
% result; per-column flags (REGISTER_P2 sec 0.4) as M.<cfg>.p2.
M.cond.PlantModel  = lower(opt.PlantModel);
M.cond.OracleTauMs = opt.OracleTauMs;
M.cond.P2N6 = opt.P2N6;  M.cond.P2N6TauMs = opt.P2N6TauMs;
if ~isempty(opt.P2PredScale), M.cond.P2PredScale = opt.P2PredScale; end
if opt.P2ImuScale ~= 1, M.cond.P2ImuScale = opt.P2ImuScale; end
if ~isempty(opt.P2ThrustMax), M.cond.P2ThrustMax = opt.P2ThrustMax; end
if ~isempty(opt.P2AccBias) && ~isempty(p2info)
    M.cond.P2AccBias = opt.P2AccBias;  M.cond.P2AccBiasAxes = opt.P2AccBiasAxes;
    M.cond.P2AccBiasVec = p2info.vars.p2_bias_acc;   % sec 45.6 (1): the segment's drawn vector
end
if opt.P2M3, M.cond.P2M3 = true;  M.cond.P2M3TauMs = opt.P2M3TauMs;  M.cond.P2M3Acc = opt.P2M3Acc; end
if opt.P2TrimFF, M.cond.P2TrimFF = true; end
if opt.P2Cmp > 0
    M.cond.P2Cmp = opt.P2Cmp;  M.cond.P2H3Hz = opt.P2H3Hz;
end
if ~isempty(p2info)
    M.cond.p2 = p2info;
    for c = ok(:)'
        if isfield(R.(CFG{c,1}), 'p2'), M.(CFG{c,1}).p2 = R.(CFG{c,1}).p2; end
    end
end
end


function s = seg_seed(name)
%SEG_SEED  A stable integer derived from the segment NAME, so that each segment
% gets its own noise realisation.
% The character sum is used: stable across sessions and independent of the order
% in which the sweep visits segments.
s = sum(double(char(name)));
end


%% =====================================================================
function s = one_line(m)
%ONE_LINE  Simulink error messages span several lines; keep the first, drop the
% line breaks.
% Strips MATLAB hyperlink markup (<a href=...>...</a>) and keeps the WHOLE
% message: the old 160-character cut, eaten by that markup, lost the solver's
% "at time" (docs/REGISTER_ROBUST.md sec 24.3). Formatting only.
s = regexprep(m, '<[^>]*>', '');
s = strtrim(regexprep(s, '\s+', ' '));
end

function s = pm_name(pm)
if pm > 0.5, s = 'physical PENDULUM (payload_model = 1)';
else,        s = 'sinusoidal (payload_model = 0)'; end
end

function v = pa_opt_log(o, name)
%PA_OPT_LOG  Read a To Workspace log if it exists; return [] if it does not.
v = [];
try
    if isprop(o, name) || (isstruct(o) && isfield(o, name))
        v = pa_sq3(o.(name).signals.values);
    end
catch
    v = [];
end
end
function s = pa_raw_log(o, name)
%PA_RAW_LOG  One To Workspace log as recorded: .t and .v, rows = time.
%
%  FOUR FORMATS, not one. In baseline1.slx, 13 To Workspace blocks set
%  SaveFormat = 'Structure With Time' and ONE - eta_d_log - is left at the
%  default, i.e. 'Timeseries'. Reading it as w.signals.values returns empty for
%  that one block, and that is exactly what happened: the previous fix bought a
%  better error message without reading a single number.
%
%  So this dispatches on the DATA TYPE rather than on an assumption, and when it
%  still cannot read a log it says which class and what size, so the next
%  diagnosis takes one run instead of two.
%
%  The model's SaveFormat is deliberately NOT changed: altering a logging
%  parameter is a model edit, and every model edit carries the obligation to
%  prove nothing else changed. Reading all four formats needs no model edit at
%  all.
s = struct('t', [], 'v', [], 'ok', false, 'why', '');
try
    if ~(isprop(o, name) || (isstruct(o) && isfield(o, name)))
        s.why = 'not present in the sim output';  return
    end
    w = o.(name);
    t = [];  v = [];
    if isa(w, 'timeseries')                       % 'Timeseries' (the default)
        t = w.Time(:);  v = w.Data;
    elseif isstruct(w) && isfield(w, 'signals')   % 'Structure [With Time]'
        v = w.signals.values;
        if isfield(w, 'time'), t = w.time(:); end
    elseif isnumeric(w)                           % 'Array'
        v = w;
    else
        s.why = sprintf('class ''%s'' is not a format this can read', class(w));  return
    end
    v = squeeze(v);
    if isempty(t)
        % 'Array' and 'Structure' carry no time vector; tout is the only source.
        if isprop(o,'tout') || (isstruct(o) && isfield(o,'tout')), t = o.tout(:); end
    end
    if size(v,1) ~= numel(t) && size(v,2) == numel(t), v = v.'; end
    s.t = t;  s.v = v;
    s.ok = ~isempty(t) && size(v,1) == numel(t);
    if ~s.ok
        s.why = sprintf('%d time samples, data %s (class %s)', ...
                        numel(t), mat2str(size(v)), class(w));
    end
catch err
    s = struct('t', [], 'v', [], 'ok', false, 'why', one_line(err.message));
end
end

function v = pa_sq3(v)
v = squeeze(v);
if size(v,1) == 3 && size(v,2) ~= 3, v = v.'; end
end

function v = pa_base(name, dflt)
if evalin('base', sprintf('exist(''%s'',''var'')', name))
    v = evalin('base', name);
else
    v = dflt;
    fprintf('  ! ''%s'' not found in base - using the fallback %g\n', name, dflt);
end
end

function K = pa_grab(names)
K = struct('names', {names}, 'vals', {cell(size(names))}, ...
           'has', false(size(names)));
for i = 1:numel(names)
    if evalin('base', sprintf('exist(''%s'',''var'')', names{i}))
        K.has(i) = true;  K.vals{i} = evalin('base', names{i});
    end
end
end

function pa_restore(SW, old, K)
try, cellfun(@(b,v) set_param(b,'sw',v), SW, old); catch, end
for i = 1:numel(K.names)
    if K.has(i)
        try, assignin('base', K.names{i}, K.vals{i}); catch, end
    end
end
end

%% =====================================================================
function s = tern(c, a, b)
%TERN  Inline if for message text (plant P2 printout).
if c, s = a; else, s = b; end
end
