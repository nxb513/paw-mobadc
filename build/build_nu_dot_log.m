function build_nu_dot_log(varargin)
%BUILD_NU_DOT_LOG  Minimal, additive To Workspace tap on the existing
%                   global 'nu_dot' signal, for Part 3.4's offline
%                   real-signal IM-est test (docs/REGISTER_C.md sec
%                   4.35 item 2 / sec 4.36).
%
%   build_nu_dot_log('Save', true)
%   build_nu_dot_log('Revert', true)
%
%  ======================================================================
%  WHY THIS EXISTS, AND WHY IT IS SEPARATE FROM build_payload_pendulum.m
%  ======================================================================
%  IM-est needs nu_dot(1:2) - the UAV's own translational acceleration,
%  the physical source that forces the pendulum (payload_pendulum_
%  derivative.m's own header: "a_uav ... lay tu nu_dot(1:2)") - logged
%  from REAL wind-driven runs so the estimator prototype (currently pure
%  Python, synthetic signals only, docs/REGISTER_C.md sec 4.33/4.34) can
%  be tested against real turbulence before any Simulink wiring is
%  attempted. No existing To Workspace block carries it: nu_dot is only
%  broadcast as a global Goto/From routing tag today
%  (build_payload_pendulum.m's own PL_G_nu_dot/PL_F_nu_dot).
%
%  A SEPARATE script, not an addition to build_payload_pendulum.m,
%  because that file's own build/teardown pairing is already the
%  reproduction path for every published number that touches the
%  payload channel - adding an unrelated diagnostic tap there risks
%  entangling two independent changes in one teardown/rebuild cycle.
%  This script only ever adds a NEW, PARALLEL From block reading the
%  SAME already-broadcast tag (Simulink's global tags support multiple
%  independent readers by design) plus one To Workspace sink - it does
%  not cut, reroute, or otherwise touch any existing signal path.
%
%  Tapped at PL_F_nu_dot2's own output - i.e. directly off the global
%  tag, NOT after PL_Mem_a's one-step delay - so the log carries the
%  TRUE, undelayed nu_dot, matching what a real onboard estimator would
%  read (IM-est's eventual live wiring reads the plant signal directly,
%  not the delayed copy the pendulum's own algebraic-loop break needs).
%
%  CHECKPOINT (registered, sec 4.36): verify_repro, check_results_
%  numbers, check_all must all stay bit-exact after this - the same bar
%  every other additive logging change this session (Part 3.8) was held
%  to. This tap reads an existing signal and writes nothing back into
%  the model; no existing computation path is touched.

opt = struct('Save', false, 'Revert', false, 'Quiet', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
say = @(varargin) fprintf(varargin{:});
if opt.Quiet, say = @(varargin) []; end

mdl  = 'baseline1';
here = repo_root();
cd(here); setup_path();

if ~bdIsLoaded(mdl), load_system(mdl); end
dist = [mdl '/Disturbances'];

from_blk = [dist '/PL_F_nu_dot2'];
log_blk  = [dist '/PL_nu_dot_log'];

% ---------------- idempotent teardown ----------------
n_removed = 0;
for b = {from_blk, log_blk}
    if getSimulinkBlockHandle(b{1}) > 0
        delete_line_into(dist, b{1});
        delete_block(b{1});
        n_removed = n_removed + 1;
    end
end
if n_removed > 0
    say('  removed %d block(s) from a previous run\n', n_removed);
end

if opt.Revert
    if opt.Save, save_system(mdl); end
    say('  reverted to baseline (no nu_dot log block present).\n');
    return
end

% ---------------- build ----------------
add_block('simulink/Signal Routing/From', from_blk, ...
          'GotoTag', 'nu_dot', 'TagVisibility', 'global', ...
          'Position', [40 700 150 730]);

add_block('simulink/Sinks/To Workspace', log_blk, ...
          'VariableName', 'nu_dot_log', 'SaveFormat', 'Structure With Time', ...
          'MaxDataPoints', 'inf', 'Decimation', '1', ...
          'Position', [190 700 280 730]);

add_line(dist, 'PL_F_nu_dot2/1', 'PL_nu_dot_log/1', 'autorouting', 'on');

say('  added PL_F_nu_dot2 (From, tag=nu_dot) -> PL_nu_dot_log (To Workspace).\n');

if opt.Save
    save_system(mdl);
    say('  saved %s.\n', mdl);
else
    say('  NOT saved (Save=false) - model in memory only.\n');
end
end

function delete_line_into(dist, blk)
% Best-effort: remove any line feeding this block's input, if one exists,
% before deleting the block itself (delete_block alone can leave a
% dangling line end behind).
try
    ph = get_param(blk, 'PortHandles');
    if isfield(ph, 'Inport') && ~isempty(ph.Inport)
        lh = get_param(ph.Inport(1), 'Line');
        if lh > 0, delete_line(lh); end
    end
catch
end
end
