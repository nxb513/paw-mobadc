function [A_do, B_do, l_gain, info] = build_do_matrices(varargin)
%BUILD_DO_MATRICES  The DO matrices for a per-axis multi-harmonic internal model.
%
%   [A_do, B_do, l_gain] = build_do_matrices(sigma, harm, l_axis)   % old form
%   [A_do, B_do, l_gain] = build_do_matrices(do_w_axis, l_axis)     % new form
%
%   sigma      the exosystem's fundamental frequency [rad/s]         (old form)
%   harm       the vector of harmonic multiples, e.g. [1] (Guo's      (old form)
%              original) or [1 3]
%   do_w_axis  cell {wx, wy, wz}: EACH AXIS'S OWN frequency vector,   (new form,
%              in rad/s - 0 = the DC mode (1 state), w > 0 = a 2x2     Part 3.3)
%              block. Axes need not have the same length or content.
%   l_axis     the per-axis l gain, [lx ly lz]. Guo: [0.10 0.08 0.10]
%
%  ------------------------------------------------------------------
%  PART 3.3 (TEST_PLAN_PROMPT.md): WHY A SECOND CALLING FORM, NOT A
%  REPLACEMENT
%  ------------------------------------------------------------------
%  Every axis used to be forced through the SAME (sigma, harm) pair - one
%  shared frequency set for x, y and z. That is exactly wrong for a
%  trajectory whose axes are NOT symmetric: figure-8's y-axis runs at
%  TWICE its x-axis frequency (docs/REGISTER_C.md's IM-oracle table), and
%  hover/square have no orbital sigma to speak of at all - their real
%  frequency is the pendulum's own wn_p = sqrt(g/L). do_w_axis lets each
%  axis declare its own set directly, in absolute rad/s, instead of
%  inheriting one shared harmonic multiplier.
%
%  The old 3-argument form is NOT retired: every existing call site
%  (op_set.m, init_MOBADC_params.m, pa_configs.m and every experiments/*.m
%  script that runs the main grid - none of which use do_w_axis) keeps
%  calling it exactly as before, and Checkpoint 3.3's own first bullet
%  requires it: do_w_axis = {[0 sigma],[0 sigma],[0 sigma]} must reproduce
%  circle's already-published L3 = 0.01412 bit for bit. That is not
%  asserted by inspection - it is enforced by construction: the old form
%  is converted internally into exactly that do_w_axis cell (do_w_axis =
%  {harm*sigma, harm*sigma, harm*sigma}, repeated per axis) and BOTH forms
%  then run through the identical per-axis loop below. There is no second
%  copy of the matrix-building logic to keep in sync by hand - one source,
%  the same discipline core/pa_cell.m's own header states for exactly this
%  situation.
%
%  ------------------------------------------------------------------
%  WHY THE THIRD HARMONIC IS NEEDED (unchanged from the original form)
%  ------------------------------------------------------------------
%  From the residual spectrum (docs/devlog/AUDIT.md, section F): after the DO
%  cancels the payload disturbance, what remains is ONE LINE at 3*sigma holding
%  ~90% of the energy. Measured at two different tether lengths and the line
%  DOES NOT MOVE -> it is a multiple of the ORBIT frequency, not of the
%  pendulum's natural frequency.
%
%  It arises from the pendulum's own output equation:
%       T = m_p*(g*cos(th) + L*thd^2 + a*sin(th))  -> cos(th), thd^2 give 2*sigma
%       d = T*sin(th)                              -> (DC + 2*sigma) x sigma
%                                                     -> sigma and 3*sigma
%  So adding one 2x2 block at 3*sigma to the exosystem is enough. Adding the
%  pendulum's natural frequency sqrt(g/L) is USELESS for a trajectory whose
%  forcing already sits at 3*sigma near that frequency - see docs/REGISTER_C.md
%  Section 2 for a case where it very nearly does, and Part 3.3's IM-oracle
%  table for the trajectories where wn_p is the RIGHT frequency instead
%  (hover, square: no orbital sigma at all, so wn_p is what is actually
%  driving the pendulum).
%
%  ------------------------------------------------------------------
%  NO FREE PARAMETERS
%  ------------------------------------------------------------------
%  The new block's l gain takes EXACTLY the value Guo uses for the old one:
%  l_axis(i) for every state of axis i. This extends an existing gain structure
%  rather than being a new design, so there is nothing to "tune".
%
%  ------------------------------------------------------------------
%  STATE ORDER
%  ------------------------------------------------------------------
%  By AXIS first, then by FREQUENCY (ascending as given): each axis's own
%  states are contiguous, and within an axis each frequency contributes 1
%  state (DC) or 2 (a harmonic block), in the order do_w_axis{i} lists
%  them. When every axis is given the SAME frequency vector, of the SAME
%  length, this is EXACTLY the old state order - harm = [1] (or any harm)
%  applied uniformly to x/y/z reproduces the original matrices element for
%  element, which is why the baseline reproduction gate needs no special
%  case even under this rewrite.
%
%  info.n_state    the number of states
%  info.poles      the error dynamics' poles
%  info.n_ax_state 1x3, states per axis (equal for every axis under the old
%                  form; may differ under the new one)
%  info.do_w_axis  the per-axis frequency cell actually used (both forms)
%  info.harm, info.w   old-form-only fields, present only when called with
%                  (sigma, harm, l_axis), for continuity with existing prints

if nargin >= 1 && iscell(varargin{1})
    % ---- NEW FORM: build_do_matrices(do_w_axis, l_axis) ----
    do_w_axis = varargin{1};
    l_axis = [0.10 0.08 0.10];
    if nargin >= 2 && ~isempty(varargin{2}), l_axis = varargin{2}; end
    old_form = false;
else
    % ---- OLD FORM: build_do_matrices(sigma, harm, l_axis) ----
    assert(nargin >= 2, 'build_do_matrices: (sigma, harm) or (do_w_axis, l_axis) required.');
    sigma = varargin{1};
    harm  = varargin{2}(:).';
    l_axis = [0.10 0.08 0.10];
    if nargin >= 3 && ~isempty(varargin{3}), l_axis = varargin{3}; end
    do_w_axis = {harm*sigma, harm*sigma, harm*sigma};
    old_form = true;
end

n_ax = 3;
assert(numel(do_w_axis) == n_ax, ...
    'build_do_matrices: do_w_axis must be a 1x3 cell {wx, wy, wz}.');
assert(numel(l_axis) == n_ax, 'l_axis must have 3 elements');

% ------------------------------------------------------------------
% HARMONIC ZERO = THE DC MODE. Why it has to exist. (unchanged rationale)
% ------------------------------------------------------------------
% §0.68 measured it: 97.8% of the payload channel's model-error energy is a
% CONSTANT FORCE, not broadband noise. Guo's exosystem uses pure multiples of
% a frequency, so it CANNOT represent a constant: a 2x2 block [0 w; -w 0] has
% poles at +-j*w, never at 0. The DC mode is ONE state per axis: xi_dot = 0,
% d = xi. No free parameter - the gain is l_axis(i) like every other state.
%
% ------------------------------------------------------------------
% BLOCKS OF DIFFERENT SIZES, NOW ALSO ACROSS AXES
% ------------------------------------------------------------------
% Each axis computes its OWN state count from its OWN frequency vector - the
% generalisation the old code's shared n_as could not express. off{i} is the
% offset TABLE within axis i; axis_base is the cumulative offset ACROSS axes,
% replacing the old (i-1)*n_as (which assumed every axis had the same n_as).
n_as = zeros(1, n_ax);
off  = cell(1, n_ax);
sz   = cell(1, n_ax);
for i = 1:n_ax
    w_i = do_w_axis{i}(:).';
    assert(all(w_i >= 0), ...
        'build_do_matrices: axis %d has a negative frequency (0 = DC mode).', i);
    assert(numel(unique(w_i)) == numel(w_i), ...
        'build_do_matrices: axis %d has a repeated frequency.', i);
    sz{i}   = 2 - (w_i == 0);          % 1 state for DC, 2 for a harmonic
    off{i}  = [0 cumsum(sz{i})];
    n_as(i) = off{i}(end);
end
axis_base = [0 cumsum(n_as)];
n = axis_base(end);

A_do   = zeros(n, n);
B_do   = zeros(n_ax, n);
l_gain = zeros(n, 2*n_ax);      % acts on [gamma; nu]; only the nu columns are nonzero

for i = 1:n_ax
    w_i = do_w_axis{i}(:).';
    for k = 1:numel(w_i)
        w = w_i(k);
        b = axis_base(i) + off{i}(k);       % the block's base index
        if sz{i}(k) == 1                    % the DC mode: xi_dot = 0
            A_do(b+1, b+1) = 0;             % (written out for clarity, not redundancy)
            B_do(i, b+1) = 1;
            l_gain(b+1, n_ax+i) = l_axis(i);
        else
            A_do(b+1:b+2, b+1:b+2) = [0 w; -w 0];
            B_do(i, b+1) = 1;               % d_mf(i) = the sum of the odd components
            % Gain: Guo's value for this axis, applied to EVERY state of it.
            l_gain(b+1, n_ax+i) = l_axis(i);
            l_gain(b+2, n_ax+i) = l_axis(i);
        end
    end
end

%% ---- Check that the error dynamics are stable ---- (unchanged)
m_uav = 1.121;
G_do  = (1/m_uav)*[zeros(n_ax); eye(n_ax)];
Acl   = A_do - l_gain*G_do*B_do;
ev    = eig(Acl);

assert(max(real(ev)) < 0, ...
    ['The DO error dynamics are NOT stable with do_w_axis = %s: Re max = %+.5f.\n' ...
     'These matrices must not be used.'], w_axis_str(do_w_axis), max(real(ev)));

info = struct('n_state', n, 'n_ax_state', n_as, 'do_w_axis', {do_w_axis}, ...
              'poles', ev, 're_max', max(real(ev)), 'tau_slow', -1/max(real(ev)));
if old_form
    % Present only for the old form, for continuity with existing callers
    % that print info.harm/info.w (grepped: none currently read these two
    % specifically, but they cost nothing to keep and nothing reads them
    % under the new form either way).
    info.harm = harm;
    info.w    = sigma*harm;
end
end

function s = w_axis_str(do_w_axis)
s = ['{' mat2str(do_w_axis{1}) ', ' mat2str(do_w_axis{2}) ', ' mat2str(do_w_axis{3}) '}'];
end
