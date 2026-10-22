#!/usr/bin/env python3
"""VCS V-2023.12-SP2 native-point union and offline source viewer.

Read-only inputs. No URG/Verdi, no simulation, no third-party Python packages.
This is a report adapter, NOT a writer of Synopsys merged coverage databases.
"""
import argparse
import collections
import csv
import datetime
import gzip
import hashlib
import html
import json
import re
import sys
from pathlib import Path, PurePosixPath
import xml.etree.ElementTree as ET
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parents[1]
ENVIRONMENT = 'dv'
SCOPES = {'master': 'tb_ace_clci_2die_smoke.u_master',
          'slave': 'tb_ace_clci_2die_smoke.u_slave'}
DEFINITIONS = {'line': 'linedef', 'cond': 'conddef', 'tgl': 'tgldef',
               'fsm': 'fsmdef', 'branch': 'branch_def'}
LABELS = {'line': 'Line basic blocks', 'cond': 'Condition vectors',
          'tgl': 'Toggle native slots (*)', 'fsm': 'FSM states+transitions (*)',
          'branch': 'Branch native slots (*)'}
SUPPORTED = ('13', '1', 'V-2023.12-SP2')
API_METRICS = ('line', 'condition', 'toggle', 'fsm_state', 'fsm_transition', 'branch')


def emit(s):
    enc = sys.stdout.encoding or 'utf-8'
    sys.stdout.write((str(s) + '\n').encode(enc, 'backslashreplace').decode(enc))
    sys.stdout.flush()


def fail(message):
    raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def inside(path, root):
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def tag(e):
    return e.tag.rsplit('}', 1)[-1]


def one(items, description):
    if len(items) != 1:
        fail('Expected exactly one {} (found {})'.format(description, len(items)))
    return items[0]


def load_xml(path):
    with path.open('rb') as stream:
        compressed = stream.read(2) == b'\x1f\x8b'
    with (gzip.open if compressed else open)(str(path), 'rb') as stream:
        return ET.parse(stream).getroot()


def xml_file(db, filename, required=True):
    paths = [p for p in db.rglob(filename + '*')
             if p.is_file() and p.name in (filename, filename + '.gz')]
    if not paths and not required:
        return None
    path = one(paths, filename + ' under ' + str(db))
    if not inside(path.resolve(), db.resolve()):
        fail('VDB XML symlink escapes database: ' + str(path))
    return path


def version(root, description):
    e = one([e for e in root.iter() if tag(e) == 'ucapi_version'],
            'ucapi_version in ' + description)
    result = tuple(e.get(k) for k in ('major_ver', 'minor_ver', 'patch_str'))
    if result != SUPPORTED:
        fail('Unsupported native XML profile {} in {}'.format(result, description))
    return result


def exclusion_metadata(db, family):
    # Some native VDBs omit the auxiliary exclusion XML for a metric.
    # Record absence; never create a file or remove points from the raw bitmap.
    path = xml_file(db, family + '.verilog.exclude.xml', required=False)
    if path is None:
        return {'status': 'absent', 'path': None, 'sha256': None}
    root = load_xml(path)
    if any(tag(e) == 'ucapi_version' for e in root.iter()):
        version(root, family + ' exclusion metadata')
    if any(tag(e) != 'ucapi_version' for e in root.iter() if e is not root):
        fail('Nonempty native exclusion file unsupported: ' + str(path))
    return {'status': 'present_empty', 'path': str(path.relative_to(db)),
            'sha256': sha(path.read_bytes())}


def canonical(e):
    # Attribute order and pretty-print whitespace are not coverage identities.
    return [tag(e), sorted(e.attrib.items()), (e.text or '').strip(),
            [canonical(c) for c in e]]


def fingerprint(e):
    return sha(json.dumps(canonical(e), sort_keys=True).encode('utf-8'))


def parse_runtime(path, env):
    lines = path.read_text(encoding='utf-8').splitlines()
    prefix = 'ACE_V2_UVM_RUNTIME' if env == 'uvm' else 'ACE_V2_RUNTIME'
    if not lines or not re.fullmatch(prefix + r'\s+version=1\s+completion=\s*FINAL\s*', lines[0]):
        fail('Missing/partial runtime report: ' + str(path))
    expected = 'SCOPE master=' + SCOPES['master'] + ' slave=' + SCOPES['slave']
    if len(lines) < 2 or lines[1] != expected:
        fail('Unexpected runtime scopes: ' + str(path))
    rows = {}
    for line in lines[2:]:
        if not line.startswith('CODE '):
            fail('Malformed runtime row: ' + line)
        fields = dict(item.split('=', 1) for item in line.split()[1:])
        key = (fields.get('scope'), fields.get('metric'))
        if key in rows or key[0] not in ('master', 'slave', 'ace_pair') or key[1] not in API_METRICS:
            fail('Unexpected/duplicate runtime row: ' + line)
        if fields.get('status') == 'OK':
            covered, total = int(fields['covered']), int(fields['total'])
            if not 0 <= covered <= total or total <= 0:
                fail('Invalid runtime counts: ' + line)
            if abs(float(fields['coverage'].rstrip('%')) - covered * 100.0 / total) > .011:
                fail('Runtime percentage/count mismatch: ' + line)
            if key[0] != 'ace_pair' and (fields.get('check_status') != '0' or
                    covered != int(fields['raw_covered']) or total != int(fields['raw_total'])):
                fail('Runtime native check/raw count mismatch: ' + line)
        elif fields.get('status') == 'NA':
            if any(fields.get(k) != 'NA' for k in ('covered', 'total', 'coverage')) or fields.get('check_status') == '-3':
                fail('Invalid N/A or partial runtime result: ' + line)
        else:
            fail('Unknown runtime status: ' + line)
        rows[key] = fields
    if len(rows) != 18:
        fail('Incomplete runtime report: ' + str(path))
    for metric in API_METRICS:
        a, b, pair = (rows[s, metric] for s in ('master', 'slave', 'ace_pair'))
        if a['status'] == b['status'] == 'OK':
            if pair['status'] != 'OK' or any(int(pair[k]) != int(a[k]) + int(b[k]) for k in ('covered', 'total')):
                fail('Runtime disjoint-scope total mismatch for ' + metric)
        elif pair['status'] != 'NA':
            fail('Runtime pair invented from unavailable metric: ' + metric)
    return rows


def select_runs(root, env, explicit):
    out = (root / env / 'out').resolve()
    if not out.is_dir():
        fail('Missing ' + str(out) + '; run from the V2 project root.')
    candidates = [p.resolve() for p in explicit] if explicit else [p.parent.resolve() for p in sorted(out.glob('*/run.json'))]
    if len(candidates) != len(set(candidates)):
        fail('Duplicate run directory')
    loaded, skipped, signature = [], [], None
    for run in candidates:
        if not inside(run, out) or run == out:
            fail('Run does not belong to selected environment: ' + str(run))
        if run.name == 'build':
            continue
        info = json.loads((run / 'run.json').read_text(encoding='utf-8'))
        reason = None
        if info.get('simulation_pass') is not True:
            reason = 'failed_or_unfinished'
        kind = info.get('run_kind', 'normal' if env == 'dv' else None)
        if kind not in ('normal', 'negative', 'diagnostic'):
            fail('Missing/invalid run category: ' + str(run))
        if kind != 'normal':
            reason = kind
        if info.get('backend') != 'runtime':
            reason = 'requires_runtime_crosscheck'
        if reason:
            if explicit:
                fail('Explicit run is ineligible ({}): {}'.format(reason, run))
            skipped.append({'run': str(run), 'reason': reason})
            emit('SKIP {} {}'.format(reason, run.name))
            continue
        expected_kind = {'ace_v2_error_status_test': 'negative', 'ace_v2_data_alias_diag_test': 'diagnostic'}.get(info.get('test'))
        if expected_kind:
            fail('Test/category mismatch: ' + str(run))
        if type(info.get('simulation_exit')) is not int or info['simulation_exit'] != 0:
            fail('Missing/nonzero simulation exit: ' + str(run))
        if not info.get('test') or not info.get('ace_commit') or not info.get('source_checksums') or not info.get('verification_checksums'):
            fail('Incomplete run provenance: ' + str(run))
        if info.get('plan') != 'ace_v2_44':
            fail('Unsupported coverage plan: ' + str(run))
        log = (run / 'run.log').read_text(encoding='utf-8', errors='replace')
        marker = 'ACE_V2_UVM_PASS' if env == 'uvm' else 'ACE_V2_DV_PASS'
        summary = 'UVM_ACE_SUMMARY' if env == 'uvm' else 'DV_SUMMARY'
        if len(re.findall(r'^' + marker + r'\s*$', log, re.MULTILINE)) != 1 or len(re.findall(r'^' + summary + r' .+$', log, re.MULTILINE)) != 1:
            fail('Missing/duplicate simulation PASS or summary: ' + str(run))
        if re.search(r'^(?:Error[-:]|Fatal[-:]|%Error|DV_FAIL|DV_CHECK_FAIL)|ACE_V2_(?:DV|UVM)_FAIL|DIAGNOSTIC_FAIL', log, re.MULTILINE):
            fail('Error marker in passed run: ' + str(run))
        if env == 'uvm' and re.search(r'^\s*UVM_(?:ERROR|FATAL)(?:\s+[^:\s]|\s*:\s*[1-9]\d*)', log, re.MULTILINE):
            fail('UVM error/fatal in passed run: ' + str(run))
        current = json.dumps({k: info[k] for k in ('ace_commit', 'plan', 'source_checksums', 'verification_checksums')}, sort_keys=True)
        if signature is not None and signature != current:
            fail('Incompatible design/testbench provenance: ' + str(run) + '; select a compatible subset with repeated --run DIR.')
        signature = current
        loaded.append({'directory': run, 'metadata': info,
                       'runtime': parse_runtime(run / 'runtime_code_coverage.txt', env)})
    if not loaded:
        fail('No passed normal runtime-coverage runs found')
    return loaded, skipped


def checked_sources(root, checksums):
    sources = {}
    for name, expected in checksums.items():
        p = PurePosixPath(name)
        if p.is_absolute() or '..' in p.parts or not re.fullmatch('[0-9a-f]{64}', expected):
            fail('Invalid source manifest entry: ' + str(name))
        path = (root / name).resolve()
        if not inside(path, root) or not path.is_file():
            fail('Source missing or outside project: ' + str(path))
        data = path.read_bytes()
        if sha(data) != expected:
            fail('Current source differs from simulated source: ' + name)
        sources[name] = data.decode('utf-8', errors='strict').splitlines()
    return sources


def source_map(db, root, manifest):
    source = load_xml(xml_file(db, 'verilog.sourceinfo.xml'))
    version(source, 'sourceinfo')
    origin = PurePosixPath(source.get('name', ''))
    mapping, seen = {}, set()
    for e in source.iter():
        if tag(e) != 'fileinfo':
            continue
        key, name = e.get('id'), e.get('name')
        if key is None or name is None or key in seen:
            fail('Missing/duplicate native source file ID')
        seen.add(key)
        path = PurePosixPath(name)
        if path.is_absolute():
            try:
                path = path.relative_to(PurePosixPath(str(root)))
            except ValueError:
                try:
                    path = path.relative_to(origin) if origin.is_absolute() else path
                except ValueError:
                    pass
        relative = str(path)
        if not path.is_absolute() and '..' not in path.parts and relative in manifest:
            mapping[key] = relative
    return mapping


def definition(shape, family, checksum):
    return one([e for e in shape.iter() if tag(e) == DEFINITIONS[family] and e.get('chksum') == checksum],
               family + ' definition checksum=' + checksum)


def mapping_for_line(defn, filemap, sources, total):
    result = {}
    for block in defn.iter():
        if tag(block) != 'linebb':
            continue
        index = int(block.get('index', '-1'))
        if not 0 <= index < total or index in result:
            fail('Invalid/duplicate native line index: ' + str(index))
        if block.get('line_ignore', '0') != '0':
            fail('Unsupported ignored native basic block at index ' + str(index))
        refs = set()
        ignored_statements = []
        for node in [block] + [n for n in block.iter() if tag(n) == 'linestmt']:
            if node is not block and node.get('line_ignore', '0') != '0':
                # A child statement is a source annotation, not a bitmap slot.
                # Preserve its attributes for review without coloring that anchor.
                # The valid parent block and its native bit stay in the union.
                ignored_statements.append(dict(node.attrib))
                continue
            key = node.get('file_id', block.get('file_id'))
            number = int(node.get('line_num', '0'))
            name = filemap.get(key)
            if name is None or not 1 <= number <= len(sources[name]):
                fail('Unresolved/out-of-range source anchor file_id={} line={}'.format(key, number))
            refs.add((name, number))
        result[index] = {'references': [list(p) for p in sorted(refs)],
                         'signature': block.get('bbsig', ''),
                         'native_id': block.get('id'), 'native_type': block.get('type'),
                         'ignored_statement_annotations': ignored_statements}
    if not result:
        fail('No mappable native basic blocks')
    # Sparse native indices are real: retain them in denominators, never invent locations.
    return result


def check_runtime(family, bits, rows, scope):
    count, total = bits.count('1'), len(bits)
    metric = {'line': 'line', 'cond': 'condition'}.get(family)
    if metric:
        row = rows[scope, metric]
        if row['status'] != 'OK' or (count, total) != (int(row['covered']), int(row['total'])):
            fail('Native bitmap/runtime mismatch: {} {}'.format(scope, family))
        return 'exact_runtime_count_match'
    if family == 'fsm':
        a, b = (rows[scope, m] for m in ('fsm_state', 'fsm_transition'))
        if a['status'] != 'OK' or b['status'] != 'OK' or (count, total) != (int(a['covered']) + int(b['covered']), int(a['total']) + int(b['total'])):
            fail('Native combined FSM/runtime mismatch: ' + scope)
        return 'combined_states_and_transitions_match_runtime'
    if family == 'tgl':
        row = rows[scope, 'toggle']
        if row['status'] != 'OK' or total != 2 * int(row['total']):
            fail('Unsupported native toggle slot count: ' + scope)
        return 'two_native_slots_per_runtime_bit;pairing_not_calibrated'
    return 'native_binary_slots_only;legacy_branch_API_unavailable'


def read_run(record, root, sources):
    run = record['directory']
    db = run / 'coverage.vdb'
    if not db.is_dir():
        fail('Missing native database: ' + str(db))
    filemap = source_map(db, root, record['metadata']['source_checksums'])
    result = {}
    for family in DEFINITIONS:
        shape = load_xml(xml_file(db, family + '.verilog.shape.xml'))
        data_path = xml_file(db, family + '.verilog.data.xml')
        data = load_xml(data_path)
        version(shape, family + ' shape')
        version(data, family + ' data')
        exclusions = exclusion_metadata(db, family)
        for scope, fullname in SCOPES.items():
            instance = one([e for e in data.iter() if tag(e) == 'instance_data' and e.get('name') == fullname],
                           family + ' instance ' + fullname)
            bits = instance.get('value', '')
            checksum = instance.get('chksum', '')
            if not re.fullmatch('[01]+', bits) or not checksum:
                fail('Unsupported nonbinary/empty bitmap: {} {} {}'.format(run.name, scope, family))
            defn = definition(shape, family, checksum)
            confirmation = check_runtime(family, bits, record['runtime'], scope)
            pointmap = mapping_for_line(defn, filemap, sources, len(bits)) if family == 'line' else {}
            result[scope, family] = {'bitmap': bits, 'checksum': checksum,
                'definition_sha256': fingerprint(defn),
                'mapping': pointmap, 'validation': confirmation,
                'exclusion_metadata': exclusions,
                'data_sha256': sha(data_path.read_bytes()),
                'mapped_source_identity': sorted({tuple(ref) for p in pointmap.values() for ref in p['references']})}
    return result


def merge(records, root, sources):
    merged = {}
    for number, record in enumerate(records):
        emit('READ {}/{} {}'.format(number + 1, len(records), record['directory'].name))
        native = read_run(record, root, sources)
        record['native'] = native
        for key, data in native.items():
            if key not in merged:
                merged[key] = dict(data)
                merged[key]['bitmap'] = '0' * len(data['bitmap'])
            combined = merged[key]
            for field in ('checksum', 'definition_sha256', 'mapping', 'mapped_source_identity'):
                if combined[field] != data[field]:
                    fail('Incompatible {} {} {} in {}'.format(key[0], key[1], field, record['directory'].name))
            if len(combined['bitmap']) != len(data['bitmap']):
                fail('Native bitmap length changed: ' + str(key))
            combined['bitmap'] = ''.join('1' if a == '1' or b == '1' else '0'
                                         for a, b in zip(combined['bitmap'], data['bitmap']))
    return merged


def ratio(bits):
    return '{}/{} {:.2f}%'.format(bits.count('1'), len(bits), 100.0 * bits.count('1') / len(bits))


def summary_text(env, records, skipped, merged):
    text = ['NATIVE POINT UNION | adapter v3 | env={} | normal_runs={}'.format(env, len(records)),
            'Profile: VCS V-2023.12-SP2 UCAPI XML 13.1; bitmap index from left (s206 calibration).',
            'Method: pointwise OR across matching shapes; master/slave are disjoint scopes.',
            'Scope: ACE u_master/module_a and u_slave/module_b, including their helper functions.',
            'Window: time zero through reset, boot, traffic and final drain.', '',
            '{:<28} {:>24} {:>24} {:>24}'.format('Metric / native point type', 'Master', 'Slave', 'ACE pair')]
    for family in DEFINITIONS:
        a, b = (merged[s, family]['bitmap'] for s in ('master', 'slave'))
        text.append('{:<28} {:>24} {:>24} {:>24}'.format(LABELS[family], ratio(a), ratio(b), ratio(a + b)))
    text += ['', 'SOURCE ANNOTATION: line basic blocks only; colors are not physical-source-line percentages.']
    for scope in SCOPES:
        data = merged[scope, 'line']
        unknown = [i for i in range(len(data['bitmap'])) if i not in data['mapping']]
        text.append('  {}: {} mapped / {} native points; unmapped indices={} (still included in totals)'.format(
            scope, len(data['mapping']), len(data['bitmap']), ','.join(map(str, unknown)) or 'none'))
        ignored_count = sum(len(p.get('ignored_statement_annotations', [])) for p in data['mapping'].values())
        text.append('  {}: ignored_child_statement_annotations={} (source mapping only; native counts unchanged)'.format(scope, ignored_count))
    text += ['', 'OPTIONAL EXCLUSION XML: absence is recorded; native bitmap counts are not adjusted.']
    for family in DEFINITIONS:
        states = collections.Counter(r['native']['master', family]['exclusion_metadata']['status'] for r in records)
        text.append('  {}: absent={} present_empty={}'.format(family, states['absent'], states['present_empty']))
    text += ['', '(*) Native-slot results have distinct units. Do not compare them as the old runtime metrics:',
             '  Toggle: OR of raw native slots; not the legacy fully-toggled-bit percentage.',
             '  FSM: combined states+transitions; category positions have not been calibrated.',
             '  Branch: raw native outcome slots; legacy API has no branch query. Source annotation is not provided.',
             '  Condition: vector slots matched to runtime totals; expression-level annotation is not provided.',
             '  No average/overall percentage is calculated across different metric types.',
             'Inputs are read-only; output is an independent report, not a vendor merged coverage.vdb.',
             'Excluded negative/diagnostic runs do not contribute to the normal union.',
             '', 'RUNS']
    for r in records:
        text.append('  ' + str(r['directory']))
    if skipped:
        text.append('SKIPPED')
        text += ['  {} {}'.format(r['reason'], r['run']) for r in skipped]
    return '\n'.join(text) + '\n'


def line_points(merged, records):
    result = []
    for scope in SCOPES:
        data = merged[scope, 'line']
        for index, hit in enumerate(data['bitmap']):
            point = data['mapping'].get(index, {})
            result.append({'scope': scope, 'index': index, 'covered': hit == '1',
                'mapped': bool(point), 'references': point.get('references', []),
                'signature': point.get('signature', ''), 'native_id': point.get('native_id'),
                'ignored_statement_annotations': point.get('ignored_statement_annotations', []),
                'hit_runs': [r['directory'].name for r in records if r['native'][scope, 'line']['bitmap'][index] == '1']})
    return result


def write_html(out, env, text, sources, points):
    esc = html.escape
    refmap = collections.defaultdict(list)
    for point in points:
        for name, number in point['references']:
            refmap[point['scope'], name, number].append(point)
    pages = {}
    for scope, name, number in refmap:
        key = scope, name
        pages[key] = 'source_' + sha((scope + '/' + name).encode('utf-8'))[:16] + '.html'
    style = '''body{font:15px system-ui,sans-serif;margin:28px;color:#17212b;background:#fff}
a{color:#1259aa}pre,code{font:13px ui-monospace,Consolas,monospace}pre{white-space:pre-wrap}
table{border-collapse:collapse;width:100%}td,th{padding:4px 9px;border:1px solid #cad2da;text-align:left;vertical-align:top}
.source td{padding:3px 7px}.source code{white-space:pre}.source td:last-child{max-width:680px}
.hit{background:#dcf4e3}.miss{background:#ffe0e0}.partial{background:#fff0b9}.unmapped{background:#f0f1f3;color:#616d79}
.note{padding:12px;background:#eff4fb}button{padding:6px 12px;margin:8px 0}.hidden{display:none}
details{margin-bottom:12px}summary{cursor:pointer}.status{white-space:nowrap}
'''
    def page(title, content):
        return '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>' + esc(title) + '</title><style>' + style + '</style><body>' + content + '</body></html>'
    nav = []
    for (scope, name), filename in sorted(pages.items()):
        nav.append('<li><a href="{}">{} / {}</a></li>'.format(filename, esc(scope), esc(name)))
        body = ['<a href="index.html">Back to merged summary</a><h1>{} / {}</h1>'.format(esc(scope), esc(name)),
            '<p class="note">Green: all mapped basic blocks hit. Red: none hit. Yellow: some hit. Gray: no mapped point; not an uncovered claim. Hover a source line for point IDs. Expand Details for which tests hit each point.</p>',
            '<button id="filter">Show only missed/partial source lines</button>',
            '<table class="source"><thead><tr><th>Line</th><th>Status / native points</th><th>Verified source snapshot</th><th>Details</th></tr></thead><tbody>']
        for number, source in enumerate(sources[name], 1):
            refs = refmap.get((scope, name, number), [])
            hits = sum(p['covered'] for p in refs)
            status = 'unmapped' if not refs else 'hit' if hits == len(refs) else 'miss' if hits == 0 else 'partial'
            label = '{}/{}'.format(hits, len(refs)) if refs else '--'
            detail = []
            for p in refs:
                tests = ', '.join(p['hit_runs']) or 'never hit in selected runs'
                detail.append('<p><b>point {}</b> {}<br>{}<br><code>{}</code></p>'.format(
                    p['index'], 'HIT' if p['covered'] else 'MISS', esc(tests), esc(p['signature'])))
                if p['ignored_statement_annotations']:
                    detail.append('<p>Child statement anchors suppressed (line_ignore != 0); parent block counts retained:<br><code>' +
                                  esc(json.dumps(p['ignored_statement_annotations'], sort_keys=True)) + '</code></p>')
            body.append('<tr class="{}" id="L{}" title="native point indices: {}"><td><a href="#L{}">{}</a></td><td class="status">{} {}</td><td><code>{}</code></td><td>{}</td></tr>'.format(
                status, number, ','.join(str(p['index']) for p in refs), number, number, status, label, esc(source),
                '<details><summary>Details</summary>' + ''.join(detail) + '</details>' if refs else ''))
        body += ['</tbody></table><script>let filtered=false;document.getElementById("filter").onclick=function(){filtered=!filtered;document.querySelectorAll("tbody tr").forEach(function(r){r.classList.toggle("hidden",filtered&&!r.classList.contains("miss")&&!r.classList.contains("partial"));});this.textContent=filtered?"Show all source lines":"Show only missed/partial source lines";};</script>']
        (out / filename).write_text(page(scope + ' / ' + name, ''.join(body)), encoding='utf-8')
    missed = []
    for p in points:
        if p['covered']:
            continue
        links = []
        for name, number in p['references']:
            links.append('<a href="{}#L{}">{}:{}</a>'.format(pages[p['scope'], name], number, esc(name), number))
        missed.append('<tr><td>{}</td><td>{}</td><td>{}</td><td><code>{}</code></td></tr>'.format(esc(p['scope']), p['index'],
                      '<br>'.join(links) or 'UNMAPPED native slot; no source location claimed', esc(p['signature'])))
    content = ['<h1>{} native code coverage union</h1>'.format(esc(env.upper())),
        '<p class="note">Native VDB report adapter. Source hashes and per-run line/condition/FSM aggregate counts were checked. The source mapping direction was calibrated on s206. Final target validation of this merger is still required.</p>',
        '<pre>' + esc(text) + '</pre>', '<h2>Source views</h2><ul>' + ''.join(nav) + '</ul>',
        '<h2>Missed native line points</h2><p>Several points can share one source line. Unmapped slots remain in the native denominator.</p>',
        '<table><tr><th>Scope</th><th>Index</th><th>Location(s)</th><th>VCS basic-block signature</th></tr>' + ''.join(missed) + '</table>',
        '<p><a href="line_points.csv">All line points (CSV)</a> | <a href="merged_points.json">Merged native bitmaps and provenance (JSON)</a> | <a href="summary.txt">Text summary</a></p>']
    (out / 'index.html').write_text(page(env.upper() + ' native union', ''.join(content)), encoding='utf-8')
    return len(pages)


def write_report(out, root, env, records, skipped, merged, sources):
    text = summary_text(env, records, skipped, merged)
    points = line_points(merged, records)
    (out / 'summary.txt').write_text(text, encoding='utf-8')
    payload = {'adapter_version': 3, 'status': 'ADAPTER_TARGET_VALIDATION_PENDING',
        'environment': env, 'project_root': str(root), 'native_xml_profile': list(SUPPORTED),
        'index_direction': 'index_from_left', 'excluded_runs': skipped,
        'input_source_checksums': records[0]['metadata']['source_checksums'],
        'runs': [{'directory': str(r['directory']), 'metadata': r['metadata'],
                  'native': {'{}/{}'.format(*k): {name: d[name] for name in ('bitmap', 'checksum', 'definition_sha256', 'data_sha256', 'validation', 'exclusion_metadata')}
                             for k, d in r['native'].items()}} for r in records],
        'merged': {'{}/{}'.format(*key): {name: data[name] for name in ('bitmap', 'checksum', 'definition_sha256', 'validation')}
                   for key, data in merged.items()}, 'line_points': points}
    (out / 'merged_points.json').write_text(json.dumps(payload, indent=2, ensure_ascii=True) + '\n', encoding='utf-8')
    with (out / 'line_points.csv').open('w', encoding='utf-8', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(['scope', 'native_index', 'covered', 'mapped', 'locations', 'hit_runs', 'basic_block_signature', 'ignored_statement_annotations'])
        for p in points:
            writer.writerow([p['scope'], p['index'], int(p['covered']), int(p['mapped']),
                ';'.join('{}:{}'.format(*ref) for ref in p['references']), ';'.join(p['hit_runs']), p['signature'],
                json.dumps(p['ignored_statement_annotations'], sort_keys=True)])
    pages = write_html(out, env, text, sources, points)
    emit(text.rstrip())
    emit('SOURCE_PAGES={}'.format(pages))
    emit('REPORT_DIR=' + str(out))
    emit('OPEN_HTML=' + str(out / 'index.html'))
    emit('ADAPTER_TARGET_VALIDATION=PENDING')
    emit('NATIVE_POINT_UNION=PASS')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=PROJECT_ROOT,
                        help='Project root (default: determined from this script)')
    parser.add_argument('--run', type=Path, action='append', default=[], help='Repeat for a compatible subset; each run must belong to selected environment')
    parser.add_argument('--output', type=Path,
                        help='New report directory under ' + ENVIRONMENT + '/out/code_coverage, or outside the project')
    args = parser.parse_args()
    root = args.project_root.resolve()
    records, skipped = select_runs(root, ENVIRONMENT, args.run)
    sources = checked_sources(root, records[0]['metadata']['source_checksums'])
    merged = merge(records, root, sources)
    # Complete all input validation before creating any output files.
    if args.output:
        out = args.output.resolve()
        report_root = (root / ENVIRONMENT / 'out' / 'code_coverage').resolve()
        if inside(out, root) and not inside(out, report_root):
            fail('Report output inside the project must be under ' + ENVIRONMENT + '/out/code_coverage')
        if any(inside(out, r['directory']) for r in records):
            fail('Report output must not overwrite an input run')
        out.mkdir(parents=True, exist_ok=False)
    else:
        report_root = root / ENVIRONMENT / 'out' / 'code_coverage'
        stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S') + '_' + uuid.uuid4().hex[:6]
        out = report_root / stamp
        out.mkdir(parents=True, exist_ok=False)
    write_report(out, root, ENVIRONMENT, records, skipped, merged, sources)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, UnicodeError, ET.ParseError) as exc:
        emit('NATIVE_COVERAGE_ERROR: ' + str(exc))
        sys.exit(1)
