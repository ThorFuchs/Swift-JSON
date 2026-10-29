#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Actual package-private store consumer and ordinary full-codegen refusals."""
import argparse,hashlib,json,pathlib,re,subprocess
from archive_candidate import files
ROOT=pathlib.Path(__file__).resolve().parents[1]
CONSUMER=r'''import Foundation
import JSON
import JSONInspection
@main struct Main {
 static func main() throws {
  let doc=try JSONParser().parseDocument(Data(#"{"collections":{"users":[{"uuid":"é","friend":null},{"uuid":"e\u0301","friend":{"collection":"users","id":"é"}}]}}"#.utf8))
  let profile=JSONStoreProfile(version:.v1,collectionsAt:[.key("collections")],collections:[
   .init(name:"users",recordsAt:[.key("users")],idKey:"uuid",referenceFields:[.init(key:"friend",presence:.required,nullable:true)])],references:.strict(marker:.v1,validateTargets:true))
  let report=try JSONStoreBuilder(document:doc,profile:profile).build(),store=report.result
  precondition(store.recordCount==2 && store.references.count==2)
  if case .null=store.references[0].state {} else { preconditionFailure() }
  if case .link(let target)=store.references[1].state { precondition(target.row==0); let record=try store.record(at:target); precondition(record.id=="é") } else { preconditionFailure() }
  let other=try JSONStoreBuilder(document:doc,profile:profile).build().result
  do { _=try other.record(at:store.record(collection:0,row:0).position); preconditionFailure() }
  catch let e as JSONStoreFailure { precondition(e.code == .invalidPosition) }
  precondition(store.document.sourceBytes==doc.sourceBytes)
  precondition(report.statistics[.nodes]>0 && report.statistics[.workUnits]>0)
  print("STORE_PRIVATE_CONSUMER passed cases=6 work=\(report.statistics[.workUnits]) retained=\(report.statistics[.retainedBytes])")
 }
}
'''
PROBES={
 'D051':('func illegal() { _ = JSONStoreProfileVersion.v2 }',"has no member 'v2'"),
 'D053':('func illegal() { _ = JSONStoreReferenceField(key:"f",presence:.required,nullable:"yes") }',"cannot convert value of type 'String' to expected argument type 'Bool'"),
 'D069':('func illegal() { _ = JSONStoreProfile(version:.v1,collectionsAt:[],collections:[],references:.disabled,guessID:true) }',"extra argument 'guessID' in call"),
 'store-initializer':('func illegal() { _ = JSONConfiguredStore() }','initializer is inaccessible'),
 'position-forge':('func illegal() { _ = JSONStorePosition() }','initializer is inaccessible'),
 'external-scope':('func illegal(_ x: JSONReadScope) {}',"cannot find type 'JSONReadScope' in scope"),
 'bound-member':('import JSONNavigation\nfunc illegal(_ c: inout JSONTraversalContext) { _ = c.member }',"cannot reference 'mutating' method as function value"),
 'member-escape':('import JSONNavigation\nfunc illegal(_ c: inout JSONTraversalContext) -> () throws -> JSON? { { try c.member(.null,key:"x",at:[]) } }',"escaping closure captures 'inout' parameter"),
}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);args=ap.parse_args();out=ROOT/args.output;out.mkdir(parents=True,exist_ok=True)
 receipt={'status':'running','source_inputs':[{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()],'commands':[],'vector_compiler_results':[]}
 def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,expected=None):
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=900);data=p.stdout+p.stderr
  crash=p.returncode<0 or any(x in data for x in ['Stack dump:','Assertion failed','Found ownership error','fatal error encountered during compilation'])
  diagnostics=re.findall(r': error: ([^\n]+)',data)
  passed=not crash and (p.returncode==0 if expected is None else p.returncode>0 and any(expected.lower() in d.lower() for d in diagnostics))
  log=out/(name+'.log');log.write_text(data)
  receipt['commands'].append({'name':name,'command':cmd,'exit':p.returncode,'passed':passed,'compiler_crash':crash,'expected':expected,'primary_diagnostics':diagnostics,'log':str(log),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()});save()
  print(name,p.returncode,'PASS' if passed else 'FAIL',flush=True)
  if not passed:raise ValueError(name)
  return p.stdout
 try:
  identity=re.sub('[^a-zA-Z0-9_]','_',ROOT.name.lower())
  if identity[0].isdigit():identity='_'+identity
  for config in ['debug','release']:
   run(config+'-build',['swift','build','-c',config,'--target','JSONInspection','--jobs','2'])
   bp=pathlib.Path(run(config+'-binpath',['swift','build','-c',config,'--show-bin-path']).strip());mods=bp/'Modules' if (bp/'Modules').exists() else bp
   common=['swiftc','-swift-version','6','-warnings-as-errors','-I',str(mods),'-Onone' if config=='debug' else '-O','-parse-as-library']
   source=out/'consumer.swift';source.write_text(CONSUMER)
   run(config+'-positive',common+['-package-name',identity,'-c',str(source),'-o',str(out/(config+'-positive.o'))])
   objs=[]
   for module in ['JSON','JSONNavigation','JSONInspection']:
    aggregate=bp/(module+'.o');objs += [str(aggregate)] if aggregate.exists() else [str(p) for p in sorted((bp/(module+'.build')).glob('*.o'))]
   executable=out/('consumer-'+config)
   run(config+'-link',common+['-package-name',identity,str(source),*objs,'-o',str(executable)])
   text=run(config+'-run',[str(executable)])
   if len(re.findall(r'^STORE_PRIVATE_CONSUMER passed cases=6 work=[1-9]\d* retained=[1-9]\d*$',text,re.M))!=1:raise ValueError('Missing actual consumer outcomes')
   for name,(body,expected) in PROBES.items():
    source=out/(name+'.swift');source.write_text('import JSON\nimport JSONInspection\n'+body+'\n')
    cmd=common+['-package-name','outside_consumer' if name.startswith('external') else identity,'-c',str(source),'-o',str(out/(config+'-'+name+'.o'))]
    run(config+'-'+name,cmd,expected)
    if name.startswith('D'):receipt['vector_compiler_results'].append({'id':name,'configuration':config,'driver':'profile-schema/compiler-negative','passed':True,'log':str(out/(config+'-'+name+'.log'))})
  receipt['status']='passed'
 except (ValueError,OSError,subprocess.TimeoutExpired) as error:receipt.update(status='failed',error=str(error))
 save();return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
