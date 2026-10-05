function spk_check_dir(d)
%SPK_CHECK_DIR  rerun/ (2026-10-05): every file in the spike-filter directory must carry meas_spike_hold > 0
%  (export_wind_sim.py --meas-spike-hold), otherwise the spike-filter runs stop before any simulation.
f = dir(fullfile(d, 'wind_*_t150_i*.mat'));
assert(~isempty(f), 'spk_check_dir: no wind_*_t150_i*.mat in %s.', d);
nh = 0;
for k = 1:numel(f)
    Z = load(fullfile(d, f(k).name), 'meas_spike_hold', 'meas_spike_n');
    assert(isfield(Z, 'meas_spike_hold') && double(Z.meas_spike_hold) > 0, ...
        'spk_check_dir: %s carries no spike filter (meas_spike_hold).', f(k).name);
    nh = nh + double(Z.meas_spike_n);
end
fprintf('  %s: %d files, spike filter on in every one, %d samples held in all\n', d, numel(f), nh);
end
