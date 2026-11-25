#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""JF1: disposable monorepo target/consumer experiment; never edit the checkout."""
import argparse
import copy
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

BASE = 'c2e4aea7cf63bdf8236c22cc9ba0c6a3abeb5201'
MANIFEST_BLOB = '088e256101f1f5f330e20ba5c915cd5e188ba11f'
PRODUCT = 'JSONFoundationModels'
PRODUCTS = set('JSON JSONSchema JSONSchemaExamples JSONStreaming JSONPatch JSONHTML JSONBridges JSONNavigation JSONInspection JSONTransform JSONValueDSL JSONSchemaDSL swift-json'.split())
CASES = ('guided-schema', 'dynamic-schema', 'typed-value', 'ordinary', 'explicit-null', 'absent', 'large-integer', 'int64-max', 'decimal', 'exponent', 'unicode-keys', 'unicode-value', 'nested')
PROBE = Path('Tools/FoundationModelsSpike/Probe.swift')
DECODE = Path('Tools/FoundationModelsSpike/Decode.swift')
ALLOWED = {str(PROBE), str(DECODE), 'Scripts/qualify_foundation_models.py', 'Scripts/test_foundation_models_spike.py', 'Documentation/Architecture/FoundationModels/JF1.md'}


def need(condition, message):
    if not condition:
        raise ValueError(message)


def graft(text):
    # Only two exact insertions into an otherwise unchanged root manifest.
    for old, new in [
        ('    products: [\n', '    products: [\n        .library(name: "JSONFoundationModels", targets: ["JSONFoundationModels"]),\n'),
        ('    targets: [\n', '    targets: [\n        .target(name: "JSONFoundationModels", dependencies: ["JSON", "JSONSchema"]),\n'),
    ]:
        need(text.count(old) == 1, 'unexpected manifest anchor')
        text = text.replace(old, new)
    return text


def named(items):
    result = {item['name']: item for item in items}
    need(len(result) == len(items), 'duplicate manifest name')
    return result


def inspect_manifests(before, after):
    b, a = copy.deepcopy(before), copy.deepcopy(after)
    bp, ap = named(b.pop('products')), named(a.pop('products'))
    bt, at = named(b.pop('targets')), named(a.pop('targets'))
    need(set(bp) == PRODUCTS and not b['dependencies'], 'unexpected baseline products/dependencies')
    need(b['platforms'] == [{'options': [], 'platformName': 'macos', 'version': '15.0'}, {'options': [], 'platformName': 'ios', 'version': '18.0'}], 'deployment floor changed')
    need(b['toolsVersion']['_version'] == '6.4.0' and b['swiftLanguageVersions'] == ['6'], 'tool/language contract changed')
    need(set(ap) == PRODUCTS | {PRODUCT} and set(at) == set(bt) | {PRODUCT}, 'unexpected candidate inventory')
    added_product, added_target = ap.pop(PRODUCT), at.pop(PRODUCT)
    need(added_product['targets'] == [PRODUCT] and added_product['type'] == {'library': ['automatic']}, 'new product is not isolated library')
    need(added_target.get('type') == 'regular' and not added_target.get('settings') and not added_target.get('resources'), 'unexpected bridge target settings')
    deps = added_target['dependencies']
    need(len(deps) == 2 and {d['byName'][0] for d in deps} == {'JSON', 'JSONSchema'}, 'unexpected bridge dependencies')
    need(bp == ap and bt == at, 'existing product/target changed')
    # SwiftPM reports the root path in packageKind. It is not a semantic delta.
    b.pop('packageKind', None); a.pop('packageKind', None)
    need(b == a, 'unrelated manifest change')


def observe(text):
    active = None
    results = {}
    for line in text.splitlines():
        if line.startswith('JF1_BEGIN '):
            name = line.split()[1]
            need(active is None and name in CASES and name not in results, 'unexpected/duplicate case start')
            active = name
        elif line.startswith('JF1_END '):
            _, name, disposition = line.split()
            need(name == active and disposition in ('OBSERVED', 'REJECTED'), 'mismatched case end')
            results[name] = disposition
            active = None
    need(active is None and tuple(results) == CASES and text.splitlines().count('JF1_PROBE_COMPLETE') == 1, 'incomplete probe receipt')
    return results


def consumer_manifest(dependency, bridge=False):
    products = ['JSON', 'JSONSchema'] + ([PRODUCT] if bridge else [])
    edges = ',\n            '.join(f'.product(name: "{n}", package: "swift-json")' for n in products)
    return f'''// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "JF1Consumer", platforms: [.macOS({'"27.0"' if bridge else '.v15'}), .iOS(.v18)],
    dependencies: [.package(path: {json.dumps(str(dependency))})],
    targets: [.executableTarget(name: "Consumer", dependencies: [
            {edges}
    ])], swiftLanguageModes: [.v6])
'''


PLAIN = '''import JSON
import JSONSchema
@main struct Consumer {
    static func main() throws {
        let value = try JSONParser().parse("9007199254740993")
        let schema = try JSONSchemaDocument(JSONParser().parse(#"{"type":"integer"}"#))
        let plan = try JSONSchemaCompiler().compile(schema)
        let result = try JSONSchemaValidator().validate(value, against: plan)
        guard result.isValid, try JSONWriter().writeString(value) == "9007199254740993" else { fatalError("plain consumer") }
        print("JF1_PLAIN_PASS")
    }
}
'''
BRIDGE = '''import JSONFoundationModels
@main struct Consumer {
    static func main() { JF1Probe.run() }
}
'''


def capture(cwd, *args):
    return subprocess.check_output(args, cwd=cwd, text=True, timeout=120).strip()


def run(cwd, evidence, label, *args, timeout=3600):
    print('=== ' + label + ' ===', flush=True)
    log = evidence / (label + '.log')
    with log.open('w') as stream:
        rc = subprocess.run(args, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout).returncode
    (evidence / (label + '.exit')).write_text(str(rc) + '\n')
    need(rc == 0, label + ' failed; see ' + str(log))
    return log.read_text(errors='replace')


def make_consumer(directory, dependency, source, bridge=False):
    (directory / 'Sources/Consumer').mkdir(parents=True)
    (directory / 'Package.swift').write_text(consumer_manifest(dependency, bridge))
    (directory / 'Sources/Consumer/Consumer.swift').write_text(source)


def assert_resolver_graph(graph, name):
    children = graph['dependencies']
    need(len(children) == 1, 'consumer must resolve exactly one local package')
    child = children[0]
    need(child.get('identity', child.get('name', '')).lower() == 'swift-json' and not child['dependencies'], 'unexpected external resolution graph: ' + name)


def qualify(root, work, out, args):
    need(re.fullmatch('[0-9a-f]{40}', args.sha), 'expected exact source SHA')
    need(capture(root, 'git', 'rev-parse', 'HEAD') == args.sha, 'source SHA mismatch')
    need(not capture(root, 'git', 'status', '--porcelain'), 'use a clean checkout')
    need(capture(root, 'git', 'hash-object', 'Package.swift') == MANIFEST_BLOB, 'root manifest changed')
    changed = set(capture(root, 'git', 'diff', '--name-only', BASE, args.sha).splitlines())
    need(changed <= ALLOWED, 'unexpected branch delta')
    swift = capture(root, 'swift', '--version')
    need(re.search(r'Swift version 6\.4\.2(?:\s|$)', swift), 'Swift 6.4.2 required')
    host = capture(root, 'uname', '-sm')
    if args.lane == 'apple':
        need(host == 'Darwin arm64' and int(capture(root, 'sw_vers', '-productVersion').split('.')[0]) >= 27, 'native macOS 27 ARM64 required')
    elif args.lane == 'linux':
        need(host in ('Linux aarch64', 'Linux x86_64'), 'native 64-bit Linux required')
    else:
        need(args.swift_sdk, 'explicit matched WASI SDK required')
    need(shutil.disk_usage(work).free >= args.min_free_gib * 1024**3, 'insufficient workspace disk space')
    provenance = dict(sha=args.sha, base=BASE, host=host, swift=swift, lane=args.lane, swift_sdk=args.swift_sdk,
                      manifest_blob=MANIFEST_BLOB, free_bytes=shutil.disk_usage(work).free)
    if args.lane == 'apple':
        provenance['xcode'] = capture(root, 'xcodebuild', '-version')
        provenance['macos_sdk'] = capture(root, 'xcrun', '--sdk', 'macosx', '--show-sdk-version')
        provenance['ios_sdk'] = capture(root, 'xcrun', '--sdk', 'iphoneos', '--show-sdk-version')
    (out / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    baseline, candidate = (work / name / 'Swift-JSON' for name in ('baseline', 'candidate'))
    baseline.mkdir(parents=True); candidate.parent.mkdir()
    archive = work / 'source.tar'
    subprocess.run(['git', 'archive', '--format=tar', '--output=' + str(archive), args.sha, 'Package.swift', 'Sources', 'Tests'], cwd=root, check=True)
    subprocess.run(['tar', '-xf', str(archive), '-C', str(baseline)], check=True)
    archive.unlink()
    shutil.copytree(baseline, candidate)
    manifest = candidate / 'Package.swift'
    manifest.write_text(graft(manifest.read_text()))
    target = candidate / 'Sources' / PRODUCT
    target.mkdir(); shutil.copyfile(root / PROBE, target / 'Probe.swift')
    before = json.loads(run(baseline, out, 'baseline-manifest', 'swift', 'package', 'dump-package'))
    after = json.loads(run(candidate, out, 'candidate-manifest', 'swift', 'package', 'dump-package'))
    inspect_manifests(before, after)
    for name, dependency in [('baseline', baseline), ('candidate', candidate)]:
        directory = work / (name + '-consumer')
        make_consumer(directory, dependency, PLAIN)
        graph = json.loads(run(directory, out, name + '-graph', 'swift', 'package', 'show-dependencies', '--format', 'json'))
        assert_resolver_graph(graph, name)
        build = ['swift', 'build', '-c', 'release', '--jobs', '2', '--product', 'Consumer', '-v']
        if args.lane == 'wasi':
            build += ['--swift-sdk', args.swift_sdk]
        elif args.lane == 'apple':
            build += ['--triple', 'arm64-apple-macosx15.0', '--sdk', capture(root, 'xcrun', '--sdk', 'macosx', '--show-sdk-path')]
        build_log = run(directory, out, name + '-plain-build', *build)
        need(not re.search(r'(?:-module-name\s+|Compiling\s+)' + PRODUCT + r'\b', build_log), 'ordinary consumer built bridge target')
        binary = Path(capture(directory, *build, '--show-bin-path')) / 'Consumer'
        if args.lane == 'wasi':
            wasm = [p for p in (binary, binary.with_suffix('.wasm')) if p.is_file()]
            need(len(wasm) == 1, 'missing/ambiguous WASI executable')
            with wasm[0].open('rb') as stream:
                need(stream.read(4) == b'\0asm', 'not a WebAssembly executable')
        else:
            need(binary.is_file() and os.access(binary, os.X_OK), 'missing executable')
            if args.lane == 'apple':
                linkage = run(directory, out, name + '-linkage', 'otool', '-L', str(binary))
                need('FoundationModels.framework' not in linkage, 'ordinary JSON consumer links FoundationModels')
            receipt = run(directory, out, name + '-plain-run', str(binary), timeout=120)
            need(receipt.splitlines().count('JF1_PLAIN_PASS') == 1, 'missing plain runtime receipt')
    # Build the opt-in target at the existing deployment floor / portable SDK.
    opts = ['--swift-sdk', args.swift_sdk] if args.lane == 'wasi' else []
    run(candidate, out, 'candidate-target-build', 'swift', 'build', '--target', PRODUCT, '--jobs', '2', *opts)
    if args.lane == 'apple':
        for sdk, triple in [('iphoneos', 'arm64-apple-ios18.0'), ('iphonesimulator', 'arm64-apple-ios18.0-simulator')]:
            sdkpath = capture(root, 'xcrun', '--sdk', sdk, '--show-sdk-path')
            run(candidate, out, sdk + '-candidate-target', 'swift', 'build', '--target', PRODUCT, '--triple', triple, '--sdk', sdkpath, '--scratch-path', str(work / sdk), '--jobs', '2')
            run(work / 'candidate-consumer', out, sdk + '-plain-target', 'swift', 'build', '--target', 'Consumer', '--triple', triple, '--sdk', sdkpath, '--scratch-path', str(work / (sdk + '-plain')), '--jobs', '2')
        directory = work / 'bridge-consumer'
        make_consumer(directory, candidate, BRIDGE, bridge=True)
        observations = {}
        for config in ('debug', 'release'):
            build = ['swift', 'build', '-c', config, '--jobs', '2', '--product', 'Consumer', '-v']
            run(directory, out, config + '-bridge-build', *build)
            binary = Path(capture(directory, *build, '--show-bin-path')) / 'Consumer'
            observations[config] = observe(run(directory, out, config + '-bridge-run', str(binary), timeout=120))
        (out / 'observations.json').write_text(json.dumps(observations, indent=2) + '\n')
        # Independent reverse Codable compile/run, so an unavailable decoder
        # cannot erase the forward probe evidence already collected.
        reverse = work / 'decode-consumer'
        make_consumer(reverse, candidate, (root / DECODE).read_text(), bridge=True)
        run(reverse, out, 'decode-build', 'swift', 'build', '-c', 'release', '--jobs', '2')
        binary = Path(capture(reverse, 'swift', 'build', '-c', 'release', '--show-bin-path')) / 'Consumer'
        receipt = run(reverse, out, 'decode-run', str(binary), timeout=120)
        need(receipt.splitlines().count('JF1_DECODE_COMPLETE') == 1, 'incomplete reverse schema observation')
    need(capture(root, 'git', 'rev-parse', 'HEAD') == args.sha and not capture(root, 'git', 'status', '--porcelain'), 'source changed during probe')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sha'); parser.add_argument('output_parent', type=Path)
    parser.add_argument('--lane', choices=['apple', 'linux', 'wasi'], default='apple')
    parser.add_argument('--swift-sdk'); parser.add_argument('--min-free-gib', type=int, default=20)
    args = parser.parse_args()
    need(args.min_free_gib >= 1, 'positive disk preflight required')
    root = Path(__file__).resolve().parents[1]
    parent = args.output_parent.expanduser().resolve()
    need(parent != root and root not in parent.parents, 'output must be outside source checkout')
    os.umask(0o077)
    parent.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='jf1-', dir=parent)); out = work / 'evidence'; out.mkdir()
    outcome = 'FAILED_OR_INCOMPLETE'
    try:
        qualify(root, work, out, args)
        outcome = {'apple': 'OBSERVATIONS_READY_FOR_REVIEW', 'linux': 'FOCUSED_LINUX_PROBE_PASS', 'wasi': 'FOCUSED_WASI_COMPILE_PASS'}[args.lane]
    except (Exception, KeyboardInterrupt) as error:
        print(f'JF1 failed: {type(error).__name__}: {error}', file=sys.stderr)
        (out / 'failure.txt').write_text(f'{type(error).__name__}: {error}\n')
    finally:
        (out / 'decision.json').write_text(json.dumps({'outcome': outcome, 'packaging_decision': 'NOT_ADMITTED'}, indent=2) + '\n')
        with tarfile.open(str(work) + '.tar.gz', 'w:gz') as archive:
            archive.add(out, arcname='evidence')
        print(f'ARCHIVE: {work}.tar.gz ({outcome})', flush=True)
        print(f'Disposable workspaces retained: {work}', flush=True)
    return int(outcome == 'FAILED_OR_INCOMPLETE')


if __name__ == '__main__':
    sys.exit(main())
