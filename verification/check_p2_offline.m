function R = check_p2_offline()
%CHECK_P2_OFFLINE  GD2b checks that need no Simulink (Octave or MATLAB).
%
%   R = check_p2_offline()
%
%  O1  p2_ic_do / p2_ic_eso with plant_model = 0 return EXACTLY the old IC expressions.
%  O2  P2 hover trim: dmf_hat(0) = B_do (z0 + l_gain [gamma0; nu0]) = -m_L g e3 exactly
%      (DoHarm [0 1]); ESO trim for DoHarm 1 (no DC mode on z).
%  O3  p2_setup: trim target by DO layout, seeds depend on the segment only, P2 numbers.
%  O4  p2_oracle_ts: 150 ms = whole-sample shift (<= 1e-12); 0 ms = the wind itself.
%  O5  thrust_attitude_ref with F_TOT_MAX = 21.6 as an input vs the pre-GD2b block code
%      (git tag v1-final): bit-exact on 20000 random inputs, including clamped cases.
%  O6  p2_trans (block code) vs plant_p2_free called directly: identical.
%  O7  p2_wind_force_hat vs the formula; p2_summary on synthetic logs.

here = fileparts(mfilename('fullpath'));  root = fileparts(here);
addpath(fullfile(root, 'core'), fullfile(root, 'simulink_blocks'), fullfile(root, 'build'));
R = struct('id', {}, 'what', {}, 'measured', {}, 'tol', {}, 'pass', {});
g = 9.81;  mL = 0.5;

%% O1, O2
R_traj = 0.8;  z0_hover = 1.0;  w_traj = 1.575;
for hv = {1, [0 1]}
    [A, B, lg, info] = build_do_matrices(w_traj, hv{1}, [0.10 0.08 0.10]); %#ok<ASGLU>
    old = -lg*[R_traj;0;z0_hover;0;R_traj*w_traj;0];
    new = p2_ic_do(lg, R_traj, z0_hover, w_traj, 0, [0 0]);
    R = add(R, sprintf('O1-do-%s', mat2str(hv{1})), 'p2_ic_do(plant_model=0) vs old IC: isequal -> 0', double(~isequal(old, new)), 0);
end
old = [R_traj;0;z0_hover; 0;R_traj*w_traj;0; 0;0;0];
R = add(R, 'O1-eso', 'p2_ic_eso(plant_model=0) vs old IC: isequal -> 0', ...
    double(~isequal(old, p2_ic_eso(R_traj, z0_hover, w_traj, 0, 0))), 0);

%% O3 p2_setup (base workspace as pa_configs leaves it)
[A1, B1, l1, i1] = build_do_matrices(w_traj, [0 1], [0.10 0.08 0.10]);
bw = struct('im_est_online_on', 0, 'm_p', mL, 'L', 1.0, 'payload_K_ratio', 0.5, ...
            'R_traj', R_traj, 'w_traj', w_traj, 'z0_hover', z0_hover, 'do_info', i1, ...
            'traj_type', 1, 'traj_par', zeros(4,1));   % circle, as reset_extensions/op_set leave it
fn = fieldnames(bw);
for i = 1:numel(fn), assignin('base', fn{i}, bw.(fn{i})); end
I1 = p2_setup('wind_real_t150_i0319.mat');
R = add(R, 'O3-target', sprintf('DoHarm [0 1] -> %s (expect DO state 7)', I1.trim_target), ...
    abs(I1.vars.p2_trim_do(1) - 7) + abs(I1.vars.p2_trim_do(2) + mL*g), 0);
z0 = p2_ic_do(l1, R_traj, z0_hover, w_traj, 1, I1.vars.p2_trim_do);
d0 = B1 * (z0 + l1*[R_traj;0;z0_hover;0;R_traj*w_traj;0]);
R = add(R, 'O2-do', sprintf('trim: dmf_hat(0) = [%g %g %g] vs [0 0 -m_L g]', d0), max(abs(d0 - [0;0;-mL*g])), 0);
I1b = p2_setup('wind_real_t150_i0319.mat', 'Cold', true);
R = add(R, 'O3-cold', 'Cold: no trim anywhere', abs(I1b.vars.p2_trim_do(1)) + abs(I1b.vars.p2_trim_eso), 0);
[~, ~, ~, i0] = build_do_matrices(w_traj, 1, [0.10 0.08 0.10]);
assignin('base', 'do_info', i0);
I0 = p2_setup('wind_real_t150_i0319.mat');
zp0 = p2_ic_eso(R_traj, z0_hover, w_traj, 1, I0.vars.p2_trim_eso);
R = add(R, 'O2-eso', sprintf('DoHarm 1 -> %s; z_p3(3) = %g', I0.trim_target, zp0(9)), ...
    abs(zp0(9) + mL*g) + abs(I0.vars.p2_trim_do(1)), 0);
assignin('base', 'do_info', i1);
I2 = p2_setup('wind_real_t150_i0319.mat');
I3 = p2_setup('wind_real_t150_i0715.mat');
R = add(R, 'O3-seed', 'seeds: same segment -> same, other segment -> different (0 = ok)', ...
    double(~isequal(I1.vars.p2_seed_pos, I2.vars.p2_seed_pos) || isequal(I1.vars.p2_seed_pos, I3.vars.p2_seed_pos)), 0);
v = I1.vars;
R = add(R, 'O3-num', sprintf('f_max %.4f, F_TOT_MAX %.3f, Ts_pos %g, nd_pos %d, sig gyro %.3e, acc %.4f', ...
    v.f_max, v.F_TOT_MAX, v.p2_Ts_pos, v.p2_nd_pos, I1.sigma.gyro, I1.sigma.acc), ...
    abs(v.f_max - 7.6675) + abs(v.F_TOT_MAX - 27.603) + abs(v.p2_Ts_pos - 0.008) + abs(v.p2_nd_pos - 1) ...
    + abs(I1.sigma.acc - 0.039471) * (abs(I1.sigma.acc - 0.039471) > 1e-6), 1e-9);
R = add(R, 'O3-x0', 'circle: p2_x0 = [v1 Int_gamma IC; v1 Int_nu IC; -e3; 0], isequal incl. sign of 0 -> 0', ...
    double(~(isequal(v.p2_x0, [R_traj;0;z0_hover; 0;R_traj*w_traj;0; 0;0;-1; 0;0;0]) && ...
             ~any(signbit(v.p2_x0([2 4 7 8 10 11 12]))))), 0);
% REGISTER_P2 sec 8: the standard IC = the condition's own reference state at t = 0
assignin('base', 'traj_type', 0);  assignin('base', 'traj_par', zeros(4,1));
Ih = p2_setup('wind_real_t150_i0319.mat');
assignin('base', 'traj_type', 4);  assignin('base', 'traj_par', [0.265218;0;0;0]);
It = p2_setup('wind_real_t150_i0319.mat');
[g5, n5] = trajectory_ref(0, R_traj, w_traj, z0_hover, 0, 4, [0.265218;0;0;0]);
R = add(R, 'O3-ic', 'standard IC: hover [0;0;z0], v 0; T5 = trajectory_ref(0); max|d|', ...
    max(abs([Ih.vars.p2_ic_pos - [0;0;z0_hover]; Ih.vars.p2_ic_vel; ...
             It.vars.p2_ic_pos - g5(:); It.vars.p2_ic_vel - n5(:)])), 0);
assignin('base', 'traj_type', 1);  assignin('base', 'traj_par', zeros(4,1));

%% O4 oracle
fs = 20;  t = (0:1/fs:200).';
W = [5 + sin(0.3*t) + 0.2*randn(size(t)), cos(0.2*t) + 0.2*randn(size(t)), 0.1*randn(size(t))];
wts = struct('time', t, 'signals', struct('values', W, 'dimensions', 3));
kk = round(150e-3 * fs);
wo_old = W([1 + kk:end, repmat(size(W, 1), 1, kk)], :);
o150 = p2_oracle_ts(wts, 150);  o0 = p2_oracle_ts(wts, 0);
R = add(R, 'O4-150', 'p2_oracle_ts(150) vs whole-sample shift: max|d|', max(abs(o150.signals.values(:) - wo_old(:))), 0);
o170 = p2_oracle_ts(wts, 170);  tq = min(t + 0.17, t(end));  wi = interp1(t, W, tq);
R = add(R, 'O4-170', 'p2_oracle_ts(170) (between samples) vs interp1: max|d|', max(abs(o170.signals.values(:) - wi(:))), 0);
R = add(R, 'O4-0', 'p2_oracle_ts(0) vs wind: max|d|', max(abs(o0.signals.values(:) - W(:))), 0);

%% O5 thrust_attitude_ref old vs new
[st, oldsrc] = system(sprintf('git -C "%s" show v1-final:simulink_blocks/thrust_attitude_ref.m', root));
if st == 0
    d = tempname();  mkdir(d);
    fid = fopen(fullfile(d, 'thrust_attitude_ref_v1.m'), 'w');
    fprintf(fid, '%s', strrep(oldsrc, 'function [f, eta_d] = thrust_attitude_ref(', ...
        'function [f, eta_d] = thrust_attitude_ref_v1('));
    fclose(fid);  addpath(d);
    rng(5);  worst = 0;
    for i = 1:20000
        F = [8*randn; 8*randn; 25*rand - 3];  eta = 0.6*randn(3, 1);  psi = 0.5*randn;
        [f1, e1] = thrust_attitude_ref_v1(F, eta, psi, 0.5);
        [f2, e2] = thrust_attitude_ref(F, eta, psi, 0.5, 21.6);
        worst = max([worst, abs(f1 - f2), max(abs(e1 - e2))]);
    end
    rmpath(d);
    R = add(R, 'O5', 'thrust_attitude_ref(..., 21.6) vs v1-final code, 20000 inputs: max|d|', worst, 0);
else
    R = add(R, 'O5', 'thrust_attitude_ref: git show v1-final failed (not run)', 1, 0);
end

%% O6 p2_trans vs plant_p2_free
P = p2_params();
prm = [P.m_Q; P.m_L; P.L; P.g; P.zeta_s; P.K; P.K_w; P.U_ref];
worst = 0;
for i = 1:200
    q = randn(3, 1);  q = q / norm(q) * (1 + 1e-9*randn);
    x = [randn(3, 1); randn(3, 1); q; randn(3, 1)];
    fa = 15 + randn;  eta = 0.3*randn(3, 1);  w = [5*randn; 5*randn; randn];
    [dx, gam, nu, aQ, dmf, dlf, mon] = p2_trans(x, fa, eta, w, prm);
    Pf = P;  Pf.mode = 'free';
    [dx2, o2] = plant_p2_free(x, force_from_attitude(fa, eta), [w(1); w(2); 0], Pf);
    worst = max([worst, max(abs(dx - dx2)), max(abs(gam - x(1:3))), max(abs(nu - x(4:6))), ...
        max(abs(aQ - dx2(4:6))), max(abs(dmf - o2.d_mf)), max(abs(dlf - o2.d_lf)), abs(mon(1) - o2.T)]);
end
R = add(R, 'O6', 'p2_trans block code vs plant_p2_free: max|d| over 200 states', worst, 0);

%% O7
w = [6; -2; 1.5];  nu = [0.4; 0.3; -0.2];
r = [w(1:2); 0] - nu;
R = add(R, 'O7-hat', 'p2_wind_force_hat vs (K_w/U_ref)|w-v|(w-v), w_z dropped', ...
    max(abs(p2_wind_force_hat(w, nu, [0.2; 5]) - (0.2/5)*norm(r)*r)), 0);
tt = (0:1e-3:200).';
mon = struct('t', tt, 'v', [4.9 + 0*tt, 0*tt, 1e-13 + 0*tt, 1e-14 + 0*tt, 0.1 + 0*tt], 'ok', true, 'why', '');
mon.v(150001, 2) = 1;  mon.v(150001, 1) = -0.1;
tf = (0:1e-2:200).';
fl = struct('t', tf, 'v', [2 + 0*tf, 3 + 0*tf, 7.6675 + 0*tf, 4 + 0*tf], 'ok', true, 'why', '');
fl.v(tf < 100, 3) = 5;
S = p2_summary(mon, fl, 140, 7.6675);
R = add(R, 'O7-sum', sprintf('p2_summary: slack %d at %.3f s, sat_frac %.3f (expect 1 at 150, ~0.5)', ...
    S.n_slack, S.t_first_slack, S.sat_frac), abs(S.n_slack - 1) + abs(S.t_first_slack - 150) ...
    + abs(S.sat_frac - mean(tf >= 100)) + double(~S.phys_div), 1e-9);

fprintf('\n  check_p2_offline\n');
for i = 1:numel(R)
    fprintf('  %-12s %-5s %-11.3e %-9.1e %s\n', R(i).id, pf(R(i).pass), R(i).measured, R(i).tol, R(i).what);
end
fprintf('\n  %d/%d PASS\n', sum([R.pass]), numel(R));
end

function R = add(R, id, what, m, tol)
R(end + 1) = struct('id', id, 'what', what, 'measured', m, 'tol', tol, 'pass', m <= tol);
end
function s = pf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
