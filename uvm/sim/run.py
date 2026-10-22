#!/usr/bin/env python3
"""Portable VCS entry. Each invocation has a fresh result directory."""
import datetime
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path
from check_project import ROOT, check

TESTS = ('ace_v2_apb_test', 'ace_v2_smoke_test', 'ace_v2_single_write_test',
         'ace_v2_single_read_test', 'ace_v2_burst_write_test', 'ace_v2_burst_read_test',
         'ace_v2_snoop_stress_test', 'ace_v2_pause_resume_test', 'ace_v2_error_status_test',
         'ace_v2_data_alias_diag_test')
LIMITS = {
    'TX_TARGET': (1, 100000), 'BURST_BEATS': (2, 256), 'PRBS_CODE': (0, 255),
    'XCODE': (0, 255), 'SNOOP_GAP': (0, 255), 'LINK_TIMEOUT_US': (1, 100000),
    'RUN_TIMEOUT_US': (1, 100000), 'GLOBAL_TIMEOUT_US': (1, 100000),
    'DRAIN_TIMEOUT_CYC': (16, 10000000), 'PROGRESS_US': (0, 1000),
    'PAUSE_CYCLES': (16, 1000000), 'PAUSE_AT': (1, 99999), 'ERROR_TARGET': (8, 100000)}


def arguments(argv):
    if argv and argv[0] in ('-h', '--help'):
        print('Usage: bash uvm/sim/run.sh TEST [mode 0..5] [seed] [+KEY=VALUE ...]')
        print('Tests: ' + ', '.join(TESTS))
        print('Numeric keys: ' + ', '.join(LIMITS))
        print('Other keys: +BASE_ADDR=<hex> +APB_TRACE')
        print('Default: ace_v2_smoke_test, mode=0, seed=1, TX_TARGET=64, BURST_BEATS=4.')
        print('Nine regular tests; data_alias_diag is a separate non-normal diagnostic.')
        print('Environment: CHECK_ONLY, COVERAGE, COV_BACKEND, VCS_BIN, VCS_INCLUDE, PYTHON_BIN, UVM_VERBOSITY.')
        sys.exit(0)
    test = argv[0] if argv else 'ace_v2_smoke_test'
    mode = argv[1] if len(argv) > 1 else '0'
    seed = argv[2] if len(argv) > 2 else '1'
    if test not in TESTS or not re.fullmatch('[0-5]', mode):
        raise ValueError('Invalid test/mode; use --help')
    if not re.fullmatch('[0-9]{1,10}', seed) or not 1 <= int(seed) <= 2147483647:
        raise ValueError('Seed must be 1..2147483647')
    options = {'TX_TARGET': 64, 'BURST_BEATS': 4}
    if test == 'ace_v2_snoop_stress_test':
        options['SNOOP_GAP'] = 0
    seen = set()
    for value in argv[3:]:
        match = re.fullmatch(r'\+([A-Z_]+)(?:=(.*))?', value)
        if not match:
            raise ValueError('Invalid argument: ' + value)
        key, text = match.groups()
        if key in seen:
            raise ValueError('Duplicate argument: ' + key)
        seen.add(key)
        if key in LIMITS:
            if text is None or not re.fullmatch('[0-9]{1,8}', text):
                raise ValueError('Expected unsigned decimal: ' + key)
            number = int(text)
            low, high = LIMITS[key]
            if not low <= number <= high:
                raise ValueError('{} must be {}..{}'.format(key, low, high))
            options[key] = number
        elif key == 'BASE_ADDR' and text and re.fullmatch(r'(?:0[xX])?[0-9a-fA-F]{1,11}', text):
            number = int(text, 16)
            if number % 16 or number > (1 << 44) - 64:
                raise ValueError('BASE_ADDR must be aligned with room for four start lines')
            options[key] = format(number, 'x')
        elif key == 'APB_TRACE' and text is None:
            options[key] = None
        else:
            raise ValueError('Unsupported argument: ' + value)
    target, beats = options['TX_TARGET'], options['BURST_BEATS']
    minima = {'ace_v2_smoke_test': 18, 'ace_v2_single_write_test': 2, 'ace_v2_single_read_test': 6,
              'ace_v2_snoop_stress_test': 32, 'ace_v2_pause_resume_test': 18, 'ace_v2_error_status_test': 8}
    if target < minima.get(test, 1):
        raise ValueError('TX_TARGET too small for required directed activity: ' + test)
    if 'PAUSE_AT' in options and (test != 'ace_v2_pause_resume_test' or options['PAUSE_AT'] >= target):
        raise ValueError('PAUSE_AT applies only to pause_resume and must be below TX_TARGET')
    if test == 'ace_v2_data_alias_diag_test' and beats != 4:
        raise ValueError('The alias diagnostic uses exactly four write beats')
    base = int(str(options.get('BASE_ADDR', '20000000')), 16)
    if test in ('ace_v2_smoke_test', 'ace_v2_pause_resume_test'):
        span = 48 + beats * 16
    elif test == 'ace_v2_burst_read_test':
        if beats >= 254 and target != 1:
            raise ValueError('254..256 beat reads require TX_TARGET=1; automatic start-line rotation can cross 4KB')
        span = (48 if target > 1 else 0) + beats * 16
    elif test in ('ace_v2_burst_write_test', 'ace_v2_data_alias_diag_test'):
        span = beats * 16
    else:
        span = 64
    if base % 4096 + span > 4096:
        raise ValueError('Configured automatic start range / burst length can cross 4KB')
    return test, int(mode), int(seed), options


def include_directory(binary):
    override = os.environ.get('VCS_INCLUDE')
    candidates = [Path(override)] if override else [p / 'include' for p in Path(binary).resolve().parents]
    if not override and os.environ.get('VCS_HOME'):
        candidates.append(Path(os.environ['VCS_HOME']) / 'include')
    for candidate in candidates:
        if (candidate / 'CoverMeter.vh').is_file():
            return candidate.resolve()
    raise ValueError('CoverMeter.vh not found; set VCS_INCLUDE to the selected VCS include directory')


def main():
    test, mode, seed, options = arguments(sys.argv[1:])
    manifest, sources = check()
    coverage = os.environ.get('COVERAGE', '1')
    if coverage not in ('0', '1'):
        raise ValueError('COVERAGE must be 0 or 1')
    backend = os.environ.get('COV_BACKEND', 'runtime') if coverage == '1' else 'off'
    if backend not in ('runtime', 'collect', 'off') or (coverage == '1' and backend == 'off'):
        raise ValueError('COV_BACKEND must be runtime or collect; COVERAGE=0 disables code coverage')
    verbosity = os.environ.get('UVM_VERBOSITY', 'UVM_LOW')
    if verbosity not in ('UVM_NONE', 'UVM_LOW', 'UVM_MEDIUM', 'UVM_HIGH', 'UVM_FULL', 'UVM_DEBUG'):
        raise ValueError('Invalid UVM_VERBOSITY')
    if os.environ.get('CHECK_ONLY') == '1':
        print('V2_UVM_FILE_CHECK_PASS test={} mode={} seed={} backend={}; no compilation/simulation'.format(test, mode, seed, backend))
        return 0
    binary = shutil.which(os.environ.get('VCS_BIN', 'vcs'))
    if not binary:
        raise ValueError('VCS not found; set VCS_BIN to the actual compiler path')
    include = include_directory(binary) if backend == 'runtime' else None
    flags = [binary, '-full64', '-sverilog', '-timescale=1ns/1ps', '+vcs+lic+wait',
             '-debug_access+all', '-ntb_opts', 'uvm-1.2', '-f', 'uvm/sim/filelist.f', '-top', 'tb_ace_clci_2die_smoke']
    if coverage == '1':
        flags += ['-cm', 'line+cond+tgl+branch+fsm', '-cm_hier', 'uvm/sim/coverage_hierarchy.cfg']
    if include:
        flags += ['+define+ACE_V2_UVM_RUNTIME_COV', '+incdir+' + str(include)]
    fingerprint = hashlib.sha256(('\n'.join(flags) + '\n' + str(ROOT)).encode())
    for path in sorted(set(sources + list((ROOT / 'uvm').glob('*.sv*')) +
                           [ROOT / 'uvm/sim/filelist.f', ROOT / 'uvm/sim/coverage_hierarchy.cfg'])):
        fingerprint.update(path.read_bytes())
    if include:
        fingerprint.update((include / 'CoverMeter.vh').read_bytes())
    fingerprint.update(str(Path(binary).stat().st_mtime_ns).encode())
    build_id = fingerprint.hexdigest()[:16]
    build = ROOT / 'uvm/out/build' / build_id
    stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S') + '_' + uuid.uuid4().hex[:6]
    run = ROOT / 'uvm/out' / '{}_mode{}_burst{}_seed{}_{}'.format(test, mode, options['BURST_BEATS'], seed, stamp)
    run.mkdir(parents=True, exist_ok=False)
    build.mkdir(parents=True, exist_ok=True)
    record = {'test': test, 'data_mode': mode, 'seed': seed, 'options': options,
              'run_kind': ('negative' if test == 'ace_v2_error_status_test' else 'diagnostic' if test == 'ace_v2_data_alias_diag_test' else 'normal'),
              'backend': backend, 'ace_commit': manifest['ace_commit'], 'build_id': build_id,
              'plan': 'ace_v2_44', 'run_dir': str(run), 'vcs': binary,
              'verification_checksums': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(list((ROOT / 'uvm').glob('*.sv*')) + [ROOT / 'uvm/sim/coverage_plan.json'])},
              'source_checksums': {p['path']: p['sha256'] for p in manifest['files']}}
    (run / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print('RUN_DIR=' + str(run), flush=True)
    # Concurrent runs may share a build, but never compile or copy it mid-write.
    with (build / 'compile.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not (build / 'compile.ok').is_file() or not (build / 'simv').is_file():
            command = flags + ['-Mdir=' + str(build / 'csrc'), '-o', str(build / 'simv'), '-l', str(build / 'compile.log')]
            if coverage == '1':
                command += ['-cm_dir', str(build / 'coverage.vdb')]
            print('Compiling; log: ' + str(build / 'compile.log'), flush=True)
            with (build / 'compile.console.log').open('w') as stream:
                result = subprocess.run(command, cwd=str(ROOT), stdout=stream, stderr=subprocess.STDOUT)
            if result.returncode:
                print('COMPILE_FAIL: ' + str(build / 'compile.console.log'), file=sys.stderr)
                return result.returncode
            (build / 'compile.ok').write_text(build_id + '\n')
        else:
            print('Reusing matching compiled build: ' + build_id, flush=True)
        if coverage == '1':
            if not (build / 'coverage.vdb').is_dir():
                raise ValueError('Compiled coverage database missing; remove this build directory and compile again')
            shutil.copytree(str(build / 'coverage.vdb'), str(run / 'coverage.vdb'))
    command = [str(build / 'simv'), '+UVM_TESTNAME=' + test, '+DATA_MODE=' + str(mode),
               '+ntb_random_seed=' + str(seed), '+CODE_COV=' + backend,
               '+REPORT_DIR=' + str(run), '+CLCI_ROM_INIT=clci/rom/TS3N28HPCPA4096X64M16MBS.rom.v']
    command += ['+' + key if value is None else '+' + key + '=' + str(value) for key, value in options.items()]
    if coverage == '1':
        command += ['-cm', 'line+cond+tgl+branch+fsm', '-cm_dir', str(run / 'coverage.vdb')]
    command += ['+UVM_VERBOSITY=' + verbosity, '-l', str(run / 'run.log')]
    record['command'] = command
    (run / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    with (run / 'console.log').open('w') as capture:
        process = subprocess.Popen(command, cwd=str(ROOT), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   universal_newlines=True, errors='replace')
        for line in process.stdout:
            print(line, end='', flush=True)
            capture.write(line)
        sim_rc = process.wait()
    log = (run / 'run.log').read_text(errors='replace') if (run / 'run.log').is_file() else ''
    bad = re.search(r'^(?:Error[-:]|Fatal[-:]|%Error)|ACE_V2_UVM_FAIL|DIAGNOSTIC_FAIL', log, re.MULTILINE)
    uvm_bad = re.search(r'^\s*UVM_(?:ERROR|FATAL)(?:\s+[^:\s]|\s*:\s*[1-9]\d*)', log, re.MULTILINE)
    passed = not uvm_bad and sim_rc == 0 and re.search(r'^ACE_V2_UVM_PASS\s*$', log, re.MULTILINE) and not bad
    record['simulation_pass'] = bool(passed)
    record['simulation_exit'] = sim_rc
    (run / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print('SIMULATION_RESULT=' + ('PASS' if passed else 'FAIL'), flush=True)
    result = subprocess.run([sys.executable, str(ROOT / 'uvm/sim/report.py'), str(run)], cwd=str(ROOT))
    print('REPORT_RESULT=' + ('PASS' if result.returncode == 0 else 'FAIL'), flush=True)
    return 0 if passed and result.returncode == 0 else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as exc:
        print('V2_UVM_RUN_ERROR: ' + str(exc), file=sys.stderr)
        sys.exit(2)
