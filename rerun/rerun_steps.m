function T = rerun_steps()
%RERUN_STEPS  Every runner call of the paper's 39 result files (data/SHA256SUMS.txt), with the
%  registered tau / SHA values of the nights that produced them (experiments/gd*.m, REGISTER_P2).
%  Re-run on another machine / MATLAB release: the numbers are expected to agree closely, not bit for bit.
%
%  T(k) = struct: id, call (function handle), needs (ids whose result files the call reuses).
CM   = 'a227e9d87a2ac436';                                         % circle_main, cap 4
S40  = '1db1de02532a3896';
N6H  = '43226c02f081460607d5f98676c57cfa1207e98498ad2919c642af5d717144c7';
S40H = '53facf03712c81ee';
tab  = @(varargin) run_p2_gd6('TAB', 'Only', {'circle'}, 'TauPrev', 0.180, 'Sha', S40, varargin{:});
c = {
 % ---- circle chain (D2 first: its L3 column is reused) ----
 'D2',               @() run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'Sha', CM),                         {}
 'six-circle-h3',    @() run_p2_gd7('six-circle-h3', 'TauW', 0.280, 'TauPred', 0.290, 'H3Hz', 32, 'Sha', CM),     {'D2'}
 'H3-circle',        @() run_p2_gd7('H3-circle', 'TauW', 0.280, 'TauPred', 0.290, 'H3Hz', 32, 'Sha', CM),         {'D2'}
 'static-circle',    @() run_p2_gd7('static-circle', 'TauW', 0.280, 'TauPred', 0.290, 'Sha', S40),                {'D2'}
 'iii-circle',       @() run_p2_gd7('iii-circle', 'TauW', 0.280, 'TauPred', 0.290, 'TauM3', 0, 'Sha', S40),       {'D2'}
 'N4b-P2-base',      @() run_p2_gd7('N4b-P2-base', 'TauW', 0.020, 'TauPred', 0.290, 'Sha', CM),                   {'D2'}
 'N4b-P2-d200',      @() run_p2_gd7('N4b-P2-d200', 'TauW', 0.020, 'TauPred', 0.290, 'Sha', CM),                   {'N4b-P2-base'}
 'N5-B-Weak',        @() run_p2_gd7('N5-B-Weak', 'TauW', 0.020, 'TauPred', 0.290, 'Sha', 'a051c6fdcf0a6be2'),     {'N4b-P2-base'}
 'N5-B-Medium',      @() run_p2_gd7('N5-B-Medium', 'TauW', 0.020, 'TauPred', 0.290, 'Sha', 'dd710794f4786481'),   {'N4b-P2-base'}
 % ---- hover chain (N6 first) ----
 'N6',               @() run_p2_gd7('N6', 'TauW', 0.280, 'TauPred', 0, 'Sha', N6H),                               {}
 'H3-hover',         @() run_p2_gd7('H3-hover', 'TauW', 0.280, 'TauPred', 0, 'H3Hz', 32, 'Sha', N6H),             {'N6'}
 'static-hover',     @() run_p2_gd7('static-hover', 'TauW', 0.280, 'TauPred', 0, 'H3Hz', 32, 'Sha', N6H),         {'N6', 'H3-hover'}
 'F-hover',          @() run_p2_gd7('F-hover', 'TauW', 0.280, 'TauPred', 0, 'Sha', S40H),                         {'N6'}
 'iii-hover',        @() run_p2_gd7('iii-hover', 'TauW', 0.280, 'TauPred', 0, 'TauM3', 0, 'Sha', S40H),           {'F-hover'}
 'static-hover-k',   @() run_p2_gd7('static-hover-k', 'TauW', 0.280, 'TauPred', 0, 'Sha', S40H),                  {'F-hover', 'iii-hover'}
 'static-indi-bias', @() run_p2_gd7('static-indi-bias', 'TauW', 0.280, 'TauPred', 0, 'H3Hz', 32, 'Sha', S40H),    {'F-hover', 'iii-hover', 'H3-hover'}
 'N5-H-StrongRel',   @() run_p2_gd7('N5-H-StrongRel', 'TauW', 0.020, 'TauPred', 0, 'Sha', '7b105836187d9f25'),    {}
 % ---- no reuse source ----
 'GUO',              @() run_p2_gd6('GUO', 'Sha', CM),                                                            {}
 'GUOTRIM',          @() run_p2_gd6('GUOTRIM', 'Sha', CM),                                                        {'GUO'}
 'TAB-T3b',          @() run_p2_gd6('TAB', 'Only', {'T3b'}, 'TauPred', 0.340, 'TauPrev', 0.210, 'Sha', '35bed7710bf224ee'), {}
 'TAB-square',       @() run_p2_gd6('TAB', 'Only', {'square'}, 'TauPred', 0.120, 'TauPrev', 0.120, 'TauN6', 0.060, 'Sha', CM), {}
 'TAB-mp025',        @() tab('MP', 0.25, 'TauPred', 0.290),                                                       {}
 'TAB-mp065',        @() tab('MP', 0.65, 'TauPred', 0.290),                                                       {}
 'TAB-L150',         @() tab('L', 1.5, 'TauPred', 0.260),                                                         {}
 'TAB-L050',         @() tab('L', 0.5, 'TauPred', 0.330),                                                         {}
 'TAB-mp025-L050',   @() tab('MP', 0.25, 'L', 0.5, 'TauPred', 0.330),                                             {}
 'TAB-mp025-L150',   @() tab('MP', 0.25, 'L', 1.5, 'TauPred', 0.260),                                             {}
 'TAB-mp065-L050',   @() tab('MP', 0.65, 'L', 0.5, 'TauPred', 0.330),                                             {}
 'TAB-mp065-L150',   @() tab('MP', 0.65, 'L', 1.5, 'TauPred', 0.260),                                             {}
 'N4b-P2-L15',       @() run_p2_gd7('N4b-P2-L15', 'TauW', 0.020, 'TauPred', 0.260, 'Sha', CM),                    {}
 'N4b-P2-K10',       @() run_p2_gd7('N4b-P2-K10', 'TauW', 0.020, 'TauPred', 0.290, 'Sha', '03fae8f8a845cb5b'),    {}
 'N5-A-Weak',        @() run_p2_gd7('N5-A-Weak', 'TauW', 0.020, 'TauPred', 0.290, 'Sha', 'a051c6fdcf0a6be2'),     {}
 'N5-A-Medium',      @() run_p2_gd7('N5-A-Medium', 'TauW', 0.020, 'TauPred', 0.290, 'Sha', '309278f9eb484c58'),   {}
 'N5-A-StrongRel',   @() run_p2_gd7('N5-A-StrongRel', 'TauW', 0.020, 'TauPred', 0.290, 'Sha', 'f8479cc53cb0d8a0'), {}
 'N0P',              @() run_p2_gd6('N0P'),                                                                       {}
 'N0V',              @() run_n0v_all(),                                                                           {}
 % ---- CONFIRM2 (14 days, wind_conf2/), set SHA from REGISTER_P2 sec 61.1 ----
 'C2-D2',            @() run_p2_gd6('D2', 'TauPred', 0.290, 'TauPrev', 0.180, 'Conf2', 'wind_conf2', ...
                         'Sha', '2f442433f5f86be38450e3934cc22296e2eedf004e79d96573dcd8acfd3df91c'),            {}
 'C2-circle',        @() run_p2_gd7('C2-circle', 'TauW', 0.280, 'TauPred', 0.290, 'H3Hz', 32, 'Conf2', 'wind_conf2', ...
                         'Sha', '2f442433f5f86be38450e3934cc22296e2eedf004e79d96573dcd8acfd3df91c'),            {'C2-D2'}
 'C2-hover',         @() run_p2_gd7('C2-hover', 'TauW', 0.280, 'TauPred', 0, 'H3Hz', 32, 'Conf2', 'wind_conf2', ...
                         'Sha', '5b69e3ad8af37528df0e174c423872777cc5dfa7246196e5d86088d7bb25af5a'),            {}
 'C2-hhover',        @() run_p2_gd7('C2-hhover', 'TauW', 0.020, 'TauPred', 0, 'Conf2', 'wind_conf2', ...
                         'Sha', '19530f2821fe9ef482ebad0925fee7b7e930c8e9d5a83ba0e8d07e184b5d3854'),            {}
 };
T = struct('id', c(:, 1), 'call', c(:, 2), 'needs', c(:, 3));
end

function run_n0v_all()
run_p2_gd6('N0V');
run_p2_gd6('N0V', 'Only', {'T3b'});
run_p2_gd6('N0V', 'Only', {'square'});
end
