function build_p2_plant(varargin)
%BUILD_P2_PLANT  Wire plant P2 into baseline1.slx behind Variant controls (GD2b).
%
%   build_p2_plant                              % build in memory, compile check 0 -> 1 -> 0, NOT saved
%   build_p2_plant('Save', true)                % build + check + save baseline1.slx
%   build_p2_plant('Revert', true)              % remove everything this script adds
%   build_p2_plant('Revert', true, 'Save', true)
%   build_p2_plant('Segment', 'wind_real_t150_i0000.mat')   % segment used by the compile check
%   build_p2_plant('Check', false)              % skip the compile check (not recommended)
%   build_p2_plant('FingerprintOf', 'C:\x\baseline1.slx')   % READ ONLY: load that file, print its fingerprint,
%                                               % close it unsaved - nothing built (verification/model_fingerprint.m)
%
%  The fingerprint of a model JUST BUILT and of the same model LOADED from its file differ (2026-09-30 build:
%  c965867910b8... built, fae8c428ca30... loaded; REGISTER_P2 sec 66). Compare like with like.
%
%  The H4 competitor (REGISTER_P2 sec 40.2) was dropped in sec 50 and never built into the saved model; its
%  'H4' option and block source were removed on 2026-10-04 (tag paper-results-p2 holds them). What the saved
%  model has is kept exactly: the third input of P2_CMP_Sel (From dmf_h4) fed by the Constant H4_off (zeros).
%
%  Design: docs/devlog/GD2B_DESIGN.md (approved 2026-09-25). Block paths, tags and
%  initial conditions below were read from the XML of the committed baseline1.slx.
%
%  WHAT CHANGES IN THE v1 PART (each is value-neutral - proven by B1):
%   1. thrust_attitude_ref: F_TOT_MAX becomes input 5, fed by Constant F_TOT_MAX
%      (init_MOBADC_params: 21.6, the old literal).
%   2. Int_z / Int_zp initial conditions: p2_ic_do / p2_ic_eso, which evaluate the old
%      expressions verbatim and add the P2 hover trim only when plant_model = 1.
%   3. Goto tags of the v1 plant outputs renamed *_v1; the controller's From blocks
%      renamed *_c; UAV_Plant/F_tau_act reads tau_plant. The ORIGINAL tags are now
%      driven by Variant Sources in the new root subsystem P2 (port 1 = v1 signal).
%   4. Poison Variant Sources {'p2_poison==0','p2_poison==1'} in front of every v1
%      plant output Goto and after WSEL (B6); port 2 = NaN.
%   5. Position_Observers: Variant Source P2_WD_Sel between WSEL (K_w*w) and WD_Switch.
%   6. Position_Observers (N6, REGISTER_P2 sec 15.4): Variant Source P2_N6_Sel between
%      PP_Switch and Manual Switch (p2_n6 = 0 -> port 1 = the unchanged path; p2_n6 = 1 ->
%      PP_Switch + dmf_n6); Gotos dmf_do (tap on DO_Out/1) and p2_wgate (tap on WD_gate/1).
%   7. Position_Observers (competitor H3, REGISTER_P2 sec 40): Variant Source P2_CMP_Sel between
%      P2_N6_Sel and Manual Switch (p2_cmp = 0 -> port 1 = the unchanged path; 1 -> dmf_h3; port 3 =
%      dmf_h4 = zeros, the slot of the dropped H4) and P2_CMPW_Sel between WD_Switch and Manual Switch1
%      (p2_cmp = 1 -> zeros: H3 replaces both channels).
%   8. Position_Observers (GD8 (iii), REGISTER_P2 sec 45): Variant Source P2_M3_Sel between P2_CMP_Sel and
%      Manual Switch (p2_m3 = 1 -> + dmf_m3p, the model force tau_m ahead) and P2_M3_DoSel between
%      F_dlf_hat and DO_12/5 (p2_m3 = 1 -> + dmf_m3n, the model's present force as known DO input).
%   9. Position_Observers (REGISTER_P2 sec 47): Variant Source P2_TRIM_Sel between Manual Switch and
%      G_dmf_hat (p2_trim_ff = 1 -> + p2_trim_ff_v, the known payload weight, after the Remark 9 switch).
%  Everything P2 computes lives in the Variant Subsystem P2/P2_Core (one choice,
%  plant_model==1, zero active choices allowed) and is not compiled when plant_model = 0.
%
%  Prints a fingerprint (SHA-256 over every block path + key parameters touched here).

opt = struct('Save', false, 'Revert', false, 'Check', true, 'Quiet', false, ...
             'Segment', 'wind_real_t150_i0000.mat', 'FingerprintOf', '');
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
say = @(varargin) fprintf(varargin{:});
if opt.Quiet, say = @(varargin) []; end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~isempty(opt.FingerprintOf)                % read only: the given file as saved, nothing built or saved
    f = char(opt.FingerprintOf);
    assert(isfile(f), 'build_p2_plant: %s not found.', f);   % (exist() gives 4, not 2, for a model on the path)
    [~, nm] = fileparts(f);
    assert(strcmp(nm, mdl), 'build_p2_plant: FingerprintOf needs a file named %s.slx.', mdl);
    if bdIsLoaded(mdl)
        assert(~bdIsDirty(mdl), 'build_p2_plant: %s has unsaved changes in memory - close it first.', mdl);
        close_system(mdl, 0);
    end
    ws = warning('off', 'all');  load_system(f);  warning(ws);   % (a second baseline1.slx shadows the repo's)
    fp = fingerprint(mdl, spec());
    fprintf('  FINGERPRINT of %s (loaded, nothing built): %s\n', f, fp);
    close_system(mdl, 0);
    return
end
if ~bdIsLoaded(mdl), load_system(mdl); end
say('build_p2_plant | MATLAB %s | git %s\n', version, git_hash());

C = spec();                                   % every name/path in one place

% ---------------- idempotent teardown (also the whole of Revert) ----------------
n = teardown(mdl, C, say);
if n > 0, say('  teardown: undid %d change(s) from a previous build\n', n); end
if opt.Revert
    say('  reverted to the pre-P2 model.\n');
    if opt.Save, save_system(mdl); say('  saved %s.\n', mdl); end
    return
end

preflight(mdl, C);

% ---------------- 1. F_TOT_MAX as an input of thrust_attitude_ref ----------------
tar = [mdl '/' C.tar];
set_eml_script(tar, fileread(fullfile(here, 'simulink_blocks', 'thrust_attitude_ref.m')));
assert_ports(tar, 5, 2);
ar = [mdl '/Attitude_Reference'];
add_block('simulink/Sources/Constant', [ar '/P2_FTOT'], 'Value', 'F_TOT_MAX', ...
    'Position', [60 260 140 290]);
add_line(ar, 'P2_FTOT/1', 'Thrust_AttRef_16/5', 'autorouting', 'on');
say('  [1] thrust_attitude_ref: F_TOT_MAX is input 5 (Constant F_TOT_MAX)\n');

% ---------------- 2. observer initial conditions ----------------
set_param([mdl '/' C.int_z],  'InitialCondition', C.ic_z_new);
set_param([mdl '/' C.int_zp], 'InitialCondition', C.ic_zp_new);
say('  [2] Int_z IC = %s\n      Int_zp IC = %s\n', C.ic_z_new, C.ic_zp_new);

% ---------------- 3+4. v1 plant Gotos: poison VS, then tag *_v1 ----------------
for k = 1:size(C.v1goto, 1)
    [blk, tag, srcBlk, srcPort] = C.v1goto{k, :};
    sys = fileparts([mdl '/' blk]);
    gname = blk(numel(fileparts(blk)) + 2:end);
    pz = sprintf('P2_PZ_%s', tag);  pc = sprintf('P2_PZc_%s', tag);
    delete_line(sys, sprintf('%s/%d', srcBlk, srcPort), [gname '/1']);
    p = get_param([sys '/' gname], 'Position');
    add_block('simulink/Signal Routing/Variant Source', [sys '/' pz], C.vs_poison{:}, ...
        'Position', [p(1) - 70, p(2) - 5, p(1) - 40, p(4) + 25]);
    add_block('simulink/Sources/Constant', [sys '/' pc], 'Value', 'nan(3,1)', ...
        'Position', [p(1) - 160, p(4) + 10, p(1) - 100, p(4) + 30]);
    add_line(sys, sprintf('%s/%d', srcBlk, srcPort), [pz '/1'], 'autorouting', 'on');
    add_line(sys, [pc '/1'], [pz '/2'], 'autorouting', 'on');
    add_line(sys, [pz '/1'], [gname '/1'], 'autorouting', 'on');
    set_param([sys '/' gname], 'GotoTag', [tag '_v1']);
end
say('  [3] v1 plant Gotos -> *_v1 with poison VS: %s\n', strjoin(C.v1goto(:, 2).', ', '));

% ---------------- 3. controller From blocks -> *_c (and Rot_5 -> tau_plant) ----------------
for k = 1:size(C.ctrlfrom, 1)
    blk = [mdl '/' C.ctrlfrom{k, 1}];
    set_param(blk, 'GotoTag', C.ctrlfrom{k, 3});
end
say('  [3] %d From blocks retagged (controller -> *_c, UAV_Plant/F_tau_act -> tau_plant)\n', ...
    size(C.ctrlfrom, 1));

% ---------------- 5. wind path: WSEL -> poison -> P2_WD_Sel -> WD_Switch/1 ----------------
po = [mdl '/Position_Observers'];
delete_line(po, 'WSEL/1', 'WD_Switch/1');
add_block('simulink/Signal Routing/Variant Source', [po '/P2_PZ_wsel'], C.vs_poison{:}, ...
    'Position', [960 560 990 610]);
add_block('simulink/Sources/Constant', [po '/P2_PZc_wsel'], 'Value', 'nan(3,1)', ...
    'Position', [880 820 940 840]);
add_block('simulink/Signal Routing/Variant Source', [po '/P2_WD_Sel'], C.vs_plant{:}, ...
    'Position', [1020 560 1050 610]);
add_block('simulink/Signal Routing/From', [po '/P2_F_dlf'], 'GotoTag', 'dlf_p2', ...
    'TagVisibility', 'global', 'Position', [880 860 960 880]);
add_line(po, 'WSEL/1', 'P2_PZ_wsel/1', 'autorouting', 'on');
add_line(po, 'P2_PZc_wsel/1', 'P2_PZ_wsel/2', 'autorouting', 'on');
add_line(po, 'P2_PZ_wsel/1', 'P2_WD_Sel/1', 'autorouting', 'on');
add_line(po, 'P2_F_dlf/1', 'P2_WD_Sel/2', 'autorouting', 'on');
add_line(po, 'P2_WD_Sel/1', 'WD_Switch/1', 'autorouting', 'on');
say('  [5] Position_Observers: WSEL -> P2_PZ_wsel -> P2_WD_Sel -> WD_Switch/1\n');

% ---------------- 6. N6: PP_Switch -> P2_N6_Sel -> Manual Switch/1 (REGISTER_P2 sec 15.4) ----------------
delete_line(po, 'PP_Switch/1', 'Manual Switch/1');
add_block('simulink/Signal Routing/Variant Source', [po '/P2_N6_Sel'], C.vs_n6{:}, ...
    'Position', [1245 205 1265 255]);
add_block('simulink/Math Operations/Sum', [po '/P2_N6_Sum'], 'Inputs', '++', ...
    'Position', [1200 400 1220 440]);
add_block('simulink/Signal Routing/From', [po '/P2_F_n6'], 'GotoTag', 'dmf_n6', ...
    'TagVisibility', 'global', 'Position', [1090 430 1170 448]);
add_block('simulink/Signal Routing/Goto', [po '/P2_G_dmf_do'], 'GotoTag', 'dmf_do', ...
    'TagVisibility', 'global', 'Position', [1090 470 1170 488]);
add_block('simulink/Signal Routing/Goto', [po '/P2_G_wgate'], 'GotoTag', 'p2_wgate', ...
    'TagVisibility', 'global', 'Position', [1250 940 1330 958]);
add_line(po, 'PP_Switch/1', 'P2_N6_Sel/1', 'autorouting', 'on');
add_line(po, 'PP_Switch/1', 'P2_N6_Sum/1', 'autorouting', 'on');
add_line(po, 'P2_F_n6/1', 'P2_N6_Sum/2', 'autorouting', 'on');
add_line(po, 'P2_N6_Sum/1', 'P2_N6_Sel/2', 'autorouting', 'on');
add_line(po, 'P2_N6_Sel/1', 'Manual Switch/1', 'autorouting', 'on');
add_line(po, 'DO_Out/1', 'P2_G_dmf_do/1', 'autorouting', 'on');
add_line(po, 'WD_gate/1', 'P2_G_wgate/1', 'autorouting', 'on');
say('  [6] Position_Observers: PP_Switch -> P2_N6_Sel (p2_n6) -> Manual Switch/1; Gotos dmf_do, p2_wgate\n');

% ---------------- 7. H3/H4: P2_N6_Sel -> P2_CMP_Sel -> Manual Switch/1; WD_Switch -> P2_CMPW_Sel -> Manual Switch1/1 ----------------
delete_line(po, 'P2_N6_Sel/1', 'Manual Switch/1');
delete_line(po, 'WD_Switch/1', 'Manual Switch1/1');
add_block('simulink/Signal Routing/Variant Source', [po '/P2_CMP_Sel'], C.vs_cmp{:}, ...
    'Position', [1330 200 1350 270]);
add_block('simulink/Signal Routing/From', [po '/P2_F_h3'], 'GotoTag', 'dmf_h3', ...
    'TagVisibility', 'global', 'Position', [1200 470 1280 488]);
add_block('simulink/Signal Routing/From', [po '/P2_F_h4'], 'GotoTag', 'dmf_h4', ...
    'TagVisibility', 'global', 'Position', [1200 500 1280 518]);
add_block('simulink/Signal Routing/Variant Source', [po '/P2_CMPW_Sel'], C.vs_cmpw{:}, ...
    'Position', [1370 600 1390 650]);
add_block('simulink/Sources/Constant', [po '/P2_Zw'], 'Value', 'zeros(3,1)', 'Position', [1290 660 1340 680]);
add_line(po, 'P2_N6_Sel/1', 'P2_CMP_Sel/1', 'autorouting', 'on');
add_line(po, 'P2_F_h3/1', 'P2_CMP_Sel/2', 'autorouting', 'on');
add_line(po, 'P2_F_h4/1', 'P2_CMP_Sel/3', 'autorouting', 'on');
add_line(po, 'P2_CMP_Sel/1', 'Manual Switch/1', 'autorouting', 'on');
add_line(po, 'WD_Switch/1', 'P2_CMPW_Sel/1', 'autorouting', 'on');
add_line(po, 'P2_Zw/1', 'P2_CMPW_Sel/2', 'autorouting', 'on');
add_line(po, 'P2_CMPW_Sel/1', 'Manual Switch1/1', 'autorouting', 'on');
say('  [7] Position_Observers: P2_N6_Sel -> P2_CMP_Sel (p2_cmp: 0 / H3 / zeros) -> Manual Switch/1; WD_Switch -> P2_CMPW_Sel -> Manual Switch1/1\n');

% ---------------- 8. (iii): P2_CMP_Sel -> P2_M3_Sel -> Manual Switch/1; F_dlf_hat -> P2_M3_DoSel -> DO_12/5 ----------------
delete_line(po, 'P2_CMP_Sel/1', 'Manual Switch/1');
add_block('simulink/Signal Routing/Variant Source', [po '/P2_M3_Sel'], C.vs_m3{:}, 'Position', [1365 200 1385 250]);
add_block('simulink/Math Operations/Sum', [po '/P2_M3_Sum'], 'Inputs', '++', 'Position', [1300 540 1320 580]);
add_block('simulink/Signal Routing/From', [po '/P2_F_m3p'], 'GotoTag', 'dmf_m3p', ...
    'TagVisibility', 'global', 'Position', [1200 560 1280 578]);
add_line(po, 'P2_CMP_Sel/1', 'P2_M3_Sel/1', 'autorouting', 'on');
add_line(po, 'P2_CMP_Sel/1', 'P2_M3_Sum/1', 'autorouting', 'on');
add_line(po, 'P2_F_m3p/1', 'P2_M3_Sum/2', 'autorouting', 'on');
add_line(po, 'P2_M3_Sum/1', 'P2_M3_Sel/2', 'autorouting', 'on');
add_line(po, 'P2_M3_Sel/1', 'Manual Switch/1', 'autorouting', 'on');
delete_line(po, 'F_dlf_hat/1', 'DO_12/5');
add_block('simulink/Signal Routing/Variant Source', [po '/P2_M3_DoSel'], C.vs_m3{:}, 'Position', [150 600 170 650]);
add_block('simulink/Math Operations/Sum', [po '/P2_M3_DoSum'], 'Inputs', '++', 'Position', [110 660 130 700]);
add_block('simulink/Signal Routing/From', [po '/P2_F_m3n'], 'GotoTag', 'dmf_m3n', ...
    'TagVisibility', 'global', 'Position', [20 700 100 718]);
add_line(po, 'F_dlf_hat/1', 'P2_M3_DoSel/1', 'autorouting', 'on');
add_line(po, 'F_dlf_hat/1', 'P2_M3_DoSum/1', 'autorouting', 'on');
add_line(po, 'P2_F_m3n/1', 'P2_M3_DoSum/2', 'autorouting', 'on');
add_line(po, 'P2_M3_DoSum/1', 'P2_M3_DoSel/2', 'autorouting', 'on');
add_line(po, 'P2_M3_DoSel/1', 'DO_12/5', 'autorouting', 'on');
say('  [8] Position_Observers: P2_CMP_Sel -> P2_M3_Sel (p2_m3, + dmf_m3p) -> Manual Switch/1; F_dlf_hat -> P2_M3_DoSel (+ dmf_m3n) -> DO_12/5\n');

% ---------------- 9. sec 47: Manual Switch -> P2_TRIM_Sel -> G_dmf_hat ----------------
delete_line(po, 'Manual Switch/1', 'G_dmf_hat/1');
add_block('simulink/Signal Routing/Variant Source', [po '/P2_TRIM_Sel'], C.vs_trim{:}, 'Position', [1460 200 1480 250]);
add_block('simulink/Math Operations/Sum', [po '/P2_TRIM_Sum'], 'Inputs', '++', 'Position', [1440 300 1460 340]);
add_block('simulink/Sources/Constant', [po '/P2_TRIM_c'], 'Value', 'p2_trim_ff_v', 'Position', [1360 330 1420 350]);
add_line(po, 'Manual Switch/1', 'P2_TRIM_Sel/1', 'autorouting', 'on');
add_line(po, 'Manual Switch/1', 'P2_TRIM_Sum/1', 'autorouting', 'on');
add_line(po, 'P2_TRIM_c/1', 'P2_TRIM_Sum/2', 'autorouting', 'on');
add_line(po, 'P2_TRIM_Sum/1', 'P2_TRIM_Sel/2', 'autorouting', 'on');
add_line(po, 'P2_TRIM_Sel/1', 'G_dmf_hat/1', 'autorouting', 'on');
say('  [9] Position_Observers: Manual Switch -> P2_TRIM_Sel (p2_trim_ff, + p2_trim_ff_v) -> G_dmf_hat\n');

% ---------------- the root subsystem P2 ----------------
build_p2_root(mdl, C, here);
say('  [P2] root subsystem P2 + Variant Subsystem P2/P2_Core built\n');

% ---------------- readable layout (layout only; connectivity checked inside) ----------------
tidy_layout();

% ---------------- compile check 0 -> 1 -> 0 ----------------
if opt.Check
    ok = compile_check(mdl, opt.Segment, say);
    if ~ok
        error('build_p2_plant:compile', ['Compile check FAILED - model left in memory, NOT saved.\n' ...
            'Fix, or undo with build_p2_plant(''Revert'', true).']);
    end
end

fp = fingerprint(mdl, C);
say('  FINGERPRINT (SHA-256 of P2 wiring): %s\n', fp);
if opt.Save
    save_system(mdl);
    say('  saved %s. Next: B1 (verify_repro, check_results_numbers, check_all, extract_eml --check),\n', mdl);
    say('  update docs/SNAPSHOT.md MD5, push baseline1.slx, report this fingerprint + hash.\n');
else
    say('  NOT saved (Save=false) - model in memory only.\n');
end
end

%% =====================================================================
function C = spec()
%SPEC  Every block path, tag and expression this script touches.
C.tar     = 'Attitude_Reference/Thrust_AttRef_16';
C.int_z   = 'Position_Observers/Int_z';
C.int_zp  = 'Position_Observers/Int_zp';
C.ic_z_old  = '-l_gain*[R_traj;0;z0_hover;0;R_traj*w_traj;0]';
C.ic_zp_old = '[R_traj;0;z0_hover; 0;R_traj*w_traj;0; 0;0;0]';
C.ic_z_new  = 'p2_ic_do(l_gain, R_traj, z0_hover, w_traj, plant_model, p2_trim_do, p2_ic_pos, p2_ic_vel)';
C.ic_zp_new = 'p2_ic_eso(R_traj, z0_hover, w_traj, plant_model, p2_trim_eso, p2_ic_pos, p2_ic_vel)';
% P2 initial conditions, explicit sizes (same values as core/p2_setup.m p2_x0, p2_f0,
% p2_gamma0, p2_gamma_prev0 - check_p2_offline O3-x0; check_p2_b5_b7 B3-pos)
% REGISTER_P2 sec 8: the standard initial state p2_ic_pos/p2_ic_vel (3x1 each, p2_setup),
% written element by element so the IC keeps an explicit 12 / 3 size (second build attempt)
C.ic_x_p2    = '[p2_ic_pos(1);p2_ic_pos(2);p2_ic_pos(3); p2_ic_vel(1);p2_ic_vel(2);p2_ic_vel(3); 0;0;-1; 0;0;0]';
C.ic_f_p2    = '(m + m_p)*g/4*ones(4,1)';
C.ic_pos_p2  = '[p2_ic_pos(1);p2_ic_pos(2);p2_ic_pos(3)]';
C.ic_prev_p2 = '[p2_ic_pos(1);p2_ic_pos(2);p2_ic_pos(3)] - [p2_ic_vel(1);p2_ic_vel(2);p2_ic_vel(3)]*p2_Ts_pos';
% v1 plant output Gotos: {Goto path, original tag, source block, source port}
C.v1goto = { ...
    'UAV_Plant/G_gamma',        'gamma',  'Int_gamma', 1; ...
    'UAV_Plant/G_nu',           'nu',     'Int_nu',    1; ...
    'UAV_Plant/PL_G_nu_dot',    'nu_dot', 'Trans_4a',  1; ...
    'Disturbances/G_d_mf',      'd_mf',   'PI_Sum',    1; ...
    'Disturbances/G_d_lf',      'd_lf',   'WS_Switch', 1};
% From blocks retagged: {path, original tag, new tag}
C.ctrlfrom = { ...
    'Position_Observers/F_gamma',                  'gamma',   'gamma_c'; ...
    'Translational_Control/F_gamma',               'gamma',   'gamma_c'; ...
    'Translational_Control/F_gamma1',              'gamma',   'gamma_c'; ...
    'Position_Observers/F_nu',                     'nu',      'nu_c'; ...
    'Translational_Control/F_nu',                  'nu',      'nu_c'; ...
    'Translational_Control/F_nu1',                 'nu',      'nu_c'; ...
    'Position_Observers/IM_Est_Online/IM_F_nu_dot', 'nu_dot', 'nu_dot_c'; ...
    'Rotational_Control/F_omega',                  'omega',   'omega_c'; ...
    'Attitude_Observer/F_eta',                     'eta',     'eta_c'; ...
    'Attitude_Reference/F_eta',                    'eta',     'eta_c'; ...
    'Rotational_Control/F_eta',                    'eta',     'eta_c'; ...
    'Attitude_Reference/F_Fcmd',                   'Fcmd',    'Fcmd_c'; ...
    'Motor_Allocation/F_fthr',                     'fthr',    'fthr_c'; ...
    'Motor_Allocation/F_tau_cmd',                  'tau_cmd', 'tau_cmd_c'; ...
    'UAV_Plant/F_tau_act',                         'tau_act', 'tau_plant'};
% Signals selected in P2: {output tag, v1 source tag ('' = zeros), P2_Core outport name, width}
C.sel = { ...
    'gamma',     'gamma_v1',  'o_gamma',     3; ...
    'nu',        'nu_v1',     'o_nu',        3; ...
    'nu_dot',    'nu_dot_v1', 'o_nu_dot',    3; ...
    'd_mf',      'd_mf_v1',   'o_d_mf',      3; ...
    'd_lf',      'd_lf_v1',   'o_d_lf',      3; ...
    'tau_plant', 'tau_act',   'o_tau_plant', 3; ...
    'gamma_c',   'gamma',     'o_gamma_c',   3; ...
    'nu_c',      'nu',        'o_nu_c',      3; ...
    'nu_dot_c',  'nu_dot',    'o_nu_dot_c',  3; ...
    'omega_c',   'omega',     'o_omega_c',   3; ...
    'eta_c',     'eta',       'o_eta_c',     3; ...
    'Fcmd_c',    'Fcmd',      'o_Fcmd_c',    3; ...
    'fthr_c',    'fthr',      'o_fthr_c',    1; ...
    'tau_cmd_c', 'tau_cmd',   'o_tau_cmd_c', 3; ...
    'dlf_p2',    '',          'o_dlf_p2',    3; ...
    'dmf_n6',    '',          'o_dmf_n6',    3; ...        % N6 term (REGISTER_P2 sec 15.4)
    'dmf_h3',    '',          'o_dmf_h3',    3; ...        % competitor H3 (REGISTER_P2 sec 40.1)
    'dmf_h4',    '',          'o_dmf_h4',    3; ...        % competitor H4 (REGISTER_P2 sec 40.2)
    'dmf_m3n',   '',          'o_dmf_m3n',   3; ...        % (iii) model force now (REGISTER_P2 sec 45)
    'dmf_m3p',   '',          'o_dmf_m3p',   3};           % (iii) model force tau_m ahead
C.vs_plant  = {'VariantControlMode', 'expression', 'VariantActivationTime', 'update diagram', ...
               'VariantControls', {'plant_model==0', 'plant_model==1'}};
C.vs_n6     = {'VariantControlMode', 'expression', 'VariantActivationTime', 'update diagram', ...
               'VariantControls', {'p2_n6==0', 'p2_n6==1'}};
C.vs_cmp    = {'VariantControlMode', 'expression', 'VariantActivationTime', 'update diagram', ...
               'VariantControls', {'p2_cmp==0', 'p2_cmp==1', 'p2_cmp==2'}};
C.vs_cmpw   = {'VariantControlMode', 'expression', 'VariantActivationTime', 'update diagram', ...
               'VariantControls', {'p2_cmp==0 || p2_cmp==2', 'p2_cmp==1'}};
C.vs_m3     = {'VariantControlMode', 'expression', 'VariantActivationTime', 'update diagram', ...
               'VariantControls', {'p2_m3==0', 'p2_m3==1'}};
C.vs_trim   = {'VariantControlMode', 'expression', 'VariantActivationTime', 'update diagram', ...
               'VariantControls', {'p2_trim_ff==0', 'p2_trim_ff==1'}};
C.vs_poison = {'VariantControlMode', 'expression', 'VariantActivationTime', 'update diagram', ...
               'VariantControls', {'p2_poison==0', 'p2_poison==1'}};
end

%% =====================================================================
function preflight(mdl, C)
%PREFLIGHT  The model must be exactly the pre-P2 state this script was written against.
b = @(p) getSimulinkBlockHandle([mdl '/' p]) > 0;
assert(b(C.tar), 'build_p2_plant: %s not found.', C.tar);
p = get_param([mdl '/' C.tar], 'Ports');
assert(p(1) == 4, 'build_p2_plant: %s has %d inputs, expected 4 (pre-P2).', C.tar, p(1));
assert(strcmp(strtrim(get_param([mdl '/' C.int_z], 'InitialCondition')), C.ic_z_old), ...
    'build_p2_plant: Int_z IC is not the expected v1 expression:\n  %s', ...
    get_param([mdl '/' C.int_z], 'InitialCondition'));
assert(strcmp(strtrim(get_param([mdl '/' C.int_zp], 'InitialCondition')), C.ic_zp_old), ...
    'build_p2_plant: Int_zp IC is not the expected v1 expression:\n  %s', ...
    get_param([mdl '/' C.int_zp], 'InitialCondition'));
for k = 1:size(C.v1goto, 1)
    g = [mdl '/' C.v1goto{k, 1}];
    assert(b(C.v1goto{k, 1}), 'build_p2_plant: %s not found.', C.v1goto{k, 1});
    assert(strcmp(get_param(g, 'GotoTag'), C.v1goto{k, 2}), ...
        'build_p2_plant: %s tag is %s, expected %s.', g, get_param(g, 'GotoTag'), C.v1goto{k, 2});
    src = source_of(g, 1);
    assert(strcmp(src, C.v1goto{k, 3}), 'build_p2_plant: %s is fed by %s, expected %s.', ...
        g, src, C.v1goto{k, 3});
end
for k = 1:size(C.ctrlfrom, 1)
    f = [mdl '/' C.ctrlfrom{k, 1}];
    assert(b(C.ctrlfrom{k, 1}), 'build_p2_plant: %s not found.', C.ctrlfrom{k, 1});
    assert(strcmp(get_param(f, 'GotoTag'), C.ctrlfrom{k, 2}), ...
        'build_p2_plant: %s tag is %s, expected %s.', f, get_param(f, 'GotoTag'), C.ctrlfrom{k, 2});
end
% no other From may read a tag this script redirects, except the ones listed (Logging keeps
% the TRUE gamma/eta; the v1 pendulum keeps nu_dot; Trans_4a keeps d_mf/d_lf)
allowed_other = {'Logging_Metrics/F_gamma', 'Logging_Metrics/F_eta', 'Disturbances/PL_F_nu_dot', ...
    'UAV_Plant/F_d_mf', 'UAV_Plant/F_d_lf', 'Logging_Metrics/F_d_mf', 'Logging_Metrics/F_d_lf', ...
    'Attitude_Observer/F_tau_act', 'Logging_Metrics/F_tau_act'};
tags = unique([C.ctrlfrom(:, 2); C.v1goto(:, 2)]);
fr = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'BlockType', 'From');
for i = 1:numel(fr)
    t = get_param(fr{i}, 'GotoTag');
    if ~any(strcmp(t, tags)), continue; end
    rel = fr{i}(numel(mdl) + 2:end);
    listed = any(strcmp(rel, C.ctrlfrom(:, 1))) || any(strcmp(rel, allowed_other));
    assert(listed, ['build_p2_plant: %s reads tag %s but is in neither list - the design ' ...
        'does not say whether it must see the TRUE or the MEASURED signal. Stop.'], rel, t);
end
fmx = [mdl '/Motor_Allocation/fmx'];
assert(strcmp(get_param(fmx, 'Value'), 'f_max'), ...
    'build_p2_plant: Motor_Allocation/fmx reads %s, not f_max - P2 would be clamped silently.', ...
    get_param(fmx, 'Value'));
po = [mdl '/Position_Observers'];
assert(strcmp(source_of([po '/WD_Switch'], 1), 'WSEL'), ...
    'build_p2_plant: WD_Switch/1 is not fed by WSEL.');
assert(strcmp(source_of([po '/Manual Switch'], 1), 'PP_Switch'), ...
    'build_p2_plant: Manual Switch/1 is not fed by PP_Switch (N6 insertion point).');
assert(strcmp(source_of([po '/PP_Switch'], 3), 'DO_Out'), ...
    'build_p2_plant: PP_Switch/3 is not fed by DO_Out (N6 reads the DO estimate there).');
assert(strcmp(source_of([po '/Manual Switch1'], 1), 'WD_Switch'), ...
    'build_p2_plant: Manual Switch1/1 is not fed by WD_Switch (H3 insertion point).');
assert(strcmp(source_of([po '/WD_Switch'], 2), 'WD_gate'), ...
    'build_p2_plant: WD_Switch/2 is not fed by WD_gate (N6 reads the wind gate there).');
assert(strcmp(source_of([po '/DO_12'], 5), 'F_dlf_hat'), ...
    'build_p2_plant: DO_12/5 is not fed by F_dlf_hat ((iii) known-input insertion point).');
assert(strcmp(source_of([po '/G_dmf_hat'], 1), 'Manual Switch'), ...
    'build_p2_plant: G_dmf_hat is not fed by Manual Switch (sec 47 trim insertion point).');
end

%% =====================================================================
function build_p2_root(mdl, C, here)
%BUILD_P2_ROOT  Root subsystem P2: Variant Sources + Gotos outside, P2_Core inside.
P2 = [mdl '/P2'];
add_block('built-in/Subsystem', P2, 'Position', [1500 50 1650 400]);
core = [P2 '/P2_Core'];
ch = make_variant_subsystem(core, [40 40 200 40 + 30 * size(C.sel, 1)], 'P2', 'plant_model==1');
for k = 1:size(C.sel, 1)
    nm = C.sel{k, 3};
    add_block('built-in/Outport', [core '/' nm], 'Port', num2str(k), 'Position', [400, 40 + 30*k, 430, 54 + 30*k]);
    add_block('built-in/Outport', [ch '/' nm], 'Port', num2str(k), 'Position', [1900, 40 + 30*k, 1930, 54 + 30*k]);
end
build_core_choice(ch, C, here);

% selectors: port 1 = v1 signal (From tag, or zeros), port 2 = P2_Core output
for k = 1:size(C.sel, 1)
    [tagOut, tagV1, nm, wdt] = C.sel{k, :};
    y = 40 + 40 * k;
    vs = sprintf('VS_%s', tagOut);
    add_block('simulink/Signal Routing/Variant Source', [P2 '/' vs], C.vs_plant{:}, ...
        'Position', [400, y, 430, y + 30]);
    if isempty(tagV1)
        add_block('simulink/Sources/Constant', [P2 '/Z_' tagOut], 'Value', sprintf('zeros(%d,1)', wdt), ...
            'Position', [300, y, 360, y + 16]);
        add_line(P2, ['Z_' tagOut '/1'], [vs '/1'], 'autorouting', 'on');
    else
        add_block('simulink/Signal Routing/From', [P2 '/F_' tagOut], 'GotoTag', tagV1, ...
            'TagVisibility', 'global', 'Position', [300, y, 360, y + 16]);
        add_line(P2, ['F_' tagOut '/1'], [vs '/1'], 'autorouting', 'on');
    end
    add_line(P2, sprintf('P2_Core/%d', k), [vs '/2'], 'autorouting', 'on');
    add_block('simulink/Signal Routing/Goto', [P2 '/G_' tagOut], 'GotoTag', tagOut, ...
        'TagVisibility', 'global', 'Position', [470, y, 540, y + 16]);
    add_line(P2, [vs '/1'], ['G_' tagOut '/1'], 'autorouting', 'on');
end
end

%% =====================================================================
function ch = make_variant_subsystem(blk, pos, choiceName, choiceCond)
%MAKE_VARIANT_SUBSYSTEM  A Variant Subsystem with ONE empty choice `choiceName`
%(VariantControl `choiceCond`), expression mode, update-diagram activation, zero active
%choices allowed (plant_model = 0 -> nothing compiled).
%
%  R2022b: the Subsystem parameter 'Variant' is read-only (first build attempt,
%  2026-09-25), so the block is taken from the Simulink library instead. The library
%  block comes with default choices and ports whose names differ between releases;
%  they are found by type, not by name: the first choice is emptied and renamed, the
%  others and every container-level port are deleted.
lib = {'simulink/Ports & Subsystems/Variant Subsystem', 'simulink/Signal Routing/Variant Subsystem'};
made = false;  last = '';
for i = 1:numel(lib)
    try
        add_block(lib{i}, blk, 'Position', pos);
        made = true;  break
    catch err
        last = err.message;
    end
end
assert(made, 'build_p2_plant:variant', 'Could not add a Variant Subsystem from the library: %s', last);
try, set_param(blk, 'LinkStatus', 'none'); catch, end
kids = children(blk);
choices = kids(strcmp(get_param(kids, 'BlockType'), 'SubSystem'));
ports   = kids(ismember(get_param(kids, 'BlockType'), {'Inport', 'Outport'}));
for i = 1:numel(ports), delete_block(ports{i}); end
if isempty(choices)
    ch = [blk '/' choiceName];
    add_block('built-in/Subsystem', ch, 'Position', [60 60 260 400]);
else
    for i = 2:numel(choices), delete_block(choices{i}); end
    ch0 = choices{1};
    ln = find_system(ch0, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
    if ~isempty(ln), delete_line(ln); end
    inner = children(ch0);
    for i = 1:numel(inner), delete_block(inner{i}); end
    set_param(ch0, 'Name', choiceName);
    ch = [blk '/' choiceName];
end
set_param(blk, 'VariantControlMode', 'expression');
set_param(blk, 'VariantActivationTime', 'update diagram');
set_param(blk, 'AllowZeroVariantControls', 'on');
% The GD3 stage switches are Variant Sources INSIDE the choice; Simulink then requires
% the container to propagate variant conditions (first GD3 rebuild, R2022b: 'select
% Propagate conditions outside of Variant Subsystem' - the fix it suggests).
set_param(blk, 'PropagateVariantConditions', 'on');
set_param(ch, 'VariantControl', choiceCond);
fprintf('  Variant Subsystem %s: choice %s (%s), %d default choice(s) and %d port(s) removed\n', ...
    blk, choiceName, choiceCond, max(numel(choices) - 1, 0), numel(ports));
end

function k = children(blk)
%CHILDREN  Blocks directly under blk (all variant choices included), blk itself excluded.
try
    k = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'MatchFilter', @Simulink.match.allVariants);
catch
    k = find_system(blk, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'Variants', 'AllVariants');
end
k = k(~strcmp(k, blk));
end

%% =====================================================================
function build_core_choice(ch, C, here)
%BUILD_CORE_CHOICE  Everything P2 computes (GD2B_DESIGN sec 2.3), inside the choice.
A = @(lib, name, varargin) add_block(lib, [ch '/' name], varargin{:});
L = @(src, dst) add_line(ch, src, dst, 'autorouting', 'on');
glob = {'TagVisibility', 'global'};
% GD3 stage switches (REGISTER_P2 sec 1.2): compile-time Variant Sources inside this
% choice only; port 1 = component ON, port 2 = component OFF.
vsw = @(name, var, pos) A('simulink/Signal Routing/Variant Source', name, ...
    'VariantControlMode', 'expression', 'VariantActivationTime', 'update diagram', ...
    'VariantControls', {[var '==1'], [var '==0']}, 'Position', pos);

% ---- inputs from the rest of the model ----
A('simulink/Signal Routing/From', 'F_f_i',     'GotoTag', 'f_i',     glob{:}, 'Position', [20  20  80  36]);
A('simulink/Signal Routing/From', 'F_eta',     'GotoTag', 'eta',     glob{:}, 'Position', [20  80  80  96]);
A('simulink/Signal Routing/From', 'F_omega',   'GotoTag', 'omega',   glob{:}, 'Position', [20 140  80 156]);
A('simulink/Signal Routing/From', 'F_Fcmd',    'GotoTag', 'Fcmd',    glob{:}, 'Position', [20 200  80 216]);
A('simulink/Signal Routing/From', 'F_fthr',    'GotoTag', 'fthr',    glob{:}, 'Position', [20 260  80 276]);
A('simulink/Signal Routing/From', 'F_tau_cmd', 'GotoTag', 'tau_cmd', glob{:}, 'Position', [20 320  80 336]);
mdl = strtok(ch, '/');
add_block([mdl '/Disturbances/WS_From'], [ch '/W_true'], 'Position', [20 400 140 440]);   % wind_ts, same interpolation
A('simulink/Sources/Constant', 'prm',   'Value', 'p2_prm',   'Position', [20 470 100 490]);
A('simulink/Sources/Constant', 'prm_w', 'Value', 'p2_prm_w', 'Position', [20 520 100 540]);

% ---- motors: first-order lag after the controller's clamped commands ----
A('simulink/Discontinuities/Saturation', 'M_sat', 'UpperLimit', 'f_max', 'LowerLimit', '0', 'Position', [140 15 180 45]);
A('simulink/Math Operations/Sum', 'M_err', 'Inputs', '+-', 'Position', [220 15 240 45]);
A('simulink/Math Operations/Gain', 'M_inv_tau', 'Gain', '1/p2_tau_m', 'Position', [270 15 310 45]);
A('simulink/Continuous/Integrator', 'M_f', 'InitialCondition', C.ic_f_p2, 'Position', [340 15 370 45]);
A('simulink/Math Operations/Gain', 'M_mix', 'Gain', 'Gamma_mix', 'Multiplication', 'Matrix(K*u)', 'Position', [410 15 460 45]);
A('simulink/Signal Routing/Selector', 'M_sel_f', 'NumberOfDimensions', '1', 'IndexMode', 'One-based', ...
  'IndexOptions', 'Index vector (dialog)', 'Indices', '1', 'InputPortWidth', '4', 'Position', [500 5 540 25]);
A('simulink/Signal Routing/Selector', 'M_sel_tau', 'NumberOfDimensions', '1', 'IndexMode', 'One-based', ...
  'IndexOptions', 'Index vector (dialog)', 'Indices', '[2 3 4]', 'InputPortWidth', '4', 'Position', [500 35 540 55]);
L('F_f_i/1', 'M_sat/1');  L('M_sat/1', 'M_err/1');  L('M_f/1', 'M_err/2');
L('M_err/1', 'M_inv_tau/1');  L('M_inv_tau/1', 'M_f/1');
vsw('V_lag', 'p2_motor_lag', [385 10 400 50]);                 % lag on / off (S1)
L('M_f/1', 'V_lag/1');  L('M_sat/1', 'V_lag/2');  L('V_lag/1', 'M_mix/1');
L('M_mix/1', 'M_sel_f/1');  L('M_mix/1', 'M_sel_tau/1');

% ---- P2_Trans: plant_p2_free via the MATLAB Function block p2_trans ----
A('simulink/User-Defined Functions/MATLAB Function', 'P2_Trans', 'Position', [620 60 800 260]);
set_eml_script([ch '/P2_Trans'], fileread(fullfile(here, 'simulink_blocks', 'p2_trans.m')));
assert_ports([ch '/P2_Trans'], 5, 7);
set_eml_sizes([ch '/P2_Trans'], {'x', '[12 1]'; 'f_act', '1'; 'eta', '[3 1]'; 'w', '[3 1]'; 'prm', '[8 1]'}, ...
    {'dx', '[12 1]'; 'gam', '[3 1]'; 'nu', '[3 1]'; 'a_Q', '[3 1]'; 'd_mf', '[3 1]'; 'd_lf', '[3 1]'; 'mon', '[5 1]'});
% IC written out as an explicit 12-vector (trim: v1 start position and velocity, q = -e3,
% omega = 0) - not a workspace variable of unfixed size (user decision, second attempt).
A('simulink/Continuous/Integrator', 'P2_x', 'InitialCondition', C.ic_x_p2, 'Position', [860 60 890 90]);
L('P2_x/1', 'P2_Trans/1');  L('M_sel_f/1', 'P2_Trans/2');  L('F_eta/1', 'P2_Trans/3');
L('W_true/1', 'P2_Trans/4');  L('prm/1', 'P2_Trans/5');  L('P2_Trans/1', 'P2_x/1');
% position and velocity taken from the STATE, not from P2_Trans's outputs gam/nu: a
% MATLAB Function block is direct feed-through on every output, so reading x(1:6)
% through it made gamma/nu look algebraic in f_act, and with the motor lag OFF (GD3 S1)
% that closed an artificial algebraic loop through the controller (REGISTER_P2 sec 1.6).
% Same doubles: gam = x(1:3), nu = x(4:6) in p2_trans.m. Its outputs 2-3 are terminated.
A('simulink/Signal Routing/Selector', 'X_gam', 'NumberOfDimensions', '1', 'IndexMode', 'One-based', ...
  'IndexOptions', 'Index vector (dialog)', 'Indices', '[1 2 3]', 'InputPortWidth', '12', 'Position', [920 110 950 130]);
A('simulink/Signal Routing/Selector', 'X_nu', 'NumberOfDimensions', '1', 'IndexMode', 'One-based', ...
  'IndexOptions', 'Index vector (dialog)', 'Indices', '[4 5 6]', 'InputPortWidth', '12', 'Position', [920 150 950 170]);
L('P2_x/1', 'X_gam/1');  L('P2_x/1', 'X_nu/1');
A('simulink/Sinks/Terminator', 'T_gam', 'Position', [830 110 845 125]);   L('P2_Trans/2', 'T_gam/1');
A('simulink/Sinks/Terminator', 'T_nu',  'Position', [830 135 845 150]);   L('P2_Trans/3', 'T_nu/1');

% ---- sensors and sample-and-hold (GD2B_DESIGN sec 2.2) ----
zoh = @(name, ts, pos) A('simulink/Discrete/Zero-Order Hold', name, 'SampleTime', ts, 'Position', pos);
rnd = @(name, var, seed, ts, pos) A('simulink/Sources/Random Number', name, 'Mean', '0', ...
    'Variance', var, 'Seed', seed, 'SampleTime', ts, 'Position', pos);
% mocap position: ZOH 8 ms -> 1-sample delay (8 ms) -> + noise
zoh('S_pos_zoh', 'p2_Ts_pos', [960 300 990 330]);
A('simulink/Discrete/Delay', 'S_pos_delay', 'DelayLength', 'p2_nd_pos', 'InitialCondition', C.ic_pos_p2, ...
  'SampleTime', 'p2_Ts_pos', 'Position', [1020 300 1060 330]);
rnd('S_pos_noise', 'p2_var_pos', 'p2_seed_pos', 'p2_Ts_pos', [1020 350 1060 380]);
A('simulink/Math Operations/Sum', 'S_pos_sum', 'Inputs', '++', 'Position', [1100 300 1120 340]);
L('X_gam/1', 'S_pos_zoh/1');  L('S_pos_zoh/1', 'S_pos_delay/1');
L('S_pos_delay/1', 'S_pos_sum/1');  L('S_pos_noise/1', 'S_pos_sum/2');
% velocity: backward difference of the measured position at 125 Hz
A('simulink/Discrete/Unit Delay', 'S_vel_prev', 'InitialCondition', C.ic_prev_p2, ...
  'SampleTime', 'p2_Ts_pos', 'Position', [1160 400 1200 430]);
A('simulink/Math Operations/Sum', 'S_vel_diff', 'Inputs', '+-', 'Position', [1240 380 1260 420]);
A('simulink/Math Operations/Gain', 'S_vel_gain', 'Gain', '1/p2_Ts_pos', 'Position', [1290 380 1330 420]);
L('S_pos_sum/1', 'S_vel_prev/1');  L('S_pos_sum/1', 'S_vel_diff/1');  L('S_vel_prev/1', 'S_vel_diff/2');
L('S_vel_diff/1', 'S_vel_gain/1');
% accelerometer (IMU, inertial frame - GD2B_DESIGN sec 6), 1 kHz
zoh('S_acc_zoh', 'p2_Ts_att', [960 470 990 500]);
rnd('S_acc_noise', 'p2_var_acc', 'p2_seed_acc', 'p2_Ts_att', [960 520 1000 550]);
A('simulink/Sources/Constant', 'S_acc_bias', 'Value', 'p2_bias_acc', 'Position', [960 570 1000 590]);
A('simulink/Math Operations/Sum', 'S_acc_sum', 'Inputs', '+++', 'Position', [1040 470 1060 530]);
L('P2_Trans/4', 'S_acc_zoh/1');  L('S_acc_zoh/1', 'S_acc_sum/1');  L('S_acc_noise/1', 'S_acc_sum/2');
L('S_acc_bias/1', 'S_acc_sum/3');
% gyro, 1 kHz
zoh('S_gyr_zoh', 'p2_Ts_att', [960 620 990 650]);
rnd('S_gyr_noise', 'p2_var_gyro', 'p2_seed_gyro', 'p2_Ts_att', [960 670 1000 700]);
A('simulink/Math Operations/Sum', 'S_gyr_sum', 'Inputs', '++', 'Position', [1040 620 1060 660]);
L('F_omega/1', 'S_gyr_zoh/1');  L('S_gyr_zoh/1', 'S_gyr_sum/1');  L('S_gyr_noise/1', 'S_gyr_sum/2');
% attitude angles (clean, 1 kHz), loop outputs held
zoh('S_eta_zoh',  'p2_Ts_att', [960 740 990 770]);   L('F_eta/1', 'S_eta_zoh/1');
zoh('H_Fcmd',     'p2_Ts_pos', [960 800 990 830]);   L('F_Fcmd/1', 'H_Fcmd/1');
zoh('H_fthr',     'p2_Ts_att', [960 860 990 890]);   L('F_fthr/1', 'H_fthr/1');
zoh('H_tau_cmd',  'p2_Ts_att', [960 920 990 950]);   L('F_tau_cmd/1', 'H_tau_cmd/1');

% ---- GD3 stage selection (REGISTER_P2 sec 1.2) ----
% sensors off: the TRUE signal, sampled when discrete is on; discrete off: continuous
zoh('D_pos_zoh', 'p2_Ts_pos', [1400 300 1430 330]);  L('X_gam/1', 'D_pos_zoh/1');
zoh('D_vel_zoh', 'p2_Ts_pos', [1400 440 1430 470]);  L('X_nu/1', 'D_vel_zoh/1');
vsw('V_gam_d', 'p2_discrete', [1460 300 1475 340]);  L('D_pos_zoh/1', 'V_gam_d/1');  L('X_gam/1', 'V_gam_d/2');
vsw('V_gam_s', 'p2_sensors',  [1500 300 1515 340]);  L('S_pos_sum/1', 'V_gam_s/1');  L('V_gam_d/1', 'V_gam_s/2');
vsw('V_nu_d',  'p2_discrete', [1460 440 1475 480]);  L('D_vel_zoh/1', 'V_nu_d/1');   L('X_nu/1', 'V_nu_d/2');
vsw('V_nu_s',  'p2_sensors',  [1500 440 1515 480]);  L('S_vel_gain/1', 'V_nu_s/1');  L('V_nu_d/1', 'V_nu_s/2');
vsw('V_acc_d', 'p2_discrete', [1100 560 1115 600]);  L('S_acc_zoh/1', 'V_acc_d/1');  L('P2_Trans/4', 'V_acc_d/2');
vsw('V_acc_s', 'p2_sensors',  [1140 560 1155 600]);  L('S_acc_sum/1', 'V_acc_s/1');  L('V_acc_d/1', 'V_acc_s/2');
vsw('V_gyr_d', 'p2_discrete', [1100 660 1115 700]);  L('S_gyr_zoh/1', 'V_gyr_d/1');  L('F_omega/1', 'V_gyr_d/2');
vsw('V_gyr_s', 'p2_sensors',  [1140 660 1155 700]);  L('S_gyr_sum/1', 'V_gyr_s/1');  L('V_gyr_d/1', 'V_gyr_s/2');
vsw('V_eta_d', 'p2_discrete', [1100 740 1115 780]);  L('S_eta_zoh/1', 'V_eta_d/1');  L('F_eta/1', 'V_eta_d/2');
vsw('V_Fcmd_d', 'p2_discrete', [1100 800 1115 840]); L('H_Fcmd/1', 'V_Fcmd_d/1');    L('F_Fcmd/1', 'V_Fcmd_d/2');
vsw('V_fthr_d', 'p2_discrete', [1100 860 1115 900]); L('H_fthr/1', 'V_fthr_d/1');    L('F_fthr/1', 'V_fthr_d/2');
vsw('V_tau_d', 'p2_discrete', [1100 920 1115 960]);  L('H_tau_cmd/1', 'V_tau_d/1');  L('F_tau_cmd/1', 'V_tau_d/2');

% ---- the controller's wind-force model (REGISTER_P2 sec 0.3) ----
po = [mdl '/Position_Observers'];
add_block([po '/WM_From'], [ch '/W_meas'], 'Position', [1200 1000 1320 1030]);
add_block([po '/WP_From'], [ch '/W_pred'], 'Position', [1200 1050 1320 1080]);
add_block([po '/WO_From'], [ch '/W_orac'], 'Position', [1200 1100 1320 1130]);
A('simulink/Sources/Constant', 'W_selc', 'Value', 'wind_use_pred', 'Position', [1200 960 1260 980]);
add_block([po '/WSEL'], [ch '/W_sel'], 'Position', [1380 950 1420 1140]);
L('W_selc/1', 'W_sel/1');  L('W_meas/1', 'W_sel/2');  L('W_pred/1', 'W_sel/3');  L('W_orac/1', 'W_sel/4');
A('simulink/User-Defined Functions/MATLAB Function', 'P2_WindHat', 'Position', [1480 980 1600 1060]);
set_eml_script([ch '/P2_WindHat'], fileread(fullfile(here, 'simulink_blocks', 'p2_wind_force_hat.m')));
assert_ports([ch '/P2_WindHat'], 3, 1);
set_eml_sizes([ch '/P2_WindHat'], {'w', '[3 1]'; 'nu_c', '[3 1]'; 'prm_w', '[2 1]'}, {'dlf_hat', '[3 1]'});
L('W_sel/1', 'P2_WindHat/1');  L('V_nu_s/1', 'P2_WindHat/2');  L('prm_w/1', 'P2_WindHat/3');

% ---- F. N6: wind -> payload term (REGISTER_P2 sec 15.4, 18.2; simulink_blocks/p2_n6_term.m) ----
% Linear pendulum observer on the DO's payload estimate, driven by the measured wind, and
% its prediction tau ahead with the column's wind (W_sel) held. Runs at 1 kHz (inputs held).
% Its output dmf_n6 is read only through P2_N6_Sel (Position_Observers) when p2_n6 = 1;
% with p2_n6 = 0 nothing in the loop reads it (value-neutral).
A('simulink/Signal Routing/From', 'F_dmf_do', 'GotoTag', 'dmf_do',   glob{:}, 'Position', [1200 1880 1280 1896]);
A('simulink/Signal Routing/From', 'F_wgate',  'GotoTag', 'p2_wgate', glob{:}, 'Position', [1200 1920 1280 1936]);
zoh('N6_z_wm', 'p2_Ts_att', [1320 1840 1350 1860]);  L('W_meas/1', 'N6_z_wm/1');
zoh('N6_z_ws', 'p2_Ts_att', [1460 1760 1490 1780]);  L('W_sel/1', 'N6_z_ws/1');
zoh('N6_z_v',  'p2_Ts_att', [1320 1800 1350 1820]);  L('V_nu_s/1', 'N6_z_v/1');
zoh('N6_z_d',  'p2_Ts_att', [1320 1880 1350 1900]);  L('F_dmf_do/1', 'N6_z_d/1');
zoh('N6_z_g',  'p2_Ts_att', [1320 1920 1350 1940]);  L('F_wgate/1', 'N6_z_g/1');
A('simulink/Discrete/Unit Delay', 'N6_s', 'InitialCondition', 'zeros(4,1)', 'SampleTime', 'p2_Ts_att', ...
  'Position', [1460 1700 1500 1730]);
A('simulink/Sources/Constant', 'N6_prm', 'Value', 'p2_prm_n6', 'Position', [1440 1980 1500 2000]);
A('simulink/User-Defined Functions/MATLAB Function', 'P2_N6', 'Position', [1560 1700 1700 2000]);
set_eml_script([ch '/P2_N6'], fileread(fullfile(here, 'simulink_blocks', 'p2_n6_term.m')));
assert_ports([ch '/P2_N6'], 7, 3);
set_eml_sizes([ch '/P2_N6'], {'s', '[4 1]'; 'w_meas', '[3 1]'; 'w_sig', '[3 1]'; 'vQ', '[3 1]'; ...
    'dmf_do', '[3 1]'; 'gate', '1'; 'prm', '[17 1]'}, {'s_next', '[4 1]'; 'delta', '[3 1]'; 'mon', '[5 1]'});
L('N6_s/1', 'P2_N6/1');   L('N6_z_wm/1', 'P2_N6/2');  L('N6_z_ws/1', 'P2_N6/3');  L('N6_z_v/1', 'P2_N6/4');
L('N6_z_d/1', 'P2_N6/5'); L('N6_z_g/1', 'P2_N6/6');   L('N6_prm/1', 'P2_N6/7');   L('P2_N6/1', 'N6_s/1');

% ---- G. competitor H3 (REGISTER_P2 sec 40; simulink_blocks/p2_h3_indi.m) ----
% Runs at 1 kHz (inputs held) whenever plant_model = 1; its output dmf_h3 is read only through
% P2_CMP_Sel (Position_Observers) when p2_cmp = 1 - value-neutral otherwise. dmf_h4 = zeros (H4_off).
zoh('H3_z_a', 'p2_Ts_att', [1320 2100 1350 2120]);  L('V_acc_s/1', 'H3_z_a/1');
zoh('H3_z_f', 'p2_Ts_att', [1320 2140 1350 2160]);  L('V_fthr_d/1', 'H3_z_f/1');
zoh('H3_z_e', 'p2_Ts_att', [1320 2180 1350 2200]);  L('V_eta_d/1', 'H3_z_e/1');
A('simulink/Discrete/Unit Delay', 'H3_s', 'InitialCondition', 'p2_h3_s0', 'SampleTime', 'p2_Ts_att', ...
  'Position', [1460 2060 1500 2090]);
A('simulink/Sources/Constant', 'H3_prm', 'Value', 'p2_prm_h3', 'Position', [1440 2220 1500 2240]);
A('simulink/User-Defined Functions/MATLAB Function', 'P2_H3', 'Position', [1560 2060 1700 2260]);
set_eml_script([ch '/P2_H3'], fileread(fullfile(here, 'simulink_blocks', 'p2_h3_indi.m')));
assert_ports([ch '/P2_H3'], 5, 2);
set_eml_sizes([ch '/P2_H3'], {'s', '[7 1]'; 'a_meas', '[3 1]'; 'f_cmd', '1'; 'eta', '[3 1]'; 'prm', '[11 1]'}, ...
    {'s_next', '[7 1]'; 'd_hat', '[3 1]'});
L('H3_s/1', 'P2_H3/1');  L('H3_z_a/1', 'P2_H3/2');  L('H3_z_f/1', 'P2_H3/3');  L('H3_z_e/1', 'P2_H3/4');
L('H3_prm/1', 'P2_H3/5');  L('P2_H3/1', 'H3_s/1');
% sec 50.5: the estimate is read from the STATE by a separate block (same arithmetic), so the thrust command that
% P2_H3 reads does not feed through to dmf_h3 (algebraic loop at the first H3 build); P2_H3's own d_hat is terminated
A('simulink/User-Defined Functions/MATLAB Function', 'P2_H3_out', 'Position', [1760 2060 1860 2120]);
set_eml_script([ch '/P2_H3_out'], fileread(fullfile(here, 'simulink_blocks', 'p2_h3_out.m')));
assert_ports([ch '/P2_H3_out'], 2, 1);
set_eml_sizes([ch '/P2_H3_out'], {'s', '[7 1]'; 'prm', '[11 1]'}, {'d_hat', '[3 1]'});
L('H3_s/1', 'P2_H3_out/1');  L('H3_prm/1', 'P2_H3_out/2');
A('simulink/Sinks/Terminator', 'T_h3', 'Position', [1760 2140 1775 2155]);  L('P2_H3/2', 'T_h3/1');
A('simulink/Sources/Constant', 'H4_off', 'Value', 'zeros(3,1)', 'Position', [1560 2320 1620 2340]);  % H4 dropped (sec 50)

% ---- H. (iii) open-loop pendulum model (REGISTER_P2 sec 45; simulink_blocks/p2_m3_term.m) ----
% Runs at 1 kHz (inputs held) whenever plant_model = 1; dmf_m3n / dmf_m3p are read only through
% P2_M3_DoSel / P2_M3_Sel (Position_Observers) when p2_m3 = 1 - value-neutral otherwise.
A('simulink/Signal Routing/From', 'F_gam_d', 'GotoTag', 'gamma_d', glob{:}, 'Position', [1200 2540 1280 2556]);
A('simulink/Signal Routing/From', 'F_nu_d',  'GotoTag', 'nu_d',    glob{:}, 'Position', [1200 2580 1280 2596]);
A('simulink/Signal Routing/From', 'F_acc_d', 'GotoTag', 'acc_d',   glob{:}, 'Position', [1200 2620 1280 2636]);
zoh('M3_z_gd', 'p2_Ts_att', [1320 2540 1350 2560]);  L('F_gam_d/1', 'M3_z_gd/1');
zoh('M3_z_nd', 'p2_Ts_att', [1320 2580 1350 2600]);  L('F_nu_d/1', 'M3_z_nd/1');
zoh('M3_z_ad', 'p2_Ts_att', [1320 2620 1350 2640]);  L('F_acc_d/1', 'M3_z_ad/1');
zoh('M3_z_gc', 'p2_Ts_att', [1320 2660 1350 2680]);  L('V_gam_s/1', 'M3_z_gc/1');
A('simulink/Discrete/Unit Delay', 'M3_s', 'InitialCondition', 'zeros(4,1)', 'SampleTime', 'p2_Ts_att', ...
  'Position', [1460 2500 1500 2530]);
A('simulink/Sources/Constant', 'M3_prm', 'Value', 'p2_prm_m3', 'Position', [1440 2720 1500 2740]);
A('simulink/User-Defined Functions/MATLAB Function', 'P2_M3', 'Position', [1560 2500 1700 2760]);
set_eml_script([ch '/P2_M3'], fileread(fullfile(here, 'simulink_blocks', 'p2_m3_term.m')));
assert_ports([ch '/P2_M3'], 9, 4);
set_eml_sizes([ch '/P2_M3'], {'s', '[4 1]'; 'w_meas', '[3 1]'; 'vQ', '[3 1]'; 'gam_d', '[3 1]'; ...
    'nu_d', '[3 1]'; 'acc_d', '[3 1]'; 'gam_c', '[3 1]'; 'a_meas', '[3 1]'; 'prm', '[30 1]'}, ...
    {'s_next', '[4 1]'; 'dM_now', '[3 1]'; 'dM_pred', '[3 1]'; 'mon', '[6 1]'});
L('M3_s/1', 'P2_M3/1');    L('N6_z_wm/1', 'P2_M3/2');  L('N6_z_v/1', 'P2_M3/3');   L('M3_z_gd/1', 'P2_M3/4');
L('M3_z_nd/1', 'P2_M3/5'); L('M3_z_ad/1', 'P2_M3/6');  L('M3_z_gc/1', 'P2_M3/7');  L('H3_z_a/1', 'P2_M3/8');
L('M3_prm/1', 'P2_M3/9');  L('P2_M3/1', 'M3_s/1');

% ---- outports (order = C.sel) ----
L('X_gam/1', 'o_gamma/1');         L('X_nu/1', 'o_nu/1');       L('P2_Trans/4', 'o_nu_dot/1');
L('P2_Trans/5', 'o_d_mf/1');       L('P2_Trans/6', 'o_d_lf/1');     L('M_sel_tau/1', 'o_tau_plant/1');
L('V_gam_s/1', 'o_gamma_c/1');     L('V_nu_s/1', 'o_nu_c/1');       L('V_acc_s/1', 'o_nu_dot_c/1');
L('V_gyr_s/1', 'o_omega_c/1');     L('V_eta_d/1', 'o_eta_c/1');     L('V_Fcmd_d/1', 'o_Fcmd_c/1');
L('V_fthr_d/1', 'o_fthr_c/1');     L('V_tau_d/1', 'o_tau_cmd_c/1');  L('P2_WindHat/1', 'o_dlf_p2/1');
L('P2_N6/2', 'o_dmf_n6/1');        L('P2_H3_out/1', 'o_dmf_h3/1');
L('H4_off/1', 'o_dmf_h4/1');
L('P2_M3/2', 'o_dmf_m3n/1');       L('P2_M3/3', 'o_dmf_m3p/1');

% ---- logs (only exist when plant_model = 1) ----
tw = @(name, var, dec, pos) A('simulink/Sinks/To Workspace', name, 'VariableName', var, ...
    'SaveFormat', 'Structure With Time', 'Decimation', dec, 'SampleTime', '-1', 'Position', pos);
tw('L_mon',       'p2_mon_log',        '1',          [860 280 940 300]);   L('P2_Trans/7', 'L_mon/1');
tw('L_f',         'p2_f_log',          'p2_log_dec', [420 80 500 100]);    L('V_lag/1', 'L_f/1');
tw('L_gamma_c',   'p2_gamma_c_log',    '1',          [1540 300 1620 320]); L('V_gam_s/1', 'L_gamma_c/1');
tw('L_nu_c',      'p2_nu_c_log',       '1',          [1540 440 1620 460]); L('V_nu_s/1', 'L_nu_c/1');
tw('L_npos',      'p2_noise_pos_log',  '1',          [1100 360 1180 380]); L('S_pos_noise/1', 'L_npos/1');
tw('L_ngyr',      'p2_noise_gyro_log', '1',          [1040 700 1120 720]); L('S_gyr_noise/1', 'L_ngyr/1');
tw('L_nacc',      'p2_noise_acc_log',  '1',          [1040 550 1120 570]); L('S_acc_noise/1', 'L_nacc/1');
tw('L_Fcmd',      'p2_Fcmd_log',       '1',          [1140 800 1220 820]); L('V_Fcmd_d/1', 'L_Fcmd/1');
tw('L_n6',        'p2_n6_log',         'p2_log_dec', [1760 1960 1840 1980]); L('P2_N6/3', 'L_n6/1');
tw('L_m3',        'p2_m3_log',         'p2_log_dec', [1760 2740 1840 2760]); L('P2_M3/4', 'L_m3/1');
end

%% =====================================================================
function ok = compile_check(mdl, segment, say)
%COMPILE_CHECK  Separate compiles at plant_model = 0 -> 1 -> 0 (Variant controls are
%compile-time). State 1 needs a loaded segment and p2_setup (P2 variables).
ok = false;
% plant_model 0, P2 nominal (all components on), P2 with every GD3 switch off, 0 again
states = [0 1 2 3 4 6 7 8 0];              % 3 = N6 term on; 4 = competitor H3 (sec 40; H4 = 5 dropped, sec 50);
                                           % 6 / 7 = (iii) cmd / meas (sec 45); 8 = weight trim (sec 47)
for si = 1:numel(states)
    pm = min(states(si), 1);
    try
        reset_extensions('Quiet', true);
        evalc('wind_sim_load(segment, 1)');
        evalin('base', 'init_MOBADC_params');
        if ~evalin('base', 'exist(''dmf_inj_ts'',''var'')')      % as pa_configs does
            assignin('base', 'dmf_inj_ts', struct('time', [0; 1], ...
                'signals', struct('values', zeros(2, 3), 'dimensions', 3)));
        end
        if states(si) == 1, p2_setup(segment); end
        if states(si) == 2
            p2_setup(segment, 'MotorLag', false, 'Discrete', false, 'Sensors', false);
        end
        if states(si) == 3, p2_setup(segment, 'N6', true, 'N6TauMs', 20); end
        if states(si) == 4, p2_setup(segment, 'Cmp', 1); end
        if states(si) == 6, p2_setup(segment, 'M3', true, 'M3TauMs', 20); end
        if states(si) == 7, p2_setup(segment, 'M3', true, 'M3TauMs', 20, 'M3Acc', 'meas'); end
        if states(si) == 8, p2_setup(segment, 'TrimFF', true); end
    catch err
        say('  [FAIL] workspace set-up for plant_model=%d: %s\n', pm, err.message);
        return
    end
    say('  compile check (plant_model=%d%s)...\n', pm, tern(states(si) == 2, ', GD3 switches all OFF', ...
        tern(states(si) == 3, ', N6 term ON', tern(states(si) == 4, ', H3 ON', ...
        tern(states(si) == 6, ', (iii) ON', tern(states(si) == 7, ', (iii-m) ON', tern(states(si) == 8, ', weight trim ON', '')))))));
    % an algebraic loop is an ERROR here (REGISTER_P2 sec 1.6: the lag-OFF loop was only a
    % warning and went unnoticed until S1 ran); the model's own setting is restored after
    alMsg = get_param(mdl, 'AlgebraicLoopMsg');
    set_param(mdl, 'AlgebraicLoopMsg', 'error');
    try
        feval(mdl, [], [], [], 'compile');
    catch err
        set_param(mdl, 'AlgebraicLoopMsg', alMsg);
        say('  [FAIL] compile error (plant_model=%d):\n    %s\n', pm, err.message);
        try, say('%s\n', getReport(err, 'extended', 'hyperlinks', 'off')); catch, end
        return
    end
    feval(mdl, [], [], [], 'term');
    set_param(mdl, 'AlgebraicLoopMsg', alMsg);
    say('  [OK]   compile clean, no algebraic loop (plant_model=%d)\n', pm);
end
ok = true;
end

%% =====================================================================
function n = teardown(mdl, C, say)
%TEARDOWN  Undo every change of this script. Safe when nothing is there.
n = 0;
here = repo_root();
% root subsystem
if getSimulinkBlockHandle([mdl '/P2']) > 0
    delete_block([mdl '/P2']);  n = n + 1;
end
po = [mdl '/Position_Observers'];
% sec 47 weight trim (after Manual Switch)
if getSimulinkBlockHandle([po '/P2_TRIM_Sel']) > 0
    try_del(po, 'Manual Switch/1', 'P2_TRIM_Sel/1');  try_del(po, 'Manual Switch/1', 'P2_TRIM_Sum/1');
    try_del(po, 'P2_TRIM_c/1', 'P2_TRIM_Sum/2');      try_del(po, 'P2_TRIM_Sum/1', 'P2_TRIM_Sel/2');
    try_del(po, 'P2_TRIM_Sel/1', 'G_dmf_hat/1');
    for b = {'P2_TRIM_Sel', 'P2_TRIM_Sum', 'P2_TRIM_c'}
        if getSimulinkBlockHandle([po '/' b{1}]) > 0, delete_block([po '/' b{1}]); end
    end
    add_line(po, 'Manual Switch/1', 'G_dmf_hat/1', 'autorouting', 'on');
    n = n + 1;
end
% (iii) insertion (before H3/H4: it sits after P2_CMP_Sel)
if getSimulinkBlockHandle([po '/P2_M3_Sel']) > 0
    try_del(po, 'P2_CMP_Sel/1', 'P2_M3_Sel/1');   try_del(po, 'P2_CMP_Sel/1', 'P2_M3_Sum/1');
    try_del(po, 'P2_F_m3p/1', 'P2_M3_Sum/2');     try_del(po, 'P2_M3_Sum/1', 'P2_M3_Sel/2');
    try_del(po, 'P2_M3_Sel/1', 'Manual Switch/1');
    try_del(po, 'F_dlf_hat/1', 'P2_M3_DoSel/1');  try_del(po, 'F_dlf_hat/1', 'P2_M3_DoSum/1');
    try_del(po, 'P2_F_m3n/1', 'P2_M3_DoSum/2');   try_del(po, 'P2_M3_DoSum/1', 'P2_M3_DoSel/2');
    try_del(po, 'P2_M3_DoSel/1', 'DO_12/5');
    for b = {'P2_M3_Sel', 'P2_M3_Sum', 'P2_F_m3p', 'P2_M3_DoSel', 'P2_M3_DoSum', 'P2_F_m3n'}
        if getSimulinkBlockHandle([po '/' b{1}]) > 0, delete_block([po '/' b{1}]); end
    end
    add_line(po, 'P2_CMP_Sel/1', 'Manual Switch/1', 'autorouting', 'on');
    add_line(po, 'F_dlf_hat/1', 'DO_12/5', 'autorouting', 'on');
    n = n + 1;
end
% H3/H4 insertion (before N6: it sits after P2_N6_Sel)
if getSimulinkBlockHandle([po '/P2_CMP_Sel']) > 0
    try_del(po, 'P2_N6_Sel/1', 'P2_CMP_Sel/1');   try_del(po, 'P2_F_h3/1', 'P2_CMP_Sel/2');
    try_del(po, 'P2_F_h4/1', 'P2_CMP_Sel/3');     try_del(po, 'P2_CMP_Sel/1', 'Manual Switch/1');
    try_del(po, 'WD_Switch/1', 'P2_CMPW_Sel/1');  try_del(po, 'P2_Zw/1', 'P2_CMPW_Sel/2');
    try_del(po, 'P2_CMPW_Sel/1', 'Manual Switch1/1');
    for b = {'P2_CMP_Sel', 'P2_F_h3', 'P2_F_h4', 'P2_CMPW_Sel', 'P2_Zw'}
        if getSimulinkBlockHandle([po '/' b{1}]) > 0, delete_block([po '/' b{1}]); end
    end
    add_line(po, 'P2_N6_Sel/1', 'Manual Switch/1', 'autorouting', 'on');
    add_line(po, 'WD_Switch/1', 'Manual Switch1/1', 'autorouting', 'on');
    n = n + 1;
end
% N6 insertion (before the wind path: both live in Position_Observers)
if getSimulinkBlockHandle([po '/P2_N6_Sel']) > 0
    try_del(po, 'PP_Switch/1', 'P2_N6_Sel/1');    try_del(po, 'PP_Switch/1', 'P2_N6_Sum/1');
    try_del(po, 'P2_F_n6/1', 'P2_N6_Sum/2');      try_del(po, 'P2_N6_Sum/1', 'P2_N6_Sel/2');
    try_del(po, 'P2_N6_Sel/1', 'Manual Switch/1');
    try_del(po, 'DO_Out/1', 'P2_G_dmf_do/1');     try_del(po, 'WD_gate/1', 'P2_G_wgate/1');
    for b = {'P2_N6_Sel', 'P2_N6_Sum', 'P2_F_n6', 'P2_G_dmf_do', 'P2_G_wgate'}
        if getSimulinkBlockHandle([po '/' b{1}]) > 0, delete_block([po '/' b{1}]); end
    end
    add_line(po, 'PP_Switch/1', 'Manual Switch/1', 'autorouting', 'on');
    n = n + 1;
end
% wind path
if getSimulinkBlockHandle([po '/P2_WD_Sel']) > 0
    try_del(po, 'WSEL/1', 'P2_PZ_wsel/1');       try_del(po, 'P2_PZc_wsel/1', 'P2_PZ_wsel/2');
    try_del(po, 'P2_PZ_wsel/1', 'P2_WD_Sel/1');  try_del(po, 'P2_F_dlf/1', 'P2_WD_Sel/2');
    try_del(po, 'P2_WD_Sel/1', 'WD_Switch/1');
    for b = {'P2_WD_Sel', 'P2_PZ_wsel', 'P2_F_dlf', 'P2_PZc_wsel'}
        delete_block([po '/' b{1}]);
    end
    add_line(po, 'WSEL/1', 'WD_Switch/1', 'autorouting', 'on');
    n = n + 1;
end
% poison VS + Goto tags
for k = 1:size(C.v1goto, 1)
    [blk, tag, srcBlk, srcPort] = C.v1goto{k, :};
    sys = fileparts([mdl '/' blk]);
    gname = blk(numel(fileparts(blk)) + 2:end);
    pz = [sys '/P2_PZ_' tag];  pc = [sys '/P2_PZc_' tag];
    if getSimulinkBlockHandle(pz) > 0
        try_del(sys, sprintf('%s/%d', srcBlk, srcPort), ['P2_PZ_' tag '/1']);
        try_del(sys, ['P2_PZc_' tag '/1'], ['P2_PZ_' tag '/2']);
        try_del(sys, ['P2_PZ_' tag '/1'], [gname '/1']);
        delete_block(pz);  delete_block(pc);
        add_line(sys, sprintf('%s/%d', srcBlk, srcPort), [gname '/1'], 'autorouting', 'on');
        n = n + 1;
    end
    if ~strcmp(get_param([sys '/' gname], 'GotoTag'), tag)
        set_param([sys '/' gname], 'GotoTag', tag);  n = n + 1;
    end
end
% From tags
for k = 1:size(C.ctrlfrom, 1)
    f = [mdl '/' C.ctrlfrom{k, 1}];
    if getSimulinkBlockHandle(f) > 0 && ~strcmp(get_param(f, 'GotoTag'), C.ctrlfrom{k, 2})
        set_param(f, 'GotoTag', C.ctrlfrom{k, 2});  n = n + 1;
    end
end
% initial conditions
if ~strcmp(strtrim(get_param([mdl '/' C.int_z], 'InitialCondition')), C.ic_z_old)
    set_param([mdl '/' C.int_z], 'InitialCondition', C.ic_z_old);  n = n + 1;
end
if ~strcmp(strtrim(get_param([mdl '/' C.int_zp], 'InitialCondition')), C.ic_zp_old)
    set_param([mdl '/' C.int_zp], 'InitialCondition', C.ic_zp_old);  n = n + 1;
end
% thrust_attitude_ref back to 4 inputs (the pre-P2 code, from git tag v1-final)
ar = [mdl '/Attitude_Reference'];
if getSimulinkBlockHandle([ar '/P2_FTOT']) > 0
    try_del(ar, 'P2_FTOT/1', 'Thrust_AttRef_16/5');  delete_block([ar '/P2_FTOT']);  n = n + 1;
end
p = get_param([mdl '/' C.tar], 'Ports');
if p(1) ~= 4
    [st, old] = system(sprintf('git -C "%s" show v1-final:simulink_blocks/thrust_attitude_ref.m', here));
    assert(st == 0, 'build_p2_plant: cannot read the pre-P2 thrust_attitude_ref from git tag v1-final.');
    set_eml_script([mdl '/' C.tar], old);
    n = n + 1;
end
end

function try_del(sys, src, dst)
%TRY_DEL  Delete exactly the connection src -> dst (a branch of a branched line only).
try, delete_line(sys, src, dst); catch, end
end

%% =====================================================================
function s = source_of(blk, port)
%SOURCE_OF  Name of the block driving input port `port` of blk.
pc = get_param(blk, 'PortConnectivity');
src = pc(port).SrcBlock;
if isempty(src) || src < 0, s = ''; else, s = get_param(src, 'Name'); end
end

function set_eml_script(blkpath, code)
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', blkpath);
assert(~isempty(ch), 'set_eml_script: no Stateflow.EMChart found for %s', blkpath);
ch(1).Script = code;
end

function set_eml_sizes(blk, ins, outs)
%SET_EML_SIZES  Explicit size and type 'double' for every input and output of a MATLAB
%Function block (GD2b, second build attempt: size inference failed in the P2_x loop).
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', blk);
assert(~isempty(ch), 'set_eml_sizes: no Stateflow.EMChart found for %s', blk);
spec = [ins; outs];
for i = 1:size(spec, 1)
    d = ch(1).find('-isa', 'Stateflow.Data', 'Name', spec{i, 1});
    assert(numel(d) == 1, 'set_eml_sizes: %s has no single data object named %s.', blk, spec{i, 1});
    d.DataType = 'double';
    d.Props.Array.Size = spec{i, 2};
end
end

function assert_ports(blk, n_in, n_out)
p = get_param(blk, 'Ports');
assert(p(1) == n_in && p(2) == n_out, '%s has %d in / %d out, expected %d / %d.', ...
    blk, p(1), p(2), n_in, n_out);
end

function fp = fingerprint(mdl, C)
%FINGERPRINT  SHA-256 over the P2 wiring: every block under P2 (path, type, key
%parameters) + every v1 block this script changed. Printed for the two sides to compare.
parts = {};
try
    bl = find_system([mdl '/P2'], 'LookUnderMasks', 'all', 'MatchFilter', @Simulink.match.allVariants);
catch
    bl = find_system([mdl '/P2'], 'LookUnderMasks', 'all', 'Variants', 'AllVariants');
end
for i = 1:numel(bl)
    parts{end + 1} = sprintf('%s|%s', bl{i}(numel(mdl) + 2:end), get_param(bl{i}, 'BlockType')); %#ok<AGROW>
end
for k = 1:size(C.ctrlfrom, 1)
    parts{end + 1} = sprintf('%s|%s', C.ctrlfrom{k, 1}, get_param([mdl '/' C.ctrlfrom{k, 1}], 'GotoTag')); %#ok<AGROW>
end
for k = 1:size(C.v1goto, 1)
    parts{end + 1} = sprintf('%s|%s', C.v1goto{k, 1}, get_param([mdl '/' C.v1goto{k, 1}], 'GotoTag')); %#ok<AGROW>
end
pob = find_system([mdl '/Position_Observers'], 'SearchDepth', 1, 'Regexp', 'on', 'Name', '^P2_');
for i = 1:numel(pob)
    parts{end + 1} = sprintf('%s|%s', pob{i}(numel(mdl) + 2:end), get_param(pob{i}, 'BlockType')); %#ok<AGROW>
end
parts{end + 1} = get_param([mdl '/' C.int_z], 'InitialCondition');
parts{end + 1} = get_param([mdl '/' C.int_zp], 'InitialCondition');
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', [mdl '/' C.tar]);
parts{end + 1} = ch(1).Script;
s = strjoin(sort(parts), newline);
md = java.security.MessageDigest.getInstance('SHA-256');
h = typecast(md.digest(uint8(s)), 'uint8');
fp = lower(reshape(dec2hex(h, 2).', 1, []));
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end

function h = git_hash()
[st, h] = system('git rev-parse --short HEAD');
if st ~= 0, h = 'unknown'; end
h = strtrim(h);
end
