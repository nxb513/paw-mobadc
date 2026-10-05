function build_payload_pendulum(varargin)
%BUILD_PAYLOAD_PENDULUM  Tu dong dau day con lac tai treo vao baseline1.slx.
%
%  LUU Y: con lac DA CO SAN trong baseline1.slx da commit. Script nay chi can
%  khi ban dung lai model tu mot ban baseline sach. Chay no tren model hien
%  tai la go het roi dung lai y nguyen (idempotent) - vo hai nhung khong can.
%
%   build_payload_pendulum                  % dung / dung lai (idempotent)
%   build_payload_pendulum('Revert', true)  % go het, tra model ve baseline
%   build_payload_pendulum('Save',  false)  % dung nhung khong ghi de .slx
%
%  ------------------------------------------------------------------
%  CAI GI DUOC THEM, VA TAI SAO CHI CO THE NHIEU
%  ------------------------------------------------------------------
%  Model dinh tuyen tin hieu bang Goto/From voi TagVisibility = 'global'.
%  Nhieu tai di theo tag 'd_mf': mot Goto duy nhat trong Disturbances, hai
%  From o UAV_Plant va Logging_Metrics.
%
%  Nghia la KHONG phai rewire gi ca. Chi doi cai gi NUOI Goto do:
%
%     truoc:  Dist_Gen/1 ────────────────────────────► G_d_mf (tag d_mf)
%
%     sau:    Dist_Gen/1 ──────────────────► Switch/3 ─► G_d_mf (tag d_mf)
%                                              ▲  ▲
%             Payload_Pendulum ────────────────┘  │
%                    ▲                            │
%             Memory ┘                     payload_model
%                    ▲
%             Selector(1:2)
%                    ▲
%             From nu_dot  ◄── Goto moi trong UAV_Plant tren Trans_4a/1
%
%  KHOI disturbance_generator KHONG BI DONG VAO. Khong doi mot ky tu nao.
%  Do la dam bao manh nhat co the cho viec payload_model = 0 tai lap baseline:
%  khong phai "cong thuc tuong tu" ma la DUNG khoi cu, dung duong cu.
%
%  Tham so (m_p, L, zeta_p, g, payload_z_on) di vao bang khoi Constant chu
%  khong phai Scope = Parameter, dung kieu ma baseline dang lam o moi noi:
%  Disturbances dung pa/ps/wa/ta, UAV_Plant dung m_/g_/Ix/Iy/Iz.
%
%  ------------------------------------------------------------------
%  VONG LAP DAI SO
%  ------------------------------------------------------------------
%  d_mf phu thuoc gia toc UAV qua so hang a*sin(theta) trong luc cang, ma
%  gia toc UAV lai phu thuoc d_mf. Khoi Memory tren gia toc pha vong lap
%  do: con lac an gia toc cua buoc truoc.
%
%  Da kiem bang python/verify_pendulum_block.py (chay khong can MATLAB): tre
%  mot buoc doi ket qua 0.004%, ha FixedStep xuong 0.5 ms doi 0.003%. Do loi
%  vong dai so m_p*sin^2(th)/m ~ 0.08 << 1 nen vong hoi tu nhanh. Ket thuc
%  script co mot buoc compile de bat loi vong lap dai so con sot neu co.
%  (Con so 0.18%/0.011% ghi o ban truoc khong co script nao sinh ra - gio da
%   co, va no bao thu hon thuc te.)
%
%  ------------------------------------------------------------------
%  AN TOAN
%  ------------------------------------------------------------------
%  * Lan chay dau tao ban sao nguyen ve baseline1_baseline_backup.slx va
%    KHONG BAO GIO ghi de no. Do la duong lui cuoi cung.
%  * Chay lai nhieu lan khong sao: script go het thu cua lan truoc roi dung
%    lai tu dau.
%  * 'Revert' tra model ve dung trang thai baseline ma khong can ban sao.

opt = parse_opts(varargin);

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();

mdl_file = fullfile(here, [mdl '.slx']);
assert(exist(mdl_file,'file') == 4 || exist(mdl_file,'file') == 2, ...
       'Khong thay %s', mdl_file);

require_block_sources(here, {'payload_pendulum_derivative', ...
                             'payload_pendulum_output'});

% Ban sao nguyen, chi tao mot lan.
bak = fullfile(here, [mdl '_baseline_backup.slx']);
if ~exist(bak, 'file')
    copyfile(mdl_file, bak);
    fprintf('Da tao ban sao nguyen: %s\n', [mdl '_baseline_backup.slx']);
else
    fprintf('Ban sao nguyen da co: %s (khong ghi de)\n', [mdl '_baseline_backup.slx']);
end

if ~bdIsLoaded(mdl), load_system(mdl); end

dist = [mdl '/Disturbances'];
uav  = [mdl '/UAV_Plant'];
pend = [dist '/Payload_Pendulum'];

%% ---------------- Go bo thu cu (idempotent + Revert) ----------------
n_removed = teardown(mdl, dist, uav, pend);
if n_removed > 0
    fprintf('Da go %d khoi cua lan dung truoc.\n', n_removed);
end

if opt.Revert
    relink_baseline(dist);
    if opt.Save, save_system(mdl); end
    fprintf('\nDa tra model ve baseline. d_mf = Dist_Gen/1 truc tiep.\n');
    return
end

% Giai phong cong vao cua G_d_mf. Sau buoc nay Switch se nuoi no thay cho
% Dist_Gen. Neu bo dong nay thi add_line ben duoi bao "port already
% connected", vi cong vao cua Goto chi nhan mot duong.
free_goto_input(dist);

%% ---------------- UAV_Plant: xuat nu_dot ra tag global ----------------
% Trans_4a la khoi translational_dynamics; output 1 la nu_dot (PropagatedSignals
% trong model da ghi dung ten do). Them mot nhanh Goto, khong dong vao
% duong Trans_4a/1 -> Int_nu dang co.
add_block('simulink/Signal Routing/Goto', [uav '/PL_G_nu_dot'], ...
          'GotoTag','nu_dot', 'TagVisibility','global', ...
          'Position',[700 190 790 220]);
add_line(uav, 'Trans_4a/1', 'PL_G_nu_dot/1', 'autorouting','on');

%% ---------------- Disturbances: duong gia toc ----------------
add_block('simulink/Signal Routing/From', [dist '/PL_F_nu_dot'], ...
          'GotoTag','nu_dot', 'TagVisibility','global', ...
          'Position',[40 400 150 430]);

add_block('simulink/Signal Routing/Selector', [dist '/PL_Sel_xy'], ...
          'NumberOfDimensions','1', 'IndexMode','One-based', ...
          'IndexOptions','Index vector (dialog)', 'Indices','[1 2]', ...
          'InputPortWidth','3', 'Position',[190 400 240 430]);

% *** Khoi pha vong lap dai so. Bo no di la Simulink bao Algebraic loop. ***
add_block('simulink/Discrete/Memory', [dist '/PL_Mem_a'], ...
          'InitialCondition','[0;0]', 'Position',[280 400 320 430]);

% Luc gio len tai. Giai doan 2.1 de 0; Giai doan 2.2 chi viec doi khoi nay
% thanh mot From, khong phai sua Payload_Pendulum.
add_block('simulink/Sources/Constant', [dist '/PL_F_wp'], ...
          'Value','[0;0]', 'Position',[190 460 320 490]);

%% ---------------- Disturbances: subsystem con lac ----------------
build_pendulum_subsystem(pend, here);

%% ---------------- Disturbances: switch + log ----------------
add_block('simulink/Sources/Constant', [dist '/PL_pm'], ...
          'Value','payload_model', 'Position',[560 470 660 500]);

add_block('simulink/Signal Routing/Switch', [dist '/PL_Switch'], ...
          'Criteria','u2 >= Threshold', 'Threshold','0.5', ...
          'Position',[700 400 740 500]);

add_block('simulink/Sinks/To Workspace', [dist '/PL_dmf_log'], ...
          'VariableName','dmf_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[790 540 880 570]);

add_block('simulink/Sinks/To Workspace', [dist '/PL_theta_log'], ...
          'VariableName','theta_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[790 620 880 650]);

%% ---------------- Noi day ----------------
add_line(dist, 'PL_F_nu_dot/1',    'PL_Sel_xy/1',        'autorouting','on');
add_line(dist, 'PL_Sel_xy/1',      'PL_Mem_a/1',         'autorouting','on');
add_line(dist, 'PL_Mem_a/1',       'Payload_Pendulum/1', 'autorouting','on');
add_line(dist, 'PL_F_wp/1',        'Payload_Pendulum/2', 'autorouting','on');

% Switch: 1 = khi dieu kien dung -> con lac; 3 = khi sai -> sin baseline.
add_line(dist, 'Payload_Pendulum/1', 'PL_Switch/1', 'autorouting','on');
add_line(dist, 'PL_pm/1',            'PL_Switch/2', 'autorouting','on');
add_line(dist, 'Dist_Gen/1',         'PL_Switch/3', 'autorouting','on');

add_line(dist, 'PL_Switch/1',        'G_d_mf/1',     'autorouting','on');
add_line(dist, 'PL_Switch/1',        'PL_dmf_log/1', 'autorouting','on');
add_line(dist, 'Payload_Pendulum/2', 'PL_theta_log/1','autorouting','on');

%% ---------------- Kiem tra ----------------
fprintf('\n=== KIEM TRA SAU KHI DUNG ===\n');
ok = compile_check(mdl, dist);

if opt.Save
    save_system(mdl);
    fprintf('Da ghi %s\n', [mdl '.slx']);
else
    fprintf('KHONG ghi (Save = false). Model dang mo o trang thai da sua.\n');
end

fprintf('\nBuoc tiep theo:\n');
if ok
    fprintf('  run_test4_payload                             %% mot L, bang chinh\n');
    fprintf('  run_test4_payload([0.8 1.0 1.2 1.445 1.8])    %% them bang quet L\n');
else
    fprintf('  Sua loi compile o tren truoc da.\n');
end
end


%% =====================================================================
function build_pendulum_subsystem(pend, here)
%BUILD_PENDULUM_SUBSYSTEM  Dung Payload_Pendulum tu dau.
%
%  Tach derivative va output thanh HAI khoi rieng la co y: dung kieu model
%  dang dung cho DO (do_derivative / do_output) va ESO, va no giu duong ra
%  khong co vong lap dai so.

add_block('built-in/Subsystem', pend, 'Position',[380 380 560 520]);
% 'built-in/Subsystem' tao subsystem RONG, khong co In1/Out1 mac dinh nen
% khong can go. Chi go phong khi phien ban Simulink tinh co tao san cap do -
% neu khong se dinh loi "Invalid Simulink object name: 'In1/1'".
if getSimulinkBlockHandle([pend '/In1']) > 0
    try delete_line(pend, 'In1/1', 'Out1/1'); catch, end
    delete_block([pend '/In1']);
end
if getSimulinkBlockHandle([pend '/Out1']) > 0
    delete_block([pend '/Out1']);
end

add_block('simulink/Sources/In1',  [pend '/a_uav'], 'Port','1', 'Position',[40  100 70  114]);
add_block('simulink/Sources/In1',  [pend '/F_wp'],  'Port','2', 'Position',[40  160 70  174]);

% Tham so vao bang Constant, dung kieu baseline (pa/ps/wa/ta, m_/g_/Ix...).
add_block('simulink/Sources/Constant', [pend '/PL_m_p'],   'Value','m_p',          'Position',[40 220 140 250]);
add_block('simulink/Sources/Constant', [pend '/PL_L'],     'Value','L',            'Position',[40 260 140 290]);
add_block('simulink/Sources/Constant', [pend '/PL_zeta'],  'Value','zeta_p',       'Position',[40 300 140 330]);
add_block('simulink/Sources/Constant', [pend '/PL_g'],     'Value','g',            'Position',[40 340 140 370]);
add_block('simulink/Sources/Constant', [pend '/PL_zon'],   'Value','payload_z_on', 'Position',[40 380 140 410]);

deriv = [pend '/pend_deriv'];
outb  = [pend '/pend_out'];
add_block('simulink/User-Defined Functions/MATLAB Function', deriv, 'Position',[260  60 420 320]);
add_block('simulink/User-Defined Functions/MATLAB Function', outb,  'Position',[620 200 780 400]);

% Mot nguon su that duy nhat: doc thang tu file .m trong simulink_blocks/.
set_eml_script(deriv, fileread(fullfile(here,'simulink_blocks','payload_pendulum_derivative.m')));
set_eml_script(outb,  fileread(fullfile(here,'simulink_blocks','payload_pendulum_output.m')));

% Port cua khoi MATLAB Function duoc suy ra tu chu ky ham. Kiem ngay o day
% de neu code trong simulink_blocks/ bi doi chu ky thi bao loi ro rang,
% thay vi mot loi add_line kho hieu o duoi.
assert_ports(deriv, 7, 1);   % xp, a_uav, F_wp, m_p, L, zeta_p, g
assert_ports(outb,  6, 1);   % xp, a_uav, m_p, L, g, payload_z_on

add_block('simulink/Continuous/Integrator', [pend '/Int_xp'], ...
          'InitialCondition','[0;0;0;0]', 'Position',[470 175 500 205]);

add_block('simulink/Sinks/Out1', [pend '/d_mf_pend'], 'Port','1', 'Position',[840 293 870 307]);
add_block('simulink/Sinks/Out1', [pend '/xp'],        'Port','2', 'Position',[840 400 870 414]);

% pend_deriv(xp, a_uav, F_wp, m_p, L, zeta_p, g)
add_line(pend, 'Int_xp/1',   'pend_deriv/1', 'autorouting','on');
add_line(pend, 'a_uav/1',    'pend_deriv/2', 'autorouting','on');
add_line(pend, 'F_wp/1',     'pend_deriv/3', 'autorouting','on');
add_line(pend, 'PL_m_p/1',   'pend_deriv/4', 'autorouting','on');
add_line(pend, 'PL_L/1',     'pend_deriv/5', 'autorouting','on');
add_line(pend, 'PL_zeta/1',  'pend_deriv/6', 'autorouting','on');
add_line(pend, 'PL_g/1',     'pend_deriv/7', 'autorouting','on');
add_line(pend, 'pend_deriv/1','Int_xp/1',    'autorouting','on');

% pend_out(xp, a_uav, m_p, L, g, payload_z_on)
add_line(pend, 'Int_xp/1',  'pend_out/1', 'autorouting','on');
add_line(pend, 'a_uav/1',   'pend_out/2', 'autorouting','on');
add_line(pend, 'PL_m_p/1',  'pend_out/3', 'autorouting','on');
add_line(pend, 'PL_L/1',    'pend_out/4', 'autorouting','on');
add_line(pend, 'PL_g/1',    'pend_out/5', 'autorouting','on');
add_line(pend, 'PL_zon/1',  'pend_out/6', 'autorouting','on');

add_line(pend, 'pend_out/1','d_mf_pend/1', 'autorouting','on');
add_line(pend, 'Int_xp/1',  'xp/1',        'autorouting','on');
end


%% =====================================================================
function set_eml_script(blkpath, code)
%SET_EML_SCRIPT  Nap code vao khoi MATLAB Function.
%  Cong port cua khoi duoc suy ra tu chu ky ham, nen phai nap code TRUOC
%  khi add_line, khong thi chua co port de noi.
ch = find(sfroot, '-isa','Stateflow.EMChart', 'Path', blkpath);
assert(~isempty(ch), 'Khong tim thay Stateflow.EMChart cho %s', blkpath);
ch(1).Script = code;
end


%% =====================================================================
function assert_ports(blk, n_in, n_out)
p = get_param(blk, 'Ports');
assert(p(1) == n_in && p(2) == n_out, ...
   ['%s co %d vao / %d ra, mong doi %d / %d.\n' ...
    'Chu ky ham trong simulink_blocks/ da doi. Sua lai so port mong doi ' ...
    'trong build_payload_pendulum, hoac tra chu ky ve nhu cu.'], ...
    blk, p(1), p(2), n_in, n_out);
end


%% =====================================================================
function n = teardown(mdl, dist, uav, pend)
%TEARDOWN  Go het thu script nay tung them. An toan khi chua co gi.
n = 0;
% Duong day truoc, roi moi den khoi.
for tgt = {[dist '/PL_Switch'], [dist '/PL_dmf_log'], [dist '/PL_theta_log'], ...
           [dist '/PL_Sel_xy'], [dist '/PL_Mem_a'], pend, ...
           [uav '/PL_G_nu_dot'], [dist '/PL_F_nu_dot'], [dist '/PL_F_wp'], ...
           [dist '/PL_pm']}
    b = tgt{1};
    if getSimulinkBlockHandle(b) > 0
        drop_lines(b);
    end
end
for tgt = {[dist '/PL_Switch'], [dist '/PL_dmf_log'], [dist '/PL_theta_log'], ...
           [dist '/PL_Sel_xy'], [dist '/PL_Mem_a'], pend, ...
           [uav '/PL_G_nu_dot'], [dist '/PL_F_nu_dot'], [dist '/PL_F_wp'], ...
           [dist '/PL_pm']}
    b = tgt{1};
    if getSimulinkBlockHandle(b) > 0
        delete_block(b);
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
function relink_baseline(dist)
%RELINK_BASELINE  Tra duong nhieu tai ve dung nhu baseline.
free_goto_input(dist);
add_line(dist, 'Dist_Gen/1', 'G_d_mf/1', 'autorouting','on');
end

function free_goto_input(dist)
%FREE_GOTO_INPUT  Xoa duong dang nuoi G_d_mf, neu co.
lh = get_param([dist '/G_d_mf'], 'LineHandles');
if lh.Inport(1) > 0
    delete_line(lh.Inport(1));
end
end


%% =====================================================================
function ok = compile_check(mdl, dist)
%COMPILE_CHECK  Compile model va doi chieu be rong tin hieu.
%  Day la cho bat loi vong lap dai so con sot, sai chieu vector, va bien
%  chua khai bao - truoc khi ton 200 giay mo phong.
ok = false;
try
    evalin('base','init_MOBADC_params');
catch err
    fprintf('  [FAIL] init_MOBADC_params loi: %s\n', err.message);
    return
end

cleanupObj = onCleanup(@() safe_term(mdl));
try
    feval(mdl, [], [], [], 'compile');
catch err
    fprintf('  [FAIL] compile loi:\n    %s\n', err.message);
    if contains(lower(err.message), 'algebraic')
        fprintf(['    -> Van con vong lap dai so. Kiem tra khoi PL_Mem_a co ' ...
                 'nam giua PL_Sel_xy va Payload_Pendulum khong.\n']);
    end
    return
end

want = struct('PL_Switch', 3, 'Payload_Pendulum', 3, 'PL_Mem_a', 2);
allok = true;
f = fieldnames(want);
for i = 1:numel(f)
    b = [dist '/' f{i}];
    w = get_param(b, 'CompiledPortWidths');
    got = w.Outport(1);
    good = (got == want.(f{i}));
    allok = allok && good;
    if good, v = 'OK'; else, v = '*** SAI ***'; end
    fprintf('  [%s] %-18s be rong dau ra = %d (mong doi %d)\n', ...
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