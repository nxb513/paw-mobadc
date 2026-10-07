function paper_size(f, w, h)
%PAPER_SIZE  Give a figure its PHYSICAL size, so the exported file needs no scaling.
%
%   paper_size(f, 'double', 7.5)   % full width, 7.5 cm tall
%   paper_size(f, 'single', 6.0)
%   paper_size(f, 19.0, 7.5)       % explicit width in cm
%
%  ======================================================================
%  THE PROBLEM THIS SOLVES, MEASURED
%  ======================================================================
%  Every figure here was created with Position = [80 80 980 420]. Those are
%  SCREEN PIXELS, and with PaperPositionMode 'auto' the exported PDF comes out
%  980 x 420 POINTS - that is 346 x 148 mm, about the width of two A4 pages.
%
%  The journal then scales it down to the column width it actually prints at,
%  and every font goes down with it:
%
%      exported at 346 mm -> printed at 190 mm   x0.55   a 9 pt tick -> 4.9 pt
%      exported at 346 mm -> printed at  90 mm   x0.26   a 9 pt tick -> 2.3 pt
%
%  Typical journal minimum is about 7 pt AFTER scaling. So the figures were not
%  badly designed - they were drawn at the wrong size and then shrunk below
%  legibility, and no amount of adjusting individual labels fixes that.
%
%  Set the physical size instead and the scale factor becomes 1: the font size
%  written in the code is the font size on the page.
%
%  ======================================================================
%  THE WIDTHS
%  ======================================================================
%    'single'      8.4 cm   one column
%    'oneandhalf' 12.9 cm
%    'double'     17.4 cm   full width, across both columns
%
%  These are the Springer artwork widths of the target journal, International
%  Journal of Dynamics and Control (2026-10-07: 39, 84, 129 or 174 mm wide, at
%  most 234 mm high; until then the Elsevier widths 9 / 14 / 19 cm were used).
%  If the journal changes, change them HERE and every figure follows; that is
%  the whole reason this is a function and not three numbers copied into three
%  scripts.
%
%  A two-panel figure needs the full width. A single panel fits one column.

WIDTH = struct('single', 8.4, 'oneandhalf', 12.9, 'double', 17.4);

if nargin < 1 || isempty(f), f = gcf; end
if nargin < 2 || isempty(w), w = 'double'; end
if ischar(w) || isstring(w)
    key = validatestring(char(w), fieldnames(WIDTH));
    w = WIDTH.(key);
end
if nargin < 3 || isempty(h), h = w * 0.42; end

assert(w > 0 && h > 0, 'paper_size: width and height must be positive [cm].');

set(f, 'Units', 'centimeters');
p = get(f, 'Position');
set(f, 'Position', [p(1) p(2) w h]);

% PaperPosition must be set together with PaperPositionMode 'manual'. With
% 'auto' MATLAB ignores PaperSize and prints at the on-screen size again, which
% is the behaviour this function exists to stop.
set(f, 'PaperUnits', 'centimeters', ...
       'PaperSize', [w h], ...
       'PaperPosition', [0 0 w h], ...
       'PaperPositionMode', 'manual');
end
