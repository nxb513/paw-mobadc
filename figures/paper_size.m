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
%    'single'  9.0 cm    one column
%    'oneandhalf' 14.0 cm
%    'double' 19.0 cm    full width, across both columns
%
%  These are the Elsevier artwork widths, which is the family this journal
%  belongs to. They were NOT read out of Control Engineering Practice's own
%  guide for authors - that page could not be retrieved, it serves a CAPTCHA to
%  anything automated. If the journal states a different width, change it HERE
%  and every figure follows; that is the whole reason this is a function and
%  not three numbers copied into three scripts.
%
%  A two-panel figure needs the full width. A single panel fits one column.

WIDTH = struct('single', 9.0, 'oneandhalf', 14.0, 'double', 19.0);

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
