#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Real external SwiftPM consumer plus domain-specific public-boundary codegen."""
import argparse, hashlib, json, pathlib, re, subprocess
from archive_candidate import files
ROOT = pathlib.Path(__file__).resolve().parents[1]
CASES = {'batch-exact-order', 'missing-is-error', 'batch-capacity', 'snapshot-root',
         'checked-construction', 'scalar-identity', 'missing-id', 'store-batch',
         'complete-cycle', 'owner-refusal', 'complete-or-error', 'cumulative-report'}
PROBES = {
 'position-forge': ('func invalid() { _ = JSONStorePosition() }', 'initializer is inaccessible'),
 'store-forge': ('func invalid() { _ = JSONConfiguredStore() }', 'initializer is inaccessible'),
 'private-context': ('func invalid(_ context: JSONTraversalContext) {}', "cannot find type 'JSONTraversalContext' in scope"),
 'version': ('func invalid() { _ = JSONStoreProfileVersion.v2 }', "has no member 'v2'"),
 'nullable': ('func invalid() { _ = JSONStoreReferenceField(key:"f",presence:.required,nullable:"yes") }', "cannot convert value of type 'String' to expected argument type 'Bool'"),
 'mutation': ('func invalid(_ store: JSONConfiguredStore) { store.document = JSONDocument(root:.null) }', "'document' is a 'let' constant"),
}
def check_receipt(data):
    configs = {'debug', 'release'}
    expected_names = {f'{c}-{name}' for c in configs for name in ['consumer','binpath','guide',*PROBES]}
    commands = data.get('commands', [])
    return (data.get('status') == 'passed' and len(commands) == len(expected_names)
        and {c['name'] for c in commands} == expected_names
        and all(c.get('passed') and c.get('compiler_crash') is False and
                (c['exit'] > 0 and any(c['expected'].lower() in d.lower() for d in c['primary_diagnostics'])
                 if c.get('expected') else c['exit'] == 0) for c in commands)
        and set(data.get('consumer_results', {})) == configs
        and all(set(x['cases']) == CASES and len(x['cases']) == len(CASES)
                and x['work_units'] > 0 and x['logical_retained_bytes'] > 0
                for x in data['consumer_results'].values()))
def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--output', required=True)
    args = parser.parse_args(); out = ROOT / args.output; out.mkdir(parents=True, exist_ok=True)
    receipt = {'status':'running', 'source_inputs':[
        {'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()],
        'commands':[], 'consumer_results':{}}
    def save(): (out/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    def run(name, command, expected=None):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=1200)
        log = result.stdout + result.stderr
        signal = result.returncode < 0
        crash = (signal and command[0] == 'swiftc') or any(x in log for x in ['Stack dump:', 'Assertion failed', 'Found ownership error', 'fatal error encountered during compilation'])
        diagnostics = re.findall(r': error: ([^\n]+)', log)
        passed = not signal and not crash and (result.returncode == 0 if expected is None else result.returncode > 0 and any(expected.lower() in d.lower() for d in diagnostics))
        path = out/(name+'.log'); path.write_text(log)
        receipt['commands'].append(dict(name=name, command=command, exit=result.returncode, passed=passed,
            compiler_crash=crash, signal_termination=signal, expected=expected, primary_diagnostics=diagnostics,
            log=str(path.relative_to(ROOT)), log_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        save(); print(name, result.returncode, 'PASS' if passed else 'FAIL', flush=True)
        if not passed: raise ValueError(name)
        return result.stdout
    try:
        for config in ['debug','release']:
            common = ['swift', 'run', '-c', config, '--jobs', '2', '--package-path', 'Examples/BoundedWorkflows', '--scratch-path', '.build/workflow-consumer']
            text = run(config+'-consumer', common+['BoundedWorkflows'])
            cases = re.findall(r'^WORKFLOW_CASE (\S+) passed$', text, re.M)
            summary = re.findall(r'^BOUNDED_WORKFLOWS passed cases=12 work=([1-9]\d*) logical_retained=([1-9]\d*)$', text, re.M)
            if len(cases) != 12 or set(cases) != CASES or len(summary) != 1: raise ValueError('Incomplete actual consumer witnesses')
            receipt['consumer_results'][config] = dict(cases=cases, work_units=int(summary[0][0]), logical_retained_bytes=int(summary[0][1]))
            bp = pathlib.Path(run(config+'-binpath', ['swift','build','-c',config,'--package-path','Examples/BoundedWorkflows','--scratch-path','.build/workflow-consumer','--show-bin-path']).strip())
            modules = bp/'Modules' if (bp/'Modules').exists() else bp
            guide = ROOT/'Sources/JSONInspection/Documentation.docc/BoundedWorkflows.md'
            blocks = re.findall(r'```swift\n(.*?)\n```', guide.read_text(), re.S)
            if len(blocks) != 1: raise ValueError('Changed DocC example inventory')
            source = out/'guide.swift'; source.write_text(blocks[0]+'\n')
            run(config+'-guide', ['swiftc','-swift-version','6','-warnings-as-errors','-I',str(modules),
                '-Onone' if config == 'debug' else '-O', '-parse-as-library','-c',str(source),'-o',str(out/(config+'-guide.o'))])
            for name, (body, expected) in PROBES.items():
                source = out/(name+'.swift'); source.write_text('import JSON\nimport JSONNavigation\nimport JSONInspection\n'+body+'\n')
                run(config+'-'+name, ['swiftc','-swift-version','6','-warnings-as-errors','-I',str(modules),
                    '-Onone' if config == 'debug' else '-O', '-parse-as-library','-c',str(source),'-o',str(out/(config+'-'+name+'.o'))], expected)
        receipt['status'] = 'passed'
        if not check_receipt(receipt): raise ValueError('Incomplete receipt')
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        receipt.update(status='failed', error=str(error))
    save(); return 0 if receipt['status'] == 'passed' else 1
if __name__ == '__main__': raise SystemExit(main())
