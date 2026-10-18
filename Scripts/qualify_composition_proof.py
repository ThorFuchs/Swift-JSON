#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Independent public SwiftPM tests, real mutant failures and ownership builds."""
import argparse, datetime, hashlib, json, os, pathlib, subprocess, sys, tempfile
from testing_events import read_events

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKAGE = 'Tools/CompositionQualification'
EXPECTED_TESTS = 29
NEGATIVE = {
    'Copy': ["'copy' cannot be applied to noncopyable types"], 'Construct': ['inaccessible'], 'Escape': ['borrowed'],
    'ExplicitEscape': ['borrowed'], 'Return': ['Copyable'], 'Sendable': ['Sendable'], 'Async': ['async', 'synchronous'],
    'Reset': ["no member 'reset'"], 'Fork': ["no member 'fork'"],
    'Refund': ["no member 'release'"], 'PackageMeter': ['inaccessible'],
    'RawMeter': ['JSONWorkMeter', 'cannot find'], 'Substitute': ['immutable'],
    'Store': ['borrowed']
}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', required=True)
    a = p.parse_args(); output = (ROOT / a.output).resolve(); output.mkdir(parents=True, exist_ok=True)
    receipt = dict(status='running', commands=[], public_tests_per_configuration=EXPECTED_TESTS,
                   compiler_negative_cases=len(NEGATIVE), expected_failing_mutants=2)
    def save(): (output/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    def run(name, command, env=None, expected_failure=False):
        log = output/(name+'.log'); started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with log.open('w') as stream:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
        record = dict(name=name, command=command, exit_code=result.returncode,
                      started_utc=started, log=log.name, log_sha256=hashlib.sha256(log.read_bytes()).hexdigest(),
                      expected_failure=expected_failure)
        receipt['commands'].append(record); save()
        print(name, 'exit='+str(result.returncode), flush=True)
        return record, log.read_text()
    save()
    for config in ['debug', 'release']:
        directory=output/config; directory.mkdir(exist_ok=True)
        events=directory/'events.jsonl'; env=os.environ.copy(); env['JCOMP_TRACE_DIRECTORY']=str(directory)
        command=['swift','test','--package-path',PACKAGE,'-c',config,'--filter','CompositionPublicTests','--event-stream-output-path',str(events)]
        if sys.platform == 'linux': command.append('--disable-xctest')
        record, log=run(config,command,env)
        assert record['exit_code']==0,log[-6000:]
        parsed=read_events(events.read_text())
        assert parsed['module_function_counts']=={'CompositionPublicTests':EXPECTED_TESTS} and parsed['parameter_case_invocations']==0
        record['swift_testing_events']=dict(parsed,path=events.relative_to(output).as_posix(),sha256=hashlib.sha256(events.read_bytes()).hexdigest());save()
        assert (directory/'owned-events.tsv').read_text()=='owner\twork\tlogical_bytes\nqueue\t65\t96\nscratch\t33\t64\nresult\t49\t80\nreceipt\t50\t424\n'
    # Mutants run the unchanged positive test as an actually failing test process.
    for mutation in ['work','reservation']:
        events=output/('mutant-'+mutation+'.events.jsonl')
        env=os.environ.copy();env['JCOMP_TRACE_MUTATION']=mutation
        command=['swift','test','--package-path',PACKAGE,'--skip-build','--filter','externalTraceMatchesIndependentLedger','--event-stream-output-path',str(events)]
        if sys.platform == 'linux': command.append('--disable-xctest')
        record,log=run('mutant-'+mutation,command,env,expected_failure=True)
        assert record['exit_code']==1 and ('workTrace' if mutation=='work' else 'retentionTrace') in log
        rows=[json.loads(line) for line in events.read_text().splitlines() if line]
        issues=[r for r in rows if r['kind']=='event' and r['payload']['kind']=='issueRecorded']
        completed=[r for r in rows if r['kind']=='event' and r['payload']['kind']=='testEnded']
        assert len(issues)==1 and len(completed)==1
        record.update(expected_issue=mutation,raw_issue_events=1,completed_test_functions=1,event_stream=events.name,event_sha256=hashlib.sha256(events.read_bytes()).hexdigest());save()
    # Each fixture is a separate unrelated SwiftPM package/build, using exactly
    # normal public products. No package-name override, @testable, SPI or shim.
    with tempfile.TemporaryDirectory(prefix='swift-json-composition-negative-') as temp:
        for name,diagnostics in NEGATIVE.items():
            directory=pathlib.Path(temp)/name; sources=directory/'Sources/NegativeConsumer';sources.mkdir(parents=True)
            (directory/'Package.swift').write_text('// swift-tools-version: 6.4\nimport PackageDescription\nlet package = Package(name: "IndependentNegative'+name+'", platforms: [.macOS("27.0")], dependencies: [.package(name: "Swift-JSON", path: '+json.dumps(str(ROOT))+')], targets: [.executableTarget(name: "NegativeConsumer", dependencies: [.product(name: "JSON", package: "Swift-JSON"), .product(name: "JSONSchema", package: "Swift-JSON")])], swiftLanguageModes: [.v6])\n')
            fixture=ROOT/PACKAGE/'ProofNegative'/(name+'.swift.txt')
            (sources/'main.swift').write_bytes(fixture.read_bytes())
            command=['swift','build','--build-system','native','--package-path',str(directory),'--scratch-path',str(output/'negative-build')]
            record,log=run('negative-'+name,command,expected_failure=True)
            assert record['exit_code']==1 and all(d in log for d in diagnostics), log[-6000:]
            assert not any(d in log for d in ['no such module','Please submit a bug report','Stack dump','SIL verification failed'])
            record.update(expected_diagnostics=diagnostics,fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest());save()
    receipt['status']='passed'; save()
    print('COMPOSITION_PROOF passed public_tests=29 configurations=2 mutants_rejected=2 compiler_negative=14')
    return 0

if __name__=='__main__': raise SystemExit(main())
