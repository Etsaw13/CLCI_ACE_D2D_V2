#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SUITE=${1:-smoke}
case "${SUITE}" in
  smoke)
    for mode in 0 1 2 3 4 5; do bash "${HERE}/run.sh" ace_v2_smoke_test "${mode}" 1; done;;
  directed)
    for test in ace_v2_apb_test ace_v2_smoke_test ace_v2_single_write_test ace_v2_single_read_test ace_v2_burst_write_test ace_v2_burst_read_test ace_v2_snoop_stress_test ace_v2_pause_resume_test; do
      bash "${HERE}/run.sh" "${test}" 0 1
    done;;
  boundary)
    for test in ace_v2_burst_write_test ace_v2_burst_read_test; do
      for beats in 2 3 4 5 8 16 255 256; do
        bash "${HERE}/run.sh" "${test}" 0 1 +TX_TARGET=1 "+BURST_BEATS=${beats}"
      done
    done;;
  negative)
    bash "${HERE}/run.sh" ace_v2_error_status_test 0 1;;
  *) echo 'Usage: bash uvm/sim/regression.sh smoke|directed|boundary|negative' >&2; exit 2;;
esac
