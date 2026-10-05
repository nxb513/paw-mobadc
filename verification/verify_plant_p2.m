function R = verify_plant_p2(varargin)
%VERIFY_PLANT_P2  GD2a offline verification of plant P2 (MASTER_PLAN sec 2.7,
%PLANT_P2_SPEC sec 3): V1-V7 and the unit tests of motor, sensors and ZOH.
%Pure functions only - no Simulink.
%
%   R = verify_plant_p2()            % all checks, prints a PASS/FAIL table
%   R = verify_plant_p2('Quick',true) % V5 over 20 s instead of 200 s
%
%  Every tolerance below was fixed in this file BEFORE the first run.
%  Integration: classical RK4 at h = 1 ms (the solver of baseline1.slx, ode4).

opt = struct('Quick', false);
for i = 1:2:numel(varargin), opt.(varargin{i}) = varargin{i+1}; end
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root, 'core'), fullfile(root, 'simulink_blocks'));

R = struct('id', {}, 'what', {}, 'measured', {}, 'tol', {}, 'pass', {});
e3 = [0; 0; 1];
h = 1e-3;

%% V1 static hanging: T = m_L g, a_Q = 0, omegadot = 0, and it stays there
P = p2_params('K', 0.5, 'zeta_s', 0.05);
x0 = [0; 0; 0; 0; 0; 0; -e3; 0; 0; 0];
u = struct('F', (P.m_Q + P.m_L) * P.g * e3, 'w', [0; 0; 0]);
[dx, o] = plant_p2_derivative(x0, u, P);
eT = abs(o.T - P.m_L * P.g) / (P.m_L * P.g);
R = add(R, 'V1a', 'static: |T - m_L g|/(m_L g)', eT, 1e-12);
R = add(R, 'V1b', 'static: max(|a_Q|, |omegadot|) [SI]', max(norm(dx(4:6)), norm(dx(10:12))), 1e-12);
X = rk4(@(t, x) plant_p2_derivative(x, u, P), x0, h, 10000);
R = add(R, 'V1c', 'static 10 s: max|q + e3|', max(vecnorm3(X(:, 7:9) + repmat(e3.', size(X, 1), 1))), 1e-12);

%% V2 small angle vs the v1 planar pendulum (prescribed UAV motion, K = 0: no wind)
A = 1.98;  Om = 1.575;  n2 = 60000;
for zs = [0 0.05]
    P = p2_params('mode', 'prescribed', 'K', 0, 'zeta_s', zs);
    uf = @(t) struct('a_Q', [A * sin(Om * t); 0; 0], 'v_Q', [-A / Om * cos(Om * t); 0; 0], 'w', [0; 0; 0]);
    Xp = rk4(@(t, x) plant_p2_derivative(x, uf(t), P), [-e3; 0; 0; 0], h, n2);
    Xv = rk4(@(t, xp) payload_pendulum_derivative(xp, [A * sin(Om * t); 0], [0; 0], P.m_L, P.L, zs, P.g), ...
             zeros(4, 1), h, n2);
    thp = atan2(Xp(:, 1), -Xp(:, 3));
    tag = sprintf('zeta_s = %g', zs);
    R = add(R, sprintf('V2a-%g', zs), ...
        sprintf('1-axis, %s, 60 s: max|theta_P2 - theta_v1| [rad] (max theta %.3f)', tag, max(abs(thp))), ...
        max(abs(thp - Xv(:, 1))), 1e-8);
    if zs == 0
        % V2b (redefined 2026-09-25, user decision): the reference is the ANALYTIC planar
        % tension T = m_L (g cos(th) + L thd^2 - a sin(th)) (one plane, horizontal a, no
        % wind, a_z = 0), not v1's payload_pendulum_output.m, whose tension has the
        % opposite sign on a sin(th) (+a sin(th); found by the first run of this file:
        % T_v1 - T_P2 = 2 m a sin(th) to 2.5e-15 N). v1 is frozen at v1-final and is
        % not corrected. For q = (sin th, 0, -cos th): omega = -thd e2.
        % V2b-N checks P2's tension independently: Newton on the payload with a_L from
        % central second differences of x_L = x_Q + L q (x_Q = -A/Om^2 sin(Om t) e1).
        tt = (0:n2).' * h;  dT = 0;  dv1 = 0;  res = 0;
        xL = [-A / Om^2 * sin(Om * tt), zeros(n2 + 1, 2)] + P.L * Xp(:, 1:3);
        for i = 2:10:n2
            [~, o] = plant_p2_derivative(Xp(i, :).', uf(tt(i)), P);
            th = thp(i);  thd = -Xp(i, 5);  a = A * sin(Om * tt(i));
            Tan = P.m_L * (P.g * cos(th) + P.L * thd^2 - a * sin(th));
            dT = max(dT, abs(o.T - Tan));
            aL = (xL(i + 1, :) - 2 * xL(i, :) + xL(i - 1, :)).' / h^2;
            res = max(res, norm(P.m_L * aL + P.m_L * P.g * e3 + o.T * Xp(i, 1:3).'));
            dv = payload_pendulum_output(Xv(i, :).', [a; 0], P.m_L, P.L, P.g, 1);
            Tv1 = dv(1) / sin(Xv(i, 1));
            if abs(sin(Xv(i, 1))) > 1e-3, dv1 = max(dv1, abs(Tv1 - o.T - 2 * P.m_L * a * sin(th))); end
        end
        R = add(R, 'V2b', '1-axis, zeta_s = 0: max|T_P2 - m_L(g cos th + L thd^2 - a sin th)| [N]', dT, 1e-8);
        R = add(R, 'V2b-N', '1-axis: Newton residual on payload |m_L a_L + m_L g e3 + T q| (finite diff.) [N]', res, 1e-5);
        R = add(R, 'V2b-v1', 'record only: |(T_v1 - T_P2) - 2 m a sin th| (v1 sign error, v1 not changed) [N]', dv1, 1e-8);
    end
end
% two axes, small angle: the planar model drops the coupling terms, O(theta^2) relative
A2 = 0.2;
P = p2_params('mode', 'prescribed', 'K', 0, 'zeta_s', 0.05);
uf = @(t) struct('a_Q', A2 * [sin(Om * t); 0.6 * cos(1.3 * t); 0], ...
                 'v_Q', A2 * [-cos(Om * t) / Om; 0.6 * sin(1.3 * t) / 1.3; 0], 'w', [0; 0; 0]);
Xp = rk4(@(t, x) plant_p2_derivative(x, uf(t), P), [-e3; 0; 0; 0], h, n2);
Xv = rk4(@(t, xp) payload_pendulum_derivative(xp, A2 * [sin(Om * t); 0.6 * cos(1.3 * t)], [0; 0], ...
         P.m_L, P.L, 0.05, P.g), zeros(4, 1), h, n2);
thx = atan2(Xp(:, 1), -Xp(:, 3));  thy = atan2(Xp(:, 2), -Xp(:, 3));
amp = max(abs([thx; thy]));
rel = max(max(abs(thx - Xv(:, 1))), max(abs(thy - Xv(:, 3)))) / amp;
R = add(R, 'V2c', sprintf('2-axis small angle (max %.2f deg), 60 s: max diff / max angle', rad2deg(amp)), rel, 1e-2);

%% V3 energy conservation (zeta_s = 0, no aerodynamic force)
% (a) fixed suspension, non-planar swing
P = p2_params('mode', 'prescribed', 'K', 0, 'zeta_s', 0, 'K_w', 0);
th0 = deg2rad(30);
q0 = [sin(th0); 0; -cos(th0)];  om0 = [0.4; 1.1; 0];  om0 = om0 - (om0.' * q0) * q0;
uz = struct('a_Q', [0; 0; 0], 'v_Q', [0; 0; 0], 'w', [0; 0; 0]);
X = rk4(@(t, x) plant_p2_derivative(x, uz, P), [q0; om0], h, 20000);
E = 0.5 * P.m_L * P.L^2 * sum(X(:, 4:6).^2, 2) + P.m_L * P.g * P.L * X(:, 3);
R = add(R, 'V3a', 'fixed point, 20 s: max|E - E0|/(m_L g L)', max(abs(E - E(1))) / (P.m_L * P.g * P.L), 1e-9);
% (b) free UAV under a constant force F: E = KE + gravity PE - F.x_Q is conserved
P = p2_params('K', 0, 'zeta_s', 0, 'K_w', 0);
F = (P.m_Q + P.m_L) * P.g * e3 + [0.3; -0.2; 0.5];
u = struct('F', F, 'w', [0; 0; 0]);
xf0 = [0; 0; 0; 0.5; -0.3; 0.2; q0; om0];
X = rk4(@(t, x) plant_p2_derivative(x, u, P), xf0, h, 20000);
E = energy_free(X, P, F);
R = add(R, 'V3b', 'free UAV, constant F, 20 s: max|E - E0|/(m_L g L)', max(abs(E - E(1))) / (P.m_L * P.g * P.L), 1e-9);

%% V4 conical pendulum: omega_c^2 = g/(L cos theta)
P = p2_params('mode', 'prescribed', 'K', 0, 'zeta_s', 0, 'K_w', 0);
th0 = deg2rad(30);  Oc = sqrt(P.g / (P.L * cos(th0)));
q0 = [sin(th0); 0; -cos(th0)];
om0 = Oc * (e3 - (e3.' * q0) * q0);
X = rk4(@(t, x) plant_p2_derivative(x, uz, P), [q0; om0], h, 10000);
cone = acos(-X(:, 3));
az = unwrap(atan2(X(:, 2), X(:, 1)));
Om_meas = (az(end) - az(1)) / 10;
R = add(R, 'V4a', 'conical 30 deg, 10 s: max|cone angle - 30 deg| [rad]', max(abs(cone - th0)), 1e-8);
R = add(R, 'V4b', sprintf('conical: |Omega_meas/Omega_c - 1| (Omega_c = %.4f rad/s)', Oc), abs(Om_meas / Oc - 1), 1e-9);

%% V5 constraint drift, free UAV, wind + damping + time-varying force
T5 = 200;  if opt.Quick, T5 = 20; end
P = p2_params('K', 0.5, 'zeta_s', 0.05);
uf = @(t) struct('F', (P.m_Q + P.m_L) * P.g * e3 + [0.5 * sin(0.5 * t); 0.3 * cos(0.9 * t); 0.2 * sin(0.3 * t)], ...
                 'w', [5 + 2 * sin(0.7 * t); 1.5 * sin(1.3 * t); 0]);
q0 = [sin(deg2rad(10)); 0; -cos(deg2rad(10))];
[X, Tmin] = rk4(@(t, x) plant_p2_derivative(x, uf(t), P), [0; 0; 0; 0; 0; 0; q0; 0; 0.3; 0], h, round(T5 / h), ...
                @(t, x) tension(x, uf(t), P));
qn = abs(sqrt(sum(X(:, 7:9).^2, 2)) - 1);
wq = abs(sum(X(:, 7:9) .* X(:, 10:12), 2) ./ sqrt(sum(X(:, 7:9).^2, 2)));
R = add(R, 'V5a', sprintf('free, wind + damping, %g s: max||q| - 1|', T5), max(qn), 1e-6);
R = add(R, 'V5b', sprintf('free, wind + damping, %g s: max|omega.q|', T5), max(wq), 1e-6);
R = add(R, 'V5c', sprintf('free, %g s: T_min > 0 (no slack) - measured T_min [N]', T5), -Tmin, 0);

%% V6 total momentum (net external force zero, no aerodynamic force), zeta_s = 0 and > 0
for zs = [0 0.05 0.12]
    P = p2_params('K', 0, 'zeta_s', zs, 'K_w', 0);
    u = struct('F', (P.m_Q + P.m_L) * P.g * e3, 'w', [0; 0; 0]);
    q0 = [sin(deg2rad(25)); 0.2; -cos(deg2rad(25))];  q0 = q0 / norm(q0);
    om0 = [0.3; 0.9; 0.1];  om0 = om0 - (om0.' * q0) * q0;
    X = rk4(@(t, x) plant_p2_derivative(x, u, P), [0; 0; 0; 0.4; -0.2; 0.1; q0; om0], h, 20000);
    p = momentum(X, P);
    dp = max(sqrt(sum((p - repmat(p(1, :), size(p, 1), 1)).^2, 2)));
    R = add(R, sprintf('V6-%g', zs), sprintf('momentum, zeta_s = %g, 20 s: max|p - p0| [N s]', zs), dp, 1e-9);
end

%% V7 drag at U_ref, quadratic scaling, relative velocity, K = 0
P = p2_params('K', 0.5);
xs = [0; 0; 0; 0; 0; 0; -e3; 0; 0; 0];
[~, o] = plant_p2_derivative(xs, struct('F', [0; 0; 0], 'w', [P.U_ref; 0; 0]), P);
R = add(R, 'V7a', '|F_wQ| at U_ref, v = 0: |F - K_w U_ref| (= 1.0 N) [N]', abs(norm(o.F_wQ) - P.K_w * P.U_ref), 1e-12);
R = add(R, 'V7b', '|F_wL| at U_ref, K = 0.5: |F - K K_w U_ref| (= 0.5 N) [N]', abs(norm(o.F_wL) - P.K * P.K_w * P.U_ref), 1e-12);
[~, o2] = plant_p2_derivative(xs, struct('F', [0; 0; 0], 'w', [2 * P.U_ref; 0; 0]), P);
R = add(R, 'V7c', 'quadratic: |F(2 U_ref)/F(U_ref) - 4| (body and payload)', ...
    max(abs(norm(o2.F_wQ) / norm(o.F_wQ) - 4), abs(norm(o2.F_wL) / norm(o.F_wL) - 4)), 1e-12);
xr = xs;  xr(4:6) = [-P.U_ref; 0; 0];
[~, o3] = plant_p2_derivative(xr, struct('F', [0; 0; 0], 'w', [0; 0; 0]), P);
R = add(R, 'V7d', 'relative velocity: w = 0, v = -U_ref e1 gives F_wQ = +1.0 e1 [N]', norm(o3.F_wQ - [1; 0; 0]), 1e-12);
[~, o4] = plant_p2_derivative(xs, struct('F', [0; 0; 0], 'w', [P.U_ref; 0; 0]), p2_params('K', 0));
R = add(R, 'V7e', 'K = 0: |F_wL| [N]', norm(o4.F_wL), 0);
R = add(R, 'V7f', 'horizontal force balance: d_lf = F_wQ exactly', norm(o.d_lf - o.F_wQ), 0);

%% U1 motor: first-order lag, RK4 at 1 ms, each tau of the spec
P = p2_params();
for tm = [0.017 0.030 0.050 0.072]
    P.tau_m = tm;
    nt = round(tm / h);
    X = rk4(@(t, f) p2_motor_derivative(f, 5 * ones(4, 1), P), zeros(4, 1), h, 5 * nt);
    e1 = abs(X(nt + 1, 1) / 5 - (1 - exp(-1)));
    e5 = abs(X(end, 1) / 5 - (1 - exp(-5)));
    R = add(R, sprintf('U1-%g', 1000 * tm), sprintf('motor tau = %g ms: |f(tau)/f_cmd - (1-e^-1)|, |f(5tau)/f_cmd - (1-e^-5)|', ...
        1000 * tm), max(e1, e5), 1e-6);
end
P.tau_m = 0.030;
X = rk4(@(t, f) p2_motor_derivative(f, [9; -1; 3; 7.67], P), [0; 2; 0; 0], h, 1000);
R = add(R, 'U1-sat', sprintf('saturation: f_cmd [9 -1 3 7.67] -> [%.2f 0 3 %.2f] after 33 tau', P.f_max, P.f_max), ...
    norm(X(end, :).' - [P.f_max; 0; 3; P.f_max]), 1e-9);

%% U2 sensor noise: sigma = N sqrt(fs/2), measured on 2e5 samples; bias
P = p2_params();
n = 200000;
[~, I] = p2_sensor(zeros(n, 1), P.fs_att, 0, P.N_acc, 0, 11, h);
R = add(R, 'U2a', sprintf('accel sigma = N sqrt(fs/2) = %.5f m/s^2: |formula - 0.0395|', I.sigma), abs(I.sigma - 0.039471), 1e-6);
R = add(R, 'U2b', 'accel: |std(samples)/sigma - 1|', abs(std(I.samples) / I.sigma - 1), 0.01);
[~, I] = p2_sensor(zeros(n, 1), P.fs_att, 0, P.N_gyro, 0, 12, h);
R = add(R, 'U2c', sprintf('gyro sigma = %.3e rad/s (0.157 deg/s): |std/sigma - 1|', I.sigma), abs(std(I.samples) / I.sigma - 1), 0.01);
[~, I] = p2_sensor(zeros(n, 1), P.fs_att, 0, P.N_acc, 0.392, 13, h);
R = add(R, 'U2d', 'accel bias 0.392: |mean - bias| / (sigma/sqrt(n)) (4 SE)', abs(mean(I.samples) - 0.392) / (I.sigma / sqrt(n)), 4);
[~, I] = p2_sensor(zeros(50 * 20000, 1), P.fs_wind, 0, struct('sigma', P.sig_wind), 0, 14, h);
R = add(R, 'U2e', sprintf('wind sigma 0.1 m/s at 20 Hz (%d samples): |std/sigma - 1|', numel(I.idx)), abs(std(I.samples) / 0.1 - 1), 0.02);

%% U3 sampling rate and exact delay (noise off): 1 kHz / 0, 125 Hz / 8 ms, 20 Hz / 50 ms
cases = [P.fs_att 0; P.fs_pos P.delay_pos; P.fs_wind P.delay_wind];
n = 10000;
xr = ((0:n - 1).' * h);                     % ramp: x(t) = t
for c = 1:3
    [y, I] = p2_sensor(xr, cases(c, 1), cases(c, 2), struct('sigma', 0), 0, 1, h);
    want = max(xr(I.idx) - cases(c, 2), 0);
    e = max(abs(y(I.idx) - want));
    nchg = sum(diff(y) ~= 0);
    R = add(R, sprintf('U3-%g', cases(c, 1)), sprintf(['%g Hz, delay %g ms: k = %d steps, d = %d steps, ' ...
        '%d samples/10 s, max|y - x(t - delay)| at samples'], cases(c, 1), 1000 * cases(c, 2), I.k, I.d, ...
        numel(I.idx)), e + abs(numel(I.idx) - cases(c, 1) * 10) + abs(nchg - (numel(I.idx) - 1 - floor(I.d / I.k))), 1e-12);
end
ok = false;
try, p2_sensor(xr, 120, 0, struct('sigma', 0), 0, 1, h); catch, ok = true; end
R = add(R, 'U3-120', '120 Hz at h = 1 ms must be refused (decision 4.7): refused = 0', double(~ok), 0);
ok = false;
try, p2_sensor(xr, 125, 0.0083, struct('sigma', 0), 0, 1, h); catch, ok = true; end
R = add(R, 'U3-8.3', '8.3 ms delay at h = 1 ms must be refused: refused = 0', double(~ok), 0);

%% U4 ZOH: held between samples, equal to the sampled value
x = sin((0:9999).' * h * 7) + (0:9999).' * 1e-4;
worst = 0;
for fs = [1000 125 20]
    [y, k, idx] = p2_zoh(x, fs, h);
    for j = 1:numel(idx)
        seg = y(idx(j):min(idx(j) + k - 1, numel(x)));
        worst = max(worst, max(abs(seg - x(idx(j)))));
    end
end
R = add(R, 'U4', 'ZOH at 1 kHz / 125 Hz / 20 Hz: max|y - x(sample)| inside each hold', worst, 0);

%% report
fprintf('\n  verify_plant_p2 (GD2a, pure functions, RK4 h = 1 ms)\n');
fprintf('  %-8s %-6s %-12s %-10s %s\n', 'id', 'result', 'measured', 'tol', 'check');
for i = 1:numel(R)
    fprintf('  %-8s %-6s %-12.3e %-10.1e %s\n', R(i).id, pf(R(i).pass), R(i).measured, R(i).tol, R(i).what);
end
fprintf('\n  %d/%d PASS\n', sum([R.pass]), numel(R));
end

%% ---------------------------------------------------------------------------
function R = add(R, id, what, measured, tol)
R(end + 1) = struct('id', id, 'what', what, 'measured', measured, 'tol', tol, 'pass', measured <= tol);
end

function s = pf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end

function v = vecnorm3(A)
v = sqrt(sum(A.^2, 2));
end

function [X, mn] = rk4(f, x0, h, n, g)
% Classical RK4 (= ode4). X(i,:) = state at t = (i-1) h. Optional g(t,x): track its minimum.
X = zeros(n + 1, numel(x0));
X(1, :) = x0.';
x = x0;  t = 0;  mn = inf;
for i = 1:n
    k1 = f(t, x);
    k2 = f(t + h / 2, x + h / 2 * k1);
    k3 = f(t + h / 2, x + h / 2 * k2);
    k4 = f(t + h, x + h * k3);
    x = x + h / 6 * (k1 + 2 * k2 + 2 * k3 + k4);
    t = t + h;
    X(i + 1, :) = x.';
    if nargin > 4, mn = min(mn, g(t, x)); end
end
end

function T = tension(x, u, P)
[~, o] = plant_p2_derivative(x, u, P);
T = o.T;
end

function E = energy_free(X, P, F)
vQ = X(:, 4:6);  q = X(:, 7:9);  om = X(:, 10:12);
vL = vQ + P.L * cross(om, q, 2);
zL = X(:, 3) + P.L * q(:, 3);
E = 0.5 * P.m_Q * sum(vQ.^2, 2) + 0.5 * P.m_L * sum(vL.^2, 2) + P.m_Q * P.g * X(:, 3) + P.m_L * P.g * zL ...
    - X(:, 1:3) * F;
end

function p = momentum(X, P)
vQ = X(:, 4:6);  q = X(:, 7:9);  om = X(:, 10:12);
p = P.m_Q * vQ + P.m_L * (vQ + P.L * cross(om, q, 2));
end
