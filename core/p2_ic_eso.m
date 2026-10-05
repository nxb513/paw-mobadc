function zp0 = p2_ic_eso(R_traj, z0_hover, w_traj, plant_model, p2_trim_eso, p2_ic_pos, p2_ic_vel)
%P2_IC_ESO  Initial condition of Position_Observers/Int_zp (the position ESO), GD2b.
%
%  v1: exactly the expression the block held before GD2b,
%      [R_traj;0;z0_hover; 0;R_traj*w_traj;0; 0;0;0]
%  P2 with an ESO trim (columns whose DO has no DC mode on z, e.g. L0 = Guo harm1):
%  z_p3(3) = p2_trim_eso = -m_L g (docs/devlog/GD2B_DESIGN.md sec 3).

if plant_model == 1 && nargin >= 7
    % REGISTER_P2 sec 8: the standard initial state of the condition's own trajectory
    zp0 = [p2_ic_pos(:); p2_ic_vel(:); 0;0;0];
else
    zp0 = [R_traj;0;z0_hover; 0;R_traj*w_traj;0; 0;0;0];
end
if plant_model == 1 && p2_trim_eso ~= 0
    zp0(9) = zp0(9) + p2_trim_eso;
end
end
