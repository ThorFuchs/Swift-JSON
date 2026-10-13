#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Build and exercise a manifest-verified, independently extracted Linux candidate."""
import argparse, hashlib, json, pathlib, re, subprocess, tarfile
from archive_candidate import archive, files, verify

ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    p = argparse.ArgumentParser(); p.add_argument('--output', required=True); a = p.parse_args()
    out = ROOT / a.output; out.mkdir(parents=True, exist_ok=True)
    first, second = out / 'candidate.tar.gz', out / 'candidate-rebuild.tar.gz'
    selected = files(); archive(first, selected); archive(second, selected)
    assert first.read_bytes() == second.read_bytes(), 'Candidate rebuild differs'
    second.unlink(); entries = verify(first)
    extracted = out / 'extracted'; extracted.mkdir(exist_ok=False)
    with tarfile.open(first) as tar:
        # verify() checked regular entries, exact prefix, safe paths and manifest.
        tar.extractall(extracted, filter='data')
    source = extracted / 'Swift-JSON'
    commands = [
        ['swift', 'build', '-c', 'release'],
        ['swift', 'test', '-c', 'release', '--disable-xctest', '--filter', 'sha256|builtinIntegrity|pinnedOfficialMetaSchemasLoadAsImmutableResources'],
        ['swift', 'run', '-c', 'release', '--package-path', 'Examples/Consumer', 'Consumer']]
    receipt = {'status': 'running', 'archive_sha256': hashlib.sha256(first.read_bytes()).hexdigest(),
        'archive_bytes': first.stat().st_size, 'archive_entries': entries, 'byte_equal_rebuild': True,
        'git_directory_present': (source / '.git').exists(), 'commands': []}
    for i, command in enumerate(commands):
        log = out / ('command-%02d.log' % i)
        with log.open('w') as stream:
            code = subprocess.run(command, cwd=source, stdout=stream, stderr=subprocess.STDOUT, timeout=900).returncode
        text = log.read_text().replace(str(ROOT), '.')
        log.write_text(text)
        counts = [int(n) for n in re.findall(r'Test run with (\d+) tests? in[^\n]*passed', text)]
        passed = code == 0
        if command[:2] == ['swift', 'test']: passed &= sorted(counts) == [2, 4]
        if 'Consumer' in command: passed &= 'Consumer passed:' in text
        receipt['commands'].append({'command': command, 'exit_code': code, 'passed': passed,
            'swift_testing_function_counts': counts, 'log': log.relative_to(ROOT).as_posix(),
            'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        if not passed: receipt['status'] = 'failed'; break
    else: receipt['status'] = 'passed'
    # Keep the exact candidate and proof, avoiding duplicated extracted build caches.
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'passed' else 1
if __name__ == '__main__': raise SystemExit(main())
