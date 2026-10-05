function P = p2_params(varargin)
%P2_PARAMS  Nominal parameters of plant P2 (docs/devlog/PLANT_P2_SPEC.md sec 2, APPROVED).
%
%   P = p2_params()                       % nominal, free mode
%   P = p2_params('mode','prescribed', 'zeta_s',0, 'K',0)   % any field overridden
%
%  Single source of the P2 numbers for the pure functions (GD2a). Nothing here is
%  read by baseline1.slx; v1 (core/init_MOBADC_params.m) is untouched.

P = struct();
P.mode   = 'free';        % 'free' (closed loop) | 'prescribed' (a_Q, v_Q given; V2-V4)
P.g      = 9.81;          % m/s^2
P.m_Q    = 1.121;         % kg    Guo 2020 A.1 / Quanser QDrone v0.4
P.m_L    = 0.5;           % kg    Guo 2020 Fig. 1; sweep {0.25, 0.5, 0.65}
P.L      = 1.0;           % m     assumption; sweep {0.5, 1.0, 1.5}
P.zeta_s = 0.05;          % -     spec 4.1; sensitivity {0.02, 0.05, 0.12}
P.K      = 0.5;           % -     (C_D A)_L = K (C_D A)_Q
P.K_w    = 0.2;           % N/(m/s) locked (core/wind_to_force.m)
P.U_ref  = 5.0;           % m/s   locked anchor V_ref (REGISTER_P2 sec 0.10)
% motor, saturation (spec 2.1, 2.4)
P.tau_m     = 0.017;      % s     amendment A1 (REGISTER_P2 sec 3): was 0.030; sensitivity {0, 25, 30} ms
P.f_max     = 30.67/4;    % N per motor, Quanser v0.4 nonlinear model (nominal)
P.F_TOT_MAX = 0.9*30.67;  % N     controller limit = 0.9 x plant max
% sampling (spec 2.5, 2.6, decisions 4.7, 4.8); base step of the fixed-step solver
P.h         = 1e-3;       % s
P.fs_pos    = 125;        % Hz   mocap + position loop (approximates 120 Hz), delay 8 ms
P.delay_pos = 0.008;      % s
P.sig_pos   = 0.2e-3;     % m    OptiTrack Flex 13 +/-0.2 mm taken as sigma
P.fs_att    = 1000;       % Hz   attitude loop, IMU
P.N_acc     = 180e-6*9.80665;          % (m/s^2)/sqrt(Hz)  BMI160 180 ug/sqrt(Hz)
P.N_gyro    = deg2rad(0.007);          % (rad/s)/sqrt(Hz)  BMI160 0.007 deg/s/sqrt(Hz)
P.bias_acc  = 0;          % m/s^2 nominal (calibrated); sensitivity +/-0.392 (40 mg)
P.fs_wind   = 20;         % Hz   TriSonica Mini
P.delay_wind= 0.050;      % s    one sample
P.sig_wind  = 0.1;        % m/s

for i = 1:2:numel(varargin)
    assert(isfield(P, varargin{i}), 'p2_params: unknown field %s', varargin{i});
    P.(varargin{i}) = varargin{i+1};
end
end
