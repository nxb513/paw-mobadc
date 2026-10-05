function build_wind_series(varargin)
%BUILD_WIND_SERIES  Thay luc gio HANG SO bang chuoi theo thoi gian. Buoc W6.0.
%
%   wind_sim_load('wind_sim_t150.mat')   % nap du lieu vao base workspace
%   build_wind_series                    % dung / dung lai (idempotent)
%   build_wind_series('Revert', true)    % go het, tra model ve truoc do
%   build_wind_series('Save',  false)    % dung nhung khong ghi de .slx
%
%  ======================================================================
%  VI SAO BUOC NAY LA NUT CHAN
%  ======================================================================
%  disturbance_generator.m cho:
%      d_lf = wind_amp*[cos(40deg); sin(40deg); 0];
%  tuc mot luc HANG SO. Voi gio hang so thi persistence la hoan hao va MOI
%  bo du doan deu vo nghia theo cau tao. Khong the do duoc bat cu dieu gi ve
%  PI-MoE tren mo hinh chua sua.
%
%  ======================================================================
%  CHEN O DAU
%  ======================================================================
%      truoc:  Dist_Gen/2 ─────────────────────────────► (dich cu)
%
%      sau:    Dist_Gen/2 ──────────────► WS_Switch/3 ──► (dich cu)
%                                            ▲  ▲
%              WS_From ─► WS_Kw ─────────────┘  │
%                                          WS_on (wind_series_on)
%
%  Khoi disturbance_generator KHONG BI DONG VAO. Do la dam bao manh nhat co
%  the cho viec wind_series_on = 0 tai lap baseline: khong phai "cong thuc
%  tuong duong" ma la dung khoi cu, dung duong cu - dung chuan ma WIRING.md
%  da dat ra cho payload_model = 0.
%
%  ======================================================================
%  TU DO DUONG DAY, KHONG DOAN TEN
%  ======================================================================
%  Script nay duoc viet ma KHONG mo duoc baseline1.slx (may soan khong co
%  MATLAB). Nen no khong gia dinh dich cua Dist_Gen/2 la khoi nao: no DO
%  duong day hien co roi noi lai dung cac dich do. Neu khong tim thay thi
%  dung han voi thong bao ro, chu khong doan.
%
%  ======================================================================
%  ANH XA GIO -> LUC
%  ======================================================================
%  Dung khoi Gain voi he so K_w, va K_w duoc dat vao base workspace boi
%  wind_sim_load() goi wind_to_force([]) - MOT nguon su that duy nhat.
%
%  Khi doi sang luc can PHI TUYEN ve sau: thay WS_Kw bang mot khoi
%  MATLAB Function nhan (w, v_uav). Phia Python khong phai sua gi, vi no chi
%  xuat VAN TOC gio. Xem docs/devlog/W6_INTEGRATION.md muc 0.2.

opt = parse_opts(varargin);

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();

if ~bdIsLoaded(mdl), load_system(mdl); end

%% ---------------- Tim khoi nguon nhieu va cong d_lf ----------------
[dis, gen, port] = find_dlf_source(mdl);
fprintf('Nguon d_lf: %s   (cong ra %d)\n', gen, port);

dst = original_dest(dis, gen, port);
fprintf('Dich GOC cua d_lf: %s\n', strjoin(dst, ', '));

%% ---------------- Go bo thu cu (idempotent + Revert) ----------------
% dst duoc chot TRUOC teardown va la dich GOC, khong phai dich hien tai.
% Loi da xay ra that: lan chay lai, dich hien tai cua Dist_Gen/2 la
% WS_Switch/3 (khoi cua chinh script nay), teardown xoa no, roi relink noi
% vao mot khoi khong con ton tai -> d_lf mat duong, G_d_lf mat nguon.
n_removed = teardown(dis);
if n_removed > 0
    fprintf('Da go %d khoi cua lan dung truoc.\n', n_removed);
end

if opt.Revert
    relink(dis, gen, port, dst);
    if opt.Save, save_system(mdl); end
    fprintf('\nDa tra model ve truoc do. %s/%d -> dich cu truc tiep.\n', ...
            gen, port);
    return
end

%% ---------------- Tien kiem dieu kien tien quyet ----------------
% Kiem TRUOC khi sua model, khong phai o buoc compile sau khi da sua.
%
% baseline1.slx da commit van con khoi Constant 'ta' (Value = amp_tau) va ban
% disturbance_generator 5 doi so. init_MOBADC_params khong con khai bao
% amp_tau nua, nen model khong compile duoc cho den khi remove_amp_tau chay.
% Chinh remove_amp_tau.m ghi dieu do trong phan dau cua no:
%     "CHAY CAI NAY TRUOC KHI CHAY run_baseline ... run_baseline se dung han.
%      Do la co y."
% Day KHONG phai loi cua script nay, nhung neu de no lo ra o buoc compile thi
% mat mot vong lap ma khong hieu tai sao.
if getSimulinkBlockHandle([dis '/ta']) > 0
    error('build_wind_series:prereq', ...
      ['Model van con khoi Constant ''%s/ta'' (Value = amp_tau), va\n' ...
       'init_MOBADC_params khong con khai bao amp_tau -> model khong\n' ...
       'compile duoc. Day la dieu kien tien quyet co san, khong lien quan\n' ...
       'den chuoi gio.\n\n' ...
       'Chay theo thu tu:\n' ...
       '    remove_amp_tau        %% go ta + nap ban 4 doi so\n' ...
       '    sync_eml_blocks       %% phai bao khop\n' ...
       '    build_wind_series     %% roi moi chay lai cai nay\n'], dis);
end

%% ---------------- Khoi moi ----------------
% From Workspace: NOI SUY TUYEN TINH giua cac mau 20 Hz. Bo giai ode4 chay o
% 1e-3 nen phai noi suy cach nao do; tuyen tinh la tai dung tron nhat cua gio
% lien tuc ben duoi. ZOH se them mot bac thang 20 Hz KHONG co trong vat ly.
add_block('simulink/Sources/From Workspace', [dis '/WS_From'], ...
          'VariableName','wind_ts', 'SampleTime','0', ...
          'Interpolate','on', 'OutputAfterFinalValue','Holding final value', ...
          'Position',[60 400 180 440]);

add_block('simulink/Math Operations/Gain', [dis '/WS_Kw'], ...
          'Gain','K_w', 'Position',[230 405 270 435]);

add_block('simulink/Sources/Constant', [dis '/WS_on'], ...
          'Value','wind_series_on', 'Position',[230 470 330 500]);

add_block('simulink/Signal Routing/Switch', [dis '/WS_Switch'], ...
          'Criteria','u2 >= Threshold', 'Threshold','0.5', ...
          'Position',[380 380 420 480]);

% Ghi dich GOC vao chinh khoi, de lan Revert sau doc lai duoc thay vi phai
% suy ra tu day dien. Tu suy ra van con lam du phong, nhung ghi thang thi
% khong the sai.
set_param([dis '/WS_Switch'], 'Description', ...
          ['WIND_SERIES_ORIG_DST=' strjoin(dst, ';')]);

add_block('simulink/Sinks/To Workspace', [dis '/WS_dlf_log'], ...
          'VariableName','dlf_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[470 520 560 550]);

%% ---------------- Noi day ----------------
% Cat duong cu TRUOC, roi noi lai qua cong tac.
cut_dlf_lines(dis, gen, port);

add_line(dis, 'WS_From/1',  'WS_Kw/1',     'autorouting','on');
add_line(dis, 'WS_Kw/1',    'WS_Switch/1', 'autorouting','on');
add_line(dis, 'WS_on/1',    'WS_Switch/2', 'autorouting','on');
add_line(dis, sprintf('%s/%d', gen, port), 'WS_Switch/3', 'autorouting','on');
for i = 1:numel(dst)
    add_line(dis, 'WS_Switch/1', dst{i}, 'autorouting','on');
end
add_line(dis, 'WS_Switch/1', 'WS_dlf_log/1', 'autorouting','on');

%% ---------------- Kiem tra ----------------
fprintf('\n=== KIEM TRA SAU KHI DUNG ===\n');
ok = compile_check(mdl, dis);

% KHONG ghi khi compile hong. build_payload_predictor.m ghi vo dieu kien -
% do la mot khiem khuyet cua no ma toi da chep lai, va no da lam ghi mot
% model khong compile duoc xuong dia. remove_amp_tau.m lam dung: no bao loi
% TRUOC khi ghi. Theo cach do.
if opt.Save && ok
    save_system(mdl);
    fprintf('Da ghi %s\n', [mdl '.slx']);
elseif opt.Save
    fprintf(['KHONG ghi: compile hong. Model dang mo o trang thai da sua;\n' ...
             'sua loi roi chay lai, hoac build_wind_series(''Revert'',true).\n']);
else
    fprintf('KHONG ghi (Save = false). Model dang mo o trang thai da sua.\n');
end

fprintf('\nBuoc tiep theo:\n');
if ok
    fprintf('  verify_wind_force(''wind_sim_t150.mat'')   %% 14 phep\n');
    fprintf('  wind_sim_load(''wind_sim_t150.mat'')       %% nap workspace\n');
    fprintf('  %% wind_series_on = 0 PHAI tai lap run_baseline TUNG CHU SO:\n');
    fprintf('  assignin(''base'',''wind_series_on'',0); run_baseline\n');
else
    fprintf('  Sua loi compile o tren truoc da.\n');
end
end


%% =====================================================================
function [dis, gen, port] = find_dlf_source(mdl)
%FIND_DLF_SOURCE  Do khoi disturbance_generator va cong d_lf cua no.
%
%  d_lf la dau ra thu HAI cua disturbance_generator:
%      function [d_mf_sin, d_lf, d_ltau] = disturbance_generator(...)
%  Neu chu ky ham doi thi con so 2 nay sai, nen no duoc KIEM lai bang so cong
%  ra chu khong tin suong.
port = 2;
b = find_system(mdl, 'LookUnderMasks','all', 'FollowLinks','on', ...
                'RegExp','on', 'BlockType','SubSystem', 'Name','Dist_?Gen.*');
if isempty(b)
    % Du phong: tim theo ma nguon cua khoi MATLAB Function.
    b = find_system(mdl, 'LookUnderMasks','all', 'FollowLinks','on', ...
                    'BlockType','SubSystem');
    keep = false(size(b));
    for i = 1:numel(b)
        try
            ch = find(sfroot, '-isa','Stateflow.EMChart', 'Path', b{i});
            keep(i) = ~isempty(ch) && ...
                      contains(ch(1).Script, 'disturbance_generator');
        catch
        end
    end
    b = b(keep);
end
assert(~isempty(b), ['build_wind_series: khong tim thay khoi ' ...
    'disturbance_generator trong %s.'], mdl);
assert(numel(b) == 1, ['build_wind_series: tim thay %d khoi ung vien, ' ...
    'khong biet chon cai nao:\n  %s'], numel(b), strjoin(b, sprintf('\n  ')));

full = b{1};
p = get_param(full, 'Ports');
assert(p(2) >= port, ['build_wind_series: %s chi co %d cong ra, ' ...
    'khong co cong %d. Chu ky disturbance_generator da doi.'], ...
    full, p(2), port);

k   = strfind(full, '/');
dis = full(1:k(end)-1);
gen = full(k(end)+1:end);
end


function dst = original_dest(dis, gen, port)
%ORIGINAL_DEST  Dich GOC cua d_lf - tuc dich khi CHUA co chuoi gio.
%
%  Ba duong, theo thu tu tin cay giam dan:
%    1. Doc lai tu Description cua WS_Switch (ghi luc dung).
%    2. Do day dien hien tai, va neu no di vao WS_* thi di XUYEN QUA.
%    3. Dung han voi huong dan khoi phuc.
sw = [dis '/WS_Switch'];

% --- 1. da ghi san ---
if getSimulinkBlockHandle(sw) > 0
    d = get_param(sw, 'Description');
    tok = regexp(d, 'WIND_SERIES_ORIG_DST=(.*)', 'tokens', 'once');
    if ~isempty(tok) && ~isempty(strtrim(tok{1}))
        dst = strsplit(strtrim(tok{1}), ';');
        fprintf('  (dich goc doc tu Description cua WS_Switch)\n');
        return
    end
end

% --- 2. do day dien, di xuyen qua khoi cua chinh script nay ---
dst = {};
lh = get_param([dis '/' gen], 'LineHandles');
if numel(lh.Outport) >= port && lh.Outport(port) > 0
    dst = walk(lh.Outport(port), {});
end
if any(startsWith(dst, 'WS_'))
    % Da ap dung roi: dich that nam sau WS_Switch/1, bo khoi ghi nhat ky.
    out = {};
    if getSimulinkBlockHandle(sw) > 0
        lsw = get_param(sw, 'LineHandles');
        if numel(lsw.Outport) >= 1 && lsw.Outport(1) > 0
            out = walk(lsw.Outport(1), {});
        end
    end
    dst = out(~startsWith(out, 'WS_'));
    if ~isempty(dst)
        fprintf('  (dich goc suy ra bang cach di xuyen qua WS_Switch)\n');
    end
end
dst = dst(~startsWith(dst, 'WS_'));

% --- 3. chiu ---
if isempty(dst)
    error('build_wind_series:noDest', ...
      ['Khong suy duoc dich GOC cua %s/%d.\n\n' ...
       'Neu day la hau qua cua mot lan Revert hong thi model dang o trang\n' ...
       'thai d_lf khong noi vao dau. Khoi phuc tu git:\n\n' ...
       '    bdclose(''baseline1'')\n' ...
       '    !git checkout -- baseline1.slx\n' ...
       '    build_wind_series\n'], gen, port);
end
end

function dst = walk(lineh, dst)
%WALK  Di het cay duong (co the co nhanh) de lay moi khoi dich.
d = get_param(lineh, 'DstBlockHandle');
for i = 1:numel(d)
    if d(i) > 0
        nm = get_param(d(i), 'Name');
        pn = get_param(lineh, 'DstPortHandle');
        num = get_param(pn(min(i, numel(pn))), 'PortNumber');
        dst{end+1} = sprintf('%s/%d', nm, num); %#ok<AGROW>
    end
end
ch = get_param(lineh, 'LineChildren');
for i = 1:numel(ch)
    dst = walk(ch(i), dst);
end
end


function cut_dlf_lines(dis, gen, port)
lh = get_param([dis '/' gen], 'LineHandles');
if numel(lh.Outport) >= port && lh.Outport(port) > 0
    delete_line(lh.Outport(port));
end
end


function relink(dis, gen, port, dst)
% Kiem khoi dich CON TON TAI truoc khi noi. Neu khong thi bao ro thay vi de
% add_line nem mot loi kho doc - va nhat la thay vi de model o trang thai
% d_lf khong noi vao dau, dung cai da xay ra.
for i = 1:numel(dst)
    nm = strtok(dst{i}, '/');
    if getSimulinkBlockHandle([dis '/' nm]) <= 0
        error('build_wind_series:destGone', ...
          ['Dich goc ''%s'' khong con trong %s.\n' ...
           'Khoi phuc tu git:\n' ...
           '    bdclose(''baseline1'')\n' ...
           '    !git checkout -- baseline1.slx\n'], nm, dis);
    end
end
cut_dlf_lines(dis, gen, port);
for i = 1:numel(dst)
    add_line(dis, sprintf('%s/%d', gen, port), dst{i}, 'autorouting','on');
end
end


%% =====================================================================
function n = teardown(dis)
n = 0;
names = {'WS_Switch','WS_dlf_log','WS_on','WS_Kw','WS_From'};
for i = 1:numel(names)
    b = [dis '/' names{i}];
    if getSimulinkBlockHandle(b) > 0, drop_lines(b); end
end
for i = 1:numel(names)
    b = [dis '/' names{i}];
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
function ok = compile_check(mdl, dis)
ok = false;
try
    evalin('base','init_MOBADC_params');
catch err
    fprintf('  [FAIL] init_MOBADC_params loi: %s\n', err.message);
    return
end
% Hai bien nay do wind_sim_load() dat. Neu chua nap thi dat tam de compile
% duoc - nhung KHONG duoc chay sim voi gia tri tam.
for v = {'K_w','wind_series_on'}
    if ~evalin('base', sprintf('exist(''%s'',''var'')', v{1}))
        assignin('base', v{1}, 0);
        fprintf('  [luu y] %s chua co - dat tam = 0 de compile.\n', v{1});
    end
end
if ~evalin('base','exist(''wind_ts'',''var'')')
    assignin('base','wind_ts', struct('time',[0;1], ...
             'signals',struct('values',zeros(2,3),'dimensions',3)));
    fprintf('  [luu y] wind_ts chua co - dat tam de compile.\n');
end

cleanupObj = onCleanup(@() safe_term(mdl)); %#ok<NASGU>
try
    feval(mdl, [], [], [], 'compile');
catch err
    fprintf('  [FAIL] compile loi:\n    %s\n', err.message);
    % Noi ro loi o khoi CUA AI. Khoi cua script nay deu ten WS_*; neu ten
    % trong thong bao khong phai WS_* thi loi co san tu truoc, va di sua
    % chuoi gio se khong bao gio tim ra.
    m = regexp(err.message, '''([^'']*)''', 'tokens', 'once');
    if ~isempty(m)
        [~, nm] = fileparts(m{1});
        if isempty(regexp(nm, '^WS_', 'once'))
            fprintf(['    -> Khoi ''%s'' KHONG phai cua script nay (khoi cua\n' ...
                     '       no deu ten WS_*). Loi nay co san tu truoc.\n' ...
                     '       Neu la ''ta'': chay remove_amp_tau.\n'], nm);
        end
    end
    return
end

w = get_param([dis '/WS_Switch'], 'CompiledPortWidths');
good = (w.Outport(1) == 3);
if good, v = 'OK'; else, v = '*** SAI ***'; end
fprintf('  [%s] WS_Switch be rong dau ra = %d (mong doi 3)\n', ...
        v, w.Outport(1));
fprintf('  [OK]   compile sach\n');
ok = good;
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
