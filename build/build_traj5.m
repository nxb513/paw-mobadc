function ok = build_traj5(varargin)
%BUILD_TRAJ5  Add traj_type/traj_par to Traj_Ref, for the robustness campaign.
%
%   build_traj5                    % build, check, KEEP (no save)
%   build_traj5('Save', true)      % build, check, then write the .slx
%   build_traj5('Revert', true, 'Save', true)   % take it back out
%
%  ======================================================================
%  WHAT THIS IS
%  ======================================================================
%  docs/REGISTER_ROBUST.md's Phase C question - does a trajectory that is
%  NOT synchronised with the payload's disturbance frequency change what
%  prediction buys over reference preview - needs trajectories other than
%  the circle. simulink_blocks/trajectory_ref.m now carries five of them
%  (hover, circle, figure-8, square, multi-sine), selected by two new
%  inputs. This script is the SECOND half of that change: growing
%  Traj_Ref's port count in baseline1.slx to match, following exactly the
%  precedent build_traj_preview.m set when it grew the same block from 4
%  ports to 5.
%
%  ======================================================================
%  WHY THIS IS SAFE FOR THE FIVE EXISTING SAVED RESULT FILES
%  ======================================================================
%  traj_type = 1 (circle) with traj_par all-zero reproduces the PRE-EXISTING
%  five-argument function bit for bit - simulink_blocks/trajectory_ref.m's
%  own case 1 branch is character-for-character the old file's body. Every
%  saved result was produced at traj_type left undefined, i.e. this build's
%  default of 1. Gate 1 below checks that default is actually 1 and that
%  run_baseline still reproduces exactly, the same discipline
%  build_lqi_controller and build_traj_preview used before it.
%
%  ======================================================================
%  THE TWO NEW BLOCKS
%  ======================================================================
%      before:  ... -> Traj_Ref (5 in) -> ...
%      after:   ... -> Traj_Ref (7 in) -> ...
%               TR_trajtype/1 -> Traj_Ref/6   (Constant, reads traj_type)
%               TR_trajpar/1  -> Traj_Ref/7   (Constant, reads traj_par, 4x1)
%
%  traj_type and traj_par are workspace variables, exactly like tau_prev
%  before them, and for the same reason: a Constant block's Value is
%  evaluated at compile time from the base workspace, so a MISSING variable
%  fails loudly ("Invalid setting for parameter 'Value'") rather than
%  silently running the wrong trajectory.

opt = struct('Save', false, 'Revert', false, 'Skip0', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
here = repo_root();
cd(here); setup_path();

require_block_sources(here, {'trajectory_ref'});

mdl = 'baseline1';
if ~bdIsLoaded(mdl), load_system(mdl); end
tr  = [mdl '/Trajectory'];
blk = [tr '/Traj_Ref'];
c1  = [tr '/TR_trajtype'];
c2  = [tr '/TR_trajpar'];

assert(getSimulinkBlockHandle(blk) > 0, 'build_traj5:noblk', ...
    'Cannot find %s. This model is not the one this repository describes.', blk);

%% ---------------- Revert ----------------
if opt.Revert
    n = teardown(tr, c1, c2);
    % Do NOT re-read simulink_blocks/trajectory_ref.m here, for the same
    % reason build_traj_preview's Revert does not: the file on disk now has
    % SEVEN inputs, so reading it back would reinstall the very thing being
    % removed. orig_fcn_text() below is the 5-input body, frozen verbatim.
    write_fcn_text(blk, orig_fcn_text(), 5);
    fprintf('Removed %d block(s). Traj_Ref back to 5 inputs.\n', n);
    ok = compile_check(mdl);
    if ok && opt.Save, save_system(mdl); fprintf('Wrote %s.\n', mdl); end
    return
end

%% ---------------- Clean-model control, before touching anything ----------
if ~opt.Skip0
    fprintf('\n=== CONTROL: does the CLEAN model compile? ===\n');
    ok0 = compile_check(mdl);
    if ~ok0
        fprintf(['\n[!] The clean model does not compile. This build is NOT the\n' ...
                 '    cause - read the causes printed above. Fix that first.\n']);
        ok = false;
        return
    end
end

%% ---------------- Workspace defaults ----------
% traj_type = 1 is the ONLY default that keeps every saved result meaningful:
% it is what every one of them ran at, implicitly, before this variable
% existed. traj_par = zeros(4,1) is inert for every branch that reads it
% (circle and hover ignore it outright).
if ~evalin('base', 'exist(''traj_type'',''var'')')
    assignin('base', 'traj_type', 1);
    fprintf('traj_type was not set -> 1 (circle, the baseline every saved result used).\n');
else
    v = evalin('base', 'traj_type');
    assert(isequal(v, 1), 'build_traj5:trajtype', '%s', sprintf(...
        ['traj_type is already set to %g in the base workspace.\n' ...
         'Gate 1 needs it at 1 (circle) to check against run_baseline.\n' ...
         'Set it to 1, or run reset_extensions-style cleanup, then retry.'], v));
end
if ~evalin('base', 'exist(''traj_par'',''var'')')
    assignin('base', 'traj_par', zeros(4,1));
    fprintf('traj_par was not set -> [0;0;0;0].\n');
end

%% ---------------- Idempotent teardown, then build ----------
teardown(tr, c1, c2);
write_fcn(blk, fullfile(here, 'simulink_blocks', 'trajectory_ref.m'), 7);

add_block('simulink/Sources/Constant', c1, ...
          'Value', 'traj_type', 'Position', [40 360 140 390]);
add_block('simulink/Sources/Constant', c2, ...
          'Value', 'traj_par', 'Position', [40 420 140 450]);
add_line(tr, 'TR_trajtype/1', 'Traj_Ref/6', 'autorouting', 'on');
add_line(tr, 'TR_trajpar/1',  'Traj_Ref/7', 'autorouting', 'on');

%% ---------------- Check ----------
fprintf('\n=== CHECK ===\n');
ok = compile_check(mdl);
if ~ok
    post_mortem(tr, blk, c1, c2);
    fprintf(['\n[!] Compile failed - NOT written. The model in memory is modified;\n' ...
             '    build_traj5(''Revert'', true) puts it back, or close unsaved:\n' ...
             '        close_system(''baseline1'', 0)\n']);
    return
end
fprintf(['\n[OK] Traj_Ref now has 7 inputs. traj_type = 1, traj_par = 0 is an\n' ...
         '     EXACT no-op versus the 5-input form - Gate 1, next, is what\n' ...
         '     proves that rather than assumes it.\n']);
if opt.Save
    save_system(mdl);
    fprintf('     Wrote %s.slx\n', mdl);
    fprintf(['     docs/SNAPSHOT.md''s baseline1.slx row is now stale. Do NOT\n' ...
             '     update it until Gate 1 (below) has passed.\n']);
else
    fprintf('     NOT written. Call again with (''Save'', true) to keep it.\n');
end

fprintf(['\nGATE 1 - in this order, stop at the first failure:\n' ...
         '  sync_eml_blocks                 %% must report a match\n' ...
         '  clear traj_type traj_par; run_baseline  %% 4 numbers unchanged;\n' ...
         '                                    %% traj_type/traj_par unset here\n' ...
         '                                    %% on purpose - see the note below\n' ...
         '  traj_check                      %% Octave-verified already; re-run\n' ...
         '                                    %% here as the MATLAB cross-check\n' ...
         'run_baseline does not set traj_type or traj_par, so this also checks\n' ...
         'that reset_extensions (or an equivalent) supplies traj_type = 1 when\n' ...
         'nothing else does - the same class of gap that let wind_pred_on leak\n' ...
         'between runs before. If run_baseline errors on a missing traj_type,\n' ...
         'that gap is real and core/reset_extensions.m needs the entry before\n' ...
         'anything in the campaign runs.\n']);
end


%% =====================================================================
function n = teardown(tr, c1, c2)
n = 0;
try
    delete_line(tr, 'TR_trajtype/1', 'Traj_Ref/6');
catch
end
try
    delete_line(tr, 'TR_trajpar/1', 'Traj_Ref/7');
catch
end
if getSimulinkBlockHandle(c1) > 0, delete_block(c1); n = n + 1; end
if getSimulinkBlockHandle(c2) > 0, delete_block(c2); n = n + 1; end
end

function write_fcn(blk, mfile, n_in)
write_fcn_text(blk, fileread(mfile), n_in, mfile);
end

function write_fcn_text(blk, txt, n_in, src)
if nargin < 4, src = '<inline text>'; end
sig = regexp(txt, '^\s*function\s*\[[^\]]*\]\s*=\s*trajectory_ref\(([^)]*)\)', ...
             'tokens', 'once', 'lineanchors');
assert(~isempty(sig), 'build_traj5:sig', ...
    '%s has no recognisable trajectory_ref signature.', src);
args = strtrim(strsplit(sig{1}, ','));
assert(numel(args) == n_in, 'build_traj5:nin', ...
    '%s has %d inputs, need %d. Wrong source for this mode.', ...
    src, numel(args), n_in);

ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', blk);
assert(~isempty(ch), 'build_traj5:nochart', ...
    'No Stateflow.EMChart found for %s.', blk);
ch.Script = txt;

ph = get_param(blk, 'PortHandles');
assert(numel(ph.Inport) == n_in, 'build_traj5:ports', ...
    ['Signature set to %d inputs but the block still shows %d ports.\n' ...
     'Open %s once in Simulink and run this again.'], n_in, numel(ph.Inport), blk);
end

function txt = orig_fcn_text()
%ORIG_FCN_TEXT  The 5-input body, frozen verbatim, for Revert only.
txt = sprintf([ ...
 'function [gamma_d, nu_d, acc_d] = trajectory_ref(t, R, w, z0, tau_prev)\n' ...
 '%%#codegen\n' ...
 'gamma_d = zeros(3,1); nu_d = zeros(3,1); acc_d = zeros(3,1);\n' ...
 'tp = t + tau_prev;\n' ...
 'gamma_d = [R*cos(w*t);       R*sin(w*t);       z0];\n' ...
 'nu_d    = [-R*w*sin(w*t);    R*w*cos(w*t);     0 ];\n' ...
 'acc_d   = [-R*w^2*cos(w*tp); -R*w^2*sin(w*tp); 0 ];\n' ...
 'end\n']);
end

function ok = compile_check(mdl)
ok = false;
% *** THE MISSING STEP THAT PROVED IT WAS MISSING. ***
% build_traj_preview.m's compile_check - the precedent this file copied -
% did not need init_MOBADC_params or reset_extensions here, because when it
% was written the model had no Constant block that read a variable neither
% of them supplies. LQI_K1/K2/K3 changed that: they are unconditional
% Constants, evaluated at compile time whether or not lqi_on is set, exactly
% like every From Workspace block ensure_fromws exists for - and on a cold
% workspace this compile_check failed on 'lqi_K1' before it ever touched
% trajectory_ref, on the very first real run of this file.
%
% reset_extensions is the single place this project keeps that list
% (core/reset_extensions.m's own header: "every run script is protected at
% the same moment"). Calling it here, rather than re-deriving the same
% defaults a second time in this file, is what that sentence means in
% practice.
evalin('base', 'init_MOBADC_params');
evalin('base', 'reset_extensions(''Quiet'', true);');
safe_term(mdl);
fwcl = ensure_fromws(mdl); %#ok<NASGU>
try
    feval(mdl, [], [], [], 'compile');
    c = onCleanup(@() safe_term(mdl)); %#ok<NASGU>
    fprintf('  compile: OK\n');
    ok = true;
catch err
    fprintf('  compile: FAILED\n');
    print_causes(err, '    ');
end
end

function print_causes(err, pad)
if ~isempty(err.identifier), fprintf('%s[%s]\n', pad, err.identifier); end
msg = regexprep(err.message, '<[^>]*>', '');
for L = strsplit(msg, newline)
    if ~isempty(strtrim(L{1})), fprintf('%s%s\n', pad, strtrim(L{1})); end
end
for k = 1:numel(err.cause)
    fprintf('%s--- cause %d/%d ---\n', pad, k, numel(err.cause));
    print_causes(err.cause{k}, [pad '  ']);
end
end

function post_mortem(tr, blk, c1, c2)
fprintf('\n  --- state after the edit ---\n');
try
    ph = get_param(blk, 'PortHandles');
    fprintf('    %s: %d in / %d out\n', blk, numel(ph.Inport), numel(ph.Outport));
catch e
    fprintf('    could not read %s ports: %s\n', blk, e.message);
end
for c = {c1, c2}
    try
        fprintf('    %s Value = ''%s''\n', c{1}, get_param(c{1}, 'Value'));
    catch
        fprintf('    %s does not exist\n', c{1});
    end
end
try
    lh = get_param(blk, 'LineHandles');
    for k = 1:numel(lh.Inport)
        if lh.Inport(k) <= 0
            fprintf('    [!] input port %d of %s is NOT connected\n', k, blk);
        end
    end
catch
end
end

function safe_term(mdl)
try
    if ~strcmp(get_param(mdl,'SimulationStatus'), 'stopped')
        feval(mdl, [], [], [], 'term');
    end
catch
end
end
