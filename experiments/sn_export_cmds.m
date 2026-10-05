function C = sn_export_cmds(outdir)
%SN_EXPORT_CMDS  REGISTER_P2 sec 43.2: the export commands for the wind-sensor-noise sensitivity.
%
%   C = sn_export_cmds               % prints the two python commands (outdir 'wind_sn010')
%
%  The segments of S40 (circle) and S40hover, split by source (wind_real_t150_* from the M5 dev
%  directory, wind_expl_t150_* from the exploration directory), re-exported with sensor noise
%  sigma 0.1 m/s into their own directory (same file names). PI-MoE w_hat is recomputed by the export
%  on the noisy input. Seeds per segment: 20240601 + 1000003*i (real), 20740601 + 1000003*i
%  (exploration - so a real and an exploration segment with the same index do not share a draw).
%  --check-against . : each new file's w_true / w_plant must equal the clean file of the same name
%  bit for bit, otherwise nothing is written. Replace <m5 dev dir> / <exploration dir> by the
%  directories used for the original exports (W6_INTEGRATION sec "Duong xuat gio that"; REGISTER_P2 6.1).
if nargin < 1, outdir = 'wind_sn010'; end
S1 = p2_segset('S40', 'Quiet', true);
S2 = p2_segset('S40hover', 'Quiet', true);
f = unique([S1.files(:); S2.files(:)]);
fprintf('  S40 %d + S40hover %d segments -> %d distinct files (sha S40 %s, S40hover %s)\n', S1.n_seg, ...
    S2.n_seg, numel(f), S1.sha256(1:16), S2.sha256(1:16));
C = struct('real', [], 'expl', []);
src = {'real', 'wind_real_t150', '<m5 dev dir>', 20240601; 'expl', 'wind_expl_t150', '<exploration dir>', 20740601};
for k = 1:2
    m = strncmp(f, [src{k, 2} '_i'], numel(src{k, 2}) + 2);
    idx = sort(cellfun(@(s) str2double(regexp(s, '_i(\d+)\.mat$', 'tokens', 'once')), f(m)));
    C.(src{k, 1}) = idx(:).';
    if isempty(idx), continue; end
    fprintf('\n  %s: %d segments\n', src{k, 2}, numel(idx));
    fprintf(['  python python/export_wind_sim.py --real-dir %s --real-split dev ' ...
        '--ckpt w4_frozen_20hz_t150_train2345_s0 --sensor-noise 0.1 --sensor-seed %d ' ...
        '--only-index %s --check-against . --out %s\n'], src{k, 3}, src{k, 4}, ...
        strjoin(arrayfun(@num2str, idx(:).', 'UniformOutput', false), ','), fullfile(outdir, [src{k, 2} '.mat']));
end
assert(numel(C.real) + numel(C.expl) == numel(f), 'sn_export_cmds: a file of neither source.');
fprintf('\n  first: mkdir %s. The export refuses an --out in the current directory.\n', outdir);
end
