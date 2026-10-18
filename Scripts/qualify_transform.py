#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run the actual JSON/JSONTransform-only consumer outside any Git checkout."""
import argparse, hashlib, json, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = (ROOT / args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    source = ROOT / 'Tools/TransformQualification'
    rows = []
    with tempfile.TemporaryDirectory(prefix='swift-json-transform-consumer-') as temporary:
        consumer = pathlib.Path(temporary)
        for file in sorted(source.rglob('*')):
            if not file.is_file() or any(x in file.relative_to(source).parts for x in ['.build', '.swiftpm']): continue
            target = consumer / file.relative_to(source); target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(file.read_bytes())
        manifest = consumer / 'Package.swift'
        manifest.write_text(manifest.read_text().replace('path: "../.."', 'path: ' + json.dumps(str(ROOT))))
        inputs = [{'path':p.relative_to(consumer).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(consumer.rglob('*')) if p.is_file()]
        for mode in ['debug', 'release']:
            command = ['swift', 'run', '-c', mode, '--package-path', str(consumer), '--jobs', '2', 'TransformConsumer']
            result = subprocess.run(command, capture_output=True, text=True)
            log = output / (mode + '.log'); log.write_text(result.stdout + result.stderr)
            reports = []
            for line in result.stdout.splitlines():
                try: reports.append(json.loads(line))
                except ValueError: continue
            expected = dict(consumer='JSON+JSONTransform', witnesses=11, status='passed')
            passed = result.returncode == 0 and reports == [expected]
            rows.append(dict(command=command, exit_code=result.returncode, status='passed' if passed else 'failed', witnesses=reports, log=log.name, log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
            if not passed: break
    receipt = dict(status='passed' if len(rows) == 2 and all(r['status'] == 'passed' for r in rows) else 'failed', source_files=inputs, commands=rows, scope='Public path-dependent SwiftPM graph, Debug/Release, no private imports; not a released-version resolution')
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt)); return 0 if receipt['status'] == 'passed' else 1
if __name__ == '__main__': raise SystemExit(main())
