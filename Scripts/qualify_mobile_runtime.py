#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Build both mobile SDKs and run isolated iPhone/iPad simulator consumers."""
import argparse, datetime, hashlib, json, pathlib, subprocess, sys
from archive_candidate import files
from preflight import collect
ROOT = pathlib.Path(__file__).resolve().parents[1]
EXPECTED = ['PUBLIC_BEHAVIOR passed fixtures=8', 'STREAM_CANCELLATION passed',
            'DISK_PERSISTENCE passed containers=3 rows=8', 'MOBILE_QUALIFICATION passed cases=3']

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='.build/ci/mobile-runtime/receipt.json')
    args = parser.parse_args()
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    source = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
    receipt = {'schema_version': 1, 'status': 'running', 'environment': collect(),
        'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'source_inputs': source, 'commands': [], 'simulators': [], 'physical_devices': 'separate physical receipts required; iPad unavailable, confirmed by maintainer',
        'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    def save(): output.write_text(json.dumps(receipt, indent=2) + '\n')
    def run(name, command):
        print('Running ' + name, flush=True)
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=900)
        path = output.parent / (name + '.log')
        path.write_text((result.stdout + result.stderr).replace(str(ROOT), '.'))
        receipt['commands'].append({'name': name, 'command': [x.replace(str(ROOT), '.') for x in command],
            'exit_code': result.returncode, 'log': path.relative_to(ROOT).as_posix(),
            'log_sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        save()
        if result.returncode: raise RuntimeError(name + ' failed')
        return result.stdout
    save()
    try:
        if receipt['environment']['status'] != 'passed': raise FileNotFoundError('Supported native host required')
        for sdk, triple, scratch in [('iphoneos', 'arm64-apple-ios27.0', '.build/mobile-runtime-device'),
                                     ('iphonesimulator', 'arm64-apple-ios27.0-simulator', '.build/mobile-runtime-sim')]:
            sdkpath = run(sdk + '-sdk', ['xcrun', '--sdk', sdk, '--show-sdk-path']).strip()
            run(sdk + '-build', ['swift', 'build', '-c', 'release', '--package-path', 'Tools/MobileQualification',
                '--scratch-path', scratch, '--triple', triple, '--sdk', sdkpath])
        # Resolve the output actually produced by the default Swift Build engine.
        candidates = [p for p in (ROOT / '.build/mobile-runtime-sim/out/Products').glob('Release*/MobileQualification') if p.is_file()]
        if len(candidates) != 1: raise RuntimeError('Expected one simulator executable')
        binary = candidates[0]
        receipt['binary_sha256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
        inventory = json.loads(run('available-simulators', ['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))['devices']
        runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
        devices = inventory.get(runtime, [])
        for family in ['iPhone', 'iPad']:
            model = next((d for d in devices if d['name'].startswith(family) and d['isAvailable']), None)
            if model is None: raise FileNotFoundError('No supported ' + family + ' simulator model/runtime')
            device = run(family + '-create', ['xcrun', 'simctl', 'create', 'Swift-JSON-1.1-' + family,
                model['deviceTypeIdentifier'], runtime]).strip()
            try:
                run(family + '-boot', ['xcrun', 'simctl', 'boot', device])
                run(family + '-bootstatus', ['xcrun', 'simctl', 'bootstatus', device, '-b'])
                result = run(family + '-consumer', ['xcrun', 'simctl', 'spawn', device, str(binary)])
                if not all(line in result.splitlines() for line in [EXPECTED[0], EXPECTED[1], 'MOBILE_QUALIFICATION passed cases=2']): raise RuntimeError('Missing exact runtime outcomes')
                disk = output.parent / ('disk-' + family)
                disk.mkdir(parents=True, exist_ok=True)
                url = disk / 'snapshots.store'
                for phase in ['save', 'reopen-update', 'verify-update']:
                    result = run(family + '-disk-' + phase, ['xcrun', 'simctl', 'spawn', device, str(binary), '--disk-phase', phase, str(url)])
                    if 'DISK_PHASE passed phase=' + phase + ' rows=8' not in result.splitlines():
                        raise RuntimeError('Missing disk phase outcome')
                if not url.is_file(): raise RuntimeError('No actual disk store')
                receipt['simulators'].append({'family': family, 'model': model['name'], 'runtime': runtime,
                    'status': 'passed', 'executed_cases': 3, 'fixtures': 8, 'disk_containers': 3})
                save()
            finally:
                run(family + '-delete', ['xcrun', 'simctl', 'delete', device])
        receipt['status'] = 'passed'
    except FileNotFoundError as error:
        receipt['status'] = 'blocked'; receipt['error'] = str(error)
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        receipt['status'] = 'failed'; receipt['error'] = str(error)
    receipt['source_inputs_unchanged'] = source == [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
    if not receipt['source_inputs_unchanged']: receipt['status'] = 'failed'
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save(); print(json.dumps({k:v for k,v in receipt.items() if k not in ['source_inputs', 'environment']}, indent=2))
    return 0 if receipt['status'] == 'passed' else 2 if receipt['status'] == 'blocked' else 1

if __name__ == '__main__': sys.exit(main())
