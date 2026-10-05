function [fn, mono] = paper_font(varargin)
%PAPER_FONT  ONE typeface for EVERY figure and EVERY table in the paper.
%
%   fn         = paper_font              % the main face (serif)
%   [fn, mono] = paper_font              % plus a monospaced face for numbers
%   fn         = paper_font('Sans', true)
%
%  ======================================================================
%  WHY SOMETHING THIS SMALL NEEDS A FUNCTION
%  ======================================================================
%  Two reasons, both of which happened rather than being anticipated:
%
%  (1) TWO TYPEFACES IN ONE PAPER. fig_table1 set 'Times New Roman'; the nine
%      other figures set nothing and therefore took MATLAB's default
%      Helvetica. A reader who cannot name the problem still sees a paper that
%      "does not match", and a copy editor names it immediately.
%
%  (2) SILENT FONT SUBSTITUTION. MATLAB does NOT report an error when a font
%      is absent - it quietly substitutes another. So a figure exported on a
%      machine with Times and one exported on a machine without it come out in
%      two different faces, and no log line says so. This function ASKS the
%      system what is actually installed, then reports which one it chose.
%
%  The list is ordered by how common each face is on Windows/macOS/Linux
%  machines running MATLAB. Serif first, because engineering-journal tables are
%  almost always serif.

opt = struct('Sans', false, 'Quiet', true);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end

if opt.Sans
    want = {'Helvetica','Arial','Liberation Sans','DejaVu Sans','Nimbus Sans'};
    fb   = 'Helvetica';
else
    want = {'Times New Roman','Times','Liberation Serif','Nimbus Roman', ...
            'DejaVu Serif','Georgia'};
    fb   = 'Times';
end
wantm = {'Courier New','Courier','Liberation Mono','DejaVu Sans Mono','Consolas'};

have = {};
try
    have = listfonts;                    % can be slow on the first call, so call it once
catch
    have = {};
end

fn   = pick(want,  have, fb);
mono = pick(wantm, have, 'Courier');

if ~opt.Quiet
    fprintf('  paper_font: %s / %s\n', fn, mono);
end
end

function f = pick(want, have, fb)
%PICK  The first candidate ACTUALLY present on this machine. If the font list
%  cannot be read (listfonts fails in some headless configurations), take the
%  first candidate and let MATLAB substitute - nothing can be verified then, but
%  at least every figure asks for THE SAME name, so they are all substituted the
%  same way.
f = want{1};
if isempty(have), return; end
for k = 1:numel(want)
    if any(strcmpi(have, want{k})), f = want{k}; return; end
end
f = fb;
end
