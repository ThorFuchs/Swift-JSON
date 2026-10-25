#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile actual public transformation ownership boundaries, never import failures."""
import argparse, hashlib, json, pathlib, platform, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]

def ordinary_rejection(exit_code, stderr, expected):
    """Require the intended primary diagnostic and reject compiler crashes."""
    crash_markers = ('Stack dump:', 'Assertion failed', 'fatal error encountered during compilation',
                     'Please submit a bug report', 'compile command failed due to signal')
    primary = [line.split(': error: ', 1)[1] for line in stderr.splitlines() if ': error: ' in line]
    return (exit_code > 0 and 'no such module' not in stderr
            and not any(marker in stderr for marker in crash_markers)
            and any(expected in diagnostic for diagnostic in primary))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--modules', default=str(ROOT / '.build/debug'))
    parser.add_argument('--module-cache')
    args = parser.parse_args()
    output = pathlib.Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    cache = pathlib.Path(args.module_cache).resolve() if args.module_cache else output / 'ModuleCache'
    base = ['swiftc', '-swift-version', '6']
    if sys.platform == 'darwin':
        sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
        base = ['xcrun', 'swiftc', '-swift-version', '6', '-sdk', sdk,
                '-target', platform.machine() + '-apple-macos27.0']
    base += ['-module-cache-path', str(cache), '-I', str(pathlib.Path(args.modules).resolve()), '-c']
    positive = output / 'PublicConsumer.swift'
    positive.write_text('import JSON\nimport JSONTransform\nfunc send<T: Sendable>(_: T) {}\nfunc check(_ p: JSONTransformProgram) throws { send(p); _ = try p.withExecution(input: .null) { e in try e.next()?.value } }\n')
    cases = [('public-consumer', positive, True, None)]
    for name, diagnostic in [('ReplaceScope', 'cannot pass immutable value as inout argument'), ('SendExecution', 'does not conform to the'), ('PrivateVM', "cannot find type 'FilterVM'"), ('PrivateContext', "cannot find type 'CLIJobContext'")]:
        cases.append((name, ROOT / 'Tests/CompileNegative/JSONTransform' / (name + '.swift'), False, diagnostic))
    for name in ['EscapeScope', 'HandleAliases']:
        cases.append((name, ROOT / 'Tests/CompilePositive/JSONTransform' / (name + '.swift'), True, None))
    rows = []
    for name, source, positive_case, diagnostic in cases:
        command = base + [str(source), '-o', str(output / (name + '.o'))]
        result = subprocess.run(command, capture_output=True, text=True)
        log = output / (name + '.log'); log.write_text(result.stdout + result.stderr)
        expected = result.returncode == 0 if positive_case else ordinary_rejection(result.returncode, result.stderr, diagnostic)
        rows.append(dict(id=name, command=command, exit_code=result.returncode, expected_diagnostic=diagnostic, status='passed' if expected else 'failed', source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
    receipt = dict(status='passed' if all(r['status'] == 'passed' for r in rows) else 'failed', observed=len(cases), cases=rows)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt)); return 0 if receipt['status'] == 'passed' else 1
if __name__ == '__main__': sys.exit(main())
