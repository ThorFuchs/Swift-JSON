#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Execute every pinned inherited row; policy rejections never count as evaluated success."""
import argparse,hashlib,json,pathlib,re,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Number(str):pass
def load(path):return json.loads(path.read_text(),parse_int=Number,parse_float=Number)
def encode(value):
 if isinstance(value,Number):return str(value)
 if value is None:return 'null'
 if value is True:return 'true'
 if value is False:return 'false'
 if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
 if isinstance(value,list):return '['+','.join(encode(x) for x in value)+']'
 if isinstance(value,dict):return '{'+','.join(json.dumps(k,ensure_ascii=False)+':'+encode(v) for k,v in value.items())+'}'
 raise TypeError(type(value))
def main():
 p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--comparator',required=True);p.add_argument('--oracle',required=True);p.add_argument('--output',required=True);a=p.parse_args()
 binary=(ROOT/a.binary).resolve();comparator=(ROOT/a.comparator).resolve();oracle=pathlib.Path(a.oracle).resolve();registry=ROOT/'Tests/Fixtures/CLI/Inherited';rows=[];pins=[]
 version=subprocess.run([str(oracle),'--version'],capture_output=True,timeout=10);assert version.returncode==0 and version.stdout.strip()==b'jq-1.8.2'
 with tempfile.TemporaryDirectory(prefix='swift-json-corpus-') as directory:
  directory=pathlib.Path(directory)
  def compare(actual,expected):
   ap=directory/'actual.json';ep=directory/'expected.json';ap.write_bytes(actual);ep.write_text(json.dumps(expected,ensure_ascii=False));r=subprocess.run([str(comparator),str(ap),str(ep)],capture_output=True,timeout=30);return r.returncode==0
  for name in ['golden-cases.json','subset-cases.json']:
   path=registry/name;data=load(path);pins.append({'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'cases':len(data['cases'])})
   for case in data['cases']:
    source=case['filter'];input_value=data.get('fixtures',{}).get(case.get('inputFixture')) if 'inputFixture' in case else case.get('input');raw=(encode(input_value)+'\n').encode()
    command=[str(binary),'query','--compact','--diagnostics=json','--',source];result=subprocess.run(command,input=raw,capture_output=True,timeout=30)
    reference=subprocess.run([str(oracle),'-c','--',source],input=raw,capture_output=True,timeout=30)
    expected=[encode(v) for v in case.get('expected',[])] if 'expected'in case else [line.decode() for line in reference.stdout.splitlines()]
    # Every unsupported row is classified from actual compiler output. This is
    # distinct from executing a supported row to an equal reference result.
    diagnostic=None
    try:diagnostic=json.loads(result.stderr)
    except ValueError:pass
    rejected=None
    if diagnostic and diagnostic.get('category')=='compile' and diagnostic.get('byteOffset') is not None:
     match=re.match(rb'[A-Za-z_][A-Za-z_0-9]*',source.encode()[diagnostic['byteOffset']:])
     if match:rejected=match.group().decode()
    deferred={'test','match','capture','scan','sub','gsub','sqrt','sin','cos','tan','log','exp','pow','nan','infinite','isnan','isinfinite','isfinite','isnormal','env','include','import'}
    forward=case['id']=='def-forward-reference' and result.returncode==reference.returncode==3 and rejected=='inner'
    policy=result.returncode==3 and (rejected in deferred or forward)
    evaluated=result.returncode==0 and reference.returncode==0
    equal=evaluated and compare(result.stdout,expected);oracle_equal=evaluated and compare(result.stdout,[line.decode() for line in reference.stdout.splitlines()])
    status='policy' if policy else 'passed' if equal else 'failed'
    row={'id':name+':'+case['id'],'historical_claim':case.get('status'),'filter':source,'command':['swift-json',*command[1:]],'exit_code':result.returncode,'reference_exit_code':reference.returncode,'status':status,'evaluated':evaluated,'golden_or_reference_equal':bool(equal),'pinned_oracle_equal':bool(oracle_equal),'stdout_sha256':hashlib.sha256(result.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(result.stderr).hexdigest(),'reference_stdout_sha256':hashlib.sha256(reference.stdout).hexdigest(),'diagnostic':result.stderr.decode(errors='replace')}
    if status=='failed':row.update(stdout=result.stdout.decode(errors='replace'),expected=expected,reference=reference.stdout.decode(errors='replace'));print(json.dumps(row,ensure_ascii=False),flush=True)
    if policy:row['reason']='Version 1 lexical earlier/self visibility rejects arbitrary forward definitions; observed compile rejection, not evaluated success.' if forward else 'Explicitly deferred '+str(rejected)+': observed compile rejection, not an evaluated success.'
    rows.append(row)
 receipt={'schema_version':1,'status':'passed' if len(rows)==168 and all(r['status']!='failed' for r in rows) else 'failed','observed':len(rows),'evaluated':sum(r['evaluated'] for r in rows),'passed':sum(r['status']=='passed' for r in rows),'policy':sum(r['status']=='policy' for r in rows),'failed':sum(r['status']=='failed' for r in rows),'fixtures':pins,'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'oracle':{'version':version.stdout.decode().strip(),'sha256':hashlib.sha256(oracle.read_bytes()).hexdigest()},'cases':rows}
 output=ROOT/a.output;output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(receipt,indent=2,ensure_ascii=False)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k!='cases'}));return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
