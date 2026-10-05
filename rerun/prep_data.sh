#!/usr/bin/env bash
# prep_data.sh - rebuild the wind segments of the paper from the public NREL M5 data (REGISTER_P2 sec 6.1, 60.6).
#
#   bash rerun/prep_data.sh            # from the repository root; PY defaults to python3
#
# 1. downloads the 260 M5 files of the 65 dev-split days (rerun/m5_dev_urls.txt) into m5/dev/ (git-ignored);
# 2. links the 128 files of the 32 exploration days into m5/explore/ and the 56 files of the 14 CONFIRM2 days
#    (16 manifest days minus the 2 characterisation days, D23) into m5/confirm2/;
# 3. exports the segments with the frozen PI-MoE checkpoint, exactly as the original runs:
#      wind_real_t150_i*.mat   (every dev segment; field_grid_K050.mat uses 30 of them)
#      wind_expl_t150_i*.mat   + wind_expl_t150_batch.json   (exploration, 441 segments expected)
#      wind_conf2/wind_conf2_t150_i*.mat + batch json        (CONFIRM2, 163 segments expected)
# Checks afterwards (MATLAB): p2_segset('all', 'CapPerDay', 4) must print the registered SHA-256 per set and the
# exploration fingerprint 73749ad2...; U of the 30 field_grid files is asserted against T.U to 1e-9.
set -euo pipefail
PY=${PY:-python3}
CK=w4_frozen_20hz_t150_train2345_s0
mkdir -p m5/dev m5/explore m5/confirm2 wind_conf2

echo "== download (resumable) =="
tr -d '\r' < rerun/m5_dev_urls.txt | xargs -P 8 -n 1 sh -c \
  'f="m5/dev/$(basename "$0")"; [ -s "$f" ] || curl -fsS --retry 5 --retry-delay 10 --max-time 900 -o "$f.part" "$0" && mv "$f.part" "$f" 2>/dev/null || true'
n=$(ls m5/dev/*.mat | wc -l); echo "  m5/dev holds $n of 260 files"; [ "$n" -eq 260 ] || { echo "download incomplete"; exit 1; }

echo "== subsets =="
for s in explore confirm2; do
  tr -d '\r' < "rerun/m5_${s}_files.txt" | while read -r f; do [ -n "$f" ] && ln -f "m5/dev/$f" "m5/$s/$f" 2>/dev/null || cp -f "m5/dev/$f" "m5/$s/$f"; done
  echo "  m5/$s: $(ls m5/$s/*.mat | wc -l) files"
done

echo "== export =="
$PY python/export_wind_sim.py --real-dir m5/explore  --real-split dev --real-max 10000 --ckpt $CK --out wind_expl_t150.mat
$PY python/export_wind_sim.py --real-dir m5/dev      --real-split dev --real-max 10000 --ckpt $CK --out wind_real_t150.mat
$PY python/export_wind_sim.py --real-dir m5/confirm2 --real-split dev --real-max 10000 --ckpt $CK --out wind_conf2/wind_conf2_t150.mat
echo "== done: $(ls wind_real_t150_i*.mat | wc -l) real, $(ls wind_expl_t150_i*.mat | wc -l) exploration, $(ls wind_conf2/wind_conf2_t150_i*.mat | wc -l) CONFIRM2 segments =="

# ---- subsets re-exported with another wind MEASUREMENT (w_plant identical: --check-against .) ----
#   wind_sn010/ : S40 + S40hover (rerun/subset_sn.txt, 51 files), sensor noise 0.1 m/s (REGISTER_P2 sec 43.3 seeds)
#   wind_spk/   : circle_main + N6_hover (rerun/subset_spk.txt, 162 files), causal spike filter 5 m/s (REGISTER_FINAL E2)
subset_export() {   # list outdir extra-args... (seed offsets: real 20240601, exploration 20740601)
  local list=$1 out=$2; shift 2
  mkdir -p "$out"
  for src in real expl; do
    idx=$(tr -d '\r' < "$list" | grep "^wind_${src}_t150_i" | sed -E 's/.*_i([0-9]+)\.mat/\1/' \
          | while read -r x; do echo $((10#$x)); done | paste -sd, -)
    [ -z "$idx" ] && continue
    dir=m5/dev; seed=20240601
    [ "$src" = expl ] && { dir=m5/explore; seed=20740601; }
    $PY python/export_wind_sim.py --real-dir "$dir" --real-split dev --ckpt $CK --only-index "$idx" \
        --check-against . --sensor-seed $seed --out "$out/wind_${src}_t150.mat" "$@"
  done
  echo "  $out: $(ls "$out"/wind_*_t150_i*.mat | wc -l) files"
}
echo "== subsets =="
subset_export rerun/subset_sn.txt  wind_sn010 --sensor-noise 0.1
subset_export rerun/subset_spk.txt wind_spk   --meas-spike-hold 5.0
