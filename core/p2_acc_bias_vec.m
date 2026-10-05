function b = p2_acc_bias_vec(bn, axes, seg)
%P2_ACC_BIAS_VEC  REGISTER_P2 sec 45.6 (1): the accelerometer-bias vector of one segment.
%
%   b = p2_acc_bias_vec(bn, axes, seg)    % bn = norm [m/s^2], axes 'xy' | 'xyz', seg = segment index
%
%  'xy'  (levels 0.086, 0.17): b = bn [cos phi; sin phi; 0], phi uniform on [0, 2 pi)
%  'xyz' (level 0.39):         b = bn u, u uniform on the unit sphere (z uniform on [-1, 1], phi uniform)
%  Direction random per segment, seeded by the segment: MT19937 seed 7000000 + 100 seg + 31 (the sensor
%  seeds of p2_setup use + 1 ... + 23 of the same base). The global generator is restored afterwards, so
%  nothing else sees the draw. The same segment gets the same draw at every level (u(1) sets phi for
%  'xy'; u(1), u(2) set z, phi for 'xyz'). bn = 0 gives the zero vector (the nominal, bit-exact).
assert(isscalar(bn) && isfinite(bn) && bn >= 0, 'p2_acc_bias_vec: the bias norm must be a scalar >= 0.');
b = zeros(3, 1);
if bn == 0, return; end
assert(any(strcmp(axes, {'xy', 'xyz'})), 'p2_acc_bias_vec: axes must be ''xy'' or ''xyz'' (sec 45.6).');
sv = rng;
rng(7000000 + 100 * seg + 31, 'twister');
u = rand(1, 2);
rng(sv);
if strcmp(axes, 'xy')
    phi = 2 * pi * u(1);
    b = bn * [cos(phi); sin(phi); 0];
else
    z = 2 * u(1) - 1;  phi = 2 * pi * u(2);  r = sqrt(1 - z^2);
    b = bn * [r * cos(phi); r * sin(phi); z];
end
end
