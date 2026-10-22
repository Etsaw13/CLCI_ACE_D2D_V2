#!/usr/bin/env python3
"""Merge passed normal UVM coverage; report negative/diagnostic runs separately."""
import argparse
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
import report as coverage_report

HERE = Path(__file__).resolve().parent


def emit(text, stream=None):
    stream = stream or sys.stdout
    encoding = stream.encoding or 'utf-8'
    stream.write(text.encode(encoding, errors='backslashreplace').decode(encoding))
    stream.flush()


def save_report(runs, destination):
    # Validate the whole report before replacing an existing summary.
    capture = io.StringIO()
    with redirect_stdout(capture):
        coverage_report.report(runs)
    rendered = capture.getvalue()
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8',
                dir=str(destination.parent), prefix='.' + destination.name + '.',
                delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(rendered)
        os.replace(str(temporary), str(destination))
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()
    emit(rendered)
    emit('SUMMARY_FILE=' + str(destination) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out-dir', type=Path, default=HERE.parent / 'out',
                        help='Run parent directory (default: uvm/out beside this script)')
    parser.add_argument('--summary', type=Path,
                        help='Normal summary file (default: OUT_DIR/merged_coverage_summary.log)')
    args = parser.parse_args()
    out = args.out_dir.resolve()
    if not out.is_dir():
        raise ValueError('Run directory does not exist: ' + str(out))
    summary = (args.summary or out / 'merged_coverage_summary.log').resolve()
    normal, separate, seen = [], [], set()
    for metadata_path in sorted(out.glob('*/run.json')):
        if metadata_path.parent.name == 'build':
            continue
        try:
            metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
        except ValueError as exc:
            raise ValueError('Invalid run metadata: {}: {}'.format(metadata_path, exc))
        if not isinstance(metadata, dict):
            raise ValueError('Invalid run metadata: ' + str(metadata_path))
        if metadata.get('simulation_pass') is not True:
            emit('SKIP_FAILED_OR_UNFINISHED: ' + str(metadata_path.parent) + '\n')
            continue
        kind = metadata.get('run_kind')
        if kind not in ('normal', 'negative', 'diagnostic'):
            raise ValueError('Missing/invalid run category: ' + str(metadata_path))
        expected = {'ace_v2_error_status_test': 'negative',
                    'ace_v2_data_alias_diag_test': 'diagnostic'}.get(metadata.get('test'))
        if expected is not None and kind != expected:
            raise ValueError('Test/category mismatch: ' + str(metadata_path))
        directory = metadata_path.parent.resolve()
        if directory in seen:
            raise ValueError('Duplicate run directory: ' + str(directory))
        seen.add(directory)
        if kind == 'normal':
            normal.append(directory)
        else:
            separate.append((directory, kind))
    failures = 0
    for directory, kind in separate:
        emit('SEPARATE_REPORT ({}): {}\n'.format(kind, directory))
        try:
            save_report([directory], directory / 'coverage_summary.log')
        except (OSError, ValueError, KeyError, TypeError, UnicodeError) as exc:
            failures += 1
            emit('SEPARATE_REPORT_ERROR: {}: {}\n'.format(directory, exc), sys.stderr)
    if not normal:
        raise ValueError('No passed normal UVM runs found in ' + str(out))
    emit('MERGING {} NORMAL RUN(S)\n'.format(len(normal)))
    save_report(normal, summary)
    if failures:
        raise ValueError('{} separate report(s) failed; normal summary was saved'.format(failures))
    emit('MERGE_RESULT=PASS\n')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, UnicodeError) as exc:
        emit('COVERAGE_MERGE_ERROR: ' + str(exc) + '\n', sys.stderr)
        sys.exit(1)
