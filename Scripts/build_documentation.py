#!/usr/bin/env python3
"""Compile public product catalogs with the native bundled DocC compiler."""
import hashlib,json,pathlib,shutil,subprocess,sys
from preflight import collect
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
 out=ROOT/'.build/handoff/docc';out.mkdir(parents=True,exist_ok=True)
 receipt={'schema_version':1,'environment':collect(),'status':'passed','products':[]}
 command=['swift','package','dump-symbol-graph','--minimum-access-level','public']
 with (out/'symbol-graph.log').open('w') as log:r=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=900)
 if r.returncode or receipt['environment']['status']!='passed':receipt['status']='failed'
 if receipt['status']=='passed':
  graphRoot=ROOT/'.build/out/symbolgraph'
  if not graphRoot.is_dir():raise RuntimeError('Native symbol graph output missing')
  for product in ['JSON','JSONSchema','JSONStreaming','JSONPatch']:
   graphs=out/'symbols'/product;graphs.mkdir(parents=True,exist_ok=True)
   selected=[];count=0
   for path in graphRoot.glob('*.symbols.json'):
    data=json.loads(path.read_text())
    if data.get('module',{}).get('name')==product:
     shutil.copyfile(path,graphs/path.name);selected.append(path.name);count+=len(data.get('symbols',[]))
   if count==0:raise RuntimeError('Zero public symbols: '+product)
   diagnostic=out/(product+'-diagnostics.json');logPath=out/(product+'.log')
   command=['xcrun','docc','convert',str(ROOT/'Sources'/product/'Documentation.docc'),'--additional-symbol-graph-dir',str(graphs),'--output-dir',str(out/(product+'.doccarchive')),'--fallback-bundle-identifier','org.swift-json.'+product,'--warnings-as-errors','--diagnostics-file',str(diagnostic)]
   with logPath.open('w') as log:r=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=180)
   entry={'product':product,'command':[arg.replace(str(ROOT),'.') for arg in command],'public_symbols':count,'graphs':selected,'exit_code':r.returncode,'log':str(logPath.relative_to(ROOT)),'log_sha256':hashlib.sha256(logPath.read_bytes()).hexdigest(),'diagnostics':json.loads(diagnostic.read_text()) if diagnostic.exists() else None}
   receipt['products'].append(entry)
   if r.returncode:receipt['status']='failed'
 (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2));return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':sys.exit(main())
