#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SUITE=${1:-smoke}
case "${SUITE}" in
  smoke)
    for mode in 0 1 2 3 4 5; do bash "${HERE}/run.sh" smoke "${mode}" 1; done;;
  boundary)
    for direction in write read; do
      for beats in 2 3 4 5 8 16 255 256; do
        bash "${HERE}/run.sh" burst_boundary 0 1 "+DIRECTION=${direction}" "+BURST_BEATS=${beats}"
      done
    done;;
  *) echo 'Usage: bash dv/sim/regression.sh smoke|boundary' >&2; exit 2;;
esac
