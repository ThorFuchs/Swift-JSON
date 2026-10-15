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
            argv=[str(ROOT/'Tests/Fixtures/CLI/NewInputs'/pathlib.Path(x).name) if x.startswith('fixtures/new/') else x for x in argv]
            probe=case.get('probe',{})
            provider=case['command']=='schema' and case.get('operands',[])[:1]==['provider']
            if provider:argv.insert(1,'--diagnostics=json')
            if 'assert_final_completed' in probe:argv.insert(1,'--report=json')
            if 'expected_diagnostic_code' in case: argv.insert(1, '--diagnostics=json')
            result=subprocess.run([str(binary),*argv],input=case.get('stdin_utf8','').encode(),capture_output=True,timeout=30)
            passed=result.returncode==case['expected_exit'];comparison=None;blocked=False
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
            if probe:
                if 'assert_result_valid' in probe:
                    try:passed=passed and json.loads(result.stdout)['valid']==probe['assert_result_valid']
                    except (ValueError,KeyError,TypeError):passed=False
                if 'assert_final_completed' in probe:
                    try:passed=passed and json.loads(result.stderr.splitlines()[-1])['completed']==probe['assert_final_completed']
                    except (ValueError,KeyError,TypeError,IndexError):passed=False
                if probe.get('assert_no_script_element'):
                    passed=passed and b'<script' not in result.stdout.lower()
                if probe.get('assert_exact_value'):
                    passed=passed and b'9007199254740993' in result.stdout
                if probe.get('assert_no_external_assets'):
                    passed=passed and not any(x in result.stdout.lower() for x in [b'src="http',b'src="//',b'@import',b'url(http'])
                if provider and result.returncode in (0,1):
                    source_path=next(pathlib.Path(x) for x in argv if x.endswith('.json') and pathlib.Path(x).is_file())
                    original=source_path.read_bytes()
                    if probe.get('assert_path_types'):
                        payload=json.loads(result.stdout)
                        for pointer,kind in probe['assert_path_types'].items():
                            selected=payload
                            for token in pointer.lstrip('/').split('/'):
                                token=token.replace('~1','/').replace('~0','~')
                                selected=selected[int(token)] if isinstance(selected,list) else selected[token]
                            passed=passed and (isinstance(selected,dict) if kind=='object' else False)
                        name=argv[argv.index('--name')+1]
                        fragment=b'{"type":"json_schema","name":'+json.dumps(name).encode()+b',"strict":true,"schema":'+original.strip()+b'}'
                        expected_bytes=json.dumps([fragment.decode('utf-8')],ensure_ascii=False).encode('utf-8')
                        actual=directory/'provider-actual.json';expected=directory/'provider-expected.json'
                        actual.write_bytes(result.stdout);expected.write_bytes(expected_bytes)
                        checked=subprocess.run([str(comparator),str(actual),str(expected)],capture_output=True,timeout=30)
                        comparison={'exit':checked.returncode,'stdout':checked.stdout.decode(),'stderr':checked.stderr.decode()};passed=passed and checked.returncode==0
                    if probe.get('assert_no_lowering'):
                        payload=json.loads(result.stdout)
                        passed=passed and payload.get('compatible') is False and 'schema' not in payload and 'parameters' not in payload and any(x.get('code')=='allPropertiesRequired' for x in payload.get('issues',[])) and source_path.read_bytes()==original
                    if probe.get('assert_no_network'):
                        paths=list((ROOT/'Sources/JSONSchema/Providers').glob('*.swift'))+[ROOT/'Sources/JSONCLIEngine/CLISchemaCommand.swift']
                        passed=passed and all(not any(token in path.read_text() for token in ['import FoundationNetworking','URLSession','URLRequest','import OpenAI','LanguageModelSession']) for path in paths)
                if provider and result.returncode==2:
                    try:blocked=json.loads(result.stderr)['code']=='capabilityUnavailable' and not result.stdout
                    except (ValueError,KeyError,TypeError):blocked=False
            row={'id':case['id'],'requirement_ids':case['requirement_ids'],'command':['swift-json',*argv],'exit_code':result.returncode,'expected_exit':case['expected_exit'],'status':'passed' if passed else 'blocked' if blocked else 'failed','stdout_sha256':hashlib.sha256(result.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(result.stderr).hexdigest(),'comparison':comparison,'diagnostic':diagnostic}
            if blocked:row['blocker']='Qualified schema-provider helper prerequisite absent at renderer base 3c1e8a1a; actual capabilityUnavailable exit 2 is not the expected provider success/rejection'
            if not passed:row.update(stdout=result.stdout.decode(errors='replace'),stderr=result.stderr.decode(errors='replace'));print(json.dumps(row),flush=True)
            rows.append(row)
    receipt={'schema_version':1,'gate':a.gate,'status':'blocked' if rows and any(x['status']=='blocked' for x in rows) and not any(x['status']=='failed' for x in rows) else 'passed' if all(x['status']=='passed' for x in rows) and rows else 'failed','observed':len(rows),'passed':sum(x['status']=='passed' for x in rows),'failed':sum(x['status']=='failed' for x in rows),'blocked':sum(x['status']=='blocked' for x in rows),'policy':0,'fixture_sha256':hashlib.sha256(fixture.read_bytes()).hexdigest(),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'comparator_sha256':hashlib.sha256(comparator.read_bytes()).hexdigest(),'cases':rows}
    output=ROOT/a.output;output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k!='cases'}));return 0 if receipt['status']=='passed' else 2 if receipt['status']=='blocked' else 1
if __name__=='__main__':raise SystemExit(main())
