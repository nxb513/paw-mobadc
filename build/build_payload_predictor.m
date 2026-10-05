function build_payload_predictor(varargin)
%BUILD_PAYLOAD_PREDICTOR  Dau bo du doan nhieu tai vao baseline1.slx.
%
%   build_payload_predictor                  % dung / dung lai (idempotent)
%   build_payload_predictor('Revert', true)  % go het, tra model ve truoc do
%   build_payload_predictor('Save',  false)  % dung nhung khong ghi de .slx
%
%  ------------------------------------------------------------------
%  CHEN VAO DAU, VA TAI SAO CHI CO THE CHEN O DO
%  ------------------------------------------------------------------
%  Trong Position_Observers, duong uoc luong nhieu tai la:
%
%     truoc:  DO_Out/1 ─────────────────────► Manual Switch/1 ─► G_dmf_hat
%
%  Manual Switch la cong tac cau hinh (DO bat/tat) da co san, va tag
%  d_mf_hat sau no duoc doc boi CA position_controller LAN eso_pos_derivative.
%
%     sau:    DO_Out/1 ──────────────► PP_Switch/3 ─► Manual Switch/1 ─► ...
%                                          ▲  ▲
%             Payload_Predictor ───────────┘  │
%                                        predictor_on
%
%  Chen o day co ba cai loi:
%    1. Mot diem chen duy nhat, khong rewire gi.
%    2. CA bo dieu khien lan ESO deu thay gia tri da du doan. Dieu do dung:
%       ESO dung dmf_hat de biet phan nao cua nhieu DA duoc bu roi, nen no
%       phai thay dung cai dang duoc ap.
%    3. Khoi DO_Out KHONG bi dong vao. predictor_on = 0 tai lap baseline
%       khong phai bang "cong thuc tuong duong" ma bang dung khoi cu.
%
%  ------------------------------------------------------------------
%  KHONG CO VONG LAP DAI SO
%  ------------------------------------------------------------------
%  Payload_Predictor chi doc gamma, nu (do duoc) va z (trang thai cua
%  Int_z). Khong doc F, khong doc dmf_hat. Giong het ly do ma DO_Out duoc
%  tach rieng khoi DO_12 trong ban goc.
%
%  ------------------------------------------------------------------
%  AN TOAN
%  ------------------------------------------------------------------
%  * 'Revert' tra duong tin hieu ve dung nhu truoc: DO_Out/1 -> Manual Switch/1.
%  * Chay lai nhieu lan khong sao: go het thu cua lan truoc roi dung lai.
%  * predictor_on = 0 PHAI tai lap baseline theo tung chu so. run_test5_predictor
%    tu kiem tra dieu do va dung han neu khong.
%
%  ------------------------------------------------------------------
%  PART 3.3 (TEST_PLAN_PROMPT.md): n_state_axis, MOT DAU VAO MOI
%  ------------------------------------------------------------------
%  simulink_blocks/payload_predictor.m gio nhan 7 dau vao thay vi 6: them
%  n_state_axis (3x1, so trang thai moi truc - build/im_oracle_axis.m va
%  build/build_do_matrices.m's new form). Ham nay dung block Constant moi,
%  PP_nax, doc bien base workspace cung ten 'n_state_axis' - bien do da duoc
%  moi noi dung lai do_w (core/init_MOBADC_params.m, core/pa_configs.m,
%  core/op_set.m, va cac script experiments/*/verification/* rebuild A_do)
%  dat lai thanh do_info.n_ax_state(:), dung mau voi do_w chinh no.
%  Voi cau hinh CU (ca 3 truc bang nhau), n_state_axis = [n_as;n_as;n_as]
%  tai lap dung trang thai cu - day la ly do Checkpoint 3.3's bit-exact
%  gate (circle) khong can nhanh rieng.

opt = parse_opts(varargin);

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();

require_block_sources(here, {'payload_predictor'});

if ~bdIsLoaded(mdl), load_system(mdl); end

po   = [mdl '/Position_Observers'];
pred = [po '/Payload_Predictor'];

%% ---------------- Go bo thu cu (idempotent + Revert) ----------------
n_removed = teardown(po, pred);
if n_removed > 0
    fprintf('Da go %d khoi cua lan dung truoc.\n', n_removed);
end

if opt.Revert
    relink_baseline(po);
    if opt.Save, save_system(mdl); end
    fprintf('\nDa tra model ve truoc do. DO_Out/1 -> Manual Switch/1 truc tiep.\n');
    return
end

% Giai phong cong vao cua Manual Switch: PP_Switch se nuoi no thay DO_Out.
free_switch_input(po);

%% ---------------- Khoi du doan ----------------
build_predictor_subsystem(pred, here);

%% ---------------- Cong tac + tham so ----------------
add_block('simulink/Sources/Constant', [po '/PP_pon'], ...
          'Value','predictor_on', 'Position',[560 640 660 670]);

add_block('simulink/Signal Routing/Switch', [po '/PP_Switch'], ...
          'Criteria','u2 >= Threshold', 'Threshold','0.5', ...
          'Position',[700 560 740 660]);

add_block('simulink/Sinks/To Workspace', [po '/PP_pred_log'], ...
          'VariableName','dmf_pred_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[790 700 880 730]);

%% ---------------- Noi day ----------------
% Vao cua khoi du doan: nhanh tu chinh cac nguon ma DO_Out dang dung, nen
% hai khoi luon thay cung mot thu. add_line tao NHANH tren duong da co, khong
% cat duong cu.
add_line(po, 'F_gamma/1', 'Payload_Predictor/1', 'autorouting','on');
add_line(po, 'F_nu/1',    'Payload_Predictor/2', 'autorouting','on');
add_line(po, 'Int_z/1',   'Payload_Predictor/3', 'autorouting','on');

add_line(po, 'Payload_Predictor/1', 'PP_Switch/1', 'autorouting','on');
add_line(po, 'PP_pon/1',            'PP_Switch/2', 'autorouting','on');
add_line(po, 'DO_Out/1',            'PP_Switch/3', 'autorouting','on');
add_line(po, 'PP_Switch/1',         'Manual Switch/1', 'autorouting','on');
add_line(po, 'PP_Switch/1',         'PP_pred_log/1',   'autorouting','on');

%% ---------------- Kiem tra ----------------
fprintf('\n=== KIEM TRA SAU KHI DUNG ===\n');
ok = compile_check(mdl, po);

% KHONG ghi khi compile hong. Ban dau ham nay ghi VO DIEU KIEN, va toi da
% chep khiem khuyet do sang build_wind_series - no da ghi mot model khong
% compile duoc xuong dia. remove_amp_tau.m lam dung: bao loi TRUOC khi ghi.
% Sua o day de ca ba script cung mot chuan.
if opt.Save && ok
    save_system(mdl);
    fprintf('Da ghi %s\n', [mdl '.slx']);
elseif opt.Save
    fprintf(['KHONG ghi: compile hong. Model dang mo o trang thai da sua;\n' ...
             'sua loi roi chay lai, hoac build_payload_predictor(''Revert'',true).\n']);
else
    fprintf('KHONG ghi (Save = false). Model dang mo o trang thai da sua.\n');
end

% Doi chieu Constant nuoi do_w: sua ten bien trong file nay ma quen chay lai
% script thi khoi van duoc nuoi bang bien CU, va lech do khong the phat hien
% qua sync_eml_blocks (no chi so CODE, khong so gia tri khoi Constant).
val = get_param([pred '/PP_sigma'], 'Value');
if ~strcmp(val, 'do_w')
    warning('build_payload_predictor:wrongConst', ...
        'PP_sigma dang tro vao ''%s'', mong doi ''do_w''.', val);
else
    fprintf('  [OK]   PP_sigma <- do_w\n');
end

val = get_param([pred '/PP_nax'], 'Value');
if ~strcmp(val, 'n_state_axis')
    warning('build_payload_predictor:wrongConst', ...
        'PP_nax dang tro vao ''%s'', mong doi ''n_state_axis''.', val);
else
    fprintf('  [OK]   PP_nax   <- n_state_axis\n');
end

fprintf('\nBuoc tiep theo:\n');
if ok
    fprintf('  sync_eml_blocks                  %% phai bao khop\n');
    fprintf('  run_test5_predictor              %% off/on tai tau mac dinh\n');
    fprintf('  run_test5_predictor(0:0.02:0.20) %% quet tau\n');
else
    fprintf('  Sua loi compile o tren truoc da.\n');
end
end


%% =====================================================================
function build_predictor_subsystem(pred, here)
%BUILD_PREDICTOR_SUBSYSTEM  Dung Payload_Predictor tu dau.

add_block('built-in/Subsystem', pred, 'Position',[380 540 560 680]);
if getSimulinkBlockHandle([pred '/In1']) > 0
    try delete_line(pred, 'In1/1', 'Out1/1'); catch, end
    delete_block([pred '/In1']);
end
if getSimulinkBlockHandle([pred '/Out1']) > 0
    delete_block([pred '/Out1']);
end

% Vao: gamma, nu, z - lay tu chinh cac From/Integrator ma DO_Out dang dung.
add_block('simulink/Sources/In1', [pred '/gamma'], 'Port','1', 'Position',[40  60 70  74]);
add_block('simulink/Sources/In1', [pred '/nu'],    'Port','2', 'Position',[40 120 70 134]);
add_block('simulink/Sources/In1', [pred '/z'],     'Port','3', 'Position',[40 180 70 194]);

add_block('simulink/Sources/Constant', [pred '/PP_lg'],    'Value','l_gain',        'Position',[40 240 140 270]);
add_block('simulink/Sources/Constant', [pred '/PP_sigma'], 'Value','do_w',          'Position',[40 290 140 320]);
add_block('simulink/Sources/Constant', [pred '/PP_nax'],   'Value','n_state_axis',  'Position',[40 340 140 370]);
add_block('simulink/Sources/Constant', [pred '/PP_tau'],   'Value','tau_pred',      'Position',[40 390 140 420]);

blk = [pred '/pred_fcn'];
add_block('simulink/User-Defined Functions/MATLAB Function', blk, 'Position',[260 60 420 320]);
set_eml_script(blk, fileread(fullfile(here,'simulink_blocks','payload_predictor.m')));
assert_ports(blk, 7, 1);   % gamma, nu, z, l_gain, do_w, n_state_axis, tau_pred

add_block('simulink/Sinks/Out1', [pred '/dmf_hat_p'], 'Port','1', 'Position',[480 183 510 197]);

add_line(pred, 'gamma/1',    'pred_fcn/1', 'autorouting','on');
add_line(pred, 'nu/1',       'pred_fcn/2', 'autorouting','on');
add_line(pred, 'z/1',        'pred_fcn/3', 'autorouting','on');
add_line(pred, 'PP_lg/1',    'pred_fcn/4', 'autorouting','on');
add_line(pred, 'PP_sigma/1', 'pred_fcn/5', 'autorouting','on');
add_line(pred, 'PP_nax/1',   'pred_fcn/6', 'autorouting','on');
add_line(pred, 'PP_tau/1',   'pred_fcn/7', 'autorouting','on');
add_line(pred, 'pred_fcn/1', 'dmf_hat_p/1','autorouting','on');
end


%% =====================================================================
function set_eml_script(blkpath, code)
ch = find(sfroot, '-isa','Stateflow.EMChart', 'Path', blkpath);
assert(~isempty(ch), 'Khong tim thay Stateflow.EMChart cho %s', blkpath);
ch(1).Script = code;
end

function assert_ports(blk, n_in, n_out)
p = get_param(blk, 'Ports');
assert(p(1) == n_in && p(2) == n_out, ...
   ['%s co %d vao / %d ra, mong doi %d / %d.\n' ...
    'Chu ky ham trong simulink_blocks/payload_predictor.m da doi.'], ...
    blk, p(1), p(2), n_in, n_out);
end


%% =====================================================================
function n = teardown(po, pred)
n = 0;
targets = {[po '/PP_Switch'], [po '/PP_pred_log'], [po '/PP_pon'], pred};
for i = 1:numel(targets)
    if getSimulinkBlockHandle(targets{i}) > 0
        drop_lines(targets{i});
    end
end
for i = 1:numel(targets)
    if getSimulinkBlockHandle(targets{i}) > 0
        delete_block(targets{i});
        n = n + 1;
    end
end
end

function drop_lines(blk)
lh = get_param(blk, 'LineHandles');
for f = {'Inport','Outport'}
    v = lh.(f{1});
    for i = 1:numel(v)
        if v(i) > 0
            try delete_line(v(i)); catch, end
        end
    end
end
end


%% =====================================================================
function relink_baseline(po)
free_switch_input(po);
add_line(po, 'DO_Out/1', 'Manual Switch/1', 'autorouting','on');
end

function free_switch_input(po)
lh = get_param([po '/Manual Switch'], 'LineHandles');
if lh.Inport(1) > 0
    delete_line(lh.Inport(1));
end
end


%% =====================================================================
function ok = compile_check(mdl, po)
ok = false;
try
    evalin('base','init_MOBADC_params');
catch err
    fprintf('  [FAIL] init_MOBADC_params loi: %s\n', err.message);
    return
end

cleanupObj = onCleanup(@() safe_term(mdl)); %#ok<NASGU>
try
    feval(mdl, [], [], [], 'compile');
catch err
    fprintf('  [FAIL] compile loi:\n    %s\n', err.message);
    if contains(lower(err.message), 'algebraic')
        fprintf(['    -> Vong lap dai so. Payload_Predictor chi duoc doc gamma, ' ...
                 'nu, z - kiem tra xem no co bi noi vao F hay dmf_hat khong.\n']);
    end
    return
end

want = struct('PP_Switch', 3, 'Payload_Predictor', 3);
allok = true;
f = fieldnames(want);
for i = 1:numel(f)
    w = get_param([po '/' f{i}], 'CompiledPortWidths');
    got = w.Outport(1);
    good = (got == want.(f{i}));
    allok = allok && good;
    if good, v = 'OK'; else, v = '*** SAI ***'; end
    fprintf('  [%s] %-20s be rong dau ra = %d (mong doi %d)\n', ...
            v, f{i}, got, want.(f{i}));
end
fprintf('  [OK]   compile sach, khong co vong lap dai so\n');
ok = allok;
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
function opt = parse_opts(args)
opt = struct('Revert', false, 'Save', true);
for i = 1:2:numel(args)
    name = validatestring(args{i}, fieldnames(opt));
    opt.(name) = args{i+1};
end
end
