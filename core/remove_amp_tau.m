function remove_amp_tau(varargin)
%REMOVE_AMP_TAU  Go han tham so amp_tau khoi baseline1.slx.
%
%   remove_amp_tau                  % go va ghi de .slx
%   remove_amp_tau('Save', false)   % go nhung khong ghi (de xem truoc)
%
%  ------------------------------------------------------------------
%  TAI SAO
%  ------------------------------------------------------------------
%  Guo et al. 2020 co Assumption 3 cho nhieu moment nhung khong cong bo dang
%  song, bien do hay huong. Tu nghi ra mot dang song la them mot bac tu do
%  khong kiem chung duoc vao ket qua duoi danh nghia "tai lap".
%
%  Truoc do amp_tau con te hon the: no la doi so cua disturbance_generator ma
%  than ham KHONG dung den. d_ltau = 0 bat ke amp_tau bang bao nhieu. Nhung
%  init khai bao 0.05 N.m va ca hai run script in no ra tieu de bang - tuc la
%  bang bao cao mot dieu kien thi nghiem khong ton tai. Xem docs/devlog/AUDIT.md A1.
%
%  Ket cuc dung: KHONG co tham so nao, va pham vi nhieu MOMENT duoc khai bao
%  tuong minh la ngoai pham vi trong paper.
%
%  ------------------------------------------------------------------
%  CHAY CAI NAY TRUOC KHI CHAY run_baseline
%  ------------------------------------------------------------------
%  simulink_blocks/disturbance_generator.m da la ban 4 doi so. Cho den khi
%  script nay chay, model van la ban 5 doi so, nen sync_eml_blocks se bao lech
%  va run_baseline / run_test4_payload se dung han. Do la co y.
%
%  Idempotent: chay lai nhieu lan khong sao.

opt = parse_opts(varargin);

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();

if ~bdIsLoaded(mdl), load_system(mdl); end

dist = [mdl '/Disturbances'];
gen  = [dist '/Dist_Gen'];
ta   = [dist '/ta'];

fprintf('=== GO amp_tau KHOI %s ===\n', mdl);

%% ---- 1. Khoi Constant 'ta' va duong cua no ----
if getSimulinkBlockHandle(ta) > 0
    lh = get_param(ta, 'LineHandles');
    for i = 1:numel(lh.Outport)
        if lh.Outport(i) > 0
            delete_line(lh.Outport(i));
        end
    end
    delete_block(ta);
    fprintf('  Da xoa Constant ''ta'' (Value = amp_tau) va duong cua no.\n');
else
    fprintf('  Constant ''ta'' khong con - da go tu truoc.\n');
end

%% ---- 2. Nap code 4 doi so vao khoi ----
% Phai lam SAU khi xoa duong: doi chu ky ham lam port 5 bien mat, neu con
% duong cam vao do thi Simulink bao loi.
src  = fullfile(here, 'simulink_blocks', 'disturbance_generator.m');
assert(exist(src, 'file') == 2, 'Khong thay %s', src);
code = fileread(src);

sig   = regexp(code, 'function\s+[^=]*=\s*\w+\s*\((.*?)\)', 'tokens', 'once');
assert(~isempty(sig), 'Khong doc duoc chu ky ham trong %s', src);
nargs = numel(strsplit(sig{1}, ','));
assert(nargs == 4, ...
    ['simulink_blocks/disturbance_generator.m co %d doi so, mong doi 4.\n' ...
     'File nguon chua duoc cap nhat sang ban khong co amp_tau.'], nargs);

ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', gen);
assert(~isempty(ch), 'Khong tim thay khoi MATLAB Function o %s', gen);
ch(1).Script = code;
fprintf('  Da nap disturbance_generator 4 doi so vao khoi.\n');

%% ---- 3. Kiem tra so port ----
p = get_param(gen, 'Ports');
if p(1) ~= 4
    error('remove_amp_tau:ports', ...
        ['Dist_Gen co %d cong vao sau khi nap, mong doi 4. Kiem tra lai chu ' ...
         'ky ham trong simulink_blocks/disturbance_generator.m.'], p(1));
end
fprintf('  Dist_Gen: %d vao / %d ra  (dung).\n', p(1), p(2));

%% ---- 4. Compile de bat loi truoc khi ghi ----
if evalin('base', 'exist(''m'',''var'')') == 0
    evalin('base', 'init_MOBADC_params');
end
cleanupObj = onCleanup(@() safe_term(mdl)); %#ok<NASGU>
try
    feval(mdl, [], [], [], 'compile');
    fprintf('  Compile sach.\n');
catch err
    error('remove_amp_tau:compile', ...
        'Compile loi sau khi go:\n  %s', err.message);
end
clear cleanupObj

%% ---- 5. Ghi ----
if opt.Save
    save_system(mdl);
    fprintf('  Da ghi %s.slx\n', mdl);
else
    fprintf('  KHONG ghi (Save = false). Model dang mo o trang thai da sua.\n');
end

fprintf('\nBuoc tiep theo:\n');
fprintf('  sync_eml_blocks      %% phai bao khop 19/19\n');
fprintf('  run_baseline         %% so PHAI khong doi - amp_tau chua bao gio co tac dung\n');
end


%% =====================================================================
function safe_term(mdl)
try
    if ~strcmp(get_param(mdl, 'SimulationStatus'), 'stopped')
        feval(mdl, [], [], [], 'term');
    end
catch
end
end

function opt = parse_opts(args)
opt = struct('Save', true);
for i = 1:2:numel(args)
    name = validatestring(args{i}, fieldnames(opt));
    opt.(name) = args{i+1};
end
end
