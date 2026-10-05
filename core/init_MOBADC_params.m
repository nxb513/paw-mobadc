%% ============================================================
%  init_MOBADC_params.m  --  THE BASELINE (reproducing Guo et al., CEP 2020)
%
%  Purpose: run the original MOBADC on the model 'baseline1.slx'. NO extension
%  of any kind (predictor / Dryden / motor lag / gyro noise / external wind
%  injection). The slung-load pendulum IS in the model but is off by default,
%  through payload_model = 0.
%
%  Expected results: see core/expected_baseline.m - that is the SINGLE source.
%  Do not restate an expected number here; they once lived in three places with
%  two different values and nobody could tell which was true.
%
%  Source convention:
%     [PAPER]   verbatim from Appendix A.1 / A.2 (or a figure of that work)
%     [DERIVED] obtained by formula from [PAPER], with no free parameter
%     [NEW]     added for this simulation, NOT in the reference work
%               -> EVERY [NEW] variable must be declared in our own paper
%
%  ------------------------------------------------------------------
%  WHICH VARIABLES THE MODEL ACTUALLY READS
%  ------------------------------------------------------------------
%  The full list is in core/model_contract.m, checked directly against the
%  Constant blocks of baseline1.slx. Regenerate it with:
%      python3 tools/check_params.py
%  A variable can exist here, be passed into the model, be printed in a table
%  header - and still have no effect at all. That is what happened to amp_tau.
%% ============================================================

%% ==================== PART A - GUO ET AL. 2020 ====================

%% ---- A.1 Physical parameters [PAPER Appendix A.1] ----
m   = 1.121;                              % kg
g   = 9.81;                               % m/s^2  (the paper uses the symbol g and gives no value)
Ixx = 0.01;  Iyy = 0.0082;  Izz = 0.0148; % kg.m^2
d_theta = 0.0879;                         % m   half the motor spacing, pitch axis
d_phi   = 0.1068;                         % m   half the motor spacing, roll axis
c_uf = 6.12e-5;  f_b = -0.2046;  u_b = 0.1922;  c_tauf = 0.00963;

% Force allocation matrix, eq. (2)
Gamma_mix = [ 1        1        1        1;
             -d_phi   -d_phi    d_phi    d_phi;
              d_theta -d_theta  d_theta -d_theta;
              c_tauf  -c_tauf  -c_tauf   c_tauf];

%% ---- A.2 Control and observer gains [PAPER Appendix A.2] ----
Kgamma  = diag([12, 12, 35]);            % K_gamma in (9)
Knu     = diag([8, 8, 18]);              % K_nu    in (9)
K_eta   = diag([2.16, 1.92, 0.59]);      % K_eta   in (18)
K_omega = diag([0.20, 0.12, 0.12]);      % K_omega in (18)

Kp1 = 50*eye(3);  Kp2 = 833*eye(3);  Kp3 = 78*eye(3);    % position ESO, (15)
Kp  = [Kp1, Kp2, Kp3];

% l(gamma,nu) in (12)-(13). Per-axis values, [PAPER Appendix A.2]:
l_axis = [0.10 0.08 0.10];
% (l_gain is used in A.3 together with A_do/B_do - see build_do_matrices.)

% Attitude ESO, (20). za3 estimates the angular ACCELERATION disturbance
% (M^-1*d_ltau), so Ka3 = 3906 is consistent. The moment is recovered as
% d_ltau_hat = M(za1)*za3. Per-axis characteristic polynomial:
% s^3 + 50 s^2 + 833 s + 3906  (Routh satisfied).
Ka1 = 50*eye(3);  Ka2 = 833*eye(3);  Ka3 = 3906*eye(3);
Ka  = [Ka1, Ka2, Ka3];

M0_att = diag([Ixx, Iyy, Izz]);          % M0 (Assumption 4) for the attitude ESO

% Gain-name aliases: the first parameter file used Ky/Kv. Kept so the model
% runs whichever name it references. baseline1.slx reads Kgamma/Knu, so this
% line is currently redundant - kept because it is harmless. Same for
% Kp/Ka/M0_att: the model reads Kp1..3 / Ka1..3 / Ixx..Izz individually, and
% these three grouped variables exist only to make the formulas read like the
% paper.
Ky = Kgamma;  Kv = Knu;

%% ---- A.3 The DO exosystem, eq. (6) & (12) ----
% sigma is an ANGULAR frequency (rad/s), NOT Hz.
%   Circular flight: sigma = w_orbit = v/R
%              Test 2   v=0.50 m/s, R=0.8 -> 0.625 rad/s
%              Test 3/4 v=1.26 m/s, R=0.8 -> 1.575 rad/s
%   (The paper writes "sigma ~ 0.25 s^-1" = 0.25 Hz -> 2*pi*0.25 = 1.575 rad/s.
%    That 2*pi dimensional inconsistency is anomaly #1, recorded in Section 2.)
payload_sigma = 0.625;                    % rad/s - Test 2 default
                                          % (run_test4 rebuilds A_do for Test 3/4)

% HARMONIC internal model. The vector do_harm lists which multiples of
% payload_sigma the DO's internal model contains.
%
%   do_harm = 1      ->  6 states. THE ORIGINAL GUO CONFIGURATION, and what
%                        this file sets. It is column L0 of every table, and
%                        the regression gate reproduces it exactly.
%   do_harm = [0 1]  -> 12 states. THE CONFIGURATION THAT PRODUCES THE PAPER'S
%                        RESULTS: it adds a DC block to the fundamental. Every
%                        column L1..L3 runs it, and PROTOCOL_LOCK.md records it
%                        as do_harm_pa. It is NOT set here, because this file
%                        is the baseline; the sweeps pass it through
%                        pa_configs('DoHarm', [0 1]).
%   do_harm = [1 3]  -> 12 states. A third-harmonic variant, supported by
%                        build_do_matrices and used by no result in the paper.
%
% Why a third harmonic was considered at all: the measured residual spectrum is
% a SINGLE LINE at 3*sigma carrying ~90% of the energy, and it does NOT move
% when L changes - so it is a multiple of the orbit frequency, generated by the
% pendulum's output nonlinearity (d = T*sin(th), with T containing cos(th) and
% thd^2). Adding the pendulum's own natural frequency sqrt(g/L) is useless -
% 0.0003 N was measured there. See docs/devlog/AUDIT.md section F.
%
% The DC block of [0 1] is a different matter and is the paper's central
% finding: mean wind deflects the load off vertical and produces a CONSTANT
% disturbance component that a purely harmonic internal model cannot represent
% (Section 6, R6.1).
do_harm = 1;

% *** A_do must be REBUILT whenever payload_sigma changes. Build it once and
%     then change the scalar, and the DO internal model keeps oscillating at
%     the old frequency -> DO estimates ~0. ***
[A_do, B_do, l_gain, do_info] = build_do_matrices(payload_sigma, do_harm, l_axis);
G_do  = (1/m)*[zeros(3); eye(3)];

% The frequency of each block, so the predictor knows how far to rotate each.
%
% *** FLAT ACROSS ALL 3 AXES, NOT ONE AXIS'S LIST - Part 3.3. ***
% simulink_blocks/payload_predictor.m's OLD code looped over 3 axes and
% RE-WALKED the same short do_w list for each (do_w = one axis's own
% frequencies). The rewritten function instead walks ONE pointer across ALL
% 3 axes without resetting it (so it can support axes with DIFFERENT
% frequency sets) - which means do_w itself must already be axis1's block in
% full, then axis2's, then axis3's: do_info.do_w_axis concatenated, not
% payload_sigma*do_harm(:) alone. With all 3 axes equal (do_harm's own
% convention) this is simply that list repeated 3 times - and reproducing
% that repetition here, rather than leaving payload_predictor.m to assume it,
% is what keeps the old call path bit-exact.
do_w  = [do_info.do_w_axis{1}(:); do_info.do_w_axis{2}(:); do_info.do_w_axis{3}(:)];

% How many STATES (not do_w entries) belong to each axis - Part 3.3
% (TEST_PLAN_PROMPT.md). All three axes equal here (do_info.n_ax_state is a
% 3x1 with the same value repeated), which is exactly what makes the old,
% uniform-per-axis call path bit-exact under payload_predictor.m's new,
% per-axis-aware reading of do_w.
n_state_axis = do_info.n_ax_state(:);

A_blk = [0 payload_sigma; -payload_sigma 0];   % kept: the run scripts reference it

%% ---- A.4 Disturbance sources [NEW - NOT published in the reference work] ----
% Guo et al. do not report the tether length, the swing amplitude, the wind
% force magnitude, or the wind moment.
% => only the RATIO of improvement is comparable; absolute errors are not.
payload_amp = 1.5;    % N    payload oscillation amplitude (sinusoidal branch, eq. (6))
wind_amp    = 1.0;    % N    mean wind force

% *** THERE IS NO EXTERNAL MOMENT DISTURBANCE. ***
% d_ltau = 0 in disturbance_generator, and that is a DELIBERATE CHOICE: Guo
% 2020 has Assumption 3 for a moment disturbance but publishes neither its
% waveform, nor its amplitude, nor its direction. Inventing a waveform would
% add an unverifiable degree of freedom to the result under the name
% "reproduction".
%
% The scope of this experiment is FORCE disturbance (payload + wind). It must
% be declared explicitly in the paper, together with its consequence: the
% attitude ESO has no external disturbance to reject, so nothing may be claimed
% about rejection of MOMENT disturbances.
%
% (An earlier version had amp_tau = 0.05 N.m here. It was an argument of
%  disturbance_generator that the function body never used - d_ltau = 0
%  whatever its value - while both run scripts printed it in their table
%  header. Removed for good by remove_amp_tau.m. See docs/devlog/AUDIT.md
%  section A1.)

% The wind direction NE 40 deg [PAPER Fig. 8b] is HARDCODED inside
% disturbance_generator (psi_w = 40*pi/180) and is not read from the
% workspace. The earlier R_wind variable was dead and has been removed.
% Changing the wind direction means editing the block.

%% ---- A.5 Trajectory [PAPER 4.2.2 / 4.2.4] ----
% run_test4 overrides R_traj/w_traj/payload_sigma per Test; op_set is the
% named way to do it. The values here are for standalone runs (Test 2 default).
R_traj   = 0.8;       % m      circle radius
w_traj   = 0.625;     % rad/s  = v/R -> v = 0.5 m/s (Test 2)
z0_hover = 1.0;       % m      [NEW] hover altitude

%% ---- A.6 Physical limits [NEW - not given in the reference work] ----
% A QDrone has a thrust-to-weight ratio of ~2, so 4*f_max ~ 2*m*g and
% f_max ~ 5.5-6 N. Hover needs f_i = m*g/4 = 2.749 N < f_max.
f_max  = 6.0;         % N
f_min  = 0.0;         % N    a propeller cannot produce negative thrust
Fz_min = 0.5;         % N    floor on Fz, to avoid the singularity in (16)
F_TOT_MAX = 21.6;     % N    total-thrust command limit = 0.9*4*f_max, read by
                      %      thrust_attitude_ref since GD2b (was a literal there; the
                      %      same double). Plant P2 overrides it in core/p2_setup.m.

%% Payload pendulum

m_p    = 0.5;         % kg   [NEW] payload mass
L      = 1.0;         % m    [NEW] tether length
zeta_p = 0.12;        % -    [NEW] pendulum damping ratio - A FREE PARAMETER,
                      %      with no source and no ablation (AUDIT section C3)

payload_model = 0;    % 0 = sinusoidal payload disturbance (baseline) | 1 = physical pendulum
payload_z_on  = 0;    % 0 = horizontal component only, trim point unchanged

%% ---- Payload disturbance predictor [NEW] ----
% predictor_on = 0 MUST reproduce the baseline digit for digit: when off, the
% signal path goes through the original DO_Out block.
predictor_on = 0;     % 0 = off (baseline) | 1 = on

% The prediction horizon. It equals the EFFECTIVE lag of the attitude loop on
% the force path - the model contains no delay block, but to change horizontal
% force the UAV must tilt:
%     y axis (roll) : wn 14.70 rad/s, zeta 0.680 -> 93 ms at w = 1.575
%     x axis (pitch): wn 15.30 rad/s, zeta 0.478 -> 63 ms
% The two axes differ, so no single value is optimal for both. See
% docs/devlog/AUDIT.md section E and tools/error_budget.py for the analysis.
%
% 0.08 was the ANALYTIC midpoint of the two axes, set before any measurement.
% The value below comes from MEASUREMENT: sweep_tau_eff('payload') sweeps
% tau_pred through the REAL payload predictor (simulink_blocks/
% payload_predictor.m's own internal-model extrapolation of the DO's own
% estimated state, dmf_hat(t+tau) = B*e^{A*tau}*xi_hat - NOT a literal
% future-value injection; that mechanism belongs to the WIND channel's own
% oracle branch, sweep_wind's w_oracle_ts, a different code path) at a
% range of horizons tau', then finds the tau' with the smallest tracking
% error (docs/devlog/W6_INTEGRATION.md §0.31). On circle this happens to be
% exact, because the payload predictor's assumed frequency (w_traj) equals
% circle's own true forcing frequency - see docs/REGISTER_C.md sec 4.53 for
% where that stops being true and why it matters:
%
%     tau'    mean err     vs DO/ESO 0.00485
%     ----    ---------    -----------------------
%      80 ms   0.00158     -67.4%   <- the old analytic value
%     120 ms   0.00079     -83.6%   <- MINIMUM
%
% The curve is V-shaped with symmetric flanks (0.00042 / 0.00043 per 20 ms) -
% the signature of PURE delay, exactly as modelled. And tau' = 0 matches
% predictor_on = 0 digit for digit, which is the sweep's own internal check.
%
% THIS IS A CALIBRATION, NOT TUNING ON THE RESULT. It was measured ONCE with an
% oracle at the operating condition in use, then HELD FIXED for every
% experiment after. Changing it per segment to get a better number would void
% every result.
%
% *** THE EARLIER CLAIM HERE WAS WITHDRAWN - 2026-09-05, §0.54. ***
%
% Until then this line read: "tau_eff is a CONSTANT OF THE SYSTEM (the attitude
% loop dynamics), not of the disturbance or of the wind segment". The argument
% sounded solid: for a lightly damped second-order term the equivalent delay
% ~ 2*zeta/wn is frequency-independent - 93 ms (roll) and 63 ms (pitch),
% unchanged between Test 2 and Test 4.
%
% But measuring it with sweep_tau_eff itself gives tau* = 220 ms at Test 4
% against 120 ms at Test 2. Sigma changes by 2.52 (0.625 -> 1.575) and tau* by
% 1.83. Not a constant - and not a constant phase either (sigma*tau* changes by
% 4.6). So tau_eff DOES depend on the operating condition, and the old claim
% was wrong.
%
% The paper must say "calibrated once at the operating condition", and must NOT
% say "a constant of the system". tools/check_retracted.py blocks the old
% phrasing from returning. The value below is for TEST 2; at Test 4 it is set
% by op_set and was re-measured.
%
% Section 6, R6.3 now derives tau* in closed form from the nominal model
% (tools/tau_star.py) and recovers both measured values to within one 20 ms
% sweep step. That derivation came AFTER these two numbers were known, which is
% why docs/REGISTER_TAU.md registers predictions at conditions never run.
tau_pred = 0.12;      % s   [MEASURED AT TEST 2] Test 4: 220 ms (§0.54)

% Note: wn_p is deliberately NOT declared here. The pendulum block computes
% wn = sqrt(g/L) internally, so assigning wn_p from outside has no effect - it
% would be a dead variable that falsely suggests a parameter is being driven
% from the workspace.

%% ---- EXTENSION variables: guarantee EXISTENCE, do not overwrite ----
%
% The variables below were introduced alongside the build_* scripts, i.e. AFTER
% this file was written. The model reads them from the workspace (the Gain
% block PW_Kwp reads payload_K_ratio, for instance), so a MISSING variable
% stops the simulation immediately with "Invalid setting ... for parameter
% 'Gain'" - which points at no extension in particular.
%
% This actually happened: the WIND branch of sweep_tau_eff died on that line in
% a freshly opened MATLAB, purely because payload_K_ratio had never been set.
% The PAYLOAD branch survived because it called reset_extensions and the wind
% branch did not - an asymmetric patch of my own making.
%
% Set ONLY IF ABSENT. init must NOT overwrite the caller's intent: pa_configs
% calls wind_sim_load (which sets wind_series_on and wind_meas_from_file)
% BEFORE init, and overwriting here would switch the wind series off for all
% 210 runs without a word.
%
% To turn everything off explicitly, use core/reset_extensions.m - that is the
% function for it. This block only patches the "does not exist yet" hole.
if ~exist('wind_pred_on',        'var'), wind_pred_on        = 0; end
if ~exist('wind_use_pred',       'var'), wind_use_pred       = 0; end
if ~exist('wind_series_on',      'var'), wind_series_on      = 0; end
if ~exist('wind_meas_from_file', 'var'), wind_meas_from_file = 0; end
if ~exist('payload_wind_on',     'var'), payload_wind_on     = 0; end
if ~exist('payload_K_ratio',     'var'), payload_K_ratio     = 0; end
if ~exist('payload_inj_on',      'var'), payload_inj_on      = 0; end
% GD2b (docs/devlog/GD2B_DESIGN.md). Set UNCONDITIONALLY, not "if missing": a
% P2 run must never leak into the next v1 run. core/p2_setup.m sets them for P2
% AFTER this script (pa_configs 'PlantModel','p2').
plant_model = 0;      % 0 = v1 plant; 1 = plant P2 (Variant controls, compile time)
p2_poison   = 0;      % B6 poison test only
p2_n6       = 0;      % N6 wind -> payload term (REGISTER_P2 sec 15.4); 1 only with plant_model = 1
p2_cmp      = 0;      % competitors (REGISTER_P2 sec 40): 1 = H3, 2 = H4; only with plant_model = 1
p2_m3       = 0;      % GD8 (iii) pendulum model on the payload channel (REGISTER_P2 sec 45); 1 only with plant_model = 1
p2_trim_ff  = 0;      % known payload weight pre-compensated (REGISTER_P2 sec 47); 1 only with plant_model = 1
p2_trim_ff_v = zeros(3,1);  % its value, set by p2_setup ([0; 0; -m_L g])
p2_trim_do  = [0 0];  % [index, value]: DO trim (P2 hover trim); 0 = none
p2_trim_eso = 0;      % ESO z_p3(3) trim (P2, columns without a DO DC mode)
p2_ic_pos   = zeros(3,1);  % P2 standard initial state (REGISTER_P2 sec 8), set by p2_setup;
p2_ic_vel   = zeros(3,1);  % never read when plant_model = 0
% K_w: the wind->force coefficient. NOT an extension switch but a DERIVED
% CONSTANT (wind_amp / V_ref = 0.2), recorded in PROTOCOL_LOCK.md. Two Gain
% blocks read it (Disturbances/PW_Kwp and Position_Observers/WM_Kw), so without
% it the model DOES NOT COMPILE in a freshly opened MATLAB - that was the real
% reason build_traj_preview would not run at §0.119, and it had been so for a
% long time before.
%
% Setting it here is safe: the only branch on exist('K_w') is in
% build_payload_wind, and that branch only SETS the variable - it changes no
% behaviour. Unlike dmf_inj_ts/wind_meas_ts, whose EXISTENCE pa_configs
% branches on, which is why those must stay in compile_check and not move up
% here.
if ~exist('K_w', 'var'), [~, K_w] = wind_to_force([]); end

% tau_prev: REFERENCE preview (build_traj_preview, §0.119). Default 0 = no
% preview, and at that value the model runs EXACTLY as it did before this
% parameter existed, because w*(t+0) == w*t bit for bit. Registered in
% docs/REGISTER_TAU.md §A2.
if ~exist('tau_prev',            'var'), tau_prev            = 0; end

%% ==================== CHECKS ====================
assert(abs(det(Gamma_mix)) > 1e-9, 'Gamma_mix is singular');
f_hover = m*g/4;
assert(f_hover < f_max, 'f_max too small: hover needs %.3f N/motor', f_hover);
assert(50*833 > 3906, 'the attitude ESO fails the Routh criterion');
% A_do against payload_sigma: ONE implementation, in op_condition.
%
% This assert used to read
%     abs(min(abs(imag(eig(A_do)))) - payload_sigma) < 1e-9
% which is the same idiom that always-failed in op_condition once the locked
% configuration became do_harm = [0 1]: the DC block has eigenvalue 0, so
% min(...) is 0 regardless of whether A_do is right. It passed here only
% because this file sets do_harm = 1 above. A second copy of a known-broken
% check, alive by accident of ordering, is how such a check comes back.
%
% So the check is not re-implemented here - op_condition does it properly, by
% comparing the whole frequency SET, and it is called. Everything it needs
% (R_traj, w_traj, payload_sigma, payload_amp, wind_amp, A_do, do_harm) exists
% by this line. Calling it also writes no variable into the workspace, which a
% local copy of the comparison would.
op_condition('Quiet', true);
assert(do_info.re_max < 0, 'the DO error dynamics are unstable');

fprintf(['MOBADC params [GUO 2020 BASELINE]. Hover f = %.3f N (%.3f N/motor)\n' ...
         '  sigma = %.4f rad/s | w_traj = %.4f rad/s | wind_amp = %.2f N\n' ...
         '  external disturbance: FORCE (payload + wind). MOMENT: out of scope.\n' ...
         '  DO: harmonics %s -> %d states | slowest pole %+.4f (tau %.1f s)\n'], ...
        m*g, f_hover, payload_sigma, w_traj, wind_amp, ...
        mat2str(do_harm), do_info.n_state, do_info.re_max, do_info.tau_slow);
