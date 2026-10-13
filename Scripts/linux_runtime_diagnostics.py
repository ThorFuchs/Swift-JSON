#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Isolate Linux runtime leaks; never suppress leak or address checks in package tests."""
import argparse, hashlib, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
READER = '''import Foundation
let url = URL(fileURLWithPath: CommandLine.arguments[2])
let data: Data
if CommandLine.arguments[1] == "data" {
    data = try Data(contentsOf: url)
} else {
    let handle = try FileHandle(forReadingFrom: url)
    data = try handle.readToEnd() ?? Data()
    try handle.close()
}
precondition(data.isEmpty)
print("EMPTY_FILE_READ bytes=0")
'''

def main():
    p = argparse.ArgumentParser(); p.add_argument('--output', required=True); a = p.parse_args()
    out = ROOT / a.output; out.mkdir(parents=True, exist_ok=True)
    (out / 'empty.json').write_bytes(b'')
    report = {'status': 'running', 'probes': [], 'sanitizer_suppressions': False}
    def run(name, command):
        log = out / (name + '.log')
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
        text = (result.stdout + result.stderr).replace(str(ROOT), '.')
        log.write_text(text)
        report['probes'].append({'name': name, 'command': [x.replace(str(ROOT), '.') for x in command],
            'exit_code': result.returncode, 'log': log.relative_to(ROOT).as_posix(),
            'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        return result.returncode, text
    failed = False
    for name, source in [('reader', READER), ('xctest', 'import XCTest\nXCTMain([])\n')]:
        path = out / (name + '.swift'); path.write_text(source)
        code, _ = run('compile-' + name, ['swiftc', '-sanitize=address', '-g', str(path), '-o', str(out / name)])
        failed |= code != 0
        if code: continue
        modes = ['data', 'handle'] if name == 'reader' else ['empty-xctest']
        for mode in modes:
            command = [str(out / name)] + ([mode, str(out / 'empty.json')] if name == 'reader' else [])
            code, text = run(mode, command)
            if mode == 'handle':
                expected = code == 0 and 'EMPTY_FILE_READ bytes=0' in text
                report['probes'][-1]['disposition'] = 'clean' if expected else 'failed'
            else:
                leaked = code != 0 and 'LeakSanitizer: detected memory leaks' in text
                clean = code == 0 and 'LeakSanitizer' not in text
                expected = leaked or clean
                report['probes'][-1]['disposition'] = 'upstream_leak_reproduced' if leaked else 'clean' if clean else 'failed'
            failed |= not expected
    report['status'] = 'failed' if failed else 'passed'
    (out / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 1 if failed else 0
if __name__ == '__main__': sys.exit(main())
