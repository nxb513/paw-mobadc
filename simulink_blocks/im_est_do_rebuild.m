function [A_do, B_do, l_gain, G_do, fallback, reason] = ...
    im_est_do_rebuild(w_hat_x, trust_x, w_hat_y, trust_y, wn_p, sigma_z, l_axis, strict)
%#codegen
%IM_EST_DO_REBUILD  Online IM = {0, w_hat_k, wn_p} internal-model
%  matrix rebuild (docs/REGISTER_C.md sec 4.29/4.35/4.46/4.47) - a
%  codegen MATLAB Function (Stateflow/EML) block, the SAME proven
%  block type as im_est_estimator.m and do_derivative/
%  payload_predictor, not build_do_matrices.m called directly:
%  build_do_matrices.m's cell-array/varargin dispatch is not verified
%  codegen-safe, and this function's do_w_axis STRUCTURE never varies
%  (always DC + 4 harmonics + wn_p on x/y, the unchanged {0,sigma_z}
%  on z - n_state = 25, fixed) - only the FREQUENCY VALUES at each
%  slot change - so a direct, fixed-index construction is used
%  instead, with build_do_matrices.m's own stability check (eig(A_cl)
%  < 0) replicated exactly. The CONSTRUCTION-EQUIVALENCE checkpoint
%  (sec 4.47) - forcing every slot to the exact-frequency reference's
%  own values and comparing against build_do_matrices's OWN output
%  bit for bit - exists specifically to catch a construction error
%  here, so drift is not asserted away, it is tested for.
%
%  State order (sec 4.46's own fixed layout, matching
%  build_do_matrices.m's "by axis first, then by frequency" rule with
%  the harmonics in slot order 1-4, then wn_p):
%    x: [1]=DC [2 3]=h1 [4 5]=h2 [6 7]=h3 [8 9]=h4 [10 11]=wn_p
%    y: [12]=DC [13 14]=h1 [15 16]=h2 [17 18]=h3 [19 20]=h4 [21 22]=wn_p
%    z: [23]=DC [24 25]=sigma_z
%
%  DECOUPLING (sec 4.47 item 3, the refinement to sec 4.29/4.35's
%  placeholder-only design): an untrusted harmonic slot (trust_x/y(k)
%  false) still occupies its 2 states (fixed size, sec 4.47's own
%  registered reasoning) but gets l_gain=0 for both AND is excluded
%  from B_do - completely inert, not merely mistuned. DC and wn_p are
%  never coasted/untrusted, so decoupling only ever applies to the 4
%  harmonic slots per axis.
%
%  FALLBACK (sec 4.46 item 1): candidate frequencies within
%  DOMEGA_MIN=0.05 rad/s of each other (checked among the axis's own
%  4 harmonics + wn_p - a defensive check on the REBUILD input, in
%  addition to im_est_estimator.m's own pre-assignment merge, sec
%  4.47's own note) OR a resulting UNSTABLE Acl -> HOLD the previous
%  A_do/B_do/l_gain (persistent, fixed-size - no Memory-block feedback
%  needed, same reasoning as im_est_estimator.m's own state) and
%  report fallback=true, reason (1=dup, 2=unstable). strict=true skips
%  the hold and errors immediately instead - for checkpoint-building
%  only, never a production/scored run (sec 4.46 item 1c).

N = 25;
DOMEGA_MIN = 0.05;
M_UAV = 1.121;

persistent A_prev B_prev L_prev initialized
if isempty(initialized)
    A_prev = zeros(N,N);
    B_prev = zeros(3,N);
    L_prev = zeros(N,6);
    initialized = true;
end

G_do = (1/M_UAV)*[zeros(3,3); eye(3)];

% ---- defensive dup check: each axis's own 4 harmonics + wn_p ----
% Only TRUSTED harmonics (+ wn_p, always trusted) can collide in a way
% that matters: a decoupled/untrusted slot is excluded from B_do and
% l_gain, so its frequency value never enters Acl's own observable
% dynamics - two untrusted slots sharing the SAME placeholder (as every
% slot does before any is trusted, during warmup) is not a real
% duplicate in the sense build_do_matrices.m's own assertion guards
% against, and must not spuriously trigger a fallback.
tx = [trust_x(1) trust_x(2) trust_x(3) trust_x(4) true];
dup = false;
fx = [w_hat_x(1) w_hat_x(2) w_hat_x(3) w_hat_x(4) wn_p];
for i = 1:5
    for j = i+1:5
        if tx(i) && tx(j) && abs(fx(i)-fx(j)) < DOMEGA_MIN, dup = true; end
    end
end
ty = [trust_y(1) trust_y(2) trust_y(3) trust_y(4) true];
fy = [w_hat_y(1) w_hat_y(2) w_hat_y(3) w_hat_y(4) wn_p];
for i = 1:5
    for j = i+1:5
        if ty(i) && ty(j) && abs(fy(i)-fy(j)) < DOMEGA_MIN, dup = true; end
    end
end

if dup && strict
    error('im_est_do_rebuild:dup', 'candidate frequencies within DOMEGA_MIN of each other (strict mode).');
end

A_new = zeros(N,N);
B_new = zeros(3,N);
L_new = zeros(N,6);

% ---- x axis: states 1..11 ----
A_new(1,1) = 0;  B_new(1,1) = 1;  L_new(1,4) = l_axis(1);
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 2, w_hat_x(1), l_axis(1), 1, trust_x(1));
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 4, w_hat_x(2), l_axis(1), 1, trust_x(2));
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 6, w_hat_x(3), l_axis(1), 1, trust_x(3));
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 8, w_hat_x(4), l_axis(1), 1, trust_x(4));
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 10, wn_p, l_axis(1), 1, true);

% ---- y axis: states 12..22 ----
A_new(12,12) = 0;  B_new(2,12) = 1;  L_new(12,5) = l_axis(2);
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 13, w_hat_y(1), l_axis(2), 2, trust_y(1));
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 15, w_hat_y(2), l_axis(2), 2, trust_y(2));
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 17, w_hat_y(3), l_axis(2), 2, trust_y(3));
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 19, w_hat_y(4), l_axis(2), 2, trust_y(4));
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 21, wn_p, l_axis(2), 2, true);

% ---- z axis: states 23..25 (unchanged {0, sigma_z} - never estimated) ----
A_new(23,23) = 0;  B_new(3,23) = 1;  L_new(23,6) = l_axis(3);
[A_new, B_new, L_new] = put_harm(A_new, B_new, L_new, 24, sigma_z, l_axis(3), 3, true);

% ---- stability check on the ACTIVE subsystem only ----
% A decoupled harmonic block still carries its own [0 w;-w 0] open-loop
% dynamics in A_new (by design - sec 4.47 item 3: the state exists and
% evolves, just isolated), whose eigenvalues sit exactly on the
% imaginary axis (Re=0) - marginally stable, not Re<0. Checking eig()
% of the FULL Acl would fail this test whenever ANY slot is untrusted,
% including the entire warmup period before t>=15s, which defeats the
% design (constant spurious fallback). Since a decoupled block is
% provably block-diagonal (B_new/L_new are both zero for it - no
% coupling in or out), its own marginal eigenvalues are harmless and
% irrelevant to whether the ACTIVE subsystem is stable. A_check patches
% each decoupled block's diagonal to a trivially-stable dummy (-I),
% fixed-index (no variable-size extraction needed) - it changes nothing
% about the ACTUAL A_do returned below, only what stability is
% evaluated against.
A_check = A_new;
A_check = patch_if_untrusted(A_check, 2,  trust_x(1));
A_check = patch_if_untrusted(A_check, 4,  trust_x(2));
A_check = patch_if_untrusted(A_check, 6,  trust_x(3));
A_check = patch_if_untrusted(A_check, 8,  trust_x(4));
A_check = patch_if_untrusted(A_check, 13, trust_y(1));
A_check = patch_if_untrusted(A_check, 15, trust_y(2));
A_check = patch_if_untrusted(A_check, 17, trust_y(3));
A_check = patch_if_untrusted(A_check, 19, trust_y(4));

Acl = A_check - L_new*G_do*B_new;
ev = eig(Acl);
stable = max(real(ev)) < 0;

if (~stable) && strict
    error('im_est_do_rebuild:unstable', 'Acl not stable with the current w_hat (strict mode).');
end

if dup || ~stable
    A_do = A_prev; B_do = B_prev; l_gain = L_prev;
    fallback = true;
    if dup, reason = 1; else, reason = 2; end
else
    A_do = A_new; B_do = B_new; l_gain = L_new;
    A_prev = A_new; B_prev = B_new; L_prev = L_new;
    fallback = false;
    reason = 0;
end
end

%% =====================================================================
function [A, B, L] = put_harm(A, B, L, idx1, w, lg, axis_col, trust)
%PUT_HARM  Place one 2-state harmonic block at states idx1,idx1+1 -
%  build_do_matrices.m's own [0 w;-w 0] / B_do(i,b+1)=1 / l_gain
%  pattern, fixed-index. trust=false -> decoupled (sec 4.47 item 3):
%  l_gain stays 0 for both states, B stays 0 - the state still exists
%  (fixed size) but contributes to and is corrected by nothing.
idx2 = idx1 + 1;
A(idx1,idx1) = 0;  A(idx1,idx2) = w;
A(idx2,idx1) = -w; A(idx2,idx2) = 0;
if trust
    B(axis_col, idx1) = 1;
    L(idx1, 3+axis_col) = lg;
    L(idx2, 3+axis_col) = lg;
end
end

%% =====================================================================
function A = patch_if_untrusted(A, idx1, trust)
%PATCH_IF_UNTRUSTED  For the stability check only (sec 4.47's own
%  reasoning, see the caller): a decoupled block's marginal (Re=0)
%  open-loop eigenvalues are harmless (B/l_gain are already zero for
%  it, so it cannot destabilize anything, block-diagonal) but would
%  otherwise fail max(real(eig(.)))<0 spuriously. Overwrite ONLY the
%  stability-check copy's diagonal block to a trivially-stable dummy.
if ~trust
    idx2 = idx1 + 1;
    A(idx1,idx1) = -1; A(idx1,idx2) = 0;
    A(idx2,idx1) = 0;  A(idx2,idx2) = -1;
end
end
