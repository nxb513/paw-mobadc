function z0 = p2_ic_do(l_gain, R_traj, z0_hover, w_traj, plant_model, p2_trim_do, p2_ic_pos, p2_ic_vel)
%P2_IC_DO  Initial condition of Position_Observers/Int_z (the DO state), GD2b.
%
%  The v1 value is computed by EXACTLY the expression the block held before GD2b,
%      -l_gain*[R_traj;0;z0_hover;0;R_traj*w_traj;0]
%  (same MATLAB evaluation -> bit-exact). Only when plant_model = 1 AND a DO trim is
%  requested (p2_trim_do = [index, value], index > 0) is the hover trim added to that
%  one state: the z-axis DC mode of the DO, so that dmf_hat(0) = -m_L g e3
%  (docs/devlog/GD2B_DESIGN.md sec 3; set by core/p2_setup.m).
%
%  REGISTER_P2 sec 8 (implementation-error fix): with plant_model = 1 and the standard
%  initial state given (p2_ic_pos, p2_ic_vel = gamma_d(0), nu_d(0) of the condition's own
%  trajectory, core/p2_setup.m), the DO starts from THAT state; for the circle it is the
%  same vector as before. plant_model = 0 never reads the two extra inputs.

if plant_model == 1 && nargin >= 8
    z0 = -l_gain*[p2_ic_pos(:); p2_ic_vel(:)];
else
    z0 = -l_gain*[R_traj;0;z0_hover;0;R_traj*w_traj;0];
end
if plant_model == 1 && p2_trim_do(1) > 0
    k = p2_trim_do(1);
    z0(k) = z0(k) + p2_trim_do(2);
end
end
