#!/usr/bin/env python3
"""Run a UVM suite and report results from that batch only."""
import argparse
from collections import namedtuple
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / 'out'
CaseResult = namedtuple('CaseResult', 'passed simulation report exit_code run_dir kind')


def case(name, mode=0, *options):
    return ('ace_v2_' + name + '_test', str(mode), '1') + options


def suites():
    burst_tests = ('burst_write', 'burst_read')
    smoke = [case('smoke', mode) for mode in range(6)]
    basic = [case(name) for name in ('apb', 'single_write', 'single_read') + burst_tests +
             ('snoop_stress', 'pause_resume')]
    boundary = [case(name, 0, '+TX_TARGET=1', '+BURST_BEATS={}'.format(beats))
                for name in burst_tests for beats in (2, 3, 4, 5, 8, 16, 255, 256)]
    cache_snoop = [case('cr_unique'), case('cr_shared')]
    integrity = [case('dirty_readonce', 2), case('data_alias', 2)]
    recovery = [case('error_status')]
    legacy_cache = [case('uc_rs_sc')] + cache_snoop
    return {
        'smoke': smoke, 'basic': basic, 'burst_boundary': boundary, 'cache_snoop': cache_snoop,
        'data_integrity': integrity, 'error_recovery': recovery,
        'coverage_targets': smoke + cache_snoop + boundary,
        'all': integrity + basic + smoke + cache_snoop + boundary + recovery,
        'directed': basic[:1] + smoke[:1] + basic[1:], 'boundary': boundary, 'cache': legacy_cache,
        'coverage': smoke + legacy_cache + boundary, 'fixes': integrity, 'negative': recovery,
    }


def execute_case(arguments, log, check_only):
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run(['bash', str(HERE / 'run.sh'), *arguments], stdout=stream,
                                stderr=subprocess.STDOUT)
    code = result.returncode
    if check_only:
        return CaseResult(code == 0, 'NOT_RUN', 'NOT_RUN', code, None, None)

    simulation = report = 'NOT_RUN'
    directory = kind = None
    try:
        with log.open(encoding='utf-8', errors='replace') as stream:
            for line in stream:
                if line.startswith('RUN_DIR='):
                    candidate = Path(line.rstrip('\r\n').split('=', 1)[1]).resolve()
                    if directory is not None or candidate.parent != OUT.resolve():
                        raise ValueError('Invalid or repeated RUN_DIR')
                    directory = candidate
                elif line.rstrip() in ('REPORT_RESULT=PASS', 'REPORT_RESULT=FAIL'):
                    report = line.rstrip().split('=', 1)[1]
        if directory is not None:
            metadata = json.loads((directory / 'run.json').read_text(encoding='utf-8'))
            if (metadata['test'], metadata['data_mode'], metadata['seed']) != (
                    arguments[0], int(arguments[1]), int(arguments[2])):
                raise ValueError('RUN_DIR metadata differs from scheduled test')
            kind = metadata['run_kind']
            if 'simulation_pass' in metadata:
                simulation = 'PASS' if metadata['simulation_pass'] is True else 'FAIL'
    except (OSError, ValueError, KeyError, TypeError) as exc:
        with log.open('a', encoding='utf-8') as stream:
            print('REGRESSION_CASE_ERROR: ' + str(exc), file=stream)
    passed = code == 0 and simulation == report == 'PASS'
    return CaseResult(passed, simulation, report, code, directory, kind)


def generate_report(command, report, log):
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run([sys.executable, '-B', *command], stdout=stream,
                                stderr=subprocess.STDOUT)
    if result.returncode == 0 and report.is_file():
        return 'PASS', report.read_text(encoding='utf-8').rstrip()
    return 'FAIL', 'See {}\n{}'.format(log.name, log.read_text(encoding='utf-8', errors='replace').rstrip())


def coverage_reports(batch, results, check_only):
    runs = [str(result.run_dir) for result in results
            if result.simulation == 'PASS' and result.kind == 'normal']
    if not runs:
        reason = 'parameter checks only' if check_only else 'no passed normal simulations in this batch'
        return ('SKIP', reason), ('SKIP', reason)

    functional = batch / 'functional_coverage.txt'
    functional_result = generate_report([str(HERE / 'report.py'), *runs, '--functional-only',
                                         '--summary', str(functional)], functional,
                                        batch / 'functional_coverage.log')
    if os.environ.get('COVERAGE', '1') == '0':
        return functional_result, ('SKIP', 'COVERAGE=0')
    if os.environ.get('COV_BACKEND', 'runtime') == 'collect':
        return functional_result, ('SKIP', 'COV_BACKEND=collect; the native union requires runtime counts')

    native = batch / 'code_coverage'
    command = [str(HERE / 'merge_code_coverage.py'), '--output', str(native)]
    for run in runs:
        command.extend(('--run', run))
    code_result = generate_report(command, native / 'summary.txt', batch / 'code_coverage.log')
    return functional_result, code_result


def main():
    plans = suites()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suite', nargs='?', choices=plans,
                        help='Default: smoke. Use --list to see test counts and members.')
    parser.add_argument('--list', action='store_true', help='List suites or preview the selected suite without running')
    args = parser.parse_args()
    if args.list and args.suite is None:
        for name, plan in plans.items():
            print('{:<20} {:>2} run(s)'.format(name, len(plan)))
        return 0

    suite = args.suite or 'smoke'
    plan = plans[suite]
    if args.list:
        for arguments in plan:
            print(' '.join(arguments))
        return 0

    check_only = os.environ.get('CHECK_ONLY') == '1'
    stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S') + '_' + uuid.uuid4().hex[:6]
    batch = OUT / 'regression' / (suite + '_' + stamp)
    logs = batch / 'cases'
    logs.mkdir(parents=True, exist_ok=False)
    print('REGRESSION_DIR=' + str(batch), flush=True)
    results, rows = [], [' #  Result  Simulation  Report   Exit  Test / mode / seed / overrides']
    for index, arguments in enumerate(plan, 1):
        label = ' '.join(arguments)
        print('[{}/{}] {}'.format(index, len(plan), label), flush=True)
        log = logs / '{:02d}_{}.log'.format(index, arguments[0])
        result = execute_case(arguments, log, check_only)
        results.append(result)
        status = 'PASS' if result.passed else 'FAIL'
        rows.append('{:2}  {:6}  {:10}  {:7}  {:4}  {}'.format(
            index, status, result.simulation, result.report, result.exit_code, label))
        if not result.passed:
            rows.append('    Log: ' + str(log.relative_to(batch)))
        print('  {} (simulation={}, report={}, exit={})'.format(
            status, result.simulation, result.report, result.exit_code), flush=True)

    functional, code = coverage_reports(batch, results, check_only)
    passed = sum(result.passed for result in results)
    ok = passed == len(plan) and functional[0] != 'FAIL' and code[0] != 'FAIL'
    finish_key = 'REGRESSION_CHECK_RESULT' if check_only else 'REGRESSION_RESULT'
    summary = '\n'.join([
        'UVM REGRESSION | suite={} | {}'.format(suite, 'parameter checks only' if check_only else 'simulation'),
        *rows, '', 'TOTAL: {} PASS, {} FAIL, {} scheduled'.format(passed, len(plan) - passed, len(plan)),
        '', 'FUNCTIONAL_COVERAGE=' + functional[0], functional[1],
        '', 'CODE_COVERAGE=' + code[0], code[1], '', finish_key + '=' + ('PASS' if ok else 'FAIL'),
    ]) + '\n'
    report = batch / 'summary.txt'
    report.write_text(summary, encoding='utf-8')
    print('\n' + summary, end='')
    if code[0] == 'PASS':
        print('OPEN_HTML=' + str(batch / 'code_coverage' / 'index.html'))
    print('REGRESSION_SUMMARY=' + str(report))
    return 0 if ok else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except OSError as exc:
        print('REGRESSION_ERROR: ' + str(exc), file=sys.stderr)
        sys.exit(2)
