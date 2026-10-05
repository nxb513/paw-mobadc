function R = run_baseline(varargin)
% RUN_BASELINE  Reproduce Test 4 (Table 1 + Fig. 10) of the original MOBADC,
%               Guo et al. 2020.
%
%   >> run_baseline
%
%  PURE BASELINE: sinusoidal payload only (eq. 6) + constant wind. NO pendulum,
%  NO Dryden turbulence, NO seed, NO mode switches. It is the reduced form of
%  run_test4(0,0). The extensions (pmodel/wmodel...) are exercised in run_test4
%  when doing ablations.
%
%  This is the REGRESSION GATE for baseline1.slx: its four numbers are compared
%  against core/expected_baseline.m, which is their single source.
%
%  Metric: gamma_bar = mean(||gamma - gamma_d||) over [T_STAT, STOP] (Sec 4.3).
%  Measured in STEADY STATE: the DO pole is ~ -0.045 rad/s (time constant 22 s)
%  and the ESO zp3 pole ~ -0.084 rad/s, so at t = 140 s about 0.2% of the
%  transient remains. A real system runs continuously; this is a Remark to be
%  recorded in the paper.
 
opt = struct('Strict', true, 'Wind', 0);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();
evalin('base','init_MOBADC_params');
% TURN EVERY EXTENSION OFF. This is the regression gate, so it must be
% independent of anything left over in the base workspace. It has slipped
% exactly for want of this line: a sweep stopped midway left wind_pred_on = 1,
% and the two rows with Manual Switch1 = '1' (ESO, MOBADC) were compensating a
% wind that was not in the plant. See core/reset_extensions.m.
%
% wind_series_on is turned off too, then set from 'Wind'. The default 0 means
% CONSTANT WIND, i.e. what this function's own header says ("sinusoidal payload
% + constant wind"), and the only condition under which expected_baseline means
% anything.
%
% This used to leave the caller's wind_series_on alone, and the consequence was:
% a wind series left over from an earlier sweep made the plant run a completely
% different disturbance, the regression gate was SILENTLY SKIPPED, and the
% function returned normally. Running run_baseline twice with a sweep in between
% gave two quite different sets of numbers, neither of which was a regression
% test. To get a wind series you now have to say so: 'Wind', 1.
reset_extensions();
assignin('base', 'wind_series_on', double(opt.Wind ~= 0));
if ~bdIsLoaded(mdl), load_system(mdl); end

% On a MATLAB just opened, this function could not run AT ALL: PI_From and
% WM_From evaluate their VariableName parameter whether or not their switch is
% on, so the regression gate stopped with a raw Simulink error about
% dmf_inj_ts and wind_meas_ts - two series that have nothing to do with the
% baseline. README says these commands "stop with a message telling you what is
% missing"; for this failure they did not, and the message pointed nowhere.
%
% This line creates them zero and deletes them again on return. It CANNOT move
% a number: reset_extensions has just turned both switches off, the values are
% zero, and when the real series are already loaded the call skips them and
% does nothing at all. See core/ensure_fromws.m.
fwcl = ensure_fromws(mdl); %#ok<NASGU>

%% ---------------- The Test 4 scenario ----------------
% DIRECTION OF INFERENCE: r and v are GIVEN in the reference work; everything
% else is DERIVED.
R_traj = 0.8;      % m    [PAPER 4.2.4] "radius ... is 0.8 m"
V_traj = 1.26;     % m/s  [PAPER 4.2.4] "flight speeds ... all set around 1.26 m/s"
w_traj = V_traj/R_traj;        % [DERIVED] = 1.5750 rad/s -> T = 3.99 s
% The paper writes "sigma_i ~ 0.25 s^-1" = 0.25 Hz = 1.575 rad/s.
% A_i = [0 sigma; -sigma 0] has eigenvalues +-j*sigma, so sigma MUST be in
% rad/s. This is the 2*pi dimensional inconsistency in the source document
% (anomaly #1).
payload_sigma = w_traj;        % [DERIVED] circular flight -> payload swings at the ORBIT FREQUENCY
 
payload_amp = 1.5;   % N    [NEW] payload oscillation amplitude (not in the Appendix)
wind_amp    = 1.0;   % N    [NEW] mean wind force

assignin('base','R_traj',        R_traj);
assignin('base','w_traj',        w_traj);
assignin('base','payload_sigma', payload_sigma);
assignin('base','payload_amp',   payload_amp);
assignin('base','wind_amp',      wind_amp);

% *** MANDATORY: rebuild A_do for the new sigma ***
% init builds A_do ONCE with the old sigma (0.625). Changing payload_sigma
% without rebuilding leaves the DO internal model oscillating at the old
% frequency, and DO then estimates ~0.
% Rebuild ALL the DO matrices for the new sigma. This used to rebuild only A_do
% with the 6-state formula, so with do_harm = [1 3] it left a 6x6 A_do beside a
% 12x6 l_gain - a size error, or worse, something that runs and is wrong.
evalin('base', ['[A_do, B_do, l_gain, do_info] = build_do_matrices(' ...
                'payload_sigma, do_harm, l_axis); ' ...
                'do_w = [do_info.do_w_axis{1}(:); do_info.do_w_axis{2}(:); ' ...
                'do_info.do_w_axis{3}(:)]; ' ...
                'n_state_axis = do_info.n_ax_state(:);']);
% The check is op_condition's, not a third copy of it.
%
% This line used to read min(abs(imag(eig(A_do)))) == payload_sigma. That is the
% idiom op_condition documents as ALWAYS FAILING once do_harm contains a DC
% block, because that block has eigenvalue 0; it passed here only because this
% function runs the baseline, where do_harm = 1. init_MOBADC_params carried the
% same copy and now calls op_condition too. Three copies of one check, two of
% them alive only by accident of configuration, is how a broken check comes
% back.
Cb = op_condition('Quiet', true);
fprintf('DO internal model: eig(A_do) = +-j%.4f  | sigma = w_traj = %.4f rad/s\n', ...
        max(Cb.A_do_f), w_traj);

%% ---------------- Gates, before spending 4 x 200 s ----------------
fprintf('\n=== CHECKS BEFORE RUNNING ===\n');
model_contract();                 % stops outright if any condition is misreported
if ~sync_eml_blocks()             % the code in the .slx vs simulink_blocks/
    error('run_baseline:drift', ...
        ['The code inside baseline1.slx does NOT match simulink_blocks/. The\n' ...
         'numbers produced would not be reproducible from the source in git.\n' ...
         'Synchronise the two and run again.']);
end

STOP = 200;  T_STAT = 140;  T_orbit = 2*pi/w_traj;
 
%% ---------------- 4 configurations (3 Manual Switches) ----------------
SW = {[mdl '/Position_Observers/Manual Switch' ], ...   % d_mf_hat   (DO)
      [mdl '/Position_Observers/Manual Switch1'], ...   % d_lf_hat   (position ESO)
      [mdl '/Attitude_Observer/Manual Switch2' ]};      % d_ltau_hat (attitude ESO)
 
% Note the ASYMMETRY: 'ESO' has the attitude ESO, 'DO' does not -> they are TWO
% DIFFERENT variants, and this must be declared explicitly in the paper.
% sweep_field_benchmark preserves the same definitions, so the two tables stay
% comparable.
cfg(1) = struct('name','Classical','tag','(b) Classical method','sw',{{'0','0','0'}});
cfg(2) = struct('name','ESO',      'tag','(c) ESO only',        'sw',{{'0','1','1'}});
cfg(3) = struct('name','DO',       'tag','(d) DO only',         'sw',{{'1','0','0'}});
cfg(4) = struct('name','MOBADC',   'tag','(e) MOBADC',          'sw',{{'1','1','1'}});
 
%% ---------------- Run ----------------
R = struct();
R.cfg_used = struct('R_traj',R_traj, 'V_traj',V_traj, 'w_traj',w_traj, ...
                    'payload_sigma',payload_sigma, 'payload_amp',payload_amp, ...
                    'wind_amp',wind_amp, ...
                    'STOP',STOP, 'T_STAT',T_STAT, 'solver','ode4', 'ts',1e-3, ...
                    'when',datestr(now));
 
for k = 1:4
    for i = 1:3, set_param(SW{i},'sw',cfg(k).sw{i}); end
 
    fprintf('Running %-9s (%d s, ode4/1e-3) ... ', cfg(k).name, STOP);
    o = sim(mdl,'StopTime',num2str(STOP),'Solver','ode4','FixedStep','1e-3');
 
    N = cfg(k).name;
    R.(N).t      = o.gamma_log.time;
    R.(N).gamma  = toN3(o.gamma_log.signals.values);
    R.(N).gammad = toN3(o.gammad_log.signals.values);
 
    % ---- the metric EXACTLY as in Sec 4.3: gamma_bar = mean(||gamma - gamma_d||) ----
    en  = sqrt(sum((R.(N).gamma - R.(N).gammad).^2, 2));
    msk = R.(N).t >= T_STAT;
    R.(N).mean = mean(en(msk));
    R.(N).std  = std(en(msk));
    R.(N).max  = max(en(msk));
 
    % ---- cross-check against the model's own err_inst ----
    try
        te = o.err_inst.time;  e_blk = o.err_inst.signals.values(:);
        mb = te >= T_STAT;  m_blk = mean(e_blk(mb));
        dm = 100*(m_blk - R.(N).mean)/R.(N).mean;
        R.(N).err_inst_mean = m_blk;  R.(N).err_inst_dev_pct = dm;
        if abs(dm) > 1
            warning('run_baseline:metric', ...
              '[%s] err_inst DIFFERS by %+.1f%% from Sec 4.3 (%.4f vs %.4f).', ...
              N, dm, m_blk, R.(N).mean);
        end
    catch
        R.(N).err_inst_mean = NaN;
    end
 
    % ---- attitude log, for do_tau ----
    try
        R.(N).tau_data = struct('t', R.(N).t, ...
                                'eta',   toN3(getval(o,'eta_log')), ...
                                'eta_d', toN3(getval(o,'eta_d_log')), ...
                                'sigma', w_traj);
    catch
        R.(N).tau_data = [];
    end
 
    fprintf('mean = %.4f | STD = %.4f\n', R.(N).mean, R.(N).std);
end
 
%% ---------------- A Table 1 - style table ----------------
% The variable is called TBL and not L: L is the tether length in the base
% workspace, and reusing that name here would only mislead a reader.
E   = expected_baseline();
TBL = {};
TBL{end+1} = sprintf('# Test 4-Circling (BASELINE: sinusoid + constant wind), steady-state t in [%g,%g] s', T_STAT, STOP);
TBL{end+1} = sprintf('# r=%.2f m, v=%.2f m/s, w=sigma=%.4f rad/s, T_orbit=%.2f s', ...
                     R_traj, V_traj, w_traj, T_orbit);
TBL{end+1} = sprintf('# payload_amp=%.2f N, wind_amp=%.2f N, moment disturbance: out of scope', ...
                     payload_amp, wind_amp);
TBL{end+1} = sprintf('  %-10s %-10s %-10s %-10s','','Mean (m)','STD (m)','Max (m)');
for k = 1:4
    N = cfg(k).name;
    TBL{end+1} = sprintf('  %-10s %-10.4f %-10.4f %-10.4f', N, R.(N).mean, R.(N).std, R.(N).max); %#ok<AGROW>
end
imp = @(a,b) 100*(a-b)/a;
TBL{end+1} = sprintf('  MOBADC improvement vs Classical: mean %.2f%% | STD %.2f%%', ...
        imp(R.Classical.mean,R.MOBADC.mean), imp(R.Classical.std,R.MOBADC.std));

% --- comparison against the previous run (the regression gate) ---
%
% expected_baseline holds the CONSTANT-WIND numbers. With a wind series on, the
% plant runs a completely different disturbance and this comparison is no longer
% a regression test - it is measuring "how much fluctuating wind differs from
% constant wind".
%
% This actually happened: I ran wind_sim_load and then run_baseline and expected
% the four numbers to be unchanged. All four reported *** MISMATCH *** and it
% looked exactly like a broken regression, when it was only the wind series
% being on. So the table now says this itself instead of leaving the reader to
% infer it.
bad = {};
ws_on = 0;
if evalin('base', 'exist(''wind_series_on'',''var'')')
    ws_on = double(evalin('base', 'wind_series_on'));
end
TBL{end+1} = '';
if ws_on
    TBL{end+1} = '  --- Comparison against expected_baseline.m: SKIPPED ---';
    TBL{end+1} = sprintf(['  wind_series_on = %g, i.e. the plant is running a WIND ' ...
        'SERIES, not constant wind.'], ws_on);
    TBL{end+1} = '  expected_baseline holds the constant-wind numbers, so comparing here';
    TBL{end+1} = '  is MEANINGLESS - a difference is expected and is not a regression.';
    TBL{end+1} = '  The real regression test:  run_baseline   (default ''Wind'',0)';
else
    TBL{end+1} = '  --- Comparison against expected_baseline.m (regression gate) ---';
    for k = 1:4
        N   = cfg(k).name;
        ref = E.repro.(N).mean;
        tol = max(E.tol_abs, E.tol_rel*ref);
        if abs(R.(N).mean - ref) < tol
            v = 'matches';
        else
            v = '*** MISMATCH ***';  bad{end+1} = N; %#ok<AGROW>
        end
        TBL{end+1} = sprintf('  %-10s %.4f vs %.4f (tol %.4f)  %s', ...
                             N, R.(N).mean, ref, tol, v); %#ok<AGROW>
    end
end
% NaN, not 1.
%
% This used to return 1 even when the comparison block HAD NOT RUN AT ALL (the
% wind series being on). A gate that reports "ok" while not running is worse
% than no gate, and I nearly believed exactly such a regression_ok: 1 line.
if ws_on
    R.regression_ok = NaN;          % could not run; not the same as passed
else
    R.regression_ok = double(isempty(bad));
end
R.regression_bad = {bad{:}};

% --- comparison against the published table, including the ORDER check ---
TBL{end+1} = '';
TBL = [TBL, check_paper_divergence(R)];

% --- the limits of the steady-state window ---
TBL{end+1} = '';
TBL{end+1} = '  --- Limits of the steady-state window ---';
TBL{end+1} = sprintf(['  The slowest pole of the DO error dynamics is -0.0357 1/s ' ...
                      '(tau = 28.0 s), so at']);
TBL{end+1} = sprintf(['  T_STAT = %g s about 0.68%% of the transient remains. Effects ' ...
                      'smaller than ~2%%'], T_STAT);
TBL{end+1} = '  cannot be separated from that residual. (docs/devlog/AUDIT.md, D1.)';

fprintf('\n%s\n', strjoin(TBL, newline));
 
%% ---------------- Analytic cross-check ----------------
m_ = 1.121;  Ky_ = 12;  Kv_ = 8;
Hd = 1/abs((1i*w_traj)^2 + Kv_*(1i*w_traj) + Ky_);   % = 1/15.79 tai w=1.575
fprintf('\n=== ANALYTIC CROSS-CHECK (baseline: sinusoid + wind) ===\n');
 
% --- wind: near-CONSTANT in the world frame -> use the DC gain 1/Ky ---
%
% With a wind series on, the mean force is no longer wind_amp. What is needed is
% the magnitude of the MEAN VECTOR, ||K_w * mean(w)||, and NOT K_w * mean||w||:
% the two differ by exactly the fluctuating part (Jensen's inequality), and
% taking the second is the error I made at §0.5 of W6_INTEGRATION.
d_dc  = wind_amp;  psi = deg2rad(40);  src = 'constant wind';
if ws_on && evalin('base','exist(''wind_ts'',''var'')')
    wts   = evalin('base','wind_ts');
    ww    = wts.signals.values(wts.time >= T_STAT, :);   % the SAME window as the table
    mw    = mean(ww, 1);                                 % VECTO trung binh
    Kw_   = evalin('base','K_w');
    d_dc  = norm(Kw_*mw);
    psi   = atan2(mw(2), mw(1));
    src   = sprintf('wind series over [%g, %g] s, ||K_w*mean(w)||', T_STAT, STOP);
    fprintf(['  (K_w*mean||w|| = %.4f N - NOT used here. The two quantities\n' ...
             '   differ by exactly the fluctuating part; see W6_INTEGRATION §0.5.)\n'], ...
            Kw_*mean(sqrt(sum(ww.^2, 2))));
end
e_wind = d_dc/(m_*Ky_);
fprintf('  wind %.4f N (DC, %s)\n', d_dc, src);
fprintf('    e = d/(m*Ky) = %.4f  | DO-only = %.4f  (differs %+.1f%%)\n', ...
        e_wind, R.DO.mean, 100*(R.DO.mean-e_wind)/e_wind);
 
% --- single-axis sinusoidal payload: d_mf = [0; A*sin(sigma*t); 0] -> mean(|sin|) = 2A/pi ---
e_pay = (2/pi) * (payload_amp/m_) * Hd;
fprintf('  payload %.1f N sin @%.3f (1 axis): e = (2/pi)*A/m*|H| = %.4f  | ESO-only = %.4f  (differs %+.1f%%)\n', ...
        payload_amp, w_traj, e_pay, R.ESO.mean, 100*(R.ESO.mean-e_pay)/e_pay);
 
% --- superposition ---
% The metric is mean(||e||_2) over 3 axes. The wind error is a CONSTANT VECTOR
% at 40 deg; the payload error is an oscillation along the y axis. Combining
% them means adding the VECTORS first, then taking the norm, then the mean - not
% the hypot of two scalar means. An earlier version used hypot and obtained
% 0.0938 against Classical 0.0939, which looked like very strong confirmation;
% it was an ARITHMETIC COINCIDENCE, not evidence. See docs/devlog/AUDIT.md, D2.
tt   = (0:1e-3:60).';
e_w  = e_wind*[cos(psi), sin(psi)];   % psi set above: 40 deg, or the real direction
e_p  = (payload_amp/m_)*Hd*sin(w_traj*tt);
sup  = mean(sqrt(e_w(1)^2 + (e_w(2) + e_p).^2));
fprintf('  VECTOR superposition: mean||e_wind + e_payload|| = %.4f  | Classical = %.4f  (differs %+.1f%%)\n', ...
        sup, R.Classical.mean, 100*(R.Classical.mean-sup)/sup);
fprintf('    (the old hypot(DO,ESO) = %.4f - dropped: geometrically wrong)\n', ...
        hypot(R.DO.mean, R.ESO.mean));
fprintf('  The ONLY row derivable from the Appendix is wind: 0.0743 vs the published 0.0725 (1.7%%).\n');
fprintf('  (The published Classical = 0.1502 would need a payload force of ~2.33 N\n');
fprintf('   / a 27 deg tether angle, and is NOT derivable, because that work does\n');
fprintf('   not publish L, the swing amplitude, or the wind force. See R3.4.)\n');
 
%% ---------------- Figure + save ----------------
fh = figure('Name','Baseline Test 4 - Trajectories','Color','w','Position',[80 80 900 840]);
for k = 1:4
    d = R.(cfg(k).name);
    idx = d.t >= T_STAT & d.t <= T_STAT + 3*T_orbit;
    subplot(2,2,k); hold on; grid on; box on;
    plot(d.gammad(idx,1), d.gammad(idx,2), 'r--', 'LineWidth', 1.4);
    plot(d.gamma(idx,1),  d.gamma(idx,2),  'b-',  'LineWidth', 1.1);
    ii = find(idx,1);
    plot(d.gamma(ii,1), d.gamma(ii,2), 'g.', 'MarkerSize', 20);
    axis equal; xlim([-1.2 1.2]); ylim([-1.2 1.2]);
    xlabel('x (m)'); ylabel('y (m)'); title(cfg(k).tag,'Interpreter','none');
    text(0,0,cfg(k).name,'HorizontalAlignment','center','FontWeight','bold','Color',[0 0 0.7]);
    if k==1, legend({'Desired','Actual','Start'},'Location','southoutside','Orientation','horizontal'); end
end
sgtitle(sprintf('Baseline Test 4: v=%.2f m/s, sigma=%.3f rad/s (sinusoid + constant wind)', ...
        V_traj, w_traj), 'Interpreter','none');
 
saveas(fh, 'baseline_trajectories.png');
savefig(fh, 'baseline_trajectories.fig');
fid = fopen('baseline_table.txt','w'); fprintf(fid,'%s\n',strjoin(TBL,newline)); fclose(fid);
save('baseline_results.mat','R','cfg');
if ws_on
    fprintf(['\n  !! THE REGRESSION GATE DID NOT RUN (''Wind'',%g).\n' ...
             '     R.regression_ok = NaN, NOT 1. The four numbers above depend\n' ...
             '     on the wind series that is loaded, so two runs with two\n' ...
             '     different series give two different sets of numbers, and\n' ...
             '     neither is a regression test.\n' ...
             '     The real gate:  run_baseline\n'], opt.Wind);
end
fprintf('\nSaved: baseline_table.txt, baseline_results.mat, baseline_trajectories.png/.fig\n');
fprintf('The configuration just used: R.cfg_used\n\n');
 
for i = 1:3, set_param(SW{i},'sw','1'); end   % put the switches back to MOBADC

% A GATE MUST BE ABLE TO STOP, not merely print.
%
% This used to print '*** MISMATCH ***' in the middle of a long table and then
% return normally. A gate that does not stop is not a gate - the person running
% it scrolls past and carries on, and that is exactly what happened in phase 0b.
%
% Every artefact has already been written before this line, so they can still be
% opened and inspected.
if opt.Strict && ~ws_on && R.regression_ok ~= 1
    error('run_baseline:regression', '%s', sprintf( ...
        ['THE REGRESSION GATE FAILED on %d rows: %s\n\n' ...
         'Which rows MATCH and which FAIL usually names the culprit:\n' ...
         '  Classical and DO have Manual Switch1 = ''0'' (they do not read dlf_hat)\n' ...
         '  ESO and MOBADC  have Manual Switch1 = ''1'' (they DO read dlf_hat)\n' ...
         'Only the latter two failing -> suspect the dlf_hat path first, i.e. an\n' ...
         'extension left on in the base workspace. reset_extensions ran at the\n' ...
         'top of this function and printed what it turned off - re-read that line.\n' ...
         'All four failing -> the plant or a parameter really has changed.\n\n' ...
         'If you are DELIBERATELY editing the model and know what you are doing:\n' ...
         '    run_baseline(''Strict'', false)'], ...
        numel(R.regression_bad), strjoin(R.regression_bad, ', ')));
end
end
 
%% ================= helpers =================
function A = toN3(V)
if isstruct(V) && isfield(V,'signals'), V = V.signals.values; end
if isa(V,'timeseries'), V = V.Data; end
A = squeeze(V);
if size(A,2) ~= 3, A = A.'; end
end
 
function v = getval(o, name)
if isprop(o,name) || (isstruct(o) && isfield(o,name)), v = o.(name);
else, v = evalin('base', name); end
end
 