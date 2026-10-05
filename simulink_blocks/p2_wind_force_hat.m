function dlf_hat = p2_wind_force_hat(w, nu_c, prm_w)
%#codegen
%P2_WIND_FORCE_HAT  MATLAB Function block P2/P2_Core/P2/P2_WindHat (GD2b, plant_model = 1).
%
%  The controller's wind-force model on P2 (REGISTER_P2 sec 0.3): quadratic, the same
%  form as the plant's body drag, NOMINAL parameters, relative velocity w - v_Q with
%  the controller's own MEASURED velocity nu_c:
%     dlf_hat = (K_w/U_ref) |w - nu_c| (w - nu_c)
%  w is the SELECTED wind (sensor / PI-MoE / oracle, as WSEL); vertical component dropped.
%  prm_w = [K_w; U_ref]. Replaces K_w*w (WM_Kw / WP_Kw / WO_Kw) only when plant_model = 1.

dlf_hat = zeros(3, 1);          % output size declared first, as every v1 block does
r = [w(1); w(2); 0] - nu_c;
dlf_hat = (prm_w(1) / prm_w(2)) * norm(r) * r;
end
