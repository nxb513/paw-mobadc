function R = pool_rule(E, dvc, th, varargin)
%POOL_RULE  The pooling rule of this paper - one source for EVERY table.
%
%   R = pool_rule(E, dvc, th)
%   R = pool_rule(E, dvc, th, 'ThetaMax', 15, 'SetCols', 1:8)
%
%  Inputs
%    E    n_seg x n_cfg   per-segment metric, one column per configuration
%    dvc  n_seg x n_cfg   logical: did that configuration diverge on that segment
%    th   n_seg x 1       static payload deflection theta_DC of each segment, deg
%
%  ======================================================================
%  WHY THIS FUNCTION EXISTS
%  ======================================================================
%  The pooling rule used to live in SEVERAL places: the envelope was written
%  once in sweep_field_grid and again in sweep_field_benchmark, and the rule
%  for building the segment set was implemented DIFFERENTLY in the two, with
%  nobody declaring that. A paper may not have two pooling rules. If a reviewer
%  asks "why does this column pool over 25 segments and that one over 22", the
%  answer has to be one sentence, in one place.
%
%  ======================================================================
%  THE RULE - fixed in advance, not re-chosen after seeing the numbers
%  ======================================================================
%  (L1) DECLARED OPERATING ENVELOPE. Segments with theta_DC > 15 deg are held
%       out of every pooled number. This is a constraint fixed BEFOREHAND, not
%       a way of cutting data to taste: it is computed from declared constants
%       and the segment mean wind speed, and it never looks at the tracking
%       error of any controller.
%
%       THE EARLIER JUSTIFICATION IS WITHDRAWN, and these very lines carried
%       it. They used to say the threshold came from the small-angle error of
%       sin(theta) ~ theta (1.1% at 15 deg) in the Payload_Pendulum block. That
%       was wrong: the block makes no such approximation -
%       payload_pendulum_derivative integrates sin/cos and
%       payload_pendulum_output uses the full tether tension
%       T = m_p(g cos th + L thd^2 + a sin th). A small-angle error cannot
%       exist in a simulator that does not take the small-angle approximation.
%
%       THE VALUE, 15 deg, IS UNCHANGED. It was fixed before any run and every
%       pooled number in the paper was formed under it; changing it now would
%       be changing the pooling rule after seeing the results. What changed is
%       the NAME: a declared operating envelope on the static deflection of the
%       load, not a model-error bound. Why the closed loop fails beyond it is
%       not known - actuator saturation was measured and REJECTED as the
%       mechanism (docs/RESULTS.md, R6.2.1).
%
%  (L2) ONE TABLE = ONE SEGMENT SET. Every column of a given table pools over
%       the SAME set, and that set is the one on which EVERY COLUMN OF THAT
%       TABLE is finite and non-divergent. A column of numbers is comparable
%       along a row only if the rows share a set.
%
%  (L3) THE HEADLINE NUMBER (PA-MOBADC vs MOBADC) comes from the MAIN table
%       (the four-stage grid), where every column is a variant of MOBADC. The
%       benchmark table reports the same quantity on its OWN five-controller
%       set and must say so. The reason: a number about two controllers must
%       NOT move because a third controller was added to the same script, and
%       the only way to guarantee that for the headline number is to take it
%       from the table that does not contain the third controller.
%
%  (L4) DIVERGENCE IS REPORTED SEPARATELY, per controller. It is a result
%       about ROBUSTNESS, not refuse. A pooled RMS table cannot express it.
%
%  ======================================================================
%  THE ALTERNATIVE THAT WAS CONSIDERED AND REJECTED
%  ======================================================================
%  "Let each pairwise comparison use the set of just those two columns." That
%  sounds more principled - the PA vs MOBADC number would not depend on whether
%  Classical survived - but:
%    - a table whose five rows pool over five different sets has a meaningless
%      RMS column;
%    - (L3) already closes that specific hole for the headline number;
%    - and it is not the conservative choice. Dropping the segments where the
%      WEAK controllers diverge drops the STRONGEST-WIND segments, which
%      UNDERSTATES the benefit of PA-MOBADC. The bias runs towards the null
%      hypothesis, which is the only direction of bias defensible in a paper.
%  So (L2) is fixed, and both sets are deliberately not printed for later
%  selection: printing both and then choosing is exactly the freedom that
%  preregistration exists to remove.
%
%  ======================================================================
%  A DEFECT THIS FUNCTION WAS WRITTEN TO FIX
%  ======================================================================
%  The grid used to build its segment set from 'dv' = the OR of FIVE columns
%  (L0 L1 L2 L3 X) and then pool ALL EIGHT columns over that set. So P, O and W
%  were pooled over a set that had never been checked for divergence of THOSE
%  columns. If the oracle O had diverged on a segment inside the set, the
%  "wind-channel ceiling" number would have been contaminated with no visible
%  sign of it. 'SetCols' reproduces the old behaviour exactly, for comparison;
%  the default is EVERY column, which is (L2).

opt = struct('ThetaMax', 15, 'SetCols', []);
for i = 1:2:numel(varargin)
    opt.(validatestring(varargin{i}, fieldnames(opt))) = varargin{i+1};
end
nc = size(E, 2);
assert(isequal(size(dvc), size(E)), 'pool_rule: dvc must be the same size as E.');
assert(numel(th) == size(E,1), 'pool_rule: th needs one element per segment.');
if isempty(opt.SetCols), opt.SetCols = 1:nc; end
sc = opt.SetCols(:)';

R.valid  = th(:) <= opt.ThetaMax;              % (L1) declared envelope
R.finite = all(isfinite(E(:, sc)), 2);
R.alive  = ~any(dvc(:, sc), 2);
R.stable = R.valid & R.finite & R.alive;       % (L2) one table, one set
assert(any(R.stable), ['pool_rule: no segment passes the pooling rule ' ...
       '(%d outside the envelope, %d diverged, %d non-finite).'], ...
       sum(~R.valid), sum(~R.alive), sum(~R.finite));

% DO NOT drop NaN column by column. Doing so would quietly pool one column over
% fewer segments than the others - precisely what (L2) forbids. A column that
% comes out NaN must be SEEN to be NaN, and the reason understood.
R.pooled = nan(1, nc);
for c = 1:nc
    R.pooled(c) = sqrt(mean(E(R.stable, c).^2));
end
R.nan_cols = find(~isfinite(R.pooled));

R.n_seg    = sum(R.stable);
R.n_total  = numel(R.stable);
R.theta_max = opt.ThetaMax;
R.set_cols = sc;
% The substring 'theta_DC' is load-bearing: fig_data accepts a saved aggregate
% as verified when G.rule contains it, and recomputes the pooling otherwise.
R.rule = sprintf('L1 theta_DC <= %g deg | L2 common set over columns [%s] | n = %d/%d', ...
                 opt.ThetaMax, num2str(sc), R.n_seg, R.n_total);
end
