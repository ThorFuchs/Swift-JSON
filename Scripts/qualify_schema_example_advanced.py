#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Materialize ten G4 successes and eight honest incomplete-search cases through public APIs."""
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
               'scope': 'G4 public native construction and honest incompleteness; all 155 native witness checks, not new external-oracle or G7 platform qualification'}

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
        required_ids = manifest['g4_must_generate_ids']
        incomplete_ids = manifest['g4_may_fail_ids']
        assert len(required_ids) == len(set(required_ids)) == 10
        assert len(incomplete_ids) == len(set(incomplete_ids)) == 8
        assert not set(required_ids) & set(incomplete_ids)
        location = run('bin-path', ['swift', 'build', '--package-path', 'Examples/SchemaExamplesConsumer', '--show-bin-path', '--scratch-path', args.scratch_path])
        bins = [pathlib.Path(line) for line in location.splitlines() if line.startswith('/')]
        assert len(bins) == 1
        binary = bins[0] / 'SchemaExamplesConsumer'
        receipts = []
        for index in range(2):
            text = run('generation-process-' + str(index), [str(binary), '--g4-fixtures', str(fixture), '--g4-manifest', str(manifest_path)])
            assert 'SCHEMA_EXAMPLES_G4 passed required=10 incomplete=8 profiles=2 seeds=4 invocations=144 witnesses=155' in text.splitlines()
            report_lines = [line.removeprefix('G4_RECEIPT ') for line in text.splitlines() if line.startswith('G4_RECEIPT ')]
            assert len(report_lines) == 1
            report = json.loads(report_lines[0], parse_float=Decimal)
            assert report['requiredIDs'] == required_ids and report['incompleteIDs'] == incomplete_ids
            assert report['schemas'] == 44 and report['witnesses'] == 155 and report['mustValid'] == 80
            assert report['algorithm'] == 's3-candidates-v4' and len(report['results']) == 144
            expected = {(name, profile, seed) for name in required_ids + incomplete_ids for profile in ['minimal','demonstration'] for seed in [0,1,42,2**64-1]}
            observed = {(r['id'],r['profile'],r['seed']) for r in report['results']}
            assert observed == expected
            must_valid = may_valid = explicit = 0
            for r in report['results']:
                required = r['id'] in required_ids
                assert r['required'] is required
                if r['outcome'] == 'validated':
                    assert r['nativeCertified'] is r['independentNativeValid'] is r['roundtrip'] is True
                    assert 0 < r['evaluationWork'] <= r['work'] and r['remainingWork'] >= 0
                    assert 1 <= r['attempts'] <= 16 and len(r['trace']) == len(r['snapshot']) == len(r['corpus']) == len(r['policy']) == 64
                    assert 'value' in r
                    if required: must_valid += 1
                    else: may_valid += 1
                else:
                    assert not required and r['outcome'] in ['unsupported','searchExhausted']
                    assert not any(k in r for k in ['value','work','evaluationWork','remainingWork','nativeCertified'])
                    if r['outcome'] == 'unsupported': assert r['reason'] in ['candidateConstruction','dynamicReference','cyclicReference']
                    else: assert 1 <= r['attempts'] <= 16
                    explicit += 1
            assert must_valid == 80 and may_valid + explicit == 64
            assert may_valid == report['mayValid'] and explicit == report['explicit']
            (output / ('generation-process-' + str(index) + '.json')).write_text(report_lines[0] + '\n')
            receipts.append(report)
        assert receipts[0] == receipts[1], 'Cross-process generation/trace/accounting drift'
        receipt.update(status='passed', required_cases=10, incomplete_cases=8, profiles=2, seeds=4,
                       invocations_per_process=144, required_valid_per_process=80, may_valid_per_process=may_valid,
                       explicit_incomplete_per_process=explicit, processes=2, fixture_schemas=44, native_witnesses_per_process=155,
                       input_sha256=AMENDED, original_sha256=ORIGINAL,
                       binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                       required_case_ids=required_ids, incomplete_case_ids=incomplete_ids,
                       classification='A valid witness is success; unsupported/exhausted is incomplete search; native operational errors fail acceptance')
    except (AssertionError, ValueError, OSError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error) or type(error).__name__
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('SCHEMA_EXAMPLES_ADVANCED ' + receipt['status'] + ' required=10 incomplete=8 profiles=2 seeds=4 per_process=144 processes=2 witnesses=155')
    return 0 if receipt['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
