function d_mf = payload_pendulum_output(xp, a_uav, m_p, L, g, payload_z_on)
%#codegen
%PAYLOAD_PENDULUM_OUTPUT  Luc cap truyen len UAV = nhieu tai d_mf.
%
%  Paste noi dung file nay vao mot khoi MATLAB Function RIENG.
%  Tach roi khoi payload_pendulum_derivative theo dung kieu ma model dang
%  dung cho DO (do_derivative / do_output) va ESO.
%
%  Luc cang cap, moi truc:
%     T = m_p*( g*cos(th) + L*thdot^2 + a*sin(th) )
%  Phan luc ngang len UAV:
%     d = T*sin(th)
%
%  KHOP VOI BASELINE.  Trong translational_dynamics:
%     m*nu_dot = F - m*g*e3 + d_mf + d_lf
%  nen d_mf la LUC, don vi N, he QUAN TINH.  Dung het - khong chia khoi
%  luong, khong doi frame, khong doi dau.
%
%  ----------------------------------------------------------------------
%  THE VERTICAL COMPONENT (payload_z_on) - Part 3.5 (TEST_PLAN_PROMPT.md)
%  ----------------------------------------------------------------------
%  The tether pulls the UAV DOWN with force T*cos(th). At hover (th ~ 0),
%  T ~ m_p*g, so this pull is the payload's static weight - and it belongs
%  in the trim, not out of it: translational_dynamics.m's own equilibrium
%  (nu_dot = 0) gives F_act(3) = m*g - d_mf(3), so d_mf(3) = -T*cos(th)
%  makes the controller command F_act(3) = m*g + T ~ (m + m_p)*g at hover -
%  exactly the physical thrust margin table above, and exactly what
%  Checkpoint 3.5 measures.
%
%  An EARLIER version of this block computed d_z = m_p*g - T*cos(th_eff)
%  instead - subtracting the payload's own weight back out, so d_z ~ 0 at
%  hover and the trim point stayed IDENTICAL to m*g with no payload at all.
%  That was deliberate at the time (docs/devlog/AUDIT.md item 11 names it a
%  documented limitation, not an oversight): payload_z_on was reserved for a
%  future ablation and had never been turned on for any locked result, so
%  nothing published depended on its old behaviour. Checkpoint 3.5 is that
%  future ablation, and it explicitly requires the opposite: the payload's
%  weight DOES have to move the trim point, or "total thrust = (m + m_p)*g"
%  cannot be measured at all. Removing the +m_p*g cancellation term is the
%  whole fix.
%
%  payload_z_on = 0  (DEFAULT, unchanged - Stage 2.1's own bit-exact gate)
%     d_mf(3) = 0, identical to the original baseline (d_mf was horizontal
%     only). Only ONE thing differs between payload_model = 0 and 1: the
%     horizontal disturbance waveform. One experiment, one variable.
%  payload_z_on = 1
%     Adds the FULL vertical reaction, constant term included. Hover, no
%     wind: position stable, no saturation, total thrust = (m + m_p)*g
%     within 1% (Checkpoint 3.5) - not the near-zero-mean oscillation the
%     earlier version produced.

d_mf = zeros(3,1);

th_x = xp(1);  thd_x = xp(2);
th_y = xp(3);  thd_y = xp(4);

T_x = m_p*( g*cos(th_x) + L*thd_x^2 + a_uav(1)*sin(th_x) );
T_y = m_p*( g*cos(th_y) + L*thd_y^2 + a_uav(2)*sin(th_y) );

d_mf(1) = T_x*sin(th_x);
d_mf(2) = T_y*sin(th_y);

if payload_z_on > 0.5
    % Combined swing angle, used to project the tether tension onto z.
    th_eff  = sqrt(th_x^2 + th_y^2);
    T_eff   = m_p*( g*cos(th_eff) + L*(thd_x^2 + thd_y^2) );
    % Full reaction, including its constant (trim-shifting) part - see the
    % header. NOT m_p*g - T_eff*cos(th_eff): that cancelled the constant
    % term back out, which is exactly what Checkpoint 3.5 says must not
    % happen anymore.
    d_mf(3) = -T_eff*cos(th_eff);
end
end
