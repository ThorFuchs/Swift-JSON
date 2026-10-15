#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Materialize public-only reference import results and exact fixture identities."""
import argparse
import hashlib
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)
    command = ['swift', 'run', '-c', 'release', '--package-path', 'Tools/CompositionQualification',
               'CompositionScaleProbe', str(output / 'cells.json'), str(output / 'fixtures')]
    run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=900)
    (output / 'command.log').write_text(run.stdout + run.stderr)
    rows = json.loads((output / 'cells.json').read_text()) if run.returncode == 0 else []
    expected = ['balanced-16-32', 'balanced-128-64', 'balanced-128-128', 'offline-256-256',
                'balanced-1024-1024', 'offline-1024-1024',
                'staged-balanced-128-128', 'staged-offline-512-256']
    completed = [r for r in rows if r['outcome'] == 'completed']
    refused = [r for r in rows if r['outcome'] == 'operational_error']
    valid = (run.returncode == 0 and [r['name'] for r in rows] == expected
             and len(completed) == 5 and len(refused) == 3
             and all(r['outcome'] == r['expected'] for r in rows)
             and all(r['completedReferences'] == r['references'] and r['work'] > 0 and r['logicalPeak'] > 0 for r in completed)
             and all(0 < r['completedReferences'] < r['references'] and r.get('metric') for r in refused))
    fixtures = [{'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size,
                 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                for p in sorted((output / 'fixtures').glob('*.json'))]
    unmet = [r['name'] for r in rows if r['outcome'] != r['capacityGoal']]
    valid = valid and unmet == ['balanced-128-128']
    receipt = dict(status='passed' if valid else 'failed', command=command, exit_code=run.returncode,
                   cells=len(rows), completed_imports=len(completed), operational_refusals=len(refused),
                   adoption_status='bounded_fixtures_only',
                   simple_strategy_capacity_status='blocked' if unmet else 'not_assessed',
                   unmet_capacity_targets=unmet,
                   fixtures=fixtures, results=rows,
                   scope='Synthetic public-API reference imports; no protocol conformance or arbitrary callback/RSS guarantee.',
                   timing='Functional observations only; not an idle-host timing comparison.')
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k: v for k, v in receipt.items() if k not in ['fixtures', 'results']}))
    return 0 if valid else 1

if __name__ == '__main__':
    raise SystemExit(main())
