function ok = confirm3_gate()
%CONFIRM3_GATE  Opening condition of CONFIRM3 (docs/REGISTER_FINAL.md sec 6.1), checked by every CONFIRM3 step.
%
%  A line starting with "APPROVED" in sec 6.1 that holds a date yyyy-mm-dd and "commit <hash>" of the runner, e.g.
%      APPROVED: Huyhoang   ngày: 2026-10-07 - runner commit abc1234
%  that commit an ancestor of HEAD, no change since it to the code or the frozen configuration (core/,
%  experiments/, analysis/, python/, rerun/, baseline1.slx, CONFIRM3_MANIFEST.json, .github/workflows/confirm3.yml),
%  and no local change to them.
%  Returns false (and prints why) otherwise; the same check runs in Python before any 2022 file is downloaded
%  (rerun/confirm3_gate.py).
paths = 'core experiments analysis python rerun baseline1.slx CONFIRM3_MANIFEST.json .github/workflows/confirm3.yml';
here = repo_root();
txt = fileread(fullfile(here, 'docs', 'REGISTER_FINAL.md'));
k = strfind(txt, '### 6.1');
ok = false;
if isempty(k), fprintf('  CONFIRM3 gate: REGISTER_FINAL sec 6.1 not found -> NOT MET\n'); return; end
sec = txt(k(1):end);
e = regexp(sec, '\n## ', 'once');
if ~isempty(e), sec = sec(1:e); end
m = regexp(sec, '^\**APPROVED[^\n]*?(\d{4}-\d{2}-\d{2})[^\n]*?commit `?([0-9a-f]{7,40})', 'tokens', 'once', ...
    'lineanchors');
if isempty(m), fprintf('  CONFIRM3 gate: no APPROVED line in REGISTER_FINAL sec 6.1 -> NOT MET\n'); return; end
c = m{2};
old = cd(here);
back = onCleanup(@() cd(old));
s1 = system(sprintf('git merge-base --is-ancestor %s HEAD', c));
s2 = system(sprintf('git diff --quiet %s HEAD -- %s', c, paths));
[s3, out] = system(sprintf('git status --porcelain -- %s', paths));
s3 = s3 == 0 && isempty(strtrim(out));
ok = s1 == 0 && s2 == 0 && s3;
fprintf(['  CONFIRM3 gate: APPROVED %s, runner commit %s: ancestor of HEAD %s, unchanged since %s, ' ...
    'no local change %s -> %s\n'], m{1}, c, yn(s1 == 0), yn(s2 == 0), yn(s3), tern(ok, 'OK', 'NOT MET'));
end

function s = yn(b)
s = tern(b, 'yes', 'NO');
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
