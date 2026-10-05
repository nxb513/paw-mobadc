function p = repo_root()
%REPO_ROOT  The top directory of this repository.
%
%   p = repo_root
%
%  ======================================================================
%  WHY THIS EXISTS
%  ======================================================================
%  Every script used to open with
%
%      here = fileparts(mfilename('fullpath')); if isempty(here), here = pwd; end
%
%  which gives the directory OF THAT FILE. That was the repository root only
%  because every file sat in the root. The moment the sources are sorted into
%  core/, experiments/, figures/ and so on, `here` silently becomes the
%  subfolder - and every fullfile(here, 'something.mat') starts looking in the
%  wrong place. The failure is silent: load() reports a missing file, which
%  reads like missing data rather than a broken path.
%
%  This file is the anchor. It lives in the root and nowhere else, so the
%  directory it reports IS the root, whatever folder the caller sits in.
%
%  ======================================================================
%  DO NOT MOVE THIS FILE
%  ======================================================================
%  Moving it into a subfolder would make it return that subfolder, and every
%  path in the repository would shift with it, quietly. It has to stay in the
%  root, which is why it carries no other purpose worth relocating it for.
p = fileparts(mfilename('fullpath'));
if isempty(p), p = pwd; end
end
