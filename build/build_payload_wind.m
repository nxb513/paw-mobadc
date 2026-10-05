function build_payload_wind(varargin)
%BUILD_PAYLOAD_WIND  Noi gio THAT vao cong F_wp cua khoi con lac.
%
%   build_payload_wind                  % dung / dung lai (idempotent)
%   build_payload_wind('Revert', true)  % tra PL_F_wp ve Constant [0;0]
%   build_payload_wind('Save',  false)  % dung nhung khong ghi de .slx
%
%  ======================================================================
%  DE LAM GI
%  ======================================================================
%  build_payload_pendulum de san cong F_wp voi ghi chu:
%
%     "Luc gio len tai. Giai doan 2.1 de 0; Giai doan 2.2 chi viec doi khoi
%      nay thanh mot From, khong phai sua Payload_Pendulum."
%
%  Day la Giai doan 2.2. Ham nay xoa Constant [0;0] va thay bang
%
%     wind_ts --> [chon truc x,y] --> Gain(K_wp) --> Switch(payload_wind_on)
%                                                        \__ Constant [0;0]
%
%  ======================================================================
%  LUAT LUC: TUYEN TINH, KHONG PHAI BINH PHUONG
%  ======================================================================
%     F_wp = K_wp * w_xy(t),   K_wp = payload_K_ratio * K_w
%
%  Khong dung 0.5*rho*Cd*A*v^2 du no "vat ly hon". Ca codebase dung luat
%  TUYEN TINH: K_w = 0.2 N/(m/s) suy ra o wind_to_force.m chinh la tuyen
%  tinh hoa cua luat binh phuong quanh V_ref = 5 m/s. Dung luat khac cho TAI
%  thi chenh lech giua hai kenh den tu LUAT LUC chu khong tu DONG HOC - ma
%  dong hoc moi la thu can do.
%
%  Con ly do dinh luong: U chay 3 -> 14 m/s qua 30 doan. Luat binh phuong
%  lam luc tren tai bien thien 22 lan trong khi luc tren UAV bien thien 4.7
%  lan. Chenh lech do ap dao moi hieu ung khac va no la san pham cua LUA
%  CHON chu khong cua he.
%
%  Giu luat nhat quan thi payload_K_ratio = K_wp/K_w CO nghia vat ly:
%       K = rho*Cd*A*V_ref   ->   K_wp/K_w = (Cd_p*A_p)/(Cd_uav*A_uav)
%  ty so DIEN TICH CAN HIEU DUNG. Tai 0.5 kg dang hop ~0.2 m (A ~ 0.04 m^2,
%  Cd ~ 1.0) so voi khung quadrotor (A ~ 0.05-0.10 m^2, Cd ~ 1.0-1.3) cho
%  ~0.3-0.8. Do la mot dai QUET, khong phai mot gia tri duoc chon.
%
%  ======================================================================
%  MAC DINH TAT - VA VI SAO DIEU DO QUAN TRONG
%  ======================================================================
%  payload_wind_on = 0 va payload_K_ratio = 0 => nhanh Switch tra [0;0],
%  DUNG BANG Constant cu, nen moi ket qua da co khong doi mot chu so nao.
%  Phai kiem bang run_baseline chu khong tin loi ham nay.
%
%  ======================================================================
%  NOI SUY: TUYEN TINH, GIONG WS_From
%  ======================================================================
%  Dung 'Interpolate','on' y het WS_From cua build_wind_series. Hai duong
%  phai thay CUNG mot gio; neu mot ben ZOH mot ben tuyen tinh thi chenh
%  lech giua kenh tai va kenh UAV co mot phan den tu cach noi suy, va khong
%  ai tach duoc phan do ra.

opt = struct('Revert', false, 'Save', true);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end
dist = [mdl '/Disturbances'];

% Kiem subsystem cha TRUOC. Neu duong dan sai thi assert duoi se bao "chua co
% Payload_Pendulum, chay build_payload_pendulum truoc" - mot thong bao SAI
% bao nguoi dung chay lai thu ho vua chay xong. Da xay ra that voi ten
% 'Disturbance_Generator'.
if getSimulinkBlockHandle(dist) <= 0
    b = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    b = cellfun(@(s) s(numel(mdl)+2:end), b, 'UniformOutput', false);
    error('build_payload_wind:subsys', ...
        ['Khong co subsystem ''%s''.\nCac subsystem cap 1 co that:%s'], ...
        dist, sprintf('\n    %s', b{:}));
end
assert(getSimulinkBlockHandle([dist '/Payload_Pendulum']) > 0, '%s', ...
    sprintf(['build_payload_wind: chua co Payload_Pendulum.\n' ...
             'Chay build_payload_pendulum truoc - cong F_wp nam trong do.']));

n = teardown(dist);
if n > 0, fprintf('Da go %d khoi cua lan dung truoc.\n', n); end

if opt.Revert
    add_block('simulink/Sources/Constant', [dist '/PL_F_wp'], ...
              'Value','[0;0]', 'Position',[190 460 320 490]);
    add_line(dist, 'PL_F_wp/1', 'Payload_Pendulum/2', 'autorouting','on');
    fprintf('Da tra PL_F_wp ve Constant [0;0].\n');
    if opt.Save, save_system(mdl); end
    return;
end

stub_vars();

%% ---------------- Khoi moi ----------------
add_block('simulink/Sources/From Workspace', [dist '/PW_From'], ...
          'VariableName','wind_ts', 'SampleTime','0', ...
          'Interpolate','on', 'OutputAfterFinalValue','Holding final value', ...
          'Position',[60 520 180 560]);

% Chi hai truc ngang: payload_pendulum_derivative nhan F_wp 2x1 (mot cho
% moi truc con lac). Truc z cua gio khong tac dung len goc lac.
add_block('simulink/Signal Routing/Selector', [dist '/PW_Sel_xy'], ...
          'NumberOfDimensions','1', 'IndexOptions','Index vector (dialog)', ...
          'Indices','[1 2]', 'InputPortWidth','3', ...
          'Position',[220 525 260 555]);

add_block('simulink/Math Operations/Gain', [dist '/PW_Kwp'], ...
          'Gain','payload_K_ratio*K_w', 'Position',[300 525 340 555]);

add_block('simulink/Sources/Constant', [dist '/PW_off'], ...
          'Value','[0;0]', 'Position',[300 600 340 630]);

add_block('simulink/Sources/Constant', [dist '/PW_on'], ...
          'Value','payload_wind_on', 'Position',[300 570 340 595]);

add_block('simulink/Signal Routing/Switch', [dist '/PW_Switch'], ...
          'Criteria','u2 >= Threshold', 'Threshold','0.5', ...
          'Position',[400 515 440 635]);

add_line(dist, 'PW_From/1',   'PW_Sel_xy/1', 'autorouting','on');
add_line(dist, 'PW_Sel_xy/1', 'PW_Kwp/1',    'autorouting','on');
add_line(dist, 'PW_Kwp/1',    'PW_Switch/1', 'autorouting','on');
add_line(dist, 'PW_on/1',     'PW_Switch/2', 'autorouting','on');
add_line(dist, 'PW_off/1',    'PW_Switch/3', 'autorouting','on');
add_line(dist, 'PW_Switch/1', 'Payload_Pendulum/2', 'autorouting','on');

%% ---------------- Kiem tra ----------------
fprintf('\n=== KIEM TRA SAU KHI DUNG ===\n');
evalin('base','init_MOBADC_params');
if ~compile_check(mdl, dist)
    teardown(dist);
    add_block('simulink/Sources/Constant', [dist '/PL_F_wp'], ...
              'Value','[0;0]', 'Position',[190 460 320 490]);
    add_line(dist, 'PL_F_wp/1', 'Payload_Pendulum/2', 'autorouting','on');
    error('build_payload_wind:compile', ...
          ['Compile that bai - da tra model ve nguyen trang.\n' ...
           'Khong ghi de .slx, nen file tren dia van sach.']);
end

% Khong ghi de neu compile hong: da co lan build_payload_predictor ghi de vo
% dieu kien va de lai mot .slx hong tren dia.
if opt.Save, save_system(mdl); fprintf('Da ghi %s.slx\n', mdl); end

fprintf(['\nBuoc tiep theo:\n' ...
         '  %% 1) HOI QUY - tat het, 4 so PHAI khong doi\n' ...
         '  assignin(''base'',''payload_wind_on'',0);\n' ...
         '  assignin(''base'',''payload_model'',0);\n' ...
         '  assignin(''base'',''predictor_on'',0);\n' ...
         '  assignin(''base'',''wind_series_on'',0); run_baseline\n' ...
         '  %% 2) kiem duong day + pho TRONG MODEL\n' ...
         '  verify_payload_wind\n' ...
         '  %% 3) quet regime (co lap kenh tai)\n' ...
         '  sweep_payload_regime\n']);
end


%% =====================================================================
function stub_vars()
%STUB_VARS  Dat bien de model compile duoc ngay ca khi chua nap gio.
%
% payload_wind_on = 0 va payload_K_ratio = 0: nhanh moi TAT hoan toan, model
% chay y het truoc khi co ham nay.
if ~evalin('base','exist(''payload_wind_on'',''var'')')
    assignin('base','payload_wind_on', 0);
    fprintf('  [luu y] payload_wind_on chua co - dat 0.\n');
end
if ~evalin('base','exist(''payload_K_ratio'',''var'')')
    assignin('base','payload_K_ratio', 0);
    fprintf('  [luu y] payload_K_ratio chua co - dat 0.\n');
end
if ~evalin('base','exist(''K_w'',''var'')')
    [~, kw] = wind_to_force([]);
    assignin('base','K_w', kw);
    fprintf('  [luu y] K_w chua co - dat %g.\n', kw);
end
if ~evalin('base','exist(''wind_ts'',''var'')')
    assignin('base','wind_ts', struct('time',[0;1], ...
                                      'signals',struct('values',zeros(2,3), ...
                                                       'dimensions',3)));
    fprintf('  [luu y] wind_ts chua co - dat tam de compile.\n');
end
end

function n = teardown(dist)
%TEARDOWN  Go het thu script nay tung them, VA ca Constant goc.
%
% Go ca PL_F_wp vi hai ben cung nuoi Payload_Pendulum/2 - de lai ca hai thi
% cong vao bi hai nguon.
n = 0;
tg = {[dist '/PW_Switch'], [dist '/PW_Kwp'], [dist '/PW_Sel_xy'], ...
      [dist '/PW_From'], [dist '/PW_on'], [dist '/PW_off'], ...
      [dist '/PL_F_wp']};
for i = 1:numel(tg)
    if getSimulinkBlockHandle(tg{i}) > 0, drop_lines(tg{i}); end
end
for i = 1:numel(tg)
    if getSimulinkBlockHandle(tg{i}) > 0
        delete_block(tg{i});  n = n + 1;
    end
end
end

function drop_lines(blk)
lh = get_param(blk, 'LineHandles');
for f = {'Inport','Outport'}
    v = lh.(f{1});
    for i = 1:numel(v)
        if v(i) > 0, try delete_line(v(i)); catch, end, end
    end
end
end

function ok = compile_check(mdl, dist)
ok = false;
try
    eval([mdl '([],[],[],''compile'');']);
    c = onCleanup(@() safe_term(mdl));
    w = get_param([dist '/PW_Switch'], 'CompiledPortWidths');
    fprintf('  [%s] PW_Switch     be rong dau ra = %d (mong doi 2)\n', ...
            tick(w.Outport(1) == 2), w.Outport(1));
    wk = get_param([dist '/PW_Kwp'], 'CompiledPortWidths');
    fprintf('  [%s] PW_Kwp        be rong dau ra = %d (mong doi 2)\n', ...
            tick(wk.Outport(1) == 2), wk.Outport(1));
    ok = (w.Outport(1) == 2) && (wk.Outport(1) == 2);
    fprintf('  [OK]   compile sach, khong co vong lap dai so\n');
catch err
    fprintf('  [LOI]  %s\n', err.message);
    safe_term(mdl);
end
end

function s = tick(b)
if b, s = 'OK'; else, s = 'LOI'; end
end

function safe_term(mdl)
try, eval([mdl '([],[],[],''term'');']); catch, end
end
