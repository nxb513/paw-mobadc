function added = setup_path(varargin)
%SETUP_PATH  Put this repository's source folders on the MATLAB path.
%
%   setup_path                  % idempotent; safe to call from anywhere
%   added = setup_path
%   setup_path('Force', true)   % re-add even if it looks done
%
%  ======================================================================
%  WHY THIS EXISTS
%  ======================================================================
%  The sources are sorted into subfolders (core/, build/, experiments/,
%  verification/, analysis/, figures/, simulink_blocks/). MATLAB does not look
%  inside subfolders of the current directory, so without this the scripts
%  cannot see one another.
%
%  Named folders, not genpath(root). genpath would also sweep in docs/,
%  python/ and any scratch directory that happens to be lying around, and a
%  path entry for a folder full of Markdown is noise at best. More to the
%  point, an explicit list is a statement of what the code IS: a folder that
%  does not appear here does not hold MATLAB sources, and that is checkable.
%
%  Idempotent because it is called at the top of nearly every script. The
%  check is a cheap string search, so calling it in a loop costs nothing.

opt = struct('Force', false, 'Quiet', true);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

root = repo_root();

% The MATLAB source folders, in the order a reader would meet them.
% A folder listed here but absent on disk is skipped, not an error: the list
% has to keep working during a reorganisation, when some folders exist and
% others do not yet.
FOLDERS = {'core', 'build', 'simulink_blocks', 'experiments', ...
           'verification', 'analysis', 'figures', 'figures/p2'};

added = {};
p = [pathsep path pathsep];
for i = 1:numel(FOLDERS)
    d = fullfile(root, FOLDERS{i});
    if exist(d, 'dir') ~= 7, continue; end
    if opt.Force || isempty(strfind(p, [pathsep d pathsep])) %#ok<STREMP>
        addpath(d);
        added{end+1} = FOLDERS{i};  %#ok<AGROW>
    end
end

% The root itself holds repo_root, setup_path, the model and the result files.
if opt.Force || isempty(strfind(p, [pathsep root pathsep])) %#ok<STREMP>
    addpath(root);
    added{end+1} = '(root)';
end

if ~opt.Quiet && ~isempty(added)
    fprintf('  setup_path: added %s\n', strjoin(added, ', '));
end
end
