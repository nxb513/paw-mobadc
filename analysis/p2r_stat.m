function r = p2r_stat(f, E, day)
%P2R_STAT  REGISTER_P2 sec 0.2 on a pooled-ratio statistic f(pooled vector): value, SE (paired delete-one-day
%  jackknife), LOO [min, max], by-day median (each day's own pooled columns), n, days.
pool = @(e) sqrt(mean(e.^2, 1));
n = size(E, 1);
r.val = f(pool(E));
loo = nan(n, 1);
for i = 1:n, if n > 1, loo(i) = f(pool(E([1:i-1, i+1:n], :))); end, end
ud = unique(day);  nd = numel(ud);  jd = nan(nd, 1);  dd = nan(nd, 1);
for j = 1:nd
    m = strcmp(day, ud{j});
    if nd > 1, jd(j) = f(pool(E(~m, :))); end
    dd(j) = f(pool(E(m, :)));
end
r.se = NaN;  if nd > 1, r.se = sqrt((nd - 1) / nd * sum((jd - mean(jd)).^2)); end
r.loo = [min(loo), max(loo)];  if n < 2, r.loo = [r.val r.val]; end
r.med = median(dd);  r.n = n;  r.nd = nd;  r.byday = dd;  r.days = ud;
end
