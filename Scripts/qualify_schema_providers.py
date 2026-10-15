#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Real offline CLI provider processes; ordinary incompatibility and errors differ."""
import argparse, hashlib, json, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--binary', required=True); parser.add_argument('--output', required=True); args = parser.parse_args()
    binary = (ROOT / args.binary).resolve(); rows = []
    schema = b'{"type":"object","properties":{"value":{"type":"integer","minimum":9007199254740993}},"required":["value"],"additionalProperties":false}'
    with tempfile.TemporaryDirectory(prefix='schema-provider-') as directory:
        directory = pathlib.Path(directory)
        def file(name, data):
            path = directory / name; path.write_bytes(data if isinstance(data, bytes) else data.encode()); return str(path)
        source = file('schema.json', schema)
        def run(name, command, code=0, inspect=lambda p: True):
            actual = subprocess.run([str(binary), *command], input=b'', capture_output=True, timeout=30)
            try: good = actual.returncode == code and inspect(actual)
            except (ValueError, TypeError, KeyError, IndexError): good = False
            row = {'id': name, 'command': ['swift-json', *command], 'exit_code': actual.returncode, 'expected_exit': code, 'status': 'passed' if good else 'failed', 'stdout_sha256': hashlib.sha256(actual.stdout).hexdigest(), 'stderr_sha256': hashlib.sha256(actual.stderr).hexdigest()}
            if not good: row.update(stdout=actual.stdout.decode(errors='replace'), stderr=actual.stderr.decode(errors='replace')); print(json.dumps(row), flush=True)
            rows.append(row)
        def command(path=source, tool=False, name='sample', extra=()): return ['schema', 'provider', 'openai-tool' if tool else 'openai-format', path, '--name', name, *extra]
        def fragment(p, field='schema'):
            value = json.loads(p.stdout)
            return value.get(field) == json.loads(schema) and value.get('strict') is True and value.get('name') == 'sample' and value.get('type') == ('json_schema' if field == 'schema' else 'function') and 'function' not in value and 'text' not in value and b'9007199254740993' in p.stdout
        run('format-object-exact', command(), inspect=fragment)
        run('tool-flat-exact', command(tool=True), inspect=lambda p: fragment(p, 'parameters'))
        optional = file('optional.json', b'{"type":"object","properties":{"value":{"type":"integer"}},"additionalProperties":false}')
        run('optionality-completed-no-candidate', command(optional, extra=['--report=json']), 1, lambda p: json.loads(p.stdout).get('compatible') is False and 'schema' not in json.loads(p.stdout) and json.loads(p.stderr.splitlines()[-1])['completed'] is True and any(x['code'] == 'allPropertiesRequired' for x in json.loads(p.stdout)['issues']))
        nullable = file('nullable.json', b'{"type":"object","properties":{"value":{"type":["integer","null"]}},"required":["value"],"additionalProperties":false}')
        run('explicit-nullability-preserved', command(nullable), inspect=lambda p: json.loads(p.stdout)['schema'] == json.loads(pathlib.Path(nullable).read_bytes()))
        unknown = file('unknown.json', schema[:-1] + b',"x-unqualified":1}')
        run('unverified-not-success', command(unknown), 1, lambda p: any(x['unverified'] for x in json.loads(p.stdout)['issues']))
        unsupported = file('unsupported.json', schema[:-1] + b',"allOf":[{"type":"object"}]}')
        run('unsupported-not-lowered', command(unsupported), 1, lambda p: any(x['code'] == 'unsupportedKeyword' for x in json.loads(p.stdout)['issues']))
        run('boolean-root-incompatible', command(file('boolean.json', 'true')), 1, lambda p: json.loads(p.stdout)['compatible'] is False)
        run('nonobject-root-incompatible', command(file('string.json', '{"type":"string"}')), 1, lambda p: json.loads(p.stdout)['compatible'] is False)
        local = file('local.json', '{"type":"object","properties":{"value":{"$ref":"#/$defs/value"}},"required":["value"],"additionalProperties":false,"$defs":{"value":{"type":"integer"}}}')
        run('local-ref-no-bundling', command(local), inspect=lambda p: json.loads(p.stdout)['schema'] == json.loads(pathlib.Path(local).read_bytes()))
        recursive = file('recursive.json', '{"type":"object","properties":{"next":{"anyOf":[{"$ref":"#"},{"type":"null"}]}},"required":["next"],"additionalProperties":false}')
        run('productive-recursion-not-unrolled', command(recursive), inspect=lambda p: json.loads(p.stdout)['schema'] == json.loads(pathlib.Path(recursive).read_bytes()))
        external = file('external.json', '{"type":"object","properties":{"value":{"$ref":"https://example.invalid/value"}},"required":["value"],"additionalProperties":false}')
        run('unresolved-is-operational', command(external, extra=['--diagnostics=json', '--report=json']), 5, lambda p: not p.stdout and json.loads(p.stderr.splitlines()[-1])['completed'] is False)
        resource = file('integer.json', '{"type":"integer"}')
        run('explicit-external-resolved-export-rejected', command(external, extra=['--resource', 'https://example.invalid/value=' + resource]), 1, lambda p: any(x['code'] == 'externalReference' for x in json.loads(p.stdout)['issues']))
        run('strict-input-grammar', command(file('bad.json', '{')), 5, lambda p: not p.stdout)
        run('strict-input-utf8', command(file('bad-utf8.json', b'\xff')), 5, lambda p: not p.stdout)
        run('invalid-native-schema-operational', command(file('native-bad.json', '{"type":123}')), 5, lambda p: not p.stdout)
        bad_regex = file('regex.json', '{"type":"object","properties":{"value":{"type":"string","pattern":"["}},"required":["value"],"additionalProperties":false}')
        run('invalid-native-regex-operational', command(bad_regex), 5, lambda p: not p.stdout)
        run('name-required-before-io', ['schema', 'provider', 'openai-format', 'not-opened.json'], 2, lambda p: not p.stdout)
        run('bad-name-before-io', command('not-opened.json', name='bad name'), 2, lambda p: not p.stdout)
        run('long-name-before-io', command('not-opened.json', name='x' * 65), 2, lambda p: not p.stdout)
        run('nonascii-name-before-io', command('not-opened.json', name='é'), 2, lambda p: not p.stdout)
        run('apple-capability-unavailable', ['schema', 'provider', 'apple-check', 'not-opened.json', '--diagnostics=json'], 2, lambda p: not p.stdout and json.loads(p.stderr)['code'] == 'capabilityUnavailable')
        run('unknown-provider-usage', ['schema', 'provider', 'unknown', 'not-opened.json'], 2, lambda p: not p.stdout)
        run('api-key-option-not-exposed', command(extra=['--api-key', 'synthetic-not-a-secret']), 2, lambda p: not p.stdout)
        work = file('work.json', '{"json":{"compileWorkUnits":0}}')
        run('compile-quota-is-operational', command(extra=['--limits-file', work, '--diagnostics=json', '--report=json']), 6, lambda p: not p.stdout and json.loads(p.stderr.splitlines()[-1])['completed'] is False)
        output = file('output-limit.json', '{"json":{"outputBytes":1}}')
        run('writer-quota-is-operational', command(extra=['--limits-file', output]), 6, lambda p: not p.stdout)
        target = pathlib.Path(file('protected.json', b'original'))
        run('quota-preserves-atomic-output', command(extra=['--limits-file', output, '--output', str(target), '--overwrite']), 6, lambda p: not p.stdout and target.read_bytes() == b'original' and not list(directory.glob('.swift-json-*.tmp')))
        run('missing-file-is-io', command(str(directory / 'missing.json')), 7, lambda p: not p.stdout)
        tail = file('tail.json', schema + b' false')
        run('late-tail-preserves-atomic-output', command(tail, extra=['--output', str(target), '--overwrite']), 5, lambda p: not p.stdout and target.read_bytes() == b'original')
        zero_issues = file('issues.json', '{"json":{"issues":0}}')
        run('truncation-never-compatible', command(optional, extra=['--limits-file', zero_issues]), 1, lambda p: json.loads(p.stdout)['truncated'] is True and not json.loads(p.stdout)['issues'] and json.loads(p.stdout)['compatible'] is False)
        run('name-inclusive-64', command(name='x' * 64), inspect=lambda p: json.loads(p.stdout)['name'] == 'x' * 64)
        description = 'exact 🦊\n</script>'
        run('metadata-native-escaped', command(extra=['--description', description]), inspect=lambda p: json.loads(p.stdout)['description'] == description)
        scalar = file('scalar.json', '{"type":"object","properties":{"é":{"type":"string"},"é":{"type":"string"}},"required":["é","é"],"additionalProperties":false}')
        run('scalar-distinct-keys-retained', command(scalar), inspect=lambda p: len(json.loads(p.stdout)['schema']['properties']) == 2)
        frozen = ROOT / 'Tests/Fixtures/Providers'
        for fixture, expected in [('portable-summary-schema.json',0),('optional-field-schema.json',1),('scalar-key-schema.json',0),('exact-number-schema.json',0),('boolean-schema.json',1)]:
            path = frozen / fixture
            run('frozen-' + fixture, command(str(path)), expected, lambda p, expected=expected, path=path: json.loads(p.stdout).get('schema') == json.loads(path.read_bytes()) if expected == 0 else json.loads(p.stdout).get('compatible') is False and 'schema' not in json.loads(p.stdout))
        unchanged = pathlib.Path(source).read_bytes() == schema
    source_files = list((ROOT / 'Sources/JSONSchema/Providers').glob('*.swift')) + [ROOT / 'Sources/JSONCLIEngine/CLISchemaCommand.swift']
    forbidden = ['import FoundationNetworking', 'import OpenAI', 'URLSession', 'URLRequest', 'LanguageModelSession']
    static_offline = all(not any(token in path.read_text() for token in forbidden) for path in source_files)
    passed = len(rows) == 37 and all(row['status'] == 'passed' for row in rows) and static_offline and unchanged
    receipt = {'schema_version': 1, 'status': 'passed' if passed else 'failed', 'observed': len(rows), 'passed': sum(row['status'] == 'passed' for row in rows), 'failed': sum(row['status'] == 'failed' for row in rows), 'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(), 'input_unchanged': unchanged, 'static_no_network_client_or_model_session': static_offline, 'network_scope': 'Local implementation/source invariant; no paid API request or remote acceptance test', 'profile_revision': '2026-10-15.v1', 'frozen_inputs': [{'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in sorted((ROOT / 'Tests/Fixtures/Providers').glob('*.json'))], 'source_files': [{'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in source_files], 'cases': rows}
    destination = ROOT / args.output; destination.parent.mkdir(parents=True, exist_ok=True); destination.write_text(json.dumps(receipt, indent=2) + '\n'); print(json.dumps({k: v for k, v in receipt.items() if k not in ['cases', 'source_files']})); return 0 if passed else 1
if __name__ == '__main__': raise SystemExit(main())
