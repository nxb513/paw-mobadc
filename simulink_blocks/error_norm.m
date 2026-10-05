function err = error_norm(gamma, gamma_d)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
err = 0;
% Sai so vi tri tuc thoi ||gamma - gamma_d|| (dinh nghia Table 1 bai bao).
err = norm(gamma - gamma_d);
end
