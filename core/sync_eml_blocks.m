function varargout = sync_eml_blocks(varargin)
%SYNC_EML_BLOCKS  Keep the MATLAB Function block code inside the .slx in step
%                 with simulink_blocks/.
%
%   sync_eml_blocks                      % CHECK only, change nothing (default)
%   sync_eml_blocks('Apply', true)       % write simulink_blocks/*.m INTO the model
%   sync_eml_blocks('Export', true)      % write the model's code OUT to simulink_blocks/
%   ok = sync_eml_blocks(...)            % true if every block matches
%
%  ------------------------------------------------------------------
%  WHY THIS FILE EXISTS
%  ------------------------------------------------------------------
%  The code that actually runs lives inside 'baseline1.slx' - a binary file. The
%  .m files in simulink_blocks/ are only a readable copy. Nothing forces the two
%  to agree: edit a block in Simulink and the .m file does not change; edit the
%  .m file and the model does not change. The two WILL drift apart, and they
%  will do it silently.
%
%  That is exactly what once happened in this repository:
%  build_payload_pendulum.m read simulink_blocks/payload_pendulum_derivative.m,
%  but that directory had never been committed. The pendulum code existed only
%  inside the .slx, and the comment right next to it claiming "a single source
%  of truth" said the opposite of the truth.
%
%  Running 'sync_eml_blocks' before every measurement is enough to stop that
%  recurring. In the default mode it does not change a single bit of the model.
%
%  ------------------------------------------------------------------
%  THREE MODES
%  ------------------------------------------------------------------
%    (default)   Check. Read the code out of the model, compare it against the
%                .m files, print which blocks differ. CHANGES NOTHING. This is
%                the mode used by the regression gate.
%    'Apply'     .m file -> model. Use this when the algorithm was changed by
%                editing the .m file (the preferred direction: git diff can read
%                it).
%    'Export'    model -> .m file. Use this after accidentally editing inside
%                Simulink, to get that change into git.
%
%  After 'Apply' you must call save_system yourself - this file never overwrites
%  the .slx on its own.

opt = parse_opts(varargin);
assert(~(opt.Apply && opt.Export), ...
       'Apply and Export are mutually exclusive: pick one direction.');

mdl  = 'baseline1';
here = repo_root();
src  = fullfile(here, 'simulink_blocks');
require_block_sources(here, {});     % an explicit message if the directory was never pulled

if ~bdIsLoaded(mdl), load_system(mdl); end

% find(sfroot,...) returns the charts of EVERY loaded model, so they have to be
% filtered by path. arrayfun rather than get(charts,'Path'): for one element get
% returns a char, for several it returns a cell - written this way both cases
% give a logical array.
charts = find(sfroot, '-isa', 'Stateflow.EMChart');
if ~isempty(charts)
    keep = arrayfun(@(c) strncmp(c.Path, [mdl '/'], numel(mdl)+1), charts);
    charts = charts(keep);
end
assert(~isempty(charts), 'No MATLAB Function block was found in %s', mdl);

n_ok = 0; n_diff = 0; n_missing = 0; n_done = 0;
diffs = {};

for i = 1:numel(charts)
    ch    = charts(i);
    inmdl = ch.Script;
    fname = eml_function_name(inmdl);
    if isempty(fname)
        warning('sync_eml_blocks:noName', ...
                'Could not read the function name at %s - skipped.', ch.Path);
        continue
    end
    fpath = fullfile(src, [fname '.m']);

    if opt.Export
        write_text(fpath, inmdl);
        fprintf('  [EXPORT ] %-32s -> simulink_blocks/%s.m\n', fname, fname);
        n_done = n_done + 1;
        continue
    end

    if exist(fpath, 'file') ~= 2
        fprintf('  [MISSING] %-32s no simulink_blocks/%s.m\n', fname, fname);
        n_missing = n_missing + 1;
        continue
    end

    ondisk = fileread(fpath);
    if same_code(inmdl, ondisk)
        n_ok = n_ok + 1;
        continue
    end

    if opt.Apply
        ch.Script = ondisk;
        fprintf('  [APPLY  ] %-32s <- simulink_blocks/%s.m\n', fname, fname);
        n_done = n_done + 1;
    else
        n_diff = n_diff + 1;
        diffs{end+1} = fname; %#ok<AGROW>
        fprintf('  [DIFFER ] %-32s (model %d lines / file %d lines)\n', ...
                fname, count_lines(inmdl), count_lines(ondisk));
        show_first_diff(inmdl, ondisk);
    end
end

fprintf('\n');
if opt.Export
    fprintf('Exported %d block(s) to simulink_blocks/.\n', n_done);
    ok = true;
elseif opt.Apply
    fprintf('Applied %d block(s) to the model; %d already matched.\n', n_done, n_ok);
    if n_done > 0
        fprintf('*** Run save_system(''%s'') to write the .slx back. ***\n', mdl);
    end
    ok = (n_missing == 0);
else
    fprintf('Match %d | Differ %d | Missing .m file %d\n', n_ok, n_diff, n_missing);
    ok = (n_diff == 0 && n_missing == 0);
    if ~ok
        fprintf(['\nThe model and simulink_blocks/ are OUT OF SYNC. Before taking any\n' ...
                 'measurement, pick a direction:\n' ...
                 '  sync_eml_blocks(''Apply'',  true)   %% the .m file is the correct one\n' ...
                 '  sync_eml_blocks(''Export'', true)   %% the model is the correct one\n']);
    end
end

if nargout > 0, varargout{1} = ok; end
end


%% =====================================================================
function name = eml_function_name(code)
% MATLAB's '...' line continuation can split the output list from the
% function name across a real newline (e.g. simulink_blocks/
% im_est_estimator.m and im_est_do_rebuild.m, both multi-line
% signatures) - collapse it to a single space ONLY for this name
% -detection pass; the regex must not otherwise cross a genuine
% newline, or it would run into the following help-text comment.
joined = regexprep(code, '\.\.\.\s*\n\s*', ' ');
tok = regexp(joined, '^\s*function\s+[^=\n]*=\s*(\w+)\s*\(', 'tokens', 'once');
if isempty(tok)
    tok = regexp(joined, '^\s*function\s+(\w+)\s*\(', 'tokens', 'once');
end
if isempty(tok), name = ''; else, name = tok{1}; end
end

function tf = same_code(a, b)
% Compare while ignoring line-ending and trailing-whitespace differences - those
% two do change on a round trip through Simulink and through git, and neither
% changes behaviour. Everything else, COMMENTS INCLUDED, is compared verbatim.
tf = isequal(norm_code(a), norm_code(b));
end

function c = norm_code(s)
s = strrep(s, sprintf('\r\n'), newline);
s = strrep(s, sprintf('\r'),   newline);
c = cellfun(@(x) deblank(x), strsplit(s, newline), 'UniformOutput', false);
while ~isempty(c) && isempty(c{end}), c(end) = []; end
end

function n = count_lines(s)
n = numel(norm_code(s));
end

function show_first_diff(a, b)
ca = norm_code(a); cb = norm_code(b);
for k = 1:max(numel(ca), numel(cb))
    la = ''; lb = '';
    if k <= numel(ca), la = ca{k}; end
    if k <= numel(cb), lb = cb{k}; end
    if ~strcmp(la, lb)
        fprintf('           line %d:\n', k);
        fprintf('             model : %s\n', trunc(la));
        fprintf('             file  : %s\n', trunc(lb));
        return
    end
end
end

function s = trunc(s)
if numel(s) > 72, s = [s(1:69) '...']; end
if isempty(s), s = '(empty)'; end
end

function write_text(path, txt)
fid = fopen(path, 'w');
assert(fid > 0, 'Could not write %s', path);
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s', txt);
if ~endsWith(txt, newline), fprintf(fid, '\n'); end
end

function opt = parse_opts(args)
opt = struct('Apply', false, 'Export', false);
for i = 1:2:numel(args)
    name = validatestring(args{i}, fieldnames(opt));
    opt.(name) = args{i+1};
end
end
