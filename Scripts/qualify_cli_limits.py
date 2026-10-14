#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Real subprocess rendezvous at the sixteen CLI quota sites and numeric reports."""
import argparse,hashlib,json,pathlib,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--output',required=True);a=p.parse_args();binary=(ROOT/a.binary).resolve();rows=[]
 with tempfile.TemporaryDirectory(prefix='swift-json-limits-') as directory:
  directory=pathlib.Path(directory);configuration=directory/'limits.json'
  probes=[('argvBytes',[],b''),('querySourceBytes',['query','-n','--','.'],b''),('queryTokens',['query','-n','--','.'],b''),('astNodes',['query','-n','--','.'],b''),('queryDepth',['query','-n','--','.'],b''),('runtimeFrames',['query','-n','--','.'],b''),('bindings',['query','-n','--','.'],b''),('collectionValues',['query','-n','--','[1]'],b''),('totalInputBytes',['format'],b'null'),('totalOutputBytes',['query','-n','--','1'],b''),('totalRecords',['format'],b'null'),('totalResults',['query','-n','--','1'],b''),('totalWorkUnits',['format'],b'null'),('retainedBytes',['format'],b'null'),('diskStagingBytes',['format','--output',str(directory/'output.json')],b'null')]
  for metric,argv,data in probes:
   configuration.write_text(json.dumps({'cli':{metric:0}}))
   argv=argv or ['format']
   command=[str(binary),argv[0],'--diagnostics=json','--limits-file',str(configuration),*argv[1:]]
   result=subprocess.run(command,input=data,capture_output=True,timeout=30)
   diagnostic=None
   try:diagnostic=json.loads(result.stderr)
   except ValueError:pass
   passed=result.returncode==6 and not result.stdout and diagnostic is not None and diagnostic.get('metric')==metric and diagnostic.get('limit')==0 and (diagnostic.get('attemptedUsage',0)>0 or diagnostic.get('overflow'))
   rows.append({'metric':metric,'command':['swift-json',*command[1:]],'exit_code':result.returncode,'status':'passed' if passed else 'failed','diagnostic':diagnostic,'stdout_sha256':hashlib.sha256(result.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(result.stderr).hexdigest()})
   if not passed:print(metric,result.returncode,result.stdout,result.stderr,flush=True)
  # Diagnostics cannot erase the originating syntax failure. Find its exact finite
  # byte boundary, then verify one byte below suppresses a whole JSONL record.
  initial=subprocess.run([str(binary),'format','--diagnostics=json'],input=b'{',capture_output=True,timeout=30)
  boundary=len(initial.stderr);outcomes=[]
  for cap in (boundary,boundary-1):
   configuration.write_text(json.dumps({'cli':{'diagnosticBytes':cap}}))
   result=subprocess.run([str(binary),'format','--diagnostics=json','--limits-file',str(configuration)],input=b'{',capture_output=True,timeout=30)
   outcomes.append({'cap':cap,'exit_code':result.returncode,'bytes':len(result.stderr),'passed':result.returncode==5 and (result.stderr==initial.stderr if cap==boundary else not result.stderr)})
  rows.append({'metric':'diagnosticBytes','status':'passed' if boundary>0 and all(x['passed'] for x in outcomes) else 'failed','inclusive_boundary':boundary,'cases':outcomes})
  result=subprocess.run([str(binary),'query','-n','--compact','--report=json','--division-scale','2','--rounding','half-even','--','1/8,3/8,-1/8'],capture_output=True,timeout=30)
  report=json.loads(result.stderr)
  needed={'kind','version','completed','inputRecords','outputResults','committedOutputResults','totalInputBytes','totalOutputBytes','totalWorkUnits','peakLogicalRetainedBytes','resolvedLimits','arithmeticPolicy','roundedDivisions','failure','remainingWorkUnits'}
  good=result.returncode==0 and needed<=report.keys() and report['arithmeticPolicy']=='half-even-scale-2' and report['roundedDivisions']==3 and report['outputResults']==3 and report['committedOutputResults']==3 and report['completed'] and report['failure'] is None
  rows.append({'id':'explicit-rounded-report','status':'passed' if good else 'failed','exit_code':result.returncode,'report':report})
  result=subprocess.run([str(binary),'query','-n','--diagnostics=json','--report=json','--','try (1e1000000+1) catch null'],capture_output=True,timeout=30)
  lines=[json.loads(line) for line in result.stderr.splitlines()]
  good=result.returncode==6 and not result.stdout and len(lines)==2 and lines[0]['metric']=='numberDigits' and lines[1]['completed'] is False and lines[1]['committedOutputResults']==0 and lines[1]['failure']['category']=='resource'
  rows.append({'id':'terminal-exact-report','status':'passed' if good else 'failed','exit_code':result.returncode,'records':lines})
 receipt={'schema_version':1,'status':'passed' if all(r['status']=='passed' for r in rows) else 'failed','observed':len(rows),'passed':sum(r['status']=='passed' for r in rows),'failed':sum(r['status']=='failed' for r in rows),'metrics':len([r for r in rows if 'metric'in r]),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'cases':rows}
 path=ROOT/a.output;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k!='cases'}));return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
