#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile actual implementation ownership boundaries, separate from public consumers."""
import argparse, hashlib, json, pathlib, platform, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--scratch-path', default='.build')
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    rows = []
    receipt = {'schema_version': 1, 'status': 'failed', 'positive_probes': 1, 'negative_probes': 8,
               'scope': 'Trusted implementation compiler fixtures, not public consumer imports', 'commands': rows}

    def run(name, command, expected=0, diagnostic=None):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180)
        text = result.stdout + result.stderr
        path = output / (name + '.log')
        path.write_text(text.replace(str(ROOT), '.'))
        passed = result.returncode == expected and (diagnostic is None or diagnostic in text)
        if expected: passed = passed and 'no such module' not in text
        rows.append({'command': command, 'exit_code': result.returncode, 'expected_exit': expected,
                     'expected_diagnostic': diagnostic, 'status': 'passed' if passed else 'failed',
                     'log': path.relative_to(ROOT).as_posix(), 'log_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        if not passed: raise ValueError('Unexpected actual compiler outcome: ' + name)
        return text

    try:
        location = run('bin-path', ['swift', 'build', '--show-bin-path', '--scratch-path', args.scratch_path])
        bins = [pathlib.Path(p) for p in location.splitlines() if p.startswith('/')]
        if len(bins) != 1: raise ValueError('Missing exact SwiftPM product directory')
        modules = [p for p in [bins[0], bins[0] / 'Modules'] if (p / 'JSONSchemaExamples.swiftmodule').exists()]
        if len(modules) != 1: raise ValueError('Missing exact compiled implementation module')
        flags = ['swiftc', '-swift-version', '6', '-strict-concurrency=complete', '-warnings-as-errors',
                 '-I', str(modules[0]), '-module-cache-path', str(output / 'module-cache'), '-emit-sil']
        if sys.platform == 'darwin':
            sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
            flags += ['-sdk', sdk, '-target', platform.machine() + '-apple-macosx27.0']
        fixtures = ROOT / 'Tests/SchemaExamplesCompilerFixtures'
        probes = [('MoveAndShare', 0, None)]
        probes += [(kind + 'Copy', 1, "'state' consumed more than once") for kind in ['Random', 'Trace']]
        probes += [(kind + 'Sendable', 1, "conformance of 'SchemaExample" + kind + "' to 'Sendable' is unavailable")
                   for kind in ['Random', 'Trace', 'Transport', 'Frame', 'ObjectFrame', 'ArrayFrame']]
        for name, expected, diagnostic in probes:
            fixture = fixtures / (name + '.swift')
            run(name, flags + [str(fixture), '-o', '/dev/null'], expected, diagnostic)
            rows[-1].update(fixture=fixture.relative_to(ROOT).as_posix(), fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest())
        receipt['status'] = 'passed'
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('SCHEMA_EXAMPLES_OWNERSHIP ' + receipt['status'] + ' positive=1 negatives=8')
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
