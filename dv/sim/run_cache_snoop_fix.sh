#!/usr/bin/env bash
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "${HERE}/../.." && pwd)
VCS=$(command -v "${VCS_BIN:-vcs}") || {
  echo "VCS not found; set VCS_BIN to the compiler path" >&2
  exit 2
}
VCS=$(cd "$(dirname "${VCS}")" && pwd)/$(basename "${VCS}")
STAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="${ROOT}/dv/out/cache_snoop_fix_${STAMP}_$$"
mkdir -p "${RUN_DIR}"

result=0
for top in tb_a_ac_order tb_a_snoop_miss tb_b_home_order; do
  build="${RUN_DIR}/${top}"
  mkdir -p "${build}"
  if ! (cd "${build}" && "${VCS}" -full64 -sverilog -timescale=1ns/1ps \
    +incdir+"${ROOT}/ace" \
    "${ROOT}/ace/ace_pkg.sv" \
    "${ROOT}/ace/module_a.sv" \
    "${ROOT}/ace/module_b.sv" \
    "${ROOT}/dv/unit/cache_snoop_fix_tb.sv" \
    -top "${top}" -o "${build}/simv" \
    -l "${build}/compile.log") >"${build}/compile.console.log" 2>&1; then
    echo "CACHE_SNOOP_COMPILE_FAIL: ${top}  log=${build}/compile.log"
    grep -n -A6 -B2 -E 'Error-\[|Syntax error|Undefined|Identifier not declared|[Ee]rror:' \
      "${build}/compile.log" | head -40 || tail -20 "${build}/compile.console.log"
    result=1
    continue
  fi
  sim_rc=0
  (cd "${build}" && ./simv -l sim.log) >"${build}/sim.console.log" 2>&1 || sim_rc=$?
  pass_marker="CACHE_SNOOP_SUBTEST_PASS"
  if [[ ${sim_rc} -eq 0 ]] && grep -q "${pass_marker}" "${build}/sim.log" && \
     ! grep -qE 'CACHE_SNOOP_REGRESSION_FAIL|Fatal:|FATAL|Error:|ERROR' "${build}/sim.log"; then
    grep '^CACHE_SNOOP_CASE_PASS ' "${build}/sim.log" || true
    echo "CACHE_SNOOP_SUBTEST_PASS: ${top}"
  else
    echo "CACHE_SNOOP_SUBTEST_FAIL: ${top}  log=${build}/sim.log"
    if [[ -s "${build}/sim.log" ]]; then
      tail -20 "${build}/sim.log"
    else
      tail -20 "${build}/sim.console.log"
    fi
    if [[ ${sim_rc} -ne 0 ]]; then echo "SIM_EXIT_CODE: ${sim_rc}"; fi
    result=1
  fi
done

if [[ ${result} -eq 0 ]]; then
  echo "CACHE_SNOOP_REGRESSION_PASS: ${RUN_DIR}"
else
  echo "CACHE_SNOOP_REGRESSION_FAIL: ${RUN_DIR}"
fi
exit "${result}"
