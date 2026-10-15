#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compiler-negative public composition ownership checks (object emission required)."""
import argparse, json, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    modules = ROOT / '.build/debug'
    if not (modules / 'JSON.swiftmodule').exists():
        modules = ROOT / '.build/debug/Modules'
    expected = {
        'Copy': 'Copyable', 'Send': 'Sendable', 'Escape': 'borrowed',
        'Refund': "no member 'release'", 'Construct': "inaccessible", 'Return': 'Copyable', 'Substitute': 'immutable', 'CrossScope': "no member 'release'"
    }
    records = []
    with tempfile.TemporaryDirectory(prefix='swift-json-composition-') as directory:
        for name, diagnostic in expected.items():
            source = pathlib.Path(directory) / (name + '.swift')
            source.write_bytes((ROOT / 'Tools/CompositionQualification/Negative' / (name + '.swift.txt')).read_bytes())
            command = ['swiftc', '-c', '-swift-version', '6', '-I', str(modules), str(source), '-o', str(source.with_suffix('.o'))]
            run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
            log = run.stdout + run.stderr
            (output / (name + '.log')).write_text(log)
            records.append(dict(name=name, command=command, exit_code=run.returncode,
                expected_diagnostic=diagnostic, status='passed' if run.returncode != 0 and diagnostic in log and 'no such module' not in log else 'failed'))
    receipt = dict(status='passed' if all(r['status']=='passed' for r in records) else 'failed',
                   compiler_negative_cases=len(records), records=records)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status']=='passed' else 1
if __name__ == '__main__': raise SystemExit(main())
