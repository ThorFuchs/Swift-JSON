#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify authored public Swift documentation and render a Doxygen catalog.

Swift's compiler is the declaration authority. No Swift-to-C++ signature rewrite,
source execution, private target extraction or network dependency is involved.
"""
import hashlib
import html
import json
import pathlib
import re
import subprocess
import urllib.parse
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
PRODUCTS = ('JSON', 'JSONSchema', 'JSONStreaming', 'JSONPatch')
DOXYGEN_VERSION = '1.18.0'


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


def page_id(symbol):
    return 'swift_' + hashlib.sha256(symbol['identifier']['precise'].encode()).hexdigest()[:24]


def comment_html(text):
    """Render the native comment's prose, inline code and structured field lists."""
    def inline(value):
        value = html.escape(value).replace('\\', '&#92;').replace('@', '&#64;').replace('*/', '*&#47;')
        return re.sub(r'`([^`]+)`', r'<code>\1</code>', value)
    parts = []
    for block in re.split(r'\n\s*\n', text):
        lines = block.splitlines()
        fields = [re.match(r'^\s*- ([^:]+):\s*(.*)', line) for line in lines]
        if all(fields) and fields:
            entries = []
            for field in fields:
                name, value = field.groups()
                if name == 'Parameters':
                    continue
                entries.append('<dt>' + inline(name) + '</dt><dd>' + inline(value) + '</dd>')
            parts.append('<dl>' + ''.join(entries) + '</dl>')
        else:
            parts.append('<p>' + inline(' '.join(lines)) + '</p>')
    return '\n'.join(parts)


def render_catalog(symbols, output):
    output.mkdir(parents=True, exist_ok=True)
    inputs = output / 'input'
    inputs.mkdir(exist_ok=True)
    for stale in inputs.glob('*'):
        stale.unlink()
    types = {(s['module'], tuple(s['pathComponents'])): s for s in symbols
             if s['kind']['identifier'] in ('swift.struct', 'swift.enum')}
    names = {}
    for symbol in symbols:
        key = (symbol['module'], tuple(symbol['pathComponents']))
        names[key] = names.get(key, 0) + 1
    def title_for(symbol):
        title = symbol['module'] + '.' + '.'.join(symbol['pathComponents'])
        if names[(symbol['module'], tuple(symbol['pathComponents']))] > 1:
            title += ' — ' + ''.join(f['spelling'] for f in symbol['declarationFragments'])
        return title
    children = {}
    for symbol in symbols:
        parent = types.get((symbol['module'], tuple(symbol['pathComponents'][:-1])))
        owner = page_id(parent) if parent else 'module_' + symbol['module']
        children.setdefault(owner, []).append(symbol)
    def child_links(owner):
        return ['- \\subpage ' + page_id(s) + ' "' + title_for(s) + '"' for s in children.get(owner, [])]
    intro = ['/**', r'\mainpage Swift-JSON public API catalog', '',
             'Exact JSON, offline Draft 2020-12 schemas, staged Patch and pull streams.', '',
             'Generated from native Swift public symbol graphs and inline documentation. '
             'Declarations below are Swift, not C++ bindings. DocC is the primary Swift reference. '
             'Compiler-synthesized members and extension containers are excluded; authored '
             'public extensions are included. Runtime dependencies remain empty.', '']
    for module in PRODUCTS:
        intro += ['- \\subpage module_' + module]
        lines = ['/**', '\\page module_' + module + ' ' + module, '']
        lines += child_links('module_' + module)
        (inputs / (module + '.dox')).write_text('\n'.join(lines) + '\n*/\n')
    (inputs / 'index.dox').write_text('\n'.join(intro) + '\n*/\n')
    inventory = []
    for symbol in symbols:
        identifier = page_id(symbol)
        declaration = ''.join(f['spelling'] for f in symbol['declarationFragments'])
        text = comment_text(symbol)
        # Preserve Swift documentation prose while making DocC links readable in Doxygen.
        text = re.sub(r'``([^`]+)``', r'`\1`', text)
        line = symbol['location']['position']['line'] + 1
        title = title_for(symbol)
        source = symbol['source']
        link = 'https://github.com/ThorFuchs/Swift-JSON/blob/main/' + source + '#L' + str(line)
        # Page commands with escaped HTML avoid Doxygen's Swift-unaware Markdown lexer.
        # Keep declarations and prose exact, without asking a C++ parser to interpret Swift.
        content = '/**\n\\page ' + identifier + ' ' + title + '\n\n'
        content += '\\htmlonly\n<pre class="fragment">' + html.escape(declaration) + '</pre>\n'
        content += comment_html(text) + '\n'
        content += '<p><a href="' + html.escape(link, quote=True) + '">Swift source</a></p>\n\\endhtmlonly\n'
        content += '\\ref module_' + symbol['module'] + '\n'
        if children.get(identifier):
            content += '\nMembers\n-------\n\n' + '\n'.join(child_links(identifier)) + '\n'
        content += '*/\n'
        (inputs / (identifier + '.dox')).write_text(content)
        inventory.append({'id': identifier, 'usr': symbol['identifier']['precise'],
                          'product': symbol['module'], 'title': title, 'source': source,
                          'line': line, 'declaration': declaration,
                          'comment_sha256': hashlib.sha256(comment_text(symbol).encode()).hexdigest()})
    (output / 'symbols.json').write_text(json.dumps(inventory, indent=2) + '\n')
    return inputs, inventory


def build_catalog(symbols, output):
    actual = subprocess.check_output(['doxygen', '--version'], text=True).strip()
    if actual != DOXYGEN_VERSION:
        raise ValueError('Expected Doxygen ' + DOXYGEN_VERSION + '; observed ' + actual)
    inputs, inventory = render_catalog(symbols, output)
    base = (ROOT / 'Documentation/Doxygen/Doxyfile').read_text()
    # Absolute paths are local build inputs only; distributable inventory paths stay relative.
    config = output / 'Doxyfile'
    config.write_text(base + '\nINPUT = "' + str(inputs) + '"\nOUTPUT_DIRECTORY = "' + str(output / 'site') + '"\n')
    command = ['doxygen', str(config)]
    proc = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=300)
    log = output / 'doxygen.log'
    log.write_text(proc.stdout + proc.stderr)
    if proc.returncode:
        raise ValueError('Doxygen failed; inspect ' + str(log))
    pages = {c.findtext('name') for c in ET.parse(output / 'site/xml/index.xml').getroot().findall('compound') if c.get('kind') == 'page'}
    expected = {s['id'] for s in inventory} | {'index'} | {'module_' + m for m in PRODUCTS}
    if pages != expected:
        raise ValueError('Doxygen page inventory differs: missing=' + str(sorted(expected - pages)) + ', extra=' + str(sorted(pages - expected)))
    return {'version': actual, 'command': command, 'exit_code': proc.returncode,
            'symbol_pages': len(inventory), 'pages': len(pages),
            'html': str((output / 'site/html/index.html').relative_to(ROOT)),
            'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest(),
            'inventory_sha256': hashlib.sha256((output / 'symbols.json').read_bytes()).hexdigest()}
