#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Synchronize every JSONSchemaExamples DocC Swift block with its public consumer."""
import argparse
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Sources/JSONSchemaExamples/Documentation.docc'
CONSUMER = ROOT / 'Examples/SchemaExamplesConsumer/Sources/SchemaExamplesConsumer/DocumentationExamples.swift'
SNIPPETS = 10
IMPORTS = {'import JSON', 'import JSONSchema', 'import JSONSchemaExamples'}


def examples():
    records = []
    for path in sorted(CATALOG.glob('*.md')):
        text = path.read_text()
        for index, match in enumerate(re.finditer(r'```swift\n(.*?)\n```', text, re.S), 1):
            code = match.group(1)
            if not code.strip():
                raise ValueError('Empty documentation snippet: ' + path.name)
            imports = [line for line in code.splitlines() if line.startswith('import ')]
            if not set(imports) <= IMPORTS:
                raise ValueError('Unexpected documentation import: ' + path.name)
            body = '\n'.join(line for line in code.splitlines() if not line.startswith('import ')).strip()
            records.append({'path': path.relative_to(ROOT).as_posix(), 'block': index,
                            'line': text[:match.start(1)].count('\n') + 1,
                            'sha256': hashlib.sha256(code.encode()).hexdigest(), 'body': body})
    if len(records) != SNIPPETS:
        raise ValueError(f'Expected exactly {SNIPPETS} guide snippets, found {len(records)}')
    return records


def consumer_source():
    records = examples()
    source = '// SPDX-License-Identifier: Apache-2.0\n// Generated from every JSONSchemaExamples DocC Swift block; do not edit by hand.\n'
    source += '\n'.join(sorted(IMPORTS)) + '\n\nfunc runSchemaExampleDocumentation() throws -> Int {\n    var completed = 0\n'
    for record in records:
        source += '    do {\n'
        source += f'        #sourceLocation(file: "{record["path"]}", line: {record["line"]})\n'
        source += '\n'.join('        ' + line if line else '' for line in record['body'].splitlines()) + '\n'
        source += '        #sourceLocation()\n        completed += 1\n    }\n'
    source += f'    precondition(completed == {SNIPPETS})\n    return completed\n}}\n'
    return source


def check():
    expected = consumer_source()
    if CONSUMER.read_text() != expected:
        raise ValueError('DocC Swift snippets differ from their compiled public consumer; run Scripts/schema_example_documentation.py --write and review')
    records = [{k: v for k, v in row.items() if k != 'body'} for row in examples()]
    return {'status': 'passed', 'snippets': SNIPPETS, 'guides': len({r['path'] for r in records}),
            'consumer': CONSUMER.relative_to(ROOT).as_posix(),
            'consumer_sha256': hashlib.sha256(expected.encode()).hexdigest(), 'sources': records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    if args.write:
        CONSUMER.write_text(consumer_source())
    print(json.dumps(check(), indent=2))


if __name__ == '__main__':
    main()
