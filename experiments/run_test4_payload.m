function R = run_test4_payload(L_list)
%RUN_TEST4_PAYLOAD  Giai doan 2.1: nhieu tai sin (baseline) vs con lac vat ly.
%
%   >> run_test4_payload              % dung L trong init_MOBADC_params
%   >> run_test4_payload([0.8 1.0 1.2 1.445 1.8])   % quet L
%
%  Chay Test 4 tren cung mot model, cung seed, cung moi thu, chi doi
%  payload_model:
%     payload_model = 0  -> d_mf = [0; payload_amp*sin(sigma*t); 0]  (baseline)
%     payload_model = 1  -> d_mf tu con lac vat ly                   (moi)
%
%  Cung controller, cung dieu kien mo phong, KHAC DUY NHAT mo hinh nhieu tai.
%  Khong predictor. Khong observer moi. Khong AI. Nhung thu do la giai doan
%  sau; o day chi thay sin() bang con lac.
%
%  Nhanh 0 PHAI tai lap baseline_table.txt theo tung chu so. Script tu kiem
%  tra va DUNG neu khong. Luc do la day sai, dung doc ket qua nhanh 1.
%
%  CHE DO QUET L. Truyen mot vector L vao thi script chay lai nhanh con lac
%  voi tung gia tri va in bang MOBADC theo L. Do la cau tra loi cho cau hoi
%  "why is the cable length chosen as ... ?": ket luan khong phu thuoc L, va
%  co bang chung minh. Nhanh 0 khong dung den L nen chi chay mot lan.
%
%  Bang in ra la BANG MOTIVATION cua bai bao.
%
%  DIEU KIEN TIEN QUYET: da lam theo simulink_blocks/WIRING.md.

% *** TEN MODEL. Con lac duoc dung trong baseline1.slx, KHONG phai trong
%     mobadcgoc.slx. Lan chay truoc dat mdl = 'mobadcgoc' nen sim() nap ban
%     KHONG co con lac: hai nhanh payload_model chay cung mot model, quet L
%     phang, va kiem tra "tai lap baseline" van pass vi no so nhanh 0 voi
%     chinh no. Neu doi ten model thi doi o day, va guard ben duoi se bat
%     neu tro nham file. ***
mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
evalin('base','init_MOBADC_params');
if ~bdIsLoaded(mdl), load_system(mdl); end

% GUARD 1 (tinh): model dang nap phai co du khoi con lac.
need = {'Payload_Pendulum','PL_Switch','PL_pm','PL_Mem_a','PL_G_nu_dot','PL_dmf_log'};
miss = need(cellfun(@(b) isempty(find_system(mdl,'LookUnderMasks','all','Name',b)), need));
if ~isempty(miss)
    error('run_test4_payload:noPendulum', ...
        ['Model "%s" (%s) THIEU: %s\n' ...
         'Day la ban khong co con lac. Nhanh payload_model = 1 se cho ra dung\n' ...
         'ket qua cua nhanh 0. Tro mdl sang model co con lac roi chay lai.'], ...
        mdl, get_param(mdl,'FileName'), strjoin(miss,', '));
end
fprintf('Model: %s\n', get_param(mdl,'FileName'));

sweep = nargin >= 1 && ~isempty(L_list);
if ~sweep
    L_list = evalin('base','L');
end

%% ---------------- Kich ban Test 4 (giong het run_test4) ----------------
R_traj = 0.8;      % m    [PAPER 4.2.4]
V_traj = 1.26;     % m/s  [PAPER 4.2.4]
w_traj = V_traj/R_traj;        % [DERIVED] 1.5750 rad/s
payload_sigma = w_traj;

payload_amp = 1.5;   % N    dung cho nhanh payload_model = 0
wind_amp    = 1.0;   % N

assignin('base','R_traj',        R_traj);
assignin('base','w_traj',        w_traj);
assignin('base','payload_sigma', payload_sigma);
assignin('base','payload_amp',   payload_amp);
assignin('base','wind_amp',      wind_amp);
assignin('base','payload_z_on',  0);     % Giai doan 2.1: thuan ngang

% *** BAT BUOC: dung lai A_do theo sigma moi ***
% Dung lai TOAN BO ma tran DO theo sigma moi. Truoc day cho nay chi xay lai
% A_do bang cong thuc 6 trang thai, nen khi do_harm = [1 3] no se de A_do 6x6
% canh l_gain 12x6 -> sai kich thuoc, hoac te hon la chay duoc nhung sai.
evalin('base', ['[A_do, B_do, l_gain, do_info] = build_do_matrices(' ...
                'payload_sigma, do_harm, l_axis); ' ...
                'do_w = [do_info.do_w_axis{1}(:); do_info.do_w_axis{2}(:); ' ...
                'do_info.do_w_axis{3}(:)]; ' ...
                'n_state_axis = do_info.n_ax_state(:);']);
sig_chk = evalin('base','min(abs(imag(eig(A_do))))');
assert(abs(sig_chk - payload_sigma) < 1e-9, ...
       'A_do KHONG khop payload_sigma (%.4f vs %.4f)', sig_chk, payload_sigma);

%% ---------------- Cong kiem tra truoc khi ton hang gio mo phong ----------
fprintf('\n=== KIEM TRA TRUOC KHI CHAY ===\n');
model_contract();
if ~sync_eml_blocks()
    error('run_test4_payload:drift', ...
        ['Code trong baseline1.slx KHONG khop simulink_blocks/. Dong bo hai\n' ...
         'ban roi chay lai - neu khong, so lay ra khong tai lap duoc tu git.']);
end

STOP = 200;  T_STAT = 140;  g_ = 9.81;

SW = {[mdl '/Position_Observers/Manual Switch' ], ...   % d_mf_hat   (DO)
      [mdl '/Position_Observers/Manual Switch1'], ...   % d_lf_hat   (ESO vi tri)
      [mdl '/Attitude_Observer/Manual Switch2' ]};      % d_ltau_hat (ESO tu the)

cfg(1) = struct('name','Classical','sw',{{'0','0','0'}});
cfg(2) = struct('name','ESO',      'sw',{{'0','1','1'}});
cfg(3) = struct('name','DO',       'sw',{{'1','0','0'}});
cfg(4) = struct('name','MOBADC',   'sw',{{'1','1','1'}});

% Nguon DUY NHAT cho so ky vong. Truoc day khoi nay hardcode mot bo so rieng,
% lech voi header cua init va voi dong cuoi baseline_table.txt (0.0228 vs
% 0.0234) va khong co cach nao biet cai nao that.
% Dung sai cung doi tu tuyet doi 5e-4 sang TUONG DOI: 5e-4 la 2.2% tren
% MOBADC (0.0228) nhung chi 0.5% tren Classical - cong chat long khac nhau
% tuy hang, dung o hang chat nhat lai long nhat.
E = expected_baseline();

%% ---------------- Nhanh 0: baseline, khong dung den L ----------------
R = struct();
assignin('base','payload_model', 0);
fprintf('\n===== payload_model = 0 (sin baseline) =====\n');
R.sin_baseline = run_all_cfg();

fprintf('\n=== KIEM TRA TAI LAP BASELINE ===\n');
bad = {};
for k = 1:4
    N   = cfg(k).name;
    got = R.sin_baseline.(N).mean;
    ref = E.repro.(N).mean;
    tol = max(E.tol_abs, E.tol_rel*ref);
    ok  = abs(got - ref) < tol;
    if ok, verdict = 'khop'; else, verdict = '*** KHONG KHOP ***'; end
    fprintf('  %-9s %.4f vs %.4f (tol %.4f)  %s\n', N, got, ref, tol, verdict);
    if ~ok, bad{end+1} = N; end %#ok<AGROW>
end
if ~isempty(bad)
    error('run_test4_payload:baseline', ...
        ['payload_model = 0 KHONG tai lap baseline o: %s\n' ...
         'Day trong model sai o dau do. Dung doc ket qua payload_model = 1 ' ...
         'cho den khi cai nay khop.'], strjoin(bad, ', '));
end
fprintf('  Tat ca khop. Nhanh baseline nguyen ven.\n');

%% ---------------- Nhanh 1: con lac, mot lan cho moi L ----------------
assignin('base','payload_model', 1);
for iL = 1:numel(L_list)
    Lv = L_list(iL);
    assignin('base','L', Lv);
    % KHONG assignin wn_p: khoi con lac tu tinh wn = sqrt(g/L) ben trong nen
    % bien do la bien chet. Van tinh o day de IN RA, khong de dieu khien gi.
    fprintf('\n===== payload_model = 1 (con lac), L = %.3f m, wn_p = %.3f rad/s =====\n', ...
            Lv, sqrt(g_/Lv));
    r      = run_all_cfg();
    r.L    = Lv;
    r.wn_p = sqrt(g_/Lv);
    if iL == 1, R.pendulum = r; else, R.pendulum(iL) = r; end
end

% GUARD 2 (dong): hai nhanh PHAI khac nhau. Kiem tra "tai lap baseline" o tren
% khong bat duoc loi nap nham model - no so nhanh 0 voi REF, ma nhanh 1 co
% giong nhanh 0 hay khong thi no khong he nhin. Day la cho nhin.
for k = 1:4
    N = cfg(k).name;
    if abs(R.pendulum(1).(N).mean - R.sin_baseline.(N).mean) < 1e-9
        error('run_test4_payload:identical', ...
            ['[%s] payload_model = 0 va = 1 cho ra DUNG mot ket qua (%.6f).\n' ...
             'Cong tac PL_Switch khong doi duong, hoac model dang nap khong\n' ...
             'phai model co con lac.'], N, R.sin_baseline.(N).mean);
    end
end

% GUARD 3: quet L phai co tac dung.
if numel(L_list) > 1
    mm = arrayfun(@(x) x.MOBADC.mean, R.pendulum);
    if max(mm) - min(mm) < 1e-9
        error('run_test4_payload:flatSweep', ...
            ['Quet L hoan toan phang. Hang so PL_L / PL_L1 khong doc duoc bien\n' ...
             'L tu base workspace, hoac con lac khong nam trong duong tin hieu.']);
    end
end

%% ---------------- Bang ----------------
iMain = 1;   % L dau tien la diem dai dien cho bang chinh
S = {};
S{end+1} = '# Giai doan 2.1: nhieu tai sin (baseline) vs con lac vat ly';
S{end+1} = sprintf('# Test 4, r=%.2f m, v=%.2f m/s, sigma=%.4f rad/s, t in [%g,%g] s', ...
                   R_traj, V_traj, w_traj, T_STAT, STOP);
S{end+1} = sprintf('# m_p=%.2f kg, zeta_p=%.2f, payload_z_on=0', ...
                   evalin('base','m_p'), evalin('base','zeta_p'));
S{end+1} = '# Cung controller, cung dieu kien. Khac duy nhat: mo hinh nhieu tai.';
S{end+1} = '';
S{end+1} = sprintf('  Bang chinh (L = %.3f m, wn_p = %.3f rad/s vs sigma = %.3f)', ...
                   R.pendulum(iMain).L, R.pendulum(iMain).wn_p, w_traj);
S{end+1} = sprintf('  %-10s %-12s %-12s %-10s', '', 'sin', 'pendulum', 'xau di');
for k = 1:4
    N = cfg(k).name;
    a = R.sin_baseline.(N).mean;
    b = R.pendulum(iMain).(N).mean;
    S{end+1} = sprintf('  %-10s %-12.4f %-12.4f %+.1f%%', N, a, b, 100*(b-a)/a); %#ok<AGROW>
end
S{end+1} = '';
S{end+1} = sprintf('  MOBADC vs Classical: sin %.2f%% -> pendulum %.2f%%', ...
    100*(R.sin_baseline.Classical.mean - R.sin_baseline.MOBADC.mean) ...
        / R.sin_baseline.Classical.mean, ...
    100*(R.pendulum(iMain).Classical.mean - R.pendulum(iMain).MOBADC.mean) ...
        / R.pendulum(iMain).Classical.mean);

% Bien do nhieu thuc te da bom vao. BAO CAO chu khong bu tru: song sin lac
% mot truc con con lac quet mot vector quay, hai dang song khong the co
% cung ca dinh lan RMS. Ghi ro trong bai de reviewer khong phai tu doan.
if ~isnan(R.sin_baseline.d_mf_rms) && ~isnan(R.pendulum(iMain).d_mf_rms)
    S{end+1} = sprintf('  RMS||d_mf||: sin %.4f N | pendulum %.4f N (%+.1f%%)', ...
        R.sin_baseline.d_mf_rms, R.pendulum(iMain).d_mf_rms, ...
        100*(R.pendulum(iMain).d_mf_rms - R.sin_baseline.d_mf_rms) ...
            / R.sin_baseline.d_mf_rms);
    S{end+1} = sprintf('  Goc lac RMS: %.2f deg', R.pendulum(iMain).swing_rms_deg);
else
    % Dong nay bien mat lan truoc va do chinh la dau hieu model dang nap
    % khong co khoi dmf_log. Khong de no im lang nua.
    warning('run_test4_payload:noDmfLog', ...
        ['Khong doc duoc dmf_log -> khong bao cao duoc bien do nhieu thuc te. ' ...
         'Kiem tra khoi To Workspace PL_dmf_log.']);
    S{end+1} = '  RMS||d_mf||: KHONG DOC DUOC (thieu log dmf_log)';
end

if sweep
    S{end+1} = '';
    S{end+1} = '  Quet L - tra loi cho "why is the cable length chosen as ... ?"';
    S{end+1} = sprintf('  %-8s %-9s %-11s %-11s %-8s', ...
                       'L [m]', 'wn_p', 'MOBADC', 'Classical', 'vs sin');
    for iL = 1:numel(L_list)
        S{end+1} = sprintf('  %-8.3f %-9.3f %-11.4f %-11.4f %+.1f%%', ...
            R.pendulum(iL).L, R.pendulum(iL).wn_p, ...
            R.pendulum(iL).MOBADC.mean, R.pendulum(iL).Classical.mean, ...
            100*(R.pendulum(iL).MOBADC.mean - R.sin_baseline.MOBADC.mean) ...
                / R.sin_baseline.MOBADC.mean); %#ok<AGROW>
    end
    % Dung dau cua cot cuoi de ket luan "khong phu thuoc L": cung DAU chi noi
    % huong tac dong khong doi, khong noi gi ve DO LON. Muon ket luan khong
    % phu thuoc L thi phai cho thay BIEN DO THIEN dong deu, nen in luon ra day.
    vs = arrayfun(@(x) 100*(x.MOBADC.mean - R.sin_baseline.MOBADC.mean) ...
                       / R.sin_baseline.MOBADC.mean, R.pendulum);
    S{end+1} = sprintf(['  Cot cuoi: dau %s tren ca dai L, bien thien %.1f - %.1f%% ' ...
                        '(rong %.1f diem).'], ...
                       ternary(all(vs > 0) || all(vs < 0), 'KHONG DOI', 'CO DOI'), ...
                       min(vs), max(vs), max(vs) - min(vs));
    S{end+1} = '  Cung dau => huong tac dong on dinh. Ket luan "khong phu thuoc chieu';
    S{end+1} = '  dai cap" chi dung neu do rong o tren cung nho so voi chinh gia tri.';
end

S{end+1} = '';
S{end+1} = sprintf(['  Con lac co mode rieng o %.3f rad/s; exosystem cua DO chi co ' ...
                    '+-j%.3f.'], R.pendulum(iMain).wn_p, w_traj);
S{end+1} = '  Do la thu ma mot noi mo hinh dieu hoa mot tan so khong bieu dien duoc.';
S{end+1} = '';
S{end+1} = '  *** HAI DONG TREN CHUA DUOC BANG NAY CHUNG MINH - dung chep vao bai.';
S{end+1} = '  Hang DO ra +0.0%: trong cau hinh DO-only, gio khong ai khu va sai so';
S{end+1} = '  gio (0.0743 m) nhan chim phan du cua tai, nen hang do MU voi chinh';
S{end+1} = '  bien dang do. Quet L thi di NGUOC du bao cua internal-model: L tang';
S{end+1} = '  -> wn_p tien LAI GAN sigma, ma sai so lai TANG. Co che khop so lieu';
S{end+1} = '  la suy giam vong kin |H(jwn)|. Xem docs/devlog/AUDIT.md muc B1-B2; can chay';
S{end+1} = '  them cot wind_amp = 0 (P1) truoc khi ket luan gi ve exosystem. ***';

fprintf('\n%s\n', strjoin(S, newline));
fid = fopen('payload_model_table.txt','w');
fprintf(fid,'%s\n',strjoin(S,newline)); fclose(fid);
save('payload_model_results.mat','R');
fprintf('\nDa luu: payload_model_table.txt, payload_model_results.mat\n');

assignin('base','L', L_list(iMain));
for i = 1:3, set_param(SW{i},'sw','1'); end   % tra switch ve MOBADC

%% ================= nested =================
function out = run_all_cfg()
    out = struct();
    out.d_mf_rms      = NaN;
    out.swing_rms_deg = NaN;
    for kk = 1:4
        for ii = 1:3, set_param(SW{ii},'sw',cfg(kk).sw{ii}); end
        fprintf('  %-9s ... ', cfg(kk).name);
        o = sim(mdl,'StopTime',num2str(STOP),'Solver','ode4','FixedStep','1e-3');

        tt  = o.gamma_log.time;
        en  = sqrt(sum((toN3(o.gamma_log.signals.values) ...
                      - toN3(o.gammad_log.signals.values)).^2, 2));
        msk = tt >= T_STAT;

        NN = cfg(kk).name;
        out.(NN).mean = mean(en(msk));
        out.(NN).std  = std(en(msk));
        out.(NN).max  = max(en(msk));

        % RMS||d_mf|| va goc lac: chi de BAO CAO trong bang, khong dung de
        % dieu chinh gi. Can khoi To Workspace dmf_log / theta_log, deu la
        % tuy chon - xem WIRING.md.
        if kk == 4
            out.d_mf_rms      = rms_of(o, 'dmf_log',   tt, msk, 1:3);
            out.swing_rms_deg = rms_of(o, 'theta_log', tt, msk, [1 3]) * 180/pi;
        end
        fprintf('mean = %.4f | STD = %.4f\n', out.(NN).mean, out.(NN).std);
    end
    if ~isnan(out.d_mf_rms)
        fprintf('  RMS||d_mf|| = %.4f N\n', out.d_mf_rms);
    end
end
end

%% ================= helpers =================
function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end

function A = toN3(V)
if isstruct(V) && isfield(V,'signals'), V = V.signals.values; end
if isa(V,'timeseries'), V = V.Data; end
A = squeeze(V);
if size(A,2) ~= 3, A = A.'; end
end

function r = rms_of(o, name, tt, msk, cols)
r = NaN;
try
    if isprop(o,name) || (isstruct(o) && isfield(o,name)), v = o.(name);
    else, v = evalin('base', name); end
    if isstruct(v) && isfield(v,'signals'), v = v.signals.values; end
    if isa(v,'timeseries'), v = v.Data; end
    v = squeeze(v);
    if size(v,1) ~= numel(tt), v = v.'; end
    r = sqrt(mean(sum(v(msk,cols).^2, 2)));
catch
    % khong co log - bo qua, chi la so bao cao
end
end
