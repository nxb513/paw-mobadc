function R = check_p2_b2_b4(varargin)
%CHECK_P2_B2_B4  GD2b checks B2, B3 (motor), B4 (docs/devlog/GD2B_DESIGN.md sec 5).
%
%   R = check_p2_b2_b4('Segment', 'wind_real_t150_i0000.mat')
%
%  B2  the MATLAB Function block p2_trans (Simulink, ode4 1 ms) vs plant_p2_free + RK4
%      in MATLAB, same piecewise-linear inputs f_act(t), eta(t), w(t), 20 s:
%      max |x_sim - x_rk4| <= 1e-9.
%  B3m the motor recipe of P2_Core (Saturation -> (u - f)/tau_m -> Integrator) in a
%      harness vs p2_motor_derivative + RK4, same piecewise-linear f_cmd(t): <= 1e-12.
%  B4  p2_oracle_ts(wind_ts, 150) vs wind_sim_load's w_oracle_ts (whole-sample shift):
%      exactly 0 (tau is a whole number of samples);  p2_oracle_ts(wind_ts, 0) vs wind_ts: exactly 0.
%  The harness models are created in memory and closed without saving; baseline1.slx is
%  not touched.

opt = struct('Segment', 'wind_real_t150_i0000.mat');
for i = 1:2:numel(varargin), opt.(varargin{i}) = varargin{i+1}; end
setup_path();
R = struct('id', {}, 'what', {}, 'measured', {}, 'tol', {}, 'pass', {});
h = 1e-3;  Tend = 20;

%% ---- B2 ----
P = p2_params('K', 0.5, 'zeta_s', 0.05);
prm = [P.m_Q; P.m_L; P.L; P.g; P.zeta_s; P.K; P.K_w; P.U_ref];
tk = (0:0.01:Tend + 0.02).';
fk = (P.m_Q + P.m_L) * P.g * (1 + 0.05 * sin(0.9 * tk) + 0.02 * cos(3.1 * tk));
ek = [0.08 * sin(0.7 * tk), 0.06 * cos(0.5 * tk), 0.02 * sin(0.2 * tk)];
wk = [5 + 2 * sin(0.6 * tk), 1.5 * sin(1.1 * tk), 0.3 * cos(0.4 * tk)];
x0 = [0.8; 0; 1; 0; 0.3; 0; sin(0.1); 0; -cos(0.1); 0; 0.2; 0];
assignin('base', 'b2_f', struct('time', tk, 'signals', struct('values', fk, 'dimensions', 1)));
assignin('base', 'b2_eta', struct('time', tk, 'signals', struct('values', ek, 'dimensions', 3)));
assignin('base', 'b2_w', struct('time', tk, 'signals', struct('values', wk, 'dimensions', 3)));
assignin('base', 'b2_prm', prm);  assignin('base', 'b2_x0', x0);
hm = 'p2_harness_b2';
if bdIsLoaded(hm), close_system(hm, 0); end
new_system(hm);
c = onCleanup(@() close_system(hm, 0));
add_block('simulink/Sources/From Workspace', [hm '/f'],   'VariableName', 'b2_f');
add_block('simulink/Sources/From Workspace', [hm '/eta'], 'VariableName', 'b2_eta');
add_block('simulink/Sources/From Workspace', [hm '/w'],   'VariableName', 'b2_w');
add_block('simulink/Sources/Constant', [hm '/prm'], 'Value', 'b2_prm');
add_block('simulink/User-Defined Functions/MATLAB Function', [hm '/P2_Trans']);
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', [hm '/P2_Trans']);
ch(1).Script = fileread(fullfile(repo_root(), 'simulink_blocks', 'p2_trans.m'));
sz = {'x', '[12 1]'; 'f_act', '1'; 'eta', '[3 1]'; 'w', '[3 1]'; 'prm', '[8 1]'; ...
      'dx', '[12 1]'; 'gam', '[3 1]'; 'nu', '[3 1]'; 'a_Q', '[3 1]'; 'd_mf', '[3 1]'; 'd_lf', '[3 1]'; 'mon', '[5 1]'};
for i = 1:size(sz, 1)                      % explicit sizes, as build_p2_plant sets them
    d = ch(1).find('-isa', 'Stateflow.Data', 'Name', sz{i, 1});
    d.DataType = 'double';  d.Props.Array.Size = sz{i, 2};
end
add_block('simulink/Continuous/Integrator', [hm '/x'], 'InitialCondition', mat2str(x0, 17));
add_block('simulink/Sinks/To Workspace', [hm '/log'], 'VariableName', 'b2_xlog', ...
    'SaveFormat', 'Structure With Time');
add_line(hm, 'x/1', 'P2_Trans/1');  add_line(hm, 'f/1', 'P2_Trans/2');
add_line(hm, 'eta/1', 'P2_Trans/3');  add_line(hm, 'w/1', 'P2_Trans/4');
add_line(hm, 'prm/1', 'P2_Trans/5');  add_line(hm, 'P2_Trans/1', 'x/1');  add_line(hm, 'x/1', 'log/1');
for k = 2:7
    add_block('simulink/Sinks/Terminator', sprintf('%s/t%d', hm, k));
    add_line(hm, sprintf('P2_Trans/%d', k), sprintf('t%d/1', k));
end
o = sim(hm, 'StopTime', num2str(Tend), 'Solver', 'ode4', 'FixedStep', num2str(h));
xs = o.b2_xlog.signals.values;                 % N x 12 for a vector signal
if size(xs, 2) ~= 12, xs = squeeze(xs).'; end
fin = @(t) interp1(tk, fk, t);  ein = @(t) interp1(tk, ek, t).';  win = @(t) interp1(tk, wk, t).';
Pf = P;  Pf.mode = 'free';
fx = @(t, x) plant_p2_free(x, force_from_attitude(fin(t), ein(t)), [[1 0 0; 0 1 0] * win(t); 0], Pf);
n = round(Tend / h);  X = zeros(n + 1, 12);  X(1, :) = x0.';  x = x0;  t = 0;
for i = 1:n
    k1 = fx(t, x);  k2 = fx(t + h/2, x + h/2*k1);  k3 = fx(t + h/2, x + h/2*k2);  k4 = fx(t + h, x + h*k3);
    x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);  t = t + h;  X(i + 1, :) = x.';
end
R = add(R, 'B2', 'p2_trans (Simulink ode4) vs plant_p2_free + RK4, 20 s: max|dx|', max(abs(xs(:) - X(:))), 1e-9);
clear c

%% ---- B3m ----
Pm = p2_params();
tk2 = (0:0.005:2.02).';
fc = [3 + 4 * sin(5 * tk2), 2 + 6 * (tk2 > 0.5), 9 * ones(size(tk2)), -1 + 0 * tk2];
assignin('base', 'b3_fc', struct('time', tk2, 'signals', struct('values', fc, 'dimensions', 4)));
assignin('base', 'f_max', Pm.f_max);  assignin('base', 'p2_tau_m', Pm.tau_m);
hm = 'p2_harness_b3';
if bdIsLoaded(hm), close_system(hm, 0); end
new_system(hm);
c = onCleanup(@() close_system(hm, 0));
add_block('simulink/Sources/From Workspace', [hm '/fc'], 'VariableName', 'b3_fc');
add_block('simulink/Discontinuities/Saturation', [hm '/M_sat'], 'UpperLimit', 'f_max', 'LowerLimit', '0');
add_block('simulink/Math Operations/Sum', [hm '/M_err'], 'Inputs', '+-');
add_block('simulink/Math Operations/Gain', [hm '/M_inv_tau'], 'Gain', '1/p2_tau_m');
add_block('simulink/Continuous/Integrator', [hm '/M_f'], 'InitialCondition', '2*ones(4,1)');
add_block('simulink/Sinks/To Workspace', [hm '/log'], 'VariableName', 'b3_flog', 'SaveFormat', 'Structure With Time');
add_line(hm, 'fc/1', 'M_sat/1');  add_line(hm, 'M_sat/1', 'M_err/1');  add_line(hm, 'M_f/1', 'M_err/2');
add_line(hm, 'M_err/1', 'M_inv_tau/1');  add_line(hm, 'M_inv_tau/1', 'M_f/1');  add_line(hm, 'M_f/1', 'log/1');
o = sim(hm, 'StopTime', '2', 'Solver', 'ode4', 'FixedStep', num2str(h));
fs = o.b3_flog.signals.values;                 % N x 4
if size(fs, 2) ~= 4, fs = squeeze(fs).'; end
fm = @(t, f) p2_motor_derivative(f, interp1(tk2, fc, t).', Pm);
n = 2000;  F = zeros(n + 1, 4);  f = 2 * ones(4, 1);  F(1, :) = f.';  t = 0;
for i = 1:n
    k1 = fm(t, f);  k2 = fm(t + h/2, f + h/2*k1);  k3 = fm(t + h/2, f + h/2*k2);  k4 = fm(t + h, f + h*k3);
    f = f + h/6*(k1 + 2*k2 + 2*k3 + k4);  t = t + h;  F(i + 1, :) = f.';
end
R = add(R, 'B3m', 'motor recipe (Simulink) vs p2_motor_derivative + RK4, 2 s: max|df| [N]', max(abs(fs(:) - F(:))), 1e-12);
clear c

%% ---- B4 ----
evalc('wind_sim_load(opt.Segment, 1)');
wts = evalin('base', 'wind_ts');  wor = evalin('base', 'w_oracle_ts');
tau = evalin('base', 'wind_tau_ms');
o150 = p2_oracle_ts(wts, tau);
o0 = p2_oracle_ts(wts, 0);
R = add(R, 'B4a', sprintf('O(%g) time-shift vs whole-sample w_oracle_ts: max|d| [m/s]', tau), ...
    max(abs(o150.signals.values(:) - wor.signals.values(:))), 0);
R = add(R, 'B4b', 'O(0) vs wind_ts: max|d| [m/s]', max(abs(o0.signals.values(:) - wts.signals.values(:))), 0);

fprintf('\n  check_p2_b2_b4\n');
for i = 1:numel(R)
    fprintf('  %-5s %-5s %-11.3e %-9.1e %s\n', R(i).id, pf(R(i).pass), R(i).measured, R(i).tol, R(i).what);
end
end

function R = add(R, id, what, m, tol)
R(end + 1) = struct('id', id, 'what', what, 'measured', m, 'tol', tol, 'pass', m <= tol);
end
function s = pf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
