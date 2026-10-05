function build_im_est_online(varargin)
%BUILD_IM_EST_ONLINE  Online IM-est (docs/REGISTER_C.md sec 4.29/4.35/
%                      4.46/4.47/4.49): a plain Subsystem
%                      (Position_Observers/IM_Est_Online, no Enable
%                      port - sec 4.49 made it redundant) that reads
%                      nu_dot off the existing global tag, filters +
%                      decimates to 1 Hz, runs the RLS/trust-gate
%                      estimator (simulink_blocks/im_est_estimator.m)
%                      and the fixed-slot matrix rebuild
%                      (simulink_blocks/im_est_do_rebuild.m), and feeds
%                      the result through four Variant Source blocks
%                      that resolve, AT COMPILE TIME, between this and
%                      the ORIGINAL Ad/Bd/lg/Gd Constants (left in
%                      place, untouched), on im_est_online_on.
%
%   build_im_est_online('Save', true)
%   build_im_est_online('Revert', true)
%
%  ======================================================================
%  BUILT IN VERIFIED STEPS, NOW COMBINED HERE
%  ======================================================================
%  This is the highest-blast-radius build in the whole campaign - it
%  touches Position_Observers/DO_12, which every published number in
%  this project's entire history runs through, and it cannot be tested
%  here (no MATLAB/Simulink in this environment). It was built and
%  checkpointed in stages, each verified before the next:
%    1. Bypass-switch scaffolding with a STUB pass-through (both
%       branches read A_do/B_do/l_gain/G_do directly, so bit-exactness
%       with im_est_online_on=0 held trivially by construction) -
%       checkpoint 1, PASS (verify_repro/check_results_numbers/
%       check_all all bit-exact, in-memory and after save+reload).
%    2. The estimator, tested in isolation (a THROWAWAY model, not this
%       one - analysis/verify_imest_estimator_isolated.m) against
%       core/im_est_rls.m - checkpoint 1.5, PASS (5.7e-14 rad/s, five
%       orders of magnitude inside the 1e-9 tolerance).
%    3. The matrix rebuild's construction, tested against
%       build_do_matrices.m directly (analysis/
%       verify_imest_do_rebuild_equivalence.m, no Simulink model) -
%       PASS, bit-exact (0.000e+00).
%    4. The real wiring, with a Switch-based bypass, FAILED to compile
%       (sec 4.48): a Switch compiles both branches unconditionally,
%       and the online path's fixed 25-state construction cannot
%       dimension-match whatever smaller n_state the current scenario's
%       own Ad/Bd/lg/Gd happen to be - a structural conflict, not a
%       wiring bug. Fixed by replacing the 4 Switches with 4 Variant
%       Source blocks (sec 4.49), resolved at compile time, which
%       exclude the INACTIVE branch's content from compilation entirely
%       - verified in isolation first (analysis/
%       probe_variant_source_api.m) before this rewrite.
%  This file now wires the CHECKPOINTED estimator and rebuild into the
%  Subsystem via Variant Source, replacing the Switch attempt -
%  checkpoints 2-4 (circle convergence, the w_hat step test, T5 vs
%  frozen, DO stability/fallback rate) apply to what THIS wiring
%  produces closed-loop, next.
%
%  ======================================================================
%  WIRING VERIFIED DIRECTLY FROM baseline1.slx's OWN XML (sec 4.46)
%  ======================================================================
%  do_derivative (Position_Observers/DO_12, a MATLAB Function/Stateflow
%  chart, SID 83, 10 inputs) reads A_do/B_do/l_gain/G_do (ports 6-9)
%  from four Constant blocks already in Position_Observers: Ad (SID 81),
%  Bd (SID 82), lg (SID 106), Gd (SID 94) - each Value = the base-
%  workspace variable name as a string, the SAME idiom
%  build_payload_predictor.m's own PP_lg/PP_sigma/etc. already use.
%  This script does not delete or rename any of the four - it only cuts
%  their EXISTING line into DO_12 (one line each) and re-routes DO_12's
%  inputs through a new Variant Source per port (sec 4.49 - a Switch,
%  build_payload_predictor.m's own free_switch_input/PP_Switch pattern
%  for Manual Switch/DO_Out, was tried first but does not work here;
%  see sec 4.48).
%
%  nu_dot is read off the SAME global Goto tag build_payload_pendulum.m
%  (PL_F_nu_dot) and build_nu_dot_log.m (PL_F_nu_dot2) already read -
%  Simulink's global tags support multiple independent readers by
%  design (build_nu_dot_log.m's own header) - this is the THIRD, not a
%  new signal path. The Selector (Indices=[1 2] of width 3) replicates
%  build_payload_pendulum.m's own PL_Sel_xy exactly, not a new pattern.

clear functions %#ok<CLFUNC>
% MATLAB does not always reload a .m file's cached bytecode just because
% the file changed on disk mid-session (e.g. a git checkout/pull while
% this function is still resident in memory from an earlier run) - the
% SAME reasoning every analysis/verify_*.m script in this repo already
% opens with. Without this, a fix to this file (or to compile_check/
% print_causes below) can silently keep running the OLD version.

opt = struct('Save', false, 'Revert', false, 'Quiet', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
say = @(varargin) fprintf(varargin{:});
if opt.Quiet, say = @(varargin) []; end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end
po = [mdl '/Position_Observers'];

assert(getSimulinkBlockHandle([po '/Ad']) > 0, ...
    'build_im_est_online: Position_Observers/Ad not found - unexpected model state.');
assert(getSimulinkBlockHandle([po '/DO_12']) > 0, ...
    'build_im_est_online: Position_Observers/DO_12 not found - unexpected model state.');

ES  = [po '/IM_Est_Online'];
swA = [po '/IM_Est_A_Sw']; swB = [po '/IM_Est_B_Sw'];
swL = [po '/IM_Est_L_Sw']; swG = [po '/IM_Est_G_Sw'];

% ---------------- idempotent teardown ----------------
n_removed = teardown(po);
if n_removed > 0
    say('  removed %d block(s) from a previous run\n', n_removed);
end

if opt.Revert
    if opt.Save, save_system(mdl); end
    say('  reverted to baseline (DO_12 fed directly by Ad/Bd/lg/Gd).\n');
    return
end

%% ---------------- Subsystem: the real estimator + rebuild ----------------
add_block('built-in/Subsystem', ES, 'Position',[520 20 1100 400]);
if getSimulinkBlockHandle([ES '/In1']) > 0
    try delete_line(ES, 'In1/1', 'Out1/1'); catch, end
    delete_block([ES '/In1']);
end
if getSimulinkBlockHandle([ES '/Out1']) > 0
    delete_block([ES '/Out1']);
end
% No Enable port (sec 4.49): with the Switch -> Variant Source
% redesign, the Variant Source itself already excludes THIS
% subsystem's entire content from COMPILATION when im_est_online_on=0
% (not merely from execution, which is all an Enable port ever gave -
% the ORIGINAL Stage 2 failure, sec 4.48, happened at COMPILE time,
% which an Enable port never guarded against in the first place). The
% user's own sec 4.49 item 1 explicitly invited dropping it once no
% longer needed - one fewer moving part, one fewer base-workspace
% signal (IM_Est_On) to keep synchronized.

% ---- nu_dot off the existing global tag, x/y only (sec 4.46) ----
add_block('simulink/Signal Routing/From', [ES '/IM_F_nu_dot'], ...
    'GotoTag','nu_dot', 'TagVisibility','global', 'Position',[40 40 150 70]);
add_block('simulink/Signal Routing/Selector', [ES '/IM_Sel_xy'], ...
    'NumberOfDimensions','1', 'IndexMode','One-based', ...
    'IndexOptions','Index vector (dialog)', 'Indices','[1 2]', ...
    'InputPortWidth','3', 'Position',[190 40 240 70]);

% ---- anti-alias filter (fs=1Hz design, sec 4.34) + decimate to 1Hz ----
% Coefficients computed HERE, at build time, the SAME butter() call
% every offline script in this session already uses - not re-derived,
% not hand-copied as literals that could drift from that design.
DT_D = 1.0; LP_HZ = 0.4; DT_RAW = 1e-3;
[bf, af] = butter(2, LP_HZ/(1/(2*DT_RAW)), 'low');
add_block('simulink/Discrete/Discrete Filter', [ES '/IM_Filt'], ...
    'Numerator', mat2str(bf), 'Denominator', mat2str(af), ...
    'SampleTime', num2str(DT_RAW), 'Position',[280 40 380 70]);
add_block('simulink/Discrete/Zero-Order Hold', [ES '/IM_ZOH'], ...
    'SampleTime', num2str(DT_D), 'Position',[420 40 480 70]);
add_block('simulink/Signal Routing/Demux', [ES '/IM_Demux'], ...
    'Outputs','2', 'Position',[520 40 540 70]);

% ---- t, sampled at the SAME 1Hz rate (a Clock alone would be
% continuous - checkpoint 1.5's own test avoided this exact mismatch
% by using a third From Workspace at 1Hz; in closed loop, a
% Zero-Order-Held Clock is the equivalent live-signal construction) ----
add_block('simulink/Sources/Clock', [ES '/IM_Clock'], 'Position',[40 120 90 140]);
add_block('simulink/Discrete/Zero-Order Hold', [ES '/IM_ClockZOH'], ...
    'SampleTime', num2str(DT_D), 'Position',[130 120 190 140]);

% ---- wn_p = sqrt(g/L), L read live (matches every offline script's
% own 'L' base-workspace convention, sec 4.29/4.35/4.46 - never
% estimated, bypasses the RLS entirely) ----
add_block('simulink/Sources/Constant', [ES '/IM_L'], 'Value','L', 'Position',[40 170 140 200]);
add_block('simulink/User-Defined Functions/Fcn', [ES '/IM_WnpFcn'], ...
    'Expr','sqrt(9.81/u)', 'Position',[180 170 280 200]);

% ---- z-axis (unchanged, sec 4.46), l_axis, strict (production=off) ----
add_block('simulink/Sources/Constant', [ES '/IM_Sigma'],  'Value','w_traj', 'Position',[40 220 150 250]);
add_block('simulink/Sources/Constant', [ES '/IM_LAxis'],  'Value','l_axis', 'Position',[40 270 150 300]);
add_block('simulink/Sources/Constant', [ES '/IM_Strict'], 'Value','0',      'Position',[40 320 150 350]);

% ---- the estimator (checkpoint 1.5, PASS) ----
blk_est = [ES '/IM_Estimator'];
add_block('simulink/User-Defined Functions/MATLAB Function', blk_est, 'Position',[600 20 820 300]);
set_eml_script(blk_est, fileread(fullfile(here,'simulink_blocks','im_est_estimator.m')));
assert_ports(blk_est, 3, 8);

% ---- the fixed-slot matrix rebuild (construction-equivalence
% checkpoint, PASS) ----
blk_reb = [ES '/IM_Rebuild'];
add_block('simulink/User-Defined Functions/MATLAB Function', blk_reb, 'Position',[900 20 1080 320]);
set_eml_script(blk_reb, fileread(fullfile(here,'simulink_blocks','im_est_do_rebuild.m')));
assert_ports(blk_reb, 8, 6);

% ---- outports: A/B/l_gain/G_do (1-4, feed the Variant Sources
% outside), fallback/reason (5-6, diagnostic only, sec 4.46 item 1b) ----
add_block('simulink/Sinks/Out1', [ES '/A_out'],  'Port','1', 'Position',[1140  30 1170  46]);
add_block('simulink/Sinks/Out1', [ES '/B_out'],  'Port','2', 'Position',[1140  80 1170  96]);
add_block('simulink/Sinks/Out1', [ES '/L_out'],  'Port','3', 'Position',[1140 130 1170 146]);
add_block('simulink/Sinks/Out1', [ES '/G_out'],  'Port','4', 'Position',[1140 180 1170 196]);
add_block('simulink/Sinks/Out1', [ES '/FB_out'], 'Port','5', 'Position',[1140 230 1170 246]);
add_block('simulink/Sinks/Out1', [ES '/RS_out'], 'Port','6', 'Position',[1140 280 1170 296]);

% ---- wire it up ----
add_line(ES, 'IM_F_nu_dot/1', 'IM_Sel_xy/1', 'autorouting','on');
add_line(ES, 'IM_Sel_xy/1',   'IM_Filt/1',   'autorouting','on');
add_line(ES, 'IM_Filt/1',     'IM_ZOH/1',    'autorouting','on');
add_line(ES, 'IM_ZOH/1',      'IM_Demux/1',  'autorouting','on');
add_line(ES, 'IM_Clock/1',    'IM_ClockZOH/1', 'autorouting','on');
add_line(ES, 'IM_L/1',        'IM_WnpFcn/1', 'autorouting','on');

add_line(ES, 'IM_Demux/1',    'IM_Estimator/1', 'autorouting','on');   % vx
add_line(ES, 'IM_Demux/2',    'IM_Estimator/2', 'autorouting','on');   % vy
add_line(ES, 'IM_ClockZOH/1', 'IM_Estimator/3', 'autorouting','on');   % t

add_line(ES, 'IM_Estimator/1', 'IM_Rebuild/1', 'autorouting','on');    % w_hat_x
add_line(ES, 'IM_Estimator/2', 'IM_Rebuild/2', 'autorouting','on');    % trust_x
add_line(ES, 'IM_Estimator/3', 'IM_Rebuild/3', 'autorouting','on');    % w_hat_y
add_line(ES, 'IM_Estimator/4', 'IM_Rebuild/4', 'autorouting','on');    % trust_y
add_line(ES, 'IM_WnpFcn/1',    'IM_Rebuild/5', 'autorouting','on');    % wn_p
add_line(ES, 'IM_Sigma/1',     'IM_Rebuild/6', 'autorouting','on');    % sigma_z
add_line(ES, 'IM_LAxis/1',     'IM_Rebuild/7', 'autorouting','on');    % l_axis
add_line(ES, 'IM_Strict/1',    'IM_Rebuild/8', 'autorouting','on');    % strict

add_line(ES, 'IM_Rebuild/1', 'A_out/1',  'autorouting','on');
add_line(ES, 'IM_Rebuild/2', 'B_out/1',  'autorouting','on');
add_line(ES, 'IM_Rebuild/3', 'L_out/1',  'autorouting','on');
add_line(ES, 'IM_Rebuild/4', 'G_out/1',  'autorouting','on');
add_line(ES, 'IM_Rebuild/5', 'FB_out/1', 'autorouting','on');
add_line(ES, 'IM_Rebuild/6', 'RS_out/1', 'autorouting','on');

%% ---------------- variant sources (sec 4.49 - replaces the Switch design) ----------------
% Switch (Stage 2's first attempt, sec 4.48) compiles BOTH branches
% unconditionally, so the online path's fixed 25-state construction
% collided with whatever smaller n_state the current scenario's own
% Ad/Bd/lg/Gd happened to be - a compile-time, not run-time, conflict,
% present regardless of im_est_online_on's value. Variant Source,
% resolved at 'update diagram' (compile time), excludes the INACTIVE
% branch's entire upstream content from compilation - verified
% directly, in isolation, before this rewrite (analysis/
% probe_variant_source_api.m: a 25x25 and a 6x6 Constant behind a
% Variant Source compiled cleanly at whichever size was active, and
% correctly re-resolved on toggling the control variable back and
% forth - sec 4.49's own run log). No control SIGNAL is needed (unlike
% Switch's data port 2) - VariantControls is a compile-time expression
% evaluated directly against the base workspace, so IM_Est_On (the
% Constant that used to drive both the switches and the enable port)
% is not created at all.
vs_common = {'VariantControlMode','expression', 'VariantActivationTime','update diagram', ...
             'VariantControls', {'im_est_online_on==1','im_est_online_on==0'}};
add_block('simulink/Signal Routing/Variant Source', swA, vs_common{:}, 'Position',[800  40 840  90]);
add_block('simulink/Signal Routing/Variant Source', swB, vs_common{:}, 'Position',[800 100 840 150]);
add_block('simulink/Signal Routing/Variant Source', swL, vs_common{:}, 'Position',[800 160 840 210]);
add_block('simulink/Signal Routing/Variant Source', swG, vs_common{:}, 'Position',[800 220 840 270]);

%% ---------------- cut DO_12's existing Ad/Bd/lg/Gd lines, re-route ----------------
% DO_12's own input order (do_derivative.m's signature): gamma, nu, z, F,
% dlf_hat, A_do, B_do, l_gain, G_do, g - ports 6/7/8/9 are A_do/B_do/
% l_gain/G_do (sec 4.46's own verified wiring).
lh = get_param([po '/DO_12'], 'LineHandles');
for p = 6:9
    if lh.Inport(p) > 0, delete_line(lh.Inport(p)); end
end

% Variant Source input port 1 <- the Enabled Subsystem's REBUILT
% A_do/B_do/l_gain/G_do (VariantControls{1} = 'im_est_online_on==1').
% Input port 2 <- Ad/Bd/lg/Gd, unchanged (VariantControls{2} =
% 'im_est_online_on==0'). Output port 1 -> DO_12's in:6/7/8/9
% (replacing the direct Ad/Bd/lg/Gd feed removed above). Columns:
% variant-source leaf name, IM_Est_Online output port, original
% Constant leaf name, DO_12 input port.
rows = {'IM_Est_A_Sw', 1, 'Ad', 6; ...
        'IM_Est_B_Sw', 2, 'Bd', 7; ...
        'IM_Est_L_Sw', 3, 'lg', 8; ...
        'IM_Est_G_Sw', 4, 'Gd', 9};
for i = 1:size(rows,1)
    vsleaf = rows{i,1}; esPort = rows{i,2}; origBlk = rows{i,3}; do12Port = rows{i,4};
    add_line(po, sprintf('IM_Est_Online/%d', esPort), [vsleaf '/1'], 'autorouting','on');
    add_line(po, [origBlk '/1'], [vsleaf '/2'], 'autorouting','on');
    add_line(po, [vsleaf '/1'], sprintf('DO_12/%d', do12Port), 'autorouting','on');
end

%% ---------------- diagnostic logging: fallback/reason (sec 4.46 item 1b) ----------------
% Ports 5/6 of IM_Est_Online - NOT variant-routed, NOT fed to DO_12,
% pure diagnostics for the fallback-rate check (checkpoint 4, sec
% 4.45: <5% of ticks with t>=140s). Wired unconditionally (same as
% every other diagnostic tap this session) - meaningful only when
% im_est_online_on=1 is the scenario actually being run; harmless
% otherwise. This does mean IM_Est_Online's own internal construction
% always compiles regardless of im_est_online_on (it has an
% unconditional consumer here, so Variant Source pruning cannot
% exclude it) - not a problem, because IM_Est_Online's own 25-state
% construction has no EXTERNAL size dependency at all (im_est_do_rebuild's
% N=25 is fixed, self-contained); the only place a size CONFLICT could
% occur is at each Variant Source's own port matching against the
% CURRENT scenario's Ad/Bd/lg/Gd, which is exactly what Variant Source
% (sec 4.49, verified in isolation first) avoids.
add_block('simulink/Sinks/To Workspace', [po '/IM_Fallback_Log'], ...
    'VariableName','im_est_fallback_log', 'SaveFormat','Structure With Time', ...
    'MaxDataPoints','inf', 'Decimation','1', 'Position',[900 320 1000 350]);
add_block('simulink/Sinks/To Workspace', [po '/IM_Reason_Log'], ...
    'VariableName','im_est_reason_log', 'SaveFormat','Structure With Time', ...
    'MaxDataPoints','inf', 'Decimation','1', 'Position',[900 370 1000 400]);
add_line(po, 'IM_Est_Online/5', 'IM_Fallback_Log/1', 'autorouting','on');
add_line(po, 'IM_Est_Online/6', 'IM_Reason_Log/1', 'autorouting','on');

%% ---------------- compile check (build_payload_predictor.m's own pattern) ----------------
say('\n  Compile check...\n');
ok = compile_check(mdl, po, {'IM_Est_A_Sw','IM_Est_B_Sw','IM_Est_L_Sw','IM_Est_G_Sw'});
if ~ok
    say('\n  [FAIL] compile check did not pass - NOT saving. See messages above.\n');
    return
end

say('\n  im_est_online_on=0 (reset_extensions default): the Variant Source\n');
say('  blocks resolve, at compile time, to Ad/Bd/lg/Gd directly - the online\n');
say('  branch''s entire content is excluded from that compile, not merely\n');
say('  unused - so checkpoint 1''s own bit-exact result does not depend on\n');
say('  what IM_Est_Online computes at all when off.\n');

if opt.Save
    save_system(mdl);
    say('  saved %s.\n', mdl);
else
    say('  NOT saved (Save=false) - model in memory only.\n');
end
end

%% =====================================================================
function ok = compile_check(mdl, po, swNames)
%COMPILE_CHECK  Variant Source resolves at COMPILE time (sec 4.49) - a
%  SEPARATE compile per state, not one compile toggled at run time.
%  Tests 0 -> 1 -> 0, not just 0 -> 1: the third state (sec 4.49 item
%  4) checks that the online branch does not stay "stuck" active after
%  a prior compile - each state re-runs init_MOBADC_params/
%  reset_extensions FRESH first, so the 3rd (0) compile starts from
%  the SAME clean 6-state Ad/etc. as the 1st, not from whatever the
%  2nd (1) state's placeholder 25-slot layout left behind.
ok = false;
states = [0 1 0];
for si = 1:numel(states)
    fl = states(si);
    try
        evalin('base', 'init_MOBADC_params');
        % im_est_online_on (and everything else reset_extensions owns) is
        % CREATED by reset_extensions, not by init_MOBADC_params itself - a
        % fresh session that never called reset_extensions would otherwise
        % fail this compile purely on an undefined variable, unrelated to
        % whether the actual wiring is correct.
        reset_extensions('Quiet', true);
    catch err
        fprintf('  [FAIL] init_MOBADC_params/reset_extensions error (im_est_online_on=%d): %s\n', ...
            fl, err.message);
        return
    end
    assignin('base', 'im_est_online_on', fl);
    if fl == 1
        if ~set_placeholder_layout()
            return
        end
    end
    fprintf('  Compile check (im_est_online_on=%d)...\n', fl);
    cleanupObj = onCleanup(@() safe_term(mdl)); %#ok<NASGU>
    try
        feval(mdl, [], [], [], 'compile');
    catch err
        % Simulink often aggregates several compile errors into one
        % MException whose own .message is a useless "Error due to
        % multiple causes." - the actual diagnostics live in err.cause
        % (itself a cell array of MExceptions, potentially nested). Print
        % every one, recursively, or this catch block hides exactly the
        % information needed to fix anything.
        fprintf('  [FAIL] compile error (im_est_online_on=%d):\n    %s\n', fl, err.message);
        print_causes(err, 4);
        fprintf('  ---- full report (belt and suspenders) ----\n');
        try, fprintf('%s\n', getReport(err, 'extended')); catch, end
        fprintf('  --------------------------------------------\n');
        return
    end
    for wi = 1:numel(swNames)
        w = get_param([po '/' swNames{wi}], 'CompiledPortWidths');
        fprintf('  [OK]   %-16s output width = %d\n', swNames{wi}, w.Outport(1));
    end
    feval(mdl, [], [], [], 'term');
    fprintf('  [OK]   compile clean, no algebraic loop (im_est_online_on=%d).\n', fl);
end
ok = true;
end

%% =====================================================================
function ok = set_placeholder_layout()
%SET_PLACEHOLDER_LAYOUT  Base-workspace 25-slot layout for
%  im_est_online_on=1 (sec 4.49) - the SAME construction as
%  core/pa_configs.m's own 'ImEstOnline' block (both derived from the
%  identical formula; duplicated here in a ~15-line form rather than
%  shared, because compile_check has always deliberately stayed
%  independent of pa_configs, calling init_MOBADC_params/
%  reset_extensions directly - build_payload_predictor.m's own
%  precedent). Reuses im_est_do_rebuild.m ITSELF, interpreted, with
%  every harmonic slot untrusted (PLACEHOLDER=0.3, matching
%  im_est_estimator.m's own constant), so this is bit-consistent with
%  the online path's own actual first tick, not a second hand-written
%  copy of the same construction.
ok = false;
try
    L_now      = evalin('base', 'L');
    wn_p_now   = sqrt(9.81 / L_now);
    w_traj_now = evalin('base', 'w_traj');
    l_axis_now = evalin('base', 'l_axis');
    PLACEHOLDER = 0.3;
    trust4 = [false false false false];
    w4     = [PLACEHOLDER PLACEHOLDER PLACEHOLDER PLACEHOLDER];
    [A0, B0, L0, G0, fb0] = im_est_do_rebuild(w4, trust4, w4, trust4, ...
        wn_p_now, w_traj_now, l_axis_now, false);
    if fb0
        fprintf('  [FAIL] placeholder 25-slot layout: unexpected fallback building it.\n');
        return
    end
    assignin('base', 'A_do', A0);
    assignin('base', 'B_do', B0);
    assignin('base', 'l_gain', L0);
    assignin('base', 'G_do', G0);
    assignin('base', 'n_state_axis', [11; 11; 3]);
    assignin('base', 'do_w', [0; w4(:); wn_p_now; 0; w4(:); wn_p_now; 0; w_traj_now]);
catch err
    fprintf('  [FAIL] placeholder 25-slot layout error: %s\n', err.message);
    return
end
ok = true;
end

function print_causes(err, indent)
%PRINT_CAUSES  Recursively print every nested cause of an MException -
%  Simulink's own "Error due to multiple causes" wrapper is otherwise
%  a dead end with no diagnostic content at all.
try
    causes = err.cause;
catch
    causes = {};
end
if isempty(causes)
    try
        if ~isempty(err.stack)
            fprintf('%s(in %s, line %d)\n', repmat(' ',1,indent), ...
                err.stack(1).name, err.stack(1).line);
        end
    catch
    end
    return
end
for i = 1:numel(causes)
    c = causes{i};
    fprintf('%s[%d] %s\n', repmat(' ',1,indent), i, c.message);
    print_causes(c, indent+4);
end
end

function safe_term(mdl)
try
    if ~strcmp(get_param(mdl,'SimulationStatus'), 'stopped')
        feval(mdl, [], [], [], 'term');
    end
catch
end
end

%% =====================================================================
function n = teardown(po)
%TEARDOWN  Undo everything this script ever added. Safe when nothing is
%  there yet. Lines before blocks; DO_12's own re-routed inputs are
%  reconnected to Ad/Bd/lg/Gd directly, restoring the pre-this-script
%  wiring exactly.
n = 0;
sw = {'IM_Est_A_Sw','IM_Est_B_Sw','IM_Est_L_Sw','IM_Est_G_Sw'};
orig = {'Ad','Bd','lg','Gd'};
ports = [6 7 8 9];
if getSimulinkBlockHandle([po '/DO_12']) > 0 && getSimulinkBlockHandle([po '/' sw{1}]) > 0
    lh = get_param([po '/DO_12'], 'LineHandles');
    for i = 1:4
        if lh.Inport(ports(i)) > 0, delete_line(lh.Inport(ports(i))); end
        add_line(po, [orig{i} '/1'], ['DO_12/' num2str(ports(i))], 'autorouting','on');
    end
end
for b = [sw, {'IM_Est_On','IM_Est_Online','IM_Fallback_Log','IM_Reason_Log'}]
    blk = [po '/' b{1}];
    if getSimulinkBlockHandle(blk) > 0
        try
            ph = get_param(blk, 'PortHandles');
            for k = 1:numel(ph.Inport)
                lhh = get_param(ph.Inport(k), 'Line');
                if lhh > 0, delete_line(lhh); end
            end
        catch
        end
        delete_block(blk);
        n = n + 1;
    end
end
end

%% =====================================================================
function set_eml_script(blkpath, code)
%SET_EML_SCRIPT  build_payload_pendulum.m/build_payload_predictor.m's
%  own local helper of the same name - port count is inferred from the
%  function signature, so the code must be loaded BEFORE add_line.
ch = find(sfroot, '-isa','Stateflow.EMChart', 'Path', blkpath);
assert(~isempty(ch), 'set_eml_script: no Stateflow.EMChart found for %s', blkpath);
ch(1).Script = code;
end

%% =====================================================================
function assert_ports(blk, n_in, n_out)
p = get_param(blk, 'Ports');
assert(p(1) == n_in && p(2) == n_out, ...
   ['%s has %d in / %d out, expected %d / %d.\n' ...
    'The source .m file''s own signature changed - update this check.'], ...
    blk, p(1), p(2), n_in, n_out);
end
