#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Execute public native CI lanes with command, source and environment receipts."""
import argparse, datetime, hashlib, json, os, pathlib, re, subprocess, sys
from archive_candidate import files
from preflight import collect

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHARED_TESTS = 'independentCodecFacadesAndExactValuesCanBeSharedAcrossTasks|concurrentSchemaEvaluationsHaveExclusiveDynamicRegexAndAnnotationState|sharedRegexProgramHasExclusiveConcurrentSearchState'

def snapshot():
    return [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]

def commands(lane, output):
    if lane == 'native':
        return [
            ['python3', '-B', 'Scripts/public_check.py'],
            ['swift', 'package', 'dump-package'],
            ['swift', 'package', 'show-dependencies', '--format', 'json'],
            ['swift', 'build', '-c', 'release'],
            ['swift', 'test'], ['swift', 'test', '-c', 'release'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Examples/Consumer', 'Consumer'],
            ['swift', 'test', '--package-path', 'Tools/MCPReadiness'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/MCPReadiness', 'MCPReadiness', str(output / 'consumer.json')],
            ['swift', 'test', '--package-path', 'Tools/Qualification'],
            ['python3', '-B', 'Scripts/qualification_watchdog.py', '--timeout', '900', '--output', str(output / 'watchdog.json'), '--', 'swift', 'run', '-c', 'release', '--package-path', 'Tools/Qualification', 'Qualification', '--all', '--registry', 'Documentation/Qualification/FixtureRegistry.json', '--output', str(output / 'qualification.json')],
        ]
    if lane == 'safety':
        return [
            ['swift', 'test', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/ci-address'],
            ['swift', 'test', '-c', 'release', '--sanitize', 'thread', '--scratch-path', '.build/ci-thread', '--filter', SHARED_TESTS],
            ['swift', 'build', '--scratch-path', '.build/ci-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
        ]
    return [['python3', '-B', 'Scripts/build_documentation.py']]

def check_result(command, code, log):
    counts = [int(n) for n in re.findall(r'Test run with (\d+) tests? in[^\n]*passed', log)]
    passed = code == 0
    if command[:2] == ['swift', 'test']:
        expected = [3] if 'Tools/MCPReadiness' in command else [9] if 'Tools/Qualification' in command else [1, 1, 1] if 'thread' in command else [8, 11, 12, 37, 54]
        passed = passed and sorted(counts) == expected
    if command == ['swift', 'package', 'dump-package'] and passed:
        d = json.loads(log)
        passed = sorted(p['name'] for p in d['products']) == ['JSON', 'JSONPatch', 'JSONSchema', 'JSONStreaming'] and not d['dependencies'] and d['swiftLanguageVersions'] == ['6'] and d['toolsVersion']['_version'] == '6.4.0' and d['platforms'] == [{'options': [], 'platformName': 'macos', 'version': '27.0'}]
    if command == ['swift', 'package', 'show-dependencies', '--format', 'json'] and passed:
        passed = json.loads(log)['dependencies'] == []
    return passed, counts

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lane', choices=['native', 'safety', 'docs'], required=True)
    parser.add_argument('--output')
    args = parser.parse_args()
    output = ROOT / (args.output or '.build/ci/' + args.lane)
    output.mkdir(parents=True, exist_ok=True)
    inputs = snapshot()
    commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True)
    receipt = {'schema_version': 1, 'lane': args.lane, 'status': 'blocked', 'environment': collect(), 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'git_commit': commit.stdout.strip() if commit.returncode == 0 else None, 'github_run_id': os.environ.get('GITHUB_RUN_ID'), 'source_inputs': inputs, 'source_manifest_sha256': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(), 'commands': []}
    def save():
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    save()
    if receipt['environment']['status'] != 'passed':
        print(json.dumps(receipt['environment'], indent=2))
        return 2
    receipt['status'] = 'running'
    for index, command in enumerate(commands(args.lane, output)):
        print('Running ' + ' '.join(command), flush=True)
        log_path = output / ('command-%02d.log' % index)
        with log_path.open('w') as stream:
            try:
                result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
                code = result.returncode
            except (OSError, subprocess.TimeoutExpired) as error:
                stream.write('\n' + str(error) + '\n')
                code = None
        log = log_path.read_text(errors='replace').replace(str(ROOT), '.')
        log_path.write_text(log)
        try:
            passed, counts = check_result(command, code, log)
        except (KeyError, ValueError, TypeError):
            passed, counts = False, []
        entry = {'command': [x.replace(str(ROOT), '.') for x in command], 'exit_code': code, 'status': 'passed' if passed else 'failed', 'log': log_path.relative_to(ROOT).as_posix(), 'log_sha256': hashlib.sha256(log_path.read_bytes()).hexdigest(), 'swift_testing_function_counts': counts, 'parameterized_case_invocations': sum(int(n) for n in re.findall(r'with (\d+) test cases passed', log))}
        receipt['commands'].append(entry)
        print(json.dumps(entry), flush=True)
        if not passed:
            receipt['status'] = 'failed'
            break
        save()
    else:
        receipt['status'] = 'passed'
    receipt['source_inputs_unchanged'] = snapshot() == inputs
    if not receipt['source_inputs_unchanged']:
        receipt['status'] = 'failed'
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    return 0 if receipt['status'] == 'passed' else 1

if __name__ == '__main__':
    sys.exit(main())
