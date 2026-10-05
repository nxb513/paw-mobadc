function lines = check_paper_divergence(measured)
%CHECK_PAPER_DIVERGENCE  Flag where this reproduction diverges from Guo 2020.
%
%   lines = check_paper_divergence(measured)
%
%  measured : a struct with fields Classical/ESO/DO/MOBADC, each holding .mean
%  lines    : a cell array of text lines to print and to write into the table
%
%  Before this file, run_baseline.m simply printed the paper's numbers beside
%  its own (the '(Paper: ...)' line) and left the reader to compare them. The
%  reader will not compare them. And the thing most in need of comparing is not
%  the magnitude but the ORDERING: in the paper ESO is WORSE than Classical, in
%  this reproduction it is the other way round.
%
%  A reproduction that reverses the order of two methods is the first thing a
%  referee will ask about. This function makes sure that fact is always in the
%  output rather than in the memory of whoever ran the script.

E = expected_baseline();
lines = {};

lines{end+1} = '  --- Against Guo et al., CEP 2020, Table 1 (Test 4) ---';
lines{end+1} = sprintf('  %-10s %-10s %-10s %-10s', ...
                       '', 'paper', 'reproduction', 'ratio');
for k = 1:numel(E.names)
    N = E.names{k};
    p = E.paper.(N).mean;
    q = measured.(N).mean;
    lines{end+1} = sprintf('  %-10s %-10.4f %-10.4f x%.2f', N, p, q, q/p); %#ok<AGROW>
end

% --- Check the ORDERING, not the magnitude ---
paper_rank = rank_of(E.paper, E.names);
repro_rank = rank_of(measured, E.names);
flipped = {};
for i = 1:numel(E.names)
    for j = i+1:numel(E.names)
        a = E.names{i}; b = E.names{j};
        pa = E.paper.(a).mean < E.paper.(b).mean;
        qa = measured.(a).mean < measured.(b).mean;
        if pa ~= qa
            flipped{end+1} = sprintf('%s/%s', a, b); %#ok<AGROW>
        end
    end
end

lines{end+1} = sprintf('  paper order        : %s', strjoin(paper_rank, ' < '));
lines{end+1} = sprintf('  reproduction order : %s', strjoin(repro_rank, ' < '));

if isempty(flipped)
    lines{end+1} = '  Method ordering: MATCHES.';
else
    lines{end+1} = sprintf('  *** ORDER REVERSED in %d pair(s): %s ***', ...
                           numel(flipped), strjoin(flipped, ', '));
    lines{end+1} = '  This is NOT a difference in magnitude but a QUALITATIVE one.';
    lines{end+1} = '  The DO row agrees to ~1% and is the only row derivable from';
    lines{end+1} = '  the Appendix; the other three cannot be derived, because the';
    lines{end+1} = '  paper does not publish the tether length, the swing amplitude';
    lines{end+1} = '  or the magnitude of the wind force.';
    lines{end+1} = '  -> This must be stated explicitly in your own paper. Do not';
    lines{end+1} = '     call it a "reproduction" without saying so.';
    warning('check_paper_divergence:order', ...
        ['This reproduction REVERSES THE ORDER against Guo 2020 in the pair(s): ' ...
         '%s. See docs/devlog/AUDIT.md, section A3.'], strjoin(flipped, ', '));
end
end


%% =====================================================================
function order = rank_of(s, names)
v = cellfun(@(n) s.(n).mean, names);
[~, idx] = sort(v);
order = names(idx);
end
