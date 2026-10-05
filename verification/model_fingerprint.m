function T = model_fingerprint(revs)
%MODEL_FINGERPRINT  READ ONLY: P2 wiring fingerprint and MD5 of baseline1.slx as committed at given git revisions,
%  every file loaded from disk the same way (build_p2_plant 'FingerprintOf'). Nothing is built or saved; the
%  repository's baseline1.slx is not touched (each revision is written to a temporary folder).
%
%   T = model_fingerprint                          % 54a72f6 (2026-09-30 build), f4c88bc (LQI removed), working copy
%   T = model_fingerprint({'54a72f6'})             % one revision ('WORK' = the file in the working folder)
%
%  Question it answers (2026-10-04): the saved model, loaded, gives fingerprint fae8c428...; an in-memory rebuild
%  gives c965867910b8... (= REGISTER_P2 sec 50 for the 2026-09-30 build, MD5 B27EA7C8). If the 2026-09-30 file,
%  loaded the same way, gives fae8... the difference comes from how the number is taken (loaded vs just built); if it
%  gives c965..., removing the LQI blocks on 2026-10-04 changed what the fingerprint covers.
%  Run in its own process:  matlab -batch "setup_path; model_fingerprint"
if nargin < 1 || isempty(revs), revs = {'54a72f6', 'f4c88bc', 'WORK'}; end
revs = cellstr(revs);
root = repo_root();
tmp = fullfile(tempdir, 'model_fingerprint');
T = struct('rev', revs(:), 'md5', '', 'fingerprint', '');
for k = 1:numel(revs)
    r = revs{k};
    if strcmpi(r, 'WORK')
        f = fullfile(root, 'baseline1.slx');
    else
        d = fullfile(tmp, r);
        if exist(d, 'dir') ~= 7, mkdir(d); end
        f = fullfile(d, 'baseline1.slx');
        % cmd.exe / sh redirect is binary-safe (a PowerShell '>' would re-encode the bytes)
        [st, msg] = system(sprintf('git -C "%s" cat-file blob %s:baseline1.slx > "%s"', root, r, f));
        assert(st == 0, 'model_fingerprint: git cat-file %s failed: %s', r, msg);
    end
    T(k).md5 = file_md5(f);
    out = evalc('build_p2_plant(''FingerprintOf'', f)');
    tok = regexp(out, 'FINGERPRINT of .*?: ([0-9a-f]{64})', 'tokens', 'once');
    assert(~isempty(tok), 'model_fingerprint: no fingerprint for %s:\n%s', r, out);
    T(k).fingerprint = tok{1};
end
fprintf('\nmodel_fingerprint (loaded from file, nothing built or saved)\n');
fprintf('  %-8s  %-32s  %s\n', 'rev', 'MD5 of baseline1.slx', 'P2 wiring fingerprint');
for k = 1:numel(T)
    fprintf('  %-8s  %-32s  %s\n', T(k).rev, T(k).md5, T(k).fingerprint);
end
end

function h = file_md5(f)
fid = fopen(f, 'r');  b = fread(fid, inf, '*uint8');  fclose(fid);
md = java.security.MessageDigest.getInstance('MD5');
h = upper(reshape(dec2hex(typecast(md.digest(b), 'uint8'), 2).', 1, []));
end
