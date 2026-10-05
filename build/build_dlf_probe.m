function build_dlf_probe(varargin)
%BUILD_DLF_PROBE  Gan mot dau do ghi UOC LUONG GIO ma bo dieu khien dang dung.
%
%   build_dlf_probe                  % gan / gan lai (idempotent)
%   build_dlf_probe('Revert', true)  % go
%   build_dlf_probe('Save',  false)  % gan nhung khong ghi de .slx
%
%  ======================================================================
%  DE TRA LOI MOT CAU HOI CU THE
%  ======================================================================
%  "Dang bom gio that vao ma bo uoc luong van tot, vay can gi bo du doan?"
%
%  Cau hoi do dung, va no chua tra loi duoc vi ta chua tach hai thu:
%
%    e_est(t) = dlf_hat(t) - d(t)     bo quan sat dat duoc gi, KHONG co
%                                     cam bien gio (no suy tu chuyen dong UAV)
%    e_lag(t) = d(t) - d(t+tau)       persistence cua mot cam bien HOAN HAO
%
%  Sai so ma bo dieu khien THAT SU chiu la tong cua hai:
%    e_eff(t) = dlf_hat(t) - d(t+tau) = e_est + e_lag
%  vi luc lenh tai t chi xuat hien tren duong luc sau ~tau (nhanh payload do
%  duoc tau = 140 ms).
%
%  Neu e_est >> e_lag  -> nut that la KENH DO. Mot cam bien gio giup nhieu,
%                         va phan "du doan" chi la mot lop mong ben tren.
%  Neu e_lag >> e_est  -> nut that la DO TRE. Du doan dung la cach sua.
%
%  Khong do thi khong biet, va dung PA-MOBADC truoc roi do sau thi neu ket
%  qua nho se khong biet vi bo du doan yeu hay vi cho trong von da nho.
%
%  ======================================================================
%  CHI THEM MOT NHANH, KHONG DOI DAY NAO
%  ======================================================================
%  Dau do la mot khoi To Workspace mac them vao dau ra cua Manual Switch1
%  (duong d_lf_hat trong Position_Observers - chinh cong tac ma run_baseline
%  dung de bat/tat ESO vi tri). add_line tren mot dau ra DA NOI tao NHANH,
%  khong cat duong cu. Nen phep do nay khong the doi ket qua mo phong.
%
%  Kiem lai dieu do bang cach chay run_baseline sau khi gan: bon con so phai
%  khong xe dich mot chu so nao.

opt = parse_opts(varargin);

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end

po  = [mdl '/Position_Observers'];
sw  = [po '/Manual Switch1'];
prb = [po '/DLF_probe'];

assert(getSimulinkBlockHandle(sw) > 0, ...
    ['build_dlf_probe: khong thay %s.\n' ...
     'Do la cong tac d_lf_hat ma run_baseline dung (SW{2}). Model khac voi ' ...
     'gia dinh.'], sw);

%% ---- go cai cu (idempotent + Revert) ----
if getSimulinkBlockHandle(prb) > 0
    lh = get_param(prb, 'LineHandles');
    for i = 1:numel(lh.Inport)
        if lh.Inport(i) > 0, try delete_line(lh.Inport(i)); catch, end, end
    end
    delete_block(prb);
    fprintf('Da go dau do cua lan truoc.\n');
end
if opt.Revert
    if opt.Save, save_system(mdl); end
    fprintf('Da go dau do. Model tro lai nhu truoc.\n');
    return
end

%% ---- gan ----
add_block('simulink/Sinks/To Workspace', prb, ...
          'VariableName','dlfhat_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[820 700 910 730]);
% NHANH tren duong da co - khong cat gi.
add_line(po, 'Manual Switch1/1', 'DLF_probe/1', 'autorouting','on');

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
    w = get_param(sw, 'CompiledPortWidths');
    ok = (w.Outport(1) == 3);
    fprintf('  [%s] d_lf_hat be rong = %d (mong doi 3)\n', ...
            ternary(ok,'OK ','SAI'), w.Outport(1));
catch err
    fprintf('  [FAIL] compile: %s\n', err.message); return
end
clear cleanupObj

if opt.Save && ok
    save_system(mdl);
    fprintf('  Da ghi %s.slx\n', mdl);
elseif opt.Save
    fprintf('  KHONG ghi: compile hong.\n');
end

fprintf('\nBuoc tiep theo:\n');
% wind_series_on PHAI la 0 o phep hoi quy nay: expected_baseline la con so
% cua gio hang so.
fprintf(['  assignin(''base'',''wind_series_on'',0); run_baseline\n' ...
         '        %% 4 so PHAI khong doi - dau do chi la mot nhanh\n']);
fprintf('  diag_wind_channel(''wind_real_t150.mat'')\n');
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
