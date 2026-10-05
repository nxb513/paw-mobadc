function build_wind_predictor(varargin)
%BUILD_WIND_PREDICTOR  Nap d_wind_hat da tinh truoc vao model. Buoc W6.1.
%
%   wind_sim_load('wind_real_t150.mat')   % nap what_ts + wvalid_ts
%   build_wind_predictor                  % gan / gan lai (idempotent)
%   build_wind_predictor('Revert', true)  % go
%   build_wind_predictor('Save',  false)  % gan nhung khong ghi de .slx
%
%  ======================================================================
%  BUOC NAY CHUA NOI VAO BO DIEU KHIEN - VA DO LA CO Y
%  ======================================================================
%  W6.1 chi dua duong tin hieu d_wind_hat VAO model va do xem no co dung
%  bang K_w * w_hat cua Python hay khong, tung mau mot. Khong khoi nao cua
%  vong dieu khien doc no.
%
%  Ly do: neu dau vao PA-MOBADC roi moi do, thi khi bang W7 ra so nho ta se
%  khong biet la vi bo du doan yeu, hay vi mot loi can thoi gian / don vi /
%  noi suy o duong day. Tach ra thi moi loi chi co mot cho de nam.
%
%  Vi khong khoi nao doc no, run_baseline sau khi gan PHAI cho lai bon con
%  so khong xe dich mot chu so. Do la phep kiem cua chinh buoc nay.
%
%  ======================================================================
%  GIU BAC THANG - CHO DE SAI NHAT VA IM LANG NHAT
%  ======================================================================
%  WP_From dat 'Interpolate','off'. Noi suy tuyen tinh giua mau k va k+1
%  la dung w_hat_{k+1}, ma mau do chi CO SAN tai t_{k+1} > t: bo dieu khien
%  se doc mot du doan CHUA DUOC SINH RA. Khong cho nao bao loi, mo phong
%  chay binh thuong, va ket qua dep len mot cach gia tao.
%
%  Doi lap voi WS_From cua build_wind_series, khoi do PHAI noi suy tuyen
%  tinh: no mang gio THAT vao plant, va gio that thi lien tuc - bac thang
%  20 Hz la mot vat the khong co trong vat ly.
%
%  Hai khoi, hai cau hinh nguoc nhau, cung mot ly do: nhan qua.
%  verify_wind_predictor kiem ca hai bang cach doc lai cau hinh khoi.
%
%  ======================================================================
%  DAT O DAU
%  ======================================================================
%  Trong Position_Observers, canh Manual Switch1 - chinh cho ma W6.3 se
%  tron d_wind_hat vao duong d_lf_hat. Dat san o do de W6.3 chi con la mot
%  phep noi day, khong phai mot lan dung lai.
%
%  ======================================================================
%  TIN HIEU HOP LE
%  ======================================================================
%  Truoc t_valid_from (30 s) khong co du doan. WP_valid = 0 o doan do va 1
%  tu do tro di; wind_sim_load dat what_ts bang KHONG o doan do. W6.3 dung
%  WP_valid de chuyen ve duong DO thuong. Xem ghi chu trong wind_sim_load.m.

opt = parse_opts(varargin);

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end

po = [mdl '/Position_Observers'];
assert(getSimulinkBlockHandle(po) > 0, ...
    'build_wind_predictor: khong thay %s.', po);

B = {'WP_From','WP_Kw','WP_valid','WP_log','WP_vlog'};

%% ---- go cai cu (idempotent + Revert) ----
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
if n > 0, fprintf('Da go %d khoi cua lan truoc.\n', n); end
if opt.Revert
    if opt.Save, save_system(mdl); end
    fprintf('Da go duong d_wind_hat. Model tro lai nhu truoc.\n');
    return
end

%% ---- tien kiem: du lieu phai co trong base workspace ----
for v = {'what_ts','wvalid_ts','K_w'}
    if ~evalin('base', sprintf('exist(''%s'',''var'')', v{1}))
        error('build_wind_predictor:prereq', ...
            ['Chua co bien ''%s'' trong base workspace.\n' ...
             'Chay truoc:  wind_sim_load(''wind_real_t150.mat'')'], v{1});
    end
end

%% ---- gan ----
% 'Interpolate','off' = GIU BAC THANG. Xem phan dau ham.
add_block('simulink/Sources/From Workspace', [po '/WP_From'], ...
          'VariableName','what_ts', 'SampleTime','0', ...
          'Interpolate','off', 'OutputAfterFinalValue','Holding final value', ...
          'Position',[60 780 180 820]);

add_block('simulink/Math Operations/Gain', [po '/WP_Kw'], ...
          'Gain','K_w', 'Position',[230 785 270 815]);

add_block('simulink/Sources/From Workspace', [po '/WP_valid'], ...
          'VariableName','wvalid_ts', 'SampleTime','0', ...
          'Interpolate','off', 'OutputAfterFinalValue','Holding final value', ...
          'Position',[60 860 180 900]);

add_block('simulink/Sinks/To Workspace', [po '/WP_log'], ...
          'VariableName','wpred_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[330 785 420 815]);

add_block('simulink/Sinks/To Workspace', [po '/WP_vlog'], ...
          'VariableName','wvalid_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[230 865 320 895]);

add_line(po, 'WP_From/1',  'WP_Kw/1',  'autorouting','on');
add_line(po, 'WP_Kw/1',    'WP_log/1', 'autorouting','on');
add_line(po, 'WP_valid/1', 'WP_vlog/1','autorouting','on');

%% ---- kiem ----
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
    w1 = get_param([po '/WP_Kw'],    'CompiledPortWidths');
    w2 = get_param([po '/WP_valid'], 'CompiledPortWidths');
    c1 = w1.Outport(1) == 3;
    c2 = w2.Outport(1) == 1;
    fprintf('  [%s] d_wind_hat be rong = %d (mong doi 3)\n', ...
            ternary(c1,'OK ','SAI'), w1.Outport(1));
    fprintf('  [%s] wvalid be rong = %d (mong doi 1)\n', ...
            ternary(c2,'OK ','SAI'), w2.Outport(1));
    ok = c1 && c2;
catch err
    fprintf('  [FAIL] compile: %s\n', err.message); return
end
clear cleanupObj

ip = get_param([po '/WP_From'], 'Interpolate');
c3 = strcmpi(ip, 'off');
fprintf('  [%s] WP_From Interpolate = %s (PHAI la off - nhan qua)\n', ...
        ternary(c3,'OK ','SAI'), ip);
ok = ok && c3;

if opt.Save && ok
    save_system(mdl);
    fprintf('  Da ghi %s.slx\n', mdl);
elseif opt.Save
    fprintf('  KHONG ghi: kiem tra hong.\n');
end

fprintf('\nBuoc tiep theo:\n');
% Phai TAT chuoi gio truoc khi doi chieu expected_baseline. Ban dau toi ghi
% "run_baseline % 4 so PHAI khong doi" ngay sau wind_sim_load, tuc voi
% wind_series_on = 1: ca bon dong bao *** KHONG KHOP *** va no trong y het
% mot hoi quy vo, trong khi chi la plant dang chay chuoi gio. run_baseline
% gio tu bao dieu do, nhung chi dan o day phai dung tu dau.
fprintf(['  assignin(''base'',''wind_series_on'',0); run_baseline\n' ...
         '        %% 4 so PHAI khong doi - chua khoi nao doc d_wind_hat\n']);
fprintf('  wind_sim_load(''wind_real_t150.mat'')   %% bat lai chuoi gio\n');
fprintf('  verify_wind_predictor(''wind_real_t150.mat'')\n');
end


%% =====================================================================
function s = ternary(c,a,b), if c, s = a; else, s = b; end, end

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
