function verify_wind_force(matfile)
%VERIFY_WIND_FORCE  Kiem chuoi gio da xuat + anh xa gio->luc, TRUOC khi dau
%                   bat cu thu gi vao model.
%
%   verify_wind_force('wind_sim_t150.mat')
%
%  ======================================================================
%  VI SAO PHEP KIEM NAY TON TAI
%  ======================================================================
%  Chuoi nay di vao plant VA vao bo dieu khien. Neu no lech tau mot buoc,
%  hoac don vi sai, hoac anh xa gio->luc khong tuyen tinh nhu da tuyen bo,
%  thi bang W7 van in ra binh thuong va van SAI - va se khong the biet loi
%  nam o PI-MoE hay o bo dieu khien.
%
%  Nen moi tuyen bo cua W6.0 duoc phat bieu thanh mot dai luong kiem duoc:
%
%    1. Can thoi gian: t_target - t_avail = tau DUNG BANG, moi mau.
%    2. |w| = V_ref  =>  |d_lf| = wind_amp dung bang (K_w duoc neo).
%    3. Huong luc = huong gio (anh xa vo huong nhan ma tran don vi).
%    4. SAI SO LUC = K_w * SAI SO VAN TOC - day la tuyen bo lam cho skill
%       cua W5 truyen thang sang mien luc. Neu no khong dung thi ca chuoi
%       W5 -> W7 mat lien ket logic.
%    5. Truc z: gio nen ngang nen d_lf(3) chi la nhieu loan trung binh khong.

if nargin < 1, error('verify_wind_force: can duong dan toi .mat da xuat.'); end
S = load(matfile);
ok = 0; bad = 0;

fprintf('%s\n', repmat('=', 1, 78));
fprintf('KIEM CHUOI GIO DA XUAT - %s\n', matfile);
fprintf('%s\n', repmat('=', 1, 78));
% Nguon phai in ra TRUOC moi con so khac. Cung mot phep chan doan cho ket
% qua nguoc dau tren Dryden tau ngan (skill am) va tren gio that (+0.157),
% nen "dang chay cai nao" khong duoc de nguoi doc phai suy.
if isfield(S, 'source') && strcmp(strtrim(char(S.source)), 'real_m5')
    fprintf('  GIO THAT M5 - %s #%d, %g s @ %g Hz\n', ...
            strtrim(char(S.split)), S.index, S.duration_s, S.fs);
    fprintf('    %s  z = %g m  +%g s   U = %.2f m/s  I = %.1f%%\n', ...
            strtrim(char(S.real_file)), S.real_height_m, S.real_offset_s, ...
            S.real_U, 100*S.real_I);
    fprintf('    doan #%d trong %d doan qua QC - so cua bai phai GOP het\n', ...
            S.index, S.real_n_segments);
    if strcmp(strtrim(char(S.split)), 'heldout')
        fprintf('    ! TAP KHOA. Chi dung cho so cuoi cung cua bai.\n');
    end
else
    fprintf('  SYNTHETIC loai %d %s #%d (seed %d), %g s @ %g Hz\n', ...
            S.wind_type, S.split, S.index, S.seed, S.duration_s, S.fs);
end

% Ep double NGAY khi doc: file .mat cu co the con scalar kieu int64, va
% MATLAB lam so hoc SO NGUYEN tren no (int64(150)*1e-3 = 0). Phep kiem o muc
% 5 da bat duoc dung loi do.
for f = {'tau_ms','fs','plant_fs','window_s','t_valid_from','duration_s', ...
         'wind_type','index','seed','stride','mean_dir_deg', ...
         'real_height_m','real_offset_s','real_U','real_I','real_n_segments'}
    if isfield(S, f{1}), S.(f{1}) = double(S.(f{1})); end
end

[~, K_w] = wind_to_force([]);

%% ---- 1. hinh dang va don vi ----
fprintf('\n1. Hinh dang, don vi\n');
chk('w_plant la (n,3)', size(S.w_plant,2) == 3, '%dx%d', size(S.w_plant));
chk('t_plant khop w_plant', size(S.t_plant,1) == size(S.w_plant,1), ...
    '%d mau', size(S.t_plant,1));
dt = diff(S.t_plant);
chk('buoc thoi gian deu', max(abs(dt - dt(1))) < 1e-12, ...
    'dt = %.6f s = 1/%g Hz', dt(1), 1/dt(1));
U = mean(sqrt(sum(S.w_plant.^2, 2)));
chk('toc do gio hop ly cho UAV', U > 1 && U < 30, '|w| tb = %.3f m/s', U);

%% ---- 2. anh xa gio -> luc ----
fprintf('\n2. Anh xa gio -> luc (K_w = %.4f N/(m/s))\n', K_w);
d_lf = wind_to_force(S.w_plant);
md = mean(sqrt(sum(d_lf.^2, 2)));
chk('ti so |d|/|w| = K_w', abs(md/U - K_w) < 1e-12, ...
    '|d| tb = %.4f N, ti so %.6f', md, md/U);
% Phep neo: |w| = V_ref phai cho |d| = wind_amp DUNG BANG.
d_ref = wind_to_force([5.0; 0; 0]);
chk('|w| = 5.0 m/s -> |d| = 1.0 N (phep neo)', ...
    abs(norm(d_ref) - 1.0) < 1e-12, '|d| = %.9f N', norm(d_ref));
psi = atan2d(mean(d_lf(:,2)), mean(d_lf(:,1)));
% So goc phai BOC VONG: atan2d tra ve (-180, 180] con mean_dir_deg nam trong
% [0, 360). Gio that di qua xoay kep co trung binh dung tren truc x, tuc goc
% 0 +- sai so may - neu sai so am thi hai con so lech dung 360 do va phep
% kiem bao SAI ma khong co gi sai.
dpsi = mod(psi - S.mean_dir_deg + 180, 360) - 180;
chk('huong luc = huong gio nen', abs(dpsi) < 1e-6, ...
    '%.4f do (cho doi %.1f, lech %.2e)', psi, S.mean_dir_deg, dpsi);
chk('d_lf(3) trung binh ~ 0 (gio nen ngang)', ...
    abs(mean(d_lf(:,3))) < 0.05*md, '%+.4f N', mean(d_lf(:,3)));

%% ---- 3. du doan: can thoi gian ----
if isfield(S, 'w_hat')
    fprintf('\n3. Du doan - can thoi gian\n');
    dd = S.t_pred_target - S.t_pred;
    chk('t_target - t_avail = tau, MOI mau', ...
        max(abs(dd - S.tau_ms*1e-3)) < 1e-12, ...
        'min %.6f max %.6f s (tau = %g ms)', min(dd), max(dd), S.tau_ms);
    chk('du doan bat dau sau khi cua so day', ...
        abs(S.t_valid_from - S.window_s) < 1e-9, ...
        't = %.2f s (cua so %.0f s)', S.t_valid_from, S.window_s);
    chk('t_pred tang nghiem ngat', all(diff(S.t_pred) > 0), ...
        '%d mau', numel(S.t_pred));

    %% ---- 4. sai so luc = K_w * sai so van toc ----
    fprintf('\n4. Tuyen tinh: sai so luc = K_w x sai so van toc\n');
    i0 = round(S.t_valid_from*S.fs) + 1;
    k  = round(S.tau_ms*1e-3*S.fs);
    j  = i0 + k + (0:numel(S.t_pred)-1)';
    chk('chi so muc tieu nam trong ban ghi', max(j) <= size(S.w_plant,1), ...
        'max j = %d / %d', max(j), size(S.w_plant,1));
    w_tgt = S.w_plant(j, :);
    e_w = w_tgt - S.w_hat;
    e_d = wind_to_force(w_tgt) - wind_to_force(S.w_hat);
    r = max(abs(e_d(:) - K_w*e_w(:)));
    chk('e_d = K_w * e_w den sai so may', r < 1e-12, 'lech lon nhat %.2e', r);
    fprintf('       RMS sai so van toc %.4f m/s  ->  RMS sai so luc %.4f N\n', ...
           sqrt(mean(e_w(:).^2)), sqrt(mean(e_d(:).^2)));

    %% ---- 5. skill doi chieu ----
    fprintf('\n5. Skill doi chieu voi bang W5\n');
    ref = S.w_plant(i0 + (0:numel(S.t_pred)-1)', :);   % persistence = w(t)
    sk = 1 - sum((S.w_hat(:) - w_tgt(:)).^2) / sum((ref(:) - w_tgt(:)).^2);
    chk('skill tinh lai o MATLAB khop Python', ...
        abs(sk - S.skill_check) < 1e-6, ...
        'MATLAB %+.6f vs Python %+.6f', sk, S.skill_check);
else
    fprintf('\n(khong co truong w_hat - chuoi nay chi co gio that)\n');
end

fprintf('\n%s\n%d dat, %d SAI\n', repmat('=', 1, 78), ok, bad);
if bad > 0
    error('verify_wind_force: %d phep kiem SAI - khong duoc dau vao model.', bad);
end

    % Ham long nhau: dung chung bien dem ok/bad voi ham cha.
    function chk(name, cond, fmt, varargin)
        if cond, tag = 'OK '; ok = ok + 1; else, tag = 'SAI'; bad = bad + 1; end
        fprintf('  [%s] %-46s %s\n', tag, name, sprintf(fmt, varargin{:}));
    end
end
