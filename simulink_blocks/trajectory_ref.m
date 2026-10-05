function [gamma_d, nu_d, acc_d] = trajectory_ref(t, R, w, z0, tau_prev, traj_type, traj_par)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
gamma_d = zeros(3,1); nu_d = zeros(3,1); acc_d = zeros(3,1);
%
% traj_type selects the horizontal path; z is always z0 (constant altitude).
%   0  hover        R forced to 0 - see the note at that case, below
%   1  circle       R, w as before (Test 2-4 of the reference work)
%   2  figure-8 (Gerono)   x = A sin(w t), y = (A/2) sin(2 w t)
%   3  square, min-jerk edges, side D, edge time T, dwell T_h at each corner
%   4  multi-sine, four fixed frequencies, fixed phases, one amplitude scale
%
% traj_par is a FIXED-SIZE 4x1 vector (codegen requires fixed size), read
% differently by each type - see the case bodies. Types that need nothing
% from it (hover, circle) ignore it entirely.
%
% TEST_PLAN_PROMPT.md's Part 3.1 specifies the standard params for each type
% (T3a/T3b for figure-8, etc.) and this file only implements the geometry; it
% chooses no numbers of its own. This is infrastructure, not a scored
% experiment - no docs/REGISTER_*.md covers it, because the campaign's own
% rule only requires one per lettered phase (A-E) that scores a prediction.
%
% ------------------------------------------------------------------
% tau_prev : REFERENCE PREVIEW (docs/REGISTER_TAU.md §A2). Unchanged by this
%            addition, and unchanged in scope: it applies to acc_d ONLY.
%            gamma_d and nu_d stay at t for every traj_type, for the same
%            reason as before - gamma_d is what Err_Norm measures error
%            against, and advancing it would move the target rather than
%            improve tracking of it.
%
%            For traj_type = 1 this is still literally a ROTATION of the
%            reference-acceleration vector, because a circle's acc_d is one
%            sinusoid. For every other type there is no single frequency to
%            rotate by, so the general form is used instead: acc_d is the
%            SAME closed-form function of time as gamma_d/nu_d, evaluated at
%            t + tau_prev rather than at t. At traj_type = 1 the general form
%            and the rotation are the same computation (cos/sin of w*(t+tau)),
%            so this is not a second implementation living beside the first -
%            it IS the first, generalised.
%
%            tau_prev = 0 must reproduce the un-previewed trajectory bit for
%            bit at every traj_type, because t + 0 == t exactly. That is
%            checkpoint 3.1's "no-disturbance, closed-loop RMS" gate reduced
%            to its open-loop half, and verification/traj_check.m checks it directly.
%
% ------------------------------------------------------------------
% CODEGEN NOTES
% ------------------------------------------------------------------
% No persistent state: every type is a pure function of t. mod() is a
% MATLAB Coder / Stateflow supported function; used only in case 3.
% traj_par is read positionally and never resized - MATLAB Function blocks
% require fixed-size signals, and a 4x1 in every branch keeps the port
% width the same regardless of which traj_type is selected at run time.

tp = t + tau_prev;

switch traj_type
case 0
    % Hover. Mathematically IDENTICAL to case 1 with R = 0 - cos(w*t)*0 = 0
    % regardless of t or w, so nothing about w matters here. Written as its
    % own branch anyway, rather than forcing R = 0 into case 1 from the
    % caller, because a caller that forgets to zero R would otherwise fly a
    % circle while believing it had selected hover. verification/traj_check.m
    % verifies the two branches agree exactly at R = 0, so there are not two
    % independent implementations of the same geometry, only one written
    % twice for safety - and the check that they match is what keeps that
    % true.
    gamma_d = [0; 0; z0];
    nu_d    = [0; 0; 0];
    acc_d   = [0; 0; 0];

case 1
    % Circle (baseline). UNCHANGED from the pre-existing file, to the
    % character: this is checkpoint 3.1's bit-exactness gate.
    gamma_d = [R*cos(w*t);       R*sin(w*t);       z0];
    nu_d    = [-R*w*sin(w*t);    R*w*cos(w*t);     0 ];
    acc_d   = [-R*w^2*cos(w*tp); -R*w^2*sin(w*tp); 0 ];

case 2
    % Figure-8 (Gerono). x = A sin(w t), y = (A/2) sin(2 w t).
    % traj_par(1) = A. w is the SAME input circle uses - T3a reuses circle's
    % w = 1.575 rad/s so the y-axis runs at 2w = 3.15 rad/s (deliberately
    % near the pendulum's natural frequency at L = 1.0, per the registration);
    % T3b uses w = 0.7875 rad/s, off resonance.
    A = traj_par(1);
    gamma_d = [ A*sin(w*t);              (A/2)*sin(2*w*t);              z0];
    nu_d    = [ A*w*cos(w*t);             A*w*cos(2*w*t);                0];
    acc_d   = [-A*w^2*sin(w*tp);        -2*A*w^2*sin(2*w*tp);            0];

case 3
    % Square, min-jerk edges. traj_par = [D; T; T_h; 0] - side length, edge
    % duration, corner dwell. A closed, counterclockwise square centred on
    % the origin (like the circle and the figure-8), corners at
    % (D/2,-D/2) -> (D/2,D/2) -> (-D/2,D/2) -> (-D/2,-D/2) -> back to start.
    D   = traj_par(1);
    T   = traj_par(2);
    T_h = traj_par(3);
    h   = D/2;
    CORNERS = [ h -h;  h h;  -h h;  -h -h ];   % 4x2, row k = corner k (0-based)
    [p, v, ~]  = square_minjerk(t,  CORNERS, T, T_h);
    [~, ~, ap] = square_minjerk(tp, CORNERS, T, T_h);
    gamma_d = [p(1); p(2); z0];
    nu_d    = [v(1); v(2); 0];
    acc_d   = [ap(1); ap(2); 0];

case 4
    % Multi-sine. Frequencies and phases are FIXED CONSTANTS, not run-time
    % inputs: a reference trajectory has to be reproducible bit for bit, and
    % a phase drawn at run time from any RNG - MATLAB's or otherwise - is
    % not a compile-time constant a %#codegen function can carry. They were
    % chosen once, are written here literally, and are not revisited.
    % traj_par(1) is the one free number: an amplitude SCALE, calibrated by
    % verification/traj_check.m so that v_max = 1.26 m/s. y uses the same
    % frequencies with an added quarter-turn-ish phase offset per harmonic,
    % so x and y are not the same signal shifted in time.
    WK  = [0.50, 1.10, 1.90, 2.70];
    PHX = [0.00, 1.30, 2.70, 4.10];
    PHY = [0.80, 2.10, 3.50, 5.60];
    AMPW = [1/0.50, 1/1.10, 1/1.90, 1/2.70];   % flattens each term's velocity peak
    c = traj_par(1);
    [px, vx, ~]    = multisine_axis(t,  WK, PHX, AMPW, c);
    [py, vy, ~]    = multisine_axis(t,  WK, PHY, AMPW, c);
    [~,  ~,  axp]  = multisine_axis(tp, WK, PHX, AMPW, c);
    [~,  ~,  ayp]  = multisine_axis(tp, WK, PHY, AMPW, c);
    gamma_d = [px; py; z0];
    nu_d    = [vx; vy; 0];
    acc_d   = [axp; ayp; 0];

otherwise
    % An unrecognised traj_type is a configuration error, not hover: falling
    % through to hover would make a typo in traj_type invisible - the vehicle
    % would still fly, just not the trajectory anyone asked for. This branch
    % keeps gamma_d/nu_d/acc_d at the zeros() declared above, which for
    % z0 = 0 is at least conspicuously wrong (in the ground) rather than
    % plausibly wrong (a valid-looking hover).
end
end


%% =====================================================================
function [p, v, a] = square_minjerk(t, corners, T, T_h)
%SQUARE_MINJERK  Position/velocity/acceleration on the 4-edge square path.
%
%  corners is 4x2, row k+1 = corner k (k = 0..3, MATLAB 1-indexed rows).
%  Edge k runs from corner k to corner k+1 (mod 4), taking time T, followed
%  by a T_h dwell AT corner k+1 before edge k+1 begins.
p = zeros(2,1); v = zeros(2,1); a = zeros(2,1);

Tcell = T + T_h;
Ttot  = 4*Tcell;
tm    = mod(t, Ttot);
if tm < 0, tm = tm + Ttot; end     % mod() on a negative t in MATLAB Coder
                                    % already returns a nonnegative result for
                                    % a positive Ttot, but this is one line of
                                    % insurance against relying on that.

k   = floor(tm/Tcell);             % 0..3, which edge+dwell slot
if k > 3, k = 3; end               % guards the tm == Ttot boundary sample
tl  = tm - k*Tcell;

k0 = mod(k,   4) + 1;              % 1-indexed row of the START corner
k1 = mod(k+1, 4) + 1;              % 1-indexed row of the END corner
p0 = corners(k0,:).';
p1 = corners(k1,:).';

if tl < T
    s  = tl/T;
    s2 = s*s; s3 = s2*s; s4 = s3*s; s5 = s4*s;
    blend  = 10*s3 - 15*s4 + 6*s5;
    dblend = (30*s2 - 60*s3 + 30*s4)/T;
    ddblend = (60*s - 180*s2 + 120*s3)/T^2;
    d = p1 - p0;
    p = p0 + d*blend;
    v = d*dblend;
    a = d*ddblend;
else
    % Dwell: sitting at the corner just reached.
    p = p1;
    v = zeros(2,1);
    a = zeros(2,1);
end
end


%% =====================================================================
function [p, v, a] = multisine_axis(t, wk, phk, ampw, c)
%MULTISINE_AXIS  One axis of the fixed-frequency multi-sine reference.
%
%  p(t) = c * sum_k ampw(k) * sin(wk(k)*t + phk(k))
%
%  wk, phk, ampw are 1x4 - fixed at the call site, never resized, so this
%  stays codegen-legal with no loop bound that depends on run-time data.
p = 0; v = 0; a = 0;
for k = 1:4
    ph = wk(k)*t + phk(k);
    p = p + c*ampw(k)*sin(ph);
    v = v + c*ampw(k)*wk(k)*cos(ph);
    a = a - c*ampw(k)*wk(k)^2*sin(ph);
end
end
