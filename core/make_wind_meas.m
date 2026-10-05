function info = make_wind_meas(sigma, bias, seed)
%MAKE_WIND_MEAS  Build wind_meas_ts = the TRUE wind + sensor noise, from
%                wind_ts.
%
%   make_wind_meas            % sigma = 0, bias = 0 -> an EXACT COPY
%   make_wind_meas(0.3)       % white noise, 0.3 m/s RMS per axis
%   make_wind_meas(0.3, 0.2, 11)
%
%  ======================================================================
%  WHY THIS FUNCTION EXISTS
%  ======================================================================
%  Every number in §0.33-0.34's two 'sensor' rows assumes a PERFECT wind
%  measurement: 20 Hz, no noise, no bias, undisturbed by the rotor wash. No
%  anemometer is like that.
%
%  And the row currently winning (g_psens = 0.0031) is one of those two. So
%  this squeezes the WINNER, it does not rescue the loser.
%
%  ======================================================================
%  WHERE THE NOISE IS ADDED - AND WHY IT MUST BE AT 20 Hz
%  ======================================================================
%  The noise is added to EACH 20 Hz SAMPLE of the wind series, and WM_From then
%  holds it as a staircase ('Interpolate','off'). Adding white noise at 1 kHz
%  instead would show the controller a signal with high-frequency energy that a
%  20 Hz anemometer CANNOT produce, and the resulting number would describe a
%  sensor that does not exist.
%
%  ======================================================================
%  TWO PARAMETERS, TWO DIFFERENT PHYSICS
%  ======================================================================
%    sigma  white noise [m/s RMS per axis] - resolution / sensor noise
%    bias   a CONSTANT offset [m/s per axis] - miscalibration, or rotor wash
%
%  bias is dangerous in a completely different way from sigma: a constant
%  offset produces a CONSTANT FORCE, and the closed loop gives a steady-state
%  position error of d/(m*Ky) - so a bias goes STRAIGHT into the tracking error
%  at 0.0743 m per N. White noise is mostly filtered out by |H(jw)|.
%
%  ======================================================================
%  SEEDING AND REPRODUCIBILITY
%  ======================================================================
%  A private RandStream is used rather than the global rng(): this function is
%  called from inside a sweep, and disturbing the global generator state would
%  make everything else in that sweep irreproducible.

if nargin < 1 || isempty(sigma), sigma = 0; end
if nargin < 2 || isempty(bias),  bias  = 0; end
if nargin < 3 || isempty(seed),  seed  = 20240601; end

assert(evalin('base','exist(''wind_ts'',''var'')'), ...
    'make_wind_meas: wind_ts does not exist. Run wind_sim_load first.');
w = evalin('base','wind_ts');
v = w.signals.values;
n = size(v,1);

if sigma == 0 && bias == 0
    % An EXACT copy: every existing result must be unchanged to the bit.
    wm = w;
    info = struct('sigma',0, 'bias',0, 'seed',seed, 'n',n, ...
                  'rms_added',0, 'rms_wind',rms3(v));
else
    st = RandStream('mt19937ar', 'Seed', seed);
    e  = sigma * randn(st, size(v)) + bias;
    wm = w;  wm.signals.values = v + e;
    info = struct('sigma',sigma, 'bias',bias, 'seed',seed, 'n',n, ...
                  'rms_added',rms3(e - mean(e,1)), 'rms_wind',rms3(v));
end
assignin('base', 'wind_meas_ts', wm);
end

function r = rms3(v)
r = sqrt(mean(sum(v.^2, 2)/3));    % per-axis RMS
end
