#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Public bounded grammar replay, exact identities and two-process reproducibility."""
import argparse,hashlib,json,pathlib,subprocess,sys
from decimal import Decimal
ROOT=pathlib.Path(__file__).resolve().parents[1]
FIXTURE_SHA='cb55604183a6db7df5fa968db283e7abeae794277d2b0cef033b0bdb92e615cb'

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',required=True);p.add_argument('--scratch-path',default='.build');a=p.parse_args()
    out=ROOT/a.output;out.mkdir(parents=True,exist_ok=True)
    receipt=dict(status='failed',commands=[],scope='64 bounded grammar cases, not exhaustive arbitrary schemas; independent external oracle is a separate research receipt')
    def run(name,cmd):
        r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=1500)
        text=r.stdout+r.stderr;log=out/(name+'.log');log.write_text(text)
        receipt['commands'].append(dict(command=cmd,exit_code=r.returncode,log=log.name,sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
        if r.returncode:raise ValueError(name+' failed')
        return text
    try:
        fixture=ROOT/'Tests/Fixtures/SchemaExamples/S3-G7-seeded-v1.json'
        assert hashlib.sha256(fixture.read_bytes()).hexdigest()==FIXTURE_SHA
        cases=json.loads(fixture.read_text())['cases'];ids={r['id'] for r in cases};assert len(ids)==len(cases)==64
        location=run('bin-path',['swift','build','--package-path','Examples/SchemaExamplesConsumer','--show-bin-path','--scratch-path',a.scratch_path])
        binary=pathlib.Path(location.strip())/'SchemaExamplesConsumer'
        outputs=[]
        expected={(i,p,s) for i in ids for p in ['minimal','demonstration'] for s in [0,1,42,2**64-1]}
        for i in range(2):
            text=run('process-'+str(i),[str(binary),'--g7-fuzz',str(fixture)])
            assert 'SCHEMA_EXAMPLES_G7 passed schemas=64 certified=512 invalid=64' in text.splitlines()
            lines=[l.removeprefix('G7_RESULT ') for l in text.splitlines() if l.startswith('G7_RESULT ')]
            rows=[json.loads(l,parse_float=Decimal) for l in lines]
            assert len(rows)==512 and {(r['id'],r['profile'],r['seed']) for r in rows}==expected
            assert all(0<r['evaluationWork']<=r['work'] and 1<=r['attempts']<=16 and len(r['trace'])==64 for r in rows)
            payload='['+','.join(lines)+']\n';(out/('results-'+str(i)+'.json')).write_text(payload);outputs.append(payload)
        assert outputs[0]==outputs[1], 'Cross-process candidate/trace/accounting drift'
        receipt.update(status='passed',schemas=64,certified_per_process=512,known_invalid_per_process=64,processes=2,byte_equal=True,fixture_sha256=FIXTURE_SHA,binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest())
    except (AssertionError,ValueError,OSError,subprocess.SubprocessError) as e:receipt['error']=str(e) or type(e).__name__
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('SCHEMA_EXAMPLES_MATRIX '+receipt['status']+' schemas=64 certified=512 invalid=64 processes=2')
    return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':sys.exit(main())
