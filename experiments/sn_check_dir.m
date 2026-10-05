function sn_check_dir(d)
%SN_CHECK_DIR  REGISTER_P2 sec 43.3: every file in the noisy-sensor directory must carry sensor_noise = 0.1
%  (and w_meas ~= w_true), otherwise the SN runs stop before any simulation.
f = dir(fullfile(d, 'wind_*_t150_i*.mat'));
assert(~isempty(f), 'sn_check_dir: no wind_*_t150_i*.mat in %s.', d);
for k = 1:numel(f)
    Z = load(fullfile(d, f(k).name), 'sensor_noise', 'w_meas', 'w_true');
    assert(isfield(Z, 'sensor_noise') && abs(double(Z.sensor_noise) - 0.1) < 1e-12, ...
        'sn_check_dir: %s has sensor_noise %s, not 0.1.', f(k).name, mat2str(Z.sensor_noise));
    assert(isfield(Z, 'w_meas') && ~isequal(Z.w_meas, Z.w_true), 'sn_check_dir: %s w_meas equals w_true.', f(k).name);
end
fprintf('  %s: %d files, sensor_noise 0.1 in every one, w_meas differs from w_true\n', d, numel(f));
end
