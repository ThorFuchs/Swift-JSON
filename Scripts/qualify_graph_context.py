#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Code-generation and original-meter proof for the graph's exclusive delegates."""
import argparse, hashlib, json, pathlib, re, subprocess
from archive_candidate import files
ROOT=pathlib.Path(__file__).resolve().parents[1]
POSITIVE='''import JSON
import JSONNavigation
struct Probe: JSONTraversalOwnedReducer {
 var strings: [String] = []
 mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction {
  if hit.relativeDepth == 0 { _ = try context.arrayCount(value, at: hit.absoluteLocation); return .continue }
  let field = try context.directStringMember(value, key: "id", at: hit.absoluteLocation)
  precondition(field.kind == .string)
  if let text = field.text { let equal = try context.equalStrings(text, text); precondition(equal); strings.append(text) }
  return .skipDescendants
 }
 mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> Int {
  for text in strings { try context.releaseStringAlias(text) }
  try context.work(7); return strings.count
 }
}
@main struct Main {
 static func main() throws {
  let document = JSONDocument(root: try JSON.parse(#"{"n":[{"id":"é"}],"e":[{"id":"e\\u0301"}]}"#))
  let walk = JSONTraversal(document: document)
  let roots: JSONTraversalScope = .virtual(roots: [[.key("n")],[.key("e")]], overlap: .rejectAmbiguous)
  let base = try walk.visit(scope: roots, options: .init(depthLimit: 1)) { _,_ in .continue }
  var reducer = Probe()
  let owned = try walk.inspectOwned(scope: roots, options: .init(depthLimit: 1), reducer: &reducer)
  precondition(owned.result == 2)
  precondition(owned.statistics[.nodes] == base.statistics[.nodes])
  precondition(owned.statistics[.workUnits] > base.statistics[.workUnits])
  precondition(owned.statistics[.retainedBytes] == base.statistics[.retainedBytes])
  precondition(reducer.strings.count == 2)
  var exact = Probe(); var limits = JSONLimits.balanced
  limits[.workUnits] = owned.statistics[.workUnits]
  _ = try JSONTraversal(document: document, limits: limits).inspectOwned(scope: roots, options: .init(depthLimit: 1), reducer: &exact)
  limits[.workUnits] -= 1
  do { var short = Probe(); _ = try JSONTraversal(document: document, limits: limits).inspectOwned(scope: roots, options: .init(depthLimit: 1), reducer: &short); preconditionFailure() }
  catch let error as JSONFailure { precondition(error.category == .resource) }
  print("GRAPH_CONTEXT parity passed nodes=\\(owned.statistics[.nodes]) work=\\(owned.statistics[.workUnits]) retained=\\(owned.statistics[.retainedBytes])")
 }
}
'''
PROBES={
 'positive':(POSITIVE,None),
 'bound':('func f(_ c: inout JSONTraversalContext) { _ = c.directStringMember }', "cannot reference 'mutating' method as function value"),
 'escape':('func f(_ c: inout JSONTraversalContext) -> () throws -> Bool { { try c.equalStrings("a", "a") } }', "escaping closure captures 'inout' parameter"),
 'task':('func f(_ c: inout JSONTraversalContext) { _ = Task { try c.releaseStringAlias("a") } }', "escaping closure captures 'inout' parameter"),
 'store':('final class Box { var c: JSONTraversalContext? }; func f(_ c: inout JSONTraversalContext) -> Box { let b = Box(); b.c = consume c; return b }', 'missing reinitialization of inout parameter'),
}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);out=ROOT/ap.parse_args().output;out.mkdir(parents=True,exist_ok=True)
 receipt={'status':'running','source_inputs':[{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()],'commands':[]}
 def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,args,expected=None):
  p=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,timeout=900);data=p.stdout+p.stderr
  diagnostics=re.findall(r': error: ([^\n]+)',data);crash=p.returncode<0 or any(x in data for x in ['Stack dump:','Assertion failed','Found ownership error','fatal error encountered during compilation'])
  passed=not crash and (p.returncode==0 if expected is None else p.returncode>0 and any(expected.lower() in d.lower() for d in diagnostics))
  log=out/(name+'.log');log.write_text(data)
  receipt['commands'].append({'name':name,'command':args,'exit_code':p.returncode,'status':'passed' if passed else 'failed','expected_diagnostic':expected,'primary_diagnostics':diagnostics,'compiler_crash':crash,'log':log.relative_to(ROOT).as_posix(),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()});save()
  if not passed: raise ValueError(name)
  return p.stdout
 try:
  identity=re.sub('[^a-zA-Z0-9_]','_',ROOT.name.lower())
  if identity[0].isdigit():identity='_'+identity
  for config in ['debug','release']:
   run(config+'-build',['swift','build','-c',config,'--target','JSONNavigation'])
   bp=pathlib.Path(run(config+'-binpath',['swift','build','-c',config,'--show-bin-path']).strip());mods=bp/'Modules' if (bp/'Modules').is_dir() else bp
   common=['swiftc','-swift-version','6','-warnings-as-errors','-package-name',identity,'-I',str(mods),'-O' if config=='release' else '-Onone','-parse-as-library']
   for name,(body,expected) in PROBES.items():
    f=out/(name+'.swift');f.write_text(body if name=='positive' else 'import JSON\nimport JSONNavigation\n'+body+'\n')
    run(config+'-'+name,common+['-c',str(f),'-o',str(out/(config+'-'+name+'.o'))],expected)
   objects=[]
   for module in ['JSON','JSONNavigation']:
    aggregate=bp/(module+'.o');objects+= [str(aggregate)] if aggregate.exists() else [str(p) for p in sorted((bp/(module+'.build')).glob('*.o'))]
   exe=out/('parity-'+config);run(config+'-link',common+[str(out/'positive.swift'),*objects,'-o',str(exe)])
   output=run(config+'-run',[str(exe)])
   if len(re.findall(r'^GRAPH_CONTEXT parity passed nodes=\d+ work=\d+ retained=\d+$',output,re.M))!=1:raise ValueError('Missing parity witness')
  receipt['status']='passed'
 except (ValueError,OSError,subprocess.TimeoutExpired) as e:receipt.update(status='failed',error=str(e))
 save();print('GRAPH_CONTEXT '+receipt['status']+' positive=2 negative=8 runtime=2');return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
