function [w_hat_x, trust_x, w_hat_y, trust_y, ...
          w_all_x, mag_all_x, w_all_y, mag_all_y] = im_est_estimator(vx, vy, t)
%#codegen
%IM_EST_ESTIMATOR  Online AR(2n) RLS + eig-based root-finding + Nyquist/
%  DC exclusion + per-slot nearest-neighbour assignment + trust gate +
%  coasting (docs/REGISTER_C.md sec 4.29/4.35/4.47). A codegen MATLAB
%  Function (Stateflow/EML) block - the SAME proven block type
%  Position_Observers/DO_12 (do_derivative) and Payload_Predictor
%  (payload_predictor) already use in this repo, not the legacy
%  Interpreted MATLAB Function block (multi-port support for that one
%  could not be verified without a MATLAB session to test against).
%  persistent state is standard, documented MATLAB Coder/Embedded
%  MATLAB practice. Every array here is FIXED SIZE (order=8 slots,
%  NaN-padded past the real count) - no dynamically-growing arrays, no
%  logical-index compaction, no nested structs - specifically to avoid
%  the variable-size codegen uncertainty that motivated (and then
%  un-motivated, sec 4.47) earlier design changes. Runs at fs=1Hz,
%  inherited from its input's sample time (the upstream Zero-Order
%  Hold in production; a From Workspace block at checkpoint 1.5).
%
%  Mirrors core/im_est_rls.m's own RLS update EXACTLY - same phi
%  convention (phi = -[x(k-1)..x(k-order)]), same lambda/order -
%  incrementally rather than in a batch loop, specifically so
%  checkpoint 1.5's 1e-9 rad/s agreement against that already-trusted
%  offline computation is a real regression test, not a coincidence.
%
%  Root-finding uses eig() of the companion matrix, not roots() -
%  roots() itself builds this same companion matrix internally and
%  calls eig() on it, so the values are identical by construction.
%
%  Untrusted slots (docs/REGISTER_C.md sec 4.29/4.35): |z|>=0.97 AND
%  <5% drift over the trailing 10 s AND t>=15s (a global floor, not a
%  per-slot "time since first trusted"). w_hat reports the 0.3 rad/s
%  placeholder for an untrusted slot - the internal tracking state is
%  NOT overwritten to the placeholder, so a slowly-converging slot
%  keeps its own continuity rather than being reset every untrusted
%  tick.
%
%  w_all_x/mag_all_x/w_all_y/mag_all_y (DIAGNOSTIC ONLY, sec 4.47
%  checkpoint 1.5): the raw ORDER=8 root set, BEFORE Nyquist/DC_GUARD
%  filtering or merging - directly comparable, element set for element
%  set (sort before comparing), to core/im_est_rls.m's own
%  R.roots(k,:) on identical input. Left unwired in the production
%  embedding - kept in this one file rather than forked into a second
%  copy, so the tested code and the deployed code never drift apart.

N_PAIRS = 4;
ORDER = 8;                      % 2*N_PAIRS, written as a literal for
                                 % codegen's fixed-size inference
LAM = 0.99;
NYQ_CUT = 0.9*pi;                % 0.9*Nyquist at DT_D = 1.0 s
DC_GUARD = 0.02;
DOMEGA_MIN = 0.05;
PLACEHOLDER = 0.3;
DRIFT_WIN = 10;
DRIFT_TOL = 0.05;
T_FLOOR = 15;

persistent theta_x theta_y P_x P_y buf_x buf_y n_seen_x n_seen_y
persistent slot_w_x slot_w_y slot_hist_x slot_hist_y

if isempty(n_seen_x)
    theta_x = zeros(ORDER,1); theta_y = zeros(ORDER,1);
    P_x = eye(ORDER)*1e3;     P_y = eye(ORDER)*1e3;
    buf_x = zeros(1,ORDER);   buf_y = zeros(1,ORDER);
    n_seen_x = 0;             n_seen_y = 0;
    slot_w_x = PLACEHOLDER*ones(1,N_PAIRS);
    slot_w_y = PLACEHOLDER*ones(1,N_PAIRS);
    slot_hist_x = PLACEHOLDER*ones(DRIFT_WIN,N_PAIRS);
    slot_hist_y = PLACEHOLDER*ones(DRIFT_WIN,N_PAIRS);
end

[theta_x, P_x, buf_x, n_seen_x, slot_w_x, slot_hist_x, w_hat_x, trust_x, w_all_x, mag_all_x] = ...
    tick_axis(theta_x, P_x, buf_x, n_seen_x, slot_w_x, slot_hist_x, vx, t, ...
    ORDER, N_PAIRS, LAM, NYQ_CUT, DC_GUARD, DOMEGA_MIN, PLACEHOLDER, DRIFT_TOL, T_FLOOR);
[theta_y, P_y, buf_y, n_seen_y, slot_w_y, slot_hist_y, w_hat_y, trust_y, w_all_y, mag_all_y] = ...
    tick_axis(theta_y, P_y, buf_y, n_seen_y, slot_w_y, slot_hist_y, vy, t, ...
    ORDER, N_PAIRS, LAM, NYQ_CUT, DC_GUARD, DOMEGA_MIN, PLACEHOLDER, DRIFT_TOL, T_FLOOR);
end

%% =====================================================================
function [theta, P, buf, n_seen, slot_w, slot_hist, w_hat, trust, w_all, mag_all] = ...
    tick_axis(theta, P, buf, n_seen, slot_w, slot_hist, v, t, order, n_pairs, ...
    lam, nyq_cut, dc_guard, domega_min, placeholder, drift_tol, t_floor)

% ---- RLS update (core/im_est_rls.m's own equations, incremental) ----
n_seen = n_seen + 1;
if n_seen > order
    phi   = -buf(:);
    e     = v - phi.'*theta;
    Pphi  = P*phi;
    denom = lam + phi.'*Pphi;
    Kk    = Pphi/denom;
    theta = theta + Kk*e;
    P     = (P - Kk*(Pphi.'))/lam;
end
buf = [v, buf(1:end-1)];

% ---- root-finding: companion matrix, eig() ----
c = theta(:).';
C = zeros(order,order);
C(1,:) = -c;
C(2:order,1:order-1) = eye(order-1);
r = eig(C);

w_all = abs(angle(r)).';          % 1 x order, DT_D = 1.0 s
mag_all = abs(r).';               % 1 x order

% ---- Nyquist/DC_GUARD exclusion + close-frequency merge, FIXED SIZE
% (order slots, NaN = not present) - no dynamically-growing arrays ----
w_cand = nan(1,order); m_cand = nan(1,order);
keep = (w_all <= nyq_cut) & (w_all > dc_guard);
w_tmp = w_all; w_tmp(~keep) = NaN;
m_tmp = mag_all; m_tmp(~keep) = NaN;
[w_tmp_sorted, ord] = sort(w_tmp);           % NaNs sort to the end
m_tmp_sorted = m_tmp(ord);
n_cand = 0;
for i = 1:order
    if isnan(w_tmp_sorted(i)), continue; end
    if n_cand > 0 && (w_tmp_sorted(i) - w_cand(n_cand) < domega_min)
        if m_tmp_sorted(i) > m_cand(n_cand)
            w_cand(n_cand) = w_tmp_sorted(i);
            m_cand(n_cand) = m_tmp_sorted(i);
        end
    else
        n_cand = n_cand + 1;
        w_cand(n_cand) = w_tmp_sorted(i);
        m_cand(n_cand) = m_tmp_sorted(i);
    end
end

% ---- greedy nearest-neighbour slot assignment (sec 4.29 item 4a);
% unmatched slots COAST - slot_w stays at its previous value. Fixed
% size throughout: n_pairs slots, order candidate cells (only the
% first n_cand are ever valid, the rest are NaN and never selected). ----
assigned = false(1,n_pairs);
mag_assigned = zeros(1,n_pairs);
avail = ~isnan(w_cand);
for pass = 1:n_pairs
    bestSlot = 0; bestCand = 0; bestDist = Inf;
    for s = 1:n_pairs
        if assigned(s), continue; end
        for k = 1:order
            if ~avail(k), continue; end
            d = abs(w_cand(k) - slot_w(s));
            if d < bestDist
                bestDist = d; bestSlot = s; bestCand = k;
            end
        end
    end
    if bestSlot == 0, break; end
    slot_w(bestSlot) = w_cand(bestCand);
    mag_assigned(bestSlot) = m_cand(bestCand);
    assigned(bestSlot) = true;
    avail(bestCand) = false;
end

slot_hist = [slot_hist(2:end,:); slot_w];

trust = false(1,n_pairs);
for s = 1:n_pairs
    h  = slot_hist(:,s);
    mh = mean(h);
    drift = (max(h)-min(h)) / max(mh, eps);
    trust(s) = assigned(s) && (mag_assigned(s) >= 0.97) && ...
               (drift < drift_tol) && (t >= t_floor);
end

w_hat = slot_w;
w_hat(~trust) = placeholder;
end
