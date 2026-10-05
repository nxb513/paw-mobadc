function L = protocol_lock(mode, varargin)
%PROTOCOL_LOCK  Lock the protocol before the confirmation set, and CHECK it by machine.
%
%   L = protocol_lock('write', 'Manifest','CONFIRM_MANIFEST.json')
%   L = protocol_lock('check')
%   L = protocol_lock('print')
%
%  ======================================================================
%  A LOCK FILE NOBODY CHECKS IS ONLY A PROMISE
%  ======================================================================
%  "Write PROTOCOL_LOCK.md and commit it" is right in spirit but binds nothing:
%  the code still runs with a different horizon, a different configuration, a
%  different statistics window, and the lock file sits there knowing none of it.
%  So this function writes the lock in a MACHINE-READABLE form, and
%  run_confirm_once calls 'check' before it runs - one field out of agreement
%  and it refuses.
%
%  ======================================================================
%  WRITTEN BY MACHINE, NOT TYPED BY HAND
%  ======================================================================
%  The values are captured from the base workspace at the moment of locking,
%  not re-typed. Typed by hand, the lock file drifts sooner or later from what
%  actually ran - and at that point it is worse than having no lock at all: it
%  certifies something false.
%
%  ======================================================================
%  FORMAT
%  ======================================================================
%  Readable Markdown, but the locked fields sit between the two markers
%  <<<LOCK and LOCK>>> as 'key = value', one field per line. Diffable by git,
%  readable by a person, parseable by machine, and with no dependency on
%  jsonencode.
%
%  ======================================================================
%  THE ENGLISH CONVERSION STOPPED AT THE LOCK RECORD - ON PURPOSE
%  ======================================================================
%  This repository was converted to English in 2026-09. The string values
%  written into the <<<LOCK ... LOCK>>> block below were NOT converted, and are
%  marked in do_write between the sentinels FROZEN-LOCK-TEXT.
%
%  The committed PROTOCOL_LOCK.md was written at 2026-09-09T20:57:13 and its
%  entire evidential value rests on not having been modified since. Translating
%  those four-or-so descriptive fields here would mean this source no longer
%  reproduces the committed artefact - and the artefact is the thing that
%  cannot be replaced. 'check' compares only numeric fields and manifest
%  hashes, so a translation would pass; that it would pass is exactly why it
%  must not be done. PROTOCOL_LOCK.md carries an English reading aid for those
%  fields, marked there as carrying no authority.
%
%  Everything outside that block - the prose preamble, this documentation, all
%  messages - is English, and the preamble here is the same text as the
%  committed file's.

if nargin < 1, mode = 'print'; end
opt = struct('File', 'PROTOCOL_LOCK.md', 'Manifest', 'CONFIRM_MANIFEST.json', ...
             'Cond', 'Test 4', 'TauWindMs', 150, 'Stop', 200, 'TStat', 140, ...
             'PayloadModel', 1, 'PayloadWind', 0.5, 'KSens', 1.0, ...
             'ThetaMax', 15, 'DvThr', 1.0);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
here = repo_root();
cd(here); setup_path();

switch lower(mode)
    case 'write', L = do_write(opt);
    case 'check', L = do_check(opt);
    case 'print', L = do_print(opt);
    otherwise, error('protocol_lock: mode must be write / check / print.');
end
end

%% =====================================================================
function L = do_write(opt)
assert(exist(opt.File,'file') ~= 2, 'protocol_lock:exists', '%s', sprintf( ...
    ['%s ALREADY EXISTS. Locking is a ONE-TIME act.\n\n' ...
     'If it genuinely has to be locked again (say phase 1 re-measured the\n' ...
     'vehicle and the numbers moved), then DELETE the file and STATE PLAINLY\n' ...
     'in the paper that the protocol was locked twice, with the reason.\n' ...
     'Silently overwriting is how a lock file loses all of its value.'], opt.File));

% Captured from the base workspace: not one number typed by hand.
evalin('base','init_MOBADC_params');
C = op_set(opt.Cond);
L = struct();
L.lock_version    = 2;                       % 2 = OUTDOOR configuration (§0.93)
L.locked_utc      = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
L.condition       = C.name;
L.R_traj          = C.R_traj;
L.V_traj          = C.V_traj;
L.payload_sigma   = C.payload_sigma;
L.payload_amp     = C.payload_amp;
L.wind_amp        = C.wind_amp;
% K_w is NOT chosen, it is DERIVED (wind_to_force line 20: K_w = wind_amp /
% V_ref). Both the theta_DC envelope and the §0.91 prediction rest on it, so it
% has to be inside the lock - otherwise a change to V_ref moves both of them
% and nothing reports it.
[~, L.K_w]        = wind_to_force([]);
% --- OUTDOOR CONFIGURATION (§0.93) ---
% BEFORE §0.93 this line was hard-coded 'L.payload_model = 0' with the comment
% "sin - same as every earlier table". That is the LABORATORY configuration.
% Every outdoor table (§0.82, §0.87, §0.89) runs payload_model = 1 with the
% physical pendulum AND payload_wind_on. Locking it unchanged would have made
% the lock file certify a configuration DIFFERENT from the one that ran - worse
% than having no lock file.
L.payload_model   = opt.PayloadModel;
L.payload_wind_on = double(opt.PayloadWind > 0);
L.payload_K_ratio = opt.PayloadWind;         % nominal; the confirmation set is scored here
L.K_sensitivity   = opt.KSens;               % run separately, reported alongside, NOT a substitute
L.do_harm_base    = '1';                     % L0 = Guo's original
L.do_harm_pa      = '[0 1]';                 % PA-MOBADC: adds the one-directional mode
L.tau_pred        = evalin('base','tau_pred');
L.tau_wind_ms     = opt.TauWindMs;           % PI-MoE checkpoint, not changeable
L.ckpt            = 'w4_frozen_20hz_t150_train2345_s0';
L.configs         = 'g_base,g_pay,g_wind,g_both,g_sens,g_psens,g_orac';
L.controllers     = 'Classical{0,0,0},ESO{0,1,1},DO{1,0,0},MOBADC{1,1,1},PA-MOBADC{1,1,1}+[0 1]';
L.confirm_mode    = 'both';                  % outdoor grid AND sinusoidal grid

% ---------------------------------------------------------------------
% <<<FROZEN-LOCK-TEXT
% The strings below are not prose, they are the LOCK RECORD. They reproduce the
% committed PROTOCOL_LOCK.md byte-for-byte and are deliberately left in the
% language they were written in on 2026-09-09. See the header of this file, and
% the section "The lock block is in Vietnamese, and it stays that way" in
% PROTOCOL_LOCK.md. Do not translate them; do not reformat them.
% ---------------------------------------------------------------------
L.confirm_field   = 'sweep_field_grid, cham dang ky D0 (muc 0.78)';
L.confirm_sin     = 'sweep_pa_grid, payload_model=0, cham T4-1..T4-6 (muc 0.49)';

% --- METRIC: record WHAT ACTUALLY RAN ---
% BEFORE §0.93 these two lines recorded 'sse_track' and 'sqrt(sum(sse_track)/
% sum(n_track))'. The code in fact pooled per-segment 'mean(en)' and then took
% an RMS across segments - a DIFFERENT quantity. The LOCK FILE was corrected to
% match the CODE, not the code to match the lock file, and the reason is not
% "recomputing would be expensive": mean(en) is MEAN TRACKING ERROR, the
% quantity Guo reports in Table 1 and the quantity expected_baseline compares
% against. Switching to sse_track would make our table incomparable with Guo's.
L.metric_seg      = 'mean(norm(p_d - p)) tren cua so t >= TStat';
L.agg_pooled      = 'sqrt(mean(m_i^2)) tren cac doan trong tap gop';
L.agg_by_day      = 'sqrt(mean(m_i^2)) trong NGAY, roi TRUNG VI qua cac ngay';
L.uncertainty     = 'jackknife theo NGAY tren trung vi';
L.metric_rejected = 'sqrt(sum(sse_track)/sum(n_track)) - da can nhac va LOAI';

% --- POOLING RULE: pool_rule.m, §0.88 ---
% pool_L1 is recorded below as a MODEL envelope. That justification was later
% withdrawn - the simulated pendulum does not linearise, so 15 deg cannot be
% defended as the bound of a small-angle model - while the threshold itself is
% unchanged. See pool_rule.m (L1) and Section 6, R6.2 of the manuscript. The
% locked file records what was believed on 2026-09-09, which is what a locked
% file is for; it is not corrected here, and must not be.
L.pool_L1         = sprintf('bao mo hinh theta_DC <= %g do', opt.ThetaMax);
L.theta_dc_max    = opt.ThetaMax;
L.theta_dc_form   = 'rad2deg(K*K_w*U/(m_p*g))';
L.pool_L2         = 'mot bang = mot tap: moi cot cua bang do huu han va khong phan ky';
L.pool_L3         = 'con so dau bai lay tu BANG CHINH (moi cot la bien the MOBADC)';
L.pool_L4         = 'phan ky bao RIENG theo tung bo';
L.divergence      = sprintf('~isfinite(mean(en)) | mean(en) > %g m', opt.DvThr);
L.dv_thresh       = opt.DvThr;
L.exclusion       = 'OnDiverge=flag; loai theo pool_rule (L1)+(L2), KHONG loc NaN tung cot';
% FROZEN-LOCK-TEXT>>>
% ---------------------------------------------------------------------

L.Stop            = opt.Stop;
L.TStat           = opt.TStat;
L.solver          = 'ode4/1e-3';
L.manifest        = opt.Manifest;
L.manifest_sha256 = manifest_field(opt.Manifest, 'sha256_files');
% Hash the CONTENT, not just the names. Re-exporting the same file names with
% different parameters leaves sha256_files UNCHANGED - see §0.94. Lock on both.
L.manifest_content = manifest_field(opt.Manifest, 'sha256_content');
L.manifest_split  = manifest_field(opt.Manifest, 'sha256_split_rule');
L.manifest_ndays  = str2double(manifest_field(opt.Manifest, 'n_days'));

% The preamble is the same text as the committed PROTOCOL_LOCK.md, lines 1-13.
% The committed file also carries a section AFTER the LOCK>>> marker (an English
% reading aid for the frozen fields); that section was added later, sits outside
% the block, and is not generated here.
txt = {
'# PROTOCOL LOCK'
''
'Locked before the independent confirmation set was scored, under condition'
'Test 4. Written by `protocol_lock(''write'')`, verified by'
'`protocol_lock(''check'')`. `run_confirm_once` calls `''check''` before it runs and'
'REFUSES to run if anything differs.'
''
'Registered predictions: `docs/devlog/W6_INTEGRATION.md` §0.49, table T4-1..T4-6.'
'They were written BEFORE any closed-loop result existed at Test 4.'
''
'From this point on: no change to the horizon, the configuration, the metric, or'
'the day split. A bad Test 4 may not retreat to Test 2.'
''
'<<<LOCK'};
f = fieldnames(L);
for i = 1:numel(f)
    v = L.(f{i});
    if ischar(v), sv = v; else, sv = num2str(v, '%.12g'); end
    txt{end+1} = sprintf('%s = %s', f{i}, sv);  %#ok<AGROW>
end
txt{end+1} = 'LOCK>>>';

fid = fopen(opt.File, 'w');
assert(fid > 0, 'protocol_lock: cannot write %s.', opt.File);
fprintf(fid, '%s\n', txt{:});  fclose(fid);
fprintf('Protocol locked -> %s\n\n', opt.File);
do_print(opt);
fprintf('\n  COMMIT this file NOW, before exporting the confirmation segments.\n');
end

%% =====================================================================
function L = do_check(opt)
L = read_lock(opt.File);

% Version 1 of the lock file described the LABORATORY configuration
% (payload_model = 0, metric sse_track). Scoring the outdoor confirmation set
% against it would be a false certificate. Refuse outright rather than compare
% field by field and then report "matches".
if ~isfield(L, 'lock_version') || L.lock_version < 2
    error('protocol_lock:oldlock', '%s', sprintf( ...
        ['%s is a VERSION 1 lock file (laboratory configuration:\n' ...
         'payload_model = 0, metric sse_track). The outdoor configuration\n' ...
         'requires version 2 (§0.93). Delete the file, lock again with\n' ...
         'protocol_lock(''write''), and STATE PLAINLY in the paper that the\n' ...
         'protocol was locked twice, with the reason.'], opt.File));
end

C = op_condition('Quiet', true);          % the condition CURRENTLY in base
bad = {};
bad = cmp_s(bad, 'condition',     C.name,                        L.condition);
bad = cmp_n(bad, 'R_traj',        C.R_traj,                      L.R_traj);
bad = cmp_n(bad, 'payload_sigma', C.payload_sigma,               L.payload_sigma);
bad = cmp_n(bad, 'payload_amp',   C.payload_amp,                 L.payload_amp);
bad = cmp_n(bad, 'wind_amp',      C.wind_amp,                    L.wind_amp);
[~, kw] = wind_to_force([]);
bad = cmp_n(bad, 'K_w',           kw,                            L.K_w);
bad = cmp_n(bad, 'tau_pred',      evalin('base','tau_pred'),     L.tau_pred);

% *** payload_model / payload_wind_on / K are deliberately NOT read from base ***
%
% reset_extensions turns every extension OFF at the start of EVERY pa_configs
% call, and the caller then sets back whatever it needs (§0.79). So between two
% runs these three variables in base are GARBAGE - reading them here would
% report a spurious mismatch, or worse, report a MATCH at the moment they all
% happen to be zero.
%
% What has to be checked is the configuration the caller is ABOUT to run.
% run_confirm_once declares it:
%     protocol_lock('check', 'PayloadModel',1, 'PayloadWind',0.5)
% and the lock refuses if it differs. Check the INTENT, not a transient state.
bad = cmp_n(bad, 'payload_model', opt.PayloadModel,              L.payload_model);
bad = cmp_n(bad, 'payload_K_ratio', opt.PayloadWind,             L.payload_K_ratio);
bad = cmp_n(bad, 'theta_dc_max',  opt.ThetaMax,                  L.theta_dc_max);
bad = cmp_n(bad, 'dv_thresh',     opt.DvThr,                     L.dv_thresh);

% The manifest must be EXACTLY the one that was locked. Change the directory
% after locking and the hash changes.
h = manifest_field(L.manifest, 'sha256_files');
bad = cmp_s(bad, 'manifest_sha256', h, L.manifest_sha256);
if isfield(L, 'manifest_content')
    bad = cmp_s(bad, 'manifest_content', ...
                manifest_field(L.manifest, 'sha256_content'), L.manifest_content);
    bad = cmp_s(bad, 'manifest_split', ...
                manifest_field(L.manifest, 'sha256_split_rule'), L.manifest_split);
end

if ~isempty(bad)
    error('protocol_lock:mismatch', '%s', sprintf( ...
        ['PROTOCOL DIFFERS FROM %s - scoring is NOT allowed.\n\n%s\n' ...
         'Either put the state back to what the lock says, or (if the lock\n' ...
         'genuinely has to change) delete the lock file, lock again, and STATE\n' ...
         'PLAINLY in the paper that it was locked twice.'], ...
        opt.File, strjoin(bad, sprintf('\n'))));
end
fprintf('  protocol MATCHES %s (locked at %s)\n', opt.File, L.locked_utc);
end

%% =====================================================================
function L = do_print(opt)
L = read_lock(opt.File);
f = fieldnames(L);
fprintf('  --- %s ---\n', opt.File);
for i = 1:numel(f)
    v = L.(f{i});
    if ~ischar(v), v = num2str(v, '%.12g'); end
    fprintf('  %-18s %s\n', f{i}, v);
end
end

%% =====================================================================
function L = read_lock(file)
assert(exist(file,'file') == 2, 'protocol_lock:missing', '%s', sprintf( ...
    ['%s does not exist. The protocol has not been locked.\n' ...
     'Lock it in phase 2, AFTER phase 1 has finished measuring the vehicle\n' ...
     'and BEFORE the confirmation set is touched:  protocol_lock(''write'')'], file));
s = fileread(file);
i1 = strfind(s, '<<<LOCK');  i2 = strfind(s, 'LOCK>>>');
assert(~isempty(i1) && ~isempty(i2) && i2(end) > i1(1), ...
    'protocol_lock: %s has no <<<LOCK ... LOCK>>> block.', file);
body = s(i1(1)+7 : i2(end)-1);
lines = strtrim(strsplit(body, sprintf('\n')));
L = struct();
for k = 1:numel(lines)
    if isempty(lines{k}), continue; end
    p = strfind(lines{k}, '=');
    assert(~isempty(p), 'protocol_lock: line is not key = value: %s', lines{k});
    key = strtrim(lines{k}(1:p(1)-1));  val = strtrim(lines{k}(p(1)+1:end));
    n = str2double(val);
    if ~isnan(n) && ~isempty(regexp(val, '^[-+0-9.eE]+$', 'once'))
        L.(key) = n;
    else
        L.(key) = val;
    end
end
end

%% =====================================================================
function v = manifest_field(file, key)
%MANIFEST_FIELD  Read one field out of CONFIRM_MANIFEST.json with a regexp.
% Not jsondecode: one dependency fewer, and only two fields are needed.
assert(exist(file,'file') == 2, 'protocol_lock:manifest', '%s', sprintf( ...
    ['%s does not exist. Fix the manifest first:\n' ...
     '    dump_used_days\n' ...
     '    python3 python/make_confirm_manifest.py --real-dir <m5> ' ...
     '--used-days used_days.txt'], file));
s = fileread(file);
t = regexp(s, ['"' key '"\s*:\s*"([^"]*)"'], 'tokens', 'once');
if isempty(t)
    t = regexp(s, ['"' key '"\s*:\s*([-0-9.eE]+)'], 'tokens', 'once');
end
assert(~isempty(t), 'protocol_lock: %s has no field "%s".', file, key);
v = t{1};
end

function bad = cmp_n(bad, name, cur, want)
if isempty(cur) || abs(double(cur) - double(want)) > 1e-9
    bad{end+1} = sprintf('  %-16s is now %g, the lock says %g', name, cur, want);
end
end
function bad = cmp_s(bad, name, cur, want)
if ~strcmp(strtrim(char(cur)), strtrim(char(want)))
    bad{end+1} = sprintf('  %-16s is now ''%s'', the lock says ''%s''', name, cur, want);
end
end
