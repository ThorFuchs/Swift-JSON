#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Build and qualify native DocC, authored API comments and the Doxygen catalog."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

import documentation_catalog
from preflight import collect

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(command, log, timeout):
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
    return {'command': [arg.replace(str(ROOT), '.') for arg in command],
            'exit_code': result.returncode, 'log': str(log.relative_to(ROOT)),
            'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}


def main():
    output = ROOT / '.build/handoff/docc'
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'schema_version': 2, 'environment': collect(), 'status': 'failed', 'products': []}
    try:
        if receipt['environment']['status'] != 'passed':
            raise ValueError('Supported native toolchain unavailable')
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
        example_source, example_count = documentation_catalog.readme_examples()
        example = ROOT / 'Examples/Consumer/Sources/Consumer/READMEExamples.swift'
        if example.read_text() != example_source:
            raise ValueError('README Swift examples differ from the compiled consumer')
        command = ['swift', 'run', '--package-path', 'Examples/Consumer', 'Consumer']
        receipt['readme_examples'] = dict(run(command, output / 'readme-examples.log', 900), executable_fences=example_count)
        if receipt['readme_examples']['exit_code']:
            raise ValueError('Compiled README examples failed')
        for product in documentation_catalog.PRODUCTS:
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
        receipt['doxygen'] = documentation_catalog.build_catalog(symbols, ROOT / '.build/handoff/doxygen')
        receipt['status'] = 'passed'
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
