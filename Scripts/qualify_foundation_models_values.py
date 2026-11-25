#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""JF2.1 diagnostic candidate; materialize and test outside the SDK checkout."""
import argparse
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

spec = importlib.util.spec_from_file_location('jf1', Path(__file__).with_name('qualify_foundation_models.py'))
jf1 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jf1)
JF1 = '53133cae207916c6f97d4087ff177d8c37a8ac9c'
TEST_TARGET = 'JSONFoundationModelsTests'
SOURCE = Path('Tools/FoundationModelsSpike/JF2')
ALLOWED = {str(SOURCE / 'ValueBridge.swift'), str(SOURCE / 'ValueBridgeTests.swift'),
           'Scripts/qualify_foundation_models_values.py', 'Scripts/test_foundation_models_values.py',
           'Documentation/Architecture/FoundationModels/JF2.md'}
PORTABLE = ('jf2ExactNativeRoundtrips', 'jf2RejectsSemanticLoss', 'jf2AcceptsOnlySemanticNotTextIdentity',
            'jf2MalformedForeignJSONRejected', 'jf2IncompleteForeignSnapshotRejected', 'jf2InputOutputLimitsDoNotReset',
            'jf2CumulativeBudgetBoundary', 'jf2CancellationAfterForeignCallback')
APPLE = ('jf2AppleOrdinaryValueRoundtrip', 'jf2AppleExactOrExplicitRejection')


def graft(text):
    result = jf1.graft(text)
    anchor = '    targets: [\n'
    jf1.need(result.count(anchor) == 1, 'unexpected test target anchor')
    return result.replace(anchor, anchor + '        .testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONFoundationModels"]),\n')


def inspect_manifests(before, after):
    candidate = dict(after)
    targets = candidate['targets']
    tests = [t for t in targets if t['name'] == TEST_TARGET]
    jf1.need(len(tests) == 1, 'missing/duplicate experimental test target')
    test = tests[0]
    jf1.need(test.get('type') == 'test' and not test.get('settings') and not test.get('resources'), 'unexpected test target settings')
    deps = test['dependencies']
    jf1.need(len(deps) == 2 and {d['byName'][0] for d in deps} == {'JSON', jf1.PRODUCT}, 'unexpected test target dependencies')
    candidate['targets'] = [t for t in targets if t['name'] != TEST_TARGET]
    jf1.inspect_manifests(before, candidate)


def verify_test_log(text, lane):
    # No green zero-test run, missing Apple tests, known-issue masking or skip.
    text = re.sub(r'\x1b\[[0-9;]*m', '', text)
    expected = PORTABLE + (APPLE if lane == 'apple' else ())
    names = re.findall(r'^.*?\bTest (jf2\w+)\(\) passed(?: after|$)', text, re.M)
    counts = re.findall(r'Test run with (\d+) tests? in[^\n]*passed', text)
    jf1.need(len(names) == len(expected) and set(names) == set(expected), 'unexpected JF2 test pass set')
    jf1.need(counts == [str(len(expected))], 'unexpected JF2 test total')
    jf1.need(not re.search(r'\b(?:known issue|skipped|skipping)\b', '\n'.join(l for l in text.splitlines() if 'Test ' in l), re.I),
             'JF2 test skip/known issue')
    return sorted(names)


def qualify(root, work, out, args):
    jf1.need(re.fullmatch('[0-9a-f]{40}', args.sha), 'expected exact source SHA')
    jf1.need(jf1.capture(root, 'git', 'rev-parse', 'HEAD') == args.sha, 'source SHA mismatch')
    jf1.need(not jf1.capture(root, 'git', 'status', '--porcelain'), 'use a clean checkout')
    jf1.need(jf1.capture(root, 'git', 'hash-object', 'Package.swift') == jf1.MANIFEST_BLOB, 'root manifest changed')
    changed = set(jf1.capture(root, 'git', 'diff', '--name-only', JF1, args.sha).splitlines())
    jf1.need(changed == ALLOWED, 'unexpected JF2 delta')
    swift = jf1.capture(root, 'swift', '--version')
    jf1.need(re.search(r'Swift version 6\.4\.2(?:\s|$)', swift), 'Swift 6.4.2 required')
    host = jf1.capture(root, 'uname', '-sm')
    if args.lane == 'apple':
        jf1.need(host == 'Darwin arm64' and int(jf1.capture(root, 'sw_vers', '-productVersion').split('.')[0]) >= 27, 'native macOS 27 ARM64 required')
    else:
        jf1.need(host in ('Linux aarch64', 'Linux x86_64'), 'native 64-bit Linux required')
    jf1.need(shutil.disk_usage(work).free >= args.min_free_gib * 1024**3, 'insufficient workspace disk space')
    provenance = dict(sha=args.sha, jf1=JF1, host=host, swift=swift, lane=args.lane, manifest_blob=jf1.MANIFEST_BLOB)
    if args.lane == 'apple':
        provenance['xcode'] = jf1.capture(root, 'xcodebuild', '-version')
        provenance['sdk'] = jf1.capture(root, 'xcrun', '--sdk', 'macosx', '--show-sdk-version')
    (out / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    package = work / 'Swift-JSON'; package.mkdir()
    archive = work / 'source.tar'
    subprocess.run(['git', 'archive', '--format=tar', '--output=' + str(archive), args.sha, 'Package.swift', 'Sources', 'Tests'], cwd=root, check=True)
    subprocess.run(['tar', '-xf', str(archive), '-C', str(package)], check=True)
    archive.unlink()
    before = json.loads(jf1.run(package, out, 'baseline-manifest', 'swift', 'package', 'dump-package'))
    manifest = package / 'Package.swift'; manifest.write_text(graft(manifest.read_text()))
    target = package / 'Sources' / jf1.PRODUCT; target.mkdir()
    tests = package / 'Tests' / TEST_TARGET; tests.mkdir()
    shutil.copyfile(root / SOURCE / 'ValueBridge.swift', target / 'ValueBridge.swift')
    shutil.copyfile(root / SOURCE / 'ValueBridgeTests.swift', tests / 'ValueBridgeTests.swift')
    after = json.loads(jf1.run(package, out, 'candidate-manifest', 'swift', 'package', 'dump-package'))
    inspect_manifests(before, after)
    receipts = {}
    for config in ('debug', 'release'):
        log = jf1.run(package, out, config + '-tests', 'swift', 'test', '-c', config, '--jobs', '2', '--test-product', TEST_TARGET, '--disable-xctest', '--filter', 'jf2')
        receipts[config] = verify_test_log(log, args.lane)
        (out / 'test-receipts.json').write_text(json.dumps(receipts, indent=2) + '\n')
    jf1.need(jf1.capture(root, 'git', 'rev-parse', 'HEAD') == args.sha and not jf1.capture(root, 'git', 'status', '--porcelain'), 'source drift')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sha'); parser.add_argument('output_parent', type=Path)
    parser.add_argument('--lane', choices=['apple', 'linux'], default='apple')
    parser.add_argument('--min-free-gib', type=int, default=20)
    args = parser.parse_args()
    jf1.need(args.min_free_gib >= 1, 'positive disk preflight required')
    root = Path(__file__).resolve().parents[1]
    parent = args.output_parent.expanduser().resolve()
    jf1.need(parent != root and root not in parent.parents, 'output must be outside source checkout')
    os.umask(0o077); parent.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='jf2-', dir=parent)); out = work / 'evidence'; out.mkdir()
    outcome = 'FAILED_OR_INCOMPLETE'
    try:
        qualify(root, work, out, args)
        outcome = 'APPLE_CANDIDATE_TESTS_PASS' if args.lane == 'apple' else 'PORTABLE_POLICY_TESTS_PASS'
    except (Exception, KeyboardInterrupt) as error:
        (out / 'failure.txt').write_text(f'{type(error).__name__}: {error}\n')
        print('JF2 failed:', error, file=sys.stderr)
    finally:
        (out / 'decision.json').write_text(json.dumps({'outcome': outcome, 'product_admission': 'NOT_ADMITTED'}, indent=2) + '\n')
        with tarfile.open(str(work) + '.tar.gz', 'w:gz') as archive:
            archive.add(out, arcname='evidence')
        print(f'ARCHIVE: {work}.tar.gz ({outcome})', flush=True)
        print(f'Disposable worktree retained: {work}', flush=True)
    return int(outcome == 'FAILED_OR_INCOMPLETE')


if __name__ == '__main__':
    sys.exit(main())
