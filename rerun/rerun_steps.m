function T = rerun_steps()
%RERUN_STEPS  Every step of the final run (docs/REGISTER_FINAL.md), in waves along the reuse chain.
%
%  T(k) = struct: id, wave ('A'..'F'), shards (parallel parts, core/shard_files.m), call (@(sh) ..., sh = [k n]
%  or []). Horizons are read when the step runs from the sweeps of earlier waves (rerun/final_tau.m, rule fixed
%  in REGISTER_FINAL sec 3); segment sets are the registered ones (their SHA-256, checked by every runner, were
%  reproduced by the fresh export on 2026-10-05).
%    A  horizon sweeps on the fixed-5: N0P (7 conditions), N0V (3), N0H3
%    B  sweeps that need a payload tau (N0W, N0W-6, N0M square); D2; Guo; the T3b and circle-S40 tables
%    C  steps reusing D2 / reading tau_w, tau_6, tau_m; N6; the square table; the wind groups; E1, E2
%    D  steps reusing N6 / N4b-P2-base / static-circle
%    E  steps reusing H3-hover / F-hover
%    F  steps reusing iii-hover
CM   = 'a227e9d87a2ac436';  S40 = '1db1de02532a3896';  S40H = '53facf03712c81ee';
N6H  = '43226c02f081460607d5f98676c57cfa1207e98498ad2919c642af5d717144c7';
t = @final_tau;
tab = @(sh, varargin) run_p2_gd6('TAB', 'Only', {'circle'}, 'TauPrev', t('V:circle'), 'Sha', S40, 'Paw', true, ...
    'Shard', sh, varargin{:});
g7c = @(grp, sh, varargin) run_p2_gd7(grp, 'TauW', t('w6'), 'TauPred', t('circle'), 'Shard', sh, varargin{:});
g7h = @(grp, sh, varargin) run_p2_gd7(grp, 'TauW', t('w6'), 'TauPred', t('hover'), 'Shard', sh, varargin{:});
g7w = @(grp, sh, tp, sha) run_p2_gd7(grp, 'TauW', t('w'), 'TauPred', tp, 'Sha', sha, 'Shard', sh);
c = {
 % ---- A: horizons (REGISTER_P2 sec 7.1 procedure), one condition per job ----
 'N0P-circle',        'A', 1, @(sh) run_p2_gd6('N0P', 'Only', {'circle'},     'OutFile', 'n0p_p2__circle.mat')
 'N0P-hover',         'A', 1, @(sh) run_p2_gd6('N0P', 'Only', {'hover'},      'OutFile', 'n0p_p2__hover.mat')
 'N0P-T3b',           'A', 1, @(sh) run_p2_gd6('N0P', 'Only', {'T3b'},        'OutFile', 'n0p_p2__T3b.mat')
 'N0P-square',        'A', 1, @(sh) run_p2_gd6('N0P', 'Only', {'square'},     'OutFile', 'n0p_p2__square.mat')
 'N0P-T5',            'A', 1, @(sh) run_p2_gd6('N0P', 'Only', {'T5'},         'OutFile', 'n0p_p2__T5.mat')
 'N0P-circle_L15',    'A', 1, @(sh) run_p2_gd6('N0P', 'Only', {'circle_L15'}, 'OutFile', 'n0p_p2__circle_L15.mat')
 'N0P-circle_L05',    'A', 1, @(sh) run_p2_gd6('N0P', 'Only', {'circle_L05'}, 'OutFile', 'n0p_p2__circle_L05.mat')
 'N0V-circle',        'A', 1, @(sh) run_p2_gd6('N0V',                         'OutFile', 'n0p_p2__V_circle.mat')
 'N0V-T3b',           'A', 1, @(sh) run_p2_gd6('N0V', 'Only', {'T3b'},        'OutFile', 'n0p_p2__V_T3b.mat')
 'N0V-square',        'A', 1, @(sh) run_p2_gd6('N0V', 'Only', {'square'},     'OutFile', 'n0p_p2__V_square.mat')
 'N0H3',              'A', 1, @(sh) run_p2_gd6('N0H3', 'Only', {'circle'})
 % ---- B ----
 'N0W',               'B', 1, @(sh) run_p2_gd6('N0W', 'TauPred', t('circle'))
 'N0W6',              'B', 1, @(sh) run_p2_gd6('N0W6', 'TauPred', t('hover'))
 'N0M-square',        'B', 1, @(sh) run_p2_gd6('N0M', 'Only', {'square'}, 'TauPred', t('square'))
 'D2',                'B', 4, @(sh) run_p2_gd6('D2', 'TauPred', t('circle'), 'TauPrev', t('V:circle'), 'Sha', CM, 'Shard', sh)
 'GUO',               'B', 4, @(sh) run_p2_gd6('GUO', 'Sha', CM, 'Shard', sh)
 'TAB-T3b',           'B', 5, @(sh) run_p2_gd6('TAB', 'Only', {'T3b'}, 'TauPred', t('T3b'), 'TauPrev', t('V:T3b'), ...
                                    'Sha', '35bed7710bf224ee', 'Paw', true, 'Shard', sh)
 'TAB-circle',        'B', 2, @(sh) tab(sh, 'TauPred', t('circle'))
 'TAB-mp025',         'B', 2, @(sh) tab(sh, 'MP', 0.25, 'TauPred', t('circle'))
 'TAB-mp065',         'B', 2, @(sh) tab(sh, 'MP', 0.65, 'TauPred', t('circle'))
 'TAB-L150',          'B', 2, @(sh) tab(sh, 'L', 1.5, 'TauPred', t('circle_L15'))
 'TAB-L050',          'B', 2, @(sh) tab(sh, 'L', 0.5, 'TauPred', t('circle_L05'))
 'TAB-mp025-L050',    'B', 2, @(sh) tab(sh, 'MP', 0.25, 'L', 0.5, 'TauPred', t('circle_L05'))
 'TAB-mp025-L150',    'B', 2, @(sh) tab(sh, 'MP', 0.25, 'L', 1.5, 'TauPred', t('circle_L15'))
 'TAB-mp065-L050',    'B', 2, @(sh) tab(sh, 'MP', 0.65, 'L', 0.5, 'TauPred', t('circle_L05'))
 'TAB-mp065-L150',    'B', 2, @(sh) tab(sh, 'MP', 0.65, 'L', 1.5, 'TauPred', t('circle_L15'))
 % ---- C ----
 'six-circle-h3',     'C', 3, @(sh) g7c('six-circle-h3', sh, 'H3Hz', t('h3'), 'Sha', CM)
 'H3-circle',         'C', 3, @(sh) g7c('H3-circle', sh, 'H3Hz', t('h3'), 'Sha', CM)
 'static-circle',     'C', 1, @(sh) g7c('static-circle', sh, 'Sha', S40)
 'iii-circle',        'C', 1, @(sh) g7c('iii-circle', sh, 'TauM3', 0, 'Sha', S40)
 'static-circle-sn',  'C', 1, @(sh) g7c('static-circle-sn', sh, 'Sha', S40, 'DataDir', 'wind_sn010')
 'static-circle-spk', 'C', 3, @(sh) g7c('static-circle-spk', sh, 'Sha', CM, 'DataDir', 'wind_spk')
 'N6',                'C', 4, @(sh) g7h('N6', sh, 'Sha', N6H)
 'static-hover-sn',   'C', 1, @(sh) g7h('static-hover-sn', sh, 'Sha', S40H, 'DataDir', 'wind_sn010')
 'static-hover-spk',  'C', 3, @(sh) g7h('static-hover-spk', sh, 'Sha', N6H, 'DataDir', 'wind_spk')
 'TAB-square',        'C', 6, @(sh) run_p2_gd6('TAB', 'Only', {'square'}, 'TauPred', t('square'), 'TauPrev', t('V:square'), ...
                                    'TauN6', t('m:square'), 'Sha', CM, 'Paw', true, 'Shard', sh)
 'GUOTRIM',           'C', 2, @(sh) run_p2_gd6('GUOTRIM', 'Sha', CM, 'Shard', sh)
 'N4b-P2-base',       'C', 4, @(sh) g7w('N4b-P2-base', sh, t('circle'), CM)
 'N4b-P2-L15',        'C', 4, @(sh) g7w('N4b-P2-L15', sh, t('circle_L15'), CM)
 'N4b-P2-K10',        'C', 4, @(sh) g7w('N4b-P2-K10', sh, t('circle'), '03fae8f8a845cb5b')
 'N5-A-Weak',         'C', 3, @(sh) g7w('N5-A-Weak', sh, t('circle'), 'a051c6fdcf0a6be2')
 'N5-A-Medium',       'C', 2, @(sh) g7w('N5-A-Medium', sh, t('circle'), '309278f9eb484c58')
 'N5-A-StrongRel',    'C', 1, @(sh) g7w('N5-A-StrongRel', sh, t('circle'), 'f8479cc53cb0d8a0')
 'N5-H-StrongRel',    'C', 1, @(sh) g7w('N5-H-StrongRel', sh, t('hover'), '7b105836187d9f25')
 % ---- D ----
 'H3-hover',          'D', 2, @(sh) g7h('H3-hover', sh, 'H3Hz', t('h3'), 'Sha', N6H)
 'F-hover',           'D', 3, @(sh) g7h('F-hover', sh, 'Sha', S40H)
 'static-circle-k',   'D', 1, @(sh) g7c('static-circle-k', sh, 'Sha', S40)
 'N4b-P2-d200',       'D', 3, @(sh) g7w('N4b-P2-d200', sh, t('circle'), CM)
 'N5-B-Weak',         'D', 1, @(sh) g7w('N5-B-Weak', sh, t('circle'), 'a051c6fdcf0a6be2')
 'N5-B-Medium',       'D', 1, @(sh) g7w('N5-B-Medium', sh, t('circle'), 'dd710794f4786481')
 % ---- E ----
 'static-hover',      'E', 2, @(sh) g7h('static-hover', sh, 'H3Hz', t('h3'), 'Sha', N6H)
 'iii-hover',         'E', 3, @(sh) g7h('iii-hover', sh, 'TauM3', 0, 'Sha', S40H)
 % ---- F ----
 'static-hover-k',    'F', 2, @(sh) g7h('static-hover-k', sh, 'Sha', S40H)
 'static-indi-bias',  'F', 1, @(sh) g7h('static-indi-bias', sh, 'H3Hz', t('h3'), 'Sha', S40H)
 };
T = struct('id', c(:, 1), 'wave', c(:, 2), 'shards', c(:, 3), 'call', c(:, 4));
end
