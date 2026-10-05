function info = p2_setup(matfile, varargin)
%P2_SETUP  Put plant P2 into the base workspace for one segment (GD2b).
%
%   info = p2_setup(matfile, 'Cold', false, 'Poison', false, 'SensorNoise', true, ...
%                   'ZetaS', [], 'TauM', [], 'MotorLag', true, 'Discrete', true, 'Sensors', true, ...
%                   'N6', false, 'N6TauMs', 0, 'PredScale', [])
%  'N6' switches on the wind -> payload term (REGISTER_P2 sec 15.4) with horizon N6TauMs;
%  off, the payload channel is the unchanged path (Variant Source P2_N6_Sel, p2_n6 = 0).
%  'PredScale' [s_L s_mL s_CdA] (REGISTER_P2 sec 39, F1-F3): the CONTROLLER-side parameters only -
%  the N6 predictor's L, m_L and payload C_D*A (via K_w), and the body C_D*A of the wind
%  feed-forward p2_prm_w - are scaled; the plant (p2_prm) keeps the nominal values.
%  [] (default) leaves every value untouched (bit-exact). A 4-vector [s_L s_mL s_CdA_payload s_CdA_body]
%  (REGISTER_P2 sec 42, F3 diagnostic) scales the payload part (N6 kL) and the body part (p2_prm_w)
%  separately; the 3-vector is the same as [s_L s_mL s_CdA s_CdA].
%  'ImuScale' k (sec 42, E3): gyro and accelerometer noise sigma x k (1 = nominal, bit-exact; 0 = none;
%  position noise and the accelerometer bias unchanged). 'ThrustMax' T [N] (sec 42, D2-thrust): plant
%  maximum total thrust T (f_max = T/4 per motor) and controller limit F_TOT_MAX = 0.9 T (the nominal
%  rule of p2_params); [] (default) = nominal 30.67 N.
%  'AccBias' b [m/s^2] (P2_SPEC_AUDIT L4; REGISTER_P2 sec 45.6 (1)): accelerometer-bias vector of norm b in
%  a random direction per segment (core/p2_acc_bias_vec.m), 'AccBiasAxes' 'xy' (levels 0.086, 0.17) or
%  'xyz' (0.39); [] = nominal 0, bit-exact. Levels {0, 0.086, 0.17, 0.39} for INDI (H3), IM-est and (iii-m).
%  'M3' true (REGISTER_P2 sec 45, GD8 (iii)): the open-loop pendulum model P2_M3 on the payload channel
%  (compensation + model force tau_m = 'M3TauMs' ahead; the DO gets the model's present force as known
%  input and estimates the residual); 'M3Acc' 'cmd' (a_c from Guo (9), the registered (iii)) | 'meas'
%  ((iii-m), the accelerometer). With M3 the DO/ESO z trim is 0 (the model supplies -m_L g). The model
%  uses the controller-side parameters (PredScale, as N6). Default false: nothing reads the block.
%  'TrimFF' true (REGISTER_P2 sec 47): the known payload weight -m_L g e3 added to dmf_hat after the
%  Remark 9 switch (Classical+trim, DO+trim). Default false (Variant, bit-exact).
%  'Cmp' 0 / 1 (REGISTER_P2 sec 40): the unchanged channels / competitor H3; 'H3Hz' (H3 filter cut-off).
%  The H3 block runs whenever plant_model = 1 and is read only when p2_cmp = 1 (value-neutral at 0).
%  H4 (Cmp 2) was dropped (sec 50) and its code removed on 2026-10-04 (tag paper-results-p2 holds it); the
%  model keeps the third input of P2_CMP_Sel fed by zeros (block H4_off), so baseline1.slx is unchanged.
%
%  Called by core/pa_configs.m ('PlantModel','p2') AFTER init_MOBADC_params,
%  reset_extensions, op_set, DoHarm/DoWAxis and PayloadWind - i.e. after every
%  variable it reads (m_p, L, payload_K_ratio, do_info, R_traj, w_traj, z0_hover)
%  holds the value the model is about to run. Nothing here is read when
%  plant_model = 0 (the P2 blocks are a Variant choice), except the trims and the
%  switches, whose v1 values init_MOBADC_params sets unconditionally.
%
%  Numbers: docs/devlog/PLANT_P2_SPEC.md sec 2 (APPROVED), core/p2_params.m.
%  Initial condition (GD2B_DESIGN sec 3): hover trim with the payload - motors at
%  (m_Q + m_L) g/4 and ONE estimator state holding -m_L g: the DO's z-axis DC mode
%  if the DO has one, else the position ESO's z_p3(3). 'Cold' = no trim (GD3 case).
%  Sensor noise seeds depend on the SEGMENT only (GD2B_DESIGN sec 4).

opt = struct('Cold', false, 'Poison', false, 'SensorNoise', true, 'ZetaS', [], 'TauM', [], ...
             'MotorLag', true, 'Discrete', true, 'Sensors', true, 'N6', false, 'N6TauMs', 0, 'PredScale', [], ...
             'Cmp', 0, 'H3Hz', 4, 'ImuScale', 1, 'ThrustMax', [], 'AccBias', [], ...
             'AccBiasAxes', '', 'M3', false, 'M3TauMs', 0, 'M3Acc', 'cmd', 'TrimFF', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
ev = @(s) evalin('base', s);
assert(ev('im_est_online_on') == 0, ...
    'p2_setup: ImEstOnline with plant P2 is not wired yet (GD8).');

P = p2_params();
if ~isempty(opt.ZetaS), P.zeta_s = opt.ZetaS; end
if ~isempty(opt.TauM),  P.tau_m  = opt.TauM;  end
if ~isempty(opt.ThrustMax)                % sec 42, D2-thrust
    assert(opt.ThrustMax > 0, 'p2_setup: ThrustMax must be > 0 [N].');
    P.f_max = opt.ThrustMax / 4;  P.F_TOT_MAX = 0.9 * opt.ThrustMax;
end
assert(opt.ImuScale >= 0, 'p2_setup: ImuScale must be >= 0.');
assert(P.tau_m > 0, 'p2_setup: tau_m must be > 0 (the motor lag is a state; use MotorLag=false for none).');
% GD3 stage switches (REGISTER_P2 sec 1.2): sensors need the discrete loops
assert(~opt.Sensors || opt.Discrete, 'p2_setup: Sensors=true requires Discrete=true (REGISTER_P2 sec 1.2).');
P.m_L = ev('m_p');
P.L   = ev('L');
P.K   = ev('payload_K_ratio');            % K: payload-to-body drag ratio (PayloadWind)
[~, K_w] = wind_to_force([]);
assert(K_w == P.K_w, 'p2_setup: K_w in wind_to_force (%g) differs from p2_params (%g).', K_w, P.K_w);

R_traj = ev('R_traj');  w_traj = ev('w_traj');  z0_hover = ev('z0_hover');
% Standard initial state (REGISTER_P2 sec 8, implementation-error fix): the reference
% state of the condition's OWN trajectory at t = 0 - not the circle's start for every
% trajectory. For the circle gamma_d(0) = [R;0;z0], nu_d(0) = [0;R w;0]: the same
% numbers as before (+ 0 turns the -0 of -R w sin(0) into +0).
[gd0, nd0] = trajectory_ref(0, R_traj, w_traj, z0_hover, 0, ev('traj_type'), ev('traj_par'));
x0_pos = gd0(:) + 0;
x0_vel = nd0(:) + 0;
f0 = (P.m_Q + P.m_L) * P.g / 4;

% ---- trim: one state holds -m_L g ----
trim_do = [0 0];  trim_eso = 0;  target = 'none (cold start)';
if opt.M3                                 % sec 45.1: the model supplies -m_L g; the DO estimates the residual
    target = 'none - the (iii) model supplies -m_L g (sec 45.1)';
elseif ~opt.Cold
    dwa = ev('do_info.do_w_axis');
    k = p2_do_dc_index(dwa, 3);
    if k > 0
        trim_do = [k, -P.m_L * P.g];
        target = sprintf('DO state %d (z-axis DC mode)', k);
    else
        trim_eso = -P.m_L * P.g;
        target = 'ESO z_p3(3) (the DO has no DC mode on z)';
    end
end

% ---- noise: variances (sigma = N sqrt(fs/2)), seeds from the segment index ----
sig_pos  = P.sig_pos;
sig_gyro = P.N_gyro * sqrt(P.fs_att / 2);
sig_acc  = P.N_acc  * sqrt(P.fs_att / 2);
if opt.ImuScale ~= 1, sig_gyro = sig_gyro * opt.ImuScale;  sig_acc = sig_acc * opt.ImuScale; end   % sec 42, E3
if ~opt.SensorNoise, sig_pos = 0; sig_gyro = 0; sig_acc = 0; end
[~, fname] = fileparts(matfile);             % the segment index from the FILE NAME (sec 43: a
tok = regexp(fname, 'i(\d+)', 'tokens', 'once');   % DataDir path must not be parsed)
assert(~isempty(tok), 'p2_setup: no segment index iNNNN in "%s".', matfile);
seg = str2double(tok{1});
s0 = 7000000 + 100 * seg;
bias_acc = P.bias_acc * ones(3, 1);
if ~isempty(opt.AccBias), bias_acc = p2_acc_bias_vec(opt.AccBias, opt.AccBiasAxes, seg); end   % sec 45.6 (1)

Ts_pos = 1 / P.fs_pos;
nd_pos = round(P.delay_pos / Ts_pos);
assert(abs(nd_pos * Ts_pos - P.delay_pos) < 1e-12, 'p2_setup: mocap delay is not a whole number of samples.');

V = struct();
V.plant_model   = 1;
V.p2_poison     = double(opt.Poison);
V.f_max         = P.f_max;                % Motor_Allocation/fmx reads f_max (checked in build)
V.F_TOT_MAX     = P.F_TOT_MAX;
V.p2_prm        = [P.m_Q; P.m_L; P.L; P.g; P.zeta_s; P.K; P.K_w; P.U_ref];
V.p2_prm_w      = [P.K_w; P.U_ref];
V.p2_tau_m      = P.tau_m;
V.p2_f0         = f0 * ones(4, 1);
V.p2_x0         = [x0_pos; x0_vel; 0; 0; -1; 0; 0; 0];
V.p2_ic_pos     = x0_pos;                 % read by the P2 and observer ICs (build_p2_plant)
V.p2_ic_vel     = x0_vel;
V.p2_Ts_pos     = Ts_pos;
V.p2_Ts_att     = 1 / P.fs_att;
V.p2_nd_pos     = nd_pos;
V.p2_gamma0     = x0_pos;
V.p2_gamma_prev0 = x0_pos - x0_vel * Ts_pos;   % first velocity difference = v0 (+ noise)
V.p2_var_pos    = sig_pos^2;
V.p2_var_gyro   = sig_gyro^2;
V.p2_var_acc    = sig_acc^2;
V.p2_bias_acc   = bias_acc;
V.p2_seed_pos   = s0 + [1 2 3];
V.p2_seed_gyro  = s0 + [11 12 13];
V.p2_seed_acc   = s0 + [21 22 23];
V.p2_trim_do    = trim_do;
V.p2_trim_eso   = trim_eso;
V.p2_log_dec    = 10;
V.p2_motor_lag  = double(opt.MotorLag);
V.p2_discrete   = double(opt.Discrete);
V.p2_sensors    = double(opt.Sensors);
% N6 (REGISTER_P2 sec 15.4): model with the run's m_L, L, K and the NOMINAL zeta_s; the block
% P2_N6 runs whenever plant_model = 1 (value-neutral while p2_n6 = 0: nothing reads it)
assert(opt.N6TauMs >= 0, 'p2_setup: N6TauMs must be >= 0.');
Pn = P;  Pn.zeta_s = p2_params().zeta_s;
if ~isempty(opt.PredScale)                % sec 39: controller-side parameters only
    ps = opt.PredScale(:);
    assert(any(numel(ps) == [3 4]) && all(ps > 0), ['p2_setup: PredScale = [s_L s_mL s_CdA] or ' ...
        '[s_L s_mL s_CdA_payload s_CdA_body], all > 0.']);
    if numel(ps) == 3, ps(4) = ps(3); end
    Pn.L = P.L * ps(1);  Pn.m_L = P.m_L * ps(2);  Pn.K_w = P.K_w * ps(3);
    V.p2_prm_w = [P.K_w * ps(4); P.U_ref];
end
V.p2_n6         = double(opt.N6);
% (iii) (REGISTER_P2 sec 45): the block P2_M3 runs whenever plant_model = 1 (value-neutral while p2_m3 = 0)
assert(opt.M3TauMs >= 0, 'p2_setup: M3TauMs must be >= 0.');
assert(any(strcmp(opt.M3Acc, {'cmd', 'meas'})), 'p2_setup: M3Acc must be ''cmd'' or ''meas''.');
assert(~(opt.M3 && (opt.N6 || opt.Cmp > 0)), 'p2_setup: M3 is not combined with N6 or H3.');
V.p2_m3         = double(opt.M3);
V.p2_prm_m3     = p2_m3_prm(Pn, opt.M3TauMs / 1000, ev('Kgamma'), ev('Knu'), double(strcmp(opt.M3Acc, 'meas')));
% sec 47: known payload weight pre-compensated (Classical+trim, DO+trim)
V.p2_trim_ff    = double(opt.TrimFF);
V.p2_trim_ff_v  = [0; 0; -P.m_L * P.g];
% competitor H3 (REGISTER_P2 sec 40): parameters always set (the block runs with plant_model = 1)
assert(any(opt.Cmp == [0 1]), 'p2_setup: Cmp must be 0 or 1 (H3); H4 (Cmp 2) was dropped (REGISTER_P2 sec 50).');
m_c = ev('m');                            % the CONTROLLER's mass (position law)
V.p2_cmp        = double(opt.Cmp);
V.p2_prm_h3     = p2_h3_prm(P, opt.H3Hz, m_c);
T0 = (P.m_Q + P.m_L) * P.g;               % hover trim thrust; filter at the trim estimate
V.p2_h3_s0      = [T0; 0; 0; 0; 0; m_c * P.g - T0; 0];
V.p2_prm_n6     = p2_n6_prm(Pn, opt.N6TauMs / 1000);
fn = fieldnames(V);
for i = 1:numel(fn), assignin('base', fn{i}, V.(fn{i})); end

info = struct('params', P, 'vars', V, 'segment', seg, 'trim_target', target, ...
              'cold', opt.Cold, 'poison', opt.Poison, 'sensor_noise', opt.SensorNoise, ...
              'motor_lag', opt.MotorLag, 'discrete', opt.Discrete, 'sensors', opt.Sensors, ...
              'n6', opt.N6, 'n6_tau_ms', opt.N6TauMs, 'pred_scale', opt.PredScale, 'cmp', opt.Cmp, 'h3_hz', opt.H3Hz, ...
              'imu_scale', opt.ImuScale, 'thrust_max', opt.ThrustMax, 'acc_bias', opt.AccBias, ...
              'acc_bias_axes', opt.AccBiasAxes, 'acc_bias_vec', bias_acc, ...
              'm3', opt.M3, 'm3_tau_ms', opt.M3TauMs, 'm3_acc', opt.M3Acc, 'trim_ff', opt.TrimFF, ...
              'sigma', struct('pos', sig_pos, 'gyro', sig_gyro, 'acc', sig_acc));
end

%% ---------------------------------------------------------------------------
function k = p2_do_dc_index(do_w_axis, ax)
%P2_DO_DC_INDEX  State index of the DC mode of axis ax in the DO layout of
%core/build_do_matrices.m (1 state per DC mode, 2 per harmonic, axes stacked);
%0 if that axis has no DC mode.
base = 0;
for i = 1:ax - 1
    w = do_w_axis{i}(:).';
    base = base + sum(2 - (w == 0));
end
w = do_w_axis{ax}(:).';
k = 0;
off = 0;
for j = 1:numel(w)
    if w(j) == 0, k = base + off + 1; return; end
    off = off + 2 - (w(j) == 0);
end
end
