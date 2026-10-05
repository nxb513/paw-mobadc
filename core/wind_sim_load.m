function info = wind_sim_load(matfile, series_on, varargin)
%WIND_SIM_LOAD  Load an exported wind series into the base workspace for Simulink.
%
%   wind_sim_load('wind_sim_t150.mat')       % wind series on
%   wind_sim_load('wind_sim_t150.mat', 0)    % off - reproduce the baseline
%   wind_sim_load(..., 'MatchMean', true)    % normalise the mean force to wind_amp
%
%  ======================================================================
%  'MatchMean' - AND WHY wind_amp IS NOT THE WAY TO DO IT
%  ======================================================================
%  A dataset run does not have a mean |w| exactly equal to V_ref = 5 m/s (the
%  first run measured 5.285), so its mean force is 1.057 N rather than 1.0. When
%  "constant wind" is compared with "wind series", part of the degradation is
%  then due to the larger AMPLITUDE rather than to the time variation - measured
%  at 41% on the DO row.
%
%  The WRONG way, which I recommended at first:
%      assignin('base','wind_amp', 1.0571)
%  run_baseline assigns wind_amp = 1.0 and then pushes it into base itself, so
%  that assignment has NO EFFECT and the table prints exactly as before.
%
%  The right way: adjust K_w, which run_baseline does not touch. Setting
%      K_w = wind_amp / mean|w|
%  makes the mean force of the wind series exactly wind_amp, so the
%  constant-versus-series comparison differs only in TIME STRUCTURE.
%
%  This is a normalisation FOR COMPARISON, not a production value. The function
%  says plainly that it changed K_w, and records it in info.match_mean.
%
%  Note that this is a deliberate exception to the rule in wind_to_force that
%  K_w is derived and locked: PROTOCOL_LOCK stores the NOMINAL K_w = 0.2, and
%  no table in the paper is produced with MatchMean on.
%
%  Placed into the base workspace:
%     wind_ts          time/signals struct for the plant's From Workspace block
%     what_ts          time/signals struct for the PREDICTION (used in W6.1)
%     K_w              wind -> force coefficient, from wind_to_force([])
%     wind_series_on   0/1
%     wind_tau_ms      the horizon of the checkpoint in use
%     wind_valid_from  the time from which a prediction exists (s)
%
%  ======================================================================
%  RUN verify_wind_force FIRST
%  ======================================================================
%  This function does NOT check the file contents - it only loads. The checks
%  live in verification/verify_wind_force.m (14 of them), and they have already
%  caught a real fault: an int64 scalar made MATLAB compute
%  k = round(tau*1e-3*fs) as 0 instead of 3, turning the "predictor" into
%  persistence with nothing reporting an error.
%
%  ======================================================================
%  WHY NOT A timeseries
%  ======================================================================
%  A From Workspace block accepts both a timeseries and a time/signals struct.
%  The struct is used because it carries no Simulink dependency when the file is
%  read elsewhere, and because the field names are visible the moment the
%  variable name is typed.

if nargin < 1, error('wind_sim_load: a path to an exported .mat is required.'); end
if nargin < 2 || isempty(series_on), series_on = 1; end
opt = struct('MatchMean', false, 'MeanOnly', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
assert(exist(matfile,'file') == 2, 'wind_sim_load: cannot find %s', matfile);

S = load(matfile);

% Cast to double IMMEDIATELY on read. savemat stores Python ints as int64, and
% MATLAB then does INTEGER ARITHMETIC on them: int64(150)*1e-3 = 0, with no
% warning at all.
for f = {'tau_ms','fs','plant_fs','window_s','t_valid_from','duration_s', ...
         'wind_type','index','seed','stride','mean_dir_deg'}
    if isfield(S, f{1}), S.(f{1}) = double(S.(f{1})); end
end

[d_ref, K_w] = wind_to_force([5.0; 0; 0]);
wind_amp_ref = norm(d_ref);              % = 1.0 N, tu chinh wind_to_force
K_w_nominal  = K_w;
mean_w = mean(sqrt(sum(S.w_plant.^2, 2)));
if opt.MatchMean
    K_w = wind_amp_ref / mean_w;
end

% 'MeanOnly': replace the series with its own MEAN VECTOR, repeated.
%
% This is the CONTROL for the "constant versus time-varying" comparison. The old
% baseline (disturbance_generator) puts constant wind at a HARDCODED
% psi_w = 40 deg, while the dataset series has its own direction (14.3 deg on
% the first run). The payload disturbance oscillates along a fixed Y axis, so
% the RELATIVE ANGLE between wind and payload has a real effect:
%
%   wind angle   mean||e||   STD||e||   (analytic, 1.0 N mean force)
%     40 deg      0.0901      0.0316
%     14.3 deg    0.0939      0.0171     <- STD lower by 46%
%
% So the change of direction alone accounts for the ENTIRE drop in STD that I
% was about to attribute to turbulence. See §0.5 - my "isotropic" argument holds
% only for wind ON ITS OWN.
%
% With 'MeanOnly' the control goes through the SAME path, the SAME direction and
% the SAME magnitude, and differs only in having no time variation.
w_plant = S.w_plant;
if opt.MeanOnly
    w_plant = repmat(mean(w_plant, 1), size(w_plant, 1), 1);
end

wind_ts = struct('time', S.t_plant, ...
                 'signals', struct('values', w_plant, 'dimensions', 3));
assignin('base', 'wind_ts', wind_ts);
assignin('base', 'K_w', K_w);
assignin('base', 'wind_series_on', double(series_on));

% ---- MEASURED wind (E1b) ----
%
% If the file carries w_meas, then the PI-MoE inside that file was fed exactly
% that series (the noise was applied before the model saw it - see
% export_wind_sim.py). The sensor branch must be fed THE SAME series and must
% not generate a different realisation; otherwise the two branches are compared
% across two different noise realisations and part of the difference comes from
% that.
%
% No w_meas -> wind_meas_ts = wind_ts. sweep_sensor_noise (E1a) still adds its
% own noise afterwards, and that is the E1a path; the two do not collide,
% because E1a runs only on files that have NO w_meas.
if isfield(S, 'w_meas')
    wm = double(S.w_meas);
    assert(size(wm,1) == size(S.t,1), ...
        ['wind_sim_load: w_meas has %d samples but t has %d. w_meas lives on ' ...
         'the SENSOR grid (fs), not on the plant grid.'], ...
        size(wm,1), size(S.t,1));
    % No rescaling for MatchMean: MatchMean changes the COEFFICIENT K_w and
    % does not touch the wind series. wind_meas_ts carries raw wind [m/s]
    % exactly as wind_ts does, and WM_Kw applies K_w downstream - the same K_w
    % for both branches.
    wind_meas_ts = struct('time', double(S.t), ...
                          'signals', struct('values', wm, 'dimensions', 3));
    sg = 0; bi = 0;
    if isfield(S,'sensor_noise'), sg = double(S.sensor_noise); end
    if isfield(S,'sensor_bias'),  bi = double(S.sensor_bias);  end
    fprintf('  MEASURED wind from file: sigma %.3f, bias %.3f m/s (the PI-MoE was fed this series)\n', sg, bi);
else
    wind_meas_ts = wind_ts;
end
assignin('base', 'wind_meas_ts', wind_meas_ts);
assignin('base', 'wind_meas_from_file', double(isfield(S, 'w_meas')));

info = struct('file', matfile, 'wind_type', S.wind_type, 'seed', S.seed, ...
              'duration_s', S.duration_s, 'fs', S.fs, 'K_w', K_w, ...
              'K_w_nominal', K_w_nominal, 'mean_w', mean_w, ...
              'match_mean', opt.MatchMean, 'mean_only', opt.MeanOnly, ...
              'series_on', double(series_on));

% "Which wind is running" has to be the FIRST line. The same measurement gives
% results of OPPOSITE SIGN on short-tau Dryden (negative skill) and on real wind
% (+0.157 at tau = 150 ms), so confusing the two means reading the wrong
% conclusion.
if isfield(S, 'source') && strcmp(strtrim(char(S.source)), 'real_m5')
    fprintf('wind_sim_load: REAL M5 WIND %s #%d, %g s @ %g Hz\n', ...
            strtrim(char(S.split)), double(S.index), S.duration_s, S.fs);
    fprintf('  %s  z = %g m  +%g s   U = %.2f m/s  I = %.1f%%\n', ...
            strtrim(char(S.real_file)), double(S.real_height_m), ...
            double(S.real_offset_s), double(S.real_U), 100*double(S.real_I));
    if strcmp(strtrim(char(S.split)), 'heldout')
        fprintf('  ! HELD-OUT SET - for the paper''s final numbers only.\n');
    end
    info_source = 'real_m5';
else
    fprintf('wind_sim_load: SYNTHETIC loai %d seed %d, %g s @ %g Hz\n', ...
            S.wind_type, S.seed, S.duration_s, S.fs);
    info_source = 'synthetic';
end
info.source = info_source;
fprintf('  reference wind direction %.1f deg%s\n', S.mean_dir_deg, ...
        ternary(isfield(S,'rotated') && S.rotated, '  (ROTATED)', ''));
fprintf('  mean |w| = %.4f m/s\n', mean_w);
if opt.MatchMean
    fprintf(['  K_w = %.5f  (NORMALISED from %.4f so the mean force = %.4f N)\n' ...
             '  -> the constant-versus-series comparison now differs only in\n' ...
             '     TIME STRUCTURE. This is a normalisation for comparison, not\n' ...
             '     a production value.\n'], K_w, K_w_nominal, K_w*mean_w);
else
    fprintf('  K_w = %.4f N/(m/s)   mean |d_lf| = %.4f N', K_w, K_w*mean_w);
    if abs(K_w*mean_w - wind_amp_ref) > 0.02*wind_amp_ref
        fprintf('   (%+.1f%% from wind_amp = %.1f N)', ...
                100*(K_w*mean_w - wind_amp_ref)/wind_amp_ref, wind_amp_ref);
    end
    fprintf('\n');
    % Real wind: U differs from segment to segment (7-12 m/s is common), so the
    % mean force differs too. Comparing tracking error ACROSS segments then
    % compares AMPLITUDE as well as STRUCTURE, and the table reports "this
    % segment is worse" when the wind was simply stronger. With synthetic wind U
    % is fixed, so this does not arise.
    if strcmp(info_source, 'real_m5') && ...
       abs(K_w*mean_w - wind_amp_ref) > 0.02*wind_amp_ref
        fprintf(['  ! REAL WIND: U differs per segment. To compare ACROSS\n' ...
                 '  ! segments, or against the 1.0 N baseline, use\n' ...
                 '  ! ''MatchMean'', true.\n']);
    end
end
if opt.MeanOnly
    fprintf(['  MeanOnly: the series was replaced by its repeated MEAN VECTOR.\n' ...
             '  -> a control with the same direction and magnitude and NO time\n' ...
             '     variation.\n']);
end
fprintf('  wind_series_on = %d%s\n', double(series_on), ...
        ternary(series_on == 0, '   <- REPRODUCING THE BASELINE', ''));

if isfield(S, 'w_hat')
    % ==================================================================
    % TWO THINGS THAT MUST BE RIGHT ABOUT THE PREDICTION SERIES
    % ==================================================================
    %
    % 1. HOLD, DO NOT INTERPOLATE. The From Workspace block must be set to
    %    'Interpolate','off'. Linear interpolation between samples k and k+1
    %    uses w_hat_{k+1}, and that sample only EXISTS at t_{k+1} > t. So
    %    interpolating here is NON-CAUSAL: the controller reads a prediction
    %    that has not been produced yet. Nothing reports an error, and the W7
    %    table would improve artificially. verify_wind_predictor checks exactly
    %    this.
    %
    %    (The PLANT wind series is the opposite: LINEAR interpolation, because
    %    real wind is continuous and a 20 Hz staircase is not physical.)
    %
    % 2. BEFORE t_valid_from THERE IS NO PREDICTION. The 30 s window is not yet
    %    full. With no sample at t = 0, the From Workspace block has to handle
    %    [0, 30) itself - and depending on configuration it may EXTRAPOLATE from
    %    the first two samples, producing nonsense for the first 30 s.
    %
    %    So that interval is set to ZERO explicitly, with its own validity
    %    signal. Zero rather than "hold the first sample backwards": if W6.3
    %    forgets to use the validity switch, zero makes the controller not
    %    compensate the wind at all - a VISIBLE and safe failure - whereas a
    %    plausible value would look like a real prediction.
    t_pred = S.t_pred(:);
    if t_pred(1) > 0
        tw = [0; t_pred];
        vw = [zeros(1, 3); S.w_hat];
    else
        tw = t_pred;
        vw = S.w_hat;
    end
    what_ts = struct('time', tw, ...
                     'signals', struct('values', vw, 'dimensions', 3));
    assignin('base', 'what_ts', what_ts);

    % The validity signal: 0 before t_valid_from, 1 from then on. Also HELD,
    % not interpolated. W6.3 uses it to fall back to the ordinary DO path over
    % the opening interval.
    wvalid_ts = struct('time', [0; double(S.t_valid_from)], ...
                       'signals', struct('values', [0; 1], 'dimensions', 1));
    assignin('base', 'wvalid_ts', wvalid_ts);

    % ==================================================================
    % ORACLE: the TRUE wind at t+tau. The absolute ceiling of any predictor.
    % ==================================================================
    % The whole "predict to compensate the lag" framing rests on an assumption
    % NOBODY HAD MEASURED on the wind channel: that a commanded force at t only
    % appears on the force path after about tau, so the controller needs
    % d(t+tau) rather than d(t). That lag is real on the payload branch
    % (measured at 140 ms), but d_lf enters translational_dynamics DIRECTLY -
    % any lag there belongs to the ATTITUDE loop realising the commanded force,
    % and that is an approximation.
    %
    % This branch tests the assumption instead of arguing it: give the
    % controller the TRUE wind at t+tau. If that is NOT better than the sensor
    % branch (true wind at t), then compensating tau ahead does not help, and
    % the whole "prediction" direction on the wind channel is misplaced - no
    % matter how strong PI-MoE is. If it is better, the difference is the
    % CEILING of PI-MoE on tracking error, and the W7 table must report that
    % ceiling too.
    %
    % This is an unrealisable control (nobody knows the wind in advance) and
    % exists only to MEASURE. The paper must say so explicitly.
    %
    % It was measured, three times, and the answer was that the ceiling is close
    % to zero: column O beats the sensor by +0.3% on the confirmation set. That
    % measurement is why the learned wind predictor is reported as a negative
    % ablation rather than as a contribution.
    kk = round(double(S.tau_ms)*1e-3*S.fs);
    wo = S.w_plant([1+kk:end, repmat(size(S.w_plant,1), 1, kk)], :);
    w_oracle_ts = struct('time', S.t_plant, ...
                         'signals', struct('values', wo, 'dimensions', 3));
    assignin('base', 'w_oracle_ts', w_oracle_ts);
    fprintf('  oracle: TRUE wind shifted forward by %d samples (= %g ms)\n', kk, S.tau_ms);
    assignin('base', 'wind_tau_ms', S.tau_ms);
    assignin('base', 'wind_valid_from', S.t_valid_from);
    info.tau_ms = S.tau_ms;
    fprintf('  prediction: tau = %g ms, available from t = %.1f s (%d samples)\n', ...
            S.tau_ms, S.t_valid_from, numel(S.t_pred));
    fprintf('  skill of this series = %+.4f\n', S.skill_check);
else
    fprintf('  (no prediction in the file - true wind only)\n');
end

%% ---- 'MeanOnly' must apply to EVERY wind path, not only to the body ----
%
% The trap: wind_meas_ts is built from S.w_meas (the file), w_oracle_ts from
% S.w_plant (the file), and what_ts from S.w_hat (the file) - ALL THREE read
% straight from the file and do NOT pass through the w_plant variable that
% MeanOnly modified. So modifying only the body path would give:
%       body     = CONSTANT wind
%       sensor   = FLUCTUATING wind    <- inconsistent
%       oracle   = FLUCTUATING wind    <- inconsistent
% The sensor branch would then compensate a fluctuation THAT DOES NOT EXIST on
% the body, and the result would look like a large effect when it is purely an
% artefact.
%
% MeanOnly has to mean "the same realisation with the time variation removed" -
% on BOTH sides of every comparison. With constant body wind the future wind IS
% that constant, so oracle = mean is exactly right, not an approximation.
%
% what_ts is a separate matter: the PI-MoE has never seen constant wind, so the
% prediction branch is MEANINGLESS under MeanOnly. It is still set to the mean
% for consistency, and the function says so - MeanOnly is a DIAGNOSTIC control
% and is only valid with wind_use_pred = 0.
if opt.MeanOnly
    for v = {'wind_meas_ts','w_oracle_ts','what_ts'}
        if evalin('base', sprintf('exist(''%s'',''var'')', v{1}))
            evalin('base', sprintf(['%s.signals.values = repmat(' ...
                'mean(%s.signals.values, 1), size(%s.signals.values, 1), 1);'], ...
                v{1}, v{1}, v{1}));
        end
    end
    fprintf(['  MeanOnly: sensor, oracle AND prediction were all set to the mean.\n' ...
             '    ! diagnostic control - valid only with wind_use_pred = 0.\n']);
end
end


function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
