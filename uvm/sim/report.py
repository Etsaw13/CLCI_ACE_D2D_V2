#!/usr/bin/env python3
"""Strict named-bin report. Cross-run code-point union is never fabricated."""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLAN = json.loads((HERE / 'coverage_plan.json').read_text())
METRICS = ('line', 'condition', 'toggle', 'fsm_state', 'fsm_transition', 'branch')


def functional(path):
    lines = path.read_text().splitlines()
    expected_header = r'ACE_V2_UVM_FUNCTIONAL\s+version=1\s+plan=ace_v2_44\s+completion=\s*FINAL\s*'
    if not lines or not re.fullmatch(expected_header, lines[0]):
        raise ValueError('Missing, partial or incompatible functional report: ' + str(path))
    bins, cache, cd = {}, {}, None
    for line in lines[1:]:
        match = re.fullmatch(r'BIN metric=(\d+) bin=(\d+) hits=(\d+)', line)
        if match:
            metric, number, count = map(int, match.groups())
            if not 0 <= metric < len(PLAN['metrics']) or not 0 <= number < len(PLAN['metrics'][metric]['bins']):
                raise ValueError('Unplanned functional bin: ' + line)
            if (metric, number) in bins:
                raise ValueError('Duplicate functional bin: ' + line)
            bins[metric, number] = count
            continue
        match = re.fullmatch(r'CACHE goal=(\d+) attempted=(\d+) matched=(\d+) conflict=(\d+) unmatched=(\d+)', line)
        if match:
            goal, attempted, matched, conflict, unmatched = map(int, match.groups())
            if goal not in range(6) or goal in cache or attempted != matched + conflict + unmatched:
                raise ValueError('Invalid cache diagnostics: ' + line)
            cache[goal] = matched
            continue
        match = re.fullmatch(r'CD expected=(\d+) delivered=(\d+)', line)
        if match and cd is None:
            cd = tuple(map(int, match.groups()))
            if cd[0] != cd[1]:
                raise ValueError('CD obligations did not close: ' + line)
            continue
        raise ValueError('Malformed functional record: ' + line)
    if len(bins) != 44 or len(cache) != 6 or cd is None:
        raise ValueError('Incomplete functional report: ' + str(path))
    for goal, count in cache.items():
        if bins[8, goal] != count:
            raise ValueError('Cache evidence count differs from named-bin count')
    return bins


def runtime(path):
    lines = path.read_text().splitlines()
    if not lines or not re.fullmatch(r'ACE_V2_UVM_RUNTIME\s+version=1\s+completion=\s*FINAL\s*', lines[0]):
        raise ValueError('Missing/partial runtime report: ' + str(path))
    if len(lines) < 2 or lines[1] != 'SCOPE master=tb_ace_clci_2die_smoke.u_master slave=tb_ace_clci_2die_smoke.u_slave':
        raise ValueError('Unexpected runtime coverage scope')
    rows = {}
    for line in lines[2:]:
        if not line.startswith('CODE '):
            raise ValueError('Malformed runtime row: ' + line)
        fields = dict(item.split('=', 1) for item in line.split()[1:])
        key = fields.get('scope'), fields.get('metric')
        if key[0] not in ('master', 'slave', 'ace_pair') or key[1] not in METRICS or key in rows:
            raise ValueError('Unexpected/duplicate runtime scope or metric')
        status = fields.get('status')
        if status == 'OK':
            covered, total = int(fields['covered']), int(fields['total'])
            if not 0 <= covered <= total or total <= 0:
                raise ValueError('Invalid native coverage counts')
            if abs(float(fields['coverage'].rstrip('%')) - 100.0 * covered / total) > .011:
                raise ValueError('Coverage percentage differs from counts')
            if key[0] != 'ace_pair' and (int(fields['check_status']) != 0 or
                covered != int(fields['raw_covered']) or total != int(fields['raw_total'])):
                raise ValueError('Native status/raw count mismatch')
        elif status == 'NA':
            if any(fields.get(name) != 'NA' for name in ('covered', 'total', 'coverage')):
                raise ValueError('N/A metric has invented counts')
            if fields.get('check_status') == '-3':
                raise ValueError('Partial native coverage scope')
        else:
            raise ValueError('Unknown runtime status')
        rows[key] = fields
    if len(rows) != 18:
        raise ValueError('Incomplete runtime metrics')
    for scope in ('master', 'slave'):
        if rows[scope, 'line']['status'] != 'OK':
            raise ValueError('Required native line coverage unavailable: ' + scope)
    for metric in METRICS:
        a, b, pair = (rows[scope, metric] for scope in ('master', 'slave', 'ace_pair'))
        if a['status'] == b['status'] == 'OK':
            if pair['status'] != 'OK' or int(pair['covered']) != int(a['covered']) + int(b['covered']) or int(pair['total']) != int(a['total']) + int(b['total']):
                raise ValueError('ACE-pair coverage must combine the two disjoint scopes by counts')
        elif pair['status'] != 'NA':
            raise ValueError('ACE-pair metric invented despite unavailable scope')
    return rows


def report(directories, summary=None):
    merged, loaded, signature = {}, [], None
    for directory in directories:
        directory = directory.resolve()
        metadata = json.loads((directory / 'run.json').read_text())
        if metadata.get('run_kind') not in ('normal', 'negative', 'diagnostic'):
            raise ValueError('Missing/invalid run category')
        log = (directory / 'run.log').read_text(errors='replace')
        if metadata.get('simulation_pass') is not True or not re.search(r'^ACE_V2_UVM_PASS\s*$', log, re.MULTILINE) or re.search(r'^\s*UVM_(?:ERROR|FATAL)(?:\s+[^:\s]|\s*:\s*[1-9]\d*)', log, re.MULTILINE):
            raise ValueError('Run has no verified simulation PASS: ' + str(directory))
        current = (metadata['ace_commit'], json.dumps(metadata['source_checksums'], sort_keys=True),
                   json.dumps(metadata['verification_checksums'], sort_keys=True), metadata['plan'])
        if signature is not None and current != signature:
            raise ValueError('Cannot merge differing design versions or coverage plans')
        signature = current
        if len(directories) > 1 and metadata['run_kind'] != 'normal':
            raise ValueError('Negative/diagnostic results must be reported separately from normal coverage merging')
        bins = functional(directory / 'functional_coverage.txt')
        for key, count in bins.items():
            merged[key] = merged.get(key, 0) + count
        loaded.append((directory, metadata))
    text = ['ACE FUNCTIONAL COVERAGE | plan=ace_v2_44 | {} run(s)'.format(len(loaded)),
            '{:<11} {:<22} {:>9} {:>10}'.format('Group', 'Item', 'Hit/Plan', 'Coverage')]
    for metric in PLAN['metrics']:
        hit = sum(merged[metric['id'], n] > 0 for n in range(len(metric['bins'])))
        total = len(metric['bins'])
        text.append('{:<11} {:<22} {:>9} {:>9.1f}%'.format(metric['group'], metric['name'], '{}/{}'.format(hit, total), 100.0 * hit / total))
    text += ['', 'NOT COVERED']
    missing_any = False
    for metric in PLAN['metrics']:
        missing = [name for n, name in enumerate(metric['bins']) if not merged[metric['id'], n]]
        if missing:
            missing_any = True
            text.append('  {}: {}'.format(metric['name'], ', '.join(missing)))
    if not missing_any:
        text.append('  none')
    text += ['', 'Data mode bins count exercised configurations; data correctness is checked separately.',
             'Cache bins require correlated before/after and response/data evidence; unmatched attempts remain diagnostic.',
             '', 'CHECK RESULTS']
    for directory, metadata in loaded:
        summaries = re.findall(r'^UVM_ACE_SUMMARY .+$', (directory / 'run.log').read_text(errors='replace'), re.MULTILINE)
        if len(summaries) != 1:
            raise ValueError('Expected exactly one final transaction summary')
        text.append('  PASS (' + metadata['run_kind'] + '): ' + directory.name)
        text.append('    ' + summaries[0][len('UVM_ACE_SUMMARY '):])
    text += ['', 'ACE CODE COVERAGE | master/module_a and slave/module_b only']
    for directory, metadata in loaded:
        if metadata['backend'] == 'runtime':
            rows = runtime(directory / 'runtime_code_coverage.txt')
            text.append('Run: ' + directory.name)
            text.append('{:<18} {:>22} {:>22} {:>22}'.format('Metric', 'Master', 'Slave', 'ACE pair'))
            for metric in METRICS:
                values = []
                for scope in ('master', 'slave', 'ace_pair'):
                    row = rows[scope, metric]
                    values.append('{}/{} {}'.format(row['covered'], row['total'], row['coverage']) if row['status'] == 'OK' else 'N/A')
                text.append('{:<18} {:>22} {:>22} {:>22}'.format(metric, *values))
        else:
            text.append('{}: {}'.format(directory.name, 'database collected; runtime percentages not requested' if metadata['backend'] == 'collect' else 'code coverage disabled'))
    text += ['Window: time zero through reset, boot, traffic and final drain.',
             'Line is VCS basic-block coverage; branch is N/A in the legacy runtime API.',
             'Cross-run code-point union is not derived from aggregate counts. Preserve every coverage.vdb.']
    rendered = '\n'.join(text) + '\n'
    if summary:
        summary.write_text(rendered)
    print(rendered, end='')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runs', nargs='+', type=Path)
    parser.add_argument('--summary', type=Path)
    args = parser.parse_args()
    directories = [p.resolve() for p in args.runs]
    if len(set(directories)) != len(directories):
        raise ValueError('Duplicate run directory')
    summary = args.summary or (directories[0] / 'coverage_summary.log' if len(directories) == 1 else None)
    report(directories, summary)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as exc:
        print('COVERAGE_REPORT_ERROR: ' + str(exc), file=sys.stderr)
        sys.exit(1)
