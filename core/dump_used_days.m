function d = dump_used_days(varargin)
%DUMP_USED_DAYS  MOI ngay M5 da bi tieu thu - khong chi lan cham tap khoa.
%
%   d = dump_used_days
%   d = dump_used_days('Res', {'heldout_final.mat','dev_t4.mat'})
%
%  ======================================================================
%  BAN CU CHI DOC heldout_final.mat - VA DO LA MOT LO RO (muc 0.94)
%  ======================================================================
%  Ban truoc doc DUY NHAT heldout_final.mat, tuc chi cac ngay bi tieu thu o
%  lan cham tap khoa 2026-09-05. No BO SOT toan bo cac ngay cua tap DEV -
%  nhung ngay ma moi quyet dinh cua bai duoc dua ra khi nhin vao:
%
%      harm = [0 1], K = 0.5, bao theta_DC <= 15 do, luat gop (L1)(L2),
%      moi khoang dang ky D0, va ca cong thuc (1+K) cua muc 0.91.
%
%  Ngay dev la ngay DA DUNG DE CHON. Neu mot ngay dev lot vao tap xac nhan
%  thi tap do khong con doc lap, va cong 3 cua run_confirm_once - von so voi
%  used_days.txt - se cho no di qua.
%
%  Co mot lop bao ve CAU TRUC: make_confirm_manifest chi lay tu
%  list_files(dir, 'heldout'), nen ngay dev khong bao gio la ung vien. Nhung
%  lap luan do dua vao viec split KHONG DOI va viec khong doan dev nao bi
%  xuat nham tu phia heldout. Ca hai deu HONG IM LANG neu sai, va khong cong
%  nao bat duoc - vi khong ai kiem 'split' cua doan dev (pa_configs GHI
%  M.split nhung khong ham nao doc no).
%
%  Nen: hop TAT CA cac ngay da cham, tu MOI bang. Mot phep hop khong ton gi
%  va no khong dua vao mot lap luan nao.
%
%  ======================================================================
%  DOC DUOC BON DANG KET QUA
%  ======================================================================
%    ckp.day                DIEM LUU TAM *_partial.mat (muc 0.88h-1)
%    MM(k).real_file        run_heldout_once / sweep_pa_grid / dev_t4
%    T.day                  sweep_field_grid / sweep_field_benchmark
%    T.file  (khong co day) mo tung doan .mat de doc real_file
%
%  Thieu file nao thi BAO chu khong im lang bo qua: mot bang bi bo sot chinh
%  la cach mot ngay da dung lot vao tap xac nhan.

opt = struct('Res', {{'heldout_final.mat', 'dev_t4.mat', ...
                      'field_grid_K*.mat', 'field_benchmark_K*.mat'}}, ...
             'Out', 'used_days.txt', 'AllowMissing', true);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
here = repo_root();
cd(here);
if ischar(opt.Res), opt.Res = {opt.Res}; end

% Giai cac mau file. Mot mau khong khop file nao la mot canh bao, khong phai
% mot chuyen binh thuong.
src = {};
for i = 1:numel(opt.Res)
    g = dir(opt.Res{i});
    g = g(~[g.isdir]);
    if isempty(g)
        fprintf('  ! khong co file nao khop ''%s''\n', opt.Res{i});
    end
    for k = 1:numel(g), src{end+1} = g(k).name; end %#ok<AGROW>
end
src = unique(src);
assert(~isempty(src), 'dump_used_days: khong tim thay bang ket qua nao trong %s.', here);

fprintf('\n%s\n  NGAY DA TIEU THU - hop tren %d bang\n%s\n', ...
        repmat('=',1,72), numel(src), repmat('=',1,72));

all_days = {};  per = cell(numel(src), 2);
for i = 1:numel(src)
    [dd, how] = days_from(src{i});
    per(i,:) = {src{i}, dd};
    fprintf('  %-34s %3d ngay  (%s)\n', src{i}, numel(dd), how);
    all_days = [all_days, dd]; %#ok<AGROW>
end
d = unique(all_days);

fprintf('\n  HOP: %d ngay\n', numel(d));
fprintf('    %s\n', strjoin(d, ' '));

% Ngay chi xuat hien o MOT bang la ngay de bi bo sot neu bang do khong duoc
% liet ke. In ra de nguoi doc thay ngay bang nao dang gong.
for i = 1:numel(src)
    others = {};
    for k = 1:numel(src), if k ~= i, others = [others, per{k,2}]; end, end %#ok<AGROW>
    only = setdiff(per{i,2}, unique(others));
    if ~isempty(only)
        fprintf('  chi co o %-28s : %s\n', per{i,1}, strjoin(only, ' '));
    end
end

fid = fopen(opt.Out, 'w');
assert(fid > 0, 'dump_used_days: khong ghi duoc %s.', opt.Out);
fprintf(fid, '%s\n', d{:});
fclose(fid);
fprintf('\n  Da ghi %s (%d ngay)\n', opt.Out, numel(d));
fprintf('  Dang MM_DD_YYYY - make_confirm_manifest doc duoc ca dang nay.\n\n');
end

%% =====================================================================
function [d, how] = days_from(file)
%DAYS_FROM  Rut ngay tu mot bang ket qua, thu ba duong theo thu tu re dan.
Z = load(file);
d = {};

% DIEM LUU TAM cua sweep_field_benchmark: dang 'ckp', do chinh toi viet o muc
% 0.88h-1 va quen xu ly o day. Mot lan chay dang do VAN dot ngay - bo qua no
% la dung cai lo ma ham nay sinh ra de bit.
if isfield(Z, 'ckp') && isstruct(Z.ckp)
    c = Z.ckp;
    nd = numel(c.day);
    if isfield(c, 'done'), nd = min(nd, c.done); end
    nfb = 0;
    for k = 1:nd
        t = strtrim(char(c.day{k}));
        if isempty(t) && isfield(c,'files') && k <= numel(c.files)
            % Ngay rong = moi cau hinh cua doan do da sap (pa_configs truoc
            % muc 0.94c khong giu real_file trong truong hop day). Doan VAN
            % DA CHAY nen ngay VAN BI DOT - phai lay lai tu chinh file doan,
            % neu khong thi mot ngay da dung se quay lai lam ung vien.
            fn = strtrim(char(c.files{k}));
            if exist(fn,'file') == 2
                S = load(fn, 'real_file');
                if isfield(S,'real_file'), t = day_str(S.real_file); nfb = nfb + 1; end
            end
        end
        if ~isempty(t), d{end+1} = to_m5(t); end %#ok<AGROW>
    end
    how = sprintf('ckp.day (%d/%d doan da chay)', nd, numel(c.day));
    if nfb > 0, how = sprintf('%s +%d lay tu file doan', how, nfb); end
    d = unique(d(~cellfun(@isempty, d)));  return
end

if isfield(Z, 'MM') && isstruct(Z.MM)
    for k = 1:numel(Z.MM)
        if isfield(Z.MM(k), 'real_file') && ~isempty(Z.MM(k).real_file)
            d{end+1} = day_str(Z.MM(k).real_file); %#ok<AGROW>
        end
    end
    how = 'MM.real_file';  d = unique(d(~cellfun(@isempty, d)));  return
end

if isfield(Z, 'T') && istable(Z.T)
    if ismember('day', Z.T.Properties.VariableNames)
        v = Z.T.day;
        for k = 1:numel(v)
            s = strtrim(char(v{k}));
            if ~isempty(s), d{end+1} = to_m5(s); end %#ok<AGROW>
        end
        how = 'T.day';  d = unique(d(~cellfun(@isempty, d)));  return
    end
    if ismember('file', Z.T.Properties.VariableNames)
        % Khong co cot ngay: phai mo tung doan. Cham hon nhung van la giay,
        % va bo qua thi mat dung cai dang can.
        v = Z.T.file;  miss = 0;
        for k = 1:numel(v)
            fn = strtrim(char(v{k}));
            if exist(fn,'file') ~= 2, miss = miss + 1; continue, end
            S = load(fn, 'real_file');
            if isfield(S,'real_file'), d{end+1} = day_str(S.real_file); end %#ok<AGROW>
        end
        how = sprintf('mo %d doan .mat', numel(v));
        if miss > 0
            how = sprintf('%s (! thieu %d tren dia)', how, miss);
        end
        d = unique(d(~cellfun(@isempty, d)));  return
    end
end

error('dump_used_days:shape', ...
    ['%s khong co ckp.day, MM.real_file, T.day hay T.file - khong rut ngay duoc.\n' ...
     'Bien co trong file: %s\n' ...
     'Bo qua im lang chinh la cach mot ngay da dung lot vao tap xac nhan.'], ...
    file, strjoin(fieldnames(Z)', ', '));
end

function s = day_str(rf)
%DAY_STR  10 ky tu dau cua ten M5: MM_DD_YYYY.
s = strtrim(char(rf));
if numel(s) >= 10 && s(3) == '_' && s(6) == '_', s = s(1:10); else, s = ''; end
end

function s = to_m5(s)
%TO_M5  'YYYY-MM-DD' -> 'MM_DD_YYYY'. Giu nguyen neu da dung dang M5.
if numel(s) == 10 && s(5) == '-' && s(8) == '-'
    s = [s(6:7) '_' s(9:10) '_' s(1:4)];
end
end
