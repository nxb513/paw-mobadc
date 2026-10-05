function V = verify_pa_mobadc(matfile, varargin)
%VERIFY_PA_MOBADC  Kiem cong tac PA-MOBADC va doi chieu voi so ngoai tuyen.
%
%   V = verify_pa_mobadc('wind_real_t150.mat')
%
%  Chay BA cau hinh tren cung mot chuoi gio:
%     wind_pred_on=0                    MOBADC (bo quan sat)
%     wind_pred_on=1, wind_use_pred=0   cam bien gio 20 Hz, KHONG du doan
%     wind_pred_on=1, wind_use_pred=1   PA-MOBADC (cam bien + PI-MoE)
%
%  Cau hinh GIUA la doi chung ma neu thieu thi ca bai sai. Do duoc o doan
%  #0: bat PA-MOBADC cho -63.0% sai so bam, nhung tren kenh luc thi trong
%  63.4 diem phan tram do, CAM BIEN chiem 62.8 va DU DOAN chiem 0.62. Chi
%  bao cao hai cau hinh la de nguoi doc quy toan bo cho PI-MoE.
%
%  ======================================================================
%  PHEP KIEM MANH NHAT O DAY - VA VI SAO NO MANH
%  ======================================================================
%  Gio la NGOAI SINH: d(t) = K_w*w(t) den tu From Workspace, khong phu
%  thuoc vong dieu khien. Va K_w*w_hat cung the. Nen dai luong
%
%      e_pred(t) = dlf_used(t) - d(t+tau)     khi wind_pred_on = 1
%
%  phai bang DUNG BANG e_pred_zoh ma diag_wind_channel do duoc khi
%  wind_pred_on = 0 - tung mau, khong phai gan bang.
%
%  Neu hai con so do lech thi day dien khong lam dung dieu ma phep do ngoai
%  tuyen o muc 0.24 gia dinh, va moi con so trong bang W7 se sai theo.
%
%  Nguoc lai sai so BO QUAN SAT phai doi giua cac lan chay: no van chay
%  nhung nhin mot quy dao khac. Su bat doi xung do la mot phep kiem rieng -
%  neu ca hai deu khong doi thi cong tac chua noi vao gi ca. Doc no tu dau
%  do RIENG (dlf_obs_log), khong phai tu dlf_hat: khi bat du doan thi
%  dlf_hat khong con la dau ra bo quan sat.

if nargin < 1, error('verify_pa_mobadc: can file .mat da xuat.'); end
opt = struct('Stop', 200, 'TStat', 140);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end
po = [mdl '/Position_Observers'];

for b = {'WD_Switch','WP_Kw','DLF_probe'}
    assert(getSimulinkBlockHandle([po '/' b{1}]) > 0, ...
        ['verify_pa_mobadc: thieu %s.\n' ...
         'Chay: build_dlf_probe; build_wind_predictor; build_pa_mobadc'], b{1});
end

np = 0; nf = 0;
fprintf('\n%s\n', repmat('=',1,78));
fprintf('W6.3 - KIEM CONG TAC PA-MOBADC (BA cau hinh)\n');
fprintf('%s\n', repmat('=',1,78));

S = load(matfile);
for f = {'tau_ms','fs','t_valid_from'}
    if isfield(S,f{1}), S.(f{1}) = double(S.(f{1})); end
end
wind_sim_load(matfile, 1);
evalin('base','init_MOBADC_params');
[~, K_w] = wind_to_force([]);

% Chay bon cau hinh qua pa_configs - MOT nguon su that dung chung voi
% sweep_pa_mobadc. Neu hai ham tu tinh metric rieng thi som muon chung lech
% nhau o cua so hay o mat na, va khi bang cua bai khong khop bang cua phep
% kiem thi khong ai biet ben nao dung.
[R, M] = pa_configs(matfile, 'Stop', opt.Stop, 'TStat', opt.TStat);

t   = R.p_obs.t;
dt  = t(2) - t(1);
tau = S.tau_ms * 1e-3;
rms3 = @(e) sqrt(mean(sum(e.^2, 2)));

%% ---------------- 1. gio la ngoai sinh ----------------
fprintf('\n1. Gio phai KHONG doi giua CA BA lan chay (no la ngoai sinh)\n');
e = max([max(max(abs(R.p_pred.d - R.p_obs.d))), ...
         max(max(abs(R.p_sens.d - R.p_obs.d)))]);
chk('d(t) giong het o ca ba lan chay', e == 0, 'lech lon nhat %.3e N', e);

%% ---------------- 2. cong tac tat = duong cu ----------------
tv = S.t_valid_from;
fprintf('\n2. Cong tac hop le - doan dau phai chay duong QUAN SAT\n');
m0 = t < tv - dt/2;
e = max(max(abs(R.p_pred.dh(m0,:) - R.p_obs.dh(m0,:))));
chk('truoc t_valid_from, dlf_hat giong het lan p=0', e == 0, ...
    'lech lon nhat %.3e N tren [0, %.1f) s', e, tv);
chk('va no KHONG bang 0 (tuc khong phai dang dung what_ts = 0)', ...
    rms3(R.p_pred.dh(m0,:)) > 1e-6, 'RMS = %.4f N', rms3(R.p_pred.dh(m0,:)));

%% ---------------- 3. cong tac bat = du doan, tung mau ----------------
fprintf('\n3. Tu t_valid_from, dlf_hat PHAI bang K_w*w_hat tung mau\n');
tp = S.t_pred(:);
ia = round(tp/dt) + 1;  keep = ia <= numel(t);  ia = ia(keep);
ref = K_w * S.w_hat(keep, :);
e = max(max(abs(R.p_pred.dh(ia,:) - ref)));
chk('dlf_hat(t_k) = K_w * w_hat_k', e < 1e-9, ...
    'lech lon nhat %.3e N tren %d moc', e, numel(ia));
e0 = max(max(abs(R.p_obs.dh(ia,:) - ref)));
chk('lan p=0 thi KHONG bang (phep kiem co suc phan biet)', e0 > 1e-3, ...
    'lech %.4f N - dung nhu mong doi', e0);

%% ---------------- 4. bat doi xung: e_pred khong doi, e_est doi ----------
fprintf('\n4. Doi chieu voi phep do ngoai tuyen (muc 0.24)\n');
ktau = round(tau/dt);
% Mat na PHAI y het diag_wind_channel, khong duoc "tuong duong": ham do dung
% isfinite(dhat), tuc chan tren la tp(end) = 199.8 s chu khong phai
% Stop - tau = 199.85 s. Lech 50 ms do se lam phep so o duoi ra NaN, va toi
% se ngoi doan tai sao day dien sai trong khi no dung.
dhat = K_w * interp1(tp, S.w_hat, t, 'previous', NaN);
mk = (t >= opt.TStat) & (t <= opt.Stop - tau) & all(isfinite(dhat), 2);
i = find(mk); j = i + ktau;
ep1 = rms3(R.p_pred.dh(i,:) - R.p_pred.d(j,:));
ep0 = rms3(R.p_obs.dh(i,:) - R.p_obs.d(j,:));      % = e_eff cua lan cu
epo  = rms3(dhat(i,:) - R.p_obs.d(j,:));        % e_pred_zoh, do ngoai tuyen
chk('e_pred cua vong kin = e_pred_zoh do ngoai tuyen', ...
    abs(ep1 - epo) < 1e-9, '%.5f vs %.5f (lech %.2e)', ep1, epo, abs(ep1-epo));
% Sai so cua BO QUAN SAT phai doc tu dau do rieng (dlf_obs_log), khong phai
% tu dlf_hat: khi wind_pred_on = 1 thi dlf_hat la DU DOAN, khong con la dau
% ra bo quan sat. Ban dau toi dan nham hai cai do va gan nhan
% "bo quan sat nhin quy dao khac" cho mot dai luong khong phai sai so bo
% quan sat. Phep kiem van dat, nhung cai nhan thi sai - va nhan sai la thu
% dan den ket luan sai vai buoc sau.
oe0 = rms3(R.p_obs.ob(i,:)  - R.p_obs.d(i,:));
oe1 = rms3(R.p_pred.ob(i,:) - R.p_pred.d(i,:));
chk('sai so BO QUAN SAT doi khi no ra khoi vong', oe0 ~= oe1, ...
    '%.5f -> %.5f N (no van chay, nhung nhin quy dao khac)', oe0, oe1);
chk('dlf_hat cua lan p_obs = dau ra bo quan sat', ...
    max(max(abs(R.p_obs.dh - R.p_obs.ob))) == 0, ...
    'lech %.2e N', max(max(abs(R.p_obs.dh - R.p_obs.ob))));

%% ---------------- 5. nhanh cam bien: dung ZOH cua gio THAT ----------
fprintf('\n5. Nhanh doi chung: cam bien 20 Hz, KHONG du doan\n');
dzoh = interp1(t(ia), R.p_obs.d(ia,:), t, 'previous', NaN);
ms2 = mk & all(isfinite(dzoh), 2);
i2 = find(ms2); j2 = i2 + ktau;
e = max(max(abs(R.p_sens.dh(i2,:) - dzoh(i2,:))));
chk('dlf_hat = K_w * w_ZOH(t), tuc persistence cua cam bien', e < 1e-9, ...
    'lech lon nhat %.3e N', e);
es = rms3(R.p_sens.dh(i2,:) - R.p_sens.d(j2,:));
chk('nhanh nay KHAC nhanh du doan', abs(es - ep1) > 1e-9, ...
    'e_lag_zoh %.5f vs e_pred %.5f N', es, ep1);

%% ---------------- 6. ket qua bam - MOT DOAN, chua phai so cua bai -------
fprintf('\n6. Sai so bam tren doan nay (MOT doan - chua phai so cua bai)\n');
nmv = M.names;  lbl = M.labels;
eo  = rms3(R.p_orac.dh(i,:) - R.p_orac.d(j,:));
frc = [ep0, es, ep1, eo];
V = struct('file',matfile, 'e_force',frc);
% Doi chieu metric cua pa_configs voi phep tinh tai cho: hai duong phai cho
% cung mot so, neu khong thi mot trong hai dinh nghia cua so da troi.
chk('metric cua pa_configs khop phep tinh tai cho', ...
    abs(M.p_pred.rms_force - ep1) < 1e-12, ...
    'luc %.6f vs %.6f', M.p_pred.rms_force, ep1);
fprintf('  %-12s %9s %9s %9s | %10s\n', '', 'Mean', 'STD', 'Max', 'kenh luc');
for c = 1:numel(nmv)
    V.(nmv{c}) = struct('mean',M.(nmv{c}).mean, 'std',M.(nmv{c}).std, ...
                        'max',M.(nmv{c}).max, 'e_force',frc(c));
    fprintf('  %-12s %9.4f %9.4f %9.4f | %10.5f\n', lbl{c}, ...
            V.(nmv{c}).mean, V.(nmv{c}).std, V.(nmv{c}).max, frc(c));
end
b = V.p_obs.mean; s1 = V.p_sens.mean; s2 = V.p_pred.mean;
fprintf('\n  Bam:   %.4f -> %.4f (cam bien, %+.1f%%) -> %.4f (PI-MoE, %+.1f%% nua)\n', ...
        b, s1, 100*(s1-b)/b, s2, 100*(s2-s1)/s1);
fprintf('  Luc:   %.5f -> %.5f (%+.1f%%) -> %.5f (%+.1f%% nua)\n', ...
        frc(1), frc(2), 100*(frc(2)-frc(1))/frc(1), frc(3), ...
        100*(frc(3)-frc(2))/frc(2));
if s2 < b
    fprintf(['  => Trong toan bo phan cai thien, CAM BIEN chiem %.1f%% va\n' ...
             '     PI-MoE chiem %.1f%%. Bai PHAI bao cao tach ra nhu vay.\n'], ...
            100*(b-s1)/(b-s2), 100*(s1-s2)/(b-s2));
end
%% ---------------- 7. VI SAO hai ty le khac nhau - phan ra DC ------------
% Muc 0.21(b) noi rang ty le tren kenh luc khong chuyen thang sang sai so
% bam. O doan nay no khong chi khac ma con DOI DAU: PI-MoE lam luc tot len
% 1.7% nhung lam bam xau di. Doan nay do xem vi sao, thay vi de do la mot
% cau noi suong.
%
% Vong vi tri co do loi mot chieu 1/(m*Ky): mot sai so luc HANG SO chuyen
% thanh sai so vi tri hang so. Nen phan DC cua du sai so luc la phan bi
% khuech dai nhat, con phan dao dong nhanh thi bi vong kin loc bot.
%
% Va persistence co mot tinh chat cau truc: du cua no la d(t_k) - d(t+tau),
% tuc mot HIEU, nen ham truyen 1 - exp(-j*w*tau) TRIET TIEU o DC. Mot bo du
% doan co RMS thap hon nhung co thanh phan DC khac khong van co the thua
% persistence tren sai so bam. Neu do duoc dieu do thi ket luan cua bai la
% "muc tieu huan luyen phai duoc TRONG SO THEO TAN SO", chu khong phai
% "bo du doan yeu".
fprintf('\n7. Phan ra DC / dao dong cua du sai so LUC\n');
m_  = getbase('m',  1.121);
Ky_ = getbase('Ky', 12);
if ~isscalar(Ky_), Ky_ = Ky_(1,1); end
gdc = 1/(m_*Ky_);
fprintf('  do loi mot chieu 1/(m*Ky) = %.5f m/N\n', gdc);
fprintf('  %-12s %10s %10s | %12s %10s\n', '', '||mean||', 'dao dong', ...
        'DC -> bam', 'bam do duoc');
res = {R.p_obs.dh(i,:)  - R.p_obs.d(j,:), ...
       R.p_sens.dh(i,:) - R.p_sens.d(j,:), ...
       R.p_pred.dh(i,:) - R.p_pred.d(j,:), ...
       R.p_orac.dh(i,:) - R.p_orac.d(j,:)};
for c = 1:numel(nmv)
    r  = res{c};
    dc = norm(mean(r, 1));
    ac = sqrt(mean(sum((r - mean(r,1)).^2, 2)));
    V.(nmv{c}).dc = dc;  V.(nmv{c}).ac = ac;
    fprintf('  %-12s %10.5f %10.5f | %12.5f %10.4f\n', lbl{c}, dc, ac, ...
            dc*gdc, V.(nmv{c}).mean);
end
% ---- DC co GIAI THICH DUOC khong, chu khong chi "co dung dau khong" ----
%
% Ban dau toi chi kiem dau: dc(du doan) > dc(persistence) -> ket luan "DC
% giai thich chenh lech". Phep kiem do QUA DE. Do duoc: DC chi chiem 2.3%
% sai so bam cua nhanh cam bien va 5.9% cua nhanh PI-MoE, va chenh lech DC
% chi giai thich ~21% chenh lech bam. Tuc gia thuyet dung DAU nhung khong
% du DO LON, va toi da in ra mot ket luan manh hon du lieu cho phep.
%
% Nen thay bang mot phep so DU DOAN DUOC: sai so vi tri thoa
%     e_ddot + Kv*e_dot + Ky*e = (d - d_hat)/m
% nen loc chinh du sai so luc qua H(s) = 1/(s^2 + Kv*s + Ky) roi chia m se
% cho ra sai so bam. Neu mo hinh nay tai lap duoc ca bon hang thi ta GIAI
% THICH duoc, chu khong phai doan.
Kv_ = getbase('Kv', 8);
if ~isscalar(Kv_), Kv_ = Kv_(1,1); end
fprintf('\n  Loc du luc qua H(s) = 1/(s^2 + %g s + %g), chia m = %g:\n', ...
        Kv_, Ky_, m_);
fprintf('  %-12s %12s %12s %8s\n', '', 'bam DU DOAN', 'bam DO DUOC', 'lech');
% Dung pa_track_filt - CUNG mot ham voi pa_configs. Ban dau toi viet vong lap
% tai cho va lay dau ra SAU cap nhat, tuc som mot mau; do duoc lech 8.7e-05
% tren bien do ~0.07. Nho, nhung la mot LUA CHON chu khong phai sai so may,
% va hai duong tinh khac nhau thi khong doi chieu duoc voi nhau.
for c = 1:numel(nmv)
    pm = M.(nmv{c}).mean_filt;
    V.(nmv{c}).mean_pred = pm;
    fprintf('  %-12s %12.4f %12.4f %+7.1f%%\n', lbl{c}, pm, ...
            V.(nmv{c}).mean, 100*(pm - V.(nmv{c}).mean)/V.(nmv{c}).mean);
end
% Doi chieu: loc tai cho tren du sai so luc phai cho DUNG so cua pa_configs.
efv = pa_track_filt(res{3}, m_, Ky_, Kv_, dt);
q0v = max(1, round(numel(efv)/2));
chk('bam DU DOAN cua pa_configs khop phep loc tai cho', ...
    abs(mean(efv(q0v:end)) - M.p_pred.mean_filt) < 1e-12, ...
    '%.6f vs %.6f', mean(efv(q0v:end)), M.p_pred.mean_filt);

% ---- SAN: phan sai so bam KHONG den tu kenh gio ----
%
% Cot tren mot minh se lech rat lon o ba hang cuoi, va doc thang thi trong
% nhu mo hinh sai. No khong sai - no chi tinh dong gop cua KENH GIO. Con
% tai treo, ESO thai do va phan du khac tao mot SAN ma kenh gio khong cham
% toi. Hang ORACLE gan nhu triet tieu du gio, nen bam do duoc o hang do
% CHINH LA san do.
%
% Hai nguon gan doc lap thi cong BAC HAI. Do la mo hinh phai so.
flo = V.p_orac.mean;
fprintf('\n  San (bam cua hang ORACLE, tuc phan KHONG den tu gio) = %.4f m\n', flo);
fprintf('  %-12s %12s %12s %8s\n', '', 'gio (+) san', 'bam DO DUOC', 'lech');
for c = 1:numel(nmv)
    q = hypot(V.(nmv{c}).mean_pred, flo);
    fprintf('  %-12s %12.5f %12.4f %+7.1f%%\n', lbl{c}, q, ...
            V.(nmv{c}).mean, 100*(q - V.(nmv{c}).mean)/V.(nmv{c}).mean);
end
fprintf(['  Neu cot nay bam sat cot DO DUOC thi ta GIAI THICH duoc bang\n' ...
         '  PHO cua du sai so luc cong mot san, chu khong phai doan.\n']);

% ---- TRAN cua moi bo du doan tren tung chi so ----
fprintf('\n  TRAN cua moi bo du doan (hang ORACLE so voi hang cam bien):\n');
for f = {'mean','std','max'}
    a = V.p_sens.(f{1}); b = V.p_orac.(f{1});
    fprintf('    %-5s %8.4f -> %8.4f   %+6.1f%%\n', f{1}, a, b, 100*(b-a)/a);
end
fprintf(['    Luc %.5f -> %.5f (%.2f lan tot hon)\n'], ...
        frc(2), frc(4), frc(2)/frc(4));
if abs(V.p_orac.mean - V.p_sens.mean)/V.p_sens.mean < 0.02
    fprintf(['    => Tren MEAN, tran cua moi bo du doan xap xi BANG KHONG:\n' ...
             '       cam bien da dua du gio xuong duoi san, nen moi cai\n' ...
             '       thien them tren kenh gio deu khong nhin thay. Khong\n' ...
             '       phai PI-MoE yeu - khong con cho de tot hon.\n' ...
             '       Cho nao con cho thi nhin cot MAX va STD.\n']);
end
fprintf(['  Ty le tren kenh LUC va tren sai so BAM khong phai mot: vong kin\n' ...
         '  la mot bo thong thap va du cua du doan co pho khac. Muc 0.21(b).\n']);

%% ---------------- ket ----------------
fprintf('\n%s\n', repmat('=',1,78));
fprintf('%d dat, %d SAI\n', np, nf);
if nf > 0, error('verify_pa_mobadc: %d phep KHONG dat.', nf); end
fprintf(['Cong tac dung. Buoc tiep: sweep_pa_mobadc tren nhieu doan de co\n' ...
         'bang co sai so, dung cach da lam o muc 0.24.\n']);
fprintf('%s\n', repmat('=',1,78));

    function chk(name, c, fmt, varargin)
        if c, np = np + 1; tg = 'OK '; else, nf = nf + 1; tg = 'SAI'; end
        fprintf('  [%s] %-50s %s\n', tg, name, sprintf(fmt, varargin{:}));
    end
end


function v = sq3(v)
v = squeeze(v);
if size(v,1) == 3 && size(v,2) ~= 3, v = v.'; end
end

function v = getbase(name, dflt)
%GETBASE  Doc mot tham so tu base workspace, co gia tri du phong.
% Du phong la con so run_baseline.m dung o phep kiem cheo giai tich; neu
% phai dung den no thi ham in canh bao chu khong im lang.
if evalin('base', sprintf('exist(''%s'',''var'')', name))
    v = evalin('base', name);
else
    v = dflt;
    fprintf('  ! khong thay ''%s'' trong base - dung gia tri du phong %g\n', ...
            name, dflt);
end
end
