function info = make_payload_inject(K, varargin)
%MAKE_PAYLOAD_INJECT  The OUT-OF-MODEL part of the payload disturbance,
%                     computed offline.
%
%   info = make_payload_inject(0.5)          % K_wp/K_w = 0.5
%   info = make_payload_inject(0)            % an all-zero series - disabled
%
%  ======================================================================
%  P0: JOINING THE HEADLINE TO THE VALIDITY CURVE
%  ======================================================================
%  The validity curve (§0.40) was measured under condition C: a physical
%  pendulum, a CONSTANT wind on the body, a payload disturbance of 0.115 N RMS.
%  The headline (§0.46) was measured under condition B: a 1.5 N sine (1.06 N
%  RMS - 9.3x larger), the REAL wind on the body. Same Test 2 trajectory, but
%  two conditions that differ in amplitude AND in the body wind.
%
%  This function injects the out-of-model part into condition B EXACTLY: keep
%  the 1.5 N sine, keep the real wind on the body, and only ADD the pendulum's
%  response to the wind hitting the payload. That makes o (the off-grid energy)
%  an independent variable while everything else stays identical to the
%  headline.
%
%  ======================================================================
%  WHY LINEAR SUPERPOSITION IS LEGITIMATE HERE
%  ======================================================================
%  §0.35 measured it: on a circular trajectory the physical pendulum is 99.98%
%  a single sine at sigma - i.e. a response FORCED by the trajectory. For a
%  linearised pendulum the response to (trajectory + wind) = the response to
%  the trajectory + the response to the wind. The headline's sine IS the first
%  term; this function computes the second. Their sum is a linearised pendulum
%  in wind - not some invented disturbance model.
%
%  The response to wind is EXOGENOUS (it does not depend on the UAV state at
%  linear order), so computing it in advance and loading it through From
%  Workspace is identical to running it online - the same argument already used
%  for PI-MoE (export_wind_sim.py).
%
%  ======================================================================
%  THE FORCE LAW AND ITS COEFFICIENT
%  ======================================================================
%  F_wp = K * K_w * w_xy(t), with K = K_wp/K_w = the ratio of effective drag
%  areas (§0.37). The same linear law as the UAV channel, for the same reason.
%
%  A linearised pendulum, per axis:
%      th'' + 2*zeta*wn*th' + wn^2*th = F_wp/(m_p*L),   wn = sqrt(g/L)
%      d_wp = m_p*g*th                             (small angle, T ~ m_p*g)
%  Discretised EXACTLY (ZOH) on the wind's own 20 Hz grid - wn*dt = 0.157,
%  comfortably fine enough.
%
%  o is computed on the TOTAL (sine + inj) by projecting onto the harmonics of
%  sigma, with the same function as sweep_payload_regime, so it is directly
%  comparable with §0.40.

opt = struct('TStat', 140, 'NH', 12);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

need = {'wind_ts','K_w','m_p','L','zeta_p','g','payload_amp','payload_sigma'};
for i = 1:numel(need)
    assert(logical(evalin('base', sprintf('exist(''%s'',''var'')', need{i}))), ...
        'make_payload_inject: %s is not in the base workspace. Run wind_sim_load + init first.', ...
        need{i});
end
w   = evalin('base','wind_ts');
K_w = evalin('base','K_w');   m_p = evalin('base','m_p');
L   = evalin('base','L');     zp  = evalin('base','zeta_p');
g   = evalin('base','g');     A0  = evalin('base','payload_amp');
sg  = evalin('base','payload_sigma');

t = w.time(:);  v = w.signals.values;
n = numel(t);   dt = median(diff(t));
assert(dt > 0, 'make_payload_inject: the timestamps are not increasing.');

d = zeros(n, 3);
if K > 0
    wn = sqrt(g/L);
    Ac = [0 1; -wn^2 -2*zp*wn];  Bc = [0; 1];
    % An exact ZOH: [Ad Bd; 0 I] = expm([Ac Bc; 0 0]*dt)
    Md = expm([Ac Bc; zeros(1,3)]*dt);
    Ad = Md(1:2,1:2);  Bd = Md(1:2,3);
    F  = K * K_w * v(:,1:2) / (m_p*L);          % [rad/s^2], both lateral axes
    x  = zeros(2,2);                            % [th; thd] for x and y
    th = zeros(n, 2);
    for k = 2:n
        x = Ad*x + Bd*F(k-1,:);
        th(k,:) = x(1,:);
    end
    d(:,1:2) = m_p*g*th;
end
inj = struct('time', t, 'signals', struct('values', d, 'dimensions', 3));
assignin('base', 'dmf_inj_ts', inj);

% o on the TOTAL, over the settled window, projected onto the harmonics - the
% same recipe as sweep_payload_regime.
m  = t >= opt.TStat;  tt = t(m);
sn = [zeros(sum(m),1), A0*sin(sg*tt), zeros(sum(m),1)];
tot = (sn + d(m,:));  tot = tot(:,1:2) - mean(tot(:,1:2),1);
r = tot;
for h = 1:opt.NH
    c = 2*mean(tot.*cos(h*sg*tt), 1);  s = 2*mean(tot.*sin(h*sg*tt), 1);
    r = r - cos(h*sg*tt)*c - sin(h*sg*tt)*s;
end
% ---- THE DC / AC SPLIT. Required; see the note below. ----
%
% wind_ts carries the FULL wind, mean field included (wind_sim_load's 'MeanOnly'
% option exists precisely to make that visible). A linearised pendulum has a
% static force-to-force gain of EXACTLY 1:
%       d_DC = m_p*g*th_DC = m_p*g * F_DC/(m_p*L*wn^2) = F_DC  (since L*wn^2 = g)
% so a mean wind U produces a STATIC payload force offset of K*K_w*U.
%
% The two quantities measured in this file are NOT consistent about that DC
% component:
%   rms_inj  is taken ON d, with NO mean removed          -> DC included
%   o        is taken on (sin + inj) WITH the mean removed -> DC excluded
% So r = rms_inj/rms_sine and o measure two different things, and the ratio
% o/o_expected is pulled down by exactly (ac/rms_inj)^2 without needing to
% invoke any resonance at all.
%
% That is a COMPETING HYPOTHESIS against the resonance explanation in §0.62/
% 0.64, and it is testable: if o ~ r_ac^2/(1+r_ac^2), then o is not broken at
% all - only r is contaminated by the DC term. Return both fields and let
% diag_r_real decide.
dm  = d(m,1:2);
dc  = norm(mean(dm, 1));                       % magnitude of the static offset [N]
ac  = sqrt(mean(sum((dm - mean(dm,1)).^2, 2)));% the oscillating part [N]
rmi = sqrt(mean(sum(d(m,:).^2,2)));
assert(abs(rmi^2 - (dc^2 + ac^2)) < 1e-9*max(1,rmi^2), ...
    'make_payload_inject: the DC/AC split does not reconstruct rms_inj (internal error).');

info = struct('K', K, 'o', sum(r(:).^2)/sum(tot(:).^2), ...
              'rms_inj', rmi, 'dc_inj', dc, 'ac_inj', ac, ...
              'rms_sine', A0/sqrt(2), 'wn', sqrt(g/L), 'dt', dt);
end
