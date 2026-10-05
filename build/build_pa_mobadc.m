function build_pa_mobadc(varargin)
%BUILD_PA_MOBADC  Dua K_w*w_hat(t+tau) vao cong dlf_hat cua bo dieu khien.
%
%   wind_sim_load('wind_real_t150.mat')   % nap what_ts + wvalid_ts
%   build_wind_predictor                  % W6.1 - phai chay truoc
%   build_pa_mobadc                       % dung / dung lai (idempotent)
%   build_pa_mobadc('Revert', true)       % go
%   build_pa_mobadc('Save',  false)       % dung nhung khong ghi de .slx
%
%  ======================================================================
%  W6.2 CUA KE HOACH KHONG TON TAI - VA DAY LA LY DO
%  ======================================================================
%  Ke hoach ghi: "W6.2 - d_hat_total = d_hat_payload + d_hat_wind, kiem
%  tung kenh voi kenh kia bang 0". Nhung position_controller.m dong 13:
%
%      F = m*a_d - dmf_hat - dlf_hat;
%
%  Phep cong DA CO SAN, ngay trong luat dieu khien, tren HAI CONG rieng.
%  Dung them mot khoi Sum nua la cong hai lan hoac phai di lai day. Nen
%  W6.2 va W6.3 gop lam mot: viec con lai la DINH TUYEN K_w*w_hat vao dung
%  cong dlf_hat.
%
%  Va d_lf DUNG LA gio, khong lan gi khac - disturbance_generator.m dong 35:
%      d_lf = wind_amp*[cos(psi_w); sin(psi_w); 0];
%  con tai treo di theo d_mf. Nen thay dlf_hat bang mot bo du doan GIO la
%  phep thay dung doi tuong, khong phai xap xi.
%
%  ======================================================================
%  CHEN O DAU - DUNG KHUON CUA PP_Switch
%  ======================================================================
%      truoc:  <nguon>/1 ──────────────────────► Manual Switch1/1 ─► ...
%
%      sau:    <nguon>/1 ─────────► WD_Switch/3 ─► Manual Switch1/1 ─► ...
%              WP_Kw/1 ──────────► WD_Switch/1
%              WD_gate/1 ────────► WD_Switch/2     (wind_pred_on * wvalid)
%
%  Manual Switch1 la cong tac cau hinh co san (ESO vi tri bat/tat) ma
%  run_baseline dung. Chen TRUOC no nghia la o che do PID (dlf_hat = 0) bo
%  du doan cung bi bo qua - dung nhu phai the.
%
%  Nguon hien tai cua Manual Switch1/1 duoc DO ra tu day dien, khong doan
%  ten, va duoc ghi vao Description cua WD_Switch de lan Revert doc lai.
%  Do la bai hoc tu build_wind_series: lan chay lai, "nguon hien tai" chinh
%  la khoi cua script nay, va Revert theo no thi pha model.
%
%  ======================================================================
%  CONG TAC HOP LE - VI SAO PHAI NHAN VOI wvalid
%  ======================================================================
%  Truoc t_valid_from = 30 s cua so chua day nen khong co du doan, va
%  what_ts bang KHONG o doan do. Neu khong nhan voi wvalid thi bo dieu
%  khien se dung dlf_hat = 0 trong 30 s dau, tuc chay o che do khong bu
%  gio, roi moi nhay ve du doan. Cua so thong ke la [140, 200] nen no
%  khong vao bang, nhung mot buoc nhay 0 -> 0.8 N o t = 30 s la mot qua do
%  that va no de lai duoi trong trang thai bo quan sat.
%
%  Voi wvalid, doan dau chay dung duong quan sat cu.
%
%  ======================================================================
%  MOT HAN CHE PHAI GHI VAO BAI
%  ======================================================================
%  Day la phep THAY THE, khong phai phep tron. Bo quan sat uoc luong TOAN
%  BO nhieu tan thap - trong mo phong thi do dung bang gio, nhung tren may
%  bay that no con hut ca sai so mo hinh. Thay han no bang mot bo du doan
%  GIO la vut di kha nang do.
%
%  Phep do o muc 0.24 la phep do cua THAY THE, nen dung buoc nay de tai lap
%  no la dung. Nhung bai phai noi ro, va mot bien the "quan sat + du doan"
%  la viec dang lam sau.

opt = parse_opts(varargin);

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end

po = [mdl '/Position_Observers'];
sw = [po '/Manual Switch1'];
assert(getSimulinkBlockHandle(sw) > 0, ...
    'build_pa_mobadc: khong thay %s (cong tac dlf_hat).', sw);

B = {'WD_Switch','WD_on','WD_gate','WM_From','WM_Kw','WO_From','WO_Kw', ...
     'WSEL','WSEL_on','WD_obs_log'};

%% ---------------- nguon GOC cua Manual Switch1/1 ----------------
% Doc tu Description da ghi truoc; neu chua co thi do tu day dien.
src = orig_src(po, sw);
fprintf('Nguon GOC cua dlf_hat: %s\n', src);

%% ---------------- go cai cu (idempotent + Revert) ----------------
n = teardown(po, B, sw, src);
if n > 0, fprintf('Da go %d khoi cua lan truoc.\n', n); end
if opt.Revert
    if opt.Save, save_system(mdl); end
    fprintf('Da go PA-MOBADC. %s -> Manual Switch1/1 truc tiep.\n', src);
    return
end

%% ---------------- tien kiem ----------------
assert(getSimulinkBlockHandle([po '/WP_Kw']) > 0, ...
    ['build_pa_mobadc: chua co WP_Kw. Chay build_wind_predictor truoc ' ...
     '(W6.1), va verify_wind_predictor phai dat truoc khi noi vao vong.']);
assert(getSimulinkBlockHandle([po '/WP_valid']) > 0, ...
    'build_pa_mobadc: chua co WP_valid. Chay build_wind_predictor truoc.');

% Kiem BIEN trong base workspace, khong chi kiem khoi.
%
% build_wind_predictor da kiem what_ts/wvalid_ts/K_w, nhung ham nay them
% hai khoi doc wind_ts va w_oracle_ts va toi quen kiem chung. Hau qua:
% model dung xong, roi COMPILE hong voi "Invalid setting for parameter
% VariableName" - mot thong bao khong he chi ve wind_sim_load. Va vi khoi
% da nam trong model nen run_baseline cung hong theo, ke ca khi
% wind_series_on = 0.
%
% w_oracle_ts la bien MOI: mot phien lam viec da nap chuoi gio TRUOC khi
% no duoc them vao wind_sim_load se khong co no. Nen thong bao phai noi
% thang la "nap lai", chu khong phai "thieu bien".
miss = {};
for v = {'wind_ts','what_ts','wvalid_ts','w_oracle_ts','K_w'}
    if ~evalin('base', sprintf('exist(''%s'',''var'')', v{1}))
        miss{end+1} = v{1}; %#ok<AGROW>
    end
end
if ~isempty(miss)
    error('build_pa_mobadc:prereq', ...
        ['Thieu bien trong base workspace: %s\n\n' ...
         'Nap lai chuoi gio truoc khi dung:\n' ...
         '    wind_sim_load(''wind_real_t150.mat'')\n\n' ...
         'Neu phien nay da nap tu truoc: w_oracle_ts la bien MOI, chi co\n' ...
         'sau khi wind_sim_load duoc cap nhat. Phai nap LAI.'], ...
        strjoin(miss, ', '));
end
if ~evalin('base', 'exist(''wind_pred_on'',''var'')')
    assignin('base', 'wind_pred_on', 0);
    fprintf('wind_pred_on chua co -> dat = 0 (TAT).\n');
end
if ~evalin('base', 'exist(''wind_use_pred'',''var'')')
    assignin('base', 'wind_use_pred', 0);
    fprintf('wind_use_pred chua co -> dat = 0.\n');
end
fprintf(['\nBA cau hinh, va bai PHAI bao cao ca ba:\n' ...
         '  wind_pred_on=0                    MOBADC (bo quan sat)\n' ...
         '  wind_pred_on=1, wind_use_pred=0   cam bien gio 20 Hz, KHONG du doan\n' ...
         '  wind_pred_on=1, wind_use_pred=1   PA-MOBADC (cam bien + PI-MoE)\n' ...
         '  wind_pred_on=1, wind_use_pred=2   ORACLE: gio THAT tai t+tau\n' ...
         'Mac dinh la cau hinh dau, de lan chay ngay sau khi dung van la\n' ...
         'mot phep hoi quy.\n']);

%% ---------------- gan ----------------
add_block('simulink/Sources/Constant', [po '/WD_on'], ...
          'Value','wind_pred_on', 'Position',[230 930 330 960]);

add_block('simulink/Math Operations/Product', [po '/WD_gate'], ...
          'Inputs','2', 'Position',[380 925 410 960]);

add_block('simulink/Signal Routing/Switch', [po '/WD_Switch'], ...
          'Criteria','u2 >= Threshold', 'Threshold','0.5', ...
          'Position',[600 780 640 900]);

set_param([po '/WD_Switch'], 'Description', ['PA_MOBADC_ORIG_SRC=' src]);

% ==================================================================
% NHANH THU BA: CAM BIEN GIO NHUNG KHONG DU DOAN
% ==================================================================
% Day la doi chung ma neu thieu thi ca bai sai. Do duoc o doan #0:
% bo dieu khien cai thien 63.0% khi bat PA-MOBADC - nhung tren kenh luc,
% trong 63.4 diem phan tram do, CAM BIEN chiem 62.8 va DU DOAN chiem 0.62.
% Neu chi co hai cau hinh (quan sat / du doan) thi con so 63% se bi doc
% thanh cong cua PI-MoE, va do la sai su that.
%
% Nhanh nay la K_w * w_ZOH(t): mot cam bien gio 20 Hz HOAN HAO, giu bac
% thang, KHONG du doan. Chinh la dzoh cua diag_wind_channel.
%
% Doc CUNG bien wind_ts nhu WS_From nhung 'Interpolate','off': WS_From
% mang gio THAT vao plant nen phai noi suy tuyen tinh; nhanh nay la thu mot
% CAM BIEN doc duoc, va cam bien 20 Hz nhan qua thi chi giu duoc.
add_block('simulink/Sources/From Workspace', [po '/WM_From'], ...
          'VariableName','wind_ts', 'SampleTime','0', ...
          'Interpolate','off', 'OutputAfterFinalValue','Holding final value', ...
          'Position',[60 700 180 740]);

add_block('simulink/Math Operations/Gain', [po '/WM_Kw'], ...
          'Gain','K_w', 'Position',[230 705 270 735]);

% NHANH THU TU: ORACLE, gio THAT tai t+tau. Xem ghi chu trong wind_sim_load.
% No kiem chinh gia dinh nen tang cua ca khung du doan, va cho TRAN cua
% PI-MoE tren sai so bam.
add_block('simulink/Sources/From Workspace', [po '/WO_From'], ...
          'VariableName','w_oracle_ts', 'SampleTime','0', ...
          'Interpolate','off', 'OutputAfterFinalValue','Holding final value', ...
          'Position',[60 620 180 660]);

add_block('simulink/Math Operations/Gain', [po '/WO_Kw'], ...
          'Gain','K_w', 'Position',[230 625 270 655]);

add_block('simulink/Sources/Constant', [po '/WSEL_on'], ...
          'Value','wind_use_pred', 'Position',[230 1000 340 1030]);

% Multiport Switch, danh chi so tu 0: 0 = cam bien, 1 = PI-MoE, 2 = oracle.
add_block('simulink/Signal Routing/Multiport Switch', [po '/WSEL'], ...
          'Inputs','3', 'DataPortOrder','Zero-based contiguous', ...
          'Position',[400 620 440 830]);

% Dau do tren dau ra bo QUAN SAT, truoc cong tac. Khi wind_pred_on = 1 thi
% DLF_probe ghi tin hieu DANG DUNG (du doan), khong con la sai so bo quan
% sat nua - va toi da tung dan nham hai cai do trong mot phep kiem.
add_block('simulink/Sinks/To Workspace', [po '/WD_obs_log'], ...
          'VariableName','dlf_obs_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[600 960 700 990]);

%% ---------------- noi day ----------------
lh = get_param(sw, 'LineHandles');
if lh.Inport(1) > 0, delete_line(lh.Inport(1)); end

add_line(po, 'WM_From/1',     'WM_Kw/1',          'autorouting','on');
add_line(po, 'WO_From/1',     'WO_Kw/1',          'autorouting','on');
% Multiport Switch: cong 1 la DIEU KHIEN, roi cac cong du lieu theo thu tu
% 0,1,2 = cam bien / PI-MoE / oracle.
add_line(po, 'WSEL_on/1',     'WSEL/1',           'autorouting','on');
add_line(po, 'WM_Kw/1',       'WSEL/2',           'autorouting','on');
add_line(po, 'WP_Kw/1',       'WSEL/3',           'autorouting','on');
add_line(po, 'WO_Kw/1',       'WSEL/4',           'autorouting','on');

add_line(po, src,             'WD_Switch/3',      'autorouting','on');
add_line(po, 'WSEL/1',        'WD_Switch/1',      'autorouting','on');
add_line(po, 'WD_on/1',       'WD_gate/1',        'autorouting','on');
add_line(po, 'WP_valid/1',    'WD_gate/2',        'autorouting','on');
add_line(po, 'WD_gate/1',     'WD_Switch/2',      'autorouting','on');
add_line(po, 'WD_Switch/1',   'Manual Switch1/1', 'autorouting','on');
add_line(po, src,             'WD_obs_log/1',     'autorouting','on');

%% ---------------- kiem ----------------
fprintf('\n=== KIEM TRA ===\n');
ok = false;
try
    evalin('base','init_MOBADC_params');
catch err
    fprintf('  [FAIL] init_MOBADC_params: %s\n', err.message); return
end
cleanupObj = onCleanup(@() safe_term(mdl)); %#ok<NASGU>
try
    feval(mdl, [], [], [], 'compile');
    w1 = get_param([po '/WD_Switch'], 'CompiledPortWidths');
    ws2 = get_param([po '/WSEL'], 'CompiledPortWidths');
    c4 = all(ws2.Inport(2:4) == 3) && ws2.Inport(1) == 1;
    fprintf('  [%s] WSEL: dieu khien 1, ba nhanh du lieu deu 3\n', tern(c4));
    c1 = w1.Outport(1) == 3;
    c2 = w1.Inport(1) == 3 && w1.Inport(3) == 3;
    c3 = w1.Inport(2) == 1;
    fprintf('  [%s] dlf_hat be rong = %d (mong doi 3)\n', tern(c1), w1.Outport(1));
    fprintf('  [%s] hai nhanh du doan/quan sat deu 3 (%d, %d)\n', ...
            tern(c2), w1.Inport(1), w1.Inport(3));
    fprintf('  [%s] cong tac hop le be rong = %d (mong doi 1)\n', ...
            tern(c3), w1.Inport(2));
    ok = c1 && c2 && c3 && c4;
catch err
    fprintf('  [FAIL] compile: %s\n', err.message);
    % Go sach TRUOC khi tra ve. Ban dau toi chi return, va model o lai
    % trong bo nho voi cac khoi vua them - nen run_baseline chay sau do
    % cung hong theo, voi mot thong bao khong lien quan gi den nguyen nhan.
    clear cleanupObj
    teardown(po, B, sw, src);
    fprintf(['  Da go cac khoi vua them; model tro lai trang thai truoc do.\n' ...
             '  Kiem base workspace (wind_sim_load) roi chay lai.\n']);
    return
end
clear cleanupObj

if opt.Save && ok
    save_system(mdl);
    fprintf('  Da ghi %s.slx\n', mdl);
elseif opt.Save
    fprintf('  KHONG ghi: kiem tra hong.\n');
end

fprintf('\nBuoc tiep theo - THEO DUNG THU TU NAY:\n');
fprintf(['  assignin(''base'',''wind_pred_on'',0);\n' ...
         '  assignin(''base'',''wind_series_on'',0); run_baseline\n' ...
         '        %% 4 so PHAI khong doi: cong tac tat = duong cu\n']);
fprintf('  verify_pa_mobadc(''wind_real_t150.mat'')\n');
fprintf('        %% kiem cong tac, roi doi chieu voi so cua muc 0.24\n');
end


%% =====================================================================
function n = teardown(po, B, sw, src)
%TEARDOWN  Go cac khoi cua ham nay va noi lai nguon goc vao cong tac.
n = 0;
for i = 1:numel(B)
    b = [po '/' B{i}];
    if getSimulinkBlockHandle(b) > 0
        lh = get_param(b, 'LineHandles');
        for q = [lh.Inport(:); lh.Outport(:)]'
            if q > 0, try delete_line(q); catch, end, end
        end
        delete_block(b); n = n + 1;
    end
end
if n > 0
    lh = get_param(sw, 'LineHandles');
    if lh.Inport(1) <= 0
        add_line(po, src, 'Manual Switch1/1', 'autorouting','on');
    end
end
end

function s = orig_src(po, sw)
%ORIG_SRC  Nguon GOC cua Manual Switch1/1: doc Description truoc, do sau.
%
%  Bai hoc tu build_wind_series: o lan chay lai, nguon HIEN TAI cua cong
%  tac chinh la WD_Switch cua script nay, va Revert theo no thi noi cong
%  tac vao mot khoi vua bi xoa.
wd = [po '/WD_Switch'];
if getSimulinkBlockHandle(wd) > 0
    d = get_param(wd, 'Description');
    k = strfind(d, 'PA_MOBADC_ORIG_SRC=');
    if ~isempty(k)
        s = strtrim(d(k+19:end));
        nl = find(s == newline, 1);
        if ~isempty(nl), s = s(1:nl-1); end
        if ~isempty(s), return, end
    end
end
lh = get_param(sw, 'LineHandles');
assert(lh.Inport(1) > 0, ...
    'build_pa_mobadc: Manual Switch1/1 khong co day vao - model khac gia dinh.');
sb = get_param(lh.Inport(1), 'SrcBlockHandle');
sp = get_param(lh.Inport(1), 'SrcPortHandle');
nm = get_param(sb, 'Name');
pn = get_param(sp, 'PortNumber');
assert(~strcmp(nm, 'WD_Switch'), ...
    ['build_pa_mobadc: nguon hien tai la WD_Switch cua chinh script nay va\n' ...
     'Description khong doc duoc. Chay build_pa_mobadc(''Revert'',true) roi thu lai.']);
s = sprintf('%s/%d', nm, pn);
end

function s = tern(c), if c, s = 'OK '; else, s = 'SAI'; end, end

function safe_term(mdl)
try
    if ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
        feval(mdl, [], [], [], 'term');
    end
catch
end
end

function opt = parse_opts(args)
opt = struct('Revert', false, 'Save', true);
for i = 1:2:numel(args)
    opt.(validatestring(args{i}, fieldnames(opt))) = args{i+1};
end
end
