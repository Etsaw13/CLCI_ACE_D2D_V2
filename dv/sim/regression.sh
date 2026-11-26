#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SUITE=${1:-smoke}
case "${SUITE}" in
  smoke)
    for mode in 0 1 2 3 4 5; do bash "${HERE}/run.sh" smoke "${mode}" 1; done;;
  cache)
    for test in uc_rs_sc cr_unique cr_shared; do bash "${HERE}/run.sh" "${test}" 0 1; done;;
  fixes)
    bash "${HERE}/run_cache_snoop_fix.sh"
    for test in dirty_readonce data_alias; do bash "${HERE}/run.sh" "${test}" 2 1; done;;
  coverage)
    bash "${HERE}/regression.sh" smoke
    bash "${HERE}/regression.sh" cache
    bash "${HERE}/regression.sh" boundary;;
  boundary)
    for direction in write read; do
      for beats in 2 3 4 5 8 16 255 256; do
        bash "${HERE}/run.sh" burst_boundary 0 1 "+DIRECTION=${direction}" "+BURST_BEATS=${beats}"
      done
    done;;
  *) echo 'Usage: bash dv/sim/regression.sh smoke|boundary|cache|coverage|fixes' >&2; exit 2;;
esac
