#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Build and qualify native DocC catalogs, authored API comments and executable README examples."""
import hashlib
import gzip
import io
import json
import pathlib
import shutil
import subprocess
import sys
import tarfile

import documentation_catalog
import schema_example_documentation
from preflight import collect

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(command, log, timeout):
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
    return {'command': [arg.replace(str(ROOT), '.') for arg in command],
            'exit_code': result.returncode, 'log': str(log.relative_to(ROOT)),
            'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}


def package_catalogs(output):
    """Preserve native DocC filenames inside an artifact with a portable outer name."""
    records = []
    for product in documentation_catalog.CATALOGS:
        catalog = output / (product + '.doccarchive')
        paths = sorted(catalog.rglob('*'))
        if not any(p.is_file() for p in paths):
            raise ValueError('Empty compiled DocC catalog: ' + product)
        for path in paths:
            if path.is_symlink():
                raise ValueError('Unexpected symlink in DocC catalog')
            if path.is_file():
                records.append((path.relative_to(output).as_posix(), path.read_bytes()))
    archive = output / 'compiled-catalogs.tar.gz'
    manifest = output / 'compiled-catalogs.MANIFEST.sha256'
    manifest.write_text(''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n' for name, data in records))
    with archive.open('wb') as stream:
        with gzip.GzipFile(fileobj=stream, mode='wb', filename='', mtime=0, compresslevel=9) as compressed:
            with tarfile.open(fileobj=compressed, mode='w', format=tarfile.GNU_FORMAT) as tar:
                for name, data in records:
                    info = tarfile.TarInfo(name)
                    info.size = len(data)
                    info.mode = 0o644
                    tar.addfile(info, io.BytesIO(data))
    with tarfile.open(archive) as tar:
        entries = tar.getmembers()
        if len(entries) != len(records) or len({p.name for p in entries}) != len(records):
            raise ValueError('Compiled catalog archive inventory differs')
        for member, (name, data) in zip(entries, records):
            if not member.isfile() or member.name != name or tar.extractfile(member).read() != data:
                raise ValueError('Compiled catalog archive bytes differ: ' + name)
    return {'archive': str(archive.relative_to(ROOT)), 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'bytes': archive.stat().st_size, 'verified_files': len(records),
            'manifest': str(manifest.relative_to(ROOT)),
            'manifest_sha256': hashlib.sha256(manifest.read_bytes()).hexdigest(),
            'policy': f'{len(documentation_catalog.CATALOGS)} native DocC archives; exact internal filenames, sorted entries and normalized tar/gzip metadata.'}


def main():
    output = ROOT / '.build/handoff/docc'
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'schema_version': 2, 'environment': collect(), 'status': 'failed', 'products': []}
    try:
        if receipt['environment']['status'] != 'passed':
            raise ValueError('Supported native toolchain unavailable')
        command = ['python3', '-B', 'Scripts/test_documentation_site.py']
        receipt['site_regressions'] = run(command, output / 'site-regressions.log', 60)
        if receipt['site_regressions']['exit_code']:
            raise ValueError('Static documentation regression tests failed')
        command = ['swift', 'package', 'dump-symbol-graph', '--minimum-access-level', 'public']
        receipt['symbol_graph'] = run(command, output / 'symbol-graph.log', 900)
        if receipt['symbol_graph']['exit_code']:
            raise ValueError('Native symbol graph extraction failed')
        graph_root = ROOT / '.build/out/symbolgraph'
        symbols = documentation_catalog.public_symbols(graph_root)
        coverage = documentation_catalog.verify_comments(symbols)
        (output / 'coverage.json').write_text(json.dumps(coverage, indent=2) + '\n')
        receipt['coverage'] = coverage
        if coverage['errors']:
            raise ValueError('Incomplete authored public API documentation')
        receipt['schema_examples_documentation'] = schema_example_documentation.check()
        example_source, example_count = documentation_catalog.readme_examples()
        example = ROOT / 'Examples/Consumer/Sources/Consumer/READMEExamples.swift'
        if example.read_text() != example_source:
            raise ValueError('README Swift examples differ from the compiled consumer')
        command = ['swift', 'run', '--package-path', 'Examples/Consumer', 'Consumer']
        receipt['readme_examples'] = dict(run(command, output / 'readme-examples.log', 900), executable_fences=example_count)
        if receipt['readme_examples']['exit_code']:
            raise ValueError('Compiled README examples failed')
        command = ['python3', '-B', 'Scripts/qualify_schema_examples.py', '--output', str(output.relative_to(ROOT) / 'schema-examples-consumer'), '--scratch-path', '.build']
        receipt['schema_examples_consumer'] = run(command, output / 'schema-examples-consumer.log', 900)
        if receipt['schema_examples_consumer']['exit_code']:
            raise ValueError('Public schema-examples consumer or compiler boundaries failed')
        for product in documentation_catalog.CATALOGS:
            graphs = output / 'symbols' / product
            if graphs.exists():
                shutil.rmtree(graphs)
            graphs.mkdir(parents=True)
            selected, count = [], 0
            for path in sorted(graph_root.glob('*.symbols.json')):
                data = json.loads(path.read_text())
                if data['module']['name'] == product:
                    shutil.copyfile(path, graphs / path.name)
                    selected.append(path.name)
                    count += len(data['symbols'])
            if not count:
                raise ValueError('Zero public symbols: ' + product)
            diagnostic = output / (product + '-diagnostics.json')
            diagnostic.unlink(missing_ok=True)
            command = ['xcrun', 'docc', 'convert', str(ROOT / 'Sources' / product / 'Documentation.docc'),
                       '--additional-symbol-graph-dir', str(graphs), '--output-dir', str(output / (product + '.doccarchive')),
                       '--fallback-bundle-identifier', 'org.swift-json.' + product,
                       '--warnings-as-errors', '--diagnostics-file', str(diagnostic)]
            entry = dict(run(command, output / (product + '.log'), 180), product=product,
                         public_symbols=count, graphs=selected,
                         diagnostics=json.loads(diagnostic.read_text()) if diagnostic.exists() else None)
            receipt['products'].append(entry)
            if entry['exit_code']:
                raise ValueError('DocC failed: ' + product)
        receipt['catalog_bundle'] = package_catalogs(output)
        command = ['python3', '-B', 'Scripts/build_documentation_site.py']
        receipt['site_build'] = run(command, output / 'pages-site.log', 900)
        receipt['site'] = json.loads((ROOT / '.build/handoff/pages/receipt.json').read_text())
        if receipt['site_build']['exit_code'] or receipt['site']['status'] != 'passed':
            raise ValueError('Static documentation site failed')
        receipt['status'] = 'passed'
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
