function ok = build_traj_preview(varargin)
%BUILD_TRAJ_PREVIEW  Them duong XEM TRUOC THAM CHIEU vao baseline1.slx.
%
%   build_traj_preview                    % dung, kiem, KHONG ghi
%   build_traj_preview('Save', true)      % dung, kiem, roi ghi model
%   build_traj_preview('Revert', true, 'Save', true)   % thao ra
%
%  ======================================================================
%  DAY LA CAI GI, VA VI SAO NO PHAI TON TAI TRUOC KHI CHAY A2
%  ======================================================================
%  docs/REGISTER_TAU.md §A2 dang ky mot duong doi chung: cho bo dieu khien
%  XEM TRUOC so hang feedforward gia toc, acc_d(t + tau_prev), va do xem no
%  mua duoc bao nhieu. Neu no gan bang PA-MOBADC thi phan lon loi ich cua
%  bai khong den tu viec du doan nhieu ma tu viec bu tre kenh tham chieu -
%  va luan de phai viet lai.
%
%  Duong do CHUA TON TAI trong model. Nen "chay A2 truoc khi sua code" la
%  khong the: A2 CHINH LA doan code nay. Cai ma dang ky bao ve khong phai
%  "khong duoc viet code", ma la "nguong da chot truoc" - va viec cam la
%  cam SUA CACH CAI DAT SAU KHI THAY KET QUA.
%
%  ======================================================================
%  NO SUA DUNG HAI THU
%  ======================================================================
%  (1) baseline1/Trajectory/Traj_Ref : ham trajectory_ref nhan them mot dau
%      vao tau_prev. Khoi MATLAB Function TU MOC THEM cong khi chu ky ham
%      doi, nen khong phai them cong bang tay.
%  (2) baseline1/Trajectory/TR_tauprev : mot Constant doc bien tau_prev tu
%      workspace, noi vao cong thu 5 do.
%
%  KHONG cham vao G_gamma_d. Do la Goto ma Err_Norm doc, nen khong mot gia
%  tri tau_prev nao co the lam sai so nho di bang cach doi muc tieu. Xem
%  §A2.0 muc 2.
%
%  ======================================================================
%  CONG A2-0
%  ======================================================================
%  tau_prev = 0 phai cho ket qua GIONG HET model truoc khi sua, tung bit,
%  vi w*(t+0) == w*t. Ham nay khong kiem duoc dieu do (no can chay sim);
%  sweep_field_grid o tau_prev = 0 kiem, va do la viec dau tien phai lam
%  sau khi chay ham nay.

opt = struct('Save', false, 'Revert', false, 'Skip0', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
here = repo_root();
cd(here); setup_path();

mdl = 'baseline1';
if ~bdIsLoaded(mdl), load_system(mdl); end
tr  = [mdl '/Trajectory'];
blk = [tr '/Traj_Ref'];
con = [tr '/TR_tauprev'];

assert(getSimulinkBlockHandle(blk) > 0, 'build_traj_preview:noblk', ...
    'Khong thay %s. Model nay khong phai baseline1 nhu kho mo ta.', blk);

%% ---------------- Thao ra ----------------
if opt.Revert
    n = teardown(tr, con);
    % KHONG doc lai simulink_blocks/trajectory_ref.m o day: file do gio co 5
    % dau vao, nen doc no se dung lai dung cai vua go. Ban 4 dau vao duoc
    % nhung thang o duoi, la ban truoc muc 0.119 nguyen van.
    write_fcn_text(blk, orig_fcn_text(), 4);
    fprintf('Da go %d khoi. Traj_Ref tro lai 4 dau vao.\n', n);
    ok = compile_check(mdl);
    if ok && opt.Save, save_system(mdl); fprintf('Da ghi %s.\n', mdl); end
    return
end

%% ---------------- DOI CHUNG: model SACH co compile duoc khong ----------------
% Neu compile hong o day thi loi KHONG phai cua thay doi nay, va moi phut
% bo ra doc ket qua compile sau khi sua deu la phut phi. Phep doi chung nay
% ton 5 giay va no da thieu o lan chay dau.
if ~opt.Skip0
    fprintf('\n=== DOI CHUNG: compile model SACH (chua sua gi) ===\n');
    ok0 = compile_check(mdl);
    if ~ok0
        fprintf(['\n[!] Model SACH da khong compile duoc, KE CA sau khi ham nay\n' ...
                 '    da tao chuoi 0 cho moi khoi From Workspace. Thay doi cua ham\n' ...
                 '    nay KHONG phai nguyen nhan - doc cac "nguyen nhan" o tren.\n' ...
                 '    Neu do la be rong tin hieu (chuoi 0 la 3 kenh), nap du lieu\n' ...
                 '    that mot lan roi chay lai voi (''Skip0'', true).\n']);
        ok = false;
        return
    end
end

%% ---------------- Bien workspace ----------------
% Mot bien THIEU lam sim dung ngay voi "Invalid setting ... for parameter
% 'Value'" - khong he chi ve khoi nao. Nen dat mac dinh TRUOC khi dung khoi.
if ~evalin('base', 'exist(''tau_prev'',''var'')')
    assignin('base', 'tau_prev', 0);
    fprintf('Da dat tau_prev = 0 trong base workspace (mac dinh: khong xem truoc).\n');
else
    fprintf('tau_prev da co: %.4g s\n', evalin('base','tau_prev'));
end

%% ---------------- Chu ky ham moi ----------------
% sync_eml_blocks doc thu muc simulink_blocks/. Ham nay ghi thang de
% build_traj_preview chay duoc doc lap, roi sync van khop vi cung mot file.
teardown(tr, con);                      % idempotent: chay lai khong chong khoi
write_fcn(blk, fullfile(here, 'simulink_blocks', 'trajectory_ref.m'), 5);

%% ---------------- Constant + day ----------------
add_block('simulink/Sources/Constant', con, ...
          'Value', 'tau_prev', 'Position', [40 300 140 330]);
add_line(tr, 'TR_tauprev/1', 'Traj_Ref/5', 'autorouting', 'on');

%% ---------------- Kiem tra ----------------
fprintf('\n=== KIEM TRA ===\n');
ok = compile_check(mdl);
if ~ok
    post_mortem(tr, blk, con);
    fprintf(['\n[!] Compile hong - KHONG ghi model (model tren dia van la ban cu).\n' ...
             '    Model TRONG BO NHO thi da bi sua; chay\n' ...
             '        build_traj_preview(''Revert'', true)\n' ...
             '    de tra no ve, hoac dong khong luu:\n' ...
             '        close_system(''baseline1'', 0)\n']);
    return
end
fprintf(['\n[OK] Da dung duong xem truoc.\n' ...
         '     tau_prev = 0  ->  phai tai lap luoi cu TUNG BIT (cong A2-0).\n' ...
         '     Do la phep chay dau tien, truoc moi so sanh.\n']);
if opt.Save
    save_system(mdl);
    fprintf('     Da ghi %s.slx\n', mdl);
else
    fprintf('     CHUA ghi. Goi lai voi (''Save'', true) khi muon giu.\n');
end
end

%% =====================================================================
function n = teardown(tr, con)
%TEARDOWN  Go khoi cua lan dung truoc. Chay lai ham nay phai an toan.
%
%  Khong co ham 'find_line' trong Simulink - ban dau toi goi mot ham khong
%  ton tai va build chet ngay dong dau. delete_line NHAN THANG dang
%  'khoi/cong' va bao loi neu duong do khong co, nen cach dung dung la goi
%  no trong try/catch: "chua co duong" la trang thai BINH THUONG o lan dung
%  dau tien, khong phai loi.
n = 0;
try
    delete_line(tr, 'TR_tauprev/1', 'Traj_Ref/5');
catch
    % chua co duong - dung nhu mong doi lan dau
end
if getSimulinkBlockHandle(con) > 0, delete_block(con); n = n + 1; end
% Cong thu 5 cua khoi MATLAB Function tu bien mat khi chu ky ham tro lai 4
% dau vao, nen khong phai xoa cong bang tay.
end

function write_fcn(blk, mfile, n_in)
%WRITE_FCN  Dat noi dung ham cua khoi MATLAB Function tu mot file .m.
write_fcn_text(blk, fileread(mfile), n_in, mfile);
end

function write_fcn_text(blk, txt, n_in, src)
%WRITE_FCN_TEXT  Dat noi dung ham, va KIEM hai thu quanh no.
if nargin < 4, src = '<chuoi noi ham>'; end

% (a) Chu ky phai khop so dau vao mong doi TRUOC khi ghi. Ghi mot chu ky sai
%     vao model roi moi phat hien la trang thai kho go nhat.
sig = regexp(txt, '^\s*function\s*\[[^\]]*\]\s*=\s*trajectory_ref\(([^)]*)\)', ...
             'tokens', 'once', 'lineanchors');
assert(~isempty(sig), 'build_traj_preview:sig', ...
    '%s khong co chu ky trajectory_ref quen thuoc.', src);
args = strtrim(strsplit(sig{1}, ','));
assert(numel(args) == n_in, 'build_traj_preview:nin', ...
    '%s co %d dau vao, can %d. Dung nguon khop voi che do dang dung.', ...
    src, numel(args), n_in);

ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', blk);
assert(~isempty(ch), 'build_traj_preview:nochart', ...
    'Khong tim thay Stateflow.EMChart cho %s.', blk);
ch.Script = txt;

% (b) Cong phai MOC THEM that su. Khoi MATLAB Function tu sinh cong theo chu
%     ky ham, nhung neu vi ly do nao do no chua kip thi add_line ngay sau day
%     se bao mot loi khong lien quan gi ("khong co cong 5"). Hoi thang o day
%     cho thong bao chi dung cho.
ph = get_param(blk, 'PortHandles');
assert(numel(ph.Inport) == n_in, 'build_traj_preview:ports', ...
    ['Da dat chu ky %d dau vao nhung khoi dang co %d cong vao.\n' ...
     'Khoi MATLAB Function chua cap nhat cong. Mo %s mot lan trong\n' ...
     'Simulink roi chay lai ham nay.'], n_in, numel(ph.Inport), blk);
end

function txt = orig_fcn_text()
%ORIG_FCN_TEXT  Ban 4 dau vao, nguyen van truoc muc 0.119. Chi dung cho Revert.
txt = sprintf([ ...
 'function [gamma_d, nu_d, acc_d] = trajectory_ref(t, R, w, z0)\n' ...
 '%%#codegen\n' ...
 'gamma_d = zeros(3,1); nu_d = zeros(3,1); acc_d = zeros(3,1);\n' ...
 'gamma_d = [R*cos(w*t);      R*sin(w*t);      z0];\n' ...
 'nu_d    = [-R*w*sin(w*t);   R*w*cos(w*t);    0 ];\n' ...
 'acc_d   = [-R*w^2*cos(w*t); -R*w^2*sin(w*t); 0 ];\n' ...
 'end\n']);
end

function ok = compile_check(mdl)
%COMPILE_CHECK  Compile, va khi hong thi IN HET nguyen nhan.
%
%  MATLAB gop cac loi lai thanh "Error due to multiple causes" va de chung
%  trong err.cause. Ban dau ham nay chi in err.message, tuc in dung chuoi
%  "Error due to multiple causes" va vut di toan bo noi dung - mot thong bao
%  loi khong noi gi ca thi te hon khong co thong bao, vi no ton mot vong
%  hoi dap. compile_check cua build_payload_predictor cung co dung diem mu
%  nay; sua o day truoc, cho no khi nao cham vao file kia.
ok = false;
safe_term(mdl);                      % phong khi lan truoc de model o trang thai compiled
% Bien TAM cho cac khoi From Workspace. Hai ham cuc bo ensure_fromws/drop_vars
% tung nam ngay trong file nay; chung da chuyen sang core/ensure_fromws.m de
% build_lqi_controller va verify_lqi_gate1 dung CHUNG mot ban, khong phai ban
% sao thu hai. Hanh vi khong doi: doi tuong tra ve tu don dung nhung bien no da
% tao, du compile hong hay khong.
cl = ensure_fromws(mdl); %#ok<NASGU>
try
    feval(mdl, [], [], [], 'compile');
    c = onCleanup(@() safe_term(mdl)); %#ok<NASGU>
    fprintf('  compile: OK\n');
    ok = true;
catch err
    fprintf('  compile: HONG\n');
    print_causes(err, '    ');
end
end

function print_causes(err, pad)
%PRINT_CAUSES  Di het cay err.cause, in tung la.
if ~isempty(err.identifier)
    fprintf('%s[%s]\n', pad, err.identifier);
end
msg = regexprep(err.message, '<[^>]*>', '');      % bo the sieu lien ket
for L = strsplit(msg, newline)
    if ~isempty(strtrim(L{1})), fprintf('%s%s\n', pad, strtrim(L{1})); end
end
for k = 1:numel(err.cause)
    fprintf('%s--- nguyen nhan %d/%d ---\n', pad, k, numel(err.cause));
    print_causes(err.cause{k}, [pad '  ']);
end
end

function post_mortem(tr, blk, con)
%POST_MORTEM  Ba thu can biet khi compile hong SAU khi sua, va chi ba thu do.
fprintf('\n  --- trang thai sau khi sua ---\n');
try
    ph = get_param(blk, 'PortHandles');
    fprintf('    %s: %d cong vao, %d cong ra\n', blk, ...
            numel(ph.Inport), numel(ph.Outport));
catch e
    fprintf('    khong doc duoc cong cua %s: %s\n', blk, e.message);
end
try
    v = evalin('base', 'tau_prev');
    fprintf('    tau_prev trong base = %g (lop %s)\n', v, class(v));
catch
    fprintf('    tau_prev KHONG co trong base workspace\n');
end
try
    fprintf('    %s Value = ''%s''\n', con, get_param(con, 'Value'));
catch
    fprintf('    %s khong ton tai\n', con);
end
% Cong nao con bo trong: mot cong vao khong noi day la nguyen nhan compile
% pho bien nhat sau khi doi chu ky ham.
try
    lh = get_param(blk, 'LineHandles');
    for k = 1:numel(lh.Inport)
        if lh.Inport(k) <= 0
            fprintf('    [!] cong vao %d cua %s KHONG duoc noi\n', k, blk);
        end
    end
catch
end
end

function safe_term(mdl)
try, eval([mdl '([],[],[],''term'');']); catch, end
end
