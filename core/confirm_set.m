function c = confirm_set(dirp)
%CONFIRM_SET  The held-out set whose export is in directory dirp (the runners' option 'Conf2'):
%  CONFIRM2 (REGISTER_P2 sec 60.1 / 60.8, 2024, used once on 2026-10-03) or CONFIRM3 (REGISTER_FINAL sec 6, 2022).
%  Told apart by the export's batch manifest in dirp: wind_conf3_t150_batch.json -> CONFIRM3, otherwise CONFIRM2
%  (whose checks are unchanged). Fields:
%    name      'CONFIRM2' / 'CONFIRM3'
%    prefix    segment file prefix (wind_conf2_t150_i / wind_conf3_t150_i)
%    batch     the export's batch manifest file name
%    manifest  the committed day manifest (repo root)
%    file_sha  its registered SHA-256 (committed bytes, CR removed)
%    days_sha  registered SHA-256 of its sorted days joined by newlines
%    n_days    registered number of days in the manifest
%    outdir    results/<outdir> of the runners (gd10 / gd12)
b3 = exist(fullfile(dirp, 'wind_conf3_t150_batch.json'), 'file') == 2;
assert(~(b3 && exist(fullfile(dirp, 'wind_conf2_t150_batch.json'), 'file') == 2), ...
    'confirm_set: %s holds both a CONFIRM2 and a CONFIRM3 export.', dirp);
if b3
    c = struct('name', 'CONFIRM3', 'prefix', 'wind_conf3_t150_i', 'batch', 'wind_conf3_t150_batch.json', ...
        'manifest', 'CONFIRM3_MANIFEST.json', ...
        'file_sha', '26c6985aed6d185f3477247a75e5ee3336b5d1bf88570a6f029013fd00598dc6', ...
        'days_sha', 'b992cc090383b0ef433b7dc8a45b8eff680d4abee17283b55b461cb5057b654e', ...
        'n_days', 58, 'outdir', 'gd12');
else
    c = struct('name', 'CONFIRM2', 'prefix', 'wind_conf2_t150_i', 'batch', 'wind_conf2_t150_batch.json', ...
        'manifest', 'CONFIRM2_MANIFEST.json', ...
        'file_sha', '86f58ae95cdbb833ae1f42bf2a36fb5786a92a716843d9da8e50df265629ed23', ...
        'days_sha', '79ea95decaf9a07699b567ecfd4d8de3295db58fb7edfc3ab148faccc55d6bc2', ...
        'n_days', 16, 'outdir', 'gd10');
end
end
