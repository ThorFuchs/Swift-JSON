#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run the public schema-example consumer and actual package-boundary negatives."""
import argparse, hashlib, json, pathlib, platform, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--scratch-path')
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    package = 'Examples/SchemaExamplesConsumer'
    base = ['swift', 'run', '--package-path', package]
    if args.scratch_path:
        base += ['--scratch-path', args.scratch_path]
    base += ['--jobs', '2', '-Xswiftc', '-strict-concurrency=complete', '-Xswiftc', '-warnings-as-errors']
    rows = []

    def run(name, command, expected=0, diagnostic=None):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=900)
        text = result.stdout + result.stderr
        path = output / (name + '.log')
        path.write_text(text.replace(str(ROOT), '.'))
        passed = result.returncode == expected and (diagnostic is None or diagnostic in text)
        if expected != 0:
            passed = passed and 'no such module' not in text
        rows.append({'name': name, 'command': command, 'exit_code': result.returncode,
                     'expected_exit': expected, 'status': 'passed' if passed else 'failed',
                     'expected_diagnostic': diagnostic, 'log': path.relative_to(ROOT).as_posix(),
                     'log_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        if not passed:
            raise ValueError('Failed actual consumer/compiler outcome: ' + name)
        return text

    receipt = {'schema_version': 1, 'status': 'failed', 'public_cases': 12, 'negative_probes': 2,
               'scope': 'G1 public consumer and access control; not G7 platform qualification', 'commands': rows}
    try:
        text = run('consumer', base + ['SchemaExamplesConsumer'])
        if 'SCHEMA_EXAMPLES_CONSUMER passed cases=12' not in text.splitlines():
            raise ValueError('Missing exact public consumer case count')
        location = ['swift', 'build', '--package-path', package, '--show-bin-path']
        if args.scratch_path:
            location += ['--scratch-path', args.scratch_path]
        bin_text = run('consumer-bin-path', location)
        bin_paths = [pathlib.Path(line) for line in bin_text.splitlines() if line.startswith('/')]
        if len(bin_paths) != 1 or not bin_paths[0].is_dir():
            raise ValueError('Missing or ambiguous SwiftPM consumer binary path')
        # Inspect only this consumer's actual product directory, not nested safety caches.
        modules = [p for p in [bin_paths[0], bin_paths[0] / 'Modules']
                   if (p / 'JSONSchemaExamples.swiftmodule').exists()]
        if len(modules) != 1:
            raise ValueError('Missing or ambiguous actual consumer modules: ' + str(modules))
        flags = ['swiftc', '-swift-version', '6', '-strict-concurrency=complete', '-warnings-as-errors',
                 '-I', str(modules[0]), '-module-cache-path', str(output / 'module-cache'), '-typecheck']
        if sys.platform == 'darwin':
            sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
            flags += ['-sdk', sdk, '-target', platform.machine() + '-apple-macosx27.0']
        fixtures = ROOT / package / 'CompileNegative'
        run('plan-is-private', flags + [str(fixtures / 'PlanIsPrivate.swift')], expected=1,
            diagnostic="'exampleRoot' is inaccessible due to 'package' protection level")
        run('certificate-is-not-constructible', flags + [str(fixtures / 'CertificateIsNotConstructible.swift')], expected=1,
            diagnostic="'JSONSchemaExampleResult' initializer is inaccessible due to 'internal' protection level")
        receipt['status'] = 'passed'
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('SCHEMA_EXAMPLES_COMPILER ' + receipt['status'] + ' public_cases=12 negatives=2')
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
