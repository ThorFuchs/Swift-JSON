#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Public cross-product acceptance and exact owned-counter/capacity observations."""
import argparse, hashlib, json, pathlib, re, subprocess
from archive_candidate import files
from qualify_structural_workflows import check_receipt as check_original_consumer

ROOT = pathlib.Path(__file__).resolve().parents[1]
MATRIX_PATH = ROOT / 'Documentation/Qualification/StructuralWorkflows1.8Matrix.json'
MATRIX = json.loads(MATRIX_PATH.read_text())
METRICS = {m['metric'] for m in json.loads((ROOT/'Documentation/Qualification/LimitsMatrix.json').read_text())['metrics']}
CASES = {'schema-store-transform', 'patched-owner', 'source-map-reset',
         'schema-refusal', 'root-removal', 'terminal-transform'}

def finite(value, positive=False):
    return type(value) is int and (0 < value if positive else 0 <= value) and value < 2**64 - 1

def validate_capacity(data):
    if not isinstance(data, dict): return False
    rows = data.get('cells', [])
    if not isinstance(rows, list) or any(not isinstance(r, dict) for r in rows): return False
    if data.get('schemaVersion') != 1 or data.get('profile') != MATRIX['profile'] or [r.get('id') for r in rows] != MATRIX['cells']:
        return False
    for row in rows:
        operation, size = row['id'].rsplit('-', 1); size = int(size)
        expected_fixture = 'chain-%d.json' % size if operation == 'follow-chain' else 'fixed-eight.json'
        if type(row.get('requests')) is not int or row['requests'] != size or row.get('operation') != operation or row.get('fixture') != expected_fixture:
            return False
        if row.get('outcome') == 'completed':
            report = row.get('report', {})
            if not (isinstance(report, dict) and all(finite(report.get(k), positive=k in ('work','nodes','peak')) for k in ['work','nodes','retained','peak'])
                    and report['peak'] >= report['retained'] and all(row.get(k) is True for k in ['requestBoundary','workBoundary','retentionBoundary'])
                    and all(row.get(k) is None for k in ['errorMetric','errorLimit','errorAttempted','errorStage'])):
                return False
            singles = row.get('independentSingles')
            if operation == 'follow-chain':
                if singles is not None: return False
            elif not (isinstance(singles, dict) and all(finite(singles.get(k), positive=k in ('workSum','nodesSum','maximumInvocationPeak'))
                    for k in ['workSum','nodesSum','maximumInvocationRetained','maximumInvocationPeak'])
                    and singles['nodesSum'] == size * report['nodes'] and singles['maximumInvocationPeak'] >= singles['maximumInvocationRetained']):
                return False
        elif row.get('outcome') == 'operational_error' and row['id'] in MATRIX['diagnostic_capacity']:
            if not (row.get('report') is None and row.get('independentSingles') is None
                    and all(row.get(k) is None for k in ['requestBoundary','workBoundary','retentionBoundary'])
                    and row.get('errorMetric') in METRICS
                    and finite(row.get('errorLimit')) and finite(row.get('errorAttempted'), positive=True)
                    and row['errorAttempted'] > row['errorLimit'] and row.get('errorStage') in ('construction','follow')):
                return False
        else:
            return False
    return all(next(r for r in rows if r['id'] == name)['outcome'] == 'completed' for name in MATRIX['required_complete'])

def validate_fixtures(directory):
    expected = {x['name']: x for x in MATRIX['fixtures']}
    actual = sorted(directory.glob('*.json'))
    if {p.name for p in actual} != set(expected) or any(p.is_symlink() for p in actual):
        raise ValueError('Changed capacity fixture inventory')
    records = []
    for path in actual:
        data = path.read_bytes(); record = dict(name=path.name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        if any(record[k] != expected[path.name][k] for k in ('bytes','sha256')):
            raise ValueError('Changed capacity fixture bytes: ' + path.name)
        records.append(record)
    return records

def check_receipt(data):
    commands = data.get('commands', [])
    expected = {'consumer','debug-binpath','debug-guide','release-binpath','release-guide','capacity'}
    fixtures = data.get('fixtures', [])
    return (data.get('status') == 'passed' and data.get('source_inputs_unchanged') is True
            and data.get('matrix_sha256') == hashlib.sha256(MATRIX_PATH.read_bytes()).hexdigest()
            and len(commands) == len(expected) and {c.get('name') for c in commands} == expected
            and all(c.get('exit') == 0 and c.get('compiler_crash') is False for c in commands)
            and set(data.get('consumer_results', {})) == {'debug','release'}
            and all(len(v) == len(CASES) and set(v) == CASES for v in data['consumer_results'].values())
            and validate_capacity(data.get('capacity', {}))
            and data.get('completed_cells') == sum(r['outcome'] == 'completed' for r in data['capacity']['cells'])
            and data.get('operational_refusals') == sum(r['outcome'] == 'operational_error' for r in data['capacity']['cells'])
            and data.get('performance_status', '').startswith('NOT MEASURED:')
            and len(fixtures) == len(MATRIX['fixtures']) and sorted(fixtures, key=lambda x:x['name']) == sorted(
                [{k:x[k] for k in ('name','bytes','sha256')} for x in MATRIX['fixtures']], key=lambda x:x['name']))

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--output', required=True)
    args = parser.parse_args(); out = ROOT / args.output; out.mkdir(parents=True, exist_ok=True)
    receipt = dict(status='running', source_inputs=[dict(path=p.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files()],
                   matrix_sha256=hashlib.sha256(MATRIX_PATH.read_bytes()).hexdigest(), commands=[], consumer_results={})
    def save(): (out/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    def run(name, command):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=1200)
        log = out/(name+'.log'); log.write_text(result.stdout+result.stderr)
        crash = (result.returncode < 0 and command[0] == 'swiftc') or any(x in log.read_text() for x in ['Stack dump:', 'Assertion failed', 'Found ownership error', 'fatal error encountered during compilation'])
        receipt['commands'].append(dict(name=name, command=command, exit=result.returncode, compiler_crash=crash, log=str(log.relative_to(ROOT)), log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        save(); print(name, result.returncode, flush=True)
        if result.returncode != 0 or crash: raise ValueError(name)
        return result.stdout
    try:
        child = out/'public-consumer'
        run('consumer', ['python3','-B','Scripts/qualify_structural_workflows.py','--output',str(child.relative_to(ROOT))])
        original = json.loads((child/'receipt.json').read_text())
        if not check_original_consumer(original): raise ValueError('Original public consumer/compiler boundary failed')
        for config in ['debug','release']:
            log = child/(config+'-consumer.log')
            cases = re.findall(r'^ACCEPTANCE18_CASE (\S+) passed$', log.read_text(), re.M)
            if len(cases) != 6 or set(cases) != CASES or len(re.findall(r'^ACCEPTANCE18 passed cases=6$', log.read_text(), re.M)) != 1:
                raise ValueError('Incomplete public cross-product witnesses')
            receipt['consumer_results'][config] = cases
            bp = pathlib.Path(run(config+'-binpath', ['swift','build','-c',config,'--package-path','Examples/BoundedWorkflows','--scratch-path','.build/workflow-consumer','--show-bin-path']).strip())
            modules = bp/'Modules' if (bp/'Modules').exists() else bp
            guide = ROOT/'Sources/JSONInspection/Documentation.docc/BoundedWorkflowRecipes.md'
            blocks = re.findall(r'```swift\n(.*?)\n```', guide.read_text(), re.S)
            if len(blocks) != 1: raise ValueError('Changed recipe snippet inventory')
            source = out/'guide.swift'; source.write_text(blocks[0]+'\n')
            run(config+'-guide', ['swiftc','-swift-version','6','-warnings-as-errors','-I',str(modules),'-Onone' if config == 'debug' else '-O',
                                  '-parse-as-library','-c',str(source),'-o',str(out/(config+'-guide.o'))])
        capacity = out/'capacity'
        run('capacity', ['swift','run','-c','release','--jobs','2','--package-path','Examples/BoundedWorkflows','--scratch-path','.build/workflow-consumer','BoundedWorkflows','--capacity',str(capacity)])
        data = json.loads((capacity/'cells.json').read_text())
        if not validate_capacity(data): raise ValueError('Changed/incomplete capacity observations or boundary proof')
        receipt['fixtures'] = validate_fixtures(capacity/'fixtures')
        receipt['capacity'] = data
        receipt['completed_cells'] = sum(r['outcome'] == 'completed' for r in data['cells'])
        receipt['operational_refusals'] = sum(r['outcome'] == 'operational_error' for r in data['cells'])
        receipt['capacity_status'] = 'observed_fixture_grid_complete' if not receipt['operational_refusals'] else 'partial_diagnostic_capacity'
        receipt['performance_status'] = 'NOT MEASURED: owned counters are not timings, heap allocations, RSS or throughput'
        receipt['status'] = 'passed'
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        receipt.update(status='failed', error=str(error))
    receipt['source_inputs_unchanged'] = receipt['source_inputs'] == [dict(path=p.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files()]
    if not receipt['source_inputs_unchanged']: receipt['status'] = 'failed'
    if receipt['status'] == 'passed' and not check_receipt(receipt): receipt.update(status='failed', error='Incomplete final acceptance receipt')
    save(); return 0 if receipt['status'] == 'passed' else 1

if __name__ == '__main__': raise SystemExit(main())
