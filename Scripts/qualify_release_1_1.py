#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Executable R0 compiler/SDK probes; prototypes are not shipping JSON APIs."""
import argparse, datetime, hashlib, json, os, pathlib, subprocess, sys
from archive_candidate import files
from preflight import collect

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROBES = ROOT / 'Tools/Release1_1Probes'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['ownership', 'sdk', 'mobile', 'index'], required=True)
    parser.add_argument('--output', default='.build/ci/r0/probe-receipt.json')
    args = parser.parse_args()
    output = ROOT / args.output
    directory = output.parent / args.mode
    directory.mkdir(parents=True, exist_ok=True)
    inputs = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
    receipt = {'schema_version': 1, 'mode': args.mode, 'status': 'running', 'environment': collect(),
               'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               'source_inputs': inputs, 'commands': [], 'runtime_qualification': 'not_run',
               'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    def save():
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(receipt, indent=2) + '\n')
    def run(name, command, expected=0, diagnostic=None):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=900)
        log = directory / (name + '.log')
        log.write_text((result.stdout + result.stderr).replace(str(ROOT), '.'))
        passed = result.returncode == expected and (diagnostic is None or diagnostic in log.read_text())
        receipt['commands'].append({'name': name, 'command': [str(c).replace(str(ROOT), '.') for c in command],
            'exit_code': result.returncode, 'expected_exit': expected, 'expected_diagnostic': diagnostic,
            'status': 'passed' if passed else 'failed', 'log': log.relative_to(ROOT).as_posix(),
            'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        save()
        if not passed: raise RuntimeError('Probe failed: ' + name)
        return result.stdout
    save()
    try:
        if receipt['environment']['status'] != 'passed': raise FileNotFoundError('Supported native baseline required')
        # SwiftPM 6.4's default Swift Build engine publishes native modules/libraries here.
        products = ROOT / '.build/out/Products/Debug'
        swift = ['xcrun', 'swiftc', '-swift-version', '6']
        if args.mode == 'ownership':
            if not (products / 'libJSON.a').is_file(): raise FileNotFoundError('Run swift test first to build the real testable JSON module')
            module = directory / 'ReaderProbe.swiftmodule'
            run('reader-module', swift + ['-parse-as-library', '-emit-module', '-emit-library', '-module-name', 'ReaderProbe',
                '-I', str(products), '-L', str(products), '-lJSON', str(ROOT / 'Tests/JSONTests/Release1_1/ReaderPrototype.swift'),
                '-o', str(directory / 'libReaderProbe.dylib'), '-emit-module-path', str(module)])
            imports = ['-I', str(directory), '-I', str(products)]
            binary = directory / 'reader-consumer'
            run('consumer-compile', swift + imports + ['-L', str(directory), '-lReaderProbe', '-Xlinker', '-rpath', '-Xlinker', str(directory),
                str(PROBES / 'Consumer.swift'), '-o', str(binary)])
            result = run('consumer-run', [str(binary)])
            if 'READER_CONSUMER passed' not in result: raise RuntimeError('Missing executed public consumer assertion')
            run('sendable-negative', swift + imports + ['-typecheck', str(PROBES / 'TaskEscape.swift')], 1, "capture of 'cursor' with non-Sendable type")
            # Region-based transfer checking happens during SIL ownership analysis, not typecheck alone.
            run('task-transfer-negative', swift + imports + ['-c', str(PROBES / 'TaskTransfer.swift'), '-o', str(directory / 'illegal.o')], 1,
                "passing closure as a 'sending' parameter risks causing data races")
            run('nonescapable-unannotated', swift + ['-typecheck', str(PROBES / 'Nonescapable.swift')], 1,
                'an initializer cannot return a ~Escapable result')
            run('lifetime-feature-boundary', swift + ['-typecheck', str(PROBES / 'LifetimeAnnotated.swift')], 1,
                "'@_lifetime' attribute is only valid when experimental feature Lifetimes is enabled")
            receipt['positive_commands'] = 3; receipt['negative_compiler_cases'] = 4
        elif args.mode == 'sdk':
            for sdk, target in [('macosx', 'arm64-apple-macosx27.0'), ('iphoneos', 'arm64-apple-ios27.0'), ('iphonesimulator', 'arm64-apple-ios27.0-simulator')]:
                path = run(sdk + '-path', ['xcrun', '--sdk', sdk, '--show-sdk-path']).strip()
                run(sdk + '-codable-shape', swift + ['-sdk', path, '-target', target, '-typecheck', str(PROBES / 'SwiftDataShape.swift')])
            receipt['sdk_shapes_compiled'] = 3
        elif args.mode == 'mobile':
            for sdk, target in [('iphoneos', 'arm64-apple-ios27.0'), ('iphonesimulator', 'arm64-apple-ios27.0-simulator')]:
                path = run(sdk + '-path', ['xcrun', '--sdk', sdk, '--show-sdk-path']).strip()
                run(sdk + '-consumer', ['swift', 'build', '-c', 'release', '--package-path', str(PROBES / 'MobileConsumer'),
                    '--scratch-path', str(directory / sdk), '--triple', target, '--sdk', path])
            receipt['sdk_consumers_built'] = 2
        else:
            products = ROOT / '.build/out/Products/Release'
            binary = directory / 'index-benchmark'
            run('compile', swift + ['-O', '-parse-as-library', '-I', str(products), '-L', str(products), '-lJSON',
                str(ROOT / 'Tests/JSONTests/Release1_1/IndexPrototype.swift'), str(PROBES / 'IndexBenchmark.swift'), '-o', str(binary)])
            run('measure', [str(binary), str(directory / 'samples.json')])
            samples = json.loads((directory / 'samples.json').read_text())
            if {s['algorithm'] for s in samples} != {'scalar', 'fingerprint-linear', 'array-AVL', 'controlled-hash'}: raise RuntimeError('Incomplete algorithm matrix')
            if {s['width'] for s in samples} != {0,1,4,8,16,32,64,256,1024,10000}: raise RuntimeError('Incomplete width matrix')
            receipt['samples'] = len(samples)
            receipt['samples_sha256'] = hashlib.sha256((directory / 'samples.json').read_bytes()).hexdigest()
        receipt['status'] = 'passed'
    except FileNotFoundError as error:
        receipt['status'] = 'blocked'; receipt['error'] = str(error)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        receipt['status'] = 'failed'; receipt['error'] = str(error)
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save(); print(json.dumps({k:v for k,v in receipt.items() if k not in ['source_inputs','environment']}, indent=2))
    return 0 if receipt['status'] == 'passed' else 2 if receipt['status'] == 'blocked' else 1

if __name__ == '__main__': sys.exit(main())
