function paper_style(f, varargin)
%PAPER_STYLE  Apply ONE typeface to a whole figure, immediately before saving.
%
%   paper_style(f)
%   paper_style(f, 'Sans', true)      % if the journal requires sans-serif figures
%
%  ======================================================================
%  WHY IT IS CALLED AT THE END, NOT SET ON EACH OBJECT AS IT IS CREATED
%  ======================================================================
%  A MATLAB figure carries text in many places: axis labels, tick numbers,
%  titles, legends, every scattered text() call, and colorbar labels too.
%  Setting 'FontName' at each site means setting it in twenty places, and
%  MISSING ONE - usually a text() added later - leaves that figure with two
%  typefaces and nothing reporting it.
%
%  A single sweep at the end cannot miss any: it takes EVERY child of the
%  figure that has a FontName property. The cost is having to REMEMBER TO CALL
%  IT - so it is called on the line above the save, and nowhere else.
%
%  The function does NOT set font SIZES. Size is a per-figure decision (axis
%  labels smaller than the title, annotations smaller than labels); the face has
%  to be uniform. Merging the two into one function would give every figure the
%  same size, which is an ugly figure.

opt = struct('Sans', false);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
if nargin < 1 || isempty(f), f = gcf; end
fn = paper_font('Sans', opt.Sans);

h = findall(f, '-property', 'FontName');
for k = 1:numel(h)
    try, set(h(k), 'FontName', fn); catch, end
end

% Labels using TeX (MATLAB's default) do NOT follow FontName for the parts
% inside $...$ or after '\\'. This paper uses no formulae in any figure label,
% so nothing further is done - but if one is ever added, that part will not
% change and this is where to look.
end
