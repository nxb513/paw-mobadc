function verify_wind_predictor(matfile, varargin)
%VERIFY_WIND_PREDICTOR  Doi chieu d_wind_hat trong Simulink voi Python. W6.1.
%
%   verify_wind_predictor('wind_real_t150.mat')
%
%  Chay SAU build_wind_predictor. Mo phong mot lan roi so tin hieu ma model
%  sinh ra voi K_w * w_hat doc thang tu file .mat - TUNG MAU, khong phai
%  bang do thi va khong phai bang thong ke.
%
%  ======================================================================
%  BON CACH SAI MA PHEP DO NAY BAT DUOC
%  ======================================================================
%  1. SAI DON VI. Quen K_w, hoac nhan hai lan. Bat bang phep so tuyet doi.
%
%  2. LECH THOI GIAN. Chuoi bi danh chi so theo t_pred_target thay vi
%     t_pred, tuc bo dieu khien nhan du doan SOM hon tau. Khi do PA-MOBADC
%     se dep len mot cach gia tao va khong cho nao bao loi. Bat bang cach
%     so voi CA HAI cach danh chi so va doi hoi cach dung khop con cach kia
%     thi khong.
%
%  3. NOI SUY KHONG NHAN QUA. From Workspace de 'Interpolate','on' thi giua
%     hai mau no dung w_hat_{k+1}, mau chi co san o t_{k+1} > t. Bat bang
%     cach do gia tri o giua hai mau: phai bang DUNG mau trai.
%
%  4. DOAN DAU KHONG XAC DINH. Truoc t_valid_from khong co du doan; neu
%     From Workspace ngoai suy thi 30 s dau la rac. Bat bang cach doi hoi
%     doan do bang dung 0 va wvalid = 0.
%
%  ======================================================================
%  VA MOT PHEP KIEM AM
%  ======================================================================
%  Neu tin hieu trong model bang K_w*w_hat theo CA HAI cach danh chi so thi
%  phep kiem khong phan biet duoc gi - dieu do xay ra khi tau nho hon mot
%  buoc mau. Ham kiem rang hai cach danh chi so THAT SU khac nhau truoc khi
%  ket luan cach dung la dung.

if nargin < 1, error('verify_wind_predictor: can file .mat da xuat.'); end
opt = struct('Stop', 200);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end
po = [mdl '/Position_Observers'];

assert(getSimulinkBlockHandle([po '/WP_From']) > 0, ...
    'verify_wind_predictor: chua gan duong du doan. Chay build_wind_predictor.');

np = 0; nf = 0;
fprintf('\n%s\n', repmat('=',1,78));
fprintf('W6.1 - DOI CHIEU d_wind_hat: Simulink <-> Python\n');
fprintf('%s\n', repmat('=',1,78));

S = load(matfile);
for f = {'tau_ms','fs','t_valid_from'}
    if isfield(S,f{1}), S.(f{1}) = double(S.(f{1})); end
end
assert(isfield(S,'w_hat'), 'verify_wind_predictor: file khong co w_hat.');
wind_sim_load(matfile, 1);
evalin('base','init_MOBADC_params');
[~, K_w] = wind_to_force([]);

%% ---- 0. cau hinh khoi: nhan qua ----
fprintf('\n0. Cau hinh khoi - tinh nhan qua\n');
chk('WP_From giu bac thang (Interpolate = off)', ...
    strcmpi(get_param([po '/WP_From'],'Interpolate'), 'off'), ...
    'du doan chi co san tai moc 20 Hz; noi suy la doc mau tuong lai');
% Tim khoi gio-that theo BIEN no doc, khong theo duong dan: ten he thong con
% do build_wind_series tu do ra chu khong phai mot hang so o day.
ws = find_system(mdl, 'LookUnderMasks','all', 'FollowLinks','on', ...
                 'BlockType','FromWorkspace', 'VariableName','wind_ts');
if ~isempty(ws)
    chk('WS_From (gio THAT vao plant) noi suy TUYEN TINH', ...
        strcmpi(get_param(ws{1},'Interpolate'), 'on'), ...
        'gio that lien tuc; bac thang 20 Hz khong co trong vat ly');
else
    fprintf('  [ .. ] khong tim thay khoi doc wind_ts - bo qua phep doi lap\n');
end

%% ---- chay ----
fprintf('\nChay mo phong (%d s) ... ', opt.Stop);
o = sim(mdl, 'StopTime', num2str(opt.Stop), 'Solver','ode4', 'FixedStep','1e-3');
fprintf('xong\n');
t  = o.wpred_log.time;
p  = sq3(o.wpred_log.signals.values);
v  = squeeze(o.wvalid_log.signals.values); v = v(:);
dt = t(2) - t(1);

%% ---- 1. hinh dang ----
fprintf('\n1. Hinh dang\n');
chk('wpred_log la (n,3)', size(p,2) == 3, '%dx%d', size(p,1), size(p,2));
chk('wvalid_log cung do dai', numel(v) == numel(t), '%d mau', numel(v));

%% ---- 2. tin hieu hop le ----
fprintf('\n2. Tin hieu hop le\n');
tv = S.t_valid_from;
chk('wvalid = 0 truoc t_valid_from', all(v(t < tv - dt/2) == 0), ...
    'tren [0, %.1f) s', tv);
chk('wvalid = 1 tu t_valid_from tro di', all(v(t >= tv) == 1), ...
    'tren [%.1f, %d] s', tv, opt.Stop);
chk('d_wind_hat = 0 dung bang 0 truoc t_valid_from', ...
    max(max(abs(p(t < tv - dt/2, :)))) == 0, ...
    'lon nhat %.3e N', max(max(abs(p(t < tv - dt/2, :)))));

%% ---- 3. tung mau tai moc 20 Hz ----
fprintf('\n3. Tung mau tai moc 20 Hz - cach danh chi so DUNG (t_pred)\n');
tp  = S.t_pred(:);
tpt = S.t_pred_target(:);
ia  = round(tp/dt) + 1;
keep = ia <= numel(t);
ia = ia(keep);
ref = K_w * S.w_hat(keep, :);
chk('moc du doan roi vao mau nhat ky', max(abs(t(ia) - tp(keep))) < dt/2, ...
    'lech lon nhat %.2e s', max(abs(t(ia) - tp(keep))));
e = max(max(abs(p(ia,:) - ref)));
chk('d_wind_hat(t_k) = K_w * w_hat_k', e < 1e-9, ...
    'lech lon nhat %.3e N tren %d moc', e, numel(ia));

%% ---- 4. phep kiem AM: cach danh chi so kia phai KHONG khop ----
fprintf('\n4. Phep kiem AM - lech thoi gian phai lo ra\n');
ib = round(tpt/dt) + 1;
k2 = ib <= numel(t);
d2 = max(max(abs(p(ib(k2),:) - K_w*S.w_hat(k2,:))));
% Mot phep kiem, khong hai: "cach kia khong khop" va "hai cach khac nhau" la
% cung mot menh de khi muc 3 da dat. Cai co noi dung la phep kiem CO SUC
% PHAN BIET - neu tau nho hon mot buoc mau thi hai cach trung nhau va muc 3
% se dat du duong day sai.
chk('phep kiem muc 3 CO suc phan biet', d2 > 1e-6, ...
    'danh chi so theo t_pred_target lech %.4f N (tau = %g ms = %g buoc mau)', ...
    d2, S.tau_ms, S.tau_ms*1e-3*S.fs);

%% ---- 5. giu bac thang giua hai moc ----
fprintf('\n5. Giu bac thang giua hai moc - khong doc mau tuong lai\n');
T20 = median(diff(tp));
% Lay diem giua hai moc: phai bang DUNG gia tri moc trai.
im = ia(1:end-1) + round(T20/dt/2);
im = im(im <= numel(t));
nm = numel(im);
em = max(max(abs(p(im,:) - p(ia(1:nm),:))));
chk('gia tri giua hai moc = gia tri moc TRAI', em == 0, ...
    'lech lon nhat %.3e N tren %d diem', em, nm);
% Neu noi suy tuyen tinh thi diem giua se la trung binh hai moc. Do xem hai
% moc lien tiep co khac nhau du de phep kiem tren co nghia hay khong.
dstep = max(max(abs(diff(ref(1:min(end,2000),:), 1, 1))));
chk('hai moc lien tiep khac nhau du de phep kiem tren co nghia', ...
    dstep > 1e-6, 'buoc lon nhat %.4f N', dstep);

%% ---- 6. don vi ----
fprintf('\n6. Don vi\n');
r = mean(sqrt(sum(p(ia,:).^2,2))) / mean(sqrt(sum(S.w_hat(keep,:).^2,2)));
chk('ti so |d_wind_hat| / |w_hat| = K_w', abs(r - K_w) < 1e-9, ...
    '%.9f (K_w = %.4f)', r, K_w);

%% ---- ket ----
fprintf('\n%s\n', repmat('=',1,78));
fprintf('%d dat, %d SAI\n', np, nf);
if nf > 0
    error('verify_wind_predictor: %d phep KHONG dat.', nf);
end
fprintf(['Duong d_wind_hat trong model bang DUNG K_w*w_hat cua Python, dung\n' ...
         'moc thoi gian, va giu bac thang nhan qua.\n\n' ...
         'Buoc tiep: run_baseline phai KHONG doi (chua ai doc tin hieu nay),\n' ...
         'roi W6.2 - cong d_wind_hat vao d_payload_hat.\n']);
fprintf('%s\n', repmat('=',1,78));

    function chk(name, c, fmt, varargin)
        if c, np = np + 1; tag = 'OK '; else, nf = nf + 1; tag = 'SAI'; end
        if nargin > 2
            fprintf('  [%s] %-52s %s\n', tag, name, ...
                    sprintf(fmt, varargin{:}));
        else
            fprintf('  [%s] %s\n', tag, name);
        end
    end
end


function v = sq3(v)
v = squeeze(v);
if size(v,1) == 3 && size(v,2) ~= 3, v = v.'; end
end
