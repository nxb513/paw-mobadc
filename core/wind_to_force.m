function [d_lf, K_w] = wind_to_force(w, wind_amp, V_ref)
%WIND_TO_FORCE  Wind velocity [m/s] -> wind force [N]. A LINEAR map.
%
%   d_lf = wind_to_force(w)                    % uses wind_amp=1.0, V_ref=5.0
%   d_lf = wind_to_force(w, wind_amp, V_ref)
%   [~, K_w] = wind_to_force([])               % the coefficient only
%
%   w : (3,1) or (n,3) wind velocity in the INERTIAL frame, m/s
%
%  ======================================================================
%  K_w IS NOT CHOSEN - IT IS DERIVED
%  ======================================================================
%  If this coefficient were picked freely, every control result downstream
%  could be read as "you only tuned the disturbance amplitude". So it is
%  anchored to TWO NUMBERS THAT ALREADY EXISTED, not to two new ones:
%
%     wind_amp = 1.0 N    the mean wind force of Guo et al., as set in
%                         core/init_MOBADC_params.m
%     V_ref    = 5.0 m/s  the reference wind speed of the wind dataset (W1)
%
%     K_w = wind_amp / V_ref = 0.2 N/(m/s)
%
%  What that means: when |w| = V_ref, |d_lf| = wind_amp EXACTLY. The baseline
%  (constant wind) is therefore reproduced exactly, and the fluctuating part is
%  a physically scaled perturbation about the published operating point.
%
%  Because it is derived, K_w is a LOCKED quantity: protocol_lock records it by
%  calling this function rather than by copying a number, precisely so that a
%  change to V_ref cannot move the theta_DC envelope and the §0.91 prediction
%  without anything reporting it.
%
%  PHYSICAL SANITY CHECK. If 1.0 N at 5 m/s were arbitrary the anchor would be
%  meaningless. Against drag:
%       F = 1/2 rho Cd A V^2   ->   Cd*A = 1.0 / (0.5*1.225*25) = 0.065 m^2
%  A 1.121 kg quadrotor has a frontal area of ~0.05-0.10 m^2 and Cd ~1.0-1.3,
%  so Cd*A lies in 0.05-0.13. The derived value is INSIDE that range. So
%  wind_amp = 1.0 N at V = 5 m/s is physically consistent and the anchor holds.
%
%  ======================================================================
%  WHY LINEAR NOW AND NONLINEAR LATER
%  ======================================================================
%  With a linear map the force error is the image of the velocity error:
%
%       d_lf - d_lf_hat = K_w * (w - w_hat)
%
%  so the SKILL measured in W5 (in m/s) carries DIRECTLY into the force domain.
%  That is what keeps the chain W5 -> W7 logically connected.
%
%  With full drag F = 1/2 rho Cd A ||v_rel|| v_rel, where v_rel = w - v_uav:
%
%    * the WIND is still EXOGENOUS - a quadrotor does not change the free
%      stream. This was overstated at first and has been corrected.
%    * but the FORCE becomes state-dependent: v_uav is decided by the
%      controller. So d_lf is no longer a function of the wind alone, and
%      "PI-MoE predicts w well" no longer translates into "predicts F well
%      with the same skill".
%
%  The architectural consequence, and it holds for BOTH maps:
%       Python exports w_hat(t+tau)      <- always valid; wind is exogenous
%       Simulink applies K_w (or drag)   <- uses v_uav AT THAT INSTANT
%  That is, the wind->force map must live INSIDE Simulink, not in Python.
%  Moving from linear to nonlinear later therefore changes nothing on the
%  Python side.
%
%  ======================================================================
%  ISOTROPY, AND THE VERTICAL COMPONENT
%  ======================================================================
%  K_w = K_w * eye(3): the drag is isotropic, so the z axis DOES take wind
%  force. That does not break the baseline: the dataset's reference wind lies
%  in the horizontal plane, so the z component is a zero-mean perturbation -
%  and the baseline (no perturbation) still gives d_lf(3) = 0, exactly as in
%  the reference work.

if nargin < 2 || isempty(wind_amp), wind_amp = 1.0; end   % N   [PAPER]
if nargin < 3 || isempty(V_ref),    V_ref    = 5.0; end   % m/s [W1 dataset]

assert(V_ref > 0, 'wind_to_force: V_ref must be positive.');
K_w = wind_amp / V_ref;

if isempty(w), d_lf = []; return; end

if isvector(w)
    w = w(:);
    assert(numel(w) == 3, 'wind_to_force: w must have 3 elements, or be (n,3).');
    d_lf = K_w * w;
else
    assert(size(w,2) == 3, 'wind_to_force: w must be (n,3).');
    d_lf = K_w * w;
end
end
