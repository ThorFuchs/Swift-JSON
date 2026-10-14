#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify compiler-derived public Swift comments and executable README examples."""
import json
import pathlib
import re
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[1]
PRODUCTS = ('JSON', 'JSONSchema', 'JSONStreaming', 'JSONPatch', 'JSONHTML')


def public_symbols(graph_dir):
    """Return unique authored declarations, excluding extension containers/synthesis."""
    symbols = {}
    for graph in sorted(graph_dir.glob('*.json')):
        data = json.loads(graph.read_text())
        module = data['module']['name']
        if module not in PRODUCTS:
            continue
        for symbol in data['symbols']:
            location = symbol.get('location')
            if not location or symbol['kind']['identifier'] == 'swift.extension':
                continue
            source = pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(location['uri']).path))
            try:
                relative = source.resolve().relative_to(ROOT)
            except ValueError:
                raise ValueError('Symbol location outside checkout: ' + symbol['names']['title'])
            if relative.parts[:2] != ('Sources', module):
                raise ValueError('Unexpected public symbol owner: ' + str(relative))
            if symbol['accessLevel'] != 'public':
                raise ValueError('Non-public symbol in public graph')
            identifier = symbol['identifier']['precise']
            symbols[identifier] = dict(symbol, module=module, source=relative.as_posix())
    for module in PRODUCTS:
        if not any(s['module'] == module for s in symbols.values()):
            raise ValueError('No authored symbols for ' + module)
    return sorted(symbols.values(), key=lambda s: (s['module'], s['pathComponents'], s['identifier']['precise']))


def comment_text(symbol):
    return '\n'.join(line['text'] for line in symbol.get('docComment', {}).get('lines', []))


def verify_comments(symbols):
    failures = []
    for symbol in symbols:
        text = comment_text(symbol)
        label = symbol['module'] + '.' + '.'.join(symbol['pathComponents'])
        if not text.strip() or text.lstrip().startswith('- '):
            failures.append(label + ': missing summary')
        for parameter in symbol.get('functionSignature', {}).get('parameters', []):
            name = parameter.get('internalName', parameter['name'])
            if not re.search(r'^\s*- (?:Parameter )?' + re.escape(name) + r':\s*\S', text, re.M):
                failures.append(label + ': missing parameter ' + name)
    return {'authored_public_symbols': len(symbols),
            'documented_public_symbols': sum(bool(comment_text(s).strip()) for s in symbols),
            'products': {m: sum(s['module'] == m for s in symbols) for m in PRODUCTS},
            'policy': 'All authored public declarations and named parameters; compiler-synthesized declarations and extension containers excluded.',
            'errors': failures}


def readme_examples():
    """Return the standalone consumer source used to execute README Swift fences."""
    blocks = re.findall(r'```swift\n(.*?)\n```', (ROOT / 'README.md').read_text(), re.S)
    if len(blocks) < 3 or not blocks[0].startswith('.package(') or not blocks[1].startswith('.product('):
        raise ValueError('Expected installation manifest fragments followed by executable Swift examples')
    imports, declarations, body = [], [], []
    for block in blocks[2:]:
        lines = block.splitlines()
        imports += [line for line in lines if line.startswith('import ')]
        block = '\n'.join(line for line in lines if not line.startswith('import ')).strip()
        if block.startswith('func inspectArray'):
            declarations.append(block)
        else:
            body.append(block)
    source = '// SPDX-License-Identifier: Apache-2.0\n// Compiled README examples; checked by the documentation lane.\n'
    source += '\n'.join(dict.fromkeys(imports)) + '\n\n'
    source += '\n\n'.join(declarations) + '\n\nfunc runREADMEExamples() throws {\n'
    source += '\n\n'.join('\n'.join(('    ' + line if line else '') for line in b.splitlines()) for b in body) + '\n}\n'
    return source, len(blocks) - 2
