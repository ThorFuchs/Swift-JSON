#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compile actual public transformation ownership boundaries, never import failures."""
import argparse, hashlib, json, pathlib, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--modules', default=str(ROOT / '.build/debug'))
    parser.add_argument('--module-cache')
    args = parser.parse_args()
    output = pathlib.Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    cache = pathlib.Path(args.module_cache).resolve() if args.module_cache else output / 'ModuleCache'
    sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
    base = ['xcrun', 'swiftc', '-swift-version', '6', '-sdk', sdk, '-target', 'arm64-apple-macos27.0', '-module-cache-path', str(cache), '-I', str(pathlib.Path(args.modules).resolve()), '-c']
    positive = output / 'PublicConsumer.swift'
    positive.write_text('import JSON\nimport JSONTransform\nfunc send<T: Sendable>(_: T) {}\nfunc check(_ p: JSONTransformProgram) throws { send(p); _ = try p.withExecution(input: .null) { e in try e.next()?.value } }\n')
    cases = [('public-consumer', positive, True, None)]
    for name, diagnostic in [('ReplaceScope', 'cannot pass immutable value as inout argument'), ('DoubleConsume', 'consumed more than once'), ('SendExecution', 'does not conform to the'), ('EscapeScope', 'escaping closure')]:
        cases.append((name, ROOT / 'Tests/CompileNegative/JSONTransform' / (name + '.swift'), False, diagnostic))
    rows = []
    for name, source, positive_case, diagnostic in cases:
        command = base + [str(source), '-o', str(output / (name + '.o'))]
        result = subprocess.run(command, capture_output=True, text=True)
        log = output / (name + '.log'); log.write_text(result.stdout + result.stderr)
        expected = result.returncode == 0 if positive_case else result.returncode != 0 and diagnostic in result.stderr and 'no such module' not in result.stderr
        rows.append(dict(id=name, command=command, exit_code=result.returncode, expected_diagnostic=diagnostic, status='passed' if expected else 'failed', source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
    receipt = dict(status='passed' if all(r['status'] == 'passed' for r in rows) else 'failed', observed=5, cases=rows)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt)); return 0 if receipt['status'] == 'passed' else 1
if __name__ == '__main__': sys.exit(main())
