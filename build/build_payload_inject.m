function build_payload_inject(varargin)
%BUILD_PAYLOAD_INJECT  Cong thanh phan ngoai mo hinh vao nhieu tai, sau PL_Switch.
%
%   build_payload_inject                  % dung / dung lai (idempotent)
%   build_payload_inject('Revert', true)  % go het, tra day ve nhu cu
%
%  ======================================================================
%  CHEN O DAU
%  ======================================================================
%  Hien tai:   (nguon d_mf) --> G_d_mf
%  Sau khi dung:
%              (nguon d_mf) --> PI_Sum --> G_d_mf
%                               ^
%              dmf_inj_ts -> PI_From -> PI_Switch(payload_inj_on) -+
%                                       Constant [0;0;0] ----------+
%
%  "nguon d_mf" la PL_Switch/1 neu da dung con lac, Dist_Gen/1 neu chua. Ham
%  nay KHONG gia dinh - doc nguon that tu PortConnectivity cua G_d_mf va ghi
%  vao Description cua PI_Sum de Revert tra lai dung cho.
%
%  ======================================================================
%  MAC DINH TAT = KHONG DOI MOT BIT
%  ======================================================================
%  payload_inj_on = 0 -> PI_Switch tra [0;0;0], PI_Sum cong 0. Moi ket qua da
%  co phai tai lap TUNG CHU SO. run_baseline la phep kiem, khong tin loi ham.
%
%  PI_dmf_log ghi d_mf SAU khi cong, de kiem o do duoc trong model khop voi o
%  tinh offline trong make_payload_inject.

opt = struct('Revert', false, 'Save', true);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end
dist = [mdl '/Disturbances'];
if getSimulinkBlockHandle(dist) <= 0
    b = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    b = cellfun(@(s) s(numel(mdl)+2:end), b, 'UniformOutput', false);
    error('build_payload_inject:subsys', ...
        ['Khong co subsystem ''%s''.\nCac subsystem cap 1 co that:%s'], ...
        dist, sprintf('\n    %s', b{:}));
end
assert(getSimulinkBlockHandle([dist '/G_d_mf']) > 0, ...
    'build_payload_inject: khong thay G_d_mf trong %s.', dist);

n = teardown(dist);
if n > 0, fprintf('Da go %d khoi cua lan dung truoc.\n', n); end
if opt.Revert
    fprintf('Da tra day ve nhu cu.\n');
    if opt.Save, save_system(mdl); end
    return;
end

% Nguon THAT dang nuoi G_d_mf/1 - doc, khong doan.
[srcblk, srcport] = src_of(dist, 'G_d_mf', 1);
assert(~isempty(srcblk), 'build_payload_inject: G_d_mf/1 khong co nguon.');
fprintf('Nguon d_mf hien tai: %s/%d\n', srcblk, srcport);

stub_vars();

%% ---------------- khoi moi ----------------
add_block('simulink/Sources/From Workspace', [dist '/PI_From'], ...
          'VariableName','dmf_inj_ts', 'SampleTime','0', ...
          'Interpolate','on', 'OutputAfterFinalValue','Holding final value', ...
          'Position',[560 560 680 600]);
add_block('simulink/Sources/Constant', [dist '/PI_off'], ...
          'Value','[0;0;0]', 'Position',[560 660 680 690]);
add_block('simulink/Sources/Constant', [dist '/PI_on'], ...
          'Value','payload_inj_on', 'Position',[560 615 680 645]);
add_block('simulink/Signal Routing/Switch', [dist '/PI_Switch'], ...
          'Criteria','u2 >= Threshold', 'Threshold','0.5', ...
          'Position',[720 555 760 695]);
add_block('simulink/Math Operations/Sum', [dist '/PI_Sum'], ...
          'Inputs','++', 'Position',[820 430 850 470]);
set_param([dist '/PI_Sum'], 'Description', ...
          sprintf('PAYLOAD_INJ_ORIG_SRC=%s/%d', srcblk, srcport));
add_block('simulink/Sinks/To Workspace', [dist '/PI_dmf_log'], ...
          'VariableName','dmf_tot_log', 'SaveFormat','Structure With Time', ...
          'MaxDataPoints','inf', 'Decimation','1', ...
          'Position',[900 500 990 530]);

%% ---------------- noi day ----------------
% Cat nguon -> G_d_mf, chen Sum vao giua.
lh = get_param([dist '/G_d_mf'], 'LineHandles');
if lh.Inport(1) > 0, delete_line(lh.Inport(1)); end
add_line(dist, sprintf('%s/%d', srcblk, srcport), 'PI_Sum/1', 'autorouting','on');
add_line(dist, 'PI_From/1',   'PI_Switch/1', 'autorouting','on');
add_line(dist, 'PI_on/1',     'PI_Switch/2', 'autorouting','on');
add_line(dist, 'PI_off/1',    'PI_Switch/3', 'autorouting','on');
add_line(dist, 'PI_Switch/1', 'PI_Sum/2',    'autorouting','on');
add_line(dist, 'PI_Sum/1',    'G_d_mf/1',    'autorouting','on');
add_line(dist, 'PI_Sum/1',    'PI_dmf_log/1','autorouting','on');

%% ---------------- kiem tra ----------------
fprintf('\n=== KIEM TRA SAU KHI DUNG ===\n');
evalin('base','init_MOBADC_params');
ok = false;
try
    eval([mdl '([],[],[],''compile'');']);
    c = onCleanup(@() safe_term(mdl));
    w = get_param([dist '/PI_Sum'], 'CompiledPortWidths');
    ok = (w.Outport(1) == 3);
    fprintf('  [%s] PI_Sum be rong dau ra = %d (mong doi 3)\n', tern(ok), w.Outport(1));
    fprintf('  [OK] compile sach\n');
    clear c;
catch err
    fprintf('  [LOI] %s\n', err.message);
    safe_term(mdl);
end
if ~ok
    teardown(dist);
    error('build_payload_inject:compile', ...
          'Compile that bai - da tra model ve nguyen trang, khong ghi de .slx.');
end
if opt.Save, save_system(mdl); fprintf('Da ghi %s.slx\n', mdl); end

fprintf(['\nBuoc tiep theo:\n' ...
         '  %% 1) HOI QUY - payload_inj_on = 0 phai tai lap TUNG CHU SO\n' ...
         '  assignin(''base'',''payload_inj_on'',0);\n' ...
         '  assignin(''base'',''payload_model'',0);\n' ...
         '  assignin(''base'',''predictor_on'',0);\n' ...
         '  assignin(''base'',''wind_series_on'',0); run_baseline\n' ...
         '  %% 2) kiem o trong model khop o offline\n' ...
         '  verify_payload_inject\n' ...
         '  %% 3) P0\n' ...
         '  sweep_validity_headline\n']);
end


%% =====================================================================
function stub_vars()
if ~evalin('base','exist(''payload_inj_on'',''var'')')
    assignin('base','payload_inj_on', 0);
    fprintf('  [luu y] payload_inj_on chua co - dat 0.\n');
end
if ~evalin('base','exist(''dmf_inj_ts'',''var'')')
    assignin('base','dmf_inj_ts', struct('time',[0;1], ...
             'signals',struct('values',zeros(2,3),'dimensions',3)));
    fprintf('  [luu y] dmf_inj_ts chua co - dat tam de compile.\n');
end
end

function [blk, port] = src_of(dist, name, k)
blk = '';  port = 0;
pc = get_param([dist '/' name], 'PortConnectivity');
h  = pc(k).SrcBlock;
if ~isempty(h) && h > 0
    blk  = get_param(h, 'Name');
    port = pc(k).SrcPort + 1;          % PortConnectivity dem tu 0
end
end

function n = teardown(dist)
%TEARDOWN  Go PI_* va noi lai nguon goc -> G_d_mf. An toan khi chua co gi.
n = 0;
orig = '';
if getSimulinkBlockHandle([dist '/PI_Sum']) > 0
    d = get_param([dist '/PI_Sum'], 'Description');
    tok = regexp(d, 'PAYLOAD_INJ_ORIG_SRC=(\S+)', 'tokens', 'once');
    if ~isempty(tok), orig = tok{1}; end
    if isempty(orig)
        % Du phong: doc nguon dang nuoi PI_Sum/1.
        [b, p] = src_of(dist, 'PI_Sum', 1);
        if ~isempty(b), orig = sprintf('%s/%d', b, p); end
    end
end
tg = {'PI_Sum','PI_Switch','PI_From','PI_on','PI_off','PI_dmf_log'};
for i = 1:numel(tg)
    if getSimulinkBlockHandle([dist '/' tg{i}]) > 0, drop_lines([dist '/' tg{i}]); end
end
for i = 1:numel(tg)
    if getSimulinkBlockHandle([dist '/' tg{i}]) > 0
        delete_block([dist '/' tg{i}]);  n = n + 1;
    end
end
if n > 0 && ~isempty(orig)
    lh = get_param([dist '/G_d_mf'], 'LineHandles');
    if lh.Inport(1) > 0, delete_line(lh.Inport(1)); end
    add_line(dist, orig, 'G_d_mf/1', 'autorouting','on');
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

function s = tern(b)
if b, s = 'OK'; else, s = 'LOI'; end
end

function safe_term(mdl)
try, eval([mdl '([],[],[],''term'');']); catch, end
end
