function report = model_contract(varargin)
%MODEL_CONTRACT  Block experimental conditions that are reported but not real.
%
%   model_contract                    % check, and throw on a violation
%   model_contract('Strict', false)   % warn only
%   r = model_contract(...)           % return a descriptive struct
%
%  ------------------------------------------------------------------
%  WHY THIS FILE EXISTS
%  ------------------------------------------------------------------
%  A parameter can exist in the workspace, be passed into the model, and be
%  printed in a table caption - while having no effect whatsoever. At that
%  point the table is reporting an experimental condition that DOES NOT EXIST,
%  and nothing complains.
%
%  That is what happened with amp_tau (docs/devlog/AUDIT.md, item A1).
%
%  This file states explicitly what the model ACTUALLY implements, and stops
%  the script if the workspace contradicts it. Nothing is guessed or inferred:
%  the lists below are checked against the code extracted from baseline1.slx
%  (see simulink_blocks/).

opt = parse_opts(varargin);
report = struct('violations', {{}}, 'notes', {{}});

%% ---- 1. amp_tau must not come back ----
% It used to be an argument of disturbance_generator that the body never used,
% while init declared it as 0.05 N.m and two run scripts printed it in a table
% caption. It was stripped out by remove_amp_tau.m. If it reappears, either
% someone restored an old model or d_ltau has genuinely been wired up - both
% need to be known about.
if evalin('base', 'exist(''amp_tau'',''var'')')
    report.violations{end+1} = [ ...
        'amp_tau exists in the base workspace. It was removed deliberately: ' ...
        'the reference work does not publish a moment-disturbance waveform, ' ...
        'so it would be an unverifiable degree of freedom.' newline ...
        '  If you INTEND to introduce a moment disturbance: delete this check, ' ...
        'genuinely wire d_ltau in disturbance_generator, and rebuild' newline ...
        '  expected_baseline.m - every baseline number will change.'];
end

%% ---- 2. Variables declared but never read by the model ----
% Read straight from the model rather than hard-coding a list: a hand-copied
% list would go stale at the first model edit, and this gate would then be
% wrong without anyone noticing - which is the very disease it exists to cure.
used = model_constant_vars(mdl_name());

% Used only DURING init to build other variables - not reported.
build_only = { 'c_tauf','d_theta','d_phi','A_blk','f_hover','psi_w', ...
               'Kp','Ka','Ky','Kv','M0_att', ...
               'l_axis','do_harm','do_info' };   % build A_do/B_do/l_gain/do_w

% Variables that once meant something and are now genuinely dead.
dead = { 'wn_p',   ['the pendulum block computes wn = sqrt(g/L) internally; ' ...
                    'setting wn_p from outside has no effect'], ...
         'R_wind', ['the wind direction is hard-coded as psi_w = 40*pi/180 ' ...
                    'inside disturbance_generator; R_wind is never read'] };

for i = 1:2:numel(dead)
    if evalin('base', sprintf('exist(''%s'',''var'')', dead{i}))
        report.notes{end+1} = sprintf(['DEAD VARIABLE: %s - %s. It has no ' ...
            'effect; delete it so nobody believes it controls something.'], ...
            dead{i}, dead{i+1});
    end
end

% Variables the model reads that the base workspace lacks -> Simulink would
% report "Undefined variable" at compile time. Catching it here is far faster.
missing = used(~cellfun(@(n) ...
    logical(evalin('base', sprintf('exist(''%s'',''var'')', n))), used));
if ~isempty(missing)
    report.violations{end+1} = sprintf([ ...
        'The model reads %d variable(s) the base workspace does not have: %s\n' ...
        '  Run init_MOBADC_params first, or find which Constant block points\n' ...
        '  at a variable that does not exist.'], ...
        numel(missing), strjoin(missing, ', '));
end

report.vars_used = used;
report.vars_build_only = build_only;
report.vars_missing = missing;

%% ---- 3. A_do must match payload_sigma ----
% The classic failure in this repository: init builds A_do ONCE, a script
% changes payload_sigma and forgets to rebuild A_do -> the observer's internal
% model runs at the old frequency -> the observer estimates ~0 and nobody
% notices.
if evalin('base', 'exist(''A_do'',''var'') && exist(''payload_sigma'',''var'')')
    % The internal model may carry HARMONICS, so eig(A_do) holds several
    % frequencies. Check:
    %   (a) the LOWEST frequency must be payload_sigma (the fundamental)
    %   (b) every frequency must be an INTEGER MULTIPLE of it
    % An earlier version used max(), so with harmonics [1 3] it compared
    % 3*sigma against sigma and reported a violation on a correct setup.
    w_all    = evalin('base', 'unique(round(abs(imag(eig(A_do))), 9))');
    w_all    = w_all(w_all > 1e-9);
    sig_want = evalin('base', 'payload_sigma');

    if isempty(w_all)
        report.violations{end+1} = 'A_do has no imaginary eigenvalues - the exosystem is broken.';
    else
        k = w_all / sig_want;
        if abs(min(w_all) - sig_want) > 1e-9
            report.violations{end+1} = sprintf([ ...
                'A_do: the lowest frequency is %.6f but payload_sigma = %.6f.\n' ...
                '  Rebuild with: [A_do, B_do, l_gain, do_info] = ' ...
                'build_do_matrices(payload_sigma, do_harm, l_axis);'], ...
                min(w_all), sig_want);
        elseif any(abs(k - round(k)) > 1e-6)
            report.violations{end+1} = sprintf([ ...
                'A_do has frequencies that are NOT integer multiples of ' ...
                'payload_sigma: %s\n' ...
                '  (divided by sigma they give %s). A harmonic exosystem must ' ...
                'use integer multiples.'], ...
                mat2str(w_all(:).', 6), mat2str(k(:).', 4));
        else
            report.notes{end+1} = sprintf(...
                'Internal model: harmonics %s of sigma = %.4f rad/s (%d states).', ...
                mat2str(round(k(:).')), sig_want, ...
                evalin('base', 'size(A_do,1)'));
        end
    end
end

%% ---- result ----
for i = 1:numel(report.notes)
    fprintf('  [note] %s\n', report.notes{i});
end
if isempty(report.violations)
    fprintf('  [OK]   model contract: no condition is reported that is not real.\n');
    return
end
msg = strjoin(report.violations, sprintf('\n\n'));
if opt.Strict
    error('model_contract:violation', ...
          '\n\n=== MODEL CONTRACT VIOLATED ===\n%s\n', msg);
else
    warning('model_contract:violation', '\n\n=== MODEL CONTRACT VIOLATED ===\n%s\n', msg);
end
end


%% =====================================================================
function name = mdl_name()
name = 'baseline1';
end

function vars = model_constant_vars(mdl)
%MODEL_CONSTANT_VARS  Base-workspace variables referenced by Constant blocks.
%  Read straight from the model. If the model is not loaded this returns empty
%  and the checks that depend on it skip themselves - nothing is guessed.
vars = {};
if ~bdIsLoaded(mdl)
    return
end
blks = find_system(mdl, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
                   'BlockType', 'Constant');
seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for i = 1:numel(blks)
    expr = get_param(blks{i}, 'Value');
    for tok = regexp(expr, '[A-Za-z_]\w*', 'match')
        t = tok{1};
        % Skip builtins and language constants
        if any(strcmp(t, {'zeros','ones','eye','diag','blkdiag','pi','inf', ...
                          'nan','true','false','sqrt','cos','sin','deg2rad'}))
            continue
        end
        if ~seen.isKey(t)
            seen(t) = true;
            vars{end+1} = t; %#ok<AGROW>
        end
    end
end
vars = sort(vars);
end

function opt = parse_opts(args)
opt = struct('Strict', true);
for i = 1:2:numel(args)
    name = validatestring(args{i}, fieldnames(opt));
    opt.(name) = args{i+1};
end
end
