#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compiler-negative public composition ownership checks (object emission required)."""
import argparse, hashlib, json, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]

def compiler_outcome(code, log, object_exists, diagnostic=None):
    """An abort never establishes an expected ownership rejection."""
    if 'no such module' in log:
        return 'failed'
    if code < 0 or any(s in log for s in ('Stack dump:', 'fatal error encountered during compilation', 'Found ownership error?!')):
        return 'compiler_abort' if not object_exists else 'failed'
    if diagnostic is None:
        return 'compiled' if code == 0 and object_exists else 'failed'
    return 'rejected' if code > 0 and not object_exists and diagnostic in log else 'failed'

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
        'Refund': "no member 'release'", 'Construct': "inaccessible", 'Return': 'Copyable', 'Substitute': 'immutable', 'CrossScope': "no member 'release'",
        'SubstituteRetention': 'immutable', 'SubstituteCaughtWork': 'immutable',
        'SubstituteCaughtRetention': 'immutable',
        'RootCopy': 'Copyable', 'RootSend': 'Sendable', 'RootEscape': 'borrowed',
        'RootConstruct': 'inaccessible', 'RootReturn': 'Copyable',
        'RootSubstitute': 'immutable', 'RootRefund': "no member 'release'"
    }
    records = []
    callsites = []
    with tempfile.TemporaryDirectory(prefix='swift-json-composition-') as directory:
        def compile_case(name, folder, diagnostic):
            source = pathlib.Path(directory) / (name + '.swift')
            source.write_bytes((ROOT / 'Tools/CompositionQualification' / folder / (name + '.swift.txt')).read_bytes())
            command = ['swiftc', '-c', '-swift-version', '6', '-I', str(modules), str(source), '-o', str(source.with_suffix('.o'))]
            run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
            log = run.stdout + run.stderr
            (output / (name + '.log')).write_text(log)
            return dict(name=name, command=command, exit_code=run.returncode,
                source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                expected_diagnostic=diagnostic,
                outcome=compiler_outcome(run.returncode, log, source.with_suffix('.o').exists(), diagnostic))
        for name, diagnostic in expected.items():
            record = compile_case(name, 'Negative', diagnostic)
            record['status'] = 'passed' if record['outcome'] == 'rejected' else 'failed'
            records.append(record)
        for name, diagnostic in [('ClosureBorrow', None), ('RootClosureBorrow', None), ('ExplicitBorrowParameters', None),
            ('MethodEscape', 'borrowed'), ('ContainerEscape', 'borrowed'),
            ('MethodBorrow', None), ('RootContainerEscape', 'borrowed'), ('LocalFunctionBorrow', None)]:
            record = compile_case(name, 'Compiler', diagnostic)
            # Preserve these known call-site compiler bugs separately. A newer
            # compiler may diagnose the escapes or compile the nonescaping use.
            known_abort = name in {'MethodEscape', 'ContainerEscape', 'MethodBorrow', 'RootContainerEscape', 'LocalFunctionBorrow'}
            record['status'] = ('blocked' if known_abort and record['outcome'] == 'compiler_abort' else
                'passed' if record['outcome'] == ('compiled' if diagnostic is None else 'rejected') else 'failed')
            callsites.append(record)
    receipt = dict(status='passed' if all(r['status']=='passed' for r in records) else 'failed',
                   compiler_negative_cases=len(records), records=records,
                   callsite_cases=len(callsites), callsites=callsites,
                   compiler_abort_cases=sum(r['outcome']=='compiler_abort' for r in callsites))
    if any(r['status']=='failed' for r in callsites): receipt['status'] = 'failed'
    receipt['compiler_robustness_status'] = ('blocked' if receipt['compiler_abort_cases'] else
        'failed' if any(r['status']=='failed' for r in callsites) else 'passed')
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status']=='passed' else 1
if __name__ == '__main__': raise SystemExit(main())
