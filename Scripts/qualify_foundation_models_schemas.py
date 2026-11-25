#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""JF3.1: isolated schema bridge and preserved value-fidelity regressions."""
import argparse
import copy
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

BASE = 'dda2274598d823d311c587d280f00444b3c1fc68'
JF22 = 'f081536bfb63b7f35e327812882ffa2cd298b631'
SOURCE = Path('Tools/FoundationModelsSpike/JF3')
ALLOWED = {str(SOURCE / 'SchemaBridge.swift'), str(SOURCE / 'SchemaBridgeTests.swift'),
           'Scripts/qualify_foundation_models_schemas.py', 'Scripts/test_foundation_models_schemas.py',
           'Documentation/Architecture/FoundationModels/JF3.1.md',
           'Documentation/Architecture/FoundationModels/JF3.1-NativeReview.md'}
PORTABLE = ('jf3ExactCodableAndCanonicalPlan', 'jf3MetadataRequiresExplicitConsent',
            'jf3RejectsConstraintMutationEvenWithMetadataConsent', 'jf3MetadataIsScopedToSchemaNodes',
            'jf3RejectsUnqualifiedDeclarations', 'jf3NativeInvalidityIsNotCompatibility',
            'jf3CumulativeBudgetBoundary', 'jf3CancellationIsNotIncompatibility')
APPLE = ('jf3AppleGuidedImport', 'jf3AppleKnownReverseAnnotationDelta', 'jf3AppleExactPreparedSchema')
SIMPLE_AUGMENTED = '{"title":"Object","type":"object","properties":{"query":{"type":"string"}},"required":["query"],"additionalProperties":false,"x-order":["query"]}'
GUIDED = '{"title":"JF3GuidedArguments","type":"object","properties":{"query":{"type":"string","description":"Search query"},"limit":{"type":"integer","minimum":1,"maximum":20},"sort":{"type":"string","enum":["date","title"]},"tags":{"type":"array","items":{"type":"string"},"minItems":2,"maxItems":2},"note":{"type":"string"}},"required":["query","limit","sort","tags"],"x-order":["query","limit","sort","tags","note"],"additionalProperties":false}'


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def need(ok, message):
    if not ok:
        raise ValueError(message)


def pass_set(log, expected):
    log = re.sub(r'\x1b\[[0-9;]*m', '', log)
    names = re.findall(r'^.*?\bTest (\w+)\(\) passed(?: after|$)', log, re.M)
    need(len(names) == len(expected) and set(names) == set(expected), 'incorrect test pass set')
    need(re.findall(r'Test run with (\d+) tests? in[^\n]*passed', log) == [str(len(expected))], 'incorrect test total')
    need(not re.search(r'\b(?:known issue|skipped|skipping)\b', '\n'.join(l for l in log.splitlines() if 'Test ' in l), re.I), 'skipped/known issue')
    return sorted(names)


def verify(log, lane, fidelity):
    names = pass_set(log, PORTABLE + (APPLE if lane == 'apple' else ()))
    expected = {'JF3_IMPORT': GUIDED, 'JF3_REVERSE': SIMPLE_AUGMENTED, 'JF3_EXACT': SIMPLE_AUGMENTED} if lane == 'apple' else {}
    observed = {}
    for line in log.splitlines():
        if line.startswith('JF3_'):
            kind, raw = line.split(' ', 1)
            need(kind in expected and kind not in observed, 'unknown/duplicate schema receipt')
            need(fidelity.same(fidelity.strict(raw), fidelity.strict(expected[kind])), 'unexpected schema receipt: ' + kind)
            observed[kind] = raw
    need(set(observed) == set(expected), 'missing schema receipts')
    return {'tests': names, 'schemas': observed}


def qualify(root, work, out, args):
    jf2 = load(root / 'Scripts/qualify_foundation_models_values.py', 'jf2')
    fidelity = load(root / 'Scripts/qualify_foundation_models_fidelity.py', 'jf22')
    jf1 = jf2.jf1
    need(re.fullmatch('[0-9a-f]{40}', args.sha) and jf1.capture(root, 'git', 'rev-parse', 'HEAD') == args.sha, 'source SHA mismatch')
    need(not jf1.capture(root, 'git', 'status', '--porcelain'), 'use a clean checkout')
    need(jf1.capture(root, 'git', 'hash-object', 'Package.swift') == jf1.MANIFEST_BLOB, 'root manifest drift')
    need(set(jf1.capture(root, 'git', 'diff', '--name-only', BASE, args.sha).splitlines()) == ALLOWED, 'unexpected JF3 delta')
    swift = jf1.capture(root, 'swift', '--version'); host = jf1.capture(root, 'uname', '-sm')
    need(re.search(r'Swift version 6\.4\.2(?:\s|$)', swift), 'Swift 6.4.2 required')
    provenance = dict(sha=args.sha, base=BASE, jf22=JF22, lane=args.lane, swift=swift, host=host, manifest_blob=jf1.MANIFEST_BLOB)
    if args.lane == 'apple':
        need(host == 'Darwin arm64', 'native Apple ARM64 required')
        provenance['os'] = jf1.capture(root, 'sw_vers', '-productVersion')
        need(int(provenance['os'].split('.')[0]) >= 27, 'macOS 27+ required')
        provenance['sdk'] = jf1.capture(root, 'xcrun', '--sdk', 'macosx', '--show-sdk-version')
        need(provenance['sdk'] == '27.2', 'anchor SDK 27.2 required')
        provenance['xcode'] = jf1.capture(root, 'xcodebuild', '-version')
    else:
        need(host in ('Linux aarch64', 'Linux x86_64'), 'native 64-bit Linux required')
    need(shutil.disk_usage(work).free >= args.min_free_gib * 1024**3, 'insufficient workspace space')
    (out / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    package = work / 'Swift-JSON'; package.mkdir(); archive = work / 'source.tar'
    subprocess.run(['git', 'archive', '--format=tar', '--output=' + str(archive), args.sha, 'Package.swift', 'Sources', 'Tests'], cwd=root, check=True)
    subprocess.run(['tar', '-xf', str(archive), '-C', str(package)], check=True); archive.unlink()
    before = json.loads(jf1.run(package, out, 'baseline-manifest', 'swift', 'package', 'dump-package'))
    manifest = package / 'Package.swift'; text = jf2.graft(manifest.read_text())
    anchor = '.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONFoundationModels"])'
    need(text.count(anchor) == 1, 'unexpected graft anchor')
    manifest.write_text(text.replace(anchor, '.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONSchema", "JSONFoundationModels"])'))
    target = package / 'Sources' / jf1.PRODUCT; target.mkdir()
    tests = package / 'Tests' / jf2.TEST_TARGET; tests.mkdir()
    for src in (root / 'Tools/FoundationModelsSpike/JF2/ValueBridge.swift', root / SOURCE / 'SchemaBridge.swift'):
        shutil.copyfile(src, target / src.name)
    for src in (root / 'Tools/FoundationModelsSpike/JF2/ValueBridgeTests.swift', root / 'Tools/FoundationModelsSpike/JF2/FidelityTests.swift', root / SOURCE / 'SchemaBridgeTests.swift'):
        shutil.copyfile(src, tests / src.name)
    after = json.loads(jf1.run(package, out, 'candidate-manifest', 'swift', 'package', 'dump-package'))
    normalized = copy.deepcopy(after)
    test = [t for t in normalized['targets'] if t['name'] == jf2.TEST_TARGET]
    need(len(test) == 1, 'missing test target')
    deps = test[0]['dependencies']; schema = [d for d in deps if d.get('byName') == ['JSONSchema', None]]
    need(len(deps) == 3 and len(schema) == 1, 'unexpected direct schema dependency')
    deps.remove(schema[0]); jf2.inspect_manifests(before, normalized)
    receipts = {}; regressions = {}
    for config in ('debug', 'release'):
        command = ('swift', 'test', '-c', config, '--jobs', '2', '--test-product', jf2.TEST_TARGET, '--disable-xctest', '--no-parallel', '--filter')
        receipts[config] = verify(jf1.run(package, out, config + '-jf3', *command, 'jf3'), args.lane, fidelity)
        log = jf1.run(package, out, config + '-jf2-regression', *command, 'jf2')
        regressions[config] = fidelity.verify(log) if args.lane == 'apple' else {'tests': jf2.verify_test_log(log, 'linux')}
        (out / 'schema-receipts.json').write_text(json.dumps(receipts, ensure_ascii=True, indent=2) + '\n')
        (out / 'value-regressions.json').write_text(json.dumps(regressions, ensure_ascii=True, indent=2) + '\n')
    if args.lane == 'apple':
        fidelity.stable(regressions['debug'], regressions['release'])
        for kind, raw in receipts['debug']['schemas'].items():
            need(fidelity.same(fidelity.strict(raw), fidelity.strict(receipts['release']['schemas'][kind])), 'schema mode drift')
    need(jf1.capture(root, 'git', 'rev-parse', 'HEAD') == args.sha and not jf1.capture(root, 'git', 'status', '--porcelain'), 'source drift')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sha'); parser.add_argument('output_parent', type=Path)
    parser.add_argument('--lane', choices=['apple', 'linux'], default='apple')
    parser.add_argument('--min-free-gib', type=int, default=20)
    args = parser.parse_args(); need(args.min_free_gib >= 1, 'positive disk preflight required')
    root = Path(__file__).resolve().parents[1]; parent = args.output_parent.expanduser().resolve()
    need(parent != root and root not in parent.parents, 'output must be outside checkout')
    os.umask(0o077); parent.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='jf3-', dir=parent)); out = work / 'evidence'; out.mkdir()
    outcome = 'FAILED_OR_INCOMPLETE'
    try:
        qualify(root, work, out, args)
        outcome = 'APPLE_SCHEMA_CANDIDATE_PASS' if args.lane == 'apple' else 'PORTABLE_SCHEMA_POLICY_PASS'
    except (Exception, KeyboardInterrupt) as error:
        (out / 'failure.txt').write_text(f'{type(error).__name__}: {error}\n')
        print('JF3 failed:', error, file=sys.stderr)
    finally:
        (out / 'decision.json').write_text(json.dumps({'outcome': outcome, 'product_admission': 'NOT_ADMITTED'}, indent=2) + '\n')
        with tarfile.open(str(work) + '.tar.gz', 'w:gz') as archive:
            archive.add(out, arcname='evidence')
        print(f'ARCHIVE: {work}.tar.gz ({outcome})', flush=True)
        print(f'Disposable worktree retained: {work}', flush=True)
    return int(outcome == 'FAILED_OR_INCOMPLETE')


if __name__ == '__main__':
    sys.exit(main())
