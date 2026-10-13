#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Qualification-only comparison of two exact source commits on one quiet native host.

This branch is not a proposed library change. Ten percent is a review trigger,
not automatic acceptance or rejection. No process is suspended or terminated
except this script's own top monitor.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import time

BASE = 'e9c6693c7cb29df5125e1699fef70f98229ccfdf'
CANDIDATE = 'a9c40e9534e98d06a6d59729be7cec608a18a0c8'
HARNESS_SHA = 'be84290bb8d1f6e641883019821e530bf5044124f92d73cba7df52f2de383558'
ORDER = ['baseline-1', 'candidate-1', 'candidate-2', 'baseline-2']
ROOT = Path.cwd()
WORK = ROOT / '.build/pr17-performance'
OUT = WORK / 'results'
OUT.mkdir(parents=True, exist_ok=True)
RECEIPT = {'schema_version': 1, 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'commands': [], 'input_commits': {'baseline': BASE, 'candidate': CANDIDATE},
           'policy': {'minimum_pre_run_idle_percent': 90, 'consecutive_samples': 3,
                      'sample_interval_seconds': 5, 'post_run_settling_samples': 9,
                      'during_run_expected_owned_cpu_cores': 1,
                      'other_high_cpu_compiler_or_renderer_processes': 0,
                      'measurement_swapins': 0, 'measurement_swapouts': 0,
                      'review_trigger_percent': 10},
           'runs': [], 'qualified_measurement': False, 'disposition': 'requires maintainer review'}


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def run(command, log, cwd=ROOT, timeout=300):
    started = utc()
    with (OUT / log).open('w') as stream:
        result = subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                                text=True, timeout=timeout)
    RECEIPT['commands'].append({'command': [str(x) for x in command], 'started_utc': started,
                               'finished_utc': utc(), 'exit_code': result.returncode, 'log': log})
    if result.returncode:
        raise RuntimeError('command failed: ' + log)
    return (OUT / log).read_text()


def version(text):
    return tuple(int(x) for x in text.split('.')[:2])


def parse_top(text):
    return {'idle_percent': [float(x) for x in re.findall(r'([0-9.]+)% idle', text)],
            'swap': [[int(a), int(b)] for a, b in re.findall(
                r'(\d+)\(\d+\) swapins, (\d+)\(\d+\) swapouts', text)]}


def other_heavy(log):
    text = subprocess.check_output(['ps', '-Ao', 'pid,pcpu,state,comm', '-r'], text=True)
    (OUT / log).write_text(text)
    result = []
    for line in text.splitlines()[1:]:
        parts = line.strip().split(None, 3)
        if len(parts) != 4 or int(parts[0]) == os.getpid() or 'T' in parts[2]:
            continue
        if float(parts[1]) >= 30 and re.search(
                r'swift|clang|latex|tex|pdf|python|mediaanalysis|Renderer|WindowServer', parts[3], re.I):
            result.append({'pid': int(parts[0]), 'cpu_percent': float(parts[1]),
                           'state': parts[2], 'comm': parts[3]})
    return result


def quiet_admission():
    command = ['top', '-l', '61', '-s', '5', '-n', '0']
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, bufsize=1)
    captured = []
    admitted = False
    heavy = []
    try:
        for line in proc.stdout:
            captured.append(line)
            if line.startswith('Disks:'):
                parsed = parse_top(''.join(captured))
                # First top sample is cumulative rather than the preceding interval.
                if len(parsed['idle_percent']) >= 4 and all(
                        x >= 90 for x in parsed['idle_percent'][-3:]):
                    heavy = other_heavy('processes-before.txt')
                    if not heavy:
                        admitted = True
                        break
    finally:
        if proc.poll() is None:
            proc.terminate()
        code = proc.wait(timeout=5)
        (OUT / 'host-before.txt').write_text(''.join(captured))
        RECEIPT['host_sampling_command'] = {'command': command, 'exit_code': code,
                                          'intentionally_stopped_at_admission': admitted,
                                          'maximum_wait_seconds': 300}
    RECEIPT['before'] = parse_top(''.join(captured))
    RECEIPT['other_heavy_before'] = heavy
    RECEIPT['admission_passed'] = admitted
    return admitted


def main():
    assert platform.system() == 'Darwin'
    os_version = run(['sw_vers', '-productVersion'], 'os.log').strip()
    swift = run(['xcrun', 'swift', '--version'], 'swift.log')
    sdk = run(['xcrun', '--sdk', 'macosx', '--show-sdk-version'], 'sdk.log').strip()
    xcode = run(['xcodebuild', '-version'], 'xcode.log')
    compiler = re.search(r'Apple Swift version (\d+\.\d+)', swift)
    assert version(os_version) >= (27, 0) and version(sdk) >= (27, 0)
    assert compiler and version(compiler.group(1)) >= (6, 4)
    RECEIPT['environment'] = {'macos': os_version, 'swift': swift.strip(), 'sdk': sdk,
                              'xcode': xcode.strip(), 'architecture': platform.machine(),
                              'DEVELOPER_DIR': os.environ.get('DEVELOPER_DIR'),
                              'language_mode': '6', 'hardware': {}}
    for name in ['hw.model', 'hw.memsize', 'hw.ncpu', 'machdep.cpu.brand_string']:
        RECEIPT['environment']['hardware'][name] = run(
            ['sysctl', '-n', name], name + '.log').strip()
    harness = (ROOT / 'Scripts/qualification/SchemaBuilderBenchmark.swift').read_bytes()
    assert hashlib.sha256(harness).hexdigest() == HARNESS_SHA
    (OUT / 'SchemaBuilderBenchmark.swift').write_bytes(harness)
    RECEIPT['harness_sha256'] = HARNESS_SHA
    binaries = {}
    for kind, commit in [('baseline', BASE), ('candidate', CANDIDATE)]:
        source = WORK / (kind + '-source')
        run(['git', 'worktree', 'add', '--detach', str(source), commit], kind + '-checkout.log')
        tree = run(['git', 'rev-parse', commit + '^{tree}'], kind + '-tree.log').strip()
        RECEIPT.setdefault('input_trees', {})[kind] = tree
        manifest = (source / 'Package.swift').read_text()
        assert 'swift-tools-version: 6.4' in manifest and '.v6' in manifest
        package = WORK / (kind + '-benchmark')
        target = package / 'Sources/BuilderBenchmark'
        target.mkdir(parents=True)
        (target / 'main.swift').write_bytes(harness)
        (package / 'Package.swift').write_text('''// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "BuilderBenchmark", platforms: [.macOS("27.0")],
    dependencies: [.package(name: "Swift-JSON", path: ''' + json.dumps(str(source)) + ''')],
    targets: [.executableTarget(name: "BuilderBenchmark", dependencies: [
        .product(name: "JSON", package: "Swift-JSON"),
        .product(name: "JSONSchema", package: "Swift-JSON")])], swiftLanguageModes: [.v6])
''')
        run(['xcrun', 'swift', 'build', '-c', 'release', '--package-path', str(package)],
            kind + '-build.log', timeout=900)
        binary = package / '.build/release/BuilderBenchmark'
        binaries[kind] = binary
        RECEIPT.setdefault('binaries', {})[kind] = {'sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
                                                   'bytes': binary.stat().st_size}
    if not quiet_admission():
        raise RuntimeError('quiet-host admission failed; no timing result admitted')
    print('Quiet admission passed: ' + str(RECEIPT['before']['idle_percent'][-3:]), flush=True)
    monitor_file = (OUT / 'host-during.txt').open('w')
    monitor = subprocess.Popen(['top', '-l', '0', '-s', '2', '-n', '0'],
                               stdout=monitor_file, stderr=subprocess.STDOUT)
    try:
        for label in ORDER:
            kind = label.rsplit('-', 1)[0]
            text = run([str(binaries[kind])], label + '.json', timeout=60)
            result = json.loads(text)
            assert result['warmups'] == 3 and result['repetitions'] == 9 and len(result['samples']) == 2
            for sample in result['samples']:
                assert len(sample['nanoseconds']) == 9
                assert sample['medianNanoseconds'] == statistics.median(sample['nanoseconds'])
                assert (sample['workload'], sample['invocations'], sample['checksum']) in [
                    ('description100', 20000, 240000), ('wide64_strings256', 1000, 768000)]
            RECEIPT['runs'].append({'label': label, **result})
            print(label + ': ' + str({x['workload']: x['medianNanoseconds'] for x in result['samples']}), flush=True)
    finally:
        monitor.terminate()
        monitor.wait(timeout=5)
        monitor_file.close()
    RECEIPT['during'] = parse_top((OUT / 'host-during.txt').read_text())
    after = run(['top', '-l', '9', '-s', '5', '-n', '0'], 'host-after.txt', timeout=50)
    RECEIPT['after'] = parse_top(after)
    RECEIPT['other_heavy_after'] = other_heavy('processes-after.txt')
    first = RECEIPT['before']['swap'][-1]
    last = RECEIPT['after']['swap'][-1]
    RECEIPT['swap_delta'] = {'swapins': last[0] - first[0], 'swapouts': last[1] - first[1]}
    RECEIPT['comparisons'] = []
    for workload in ['description100', 'wide64_strings256']:
        values = {kind: [s['medianNanoseconds'] for r in RECEIPT['runs']
                         if r['label'].startswith(kind) for s in r['samples'] if s['workload'] == workload]
                  for kind in ['baseline', 'candidate']}
        baseline = statistics.median(values['baseline'])
        candidate = statistics.median(values['candidate'])
        change = (candidate / baseline - 1) * 100
        RECEIPT['comparisons'].append({'workload': workload, 'baseline_process_medians_ns': values['baseline'],
                                       'candidate_process_medians_ns': values['candidate'],
                                       'baseline_median_ns': baseline, 'candidate_median_ns': candidate,
                                       'change_percent': change, 'ten_percent_review_trigger': change > 10})
    assert all(x >= 90 for x in RECEIPT['after']['idle_percent'][-3:]), 'post-run host no longer quiet'
    assert not RECEIPT['other_heavy_after'], 'competing compiler/renderer after run'
    assert RECEIPT['swap_delta'] == {'swapins': 0, 'swapouts': 0}, 'paging observed during comparison'
    RECEIPT['qualified_measurement'] = True
    print(json.dumps(RECEIPT['comparisons'], indent=2))


exit_code = 0
try:
    main()
except BaseException as error:
    RECEIPT['error'] = repr(error)
    print('Qualification failed: ' + repr(error), flush=True)
    exit_code = 1
finally:
    RECEIPT['finished_utc'] = utc()
    RECEIPT['exit_code'] = exit_code
    (OUT / 'Comparison.json').write_text(json.dumps(RECEIPT, indent=2) + '\n')
    entries = []
    for path in sorted(OUT.rglob('*')):
        if path.is_file() and path.name != 'MANIFEST.sha256':
            entries.append(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + str(path.relative_to(OUT)))
    (OUT / 'MANIFEST.sha256').write_text('\n'.join(entries) + '\n')
sys.exit(exit_code)
