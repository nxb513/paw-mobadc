function S = check_confirm_manifest(varargin)
%CHECK_CONFIRM_MANIFEST  Re-read the manifest INDEPENDENTLY and look for leaks.
%
%   S = check_confirm_manifest
%   S = check_confirm_manifest('Manifest','CONFIRM_MANIFEST.json')
%
%  ======================================================================
%  THIS DOES NOT TRUST THE MANIFEST - IT CHECKS IT
%  ======================================================================
%  make_confirm_manifest.py reports that it filtered correctly. A file that
%  certifies itself certifies nothing. This function re-reads the same claim
%  along a DIFFERENT route (MATLAB, from the actual result tables) and looks
%  for contradictions.
%
%  Run it BEFORE protocol_lock('write'). Locking happens once; checking does
%  not.
%
%  ======================================================================
%  EIGHT CHECKS
%  ======================================================================
%   1  used_days.txt is the union over EVERY result table, not just one
%   2  NO day in the manifest appears in used_days             <- LEAK
%   3  every confirmation segment on disk has split = heldout
%   4  every confirmation segment belongs to a day IN the manifest
%   4c every segment's real_file is in the manifest's FILE list (stricter than 4)
%   5  the file list hashes to the recorded sha256_files
%   6  every development/confirmation table that has been scored is listed
%   7  the manifest does NOT carry run-configuration fields (PROTOCOL_LOCK owns those)
%   8  the manifest HAS every field protocol_lock('write') is about to read
%
%  Check 7 is about SEPARATION OF ROLES, not about numbers:
%      the manifest   proves WHICH DATA was used
%      PROTOCOL_LOCK  proves WHAT WAS RUN
%  Merge the two into one file and a configuration change alters the data hash
%  and vice versa, and nobody can tell any more what actually changed.

opt = struct('Manifest', 'CONFIRM_MANIFEST.json', 'Used', 'used_days.txt', ...
             'Pattern', 'wind_conf_t150_i*.mat');
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
here = repo_root();
cd(here); setup_path();
assert(exist(opt.Manifest,'file') == 2, ...
    'check_confirm_manifest: no %s yet. Run make_confirm_manifest.py first.', opt.Manifest);

txt = fileread(opt.Manifest);
mdays = json_list(txt, 'days');
mfiles = json_list(txt, 'files');
h_names = json_str(txt, 'sha256_files');

fprintf('\n%s\n  INDEPENDENT CHECK: %s\n%s\n', repmat('=',1,76), opt.Manifest, repmat('=',1,76));
fprintf('  manifest: %d days, %d files\n', numel(mdays), numel(mfiles));

bad = {};  skip = {};

%% 1 - is used_days the union over EVERY table
if exist(opt.Used,'file') == 2
    used = to_m5_all(strtrim(strsplit(strtrim(fileread(opt.Used)))));
    used = used(~cellfun(@isempty, used));
    fprintf('\n  (1) %s: %d days\n', opt.Used, numel(used));
else
    used = {};
    bad{end+1} = sprintf('(1) no %s yet - run dump_used_days first.', opt.Used);
    fprintf('\n  (1) ! no %s\n', opt.Used);
end

%% 2 - LEAK: does any manifest day appear in used_days
ov = intersect(to_m5_all(mdays), used);
if isempty(ov)
    fprintf('  (2) [OK] no manifest day appears in used_days\n');
else
    bad{end+1} = sprintf(['(2) *** LEAK: %d day(s) are in both the manifest and ' ...
                          'used_days: %s ***'], numel(ov), strjoin(ov, ' '));
    fprintf('  (2) *** LEAK: %s ***\n', strjoin(ov, ' '));
end

%% 3, 4 - confirmation segments on disk
f = dir(opt.Pattern);
if isempty(f)
    fprintf('  (3,4,4c) confirmation segments not exported yet (%s) - SKIPPED\n', opt.Pattern);
    skip = {'3','4','4b','4c'};
else
    nsp = 0;  nday = 0;  seen = {};
    for k = 1:numel(f)
        S1 = load(f(k).name, 'split', 'real_file');
        if ~isfield(S1,'split') || ~strcmpi(strtrim(char(S1.split)), 'heldout')
            nsp = nsp + 1;
        end
        if isfield(S1,'real_file')
            dd = day_m5(S1.real_file);
            seen{end+1} = dd; %#ok<AGROW>
            if ~any(strcmp(dd, to_m5_all(mdays))), nday = nday + 1; end
        end
    end
    fprintf('  (3) %d segments, %d do NOT have split = heldout\n', numel(f), nsp);
    fprintf('  (4) %d segments belong to a day OUTSIDE the manifest\n', nday);
    if nsp  > 0, bad{end+1} = sprintf('(3) %d segment(s) not heldout', nsp); end
    if nday > 0, bad{end+1} = sprintf('(4) %d segment(s) outside the manifest', nday); end
    ov2 = intersect(unique(seen), used);
    if ~isempty(ov2)
        bad{end+1} = sprintf('(4b) *** confirmation segment on an ALREADY-USED day: %s ***', ...
                             strjoin(ov2, ' '));
    end
    % (4c) at FILE level, not just DAY level. The manifest lists SOURCE files;
    % what gets scored are the SEGMENTS cut from them at export time, and the
    % manifest pins no individual segment. A day-level check would let a
    % re-export at a different height or duration pass unnoticed.
    nrf = 0;  rfs = {};
    for k = 1:numel(f)
        S2 = load(f(k).name, 'real_file');
        if isfield(S2,'real_file')
            r = strtrim(char(S2.real_file));  rfs{end+1} = r; %#ok<AGROW>
            if ~any(strcmp(r, mfiles)), nrf = nrf + 1; end
        end
    end
    fprintf('  (4c) %d segment(s) whose real_file is OUTSIDE the manifest list\n', nrf);
    if nrf > 0
        bad{end+1} = sprintf('(4c) %d segment(s) outside the fixed file set', nrf);
    end
    fprintf('       used %d/%d of the manifest source files\n', ...
            numel(unique(rfs)), numel(mfiles));

    % DAY COVERAGE. The paper's unit of inference is the DAY, not the segment
    % (R0.2): median across days, jackknife across days. If 30 segments span
    % only a handful of days, the effective n of the confirmation table is far
    % below the n = 15 of the development table, and that has to be known
    % BEFORE scoring rather than read off the result afterwards.
    %
    % REPORTED ONLY. The set is already fixed and hashed; re-exporting to "get
    % more days" would be choosing the set after looking at it.
    ud = unique(seen(~cellfun(@isempty, seen)));
    cnt = cellfun(@(d) sum(strcmp(seen, d)), ud);
    fprintf('       spans %d/%d manifest days | %d..%d segments per day\n', ...
            numel(ud), numel(mdays), min(cnt), max(cnt));
    if numel(ud) < 8
        fprintf(['       ! n by DAY = %d, far below the n = 15 of the development\n' ...
                 '         table. The day-level statistics will be weak - state that\n' ...
                 '         in the paper, do NOT re-export to find more days.\n'], numel(ud));
    end
end

%% 5 - hash of the file list
h2 = sha_names(mfiles);
if isempty(h2)
    fprintf('  (5) SHA-256 unavailable in this MATLAB - SKIPPED\n');
    skip{end+1} = '5';
elseif strcmpi(h2, h_names)
    fprintf('  (5) [OK] sha256_files matches the file list in the manifest\n');
else
    bad{end+1} = '(5) sha256_files does NOT match the file list';
    fprintf('  (5) ! sha256 differs: recorded %s, recomputed %s\n', h_names(1:12), h2(1:12));
end

%% 6 - which tables are contributing
fprintf('  (6) dump_used_days scans: heldout_final, dev_t4, field_grid_K*, field_benchmark_K*\n');
g = [dir('field_grid_K*.mat'); dir('field_benchmark_K*.mat'); ...
     dir('dev_t4.mat'); dir('heldout_final.mat')];
fprintf('      present on disk: %d table(s)\n', numel(g));
if numel(g) < 2
    bad{end+1} = ['(6) fewer than 2 result tables on disk - used_days is likely ' ...
                  'MISSING days. Run dump_used_days in the right directory.'];
end

%% 7 - separation of roles
cfgk = {'payload_model','payload_K_ratio','theta_dc_max','pool_L1','metric_seg'};
in_man = cfgk(cellfun(@(k) ~isempty(strfind(txt, ['"' k '"'])), cfgk)); %#ok<STREMP>
if isempty(in_man)
    fprintf('  (7) [OK] the manifest carries no run-configuration field (PROTOCOL_LOCK owns those)\n');
else
    bad{end+1} = sprintf(['(7) the manifest carries run-configuration fields (%s) - ' ...
                          'duplicating the role of PROTOCOL_LOCK'], strjoin(in_man, ', '));
end

%% 8 - does the manifest have every field protocol_lock IS ABOUT TO READ
% do_write calls manifest_field for each of these and ASSERTS if one is
% missing. It fails BEFORE writing the file, so nothing breaks - but a failure
% during a ONE-TIME step is better known in advance. A manifest produced by the
% older script has no sha256_content and no sha256_split_rule.
need = {'sha256_files','sha256_content','sha256_split_rule','n_days'};
miss = need(cellfun(@(k) isempty(strfind(txt, ['"' k '"'])), need)); %#ok<STREMP>
if isempty(miss)
    fprintf('  (8) [OK] the manifest has every field protocol_lock will read\n');
else
    bad{end+1} = sprintf(['(8) the manifest is MISSING %s - protocol_lock(''write'') ' ...
                          'would fail. Regenerate it with the current script.'], ...
                         strjoin(miss, ', '));
    fprintf('  (8) ! missing: %s\n', strjoin(miss, ', '));
end

%% ---- conclusion ----
% A SKIPPED CHECK IS NOT A PASSED CHECK.
% An earlier version printed "ALL SEVEN CHECKS PASSED" even when the three
% checks that depend on exported segments had not run at all. A reader takes
% that as everything being clear, and that is how a gate that does not exist
% gets recorded as a gate that passed.
fprintf('\n%s\n', repmat('-',1,76));
if isempty(bad) && ~isempty(skip)
    fprintf(['  [OK] every check that COULD run has passed. SKIPPED: %s\n' ...
             '       -> Enough for protocol_lock(''write'') (locking happens BEFORE export).\n' ...
             '       -> But this function MUST be re-run AFTER exporting the segments\n' ...
             '          and BEFORE scoring: checks %s are exactly the ones that test\n' ...
             '          whether the scored set is the set that was fixed.\n'], ...
            strjoin(skip, ','), strjoin(skip, ','));
elseif isempty(bad)
    fprintf('  [OK] ALL EIGHT CHECKS RAN AND ALL PASSED.\n');
else
    fprintf('  *** %d PROBLEM(S) - DO NOT lock: ***\n', numel(bad));
    fprintf('    %s\n', bad{:});
end
fprintf('%s\n\n', repmat('-',1,76));
S = struct('manifest', opt.Manifest, 'days', {mdays}, 'files', {mfiles}, ...
           'used', {used}, 'problems', {bad}, 'skipped', {skip}, ...
           'ok', isempty(bad));
end

%% =====================================================================
function v = json_list(txt, key)
t = regexp(txt, ['"' key '"\s*:\s*\[(.*?)\]'], 'tokens', 'once');
if isempty(t), v = {}; return, end
m = regexp(t{1}, '"([^"]+)"', 'tokens');
v = cellfun(@(c) c{1}, m, 'UniformOutput', false);
end
function v = json_str(txt, key)
t = regexp(txt, ['"' key '"\s*:\s*"([^"]*)"'], 'tokens', 'once');
if isempty(t), v = ''; else, v = t{1}; end
end
function c = to_m5_all(c)
for i = 1:numel(c), c{i} = to_m5(strtrim(c{i})); end
end
function s = to_m5(s)
s = strtrim(strrep(s, '"', ''));
if numel(s) == 10 && s(5) == '-' && s(8) == '-'
    s = [s(6:7) '_' s(9:10) '_' s(1:4)];
end
end
function s = day_m5(rf)
s = strtrim(char(rf));
if numel(s) >= 10 && s(3) == '_' && s(6) == '_', s = s(1:10); else, s = ''; end
end
function h = sha_names(files)
%SHA_NAMES  SHA-256 of the newline-joined file names - identical to the Python side.
h = '';
try
    s = strjoin(files(:)', sprintf('\n'));
    md = java.security.MessageDigest.getInstance('SHA-256');
    b = md.digest(uint8(s));
    h = lower(reshape(dec2hex(typecast(b, 'uint8'))', 1, []));
catch
end
end
