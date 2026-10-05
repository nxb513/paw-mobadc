function [files, days, outf] = shard_files(files, days, outf, shard)
%SHARD_FILES  Contiguous part k of n of a runner's segment list, for parallel runs (rerun/, 2026-10-05).
%
%   [files, days, outf] = shard_files(files, days, outf, [k n])
%
%  shard = [] (every runner's default) returns the inputs unchanged. Otherwise part k of n: segments
%  floor((k-1) N/n) + 1 .. floor(k N/n), in the set's own order, saved to <outf>__s<k>of<n>N<N>.mat with the
%  runner's usual key. rerun/rerun_merge.m concatenates parts 1..n in order, so the merged rows are in the
%  same order as one unsharded run; it merges only when every part holds exactly its share of the N segments.
if isempty(shard), return; end
assert(numel(shard) == 2 && shard(2) >= 1 && shard(1) >= 1 && shard(1) <= shard(2) && all(shard == round(shard)), ...
    'shard_files: Shard must be [k n] with 1 <= k <= n.');
k = shard(1);  n = shard(2);  N = numel(files);
lo = floor((k - 1) * N / n) + 1;  hi = floor(k * N / n);
files = files(lo:hi);  days = days(lo:hi);
[d, b, e] = fileparts(outf);
outf = fullfile(d, sprintf('%s__s%dof%dN%d%s', b, k, n, N, e));
fprintf('  shard %d of %d: segments %d-%d of %d -> %s\n', k, n, lo, hi, N, outf);
end
