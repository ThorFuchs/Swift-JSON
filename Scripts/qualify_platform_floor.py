#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile-time evidence for the declared Apple deployment minimums (macOS 15, iOS 18).

Checks the manifest minimums, cross-compiles every library product for iOS devices and
the iOS simulator at iOS 18, and builds and runs an external consumer that declares the
same minimums. It does not run anything on an older OS; that remains outside CI.
"""
import argparse, hashlib, json, os, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONSUMER = 'Tools/PlatformFloorConsumer'
LIBRARIES = ['JSON', 'JSONSchema', 'JSONSchemaExamples', 'JSONStreaming', 'JSONPatch', 'JSONHTML', 'JSONBridges',
             'JSONNavigation', 'JSONInspection', 'JSONTransform', 'JSONValueDSL', 'JSONSchemaDSL']
EXPECTED_PLATFORMS = [{'options': [], 'platformName': 'macos', 'version': '15.0'},
                      {'options': [], 'platformName': 'ios', 'version': '18.0'}]
WITNESS = 'PLATFORM_FLOOR passed witnesses=8'


def check_receipt(receipt):
    expected = {'manifest', 'ios-consumer', 'ios-simulator-consumer',
                'macos-consumer-debug', 'macos-consumer-release'}
    expected.update(prefix + '-' + library for prefix in ('ios', 'ios-simulator') for library in LIBRARIES)
    commands = receipt.get('commands', [])
    names = [entry.get('name') for entry in commands]
    return (receipt.get('status') == 'passed' and receipt.get('libraries') == LIBRARIES
            and receipt.get('platforms') == EXPECTED_PLATFORMS and len(names) == len(expected)
            and set(names) == expected and all(entry.get('exit') == 0 for entry in commands))


def sdk_path(name):
    return subprocess.check_output(['xcrun', '--sdk', name, '--show-sdk-path'], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = (ROOT / args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    receipt = dict(status='failed', commands=[], libraries=LIBRARIES, platforms=EXPECTED_PLATFORMS)

    def run(name, command, env=None, cwd=ROOT):
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, env=env, timeout=1800)
        log = output / (name + '.log'); log.write_text(result.stdout + result.stderr)
        receipt['commands'].append(dict(name=name, command=command, exit=result.returncode,
                                        log=log.name, sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        print(name, result.returncode, flush=True)
        if result.returncode != 0:
            raise RuntimeError(name)
        return result.stdout

    try:
        manifest = json.loads(run('manifest', ['swift', 'package', 'dump-package']))
        if manifest['platforms'] != EXPECTED_PLATFORMS:
            raise RuntimeError('manifest platforms ' + json.dumps(manifest['platforms']))
        for sdk, triple, scratch in [('iphoneos', 'arm64-apple-ios18.0', 'ios'),
                                     ('iphonesimulator', 'arm64-apple-ios18.0-simulator', 'ios-simulator')]:
            # SwiftPM compiles Package.swift for the host. An iOS SDKROOT
            # contaminates that host manifest compilation, so pass the target
            # SDK only through SwiftPM's destination option.
            env = dict(os.environ)
            env.pop('SDKROOT', None)
            target_sdk = sdk_path(sdk)
            for library in LIBRARIES:
                run(scratch + '-' + library, ['swift', 'build', '--target', library, '--triple', triple, '--sdk', target_sdk,
                                               '--scratch-path', '.build/platform-floor/' + scratch], env=env)
            run(scratch + '-consumer', ['swift', 'build', '--package-path', CONSUMER, '--target', 'FloorProbe', '--triple', triple,
                                        '--sdk', target_sdk, '--scratch-path', CONSUMER + '/.build/' + scratch], env=env)
        for config in ['debug', 'release']:
            stdout = run('macos-consumer-' + config, ['swift', 'run', '--package-path', CONSUMER, '-c', config,
                                                       '--scratch-path', CONSUMER + '/.build/macos', 'PlatformFloorConsumer'])
            if stdout.strip().splitlines()[-1:] != [WITNESS]:
                raise RuntimeError('consumer witness ' + config)
        receipt['status'] = 'passed'
    except (RuntimeError, subprocess.SubprocessError, OSError, KeyError, ValueError) as error:
        receipt['error'] = str(error)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=1) + '\n')
    print(json.dumps(dict(status=receipt['status'], commands=len(receipt['commands']), libraries=len(LIBRARIES))))
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
