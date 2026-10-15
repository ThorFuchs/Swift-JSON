#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Materialize the 24-case G3 acceptance matrix through actual public APIs."""
import argparse, hashlib, json, pathlib, subprocess, sys
from decimal import Decimal

ROOT = pathlib.Path(__file__).resolve().parents[1]
ORIGINAL = '6f2bfd4fdb7c7e206b6570c2156ca8e248831840733b0258aa8cd5938b35649f'
AMENDED = '5b3e6e40e83439a810d0eb7ac412ce158a4e582f36b9d36d6e313c159654ddd3'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('--scratch-path', default='.build')
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    rows = []
    receipt = {'schema_version': 1, 'status': 'failed', 'commands': rows,
               'scope': 'Public native generation/validation/roundtrip; not an independent external validator or G4/G7 qualification'}

    def run(name, command):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=1200)
        text = result.stdout + result.stderr
        log = output / (name + '.log')
        log.write_text(text.replace(str(ROOT), '.'))
        rows.append({'command': command, 'exit_code': result.returncode, 'log': log.relative_to(ROOT).as_posix(),
                     'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        if result.returncode: raise ValueError('Failed actual public consumer: ' + name)
        return text

    try:
        fixtures = ROOT / 'Tests/Fixtures/SchemaExamples'
        fixture = fixtures / 'S3-integral-correction-v1.json'
        manifest_path = fixtures / 'Manifest.json'
        manifest = json.loads(manifest_path.read_text())
        assert hashlib.sha256(fixture.read_bytes()).hexdigest() == manifest['amended_sha256'] == AMENDED
        assert hashlib.sha256((fixtures / 'S3-original-v1.json').read_bytes()).hexdigest() == manifest['original_sha256'] == ORIGINAL
        expected_ids = manifest['g3_must_generate_ids']
        assert len(expected_ids) == len(set(expected_ids)) == 24
        location = run('bin-path', ['swift', 'build', '--package-path', 'Examples/SchemaExamplesConsumer', '--show-bin-path', '--scratch-path', args.scratch_path])
        bins = [pathlib.Path(line) for line in location.splitlines() if line.startswith('/')]
        assert len(bins) == 1
        binary = bins[0] / 'SchemaExamplesConsumer'
        receipts = []
        for index in range(2):
            text = run('generation-process-' + str(index), [str(binary), '--g3-fixtures', str(fixture), '--g3-manifest', str(manifest_path)])
            assert 'SCHEMA_EXAMPLES_G3 passed cases=24 profiles=2 seeds=4 validated=192 witnesses=90 proofs=2' in text.splitlines()
            report_lines = [line.removeprefix('G3_RECEIPT ') for line in text.splitlines() if line.startswith('G3_RECEIPT ')]
            assert len(report_lines) == 1
            report = json.loads(report_lines[0], parse_float=Decimal)
            assert report['ids'] == expected_ids and report['witnesses'] == 90
            assert report['proofs'] == manifest['g3_sound_proof_ids']
            assert report['algorithm'] == 's3-candidates-v3' and len(report['results']) == 192
            expected = {(name, profile, seed) for name in expected_ids for profile in ['minimal','demonstration'] for seed in [0,1,42,2**64-1]}
            observed = {(r['id'],r['profile'],r['seed']) for r in report['results']}
            assert observed == expected
            for r in report['results']:
                assert r['nativeCertified'] is r['independentNativeValid'] is r['roundtrip'] is True
                assert 0 < r['evaluationWork'] <= r['work'] and r['remainingWork'] >= 0
                assert r['attempts'] >= 1 and len(r['trace']) == len(r['snapshot']) == len(r['corpus']) == len(r['policy']) == 64
            (output / ('generation-process-' + str(index) + '.json')).write_text(report_lines[0] + '\n')
            receipts.append(report)
        assert receipts[0] == receipts[1], 'Cross-process generation/trace/accounting drift'
        receipt.update(status='passed', cases=24, profiles=2, seeds=4, generated_per_process=192,
                       processes=2, witnesses_per_process=90, sound_proofs_per_process=2,
                       input_sha256=AMENDED, original_sha256=ORIGINAL,
                       binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                       expected_case_ids=expected_ids, source_policies_excluded_from_successes=['18 G4 cases'])
    except (AssertionError, ValueError, OSError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error) or type(error).__name__
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('SCHEMA_EXAMPLES_GENERATION ' + receipt['status'] + ' cases=24 profiles=2 seeds=4 per_process=192 processes=2 proofs=2')
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
