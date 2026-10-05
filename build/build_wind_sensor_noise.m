function build_wind_sensor_noise(varargin)
%BUILD_WIND_SENSOR_NOISE  Doi nhanh CAM BIEN cua WSEL sang doc wind_meas_ts.
%
%   build_wind_sensor_noise                  % dung / dung lai (idempotent)
%   build_wind_sensor_noise('Revert', true)  % tra WM_From ve doc wind_ts
%
%  ======================================================================
%  MOT DONG DUY NHAT DOI TRONG MODEL
%  ======================================================================
%  WM_From dang doc 'wind_ts' - gio THAT. Doi sang 'wind_meas_ts' - gio DO
%  DUOC. make_wind_meas tao wind_meas_ts tu wind_ts, va khi sigma = bias = 0
%  no la BAN SAO CHINH XAC, nen moi ket qua da co khong doi mot bit nao.
%
%  Khong dung khoi Random Number cua Simulink: no chay o buoc giai 1e-3 nen
%  se sinh nhieu trang 1 kHz, tuc mot cam bien co bang thong 500 Hz. May do
%  gio that chay 10-32 Hz. Sinh chuoi ben MATLAB o dung luoi 20 Hz roi de
%  WM_From giu bac thang moi dung vat ly - va tai lap duoc theo mam.
%
%  ======================================================================
%  CHI DOI NHANH CAM BIEN
%  ======================================================================
%  WP_From (PI-MoE) va WO_From (oracle) GIU NGUYEN. Do la mot bat doi xung
%  CO Y va phai ghi ro khi bao cao: PI-MoE van an gio SACH trong khi cam
%  bien an gio ban.
%
%  Bat doi xung do lam lech ket qua NGHIENG VE PHIA PI-MoE. Nen phep thu chi
%  ket luan duoc mot chieu:
%     PI-MoE VAN THUA  -> ket qua am VUNG HON, vi no thua ca khi duoc uu ai
%     PI-MoE THANG     -> KHONG ket luan duoc gi, phai chay lai voi PI-MoE
%                         an cung chuoi gio ban (xuat lai tu Python)
%  Xem docs/devlog/W6_INTEGRATION.md muc 0.41.

opt = struct('Revert', false, 'Save', true);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end
po = [mdl '/Position_Observers'];

if getSimulinkBlockHandle(po) <= 0
    b = find_system(mdl, 'SearchDepth', 1, 'BlockType', 'SubSystem');
    b = cellfun(@(s) s(numel(mdl)+2:end), b, 'UniformOutput', false);
    error('build_wind_sensor_noise:subsys', ...
        ['Khong co subsystem ''%s''.\nCac subsystem cap 1 co that:%s'], ...
        po, sprintf('\n    %s', b{:}));
end
assert(getSimulinkBlockHandle([po '/WM_From']) > 0, '%s', ...
    sprintf(['build_wind_sensor_noise: chua co WM_From.\n' ...
             'Chay build_pa_mobadc truoc.']));

tgt = 'wind_meas_ts';
if opt.Revert, tgt = 'wind_ts'; end
cur = get_param([po '/WM_From'], 'VariableName');

if strcmp(tgt, 'wind_meas_ts') && ...
        ~evalin('base','exist(''wind_meas_ts'',''var'')')
    % Stub de model compile duoc truoc khi ai goi make_wind_meas.
    if evalin('base','exist(''wind_ts'',''var'')')
        evalin('base','wind_meas_ts = wind_ts;');
        fprintf('  [luu y] wind_meas_ts chua co - dat = wind_ts.\n');
    else
        assignin('base','wind_meas_ts', ...
                 struct('time',[0;1], ...
                        'signals',struct('values',zeros(2,3),'dimensions',3)));
        fprintf('  [luu y] chua co gio - dat wind_meas_ts tam de compile.\n');
    end
end

set_param([po '/WM_From'], 'VariableName', tgt);
fprintf('WM_From: ''%s'' -> ''%s''\n', cur, tgt);

% Doi chung: hai nhanh kia PHAI khong bi dung den. Neu mot lan sua nao do
% lam WP_From cung doc wind_meas_ts thi so se trong hop ly va sai hoan toan.
for b = {'WP_From','WO_From'}
    if getSimulinkBlockHandle([po '/' b{1}]) > 0
        v = get_param([po '/' b{1}], 'VariableName');
        assert(~strcmp(v, 'wind_meas_ts'), ...
            '%s dang doc wind_meas_ts - nhanh do phai an gio SACH.', b{1});
        fprintf('  [OK] %-8s van doc ''%s''\n', b{1}, v);
    end
end

if opt.Save, save_system(mdl); fprintf('Da ghi %s.slx\n', mdl); end

fprintf(['\nBuoc tiep theo:\n' ...
         '  %% 1) HOI QUY - sigma = 0 phai tai lap TUNG CHU SO\n' ...
         '  assignin(''base'',''predictor_on'',0);\n' ...
         '  assignin(''base'',''wind_series_on'',0); run_baseline\n' ...
         '  %% 2) quet nhieu cam bien\n' ...
         '  S = sweep_sensor_noise;\n']);
end
