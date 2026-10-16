#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile real Apple deployment consumers; execution retains the actual host OS."""
import argparse
import datetime
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys

from archive_candidate import files
from preflight import collect

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARIES = ['JSON', 'JSONSchema', 'JSONSchemaExamples', 'JSONStreaming',
             'JSONPatch', 'JSONHTML', 'JSONBridges', 'JSONNavigation']
CONSUMERS = ['Consumer', 'SchemaExamplesConsumer', 'NavigationConsumer']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='.build/ci/apple-deployment/probes')
    args = parser.parse_args()
    out = (ROOT / args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    environment = collect()
    receipt = dict(status='running', environment=environment,
                   started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   source_inputs=[dict(path=p.relative_to(ROOT).as_posix(),
                                       sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files()],
                   commands=[], runtime_scope='Current macOS host only; cross-builds do not establish older-OS, simulator or physical-device execution.')

    def save():
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')

    def run(name, command, negative=None):
        log = out / (name + '.log')
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        text = result.stdout + result.stderr
        log.write_text(text)
        passed = (result.returncode == 0 if negative is None
                  else result.returncode != 0 and all(value in text for value in negative))
        receipt['commands'].append(dict(name=name, command=command,
              exit_code=result.returncode, expected='success' if negative is None else 'availability rejection',
              passed=passed, log=log.relative_to(out).as_posix(),
              log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        save()
        if not passed:
            raise RuntimeError(name + ' failed; inspect ' + str(log))
        return text

    save()
    if environment['status'] != 'passed':
        receipt['status'] = 'blocked'; save()
        print(json.dumps(environment, indent=2))
        return 2
    try:
        manifest = json.loads(run('manifest', ['swift', 'package', 'dump-package']))
        assert manifest['platforms'] == [dict(options=[], platformName='macos', version='14.0'),
                                         dict(options=[], platformName='ios', version='17.0')]
        assert manifest['dependencies'] == [] and manifest['swiftLanguageVersions'] == ['6']
        assert manifest['toolsVersion']['_version'] == '6.4.0'
        assert {p['name'] for p in manifest['products']} == set(LIBRARIES) | {'swift-json'}
        consumer = out / 'Consumer'
        consumer.mkdir(exist_ok=True)
        source_records = []
        for name, source in [('Consumer', ROOT / 'Examples/Consumer/Sources/Consumer'),
                             ('SchemaExamplesConsumer', ROOT / 'Examples/SchemaExamplesConsumer/Sources/SchemaExamplesConsumer')]:
            shutil.copytree(source, consumer / 'Sources' / name, dirs_exist_ok=True)
            for path in sorted(source.rglob('*.swift')):
                source_records.append(dict(path=path.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        nav_source = ROOT / 'Tools/NavigationQualification/Consumer.swift'
        nav = consumer / 'Sources/NavigationConsumer'
        nav.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(nav_source, nav / 'main.swift')
        source_records.append(dict(path=nav_source.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(nav_source.read_bytes()).hexdigest()))
        dependencies = ', '.join('.product(name: "' + name + '", package: "Swift-JSON")' for name in LIBRARIES)
        targets = ',\n'.join('.executableTarget(name: "' + name + '", dependencies: [' + dependencies + '])' for name in CONSUMERS)
        # Only the generated external consumer is written; the root manifest is never mutated.
        (consumer / 'Package.swift').write_text('// swift-tools-version: 6.4\nimport PackageDescription\n'
            'let package = Package(name: "AppleDeploymentConsumer", platforms: [.macOS("14.0"), .iOS("17.0")],'
            'dependencies: [.package(name: "Swift-JSON", path: ' + json.dumps(str(ROOT)) + ')], targets: [' + targets + '], swiftLanguageModes: [.v6])\n')
        receipt['consumer_source_inputs'] = source_records
        directories = {}
        architecture = environment['architecture']
        for sdk, triple in [('macosx', architecture + '-apple-macosx14.0'),
                            ('iphoneos', 'arm64-apple-ios17.0'),
                            ('iphonesimulator', 'arm64-apple-ios17.0-simulator')]:
            path = run(sdk + '-path', ['xcrun', '--sdk', sdk, '--show-sdk-path']).strip()
            scratch = out / ('build-' + sdk)
            run(sdk + '-build', ['swift', 'build', '--package-path', str(consumer),
                '--scratch-path', str(scratch), '--jobs', '2', '--disable-index-store',
                '-debug-info-format', 'none', '--triple', triple, '--sdk', path])
            products = scratch / 'out/Products/Debug'
            assert all((products / name).is_file() for name in CONSUMERS), (sdk, 'missing consumer executable')
            assert all((products / (name + '.swiftmodule')).is_dir()
                       and (products / (name + '.o')).is_file() for name in LIBRARIES), (sdk, 'missing linked library module/object')
            for name in CONSUMERS:
                metadata = run(sdk + '-' + name + '-load-commands', ['xcrun', 'vtool', '-show-build', str(products / name)])
                minimum = '14.0' if sdk == 'macosx' else '17.0'
                assert re.search(r'\bminos\s+' + re.escape(minimum) + r'\b', metadata), metadata
            schema_files = [p for p in products.rglob('*.json')
                            if 'Draft2020-12' in p.parts and p.name != 'Provenance.json']
            assert len(schema_files) == 9, (sdk, schema_files)
            directories[sdk] = (path, products)
            if sdk == 'macosx':
                for name in CONSUMERS:
                    text = run(name + '-execute', [str(products / name)])
                    marker = {'Consumer': 'Consumer passed:',
                              'SchemaExamplesConsumer': 'SCHEMA_EXAMPLES_CONSUMER passed cases=15',
                              'NavigationConsumer': 'NAVIGATION_CONSUMER passed cases=18'}[name]
                    assert marker in text
        probes = ROOT / 'Tools/AppleDeploymentQualification'
        mac_sdk, mac_modules = directories['macosx']
        ios_sdk, ios_modules = directories['iphoneos']
        cases = [
            ('mac14-unguarded', mac_sdk, mac_modules, architecture + '-apple-macosx14.0', 'PDFUnguarded.swift', ['preparingPDF', 'only available in macOS 26.0']),
            ('mac15-unguarded', mac_sdk, mac_modules, architecture + '-apple-macosx15.0', 'PDFUnguarded.swift', ['preparingPDF', 'only available in macOS 26.0']),
            ('mac14-guarded', mac_sdk, mac_modules, architecture + '-apple-macosx14.0', 'PDFGuarded.swift', None),
            ('mac26_2-unguarded', mac_sdk, mac_modules, architecture + '-apple-macosx26.2', 'PDFUnguarded.swift', None),
            ('ios17-unguarded', ios_sdk, ios_modules, 'arm64-apple-ios17.0', 'PDFUnguarded.swift', ['preparingPDF', 'only available in iOS 26.0']),
            ('ios17-guarded', ios_sdk, ios_modules, 'arm64-apple-ios17.0', 'PDFGuarded.swift', None),
            ('swiftdata27', mac_sdk, mac_modules, architecture + '-apple-macosx27.0', 'SwiftDataPayload.swift', None),
            ('swiftdata26_2', mac_sdk, mac_modules, architecture + '-apple-macosx26.2', 'SwiftDataPayload.swift', ['codable', 'only available in macOS 27'])]
        for name, sdk, modules, triple, source, negative in cases:
            run(name, ['swiftc', '-swift-version', '6', '-sdk', sdk, '-target', triple,
                       '-I', str(modules), '-typecheck', str(probes / source)], negative)
        receipt.update(status='passed', libraries=8, consumers=3, mobile_builds=2,
                       pdf_availability_cases=6, swiftdata_availability_cases=2,
                       schema_resources_per_build=9, runtime_host=environment['macos'])
        print('APPLE_DEPLOYMENT passed libraries=8 consumers=3 mobile_builds=2 pdf_availability=6 swiftdata_availability=2 resources=9')
        return 0
    except (AssertionError, RuntimeError, OSError) as error:
        receipt.update(status='failed', error=str(error))
        print(str(error), file=sys.stderr)
        return 1
    finally:
        receipt['completed_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save()


if __name__ == '__main__':
    sys.exit(main())
