function [e, bcoef, acoef] = pa_track_filt(r, m, Ky, Kv, dt)
%PA_TRACK_FILT  Residual FORCE error -> predicted tracking error, through the
%               closed-loop dynamics.
%
%   e = pa_track_filt(r, m, Ky, Kv, dt)
%
%   r  : (n,3) residual force error [N] = d_hat - d
%   e  : (n,1) norm of the predicted position error [m]
%
%  ======================================================================
%  WHY THIS QUANTITY AND NOT THE DC GAIN
%  ======================================================================
%  The position error satisfies
%      e_ddot + Kv*e_dot + Ky*e = (d - d_hat)/m
%  so the effect of a residual force error on tracking passes through
%      H(s) = 1/(s^2 + Kv*s + Ky),   with DC gain 1/(m*Ky).
%
%  The DC gain is ONE POINT of that response. Measured in §0.29 of the
%  development log: the DC-level difference between PI-MoE and persistence has
%  the right sign (29 of 30 segments), but its correlation with the difference
%  in tracking is only +0.132 once normalised - that is, it explains nothing
%  quantitatively. The right quantity is the residual energy WEIGHTED by
%  |H(jw)|^2, and the cheapest way to obtain it is to filter the residual force
%  error through H itself and then measure.
%
%  ======================================================================
%  THE NON-FEEDTHROUGH FORM - AND A ONE-SAMPLE OFFSET THAT WAS MEASURED
%  ======================================================================
%  Under ZOH, u is held on [k, k+1) and x(k+1) = Ad*x(k) + Bd*u(k), so the
%  output y(k) = C*x(k) does NOT depend on u(k). That is the correct form.
%
%  verification/verify_pa_mobadc.m step 7 originally wrote the loop as
%      x = Ad*x + Bd*r(q,:);  ep(q) = norm(x(1,:));
%  i.e. it took the output AFTER the update, one sample early. Measured: an
%  offset of 8.7e-05 on an amplitude of ~0.07, about 0.1%. Small - but it is a
%  CHOICE rather than machine error, and two different conventions cannot be
%  compared against each other. This function fixes the correct form, and both
%  the verify script and pa_configs call it.
%
%  The three axes are independent (Ky, Kv are scalars), so filter each column
%  and then take the norm.

if nargin < 5, dt = 1e-3; end
if ~isscalar(Ky), Ky = Ky(1,1); end
if ~isscalar(Kv), Kv = Kv(1,1); end

A2 = [0 1; -Ky -Kv];
B2 = [0; 1/m];
Ad = expm(A2*dt);
Bd = A2 \ ((Ad - eye(2)) * B2);
C  = [1 0];

% Cayley-Hamilton for order 2: (zI - Ad)^-1 has denominator z^2 - tr*z + det.
tr = Ad(1,1) + Ad(2,2);
de = det(Ad);
acoef = [1, -tr, de];
bcoef = [0, C*Bd, C*Ad*Bd - tr*(C*Bd)];

e = sqrt(sum(filter(bcoef, acoef, r).^2, 2));
end
