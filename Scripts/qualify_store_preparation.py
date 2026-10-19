#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Full-codegen prepared-capability ownership matrix. No store engine."""
import argparse,hashlib,json,pathlib,re,subprocess
from archive_candidate import files
ROOT=pathlib.Path(__file__).resolve().parents[1]
POSITIVE="""import JSON
import JSONNavigation
struct P: JSONReadPreparation, JSONTraversalOwnedReducer {
 mutating func prepare(context: inout JSONReadPreparationContext) throws {
  try context.admitText("profile"); try context.work(7)
  let same = try context.equalStrings("é", "é"); precondition(same)
 }
 mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction { try context.work(); return .continue }
 mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> JSONDocument { try context.transferDocumentOwnership() }
}
func legal(_ d: JSONDocument) throws -> JSONOperationReport<JSONDocument> {
 var reducer=P(); return try JSONTraversal(document:d).inspectPreparedOwned(reducer:&reducer)
}
"""
PROBES={
 'positive':(POSITIVE,None),
 'return':('func illegal(_ c: inout JSONReadPreparationContext) -> JSONReadPreparationContext { consume c }','missing reinitialization of inout parameter'),
 'escape':('func illegal(_ c: inout JSONReadPreparationContext) -> () throws -> Void { { try c.checkpoint() } }',"escaping closure captures 'inout' parameter"),
 'explicit-capture':('func illegal(_ c: inout JSONReadPreparationContext) -> () -> Void { { [c = consume c] in _ = consume c } }', 'missing reinitialization of inout parameter'),
 'sendable':('func illegal(_ c: inout JSONReadPreparationContext) -> @Sendable () throws -> Void { { try c.checkpoint() } }',"capture of 'c' with non-Sendable type"),
 'task':('func illegal(_ c: inout JSONReadPreparationContext) { _ = Task { try c.checkpoint() } }',"escaping closure captures 'inout' parameter"),
 'task-detached':('func illegal(_ c: inout JSONReadPreparationContext) { _ = Task.detached { try c.checkpoint() } }',"escaping closure captures 'inout' parameter"),
 'store':('final class Box { var c: JSONReadPreparationContext? }; func illegal(_ c: inout JSONReadPreparationContext) -> Box { let b=Box(); b.c=consume c; return b }','missing reinitialization of inout parameter'),
 'global':('@MainActor var saved: JSONReadPreparationContext?; @MainActor func illegal(_ c: inout JSONReadPreparationContext) { saved=consume c }','missing reinitialization of inout parameter'),
 'bound-method':('func illegal(_ c: inout JSONReadPreparationContext) -> () throws -> Void { c.checkpoint }',"cannot reference 'mutating' method as function value"),
 'copy':('func illegal(_ c: inout JSONReadPreparationContext) { let a=copy c; _=a }',"'copy' cannot be applied to noncopyable types"),
 'consume':('func take(_ c: consuming JSONReadPreparationContext) {}\nfunc illegal(_ c: inout JSONReadPreparationContext) { take(consume c) }','missing reinitialization of inout parameter'),
 'forge':('func illegal() throws { let s=try JSONReadScope(preparingWith:.balanced); _=JSONReadPreparationContext(scope:s) }','initializer is inaccessible'),
 'state':('func illegal(_ c: inout JSONReadPreparationContext) { _=c.scope }',"'scope' is inaccessible"),
 'select':('func illegal(_ c: inout JSONReadPreparationContext) throws { _=try c.select([]) }',"has no member 'select'"),
 'span':('func illegal(_ c: inout JSONReadPreparationContext) throws { _=try c.sourceSpan(at:[]) }',"has no member 'sourceSpan'"),
 'complete':('func illegal(_ c: inout JSONReadPreparationContext) throws { _=try c.complete(0) }',"has no member 'complete'"),
 'transfer':('func illegal(_ c: inout JSONReadPreparationContext) throws { _=try c.transferDocumentOwnership() }',"has no member 'transferDocumentOwnership'"),
 'external':('func illegal(_ c: inout JSONReadPreparationContext) throws { try c.checkpoint() }',"cannot find type 'JSONReadPreparationContext' in scope"),
}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);args=ap.parse_args();out=pathlib.Path(args.output)
 if not out.is_absolute():out=ROOT/out
 out.mkdir(parents=True,exist_ok=True)
 receipt={'status':'running','source_inputs':[{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()],'commands':[]}
 def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,expected=None):
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=900);data=p.stdout+p.stderr
  crash=p.returncode<0 or any(x in data for x in ['Stack dump:','Assertion failed','Found ownership error','fatal error encountered during compilation'])
  diagnostics=re.findall(r': error: ([^\n]+)',data)
  patterns=expected if isinstance(expected,list) else [expected]
  ok=not crash and (p.returncode==0 if expected is None else p.returncode>0 and any(e.lower() in d.lower() for e in patterns for d in diagnostics))
  log=out/(name+'.log');log.write_text(data)
  receipt['commands'].append({'name':name,'command':cmd,'exit':p.returncode,'passed':ok,'compiler_crash':crash,'expected':expected,'primary_diagnostics':diagnostics,'log':str(log),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()});save()
  print(name,p.returncode,'PASS' if ok else 'BLOCKED',flush=True)
  if not ok:raise ValueError('D0 blocked: '+name)
  return p.stdout
 try:
  identity=re.sub('[^a-zA-Z0-9_]','_',ROOT.name.lower())
  if identity[0].isdigit():identity='_'+identity
  for config in ['debug','release']:
   run(config+'-build',['swift','build','-c',config,'--target','JSONInspection','--jobs','2'])
   bp=pathlib.Path(run(config+'-binpath',['swift','build','-c',config,'--show-bin-path']).strip());mods=bp/'Modules' if (bp/'Modules').exists() else bp
   for name,(body,expected) in PROBES.items():
    source=out/(name+'.swift');source.write_text(body if name=='positive' else 'import JSON\nimport JSONNavigation\n'+body+'\n')
    cmd=['swiftc','-swift-version','6','-warnings-as-errors','-package-name','outside_consumer' if name=='external' else identity,'-module-name','StorePreparationProbe','-I',str(mods),'-Onone' if config=='debug' else '-O','-parse-as-library','-c',str(source),'-o',str(out/(config+'-'+name+'.o'))]
    run(config+'-'+name,cmd,expected)
  receipt['status']='passed'
 except (ValueError,OSError,subprocess.TimeoutExpired) as error:receipt.update(status='blocked',error=str(error))
 save();print('STORE_PREPARATION_CODEGEN '+receipt['status']);return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
