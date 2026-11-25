#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""JF2.2: validate the real SDK fidelity matrix and preserve exact evidence."""
import argparse
import copy
from decimal import Decimal
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

BASE = '084d740ecbb4a40562da276212cb7dfa82b17010'
JF2 = '1772e1e173713c9361e2ecfcae8b4a5b8a7344d9'
SOURCE = Path('Tools/FoundationModelsSpike/JF2')
NEW_TEST = SOURCE / 'FidelityTests.swift'
ALLOWED = {str(NEW_TEST), 'Scripts/qualify_foundation_models_fidelity.py',
           'Scripts/test_foundation_models_fidelity.py', 'Documentation/Architecture/FoundationModels/JF2.2.md'}
NEW_TESTS = ('jf22AppleFidelityMatrix', 'jf22AppleCompleteUnicodeCollision',
             'jf22AppleGuideValidation', 'jf22AppleTypedOptionality')
OLD_TESTS = ('jf2ExactNativeRoundtrips', 'jf2RejectsSemanticLoss', 'jf2AcceptsOnlySemanticNotTextIdentity',
             'jf2MalformedForeignJSONRejected', 'jf2IncompleteForeignSnapshotRejected', 'jf2InputOutputLimitsDoNotReset',
             'jf2CumulativeBudgetBoundary', 'jf2CancellationAfterForeignCallback',
             'jf2AppleOrdinaryValueRoundtrip', 'jf2AppleExactOrExplicitRejection')
NUMBERS = dict([('zero', '0'), ('one', '1'), ('safe-below', '9007199254740991'),
                ('safe-boundary', '9007199254740992'), ('safe-above', '9007199254740993'),
                ('negative-above', '-9007199254740993'), ('int64-min', '-9223372036854775808'),
                ('int64-max', '9223372036854775807'), ('uint64-max', '18446744073709551615'),
                ('binary-fraction', '0.125'), ('decimal-tenth', '0.1'),
                ('precise-decimal', '0.12345678901234567890123456789'),
                ('large-exponent', '1e100'), ('small-exponent', '1e-100')])
STRUCTURES = {'ordinary': '{"a":[true,false,1,"hello"],"b":{}}', 'explicit-null': '{"a":null}', 'absent': '{}',
              'unicode-keys': r'{"\u00e9":1,"e\u0301":2}', 'unicode-keys-reversed': r'{"e\u0301":2,"\u00e9":1}',
              'unicode-keys-nested': r'{"a":[{"\u00e9":1,"e\u0301":2}]}', 'unicode-value': r'"e\u0301"',
              'nested': '[{"a":[1,null,{"b":2}]}]', 'null-root': 'null', 'bool-root': 'true'}
# Reproduce actual JF1 observations on the pinned SDK; new vectors are observations, not hard-coded vendor guesses.
ANCHORS = {'ordinary': (True, True), 'explicit-null': (True, True), 'absent': (True, True),
           'root-safe-above': (False, False), 'root-int64-max': (False, False),
           'root-precise-decimal': (False, False), 'root-large-exponent': (False, True),
           'unicode-keys': (True, False), 'unicode-value': (True, True), 'nested': (True, True)}


def need(condition, message):
    if not condition:
        raise ValueError(message)


def strict(text):
    def object_pairs(pairs):
        result = {}
        for key, value in pairs:
            need(key not in result, 'duplicate decoded key')
            result[key] = value
        return result
    def constant(value):
        raise ValueError('non-JSON constant')
    return json.loads(text, parse_int=Decimal, parse_float=Decimal, parse_constant=constant,
                      object_pairs_hook=object_pairs)


def same(a, b):
    # Python's ordinary equality treats true == 1. Never use that for JSON.
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return a == b


def vectors():
    result = {}
    for name, number in NUMBERS.items():
        result['root-' + name] = number
        result['object-' + name] = '{"n":' + number + '}'
        result['array-' + name] = '[' + number + ']'
    return result | STRUCTURES


def guide_cases():
    base = strict('{"query":"test","limit":1,"sort":"date","tags":["a","b"]}')
    return {'base': (base, True), 'upper-bound': (base | {'limit': Decimal(20)}, True),
            'enum-title': (base | {'sort': 'title'}, True), 'note-string': (base | {'note': 'ok'}, True),
            'note-null': (base | {'note': None}, False), 'range-low': (base | {'limit': Decimal(0)}, False),
            'range-high': (base | {'limit': Decimal(21)}, False), 'enum-other': (base | {'sort': 'other'}, False),
            'count-low': (base | {'tags': ['a']}, False), 'count-high': (base | {'tags': ['a', 'b', 'c']}, False),
            'item-type': (base | {'tags': ['a', Decimal(2)]}, False),
            'required-query': ({k: v for k, v in base.items() if k != 'query'}, False),
            'extra-property': (base | {'extra': True}, False), 'query-type': (base | {'query': Decimal(1)}, False)}


def singleton(log, kind):
    rows = [strict(line[len(kind) + 1:]) for line in log.splitlines() if line.startswith(kind + ' ')]
    need(len(rows) == 1 and isinstance(rows[0], dict), 'missing/duplicate ' + kind)
    return rows[0]


def rows(log, kind, expected):
    result = {}
    for line in log.splitlines():
        if line.startswith(kind + ' '):
            row = strict(line[len(kind) + 1:])
            need(isinstance(row, dict) and row.get('id') in expected and row['id'] not in result,
                 'unknown/duplicate ' + kind + ' row')
            result[row['id']] = row
    need(set(result) == set(expected), 'missing ' + kind + ' rows: ' + str(sorted(set(expected) - set(result))))
    return result


def verify(log):
    log = re.sub(r'\x1b\[[0-9;]*m', '', log)
    names = re.findall(r'^.*?\bTest (jf2\w+)\(\) passed(?: after|$)', log, re.M)
    need(len(names) == 14 and set(names) == set(OLD_TESTS + NEW_TESTS), 'incorrect Swift test pass set')
    need(re.findall(r'Test run with (\d+) tests? in[^\n]*passed', log) == ['14'], 'incorrect Swift test total')
    need(not re.search(r'\b(?:known issue|skipped|skipping)\b', '\n'.join(l for l in log.splitlines() if 'Test ' in l), re.I), 'skipped/known issue')
    expected = vectors()
    values = rows(log, 'JF22_VALUE', expected)
    raw_rows = {}
    for line in log.splitlines():
        if line.startswith('JF22_RAW '):
            _, name, payload = line.split(' ', 2)
            need(name in expected and name not in raw_rows, 'unknown/duplicate raw row')
            raw_rows[name] = strict(payload)
    for name, row in values.items():
        need(same(strict(row['source']), strict(expected[name])), name + ': fixture drift')
        fields = {'id', 'source', 'exportOutcome', 'importOutcome'}
        if 'raw' not in row:
            need(set(row) == fields and name not in raw_rows and row['exportOutcome'] == 'frameworkRejected'
                 and row['importOutcome'] == 'notAttempted' and name not in ANCHORS, name + ': unexpected constructor rejection')
            continue
        need(set(row) == fields | {'raw', 'complete', 'equal'} and type(row['complete']) is bool and type(row['equal']) is bool,
             name + ': malformed observation')
        need(raw_rows.get(name) == row['raw'], name + ': raw receipt mismatch')
        equal = same(strict(row['source']), strict(row['raw']))
        need(row['equal'] == equal, name + ': independent exact equality mismatch')
        complete = row['complete']
        need(row['exportOutcome'] == ('incompleteContent' if not complete else 'accepted' if equal else 'changedValue'), name + ': export policy violation')
        need(row['importOutcome'] == ('accepted' if complete else 'incompleteContent'), name + ': import policy violation')
        if name in ANCHORS:
            need((complete, equal) == ANCHORS[name], name + ': historical SDK behavior drift; review required')
    need(set(raw_rows) == {n for n, r in values.items() if 'raw' in r}, 'unexpected raw receipt set')
    guides = rows(log, 'JF22_GUIDE', guide_cases())
    for name, (source, verdict) in guide_cases().items():
        row = guides[name]
        need(set(row) == {'id', 'source', 'expected', 'actual'} and same(strict(row['source']), source)
             and row['expected'] is verdict and row['actual'] is verdict, name + ': isolated guide verdict mismatch')
    schema = singleton(log, 'JF22_SCHEMA')
    props = strict('{"query":{"type":"string","description":"Search query"},"limit":{"type":"integer","minimum":1,"maximum":20},"sort":{"type":"string","enum":["date","title"]},"tags":{"type":"array","items":{"type":"string"},"minItems":2,"maxItems":2},"note":{"type":"string"}}')
    need(schema.get('type') == 'object' and same(schema.get('properties'), props) and schema.get('additionalProperties') is False
         and schema.get('required') == ['query', 'limit', 'sort', 'tags']
         and schema.get('x-order') == ['query', 'limit', 'sort', 'tags', 'note'], 'observed guide schema drift')
    typed = singleton(log, 'JF22_TYPED')
    base = guide_cases()['base'][0] | {'limit': Decimal(2)}
    need(set(typed) == {'source', 'returned', 'inputValid', 'outputValid', 'equal'}
         and same(strict(typed['source']), base | {'note': None}) and same(strict(typed['returned']), base)
         and typed['inputValid'] is False and typed['outputValid'] is True and typed['equal'] is False,
         'typed optionality observation drift')
    # Preserve exact source/raw number text, not Decimal -> float projections.
    return {'tests': sorted(names), 'values': values, 'guides': guides, 'typed': typed,
            'schemaJSON': next(l[len('JF22_SCHEMA '):] for l in log.splitlines() if l.startswith('JF22_SCHEMA '))}


def stable(before, after):
    for name, row in before['values'].items():
        other = after['values'][name]
        keys = ('complete', 'equal', 'exportOutcome', 'importOutcome')
        need(all(row.get(k) == other.get(k) for k in keys), name + ': Debug/Release disposition drift')
    need(same(strict(before['schemaJSON']), strict(after['schemaJSON'])), 'Debug/Release schema drift')


def qualify(root, work, out, sha, min_free):
    spec = importlib.util.spec_from_file_location('jf2', root / 'Scripts/qualify_foundation_models_values.py')
    jf2 = importlib.util.module_from_spec(spec); spec.loader.exec_module(jf2)
    jf1 = jf2.jf1
    need(re.fullmatch('[0-9a-f]{40}', sha) and jf1.capture(root, 'git', 'rev-parse', 'HEAD') == sha, 'source SHA mismatch')
    need(not jf1.capture(root, 'git', 'status', '--porcelain'), 'use a clean checkout')
    need(jf1.capture(root, 'git', 'hash-object', 'Package.swift') == jf1.MANIFEST_BLOB, 'root manifest drift')
    need(set(jf1.capture(root, 'git', 'diff', '--name-only', BASE, sha).splitlines()) == ALLOWED, 'unexpected JF2.2 delta')
    swift = jf1.capture(root, 'swift', '--version')
    need(re.search(r'Swift version 6\.4\.2(?:\s|$)', swift), 'Swift 6.4.2 required')
    host = jf1.capture(root, 'uname', '-sm'); os_version = jf1.capture(root, 'sw_vers', '-productVersion')
    need(host == 'Darwin arm64' and int(os_version.split('.')[0]) >= 27, 'native macOS 27 ARM64 required')
    need(shutil.disk_usage(work).free >= min_free * 1024**3, 'insufficient workspace space')
    sdk = jf1.capture(root, 'xcrun', '--sdk', 'macosx', '--show-sdk-version')
    need(sdk == '27.2', 'JF1 anchor SDK 27.2 required; review other SDK separately')
    (out / 'provenance.json').write_text(json.dumps(dict(sha=sha, base=BASE, jf2=JF2, host=host, os=os_version,
        swift=swift, sdk=sdk, xcode=jf1.capture(root, 'xcodebuild', '-version'), manifest_blob=jf1.MANIFEST_BLOB), indent=2) + '\n')
    package = work / 'Swift-JSON'; package.mkdir(); archive = work / 'source.tar'
    subprocess.run(['git', 'archive', '--format=tar', '--output=' + str(archive), sha, 'Package.swift', 'Sources', 'Tests'], cwd=root, check=True)
    subprocess.run(['tar', '-xf', str(archive), '-C', str(package)], check=True); archive.unlink()
    before = json.loads(jf1.run(package, out, 'baseline-manifest', 'swift', 'package', 'dump-package'))
    manifest = package / 'Package.swift'; text = jf2.graft(manifest.read_text())
    anchor = '.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONFoundationModels"])'
    need(text.count(anchor) == 1, 'unexpected graft anchor')
    manifest.write_text(text.replace(anchor, '.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONSchema", "JSONFoundationModels"])'))
    target = package / 'Sources' / jf1.PRODUCT; target.mkdir()
    tests = package / 'Tests' / jf2.TEST_TARGET; tests.mkdir()
    shutil.copyfile(root / SOURCE / 'ValueBridge.swift', target / 'ValueBridge.swift')
    for name in ('ValueBridgeTests.swift', 'FidelityTests.swift'):
        shutil.copyfile(root / SOURCE / name, tests / name)
    after = json.loads(jf1.run(package, out, 'candidate-manifest', 'swift', 'package', 'dump-package'))
    normalized = copy.deepcopy(after)
    test = [t for t in normalized['targets'] if t['name'] == jf2.TEST_TARGET]
    need(len(test) == 1, 'missing test target')
    deps = test[0]['dependencies']; schema = [d for d in deps if d.get('byName') == ['JSONSchema', None]]
    need(len(deps) == 3 and len(schema) == 1, 'unexpected direct schema dependency')
    deps.remove(schema[0]); jf2.inspect_manifests(before, normalized)
    receipts = {}
    for config in ('debug', 'release'):
        log = jf1.run(package, out, config + '-tests', 'swift', 'test', '-c', config, '--jobs', '2',
                      '--test-product', jf2.TEST_TARGET, '--disable-xctest', '--no-parallel', '--filter', 'jf2')
        receipts[config] = verify(log)
        (out / 'fidelity.json').write_text(json.dumps(receipts, ensure_ascii=True, indent=2) + '\n')
    stable(receipts['debug'], receipts['release'])
    need(jf1.capture(root, 'git', 'rev-parse', 'HEAD') == sha and not jf1.capture(root, 'git', 'status', '--porcelain'), 'source drift')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sha'); parser.add_argument('output_parent', type=Path)
    parser.add_argument('--min-free-gib', type=int, default=20)
    args = parser.parse_args(); need(args.min_free_gib >= 1, 'positive disk preflight required')
    root = Path(__file__).resolve().parents[1]; parent = args.output_parent.expanduser().resolve()
    need(parent != root and root not in parent.parents, 'output must be outside checkout')
    os.umask(0o077); parent.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='jf22-', dir=parent)); out = work / 'evidence'; out.mkdir()
    outcome = 'FAILED_OR_INCOMPLETE'
    try:
        qualify(root, work, out, args.sha, args.min_free_gib)
        outcome = 'APPLE_FIDELITY_MATRIX_PASS'
    except (Exception, KeyboardInterrupt) as error:
        (out / 'failure.txt').write_text(f'{type(error).__name__}: {error}\n')
        print('JF2.2 failed:', error, file=sys.stderr)
    finally:
        (out / 'decision.json').write_text(json.dumps({'outcome': outcome, 'product_admission': 'NOT_ADMITTED'}, indent=2) + '\n')
        with tarfile.open(str(work) + '.tar.gz', 'w:gz') as archive:
            archive.add(out, arcname='evidence')
        print(f'ARCHIVE: {work}.tar.gz ({outcome})', flush=True)
        print(f'Disposable worktree retained: {work}', flush=True)
    return int(outcome == 'FAILED_OR_INCOMPLETE')


if __name__ == '__main__':
    sys.exit(main())
