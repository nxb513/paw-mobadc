function tau_cmd = attitude_controller(eta_d, eta, omega, dltau_hat, K_eta, K_omega)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
tau_cmd = zeros(3,1);
% Luat dieu khien vong tu the, pt. (17)-(18) Guo 2020:
%   e_eta = eta_d - eta                                               (17)
%   tau_d = K_eta*e_eta - K_omega*omega - dltau_hat                   (18)
% omega la BODY rates (Remark 3: omega_d = 0). PID mode: dltau_hat = 0.
e_eta   = eta_d - eta;
tau_cmd = K_eta*e_eta - K_omega*omega - dltau_hat;
end
