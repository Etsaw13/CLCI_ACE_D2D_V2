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

LIMITS = {
    'TX_TARGET': (1, 100000), 'BURST_BEATS': (2, 256), 'PRBS_CODE': (0, 255),
    'XCODE': (0, 255), 'SNOOP_GAP': (0, 255), 'LINK_TIMEOUT_US': (1, 100000),
    'RUN_TIMEOUT_US': (1, 100000), 'GLOBAL_TIMEOUT_US': (1, 100000),
    'DRAIN_TIMEOUT_CYC': (16, 10000000), 'PROGRESS_US': (0, 1000)}


def arguments(argv):
    if argv and argv[0] in ('-h', '--help'):
        print('Usage: bash dv/sim/run.sh [apb|smoke|burst_boundary|uc_rs_sc|cr_unique|cr_shared|dirty_readonce|data_alias] [mode 0..5] [seed] [+KEY=VALUE ...]')
        print('Numeric keys: ' + ', '.join(LIMITS))
        print('Other keys: +DIRECTION=write|read +BASE_ADDR=<hex> +APB_TRACE')
        print('Default: smoke, mode=0, seed=1, TX_TARGET=64, BURST_BEATS=4.')
        print('burst_boundary defaults to TX_TARGET=1 and requires exactly that setting.')
        print('uc_rs_sc/cr_unique/cr_shared use fixed APB phases; no TX_TARGET/BURST_BEATS/DIRECTION override; SNOOP_GAP=255.')
        print('Environment: CHECK_ONLY=1, COVERAGE=0|1, COV_BACKEND=runtime|collect, VCS_BIN, VCS_INCLUDE, PYTHON_BIN.')
        sys.exit(0)
    test = argv[0] if argv else 'smoke'
    mode = argv[1] if len(argv) > 1 else '0'
    seed = argv[2] if len(argv) > 2 else '1'
    if test not in ('apb', 'smoke', 'burst_boundary', 'uc_rs_sc', 'cr_unique', 'cr_shared',
                    'dirty_readonce', 'data_alias') or not re.fullmatch('[0-5]', mode):
        raise ValueError('Invalid test/mode; use --help')
    if not re.fullmatch('[0-9]{1,10}', seed) or not 1 <= int(seed) <= 2147483647:
        raise ValueError('Seed must be 1..2147483647')
    target = {'burst_boundary': 1, 'uc_rs_sc': 2, 'cr_unique': 6, 'cr_shared': 3,
              'dirty_readonce': 7, 'data_alias': 2}.get(test, 64)
    options = {'TX_TARGET': target, 'BURST_BEATS': 4}
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
        elif key == 'DIRECTION' and text in ('write', 'read'):
            options[key] = text
        elif key == 'BASE_ADDR' and text and re.fullmatch(r'(?:0[xX])?[0-9a-fA-F]{1,11}', text):
            number = int(text, 16)
            if number % 16:
                raise ValueError('BASE_ADDR must be 16-byte aligned')
            options[key] = format(number, 'x')
        elif key == 'APB_TRACE' and text is None:
            options[key] = None
        else:
            raise ValueError('Unsupported argument: ' + value)
    if test == 'burst_boundary' and options['TX_TARGET'] != 1:
        raise ValueError('burst_boundary uses TX_TARGET=1; run each direction/length separately')
    if test in ('uc_rs_sc', 'cr_unique', 'cr_shared'):
        for key in ('TX_TARGET', 'BURST_BEATS', 'DIRECTION'):
            if key in seen:
                raise ValueError(test + ' uses a fixed single-write/APB phase flow; do not set ' + key)
        if 'SNOOP_GAP' in options and options['SNOOP_GAP'] != 255:
            raise ValueError(test + ' requires SNOOP_GAP=255 for APB phase control')
        options['SNOOP_GAP'] = 255
    base = int(str(options.get('BASE_ADDR', '20000000')), 16)
    if test in ('dirty_readonce', 'data_alias'):
        if seen.intersection(('TX_TARGET', 'BURST_BEATS', 'DIRECTION')):
            raise ValueError(test + ' uses fixed four-beat APB phases')
        if base % 4096 + 112 > 4096 or base + 111 >= 1 << 44:
            raise ValueError(test + ' requires room for seven lines in one 4KB page')
    if test == 'burst_boundary' and (base % 4096) + options['BURST_BEATS'] * 16 > 4096:
        raise ValueError('Boundary start address/length crosses 4KB')
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
    if os.environ.get('CHECK_ONLY') == '1':
        print('V2_DV_FILE_CHECK_PASS test={} mode={} seed={} backend={}; no compilation/simulation'.format(test, mode, seed, backend))
        return 0
    binary = shutil.which(os.environ.get('VCS_BIN', 'vcs'))
    if not binary:
        raise ValueError('VCS not found; set VCS_BIN to the actual compiler path')
    include = include_directory(binary) if backend == 'runtime' else None
    flags = [binary, '-full64', '-sverilog', '-timescale=1ns/1ps', '+vcs+lic+wait',
             '-debug_access+all', '-f', 'dv/sim/filelist.f', '-top', 'tb_ace_clci_2die_smoke']
    if coverage == '1':
        flags += ['-cm', 'line+cond+tgl+branch+fsm', '-cm_hier', 'dv/sim/coverage_hierarchy.cfg']
    if include:
        flags += ['+define+ACE_V2_RUNTIME_COV', '+incdir+' + str(include)]
    fingerprint = hashlib.sha256(('\n'.join(flags) + '\n' + str(ROOT)).encode())
    for entry in sorted(manifest['files'], key=lambda asset: asset['path']):
        fingerprint.update((entry['path'] + '\0' + entry['sha256'] + '\n').encode())
    for path in sorted(set(sources + list((ROOT / 'dv').glob('*.sv*')) +
                           [ROOT / 'dv/sim/filelist.f', ROOT / 'dv/sim/coverage_hierarchy.cfg'])):
        fingerprint.update(path.read_bytes())
    if include:
        fingerprint.update((include / 'CoverMeter.vh').read_bytes())
    fingerprint.update(str(Path(binary).stat().st_mtime_ns).encode())
    build_id = fingerprint.hexdigest()[:16]
    build = ROOT / 'dv/out/build' / build_id
    stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S') + '_' + uuid.uuid4().hex[:6]
    run = ROOT / 'dv/out' / '{}_mode{}_burst{}_seed{}_{}'.format(test, mode, options['BURST_BEATS'], seed, stamp)
    run.mkdir(parents=True, exist_ok=False)
    build.mkdir(parents=True, exist_ok=True)
    record = {'test': test, 'data_mode': mode, 'seed': seed, 'options': options,
              'backend': backend, 'ace_commit': manifest['ace_commit'], 'build_id': build_id,
              'plan': 'ace_v2_44', 'run_dir': str(run), 'vcs': binary,
              'verification_checksums': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(list((ROOT / 'dv').glob('*.sv*')) + [ROOT / 'dv/sim/coverage_plan.json'])},
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
    command = [str(build / 'simv'), '+TEST=' + test, '+DATA_MODE=' + str(mode),
               '+ntb_random_seed=' + str(seed), '+CODE_COV=' + backend,
               '+REPORT_DIR=' + str(run), '+CLCI_ROM_INIT=clci/rom/TS3N28HPCPA4096X64M16MBS.rom.v']
    command += ['+' + key if value is None else '+' + key + '=' + str(value) for key, value in options.items()]
    if coverage == '1':
        command += ['-cm', 'line+cond+tgl+branch+fsm', '-cm_dir', str(run / 'coverage.vdb')]
    command += ['-l', str(run / 'run.log')]
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
    bad = re.search(r'^(?:Error[-:]|Fatal[-:]|DV_FAIL|DV_CHECK_FAIL)|ACE_V2_DV_FAIL', log, re.MULTILINE)
    passed = sim_rc == 0 and re.search(r'^ACE_V2_DV_PASS\s*$', log, re.MULTILINE) and not bad
    record['simulation_pass'] = bool(passed)
    record['simulation_exit'] = sim_rc
    (run / 'run.json').write_text(json.dumps(record, indent=2) + '\n')
    print('SIMULATION_RESULT=' + ('PASS' if passed else 'FAIL'), flush=True)
    result = subprocess.run([sys.executable, str(ROOT / 'dv/sim/report.py'), str(run)], cwd=str(ROOT))
    print('REPORT_RESULT=' + ('PASS' if result.returncode == 0 else 'FAIL'), flush=True)
    return 0 if passed and result.returncode == 0 else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as exc:
        print('V2_DV_RUN_ERROR: ' + str(exc), file=sys.stderr)
        sys.exit(2)
