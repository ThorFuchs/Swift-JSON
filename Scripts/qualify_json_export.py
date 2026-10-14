#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Native export and Apple compiler/API qualification; receiver/device gates remain separate."""
import argparse, hashlib, json, os, pathlib, subprocess, sys
from archive_candidate import files
from preflight import collect

ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    inputs = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
    receipt = {'status': 'blocked', 'environment': collect(), 'source_inputs': inputs,
        'source_manifest_sha256': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
        'commands': [], 'capability': 'four defaults, opt-in styled RTF and explicit paginated/continuous Apple PDF; API/file transport',
        'limitations': ['SDK builds are not simulator/device execution.',
            'No share-sheet, drag/drop or receiving-editor UI success is inferred.',
            'Opaque SDK allocation/work is not owned instruction or process RSS accounting.',
            'Native PDF text/geometry and RTF decoding do not establish recipient UI or physical-device behavior.']}
    def run(name, command, timeout=900):
        log = output / (name + '.log')
        with log.open('w') as stream:
            try:
                result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
                stream.write('\nEXTERNAL_PROBE_TIMEOUT\n')
        entry = {'name': name, 'command': command, 'exit_code': code,
            'log': log.relative_to(ROOT).as_posix(), 'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
        receipt['commands'].append(entry)
        if code: raise ValueError(name + ' failed with exit ' + str(code))
        return log.read_text()
    try:
        if receipt['environment']['status'] != 'passed': raise ValueError('Required native preflight blocked')
        fixture_root = ROOT / 'Tools/JSONHTMLExport/Sources/ExportConsumer/Fixtures'
        registry = json.loads((fixture_root / 'registry.json').read_text())
        for fixture in registry['fixtures']:
            path = fixture_root / pathlib.Path(fixture['path']).name
            if hashlib.sha256(path.read_bytes()).hexdigest() != fixture['sha256']: raise ValueError('Fixture hash mismatch')
        receipt['fixtures_verified'] = registry['fixtures']
        text = run('native-consumer', ['swift', 'run', '-c', 'release', '--package-path', 'Tools/JSONHTMLExport',
            'ExportConsumer', str(output / 'samples')])
        if 'JSONHTML_EXPORT_CONSUMER passed cases=63 artifacts=8 measurements=7' not in text.splitlines():
            raise ValueError('Changed native consumer cardinality')
        consumer = json.loads((output / 'samples/consumer.json').read_text())
        if consumer['status'] != 'passed' or len(consumer['cases']) != 63 or not all(row['passed'] for row in consumer['cases']):
            raise ValueError('Missing consumer outcomes')
        receipt['consumer'] = consumer
        if len(consumer['pdfReports']) != 3 or len(consumer['samples']) != 8: raise ValueError('Missing PDF artifacts/reports')
        probe = ROOT / 'Tools/JSONHTMLExport/Probes/WebPageBackend.swift'
        for sdk, target in [('macosx', 'arm64-apple-macos27.0'), ('iphoneos', 'arm64-apple-ios27.0'),
                            ('iphonesimulator', 'arm64-apple-ios27.0-simulator')]:
            sdk_path = run(sdk + '-path', ['xcrun', '--sdk', sdk, '--show-sdk-path']).strip()
            run(sdk + '-webpage-declarations', ['xcrun', 'swiftc', '-swift-version', '6', '-warnings-as-errors',
                '-parse-as-library', '-sdk', sdk_path, '-target', target, '-typecheck', str(probe)])
            if sdk != 'macosx':
                run(sdk + '-public-consumer', ['swift', 'build', '-c', 'release', '--package-path', 'Tools/JSONHTMLExport',
                    '--scratch-path', str(output / sdk), '--triple', target, '--sdk', sdk_path])
        binary = output / 'webpage-probe'
        run('webpage-compile', ['xcrun', 'swiftc', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
            '-target', 'arm64-apple-macos27.0', str(probe), '-o', str(binary)])
        text = run('webpage-region-runtime', [str(binary), str(output / 'WebPage-region-probe.pdf')], timeout=45)
        if 'finished=true' not in text or 'sentinel=true' not in text: raise ValueError('Incomplete region probe')
        receipt['backend_probe'] = {'observation': text.strip(), 'production_qualified': False,
            'pagination': 'region capture only; no A4/Letter backend selected',
            'pdf_sha256': hashlib.sha256((output / 'WebPage-region-probe.pdf').read_bytes()).hexdigest()}
        receipt['status'] = 'passed'
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        receipt['status'] = 'failed' if receipt['commands'] else 'blocked'
        receipt['error'] = str(error)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k: v for k, v in receipt.items() if k not in ('source_inputs', 'consumer')}, indent=2))
    return 0 if receipt['status'] == 'passed' else 1

if __name__ == '__main__': sys.exit(main())
