#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile real public E2 callsites and prove opt-in extension isolation."""
import hashlib
import json
import pathlib
import platform
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OLD = '''import Foundation
import JSON
let a: JSON = .number(42)
let b = JSON.number(JSONNumber(integer: 42))
let inferredFactory = JSON.number
let inferredValue = inferredFactory(42)
let factory: (JSONNumber) -> JSON = JSON.number
let values = [JSONNumber(integer: 1)].map(JSON.number)
if case .number(let n) = a { precondition(n == 42) }
struct Model: Codable { let n: Int }
let model = try JSON(encoding: Model(n: 1)).decode(Model.self)
'''
BRIDGES = '''import Foundation
import JSON
import JSONBridges
func convert<T: BinaryInteger>(_ n: T) -> JSONNumber { n.jsonNumber() }
let n = UInt64.max.jsonNumber()
let recovered = try UInt64(jsonNumber: n)
let decimal = try JSONNumber(parsing: "0.1")
let rounded = try Double(jsonNumber: decimal, policy: .rounded)
let adopted = try rounded.jsonNumberFromRoundTripText()
let foundation = try Decimal(jsonNumber: decimal)
'''


def main():
    output = ROOT / '.build/ci/ergonomics'
    output.mkdir(parents=True, exist_ok=True)
    receipt = {'status': 'failed', 'commands': [], 'build_paths': [], 'guide_fences': 0}
    guides = [ROOT / p for p in (
        'Sources/JSON/Documentation.docc/QuickEntryPoints.md',
        'Sources/JSONBridges/Documentation.docc/NumericFidelity.md',
        'Sources/JSONSchema/Documentation.docc/CompiledPlanConvenience.md')]
    import re
    consumer = (ROOT / 'Examples/Consumer/Sources/Consumer/ErgonomicsExamples.swift').read_text()
    for guide in guides:
        blocks = re.findall(r'```swift\n(.*?)\n```', guide.read_text(), re.S)
        if len(blocks) != 1:
            raise ValueError('Expected one executed guide fence: ' + str(guide))
        indented = '\n'.join('    ' + line for line in blocks[0].splitlines())
        if indented not in consumer:
            raise ValueError('Guide differs from public executable: ' + str(guide))
        receipt['guide_fences'] += 1
    for configuration in ('debug', 'release'):
        # Ask SwiftPM rather than guessing Debug/Debug-linux/triple directories.
        path_command = ['swift', 'build', '-c', configuration, '--show-bin-path']
        products = pathlib.Path(subprocess.check_output(path_command, cwd=ROOT, text=True).strip())
        if not products.is_dir() or not products.is_relative_to(ROOT / '.build'):
            raise ValueError('Invalid SwiftPM products path: ' + str(products))
        include = [products / 'Modules' if (products / 'Modules').is_dir() else products]
        for module in ('JSON', 'JSONBridges'):
            path = include[0] / (module + '.swiftmodule')
            if not (path.is_file() or (path.is_dir() and any(path.glob('*.swiftmodule')))):
                raise ValueError('Missing built module: ' + str(path))
        receipt['build_paths'].append({'command': path_command, 'products': str(products)})
        flags = ['swiftc', '-swift-version', '6', '-strict-concurrency=complete', '-warnings-as-errors']
        if sys.platform == 'darwin':
            sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
            flags += ['-sdk', sdk, '-target', platform.machine() + '-apple-macosx27.0']
        for path in sorted(set(include)):
            flags += ['-I', str(path)]
        for name, source, expected, diagnostic in (
            ('old-calls', OLD, 0, None), ('bridges', BRIDGES, 0, None),
            ('no-bridge-import', 'import JSON\nlet _ = (42 as Int).jsonNumber()\n', 1, 'jsonNumber'),
            ('no-float-bridge', 'import JSON\nimport JSONBridges\nlet _ = Float(0.1).jsonNumberFromRoundTripText()\n', 1, 'jsonNumberFromRoundTripText')):
            stem = configuration + '-' + name
            source_path = output / (stem + '.swift')
            source_path.write_text(source)
            command = flags + ['-typecheck'] + (['-O'] if configuration == 'release' else []) + [str(source_path)]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            log = output / (stem + '.log'); log.write_text(result.stdout + result.stderr)
            passed = (result.returncode == 0) == (expected == 0)
            if diagnostic:
                passed = passed and 'has no member' in result.stderr and diagnostic in result.stderr
            receipt['commands'].append({'command': command, 'exit_code': result.returncode,
                'expected_rejection': expected != 0, 'status': 'passed' if passed else 'failed',
                'log': log.relative_to(ROOT).as_posix(), 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest(),
                'source_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest()})
            if not passed:
                (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
                raise ValueError('Compiler contract failed: ' + stem)
    receipt['status'] = 'passed'
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('ERGONOMICS_COMPILER passed commands=8 guide_fences=3')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
