#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run the built public export consumer on owned iPhone/iPad simulators."""
import argparse, datetime, hashlib, json, pathlib, subprocess, sys
from archive_candidate import files
from preflight import collect
ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', required=True, help='Actual iPhoneSimulator ExportConsumer binary')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    binary = (ROOT / args.binary).resolve()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    inputs = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
    receipt = {'schema_version': 1, 'status': 'running', 'environment': collect(),
        'source_inputs': inputs, 'source_manifest_sha256': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
        'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'commands': [], 'simulators': [], 'limitations': ['Native UIKit decoder and transport CLI; no share sheet/editor/physical-device UI claim.']}
    def save(): (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    def run(name, command):
        print('Running ' + name, flush=True)
        try:
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=300)
            code = result.returncode; text = result.stdout + result.stderr; stdout = result.stdout
        except subprocess.TimeoutExpired as error:
            code = 124; stdout = ''; text = str(error) + '\nEXTERNAL_SIMULATOR_TIMEOUT\n'
        log = output / (name + '.log'); log.write_text(text.replace(str(ROOT), '.'))
        receipt['commands'].append({'name': name, 'command': command, 'exit_code': code,
            'log': log.relative_to(ROOT).as_posix(), 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        save()
        if code: raise RuntimeError(name + ' failed with exit ' + str(code))
        return stdout
    save()
    try:
        if receipt['environment']['status'] != 'passed': raise FileNotFoundError('Required native preflight blocked')
        if not binary.is_file(): raise FileNotFoundError('Missing simulator consumer binary')
        receipt['binary_sha256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
        # The SwiftPM resource bundle remains beside the original binary.
        inventory = json.loads(run('inventory', ['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))['devices']
        runtime = 'com.apple.CoreSimulator.SimRuntime.iOS-27-0'
        for family in ['iPhone', 'iPad']:
            model = next((d for d in inventory.get(runtime, []) if d['name'].startswith(family) and d['isAvailable']), None)
            if model is None: raise FileNotFoundError('No supported ' + family + ' simulator model/runtime')
            device = run(family + '-create', ['xcrun', 'simctl', 'create', 'Swift-JSON-Export-' + family, model['deviceTypeIdentifier'], runtime]).strip()
            try:
                run(family + '-boot', ['xcrun', 'simctl', 'boot', device])
                run(family + '-bootstatus', ['xcrun', 'simctl', 'bootstatus', device, '-b'])
                samples = output / family
                text = run(family + '-consumer', ['xcrun', 'simctl', 'spawn', device, str(binary), str(samples)])
                if 'JSONHTML_EXPORT_CONSUMER passed cases=65 artifacts=8 measurements=7' not in text.splitlines():
                    raise RuntimeError('Changed consumer discovery/cardinality')
                consumer = json.loads((samples / 'consumer.json').read_text())
                if consumer['status'] != 'passed' or len(consumer['cases']) != 65 or not all(c['passed'] for c in consumer['cases']):
                    raise RuntimeError('Incomplete or failing consumer outcomes')
                rtf = samples / 'Exact-JSON.rtf'
                receipt['simulators'].append({'family': family, 'model': model['name'], 'runtime': runtime,
                    'status': 'passed', 'cases': 65, 'artifacts': 8, 'rtf_sha256': hashlib.sha256(rtf.read_bytes()).hexdigest(),
                    'pdf_sha256': {name: hashlib.sha256((samples / name).read_bytes()).hexdigest() for name in ['A4.pdf', 'Letter.pdf', 'Continuous.pdf']},
                    'consumer': consumer})
                save()
            finally:
                # Delete only the simulator created by this invocation.
                run(family + '-delete', ['xcrun', 'simctl', 'delete', device])
        receipt['status'] = 'passed'
    except FileNotFoundError as error:
        receipt['status'] = 'blocked'; receipt['error'] = str(error)
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        receipt['status'] = 'failed'; receipt['error'] = str(error)
    receipt['source_inputs_unchanged'] = inputs == [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
    if not receipt['source_inputs_unchanged']: receipt['status'] = 'failed'
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save(); print('EXPORT_SIMULATORS ' + receipt['status'])
    return 0 if receipt['status'] == 'passed' else 2 if receipt['status'] == 'blocked' else 1

if __name__ == '__main__': sys.exit(main())
