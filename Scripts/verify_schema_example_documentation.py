#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Reject documentation drift/count/import/receipt mutations; verify all 49 scope rows."""
import json
import pathlib
import shutil
import tempfile
from unittest.mock import patch

import ci
import schema_example_documentation as docs

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main():
    rows = []
    assert docs.check()['snippets'] == 10
    rows.append({'case': 'actual-ten-snippets', 'accepted': True})
    source = (docs.CATALOG / 'VerifiedCandidates.md').read_text()
    for name, change in [
        ('missing-block', lambda s: s.replace('```swift', '```text', 1)),
        ('extra-block', lambda s: s + '\n```swift\nprecondition(true)\n```\n'),
        ('empty-block', lambda s: s + '\n```swift\n\n```\n'),
        ('foreign-import', lambda s: s.replace('import JSON\n', 'import Foundation\n', 1)),
        ('changed-authored-code', lambda s: s.replace('result.attempts == 1', 'result.attempts == 2', 1)),
        ('stale-consumer', lambda s: s),
    ]:
        with tempfile.TemporaryDirectory(prefix='swift-json-docs-') as temporary:
            root = pathlib.Path(temporary)
            catalog = root / 'Sources/JSONSchemaExamples/Documentation.docc'
            shutil.copytree(docs.CATALOG, catalog)
            (catalog / 'VerifiedCandidates.md').write_text(change(source))
            consumer = root / docs.CONSUMER.relative_to(ROOT)
            consumer.parent.mkdir(parents=True)
            consumer.write_text(docs.CONSUMER.read_text() + ('\n// stale\n' if name == 'stale-consumer' else ''))
            with patch.object(docs, 'ROOT', root), patch.object(docs, 'CATALOG', catalog), patch.object(docs, 'CONSUMER', consumer):
                try:
                    docs.check()
                except ValueError:
                    rows.append({'case': name, 'accepted': False})
                else:
                    raise ValueError('Accepted documentation mutation: ' + name)
    command = ['python3', '-B', 'Scripts/qualify_schema_examples.py']
    actual = 'SCHEMA_EXAMPLES_COMPILER passed public_cases=15 negatives=2\nSCHEMA_EXAMPLES_DOCUMENTATION_COMPILER passed snippets=10 processes=2'
    for name, code, log, expected in [
        ('actual-receipt', 0, actual, True),
        ('missing-documentation-outcome', 0, actual.splitlines()[0], False),
        ('wrong-snippet-count', 0, actual.replace('snippets=10', 'snippets=11'), False),
        ('nonzero-command', 1, actual, False),
    ]:
        accepted = ci.check_result(command, code, log)[0]
        assert accepted == expected, name
        rows.append({'case': name, 'accepted': accepted})
    policy = json.loads((ROOT / 'Documentation/Architecture/ResourceProfiles.json').read_text())
    metrics = [m.get('metric', m.get('id')) for k in ['core','schema','streaming','patch','enhancement_limits'] for m in policy[k]]
    classified = []
    for line in (ROOT / 'Documentation/Architecture/Release1.6/SchemaExamplesLimits.md').read_text().splitlines():
        if not line.startswith('| ') or line.startswith(('| Metrics ', '| ---')):
            continue
        names = line.split('|')[1].strip().split(', ')
        classified += names
    assert len(classified) == len(set(classified)) == 49 and set(classified) == set(metrics), classified
    assert len(rows) == 11
    print(json.dumps({'status': 'passed', 'checks': rows, 'scope_metrics': 49}, indent=2))
    print('SCHEMA_EXAMPLES_DOC_HARNESS passed cases=11 metrics=49')


if __name__ == '__main__':
    main()
