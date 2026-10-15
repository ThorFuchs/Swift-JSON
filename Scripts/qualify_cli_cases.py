#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run authored CLI vectors and use an independent native exact-value consumer."""
import argparse, hashlib, json, pathlib, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--comparator',required=True);p.add_argument('--gate',default='C2');p.add_argument('--output',required=True);a=p.parse_args()
    binary=(ROOT/a.binary).resolve(); comparator=(ROOT/a.comparator).resolve(); fixture=ROOT/'Tests/Fixtures/CLI/NewCases.json';declaration=json.loads(fixture.read_text());rows=[]
    with tempfile.TemporaryDirectory(prefix='cli-vectors-') as directory:
        directory=pathlib.Path(directory)
        for case in declaration['cases']:
            if case['gate']!=a.gate:continue
            argv=[case['command'],*case.get('options',[])]
            if case['command']=='query':argv += declaration['default_query_options']+['--',case['filter']]
            argv += case.get('operands',[])
            if 'expected_diagnostic_code' in case: argv.insert(1, '--diagnostics=json')
            result=subprocess.run([str(binary),*argv],input=case.get('stdin_utf8','').encode(),capture_output=True,timeout=30)
            passed=result.returncode==case['expected_exit'];comparison=None
            diagnostic=None
            if 'expected_diagnostic_code' in case:
                try:
                    diagnostics=[json.loads(line) for line in result.stderr.splitlines()]
                    diagnostic=[row for row in diagnostics if row.get('kind')=='diagnostic']
                    passed=passed and len(diagnostic)==1 and diagnostic[0].get('code')==case['expected_diagnostic_code']
                except (ValueError,TypeError):passed=False
            if 'expected_stdout_utf8' in case:passed=passed and result.stdout==case['expected_stdout_utf8'].encode()
            if 'expected_json_values' in case and result.returncode==case['expected_exit']:
                actual=directory/'actual.json';expected=directory/'expected.json';actual.write_bytes(result.stdout);expected.write_text(json.dumps(case['expected_json_values'],ensure_ascii=False))
                checked=subprocess.run([str(comparator),str(actual),str(expected)],capture_output=True,timeout=30)
                comparison={'exit':checked.returncode,'stdout':checked.stdout.decode(),'stderr':checked.stderr.decode()};passed=passed and checked.returncode==0
            row={'id':case['id'],'requirement_ids':case['requirement_ids'],'command':['swift-json',*argv],'exit_code':result.returncode,'expected_exit':case['expected_exit'],'status':'passed' if passed else 'failed','stdout_sha256':hashlib.sha256(result.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(result.stderr).hexdigest(),'comparison':comparison,'diagnostic':diagnostic}
            if not passed:row.update(stdout=result.stdout.decode(errors='replace'),stderr=result.stderr.decode(errors='replace'));print(json.dumps(row),flush=True)
            rows.append(row)
    receipt={'schema_version':1,'gate':a.gate,'status':'passed' if all(x['status']=='passed' for x in rows) and rows else 'failed','observed':len(rows),'passed':sum(x['status']=='passed' for x in rows),'failed':sum(x['status']=='failed' for x in rows),'policy':0,'fixture_sha256':hashlib.sha256(fixture.read_bytes()).hexdigest(),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'comparator_sha256':hashlib.sha256(comparator.read_bytes()).hexdigest(),'cases':rows}
    output=ROOT/a.output;output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k!='cases'}));return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
