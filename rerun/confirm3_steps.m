function T = confirm3_steps()
%CONFIRM3_STEPS  The steps of CONFIRM3 (docs/REGISTER_FINAL.md sec 6 / 6.1), run ONCE by .github/workflows/confirm3.yml.
%
%  Same struct as rerun_steps (id, wave, shards, call). Ids 'C3-*' read the CONFIRM3 export in wind_conf3/;
%  ids 'C3dev-*' run the same chain on the first NDEV segments of each rule's DEV set (plumbing test, results in
%  results/gd10_devtest/, no 2022 file read).
%    G  C3-open    opening condition (REGISTER_FINAL sec 6.1 APPROVED line), D2 row 1 on dev data, the three sets
%                  by rule - SHA-256 printed first, saved to results/gd12/sets.mat (a resume must find the same)
%    H  C3-D2      D2 on the circle set (L0 L2 L3 V)              C3-hover   C2-hover (L3 L3_iii0 H3 H3_b086 H3_b170)
%       C3-hhover  C2-hhover on the H-hover set (L3 P O O0)
%    I  C3-circle  C2-circle on the circle set (L3_iii0 H3; L3 reused from C3-D2 after a spot check)
%    J  C3-claims  the claims of REGISTER_FINAL sec 6.1 (analysis/conf2_claims.m) -> results/gd12/claims.mat
%  Frozen configuration (REGISTER_FINAL sec 6.1; read from the final run's sweeps, nothing tuned on CONFIRM3):
FZ = struct('TauCircle', 0.290, 'TauPrev', 0.180, 'TauHover', 0, 'TauW6', 0.280, 'TauWHH', 0.020, ...
    'H3Hz', NaN, 'Cap', 4, 'Dir', 'wind_conf3', 'SpikeHold', 0, 'NDev', 8);
c = {
 'C3-open',       'G', 1, @(sh) c3_open(FZ, false)
 'C3-D2',         'H', 8, @(sh) c3_run(FZ, false, 'D2', sh)
 'C3-hover',      'H', 8, @(sh) c3_run(FZ, false, 'C2-hover', sh)
 'C3-hhover',     'H', 1, @(sh) c3_run(FZ, false, 'C2-hhover', sh)
 'C3-circle',     'I', 4, @(sh) c3_run(FZ, false, 'C2-circle', sh)
 'C3-claims',     'J', 1, @(sh) c3_claims(FZ, false)
 'C3dev-open',    'G', 1, @(sh) c3_open(FZ, true)
 'C3dev-D2',      'H', 8, @(sh) c3_run(FZ, true, 'D2', sh)
 'C3dev-hover',   'H', 8, @(sh) c3_run(FZ, true, 'C2-hover', sh)
 'C3dev-hhover',  'H', 1, @(sh) c3_run(FZ, true, 'C2-hhover', sh)
 'C3dev-circle',  'I', 4, @(sh) c3_run(FZ, true, 'C2-circle', sh)
 'C3dev-claims',  'J', 1, @(sh) c3_claims(FZ, true)
};
T = struct('id', c(:, 1), 'wave', c(:, 2), 'shards', c(:, 3), 'call', c(:, 4));
end

%% ---------------------------------------------------------------------
function c3_open(FZ, dev)
fprintf('\n  CONFIRM3%s (REGISTER_FINAL sec 6 / 6.1) | git %s\n', tern(dev, ' DEV TEST - no 2022 file is read', ''), ...
    git_head());
ok = confirm3_gate();
assert(ok || dev, 'CONFIRM3 not opened: the opening condition of REGISTER_FINAL sec 6.1 is not met.');
check_frozen(FZ);
Gd = run_p2_gd6('D2', 'TauPred', FZ.TauCircle, 'TauPrev', FZ.TauPrev, 'DryRun', true);
got = round(Gd.rows(1).E * 1e4) / 1e4;  want = [0.0414 0.0334 0.0140 0.0136];
fprintf('  D2 row 1 (dev wind_real_t150_i0000) L0 L2 L3 V: got %s expected %s\n', mat2str(got), mat2str(want));
assert(numel(got) == 4 && all(abs(got - want) < 1e-7), 'CONFIRM3: D2 row 1 changed - not opened.');
if ~dev, check_spike(FZ); end
Sets = c3_sets(FZ, dev);
fprintf('\n  SETS (REGISTER_FINAL sec 6) - SHA-256 of each list:\n');
for f = fieldnames(Sets)'
    s = Sets.(f{1});
    fprintf('  SHA %-7s %-15s %s  (%d segments, %d days)\n', f{1}, s.rule, s.sha256, s.n_seg, s.n_days);
end
setf = fullfile(outdir(dev), 'sets.mat');
if exist(setf, 'file') == 2
    Z = load(setf, 'Sets');
    for f = fieldnames(Sets)'
        assert(strcmp(Z.Sets.(f{1}).sha256, Sets.(f{1}).sha256), ...
            'CONFIRM3: the %s set differs from the saved one - STOP.', f{1});
    end
    fprintf('  resume: the three sets equal %s\n', setf);
else
    git = git_head(); %#ok<NASGU>
    if ~exist(fileparts(setf), 'dir'), mkdir(fileparts(setf)); end
    save(setf, 'Sets', 'git');
end
for f = fieldnames(Sets)'
    s = Sets.(f{1});
    fprintf('\n  %s set (%s): %d segments, %d days, U %.2f-%.2f m/s\n', f{1}, s.rule, s.n_seg, s.n_days, s.U_lo, s.U_hi);
    for i = 1:s.n_seg, fprintf('    %-28s %-10s U %6.2f\n', s.files{i}, s.day{i}, s.U(i)); end
end
end

function c3_run(FZ, dev, what, sh)
ok = confirm3_gate();
assert(ok || dev, 'CONFIRM3: the opening condition of REGISTER_FINAL sec 6.1 is not met - not run.');
check_frozen(FZ);
setf = fullfile(outdir(dev), 'sets.mat');
assert(exist(setf, 'file') == 2, 'CONFIRM3: %s not found - run C3-open first.', setf);
Z = load(setf, 'Sets');  Sets = Z.Sets;
cm = {'Conf2', FZ.Dir};
if dev, cm = {'DevTest', true, 'NDev', FZ.NDev}; end
switch what
    case 'D2'
        run_p2_gd6('D2', 'TauPred', FZ.TauCircle, 'TauPrev', FZ.TauPrev, 'Sha', Sets.circle.sha256, 'Shard', sh, cm{:});
    case 'C2-circle'
        run_p2_gd7('C2-circle', 'TauW', FZ.TauW6, 'TauPred', FZ.TauCircle, 'H3Hz', FZ.H3Hz, ...
            'Sha', Sets.circle.sha256, 'Shard', sh, cm{:});
    case 'C2-hover'
        run_p2_gd7('C2-hover', 'TauW', FZ.TauW6, 'TauPred', FZ.TauHover, 'H3Hz', FZ.H3Hz, ...
            'Sha', Sets.hover.sha256, 'Shard', sh, cm{:});
    case 'C2-hhover'
        if Sets.hhover.n_seg == 0, fprintf('  H-hover set is empty - nothing to run\n'); return; end
        run_p2_gd7('C2-hhover', 'TauW', FZ.TauWHH, 'TauPred', FZ.TauHover, 'Sha', Sets.hhover.sha256, ...
            'Shard', sh, cm{:});
end
end

function c3_claims(FZ, dev)
ok = confirm3_gate();
assert(ok || dev, 'CONFIRM3: the opening condition of REGISTER_FINAL sec 6.1 is not met.');
od = outdir(dev);
src = {'D2', 'D2'; 'circle', 'C2-circle'; 'hover', 'C2-hover'; 'hhover', 'C2-hhover'};
Z = struct();
for k = 1:size(src, 1)
    f = fullfile(od, [src{k, 2} '.mat']);
    Z.(src{k, 1}) = [];
    if exist(f, 'file') == 2, Z.(src{k, 1}) = load(f, 'rows', 'key'); end
end
C = conf2_claims(Z, 'Dir', tern(dev, '', FZ.Dir), 'Title', 'CONFIRM3 CLAIMS (REGISTER_FINAL sec 6.1)');
Sets = load(fullfile(od, 'sets.mat'), 'Sets');  Sets = Sets.Sets; %#ok<NASGU>
git = git_head(); %#ok<NASGU>
save(fullfile(od, 'claims.mat'), 'C', 'Sets', 'git', 'FZ');
fprintf('  saved %s\n', fullfile(od, 'claims.mat'));
end

%% ---------------------------------------------------------------------
function Sets = c3_sets(FZ, dev)
rules = {'circle', 'circle_main'; 'hover', 'N6_hover'; 'hhover', 'N5-H-StrongRel'};
sarg = {'CapPerDay', FZ.Cap, 'Quiet', true};
if ~dev, sarg = [sarg, {'Confirm2', FZ.Dir}]; end
for k = 1:size(rules, 1)
    s = p2_segset(rules{k, 2}, sarg{:});
    s.rule = rules{k, 2};
    if dev, n = min(FZ.NDev, s.n_seg); s.files = s.files(1:n); s.day = s.day(1:n); s.U = s.U(1:n); end
    Sets.(rules{k, 1}) = s;
end
end

function check_frozen(FZ)
assert(isfinite(FZ.H3Hz), 'CONFIRM3: the INDI cut-off of REGISTER_FINAL sec 6.1 is not filled in (H3Hz NaN).');
fprintf(['  frozen (REGISTER_FINAL sec 6.1): tau circle %g s, tau_prev %g s, tau hover %g s, tau_w %g s (C2 groups), ' ...
    '%g s (H-hover), omega_f %g Hz, cap %d/day, spike hold %g m/s\n'], FZ.TauCircle, FZ.TauPrev, FZ.TauHover, ...
    FZ.TauW6, FZ.TauWHH, FZ.H3Hz, FZ.Cap, FZ.SpikeHold);
end

function check_spike(FZ)
%CHECK_SPIKE  every CONFIRM3 segment exported with the registered spike-filter setting (0 = no filter: no field).
d = dir(fullfile(FZ.Dir, 'wind_conf3_t150_i*.mat'));
assert(~isempty(d), 'CONFIRM3: no segment in %s.', FZ.Dir);
for i = 1:numel(d)
    w = whos('-file', fullfile(d(i).folder, d(i).name));
    has = any(strcmp({w.name}, 'meas_spike_hold'));
    if FZ.SpikeHold == 0
        assert(~has, 'CONFIRM3: %s was exported with a spike filter, registered none.', d(i).name);
    else
        assert(has, 'CONFIRM3: %s has no spike filter, registered %g m/s.', d(i).name, FZ.SpikeHold);
        Z = load(fullfile(d(i).folder, d(i).name), 'meas_spike_hold');
        assert(Z.meas_spike_hold == FZ.SpikeHold, 'CONFIRM3: %s spike hold %g, registered %g.', d(i).name, ...
            Z.meas_spike_hold, FZ.SpikeHold);
    end
end
fprintf('  spike filter: %d segments, all as registered (%g m/s)\n', numel(d), FZ.SpikeHold);
end

function d = outdir(dev)
d = fullfile(repo_root(), 'results', tern(dev, 'gd10_devtest', 'gd12'));
end

function h = git_head()
[st, h] = system('git rev-parse HEAD');
if st ~= 0, h = 'unknown'; end
h = strtrim(h);
end

function s = tern(c, a, b)
if c, s = a; else, s = b; end
end
