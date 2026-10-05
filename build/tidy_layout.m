function tidy_layout(varargin)
%TIDY_LAYOUT  Readable layout of the diagrams the build scripts create or extend:
%   Position_Observers, Position_Observers/IM_Est_Online, P2, P2/P2_Core, P2/P2_Core/P2.
%
%   tidy_layout                  % in memory (baseline1 loaded), NOT saved
%   tidy_layout('Save', true)    % + save baseline1.slx
%   tidy_layout('Only', {'P2'})  % one or more of the systems above (relative paths)
%
%  LAYOUT ONLY - value-neutral by construction:
%   * blocks are moved/resized (Position), never renamed, added or removed - with ONE
%     exception: the four diagnostic outputs of IM_Est_Online/IM_Estimator (w_all_x,
%     mag_all_x, w_all_y, mag_all_y: every candidate frequency and its magnitude) were left
%     unconnected; they now end in labelled Terminators (IM_T_*). Nothing in the loop reads
%     them (analysis/verify_imest_estimator_isolated.m logs them in its own test model).
%   * every line is deleted and re-added between the SAME ports (autorouting 'smart'); the
%     port-to-port connectivity is recorded before and compared after - any difference is
%     an error (nothing is saved).
%   * text/area annotations tagged 'tidy_layout' are removed and re-drawn.
%  Signal flow left -> right; one row per signal chain; ports aligned so that lines are
%  straight where the chain allows; functional groups framed by area annotations.
%  After it: B1 (verify_repro, check_results_numbers, extract_eml --check), the P2
%  fingerprint (block paths/types - unchanged), SNAPSHOT.md MD5.
opt = struct('Save', false, 'Only', {{}}, 'Quiet', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
mdl = 'baseline1';
here = repo_root();
cd(here); setup_path();
if ~bdIsLoaded(mdl), load_system(mdl); end
jobs = {'Position_Observers/IM_Est_Online', @lay_imest; ...
        'Position_Observers',               @lay_po; ...
        'P2/P2_Core/P2',                    @lay_p2_choice; ...
        'P2/P2_Core',                       @lay_p2_core; ...
        'P2',                               @lay_p2_root};
for j = 1:size(jobs, 1)
    rel = jobs{j, 1};
    if ~isempty(opt.Only) && ~any(strcmp(opt.Only, rel)), continue; end
    sys = [mdl '/' rel];
    if getSimulinkBlockHandle(sys) <= 0
        fprintf('  tidy_layout: %s not in the model - skipped\n', rel);
        continue
    end
    before = connectivity(sys);
    clear_notes(sys);
    b0 = kids(sys);  p0 = get_param(b0, 'Position');  if ~iscell(p0), p0 = {p0}; end
    extra = jobs{j, 2}(sys);                     % positions (+ new connections, if any)
    p1 = get_param(b0, 'Position');  if ~iscell(p1), p1 = {p1}; end
    same = cellfun(@isequal, p0, p1);
    if any(same)
        fprintf('  tidy_layout: %s - left where it was (not in the layout): %s\n', rel, ...
            strjoin(cellfun(@(s) s(numel(sys) + 2:end), b0(same), 'UniformOutput', false).', ', '));
    end
    if is_variant_container(sys)
        % a Variant Subsystem holds no lines (its choices connect implicitly) - positions only
        fprintf('  tidy_layout: %-34s %3d blocks, variant container - positions only\n', rel, numel(kids(sys)));
        continue
    end
    reroute(sys, [before; extra]);
    after = connectivity(sys);
    want = sort([before; extra]);
    if ~isequal(sort(after), want)
        d1 = setdiff(want, after);  d2 = setdiff(after, want);
        error('tidy_layout:conn', 'Connectivity of %s changed - NOT saved.\n  missing: %s\n  new: %s', ...
            rel, strjoin(d1, ', '), strjoin(d2, ', '));
    end
    fprintf('  tidy_layout: %-34s %3d blocks, %3d connections re-drawn (%d added), connectivity OK\n', ...
        rel, numel(kids(sys)), numel(after), numel(extra));
end
if opt.Save
    save_system(mdl);
    fprintf('  saved %s - next: B1, fingerprint, SNAPSHOT.md MD5\n', mdl);
end
end

%% =====================================================================
%  generic helpers
%% =====================================================================
function k = kids(sys)
try
    k = find_system(sys, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'MatchFilter', @Simulink.match.allVariants);
catch
    k = find_system(sys, 'SearchDepth', 1, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'Variants', 'AllVariants');
end
k = k(~strcmp(k, sys));
end

function v = is_variant_container(sys)
v = false;
try, v = strcmp(get_param(sys, 'Variant'), 'on'); catch, end
end

function c = connectivity(sys)
%CONNECTIVITY  'src/port>dst/port' for every connected input port of every block in sys.
c = {};
b = kids(sys);
for i = 1:numel(b)
    pc = get_param(b{i}, 'PortConnectivity');
    dn = get_param(b{i}, 'Name');
    for p = 1:numel(pc)
        if isempty(pc(p).SrcBlock) || pc(p).SrcBlock < 0, continue; end
        sn = get_param(pc(p).SrcBlock, 'Name');
        c{end + 1, 1} = sprintf('%s/%d>%s/%s', sn, pc(p).SrcPort + 1, dn, pc(p).Type); %#ok<AGROW>
    end
end
end

function reroute(sys, conns)
ln = find_system(sys, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
if ~isempty(ln), delete_line(ln); end
for i = 1:numel(conns)
    t = regexp(conns{i}, '^(.*)/(\d+)>(.*)/([^/]+)$', 'tokens', 'once');
    try
        add_line(sys, [t{1} '/' t{2}], [t{3} '/' t{4}], 'autorouting', 'smart');
    catch
        add_line(sys, [t{1} '/' t{2}], [t{3} '/' t{4}], 'autorouting', 'on');
    end
end
end

function P = setp(sys, name, pos)
blk = [sys '/' name];
assert(getSimulinkBlockHandle(blk) > 0, 'tidy_layout: %s not found.', blk);
set_param(blk, 'Position', round(pos));
P = pos;
end

function pin(sys, name, x, w, h, port, y, side)
%PIN  Place a block of size w x h at left x so that its input (side 'in') or output
%  (side 'out') port number `port` sits at height y (Simulink spaces ports evenly).
blk = [sys '/' name];
pp = get_param(blk, 'Ports');
n = pp(1);  if strcmp(side, 'out'), n = pp(2); end
t = y - h * (2 * port - 1) / (2 * n);
setp(sys, name, [x, t, x + w, t + h]);
end

function row(sys, name, x, w, h, y)
%ROW  Block centred on the row line y.
setp(sys, name, [x, y - h / 2, x + w, y + h / 2]);
end

function clear_notes(sys)
%CLEAR_NOTES  Remove the annotations a previous tidy_layout drew: tag 'tidy_layout', or
%  (if the tag could not be set) a text starting with one of this tool's title prefixes.
old = find_system(sys, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'annotation');
pre = {'A. ', 'B. ', 'C. ', 'D. ', 'E. ', 'Front end', 'Diagnostics', 'IM_Rebuild parameters', ...
       'Disturbance observer', 'Wind channel', 'Position ESO', 'Each tag'};
for i = 1:numel(old)
    try
        tg = '';  try, tg = get_param(old(i), 'Tag'); catch, end
        tx = '';  try, tx = get_param(old(i), 'Text'); catch, end
        if strcmp(tg, 'tidy_layout') || any(strncmp(tx, pre, cellfun(@numel, pre)))
            delete(get_param(old(i), 'Object'));
        end
    catch
    end
end
end

function a = new_note(sys, text)
%NEW_NOTE  A text annotation in sys ('model/path/text' form; no '/' allowed in text).
assert(~contains(text, '/'), 'tidy_layout: annotation text may not contain ''/''.');
a = Simulink.Annotation([sys '/' text]);
a.Tag = 'tidy_layout';
end

function areas(sys, A)
%AREAS  Area annotations {title, [l t r b]} (add_block('built-in/Area', ...), the documented
%  way to create an area; AnnotationType of an existing annotation is read-only in R2022b)
%  - cosmetic: a failure is reported, not fatal.
for i = 1:size(A, 1)
    try
        assert(~contains(A{i, 1}, '/'), 'tidy_layout: area title may not contain ''/''.');
        h = add_block('built-in/Area', [sys '/' A{i, 1}], 'Position', round(A{i, 2}));
        try, set_param(h, 'Tag', 'tidy_layout'); catch, end
    catch err
        fprintf('  tidy_layout: area annotation skipped in %s (%s)\n', sys, err.message);
        return
    end
end
end

function note(sys, text, pos)
try
    a = new_note(sys, text);
    a.HorizontalAlignment = 'left';
    a.Position = [pos(1), pos(2), pos(1) + 700, pos(2) + 40];
catch err
    fprintf('  tidy_layout: note skipped in %s (%s)\n', sys, err.message);
end
end

%% =====================================================================
%  IM_Est_Online  (image 2): one row per signal, estimator -> rebuild -> outports;
%  diagnostic outputs terminated; the rebuild's parameters grouped below
%% =====================================================================
function extra = lay_imest(sys)
extra = {};
dg = {'w_all_x', 5; 'mag_all_x', 6; 'w_all_y', 7; 'mag_all_y', 8};
for k = 1:size(dg, 1)
    nm = ['IM_T_' dg{k, 1}];
    if getSimulinkBlockHandle([sys '/' nm]) <= 0
        add_block('simulink/Sinks/Terminator', [sys '/' nm]);
        extra{end + 1, 1} = sprintf('IM_Estimator/%d>%s/1', dg{k, 2}, nm); %#ok<AGROW>
    end
end
% estimator 8 outputs, rebuild 8 inputs: pitch 50 -> outputs 1-4 straight into rebuild 1-4
T = 60;  P = 50;
setp(sys, 'IM_Estimator', [560, T, 780, T + 8 * P]);
setp(sys, 'IM_Rebuild',   [940, T, 1120, T + 8 * P]);
ye = @(k) T + P / 2 + P * (k - 1);                        % estimator out k / rebuild in k
yin = @(i) T + (T + 8 * P - T) * (2 * i - 1) / 6;          % estimator in i (3 inputs)
% front end: nu_dot_c -> x/y -> filter -> ZOH -> demux (vx, vy) -> estimator in 1, 2
yd = (yin(1) + yin(2)) / 2;
row(sys, 'IM_F_nu_dot', 20, 110, 30, yd);
row(sys, 'IM_Sel_xy', 170, 50, 30, yd);
row(sys, 'IM_Filt', 260, 90, 34, yd);
row(sys, 'IM_ZOH', 390, 50, 30, yd);
setp(sys, 'IM_Demux', [480, yd - (yin(2) - yin(1)), 490, yd + (yin(2) - yin(1))]);
% time: clock -> ZOH -> estimator in 3
row(sys, 'IM_Clock', 290, 40, 26, yin(3));
row(sys, 'IM_ClockZOH', 390, 50, 30, yin(3));
% diagnostic outputs 5-8 -> terminators right at the port
for k = 1:size(dg, 1)
    row(sys, ['IM_T_' dg{k, 1}], 800, 16, 16, ye(dg{k, 2}));
end
% rebuild parameters 5-8, grouped below the estimator
yb = T + 8 * P + 70;
row(sys, 'IM_L', 560, 70, 26, yb);
row(sys, 'IM_WnpFcn', 670, 110, 30, yb);
row(sys, 'IM_Sigma', 670, 110, 26, yb + 45);
row(sys, 'IM_LAxis', 670, 110, 26, yb + 90);
row(sys, 'IM_Strict', 670, 110, 26, yb + 135);
% rebuild 6 outputs -> outports
outs = {'A_out', 'B_out', 'L_out', 'G_out', 'FB_out', 'RS_out'};
for k = 1:6
    y = T + (8 * P) * (2 * k - 1) / 12;
    row(sys, outs{k}, 1200, 30, 14, y);
end
areas(sys, {'Front end: measured acceleration x and y, filtered, sampled', [10, T - 30, 500, T + 8 * P + 10]; ...
            'Diagnostics: every candidate frequency and magnitude - not used in the loop', ...
                [790, ye(5) - 25, 900, ye(8) + 25]; ...
            'IM_Rebuild parameters', [550, yb - 30, 800, yb + 160]});
end

%% =====================================================================
%  Position_Observers  (image 1): DO band (top), wind-channel band (middle), ESO band (bottom)
%% =====================================================================
function extra = lay_po(sys)
extra = {};
% ---- DO band: DO_12 inputs pitch 50 ----
T = 40;  P = 50;
setp(sys, 'DO_12', [620, T, 790, T + 10 * P]);
yd = @(i) T + P / 2 + P * (i - 1);                         % DO_12 input i
row(sys, 'F_gamma', 20, 110, 30, yd(1));
row(sys, 'F_nu', 20, 110, 30, yd(2));
row(sys, 'F_F_act', 20, 110, 30, yd(4));
row(sys, 'F_dlf_hat', 20, 110, 30, yd(5));
% internal model A, B, L, G: IM_Est_Online (port 1 of each switch) or the constant (port 2)
sw = {'IM_Est_A_Sw', 'Ad'; 'IM_Est_B_Sw', 'Bd'; 'IM_Est_L_Sw', 'lg'; 'IM_Est_G_Sw', 'Gd'};
for k = 1:4
    y = yd(5 + k);
    setp(sys, sw{k, 1}, [530, y - 25, 560, y + 25]);         % in1 y-12.5, in2 y+12.5
    row(sys, sw{k, 2}, 420, 80, 20, y + 12.5);
end
setp(sys, 'IM_Est_Online', [240, yd(6) - 12.5 - 25, 380, yd(6) - 12.5 - 25 + 6 * P]);   % outputs 1-4 -> switch in1
row(sys, 'IM_Fallback_Log', 420, 110, 26, yd(10) + 70);
row(sys, 'IM_Reason_Log', 420, 110, 26, yd(10) + 110);
row(sys, 'g_', 540, 60, 22, yd(10));
% DO state, then the payload channel: predictor (top) / DO output (below) -> PP_Switch
row(sys, 'Int_z', 840, 30, 30, T + 5 * P);
setp(sys, 'Payload_Predictor', [940, T, 1070, T + 3 * P]);
setp(sys, 'DO_Out', [940, T + 4 * P, 1070, T + 9 * P]);
setp(sys, 'PP_Switch', [1180, T + 40, 1220, T + 40 + 6 * P]);
row(sys, 'PP_pon', 1090, 70, 24, T + 40 + 3 * P);
row(sys, 'PP_pred_log', 1300, 100, 26, T + 40 + 5 * P);
% N6 (REGISTER_P2 sec 15.4): PP_Switch -> P2_N6_Sel (port 1 = unchanged, port 2 = + dmf_n6)
yS = T + 40 + 3 * P;                                      % PP_Switch output
pin(sys, 'P2_N6_Sel', 1270, 20, 50, 1, yS, 'in');          % in1 on the PP_Switch row
pin(sys, 'P2_N6_Sum', 1210, 20, 40, 2, yS + 4 * P, 'in');
row(sys, 'P2_F_n6', 1090, 90, 22, yS + 4 * P);
row(sys, 'P2_G_dmf_do', 1090, 90, 22, T + 9 * P + 30);   % tap on DO_Out/1
setp(sys, 'Manual Switch', [1400, yS - 30, 1440, yS + 30]);
row(sys, 'Zero3', 1320, 60, 22, yS + 15);
row(sys, 'G_dmf_hat', 1500, 100, 28, yS);
% ---- wind band: measured / predicted / oracle wind force -> WSEL -> poison -> P2 -> gate ----
W = T + 10 * P + 180;                                     % top of the band
setp(sys, 'WSEL', [860, W, 900, W + 4 * P]);             % in 1..4 at W+25 .. W+175
yw = @(i) W + P / 2 + P * (i - 1);
row(sys, 'WSEL_on', 560, 110, 26, yw(1));
row(sys, 'WM_From', 560, 120, 34, yw(2));  row(sys, 'WM_Kw', 720, 40, 30, yw(2));
row(sys, 'WP_From', 560, 120, 34, yw(3));  row(sys, 'WP_Kw', 720, 40, 30, yw(3));
row(sys, 'WO_From', 560, 120, 34, yw(4));  row(sys, 'WO_Kw', 720, 40, 30, yw(4));
row(sys, 'WP_log', 780, 90, 26, yw(4) + 50);
yo = W + 2 * P;                                           % WSEL output
setp(sys, 'P2_PZ_wsel', [960, yo - 12.5, 990, yo + 37.5]);  % in1 yo, in2 yo+25, out yo+12.5
row(sys, 'P2_PZc_wsel', 905, 45, 20, yo + 40);
setp(sys, 'P2_WD_Sel', [1040, yo, 1070, yo + 50]);         % in1 yo+12.5, in2 yo+37.5, out yo+25
row(sys, 'P2_F_dlf', 960, 70, 22, yo + 65);
setp(sys, 'WD_Switch', [1300, yo, 1340, yo + 150]);        % in1 yo+25, in2 yo+75, in3 yo+125
row(sys, 'WD_gate', 1200, 30, 50, yo + 75);
row(sys, 'WD_on', 1090, 90, 26, yo + 62);
row(sys, 'WP_valid', 1090, 90, 30, yo + 97);
row(sys, 'WP_vlog', 1200, 90, 26, yo + 140);
row(sys, 'P2_G_wgate', 1200, 90, 22, yo + 175);          % tap on WD_gate/1 (N6 gate)
setp(sys, 'Manual Switch1', [1420, yo + 62.5, 1460, yo + 112.5]);   % in1 yo+75, in2 yo+100
row(sys, 'Zero3b', 1350, 60, 22, yo + 100);
row(sys, 'G_dlf_hat', 1520, 100, 28, yo + 87.5);
row(sys, 'DLF_probe', 1520, 100, 26, yo + 130);
% ---- ESO band: 9 inputs pitch 40 ----
E = W + 4 * P + 150;  Q = 40;
setp(sys, 'ESO_15', [260, E, 430, E + 9 * Q]);
ye = @(i) E + Q / 2 + Q * (i - 1);
row(sys, 'F_dmf_hat', 20, 110, 28, ye(4));
k = {'K1', 5; 'K2', 6; 'K3', 7; 'm_', 8; 'g2', 9};
for i = 1:size(k, 1), row(sys, k{i, 1}, 20, 110, 26, ye(k{i, 2})); end
row(sys, 'Int_zp', 500, 30, 30, E + 4.5 * Q);
row(sys, 'ESO_Out', 580, 100, 60, E + 4.5 * Q);
row(sys, 'WD_obs_log', 740, 100, 26, E + 4.5 * Q + 60);
areas(sys, {'Disturbance observer DO_12 (payload channel) + internal model A, B, L, G; N6 term via P2_N6_Sel', [10, T - 30, 1640, T + 10 * P + 140]; ...
            'Wind channel: force of the selected wind (sensor, PI-MoE or oracle); P2 quadratic model via P2_WD_Sel', ...
                [540, W - 30, 1640, W + 4 * P + 60]; ...
            'Position ESO_15 (wind channel estimate)', [10, E - 30, 860, E + 9 * Q + 20]});
end

%% =====================================================================
%  P2 (root subsystem, image 3): P2_Core output k -> VS_k port 2 in a straight line,
%  the v1 signal (From) into port 1 just above it, Goto after
%% =====================================================================
function extra = lay_p2_root(sys)
extra = {};
b = kids(sys);
nm = cellfun(@(s) s(numel(sys) + 2:end), b, 'UniformOutput', false);
vs = sort(nm(strncmp(nm, 'VS_', 3)));
n = numel(vs);
T = 40;  P = 50;
setp(sys, 'P2_Core', [40, T, 220, T + n * P]);
for k = 1:n
    % the order of the outports of P2_Core decides the row: VS_<tag> fed by P2_Core/k
    pc = get_param([sys '/P2_Core'], 'PortConnectivity');
    outs = pc(arrayfun(@(p) ~isempty(p.DstBlock), pc));
    dst = get_param(outs(k).DstBlock(1), 'Name');
    tag = dst(4:end);
    y = T + P / 2 + P * (k - 1);                           % P2_Core out k
    setp(sys, dst, [440, y - 30, 470, y + 10]);            % in1 y-20, in2 y
    if getSimulinkBlockHandle([sys '/F_' tag]) > 0
        row(sys, ['F_' tag], 330, 80, 16, y - 20);
    else
        row(sys, ['Z_' tag], 330, 80, 16, y - 20);
    end
    row(sys, ['G_' tag], 510, 80, 16, y - 10);
end
note(sys, sprintf(['Each tag: port 1 = the v1 signal (plant_model = 0), port 2 = P2 (plant_model = 1).\n' ...
    'P2_Core is compiled only when plant_model = 1.']), [40, T + n * P + 20]);
end

function extra = lay_p2_core(sys)
%LAY_P2_CORE  Variant container: the choice and its outports, rows pitch 50 (as P2).
extra = {};
b = kids(sys);
nm = cellfun(@(s) s(numel(sys) + 2:end), b, 'UniformOutput', false);
o = nm(strncmp(nm, 'o_', 2));
n = numel(o);
T = 40;  P = 50;
setp(sys, 'P2', [60, T, 260, T + n * P]);
for i = 1:n
    k = str2double(get_param([sys '/' o{i}], 'Port'));
    row(sys, o{i}, 360, 30, 14, T + P / 2 + P * (k - 1));
end
end

%% =====================================================================
%  P2/P2_Core/P2 (image 4): five bands - motors, rigid body, sensors, held commands,
%  controller wind force; every chain one row, outports in one column on the right
%% =====================================================================
function extra = lay_p2_choice(sys)
extra = {};
xO = 1900;                                                 % outport column
o = @(name, y) row(sys, name, xO, 30, 14, y);
lg = @(name, x, y) row(sys, name, x, 100, 22, y);         % To Workspace logs
% ---- A. motors: f_i -> clamp -> first-order lag -> mixer -> [f_total ; tau] ----
yM = 70;
row(sys, 'F_f_i', 20, 70, 18, yM);
row(sys, 'M_sat', 130, 40, 30, yM);
pin(sys, 'M_err', 220, 20, 40, 1, yM, 'in');
row(sys, 'M_inv_tau', 280, 50, 30, yM + 10);
row(sys, 'M_f', 370, 30, 30, yM + 10);
pin(sys, 'V_lag', 450, 16, 40, 1, yM + 10, 'in');
row(sys, 'M_mix', 520, 60, 30, yM + 20);
row(sys, 'M_sel_f', 640, 40, 24, yM + 20);
row(sys, 'M_sel_tau', 640, 40, 24, yM + 70);
lg('L_f', 480, yM + 80);
o('o_tau_plant', yM + 70);
% ---- B. rigid body + payload: P2_Trans (plant_p2_free) and its state ----
T = 200;
setp(sys, 'P2_Trans', [760, T, 940, T + 280]);             % in i: T+28+56(i-1); out k: T+20+40(k-1)
yi = @(i) T + 28 + 56 * (i - 1);  yo = @(k) T + 20 + 40 * (k - 1);
row(sys, 'F_eta', 560, 70, 18, yi(3));
row(sys, 'W_true', 540, 120, 30, yi(4));
row(sys, 'prm', 580, 80, 22, yi(5));
row(sys, 'P2_x', 1000, 30, 30, yo(1));
row(sys, 'T_gam', 980, 16, 16, yo(2));
row(sys, 'T_nu', 980, 16, 16, yo(3));
row(sys, 'X_gam', 1080, 36, 24, yo(1));
row(sys, 'X_nu', 1080, 36, 24, yo(1) + 45);
lg('L_mon', 1000, yo(7));
o('o_gamma', yo(1));  o('o_nu', yo(1) + 45);  o('o_nu_dot', yo(4));
o('o_d_mf', yo(5));  o('o_d_lf', yo(6));
% ---- C. sensors; switches: V_*_d (discrete on/off), V_*_s (sensors on/off) ----
x1 = 1180;  x2 = 1260;  x3 = 1360;  xd = 1600;  xs = 1700;
sws = @(name, x, y) pin(sys, name, x, 16, 40, 1, y, 'in');   % in1 at y, in2 at y+20
% mocap position
yP = 560;
row(sys, 'S_pos_zoh', x1, 36, 30, yP);
row(sys, 'S_pos_delay', x2, 44, 30, yP);
pin(sys, 'S_pos_sum', x3, 20, 40, 1, yP, 'in');
row(sys, 'S_pos_noise', x2, 44, 30, yP + 50);
lg('L_npos', x3 + 50, yP + 70);
row(sys, 'D_pos_zoh', 1500, 36, 30, yP - 40);
sws('V_gam_d', xd, yP - 40);
sws('V_gam_s', xs, yP + 10);                              % in1 = the sum's output
lg('L_gamma_c', 1760, yP + 60);
o('o_gamma_c', yP + 20);
% velocity = backward difference of the measured position
yV = 720;
row(sys, 'S_vel_prev', 1420, 40, 30, yV + 30);
pin(sys, 'S_vel_diff', 1490, 20, 40, 1, yV, 'in');
row(sys, 'S_vel_gain', 1530, 50, 30, yV + 10);
row(sys, 'D_vel_zoh', 1500, 36, 30, yV - 50);
sws('V_nu_d', xd, yV - 50);
sws('V_nu_s', xs, yV + 10);
lg('L_nu_c', 1760, yV + 60);
o('o_nu_c', yV + 20);
% accelerometer
yA = 880;
row(sys, 'S_acc_zoh', x1, 36, 30, yA);
pin(sys, 'S_acc_sum', x3, 20, 60, 1, yA, 'in');
row(sys, 'S_acc_noise', x2, 44, 30, yA + 40);
row(sys, 'S_acc_bias', x2 - 10, 60, 22, yA + 80);
lg('L_nacc', x3 + 50, yA + 70);
sws('V_acc_d', xd, yA - 40);
sws('V_acc_s', xs, yA + 20);
o('o_nu_dot_c', yA + 30);
% gyro
yG = 1040;
row(sys, 'F_omega', 1060, 80, 18, yG);
row(sys, 'S_gyr_zoh', x1, 36, 30, yG);
pin(sys, 'S_gyr_sum', x3, 20, 40, 1, yG, 'in');
row(sys, 'S_gyr_noise', x2, 44, 30, yG + 50);
lg('L_ngyr', x3 + 50, yG + 70);
sws('V_gyr_d', xd, yG - 40);
sws('V_gyr_s', xs, yG + 10);
o('o_omega_c', yG + 20);
% attitude (clean, sampled)
yE = 1160;
row(sys, 'S_eta_zoh', x1, 36, 30, yE);
sws('V_eta_d', xd, yE);
o('o_eta_c', yE + 10);
% ---- D. controller outputs held by the discrete loops ----
cmd = {'F_Fcmd', 'H_Fcmd', 'V_Fcmd_d', 'o_Fcmd_c'; 'F_fthr', 'H_fthr', 'V_fthr_d', 'o_fthr_c'; ...
       'F_tau_cmd', 'H_tau_cmd', 'V_tau_d', 'o_tau_cmd_c'};
for k = 1:3
    y = 1290 + 70 * (k - 1);
    row(sys, cmd{k, 1}, 1060, 80, 18, y);
    row(sys, cmd{k, 2}, x1, 36, 30, y);
    sws(cmd{k, 3}, xd, y);
    o(cmd{k, 4}, y + 10);
end
lg('L_Fcmd', 1760, 1290 + 40);
% ---- E. the controller's wind-force model (REGISTER_P2 sec 0.3) ----
yW = 1560;
setp(sys, 'W_sel', [1400, yW, 1440, yW + 200]);            % in 1..4 at yW+25 .. yW+175
yws = @(i) yW + 25 + 50 * (i - 1);
row(sys, 'W_selc', 1240, 90, 24, yws(1));
row(sys, 'W_meas', 1220, 120, 32, yws(2));
row(sys, 'W_pred', 1220, 120, 32, yws(3));
row(sys, 'W_orac', 1220, 120, 32, yws(4));
setp(sys, 'P2_WindHat', [1540, yW + 80, 1680, yW + 200]);  % in 1 w (= W_sel out), 2 nu_c, 3 prm_w
row(sys, 'prm_w', 1455, 70, 22, yW + 180);
o('o_dlf_p2', yW + 140);
% ---- F. N6 wind -> payload term (REGISTER_P2 sec 15.4): observer + tau-ahead prediction ----
yF = 1880;
setp(sys, 'P2_N6', [1560, yF, 1700, yF + 280]);            % in i: yF + 20 + 40 (i - 1)
yn = @(i) yF + 20 + 40 * (i - 1);
row(sys, 'N6_s', 1440, 40, 30, yn(1));
row(sys, 'N6_z_wm', 1440, 36, 30, yn(2));
row(sys, 'N6_z_ws', 1440, 36, 30, yn(3));
row(sys, 'N6_z_v', 1440, 36, 30, yn(4));
row(sys, 'N6_z_d', 1440, 36, 30, yn(5));   row(sys, 'F_dmf_do', 1300, 80, 18, yn(5));
row(sys, 'N6_z_g', 1440, 36, 30, yn(6));   row(sys, 'F_wgate', 1300, 80, 18, yn(6));
row(sys, 'N6_prm', 1420, 80, 22, yn(7));
o('o_dmf_n6', yF + 140);
lg('L_n6', 1760, yF + 230);
areas(sys, {'A. Motors: clamp, first-order lag (V_lag = GD3 switch), mixer', [10, 20, 760, 170]; ...
            'B. Rigid body + payload: plant_p2_free (P2_Trans), 12-state integrator', [520, 180, 1140, 500]; ...
            'C. Sensors: mocap 125 Hz + 8 ms, velocity by difference, IMU, gyro, attitude  (V_x_d = discrete on-off, V_x_s = sensors on-off)', ...
                [1040, 500, 1880, 1210]; ...
            'D. Controller outputs held by the discrete loops', [1040, 1240, 1880, 1480]; ...
            'E. Controller wind-force model: quadratic in (w - nu_c), w = sensor, PI-MoE or oracle (P2_WindHat)', ...
                [1200, 1510, 1880, 1820]; ...
            'F. N6: pendulum observer on the DO payload estimate + prediction tau ahead with the column wind (P2_N6, used when p2_n6 = 1)', ...
                [1280, 1850, 1880, 2190]});
end
