function ok = check_all(varargin)
%CHECK_ALL  ONE command that runs every gate in the repository, as a scorecard.
%
%   check_all                  % everything
%   check_all('Quick', true)   % skip the checks that read large .mat files
%
%  ======================================================================
%  IT ANSWERS EXACTLY ONE QUESTION
%  ======================================================================
%  "Does everything in this repository still agree with everything else?" -
%  and it answers with a scorecard, not a paragraph.
%
%  It runs NO simulation. Every check here READS a saved result file and
%  compares, so the whole thing takes seconds rather than hours.
%
%  ======================================================================
%  WHAT IT CHECKS (P2 paper; the planar-pendulum v1 study and its data were
%  removed 2026-10-04, user decision, so its result-file checks are gone)
%  ======================================================================
%  (1) SYNTAX      - is every .m file resolvable on the path.
%  (2) LOCK        - does the Guo baseline configuration match PROTOCOL_LOCK.md.
%  (3) SENTENCES   - has a withdrawn claim come back (tools/check_retracted.py).
%  (4) PROPAGATION - are the numbers of paper/manuscript.md in docs/RESULTS_P2.md /
%                    paper/tables/tables_p2.md, both generated from the result files.
%  (5) MODEL       - do the blocks in baseline1.slx match simulink_blocks/.
%  (6) EQUATIONS   - does every labelled equation have a row in
%                    EQUATIONS_TABLE.md; no priority claim on a formula.
%  (7) NAMES       - no internal controller code in figures, tables, text.
%
%  ======================================================================
%  WHAT IT CANNOT CHECK - these must be read by a person
%  ======================================================================
%    - interpretation: "numerically close" written as "reproduces";
%    - whether a figure caption is still true after the figure changed;
%    - a NEW wrong sentence - check (3) only knows the ones already known.

opt = struct('Quick', false, 'Dir', '');
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
here = repo_root();
if isempty(opt.Dir), opt.Dir = here; end
addpath(opt.Dir);

R = {};   % {name, status, note}
fprintf('\n%s\n', repmat('=', 1, 74));
fprintf('  CHECK_ALL - repository scorecard\n');
fprintf('%s\n', repmat('=', 1, 74));

%% (1) SYNTAX --------------------------------------------------------
fprintf('\n[1/7] Syntax: can every .m file be resolved\n');
% Scan the source folders, not just the root. The sources were sorted into
% subdirectories; a bare dir(opt.Dir, '*.m') would silently check two files
% and report PASS, which is worse than not checking at all.
d = src_files(opt.Dir);
bad = {};
for k = 1:numel(d)
    [~, nm] = fileparts(d(k).name);
    if strcmp(nm, mfilename), continue; end
    try
        % 'which' makes MATLAB parse the file. It does NOT call the function:
        % calling would actually run it, and some functions here open Simulink
        % or overwrite files.
        w = which(nm);
        if isempty(w), bad{end+1} = [nm '  (not found on the path)']; end %#ok<AGROW>
    catch err
        bad{end+1} = sprintf('%s  (%s)', nm, err.message); %#ok<AGROW>
    end
end
if isempty(bad)
    R(end+1,:) = {'syntax / path', 'PASS', sprintf('%d .m files', numel(d))};
else
    R(end+1,:) = {'syntax / path', 'FAIL', sprintf('%d file(s) with problems', numel(bad))};
    for k = 1:numel(bad), fprintf('      ! %s\n', bad{k}); end
end
fprintf('      %d .m files on the path\n', numel(d));

%% (2) PROTOCOL LOCK -------------------------------------------------
fprintf('\n[2/7] Protocol lock\n');
if exist(fullfile(opt.Dir, 'PROTOCOL_LOCK.md'), 'file') ~= 2
    R(end+1,:) = {'protocol_lock', 'SKIP', 'no PROTOCOL_LOCK.md yet'};
    fprintf('      no PROTOCOL_LOCK.md - skipped\n');
else
    % *** ESTABLISH THE STATE, THEN CHECK IT. ***
    %
    % This used to call protocol_lock('check') bare. protocol_lock's do_check
    % reads the operating condition out of the BASE WORKSPACE, so that call
    % answered one of two useless questions:
    %
    %   - in a freshly opened MATLAB, base is empty and the gate died with
    %     "R_traj, w_traj, ... missing from base";
    %   - in a session where something had been run before, it compared the
    %     lock against whatever state happened to be left over.
    %
    % The second is worse than the first, because it PASSES. This gate reported
    % "configuration matches the lock" for a long time on the strength of
    % variables left behind by an earlier op_set - the exact class of silent
    % state-leakage that reset_extensions, op_set and op_condition all exist to
    % prevent, sitting inside the suite that checks for it.
    %
    % The meaningful question is the one run_confirm_once asks: bring the state
    % to the condition THE LOCK NAMES, then verify that everything derived from
    % it still equals what was locked. That still catches a changed op_set row,
    % a changed V_ref (through K_w), a changed tau_pred, and a re-exported
    % manifest - while no longer depending on invisible prior state.
    %
    % It costs a mutated base workspace, which is why it says so.
    try
        evalin('base', 'init_MOBADC_params');
        evalc('Lk = protocol_lock(''print'', ''File'', fullfile(opt.Dir, ''PROTOCOL_LOCK.md''));');
        op_set(Lk.condition);
        fprintf('      state set from the lock: %s (base workspace modified)\n', ...
                Lk.condition);
        protocol_lock('check', 'PayloadModel', Lk.payload_model, ...
                      'PayloadWind', Lk.payload_K_ratio);
        R(end+1,:) = {'protocol_lock', 'PASS', 'configuration matches the lock'};
    catch err
        R(end+1,:) = {'protocol_lock', 'FAIL', err.message};
        fprintf('      ! %s\n', err.message);
    end
end

%% (3) WITHDRAWN CLAIMS ----------------------------------------------
% Calls tools/check_retracted.py. It needs no MATLAB, so it is also the one
% gate here that somebody without MATLAB can still run.
fprintf('\n[3/7] Withdrawn claims (tools/check_retracted.py)\n');
R = py_gate(R, opt, 'check_retracted', 'CHECK_RETRACTED', ...
            'no withdrawn claim has returned', 'a withdrawn claim is back');

%% (4) NUMBER PROPAGATION --------------------------------------------
% Gate (3) checks SENTENCES; this one checks NUMBERS:
%     docs/RESULTS_P2.md, paper/tables/tables_p2.md (generated) -> paper/manuscript.md
fprintf('\n[4/7] Number propagation (tools/check_propagation.py)\n');
R = py_gate(R, opt, 'check_propagation', 'CHECK_PROPAGATION', ...
            'every result number is verbatim from RESULTS_P2 / TABLES_P2', 'number mismatch');

%% (5) MODEL vs BLOCK SOURCES ----------------------------------------
% The code that actually runs is inside baseline1.slx, a binary. simulink_blocks/
% is only a readable copy, and NOTHING makes the two agree.
%
% This gate existed as tools/extract_eml.py --check from the start, but nothing
% ever called it, so it never ran. On 2026-09-12 commit e5326a8 rewrote a
% documentation path across the repository and caught two block sources in the
% sweep; the model was not resynchronised. sync_eml_blocks compares VERBATIM,
% comments included, so run_baseline, run_test4_payload, run_test5_predictor and
% run_sanity_t2 all refused to start - and check_all still reported 9/9 PASS,
% because it was not looking. A gate nobody calls is not a gate.
%
% The Python twin is used rather than sync_eml_blocks itself: it needs no
% Simulink licence and no loaded model, so this gate also runs for a reviewer
% who only has the repository.
fprintf('\n[5/7] Model vs block sources (tools/extract_eml.py --check)\n');
R = py_gate(R, opt, 'extract_eml', 'CHECK_EML_SYNC', ...
            'baseline1.slx matches simulink_blocks/', ...
            'the model and simulink_blocks/ are out of sync', ...
            sprintf('"%s" --check "%s"', fullfile(opt.Dir, 'baseline1.slx'), ...
                                         fullfile(opt.Dir, 'simulink_blocks')));

%% (6) EQUATIONS TABLE ------------------------------------------------
% Every labelled equation of the manuscript ({#eq:name}) has a row in
% docs/EQUATIONS_TABLE.md, every @eq: citation resolves, every row has a valid
% type (user decision 2026-09-29, GD11c). Before submission run the same tool
% with --final (no [C?], no CAN TIM, every row ticked).
fprintf('\n[6/7] Equations table (tools/check_equations.py)\n');
R = py_gate(R, opt, 'check_equations', 'CHECK_EQUATIONS', ...
            'every labelled equation has a table row', 'equation label / table mismatch');

%% (7) NAMES --------------------------------------------------------
% No internal controller code (L0-L3, V, iii, iii-0, H3) in the manuscript,
% the generated tables / results or any drawn figure string (REGISTER_P2
% sec 63.1; names: analysis/p2_names.m).
fprintf('\n[7/7] Names in figures, tables, manuscript (tools/check_names.py)\n');
R = py_gate(R, opt, 'check_names', 'CHECK_NAMES', ...
            'no internal code in figures, tables, manuscript', 'an internal code is shown');

%% SCORECARD ---------------------------------------------------------
fprintf('\n%s\n', repmat('=', 1, 74));
fprintf('  SCORECARD\n');
fprintf('%s\n', repmat('-', 1, 74));
nd = 0; nl = 0; nb = 0;
for k = 1:size(R,1)
    fprintf('  %-8s %-30s %s\n', ['[' R{k,2} ']'], R{k,1}, trim1(R{k,3}));
    switch R{k,2}
        case 'PASS',   nd = nd + 1;
        case 'FAIL',   nl = nl + 1;
        otherwise,     nb = nb + 1;
    end
end
fprintf('%s\n', repmat('-', 1, 74));
fprintf('  %d passed / %d failed / %d skipped\n', nd, nl, nb);
ok = (nl == 0);
if ok
    fprintf('  [OK] every gate that could run has passed.\n');
else
    fprintf(['  [!] %d failure(s). Fix from CHECK 1 downwards: broken syntax\n' ...
             '      makes the lock meaningless, a mismatched lock makes every\n' ...
             '      later check meaningless, and so on.\n'], nl);
end
fprintf(['\n  Three things this cannot check - they must be read by a person:\n' ...
         '    - interpretation (e.g. "numerically close" -> "reproduces")\n' ...
         '    - whether a figure caption survived a change of figure\n' ...
         '    - a NEW wrong sentence: check (3) only knows the old ones\n\n']);
end

function s = trim1(s)
s = strrep(char(s), sprintf('\n'), ' ');
if numel(s) > 30, s = [s(1:27) '...']; end
end


%% =====================================================================
function R = py_gate(R, opt, name, banner, ok_msg, bad_msg, gate_args)
%PY_GATE  Run one Python gate and record the outcome on the scorecard.
%  Python is named differently on different machines, so try each in turn. A
%  missing Python is NOT a FAIL - that is a missing tool, not a wrong paper.
%  But it is not a PASS either: a gate that could not run has checked nothing.
%
%  gate_args is optional: most gates take none, extract_eml needs the .slx and
%  the source directory.
if nargin < 7, gate_args = ''; end
gate = fullfile(opt.Dir, 'tools', [name '.py']);
if exist(gate, 'file') ~= 2
    R(end+1,:) = {name, 'SKIP', sprintf('no tools/%s.py', name)};
    return
end
cand = {'python3', 'python', 'py -3'};
st = -1; outp = '';
for c = 1:numel(cand)
    [st, outp] = system(strtrim(sprintf('%s "%s" %s', cand{c}, gate, gate_args)));
    if st == 0 || ~isempty(strfind(outp, banner)) %#ok<STREMP>
        break
    end
end
if isempty(strfind(outp, banner)) %#ok<STREMP>
    R(end+1,:) = {name, 'SKIP', 'could not invoke python'};
elseif st == 0
    R(end+1,:) = {name, 'PASS', ok_msg};
else
    R(end+1,:) = {name, 'FAIL', [bad_msg ' - run it directly to see']};
end
fprintf('%s', outp);
end

%% =====================================================================
function d = src_files(root)
%SRC_FILES  Every .m file in the repository's MATLAB source folders.
%  The list mirrors setup_path: a folder holding MATLAB sources appears in
%  both, or in neither. Absent folders are skipped so this keeps working
%  during a reorganisation.
FOLDERS = {'', 'core', 'build', 'simulink_blocks', 'experiments', ...
           'verification', 'analysis', 'figures'};
d = [];
for i = 1:numel(FOLDERS)
    p = fullfile(root, FOLDERS{i});
    if exist(p, 'dir') ~= 7, continue; end
    d = [d; dir(fullfile(p, '*.m'))];  %#ok<AGROW>
end
end
