#!/usr/bin/env bash
# fetch_results.sh - copy the artifacts matching PATTERN of the given runs into DEST, in run order (a later run's
# file replaces an earlier one's of the same path). Used by final-step.yml, final.yml (report) and confirm3.yml.
#
#   bash rerun/fetch_results.sh 'results-*' results "<earlier run ids, comma-separated or empty>" "$GITHUB_RUN_ID"
#
# `gh run download` lists every artifact of a run (paginated); actions/download-artifact with run-id lists only the
# first 100 (run 37481942029 lost waves A-B that way). Needs GH_TOKEN (actions: read). A run with no matching
# artifact is not an error (a first wave has none).
set -euo pipefail
pat=$1 dest=$2 earlier=$3 this=$4
mkdir -p "$dest"
for r in ${earlier//,/ } $this; do
  d="${RUNNER_TEMP:-/tmp}/fetch_${r}_${pat//[^A-Za-z0-9]/_}"
  rm -rf "$d"; mkdir -p "$d"
  gh run download "$r" -R "${GITHUB_REPOSITORY:-nxb513/paw-mobadc}" -p "$pat" -D "$d" 2>/dev/null || true
  n=0
  for a in "$d"/*/; do
    [ -d "$a" ] || continue
    cp -a "$a". "$dest"/; n=$((n + 1))
  done
  echo "run $r: $n artifact(s) '$pat' -> $dest/"
  rm -rf "$d"
done
echo "$dest/: $(find "$dest" -type f | wc -l) file(s)"
