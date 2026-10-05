function dmf_hat_p = payload_predictor(gamma, nu, z, l_gain, do_w, n_state_axis, tau_pred)
%#codegen
%PAYLOAD_PREDICTOR  Physical predictor for the payload disturbance: dmf_hat(t + tau).
%
%  Inputs
%     gamma, nu     : UAV position / velocity, inertial frame
%     z             : disturbance observer (DO) state, FLAT across all 3 axes
%     l_gain        : the DO's l gain (same as the DO_Out block)
%     do_w          : each exosystem block's frequency, FLAT across all 3
%                     axes, in the SAME order build_do_matrices.m used to
%                     build z (axis 1 in full, then axis 2, then axis 3)
%     n_state_axis  : 3x1, the number of STATES (not frequencies) each
%                     axis owns within z/xi_hat - Part 3.3 (TEST_PLAN_PROMPT.md)
%     tau_pred      : prediction horizon, s
%  Output
%     dmf_hat_p : the payload disturbance estimate AT TIME t + tau_pred, 3x1, N
%
%  ----------------------------------------------------------------------
%  PART 3.3: WHY n_state_axis WAS ADDED INSTEAD OF MAKING do_w A CELL
%  ----------------------------------------------------------------------
%  build/build_do_matrices.m's new form takes do_w_axis, a CELL {wx,wy,wz}
%  - but this is a %#codegen Simulink MATLAB Function block, and every
%  signal crossing a Simulink wire needs a FIXED SIZE at compile time;
%  Simulink cannot carry a cell type across a signal line. do_w here STAYS
%  a FLAT vector (exactly as before), just no longer IMPLICITLY split into
%  three equal shares - n_state_axis(i) says EXACTLY how many STATES (not
%  how many do_w entries) belong to axis i, and this function works out
%  how many do_w entries that is by accumulating block sizes (1 for DC, 2
%  for a harmonic) until that target is reached - the same logic
%  build_do_matrices.m uses to turn do_w_axis{i} into states, run in
%  reverse here.
%
%  With n_state_axis = [n_as;n_as;n_as] (all three axes equal, the
%  original case) and do_w in the OLD order, the loop below consumes
%  exactly n_as states per axis, identical to the old behaviour - which is
%  why Checkpoint 3.3's bit-exact gate (circle) needs no special-case branch.
%
%  ----------------------------------------------------------------------
%  DERIVATION (unchanged)
%  ----------------------------------------------------------------------
%  DO gia thiet nhieu tai sinh boi mot exosystem tuyen tinh, pt. (6):
%       xi_dot = A*xi,      d_mf = B*xi
%  Neu gia thiet do dung thi trang thai tuong lai biet duoc chinh xac:
%       xi(t + tau) = e^{A*tau} * xi(t)
%  va uoc luong hien tai la xi_hat = z + l*[gamma; nu]  (pt. 11a). Nen:
%       dmf_hat_p = B * e^{A*tau} * xi_hat
%
%  A la khoi cheo cac khoi 2x2 [0 w; -w 0], moi khoi mot tan so. e^{A*tau}
%  vi vay la mot phep QUAY, va MOI KHOI QUAY MOT GOC KHAC NHAU: khoi o tan so
%  w quay goc w*tau.
%       e^{A_k*tau} = [ cos(w_k*tau)   sin(w_k*tau);
%                      -sin(w_k*tau)   cos(w_k*tau) ]
%  Khong can expm - hai ham luong giac cho moi khoi.
%
%  B lay thanh phan LE cua moi khoi va CONG chung lai (d_mf cua mot truc la
%  tong dong gop cua cac hoa), nen chi can hang thu nhat cua moi phep quay:
%       dmf_hat_p(i) = sum_k [ cos(w_k*tau)*xi(le_k) + sin(w_k*tau)*xi(chan_k) ]
%
%  ----------------------------------------------------------------------
%  STATE ORDER - must match build_do_matrices
%  ----------------------------------------------------------------------
%  By AXIS first, then by FREQUENCY (in the order do_w_axis{i} lists them):
%       [axis1_freq1(1 or 2), axis1_freq2(...), axis2_freq1(...), ...]
%  With n_state_axis equal across axes and do_w in the old order, this
%  reduces to exactly the original 6/9/... state layout.
%
%  BLOCKS OF DIFFERENT SIZES, NOW ALSO ACROSS AXES (new - Part 3.3):
%  frequency 0 is the ONE-DIMENSIONAL DC mode, 1 state (§0.68 - 97.8% of
%  the payload channel's model error is a constant force); any other
%  frequency takes 2. The original code ASSUMED all 3 axes had the SAME
%  state count (numel(z) == 3*n_as); this one no longer does -
%  n_state_axis states it separately per axis.
%
%  ----------------------------------------------------------------------
%  TAU_PRED (unchanged)
%  ----------------------------------------------------------------------
%  Bang do tre HIEU DUNG tren duong luc, DO DUOC chu khong tinh ra: quet tau
%  o nhanh sin cho thay diem triet tieu (RMS_y = RMS_x) o tau = 140 ms.
%  Mo hinh chi tinh vong tu the bac hai cho 93 ms, nen ~47 ms den tu phan mo
%  hinh do khong co (phi tuyen thrust_attitude_ref, quan sat tu the, C(eta)).
%  Xem docs/AUDIT.md muc E.
%
%  ----------------------------------------------------------------------
%  GIOI HAN - PHAI GHI TRONG PAPER (khong doi)
%  ----------------------------------------------------------------------
%  Phep quay lay ca thanh phan CHAN cua exosystem vao dau ra. Thanh phan do
%  khong duoc quan sat truc tiep (B chi lay thanh phan le) nen sai so uoc
%  luong cua no lon hon, va bo du doan khuech dai no len theo sin(w*tau).
%  Do duoc: residual cua nhanh sin tang tu 0.0024 N (tau = 0) len 0.0118 N
%  (tau = 140 ms), voi mot vach moi hien ra dung o tan so sigma.
%  Do la mot gioi han tren THAT cho viec tang tau, khong phai loi cai dat.

dmf_hat_p = zeros(3,1);

xi_hat = z + l_gain*[gamma; nu];        % pt. (11a), giong DO_Out

% *** LOCK DIMENSIONS, per-axis version. ***
% If n_state_axis(i) does not match z's real state count, this fails
% SILENTLY in exactly the way the original warning described: the block
% keeps running, still outputs three plausible-looking numbers, just
% picking up the wrong axis's states. The assert below is the only guard.
assert(numel(n_state_axis) == 3, ...
    'payload_predictor: n_state_axis must have 3 elements.');
assert(sum(n_state_axis) == numel(z), ...
    ['payload_predictor: n_state_axis sums to %d, which does not match ' ...
     'z''s state count (%d). The Constant block feeding n_state_axis or ' ...
     'do_w is pointing at the wrong variable - re-run build_payload_predictor.'], ...
    sum(n_state_axis), numel(z));

n_w = numel(do_w);
b  = 0;   % state pointer (into z / xi_hat)
kw = 0;   % frequency pointer (into do_w)
for i = 1:3
    acc = 0;
    consumed = 0;
    while consumed < n_state_axis(i)
        kw = kw + 1;
        assert(kw <= n_w, ...
            'payload_predictor: ran out of do_w before axis %d had enough states.', i);
        w = do_w(kw);
        if w == 0
            % e^{0*tau} = 1: a constant predicts itself. This is why this
            % mode can never "predict wrong" - it only needs to be ESTIMATED.
            acc = acc + xi_hat(b+1);
            b = b + 1;
            consumed = consumed + 1;
        else
            c = cos(w*tau_pred);
            s = sin(w*tau_pred);
            acc = acc + c*xi_hat(b+1) + s*xi_hat(b+2);
            b = b + 2;
            consumed = consumed + 2;
        end
    end
    dmf_hat_p(i) = acc;
end
end
