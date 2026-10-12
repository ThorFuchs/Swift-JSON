#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Execute public native CI lanes with command, source and environment receipts."""
import argparse, datetime, hashlib, json, os, pathlib, re, subprocess, sys
from archive_candidate import files
from preflight import collect, collect_linux

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHARED_TESTS = 'independentCodecFacadesAndExactValuesCanBeSharedAcrossTasks|concurrentSchemaEvaluationsHaveExclusiveDynamicRegexAndAnnotationState|sharedRegexProgramHasExclusiveConcurrentSearchState|immutableIndexedObjectCanBeSharedAcrossTasks|qaSharedPayloadAndRootHaveIndependentConcurrentReadScopes|sha256InputCapacityAndConcurrentInvocationsRemainIndependent'
R0_TESTS = 'readerProbe|indexProbes|duplicateRecognitionPrecedesValueAndClosingSyntax'

def snapshot():
    return [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]

def commands(lane, output):
    # The qualification executable resolves output paths from its repository root.
    output = output.relative_to(ROOT)
    if lane == 'linux':
        # Root behavior/corpora remain required. SwiftData and Apple SDK/lifetime
        # probes are separate Apple acceptance; they never become Linux passes.
        return [c for c in commands('native', ROOT / output)
                if not any(x in c for x in ['Tools/MobileQualification', '--mode'])]
    if lane == 'linux-safety':
        return commands('safety', ROOT / output)
    if lane == 'qa':
        return [
            ['swift', 'test', '--filter', 'qa'],
            ['swift', 'test', '-c', 'release', '--filter', 'qa'],
            ['swift', 'test', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/ci-address', '--filter', 'qa'],
        ]
    if lane == 'native':
        return [
            ['python3', '-B', 'Scripts/public_check.py'],
            ['swift', 'package', 'dump-package'],
            ['swift', 'package', 'show-dependencies', '--format', 'json'],
            ['swift', 'build', '-c', 'release'],
            ['swift', 'test'], ['swift', 'test', '-c', 'release'],
            ['python3', '-B', 'Scripts/qualify_release_1_1.py', '--mode', 'ownership', '--output', str(output / 'ownership.json')],
            ['python3', '-B', 'Scripts/qualify_release_1_1.py', '--mode', 'reader', '--output', str(output / 'reader.json')],
            ['swift', 'run', '-c', 'release', '--package-path', 'Examples/Consumer', 'Consumer'],
            ['swift', 'test', '--package-path', 'Tools/MobileQualification'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/MobileQualification', 'MobileQualification'],
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
    if lane == 'r0':
        return [
            ['swift', 'test', '--filter', R0_TESTS],
            ['python3', '-B', 'Scripts/qualify_release_1_1.py', '--mode', 'ownership', '--output', str(output / 'ownership.json')],
            ['python3', '-B', 'Scripts/qualify_release_1_1.py', '--mode', 'sdk', '--output', str(output / 'sdk.json')],
        ]
    return [['python3', '-B', 'Scripts/build_documentation.py']]

def materialized_outcomes(output):
    qualification = json.loads((output / 'qualification.json').read_text())
    consumer = json.loads((output / 'consumer.json').read_text())
    watchdog = json.loads((output / 'watchdog.json').read_text())
    if qualification['status'] != 'passed' or qualification['errors'] or watchdog['status'] != 'passed' or watchdog['exit_code'] != 0:
        raise ValueError('Independent qualification receipt failed')
    expected = {'nst/JSONTestSuite': (318, 287, 31), 'json-schema-org/JSON-Schema-Test-Suite': (2337, 2300, 37)}
    suites = qualification['suites']
    if {s['repository'] for s in suites} != set(expected) or len(suites) != 2:
        raise ValueError('Missing independent suite receipt')
    for suite in suites:
        if (suite['observed_cases'], suite['passed_cases'], suite['policy_cases']) != expected[suite['repository']] or suite['failed_cases'] or suite['unexpected_skips'] or len(suite['cases']) != suite['observed_cases']:
            raise ValueError('Missing, changed or failing independent case outcomes')
    authored = {a['name']: a for a in qualification['authored']}
    for name, count in [('authored_public_semantics', 82), ('public_budget_and_counter_boundaries', 9), ('deterministic_malformed_utf8_replay', 4396)]:
        if authored[name]['observed'] != count or authored[name]['failed']:
            raise ValueError('Missing or failing authored qualification')
    if consumer['status'] != 'passed' or (consumer['positiveCases'], consumer['negativeCases'], consumer['operationalErrors']) != (8, 12, 2) or len(consumer['outcomes']) != 20 or any(c['actual'] != c['expected'] for c in consumer['outcomes']):
        raise ValueError('Missing or failing rooted consumer outcomes')
    return {name: {'sha256': hashlib.sha256((output / name).read_bytes()).hexdigest()} for name in ['qualification.json', 'consumer.json', 'watchdog.json']}

def check_result(command, code, log):
    counts = [int(n) for n in re.findall(r'Test run with (\d+) tests? in[^\n]*passed', log)]
    passed = code == 0
    if command[:2] == ['swift', 'test']:
        expected = [2, 3, 3, 11] if 'qa' in command else [7] if R0_TESTS in command else [3] if 'Tools/MCPReadiness' in command or 'Tools/MobileQualification' in command else [1] if 'Tools/Qualification' in command else [1, 1, 4] if 'thread' in command else [11, 12, 14, 42, 101]
        passed = passed and sorted(counts) == expected
        if '--filter' not in command and not any(x.startswith('Tools/') for x in command):
            passed = passed and sum(int(n) for n in re.findall(r'with (\d+) test cases passed', log)) == 173
        if 'Tools/Qualification' in command:
            probes = re.findall(r'^CAP_PROBE (\w+) (\S+)$', log, re.MULTILINE)
            matrix = json.loads((ROOT / 'Documentation/Qualification/LimitsMatrix.json').read_text())
            expected_probes = {m['metric']: m['public_probe_outcome'] for m in matrix['metrics']}
            passed = passed and len(probes) == 49 and dict(probes) == expected_probes
    if command == ['swift', 'package', 'dump-package'] and passed:
        d = json.loads(log)
        passed = sorted(p['name'] for p in d['products']) == ['JSON', 'JSONPatch', 'JSONSchema', 'JSONStreaming'] and not d['dependencies'] and d['swiftLanguageVersions'] == ['6'] and d['toolsVersion']['_version'] == '6.4.0' and d['platforms'] == [{'options': [], 'platformName': 'macos', 'version': '27.0'}, {'options': [], 'platformName': 'ios', 'version': '27.0'}]
    if command == ['swift', 'package', 'show-dependencies', '--format', 'json'] and passed:
        passed = json.loads(log)['dependencies'] == []
    if command[:2] == ['swift', 'run'] and 'Tools/MobileQualification' in command:
        passed = passed and all(line in log.splitlines() for line in ['PUBLIC_BEHAVIOR passed fixtures=8', 'STREAM_CANCELLATION passed', 'DISK_PERSISTENCE passed containers=3 rows=8', 'MOBILE_QUALIFICATION passed cases=3'])
    return passed, counts

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lane', choices=['native', 'safety', 'docs', 'r0', 'qa', 'linux', 'linux-safety'], required=True)
    parser.add_argument('--output')
    args = parser.parse_args()
    output = ROOT / (args.output or '.build/ci/' + args.lane)
    output.mkdir(parents=True, exist_ok=True)
    inputs = snapshot()
    commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True)
    environment = collect_linux() if args.lane.startswith('linux') else collect()
    receipt = {'schema_version': 1, 'lane': args.lane, 'status': 'blocked', 'environment': environment, 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'git_commit': commit.stdout.strip() if commit.returncode == 0 else None, 'github_run_id': os.environ.get('GITHUB_RUN_ID'), 'source_inputs': inputs, 'source_manifest_sha256': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(), 'commands': []}
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
    if receipt['status'] == 'passed' and args.lane in ('native', 'linux'):
        try:
            receipt['materialized_outcomes'] = materialized_outcomes(output)
        except (OSError, KeyError, ValueError, TypeError) as error:
            receipt['status'] = 'failed'
            receipt['evidence_error'] = str(error)
            print('Native evidence failed: ' + str(error), flush=True)
    receipt['source_inputs_unchanged'] = snapshot() == inputs
    if not receipt['source_inputs_unchanged']:
        receipt['status'] = 'failed'
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    return 0 if receipt['status'] == 'passed' else 1

if __name__ == '__main__':
    sys.exit(main())
