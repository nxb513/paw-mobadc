function xp_dot = payload_pendulum_derivative(xp, a_uav, F_wp, m_p, L, zeta_p, g)
%#codegen
%PAYLOAD_PENDULUM_DERIVATIVE  Dong luc hoc con lac treo duoi UAV.
%
%  Paste noi dung file nay vao mot khoi MATLAB Function trong Simulink.
%
%  Trang thai  xp = [th_x; thd_x; th_y; thd_y]     (rad, rad/s)
%  Vao
%     a_uav : 2x1  gia toc NGANG cua UAV, he QUAN TINH        [m/s^2]
%             -> lay tu nu_dot(1:2), QUA MOT KHOI MEMORY (xem WIRING.md)
%     F_wp  : 2x1  luc gio tac dung TRUC TIEP len tai          [N]
%             -> Giai doan 2.1 noi Constant [0;0] vao day.
%                Cong da co san de Giai doan 2.2 cam vao khong phai sua khoi.
%     m_p, L, zeta_p, g : tham so (tu init_MOBADC_params)
%
%  Phuong trinh, moi truc (con lac phang, day cung, khoi luong tap trung):
%
%     thddot = -(g/L) sin(th) - (a/L) cos(th)
%              - 2 zeta wn thdot + F_w/(m_p L),      wn = sqrt(g/L)
%
%  Hai truc coi nhu doc lap.  Con lac cau that co so hang ghep bac
%  th^2*thdot, rat nho o bien do lac o day nhung KHAC KHONG - do la mot
%  thanh phan cua residual, phai ghi vao bai chu khong phai bo qua im lang.
%
%  KHONG dung khoi nay de dat dieu kien dau: Integrator ngoai giu state,
%  IC = [0;0;0;0].

xp_dot = zeros(4,1);

wn = sqrt(g/L);
for k = 0:1
    th  = xp(2*k + 1);
    thd = xp(2*k + 2);

    xp_dot(2*k + 1) = thd;
    xp_dot(2*k + 2) = -(g/L)*sin(th) - (a_uav(k+1)/L)*cos(th) ...
                      - 2*zeta_p*wn*thd + F_wp(k+1)/(m_p*L);
end
end
