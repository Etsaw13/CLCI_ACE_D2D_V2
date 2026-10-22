#!/usr/bin/env python3
"""Validate self-contained dependencies and unchanged ACE/CLCI assets."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def check():
    manifest = json.loads((ROOT / 'docs/source_manifest.json').read_text())
    for entry in manifest['files']:
        path = ROOT / entry['path']
        if not path.is_file() or ROOT not in path.resolve().parents:
            raise ValueError('Missing/external source asset: ' + str(path))
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != entry['sha256']:
            raise ValueError('Source checksum mismatch: ' + entry['path'])
    filelist = ROOT / 'dv/sim/filelist.f'
    sources = []
    for line in filelist.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('//'):
            continue
        include = line.startswith('+incdir+')
        relative = Path(line[8:] if include else line)
        path = ROOT / relative
        if relative.is_absolute() or '..' in relative.parts or ROOT not in path.resolve().parents:
            raise ValueError('Filelist must stay inside V2: ' + line)
        if not (path.is_dir() if include else path.is_file()):
            raise ValueError('Missing filelist dependency: ' + line)
        if not include:
            sources.append(path)
    for name in ('coverage_plan.json', 'coverage_hierarchy.cfg', 'report.py'):
        if not (ROOT / 'dv/sim' / name).is_file():
            raise ValueError('Missing report dependency: ' + name)
    for path in (ROOT / 'dv').rglob('*'):
        if path.is_file() and path.resolve() != Path(__file__).resolve() and 'out' not in path.relative_to(ROOT / 'dv').parts:
            if path.suffix in ('.sv', '.svh', '.f', '.py', '.sh'):
                text = path.read_text()
                if any(value in text for value in ('integration/uvm', 'ace_full_project/', 'uvm/env/')):
                    raise ValueError('Obsolete or cross-environment dependency: ' + str(path))
    return manifest, sources


if __name__ == '__main__':
    try:
        manifest, sources = check()
        print('V2_DV_FILE_CHECK_PASS: {} compiled sources, {} unchanged assets'.format(
            len(sources), len(manifest['files'])))
        print('Paths and checksums only; not a VCS compilation or simulation.')
    except (ValueError, OSError, KeyError) as exc:
        print('V2_DV_FILE_CHECK_FAIL: ' + str(exc), file=sys.stderr)
        sys.exit(1)
