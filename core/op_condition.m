function C = op_condition(varargin)
%OP_CONDITION  Read, VERIFY and NAME the operating condition in base workspace.
%
%   C = op_condition                    % read + verify, silent
%   C = op_condition('Quiet', false)    % print one line
%
%  ======================================================================
%  WHY THIS FUNCTION HAS TO EXIST
%  ======================================================================
%  core/init_MOBADC_params.m sets payload_sigma = 0.625 and w_traj = 0.625
%  UNCONDITIONALLY. Only run_baseline overrode them to Test 4; no grid script
%  did. So every closed-loop result in W6 - the development grid, the locked
%  set, the wind ladder, sweep_tau_eff, E1a/E1b, the validity curve - ran at
%  Test 2.
%
%  That is not wrong in itself. What was wrong is that the operating condition
%  was HIDDEN: no script printed it, no .mat file stored it, so it could only be
%  found by re-reading the source after every experiment had already run. This
%  is precisely the silent-failure class of the payload_model trap in §0.38 -
%  210 runs in sinusoidal mode while the person running them believed it was
%  the pendulum.
%
%  This function turns the condition into a quantity that is READ, PRINTED and
%  STORED.
%
%  ======================================================================
%  THE MOST IMPORTANT CHECK HERE: A_do vs payload_sigma
%  ======================================================================
%  build_do_matrices builds A_do ONCE from payload_sigma. Change payload_sigma
%  afterwards without rebuilding and the DO internal model keeps oscillating at
%  the OLD frequency; DO then estimates ~0 and MOBADC silently degrades to
%  Classical, with no warning. init asserts this at its end, but any assignin
%  issued after init walks straight past that. So it is checked again here,
%  every time the condition is read.

opt = struct('Quiet', true, 'Assert', true);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

need = {'R_traj','w_traj','payload_sigma','payload_amp','wind_amp'};
miss = {};
for i = 1:numel(need)
    if ~evalin('base', sprintf('exist(''%s'',''var'')', need{i}))
        miss{end+1} = need{i};  %#ok<AGROW>
    end
end
assert(isempty(miss), 'op_condition: %s missing from base. Run init_MOBADC_params first.', ...
       strjoin(miss, ', '));

C = struct();
for i = 1:numel(need)
    C.(need{i}) = double(evalin('base', need{i}));
end
C.V_traj  = C.w_traj * C.R_traj;
C.T_orbit = 2*pi / C.w_traj;

% The payload disturbance mode travels with the condition: a table in
% sinusoidal mode and a table in pendulum mode are not comparable, and that is
% exactly one of the errors this guards against.
%
% traj_type/traj_par added for Part 3.2 (TEST_PLAN_PROMPT.md): read
% optionally, same as the others, so a script that predates build_traj5.m
% (traj_type never existing at all) is unaffected - it simply never enters
% any of the five new naming branches below and falls through to 'Test 3/4'
% exactly as it always did.
for f = {'payload_model','payload_z_on','payload_inj_on','tau_pred','traj_type','traj_par', ...
         'im_est_online_on'}
    if evalin('base', sprintf('exist(''%s'',''var'')', f{1}))
        C.(f{1}) = double(evalin('base', f{1}));
    end
end

%% ---- naming ----
% Guo 4.2.2 / 4.2.4: r = 0.8 m at both Tests. Test 2 v = 0.50 m/s, Test 3/4
% v = 1.26 m/s. sigma = v/r.
%
% These names are DATA, not display text: op_set's round-trip check compares
% against them, they are stored as G.cond in every result file, and
% PROTOCOL_LOCK.md locks the string 'Test 3/4'. They are therefore not
% translated and must not be reworded.
%
% The A4 series (docs/REGISTER_TAU.md §A4) must read back, or op_set's final
% round-trip check - "name it X, read it back, get X" - fails and those three
% conditions cannot run at all. They are tested BEFORE the Test 3/4 branch,
% because that branch does not look at payload_sigma and would misread a
% detuned configuration as Test 4.
% Robustness campaign, Part 3.2: the five new traj_type conditions, named
% BEFORE 'Test 3/4' so they are not misread by R/w coincidence - same
% placement rule, same reason, as the A4 series above them. traj_type = 1
% (circle) or traj_type absent (a script that predates build_traj5.m) both
% fall through to 'Test 3/4' unchanged - Rule 4's "new default reproduces
% the old digit for digit" applies to NAMING too, not just to the numbers.
hastt = isfield(C, 'traj_type');
if near(C.R_traj, 0.0) && near(C.w_traj, 1.575)
    C.name = 'A4 hover';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 1.575) && near(C.payload_sigma, 0.8)
    C.name = 'A4 detune low';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 1.575) && near(C.payload_sigma, 3.2)
    C.name = 'A4 detune high';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 1.575) && hastt && near(C.traj_type, 0)
    C.name = 'Hover';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 1.575) && hastt && near(C.traj_type, 2) ...
        && isfield(C,'traj_par') && near(C.traj_par(1), 0.566)
    C.name = 'Fig8 res';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 0.7875) && hastt && near(C.traj_type, 2) ...
        && isfield(C,'traj_par') && near(C.traj_par(1), 1.130)
    C.name = 'Fig8 off-res';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 1.575) && hastt && near(C.traj_type, 3)
    C.name = 'Square';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 1.575) && hastt && near(C.traj_type, 4)
    C.name = 'Multisine';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 0.625)
    C.name = 'Test 2';
elseif near(C.R_traj, 0.8) && near(C.w_traj, 1.575)
    C.name = 'Test 3/4';
else
    C.name = 'OTHER';
end

%% ---- consistency checks ----
% In circular flight the slung load is forced at EXACTLY the orbit frequency
% (§0.35 measured 99.98% of the line at sigma). So sigma ~= w_traj is a
% non-physical configuration - it may be deliberate, but it may not be silent.
%
% *** NOT YET REPLACED BY do_w_axis, DELIBERATELY. ***
% TEST_PLAN_PROMPT.md's Part 3.2 asks for this check to compare against
% do_w_axis (the per-axis declared frequency set) instead of a single
% sigma vs w_traj scalar comparison - but do_w_axis is Part 3.3's own
% deliverable (build_do_matrices's per-axis form, the IM-oracle table) and
% does not exist yet. Left as the single-sigma check for now: still
% correct for Test 2/Test 4/A4 (unchanged), and still non-crazy for the
% five new conditions (op_set.m sets payload_sigma = w_traj as IM-single's
% own convention for all five - see op_set.m's own comment on why that is
% NOT yet the physically right frequency for Square/Multisine/Hover). Do
% not read a clean pass here as "the internal model is at the right
% frequency for this shape" - that claim is exactly what Part 3.3 has not
% been built to make yet.
C.sigma_matches_traj = near(C.payload_sigma, C.w_traj);

% *** THIS CHECK ONCE FAILED, in the worst possible way: ALWAYS FAILING ***
%
% It originally took min(abs(imag(eig(A_do)))) and compared that with
% payload_sigma. Correct while do_harm was a scalar (A_do has one block,
% eigenvalues +-i*sigma). But since §0.69 the LOCKED configuration is
% do_harm = [0 1]: the DC block has eigenvalue 0, so min(...) is ALWAYS 0 and
% the check ALWAYS failed - even with a perfectly correct A_do.
%
% A gate that always fails protects nothing: it only trains the reader to
% ignore it. And it did exactly that - check_all reported a mismatch here while
% all 74 numbers in the paper agreed.
%
% What has to be checked is whether A_do's FREQUENCY SET matches the set
% declared by do_harm - that is what forgetting to rebuild A_do breaks. Compare
% the whole set, not one number.
C.A_do_ok = true;  C.A_do_f = [];  C.A_do_want = [];
if evalin('base', 'exist(''A_do'',''var'')')
    C.A_do_f = uniq_round(evalin('base', 'abs(imag(eig(A_do)))'));
    if evalin('base', 'exist(''do_harm'',''var'')')
        h = evalin('base', 'do_harm(:)');
        C.A_do_want = uniq_round(C.payload_sigma * h);
    else
        % With no do_harm, assume a single fundamental block - and SAY that
        % this is an assumption rather than a reading.
        C.A_do_want = uniq_round(C.payload_sigma);
    end
    C.A_do_ok = numel(C.A_do_f) == numel(C.A_do_want) && ...
                all(abs(C.A_do_f - C.A_do_want) < 1e-9);
end
if opt.Assert
    assert(C.A_do_ok, 'op_condition:A_do', '%s', sprintf( ...
        ['A_do has frequency set [%s] rad/s, but payload_sigma = %.4f with\n' ...
         'do_harm requires [%s].\n' ...
         'The DO internal model is at the wrong frequency -> DO estimates ~0\n' ...
         'and MOBADC degrades to Classical WITH NO WARNING. Rebuild:\n' ...
         '    [A_do, B_do, l_gain, do_info] = build_do_matrices(payload_sigma, do_harm, l_axis);\n' ...
         '    do_w = [do_info.do_w_axis{1}(:); do_info.do_w_axis{2}(:); do_info.do_w_axis{3}(:)];\n' ...
         '    n_state_axis = do_info.n_ax_state(:);'], ...
        num2str(C.A_do_f(:)', '%.4f '), C.payload_sigma, ...
        num2str(C.A_do_want(:)', '%.4f ')));
end
if ~C.sigma_matches_traj
    % The A4 series breaks this assumption DELIBERATELY and by registration, so
    % it must not be warned about as if it were an accident. Every OTHER
    % configuration still warns.
    if any(strcmp(C.name, {'A4 detune low','A4 detune high'}))
        if ~opt.Quiet
            fprintf(['    [A4] payload_sigma = %.4f DIFFERS from w_traj = %.4f -\n' ...
                     '         deliberate, registered in docs/REGISTER_TAU.md §A4.2.\n'], ...
                    C.payload_sigma, C.w_traj);
        end
    else
        warning('op_condition:sigma', ...
            'payload_sigma = %.4f differs from w_traj = %.4f - the load is NOT swinging at the orbit frequency.', ...
            C.payload_sigma, C.w_traj);
    end
end

C.tag = sprintf(['%s | R %.2f m, v %.2f m/s, sigma %.4f rad/s (T %.2f s) | ' ...
                 'A_payload %.2f N, wind %.2f N'], ...
                C.name, C.R_traj, C.V_traj, C.payload_sigma, C.T_orbit, ...
                C.payload_amp, C.wind_amp);

if ~opt.Quiet
    fprintf('  operating condition: %s\n', C.tag);
    if isfield(C,'payload_model')
        if C.payload_model > 0.5, s = 'physical PENDULUM'; else, s = 'sinusoidal'; end
        fprintf('    payload disturbance %s | tau_pred %g s\n', s, getdef(C,'tau_pred',NaN));
    end
end
end

%% =====================================================================
function b = near(a, r)
b = abs(a - r) < 1e-6;
end
function v = getdef(S, f, d)
if isfield(S, f), v = S.(f); else, v = d; end
end

function v = uniq_round(x)
%UNIQ_ROUND  The frequency set, rounded to 1e-9 before taking unique values.
%  Without rounding, two eigenvalues of the same block that differ in the last
%  digit become TWO frequencies, and the set comparison reports a spurious
%  mismatch.
v = sort(unique(round(abs(x(:)) * 1e9) / 1e9));
end
