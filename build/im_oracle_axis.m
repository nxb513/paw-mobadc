function do_w_axis = im_oracle_axis(traj_type, traj_par, w_traj, L)
%IM_ORACLE_AXIS  The `IM-oracle` per-axis frequency set (TEST_PLAN_PROMPT.md
%                 Part 3.3's table), for one trajectory/tether-length pair.
%
%   do_w_axis = im_oracle_axis(traj_type, traj_par, w_traj, L)
%
%   traj_type  0 hover | 1 circle | 2 figure-8 | 3 square | 4 multi-sine
%              (simulink_blocks/trajectory_ref.m's own numbering)
%   traj_par   the trajectory's own 4x1 parameter vector (same meaning as
%              trajectory_ref.m: traj_par(1) = A for figure-8, [D;T;T_h;0]
%              for square, amplitude scale for multi-sine)
%   w_traj     the trajectory's own frequency, where it has one (circle's
%              sigma, figure-8's omega) - ignored for hover/square/multi-sine
%   L          tether length [m], for wn_p = sqrt(g/L)
%
%  Returns do_w_axis, the 1x3 cell build_do_matrices.m's new form takes
%  directly: {wx, wy, wz}. The table (TEST_PLAN_PROMPT.md Part 3.3, SQUARE
%  ROW CORRECTED - docs/REGISTER_ROBUST.md sec 14, docs/REGISTER_C.md sec 2):
%
%      trajectory   x axis                    y axis
%      hover        {0, wn_p}                 {0, wn_p}
%      circle       {0, w}                    {0, w}
%      figure-8     {0, w}                    {0, 2w}          (confirmed, sec 14)
%      square       {0, w0,3w0,5w0,7w0, wn_p} {0, w0,3w0,5w0,7w0, wn_p}
%      multi-sine   {0, w1..w4, wn_p}         {0, w1..w4, wn_p}
%
%  SQUARE, CORRECTED: the plan's original {0, wn_p} row assumed the ONLY
%  relevant frequency was the pendulum's own free-oscillation rate and
%  dropped the FORCING entirely - w_traj is not even the right forcing
%  frequency either (op_set.m's own comment already flagged this; square's
%  true excitation is broadband, not w_traj at all). Measured directly
%  (docs/REGISTER_ROBUST.md sec 14: full nonlinear payload_pendulum_
%  derivative.m/_output.m, RK4, zero wind, exact harmonic projection over
%  40 periods of the pendulum's own d_mf response) - only ODD harmonics of
%  the corner-repeat fundamental w0 = 2*pi/(4*(T+T_h)) carry energy, and the
%  FIFTH (not the first) dominates. Independently corroborated by
%  docs/REGISTER_C.md sec 2's own earlier, separately-run FFT of acc_d
%  itself (traj_check.m's own square_spectrum_report): same dominant line,
%  2.6715 rad/s, to the digit.
%
%  ======================================================================
%  Z-AXIS: NOT IN THE PLAN'S TABLE, DELIBERATELY LEFT AT THE OLD DEFAULT
%  ======================================================================
%  Part 3.3's table only gives x/y - this whole robustness campaign inherits
%  the project's established scope, "horizontal component only, trim point
%  unchanged" (payload_z_on = 0, core/init_MOBADC_params.m's own header) and
%  "MOMENT: out of scope" (init's own startup banner). do_w_axis{3} is
%  therefore set to the SAME {0, sigma} the z-axis has always used (the
%  locked do_harm = [0 1] default, at whatever sigma is passed in as
%  w_traj) - not redesigned, because nothing in Part 3.3 asks it to be.
%
%  ======================================================================
%  MULTI-SINE'S wn_p TERM: KEPT EVEN THOUGH THE FORCING NEVER PUTS ENERGY
%  THERE
%  ======================================================================
%  multi-sine's own four forcing frequencies (0.50, 1.10, 1.90, 2.70 rad/s,
%  simulink_blocks/trajectory_ref.m) are fixed by the trajectory itself, not
%  by L - so wn_p is ADDED to whatever those four already are, exactly as
%  the plan's table specifies, not substituted for one of them. If wn_p
%  happens to coincide with one of the four (or with 2x one of them, the
%  pendulum's own quadratic nonlinearity - docs/REGISTER_C.md Section 1's
%  finding for the square), im_oracle_axis does not deduplicate - a repeated
%  frequency is exactly what build_do_matrices.m's own "repeated frequency"
%  assertion is for, and the caller sees that assertion fire rather than a
%  silently dropped state.

g = 9.81;
wn_p = sqrt(g/L);
MS_W = [0.50, 1.10, 1.90, 2.70];   % simulink_blocks/trajectory_ref.m's own fixed set

z_axis = [0, w_traj];   % unchanged from the locked default - see header

switch traj_type
    case 0   % hover
        do_w_axis = {[0, wn_p], [0, wn_p], z_axis};
    case 1   % circle
        do_w_axis = {[0, w_traj], [0, w_traj], z_axis};
    case 2   % figure-8 (Gerono): y-axis at exactly 2x the x-axis frequency -
             % CONFIRMED, not just assumed, by the same measurement that
             % fixed square below (docs/REGISTER_ROBUST.md sec 14): both
             % T3a and T3b's own d_mf response is a pure single line per
             % axis, at exactly w (x) and 2w (y), energy outside those two
             % lines ~0% - no change from the plan's own original table.
        do_w_axis = {[0, w_traj], [0, 2*w_traj], z_axis};
    case 3   % square - see the header for why this changed from {0, wn_p}.
             % traj_par(2)/(3) = T, T_h (simulink_blocks/trajectory_ref.m's
             % own square_minjerk convention) - callers that only need
             % hover/multi-sine (traj_par unused there) may still pass [],
             % but a caller reaching this case MUST pass the real traj_par.
        assert(numel(traj_par) >= 3, ['im_oracle_axis: traj_type=3 (square) needs ' ...
            'traj_par = [D;T;T_h;0] (op_condition''s own C.traj_par) to derive the ' ...
            'corner-repeat fundamental - got %d element(s).'], numel(traj_par));
        w0_sq = 2*pi / (4*(traj_par(2) + traj_par(3)));
        SQ_W  = w0_sq * [1 3 5 7];
        do_w_axis = {[0, SQ_W, wn_p], [0, SQ_W, wn_p], z_axis};
    case 4   % multi-sine
        do_w_axis = {[0, MS_W, wn_p], [0, MS_W, wn_p], z_axis};
    otherwise
        error('im_oracle_axis:type', 'im_oracle_axis: unknown traj_type %g.', traj_type);
end
end
