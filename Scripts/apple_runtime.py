#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Build on the native baseline, then execute those bytes on separately identified runtimes."""
import argparse
import datetime
import hashlib
import json
import pathlib
import platform
import re
import shutil
import subprocess
import sys

from archive_candidate import files
from preflight import collect
from qualify_apple_deployment import LIBRARIES, CONSUMERS

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROGRAMS = CONSUMERS + ['DiskPayload']
MARKERS = {
    'Consumer': ['Consumer passed:', 'ERGONOMICS_PUBLIC_CONSUMER passed guides=3',
                 'JSONHTML_ANNOTATION_PUBLIC_CONSUMER passed typed_targets=2 coherent_spans=2 replaced_spans=0'],
    'SchemaExamplesConsumer': ['SCHEMA_EXAMPLES_CONSUMER passed cases=15'],
    'NavigationConsumer': ['NAVIGATION_CONSUMER passed cases=18'],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(root):
    return [dict(path=p.relative_to(root).as_posix(), sha256=digest(p)) for p in files(root)]


def payload_records(bundle):
    records = []
    for path in sorted(bundle.rglob('*')):
        if path.is_symlink():
            raise ValueError('Runtime bundle must not contain symlinks')
        if path.is_file() and path.name != 'MANIFEST.json':
            records.append(dict(path=path.relative_to(bundle).as_posix(), sha256=digest(path)))
    return records


def verify_bundle(bundle, source):
    recorded = json.loads((bundle / 'MANIFEST.json').read_text())
    if recorded != payload_records(bundle):
        raise ValueError('Runtime bundle manifest mismatch')
    producer = json.loads((bundle / 'producer.json').read_text())
    if producer['status'] != 'passed' or producer['source_inputs'] != source:
        raise ValueError('Runtime bundle does not match this checkout')
    return producer


def runtime_matches(actual, expected):
    # 26.2 deliberately does not accept 26.6 or a rolling macOS 26 runner.
    return actual == expected or actual.startswith(expected + '.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['build', 'macos', 'simulator'])
    parser.add_argument('--output', required=True)
    parser.add_argument('--bundle')
    parser.add_argument('--expected-os', default='27')
    args = parser.parse_args()
    out = pathlib.Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    bundle = pathlib.Path(args.bundle).resolve() if args.bundle else out / 'bundle'
    source = snapshot(ROOT)
    receipt = dict(schema_version=1, status='running', mode=args.mode,
                   git_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                   source_inputs=source, commands=[], runtime_results=[],
                   architecture=platform.machine(), macos=platform.mac_ver()[0],
                   started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())

    def save():
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')

    def run(name, command, timeout=1200):
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        log = out / (name + '.log')
        log.write_text(result.stdout + result.stderr)
        receipt['commands'].append(dict(name=name, command=command, exit_code=result.returncode,
                                       log=log.name, log_sha256=digest(log)))
        save()
        if result.returncode:
            raise RuntimeError(name + ' failed, exit=' + str(result.returncode))
        return result.stdout

    def execute(sdk, prefix, label):
        products = bundle / sdk
        text = run(label + '-uri', prefix + [str(products / 'DiskPayload'), 'uri-probe', str(out / 'unused')])
        if 'URI_COMPATIBILITY passed cases=54' not in text.splitlines():
            raise ValueError('Incomplete URI compatibility proof')
        for name in CONSUMERS:
            text = run(label + '-' + name, prefix + [str(products / name)])
            if not all(marker in text for marker in MARKERS[name]):
                raise ValueError('Incomplete public consumer: ' + name)
        disk = out / (label + '-disk')
        if disk.exists():
            raise ValueError('Disk proof requires a fresh directory')
        for phase in ['save', 'reopen-update', 'verify-update']:
            text = run(label + '-disk-' + phase,
                       prefix + [str(products / 'DiskPayload'), phase, str(disk)])
            if 'DISK_PAYLOAD passed phase=' + phase + ' fixtures=8' not in text.splitlines():
                raise ValueError('Incomplete disk proof')
        if len(list(disk.glob('payload-*.plist'))) != 8:
            raise ValueError('Expected eight materialized payloads')
        if sdk == 'macosx':
            text = run(label + '-cli', [sys.executable, '-B', 'Scripts/qualify_cli.py',
                       '--binary', str(products / 'swift-json'), '--output', str(out / (label + '-cli.json'))])
            result = json.loads(text.strip().splitlines()[-1])
            if (result['observed'], result['passed'], result['failed']) != (53, 53, 0):
                raise ValueError('Incomplete older-runtime CLI acceptance')
        receipt['runtime_results'].append(dict(label=label, status='passed', consumers=3,
            schema_examples_cases=15, navigation_cases=18, disk_fixtures=8, disk_processes=3,
            uri_cases=54, cli_cases=53 if sdk == 'macosx' else 0))
        save()

    save()
    try:
        if args.mode == 'build':
            receipt['environment'] = collect()
            if receipt['environment']['status'] != 'passed':
                raise FileNotFoundError('Native producer requires macOS/SDK 27 and Swift 6.4')
            if bundle.exists():
                raise ValueError('Use a fresh runtime bundle destination')
            bundle.mkdir()
            package = out / 'Consumer'
            for name in CONSUMERS:
                destination = package / 'Sources' / name
                destination.mkdir(parents=True)
                if name == 'NavigationConsumer':
                    shutil.copyfile(ROOT / 'Tools/NavigationQualification/Consumer.swift', destination / 'main.swift')
                else:
                    source_dir = ROOT / ('Examples/' + name + '/Sources/' + name)
                    shutil.copytree(source_dir, destination, dirs_exist_ok=True)
            disk_source = package / 'Sources/DiskPayload'
            disk_source.mkdir()
            shutil.copyfile(ROOT / 'Tools/AppleDeploymentQualification/DiskPayload.swift', disk_source / 'DiskPayload.swift')
            shutil.copyfile(ROOT / 'Tools/MobileQualification/Sources/ProbeCases/Fixtures/version1.json', disk_source / 'version1.json')
            shutil.copyfile(ROOT / 'Tests/Fixtures/Schema/URIResolution.json', disk_source / 'URIResolution.json')
            dependencies = ', '.join('.product(name: "' + name + '", package: "Swift-JSON")' for name in LIBRARIES)
            targets = ',\n'.join('.executableTarget(name: "' + name + '", dependencies: [' + dependencies + ']'
                + (', resources: [.copy("version1.json"), .copy("URIResolution.json")]' if name == 'DiskPayload' else '') + ')' for name in PROGRAMS)
            (package / 'Package.swift').write_text('// swift-tools-version: 6.4\nimport PackageDescription\n'
                'let package = Package(name: "AppleRuntimeConsumer", platforms: [.macOS("14.0"), .iOS("17.0")],'
                'dependencies: [.package(name: "Swift-JSON", path: ' + json.dumps(str(ROOT)) + ')],'
                'targets: [' + targets + '], swiftLanguageModes: [.v6])\n')
            for sdk, triple in [('macosx', 'arm64-apple-macosx14.0'),
                                ('iphonesimulator', 'arm64-apple-ios17.0-simulator')]:
                sdkpath = run(sdk + '-sdk', ['xcrun', '--sdk', sdk, '--show-sdk-path']).strip()
                command = ['swift', 'build', '--package-path', str(package), '--scratch-path', str(out / ('build-' + sdk)),
                           '--jobs', '2', '--disable-index-store', '-debug-info-format', 'none',
                           '--triple', triple, '--sdk', sdkpath,
                           '-Xlinker', '-rpath', '-Xlinker', '@executable_path/Frameworks']
                run(sdk + '-build', command)
                products = pathlib.Path(run(sdk + '-bin-path', command + ['--show-bin-path']).strip())
                dest = bundle / sdk
                dest.mkdir()
                if sdk == 'macosx':
                    cli_command = ['swift', 'build', '--product', 'swift-json', '--scratch-path', str(out / 'build-cli'),
                        '--jobs', '2', '--disable-index-store', '-debug-info-format', 'none',
                        '--triple', triple, '--sdk', sdkpath,
                        '-Xlinker', '-rpath', '-Xlinker', '@executable_path/Frameworks']
                    run('cli-build', cli_command)
                    cli_products = pathlib.Path(run('cli-bin-path', cli_command + ['--show-bin-path']).strip())
                    shutil.copy2(cli_products / 'swift-json', dest / 'swift-json')
                    metadata = run('cli-minimum', ['xcrun', 'vtool', '-show-build', str(dest / 'swift-json')])
                    if not re.search(r'\bminos\s+14\.0\b', metadata):
                        raise ValueError('Unexpected CLI deployment minimum')
                for name in PROGRAMS:
                    shutil.copy2(products / name, dest / name)
                    metadata = run(sdk + '-' + name + '-minimum', ['xcrun', 'vtool', '-show-build', str(dest / name)])
                    minimum = '14.0' if sdk == 'macosx' else '17.0'
                    if not re.search(r'\bminos\s+' + re.escape(minimum) + r'\b', metadata):
                        raise ValueError('Unexpected deployment command for ' + name)
                for resource in products.glob('*.bundle'):
                    shutil.copytree(resource, dest / resource.name)
                schemas = [p for p in dest.rglob('*.json') if 'Draft2020-12' in p.parts and p.name != 'Provenance.json']
                if len(schemas) != 9:
                    raise ValueError('Expected nine packaged meta-schemas')
                frameworks = dest / 'Frameworks'
                frameworks.mkdir()
                run(sdk + '-swift-libraries', ['xcrun', 'swift-stdlib-tool', '--copy', '--platform', sdk,
                    '--scan-folder', str(dest), '--destination', str(frameworks), '--sign', '-'])
            # Relocation is tested with only the copied bytes, not build output paths.
            execute('macosx', [], 'producer-macos')
            receipt['status'] = 'passed'
            (bundle / 'producer.json').write_text(json.dumps(receipt, indent=2) + '\n')
            (bundle / 'MANIFEST.json').write_text(json.dumps(payload_records(bundle), indent=2) + '\n')
            print('APPLE_RUNTIME_BUILD passed libraries=8 consumers=3 disk_fixtures=8 builds=2 resources=9 uri_cases=54 cli_cases=53')
        else:
            producer = verify_bundle(bundle, source)
            receipt['producer_git_head'] = producer['git_head']
            receipt['bundle_manifest_sha256'] = digest(bundle / 'MANIFEST.json')
            run('host-version', ['sw_vers'])
            if args.mode == 'macos':
                if not runtime_matches(receipt['macos'], args.expected_os):
                    raise FileNotFoundError('Expected macOS ' + args.expected_os + '; actual=' + receipt['macos'])
                execute('macosx', [], 'macos-' + receipt['macos'])
            else:
                inventory = json.loads(run('simulator-runtimes', ['xcrun', 'simctl', 'list', 'runtimes', '-j']))['runtimes']
                runtime = next((r for r in inventory if r['isAvailable'] and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')
                                and runtime_matches(r['version'], args.expected_os)), None)
                if runtime is None:
                    raise FileNotFoundError('Requested available iOS/iPadOS simulator runtime ' + args.expected_os + ' is missing')
                receipt['simulator_runtime'] = runtime
                types = json.loads(run('device-types', ['xcrun', 'simctl', 'list', 'devicetypes', '-j']))['devicetypes']
                supported = {d['identifier'] for d in runtime.get('supportedDeviceTypes', [])}
                for family, product in [('iPhone', 'iPhone'), ('iPad', 'iPad')]:
                    model = next((d for d in types if d['productFamily'] == product
                                  and (d['identifier'] in supported if supported else d['name'] in ['iPhone 15', 'iPad (10th generation)'])), None)
                    if model is None:
                        raise FileNotFoundError('No compatible ' + family + ' model for the requested runtime')
                    device = run(family + '-create', ['xcrun', 'simctl', 'create', 'SwiftJSON-Deployment-' + family,
                                                     model['identifier'], runtime['identifier']]).strip()
                    try:
                        run(family + '-boot', ['xcrun', 'simctl', 'boot', device])
                        run(family + '-bootstatus', ['xcrun', 'simctl', 'bootstatus', device, '-b'])
                        execute('iphonesimulator', ['xcrun', 'simctl', 'spawn', device], family)
                    finally:
                        run(family + '-delete', ['xcrun', 'simctl', 'delete', device])
            receipt['status'] = 'passed'
            print('APPLE_RUNTIME passed runtimes=' + str(len(receipt['runtime_results'])))
    except FileNotFoundError as error:
        receipt.update(status='blocked', error=str(error))
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError) as error:
        receipt.update(status='failed', error=str(error))
    finally:
        receipt['source_inputs_unchanged'] = source == snapshot(ROOT)
        if not receipt['source_inputs_unchanged']:
            receipt.update(status='failed', error='Source inputs changed during qualification')
        receipt['completed_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save()
        print(json.dumps({k: receipt[k] for k in ['status', 'runtime_results', 'source_inputs_unchanged']}))
    return 0 if receipt['status'] == 'passed' else 2 if receipt['status'] == 'blocked' else 1


if __name__ == '__main__':
    sys.exit(main())
