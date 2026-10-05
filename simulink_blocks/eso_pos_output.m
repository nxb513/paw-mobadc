function dlf_hat = eso_pos_output(zp)
%#codegen
% --- Khai bao kich thuoc output (de Simulink suy dung kich thuoc tin hieu) ---
dlf_hat = zeros(3,1);
% Dau ra ESO vi tri, pt. (15): dlf_hat = zp3 (uoc luong nhieu gio).
% Tach rieng (chi phu thuoc trang thai zp) de pha algebraic loop.
dlf_hat = zp(7:9);
end
