function [d_mf_sin, d_lf, d_ltau] = disturbance_generator(t, payload_amp, payload_sigma, wind_amp)
%#codegen
%DISTURBANCE_GENERATOR  Nguon nhieu ngoai cua Test 4.
%
%  d_mf_sin : nhieu tai, luc, he quan tinh          [N]     pt. (6)
%  d_lf     : luc gio, hang so trong he the gioi    [N]
%  d_ltau   : nhieu moment ngoai                    [N.m]   -- KHONG MO HINH HOA
%
%  ----------------------------------------------------------------------
%  VE d_ltau
%  ----------------------------------------------------------------------
%  Guo et al. 2020 co Assumption 3 cho nhieu moment, nhung KHONG cong bo dang
%  song, bien do, hay huong cua no. Bom vao mot dang song tu nghi ra la them
%  mot bac tu do khong ai kiem chung duoc, va no se di thang vao bang ket qua
%  duoi danh nghia "tai lap".
%
%  Nen d_ltau = 0, va do la mot LUA CHON CO CHU DICH phai khai bao trong paper:
%  pham vi cua ban la nhieu LUC (tai + gio), khong phai nhieu MOMENT.
%
%  He qua phai noi ro: ESO tu the trong cau hinh ESO/MOBADC khong co nhieu
%  ngoai nao de khu. No van lam viec (khu sai lech mo hinh va ghep truc), nhung
%  bat ky phat bieu nao ve kha nang khang nhieu MOMENT deu khong duoc thi
%  nghiem nay chong do.
%
%  Ban truoc co mot doi so amp_tau o day ma than ham khong dung den, trong khi
%  init khai bao 0.05 N.m va ca hai run script in no ra tieu de bang. Bang khi
%  do dang bao cao mot dieu kien thi nghiem khong ton tai.
%  Xem docs/AUDIT.md muc A1.

d_mf_sin = zeros(3,1); d_lf = zeros(3,1); d_ltau = zeros(3,1);

d_mf_sin = [0; payload_amp*sin(payload_sigma*t); 0];

psi_w = 40*pi/180;                       % [PAPER Fig. 8b] huong gio NE 40 deg
d_lf  = wind_amp*[cos(psi_w); sin(psi_w); 0];

d_ltau = zeros(3,1);                     % khong mo hinh hoa - xem chu thich
end
