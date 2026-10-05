function [p_noV, p_V] = traj5_predict_residual(s, z0, tau_V)
%TRAJ5_PREDICT_RESIDUAL  docs/REGISTER_C.md Section 4.2, evaluated for one
%                        trajectory scenario.
%
%   [p_noV, p_V] = traj5_predict_residual(s, z0, tau_V)
%
%   s : struct with fields ty, par, R, w, Ttot (the exact trajectory period)
%       - the SC(i) scenario structs diag_traj5_floor.m and
%       diag_traj5_crosscheck.m both build.
%
%  acc_d(t), tau_prev = 0, over exactly one period -> FFT per axis -> the
%  closed-loop model (Hr-1)/D per axis -> IFFT -> mean_t ||e||. Twice: once
%  with Hr = H (no preview), once with Hr = H*exp(jw*tau_V) (preview).
%
%  Extracted out of analysis/diag_traj5_floor.m (where it started as a local
%  function) when analysis/diag_traj5_crosscheck.m needed the identical
%  prediction for two more scenarios (double-amplitude circle and fig8 T3a,
%  the linear counter-check) - one source for the model, not a second copy
%  that could quietly drift from the first.

% ---- constants, ported from tools/tau_star.py (matching init_MOBADC_params.m) ----
m_mass = 1.121;
Ixx = 0.01; Iyy = 0.0082;
Kg = 12.0; Kn = 8.0;
K_eta   = [2.16, 1.92, 0.59];
K_omega = [0.20, 0.12, 0.12];

% x <- pitch (Iyy, K_eta(2), K_omega(2)); y <- roll (Ixx, K_eta(1), K_omega(1))
wnx = sqrt(K_eta(2)/Iyy); zx = (K_omega(2)/Iyy) / (2*wnx);
wny = sqrt(K_eta(1)/Ixx); zy = (K_omega(1)/Ixx) / (2*wny);

% ---- acc_d(t), tau_prev = 0, exactly one period, 200 Hz ----
fs = 200; Ttot = s.Ttot;
N  = round(fs*Ttot);
dt = Ttot/N;
t  = (0:N-1)'*dt;
ax = zeros(N,1); ay = zeros(N,1);
for k = 1:N
    [~,~,a] = trajectory_ref(t(k), s.R, s.w, z0, 0, s.ty, s.par);
    ax(k) = a(1); ay(k) = a(2);
end

Fx = fft(m_mass*ax);
Fy = fft(m_mass*ay);

freq = (0:N-1)'/(N*dt);
freq(freq > 1/(2*dt)) = freq(freq > 1/(2*dt)) - 1/dt;   % fold to signed frequency
w = 2*pi*freq;

Hx = wnx^2 ./ ((1i*w).^2 + 2*zx*wnx*(1i*w) + wnx^2);
Hy = wny^2 ./ ((1i*w).^2 + 2*zy*wny*(1i*w) + wny^2);
Dx = m_mass*(1i*w).^2 + Hx.*m_mass.*(Kg + Kn*(1i*w));
Dy = m_mass*(1i*w).^2 + Hy.*m_mass.*(Kg + Kn*(1i*w));

p_noV = solve_one(Hx, Hy, Dx, Dy, Fx, Fy, w, 0);
p_V   = solve_one(Hx, Hy, Dx, Dy, Fx, Fy, w, tau_V);
end

function p = solve_one(Hx, Hy, Dx, Dy, Fx, Fy, w, tau_prev)
Hrx = Hx .* exp(1i*w*tau_prev);
Hry = Hy .* exp(1i*w*tau_prev);
Ex = (Hrx - 1)./Dx .* Fx;
Ey = (Hry - 1)./Dy .* Fy;
ex = real(ifft(Ex));
ey = real(ifft(Ey));
p  = mean(hypot(ex, ey));
end
