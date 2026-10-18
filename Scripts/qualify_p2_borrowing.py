#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""NAV9 D0: original-meter comparison runtime and full ownership codegen proof."""
import argparse,hashlib,json,pathlib,re,subprocess
from archive_candidate import files
from qualify_release_1_1 import checkout_head
ROOT=pathlib.Path(__file__).resolve().parents[1]
POSITIVE=r'''import Foundation
import Synchronization
import JSON
import JSONNavigation
final class Trace: Sendable {
 struct State { var active=false; var calls=0 }
 let state=Mutex(State())
 func activate() { state.withLock { $0.active=true } }
 func step() -> Bool { state.withLock { s in guard s.active else { return false }; s.calls += 1; return s.calls == 64 } }
}
struct Probe: JSONTraversalOwnedReducer {
 enum Mode { case noop, compare, caughtType, caughtWork }
 let mode:Mode
 var trace:Trace?=nil
 var outcome=false, finished=false
 mutating func observe(_ hit:JSONTraversalHit,value:JSON,context:inout JSONTraversalContext) throws -> JSONTraversalAction {
  switch mode {
  case .noop: break
  case .compare: trace?.activate(); outcome=try context.equalArrayElements(at:hit.absoluteLocation,lhs:0,rhs:1)
  case .caughtType: do { _=try context.equalArrayElements(at:[.index(0)],lhs:0,rhs:0) } catch { }
  case .caughtWork: do { try context.work(100_000_000) } catch { }
  }
  return .skipDescendants
 }
 mutating func finish(_ summary:JSONTraversalSummary,context:inout JSONTraversalContext) throws -> Bool { finished=true; return outcome }
}
@main struct P2BorrowProbe {
 static func check(_ value:Bool) { precondition(value) }
 static func report(_ name:String) { print("P2_BORROW_CHECK \(name) passed") }
 static func main() async throws {
  let fixtures=[#"[0.1,0.10]"#,#"[9007199254740993,9007199254740992]"#,#"[{"a":1,"b":2},{"b":2,"a":1}]"#,#"["é","e\u0301"]"#,#"[{"é":1},{"e\u0301":1}]"#,#"[[1,2],[2,1]]"#,"[null,null]","[true,1]"]
  for text in fixtures {
   let value=try JSONParser().parse(text), document=JSONDocument(root:value)
   guard case .array(let values)=value else { preconditionFailure() }
   var no=Probe(mode:.noop),yes=Probe(mode:.compare)
   let baseline=try JSONTraversal(document:document).inspectOwned(options:.init(depthLimit:0),reducer:&no)
   let result=try JSONTraversal(document:document).inspectOwned(options:.init(depthLimit:0),reducer:&yes)
   let expected=try JSONComparison.equals(values[0],values[1])
   check(result.result==expected && result.statistics[.nodes]==baseline.statistics[.nodes])
   check(result.statistics[.retainedBytes]==0 && baseline.statistics[.retainedBytes]==0)
   var meter=try JSONWorkMeter(limits:.balanced,domain:.core)
   _=try JSONComparison.equals(values[0],values[1],meter:&meter)
   check(result.statistics[.workUnits]-baseline.statistics[.workUnits]==3+meter.used(.workUnits))
  }
  report("delegate-differential")
  report("one-admission")
  report("exact-cumulative-delta")
  let document=JSONDocument(root:try JSONParser().parse("[0.1,0.10]"))
  var reducer=Probe(mode:.compare)
  let measured=try JSONTraversal(document:document).inspectOwned(options:.init(depthLimit:0),reducer:&reducer)
  var limits=JSONLimits.balanced;limits[.workUnits]=measured.statistics[.workUnits]
  reducer=Probe(mode:.compare)
  check(try JSONTraversal(document:document,limits:limits).inspectOwned(options:.init(depthLimit:0),reducer:&reducer).statistics[.workUnits]==limits[.workUnits])
  limits[.workUnits]-=1;reducer=Probe(mode:.compare)
  do { _=try JSONTraversal(document:document,limits:limits).inspectOwned(options:.init(depthLimit:0),reducer:&reducer);preconditionFailure() }
  catch let e as JSONFailure { check(e.resource?.metric == .workUnits) }
  report("inclusive-work")
  for mode in [Probe.Mode.caughtType,.caughtWork] {
   let cleared=Mutex(false)
   var walk=JSONTraversal(document:document)
   walk.lifetimeObserver={ a,b in cleared.withLock { $0=a && b } }
   var caught=Probe(mode:mode)
   do { _=try walk.inspectOwned(options:.init(depthLimit:0),reducer:&caught);preconditionFailure() }
   catch let e as JSONAccessFailure { check(mode == .caughtType && e.cause.code == .wrongKind && e.path == [.index(0)]) }
   catch let e as JSONFailure { check(mode == .caughtWork && e.resource?.metric == .workUnits) }
   check(!caught.finished && cleared.withLock { $0 })
  }
  report("terminal-failure")
  report("root-state-release")
  let trace=Trace(),cleared=Mutex(false)
  let text=String(repeating:"x",count:8192)
  let task=Task.detached {
   var limits=JSONLimits.balanced;limits[.cancellationQuantum]=1
   var walk=JSONTraversal(document:JSONDocument(root:.array([.string(text),.string(text)])),limits:limits)
   walk.checkpointObserver={ _ in if trace.step() { withUnsafeCurrentTask { $0?.cancel() } } }
   walk.lifetimeObserver={ a,b in cleared.withLock { $0=a && b } }
   var reducer=Probe(mode:.compare,trace:trace)
   return try walk.inspectOwned(options:.init(depthLimit:0),reducer:&reducer)
  }
  do { _=try await task.value;preconditionFailure() } catch is CancellationError { }
  check(trace.state.withLock { $0.calls>=64 } && cleared.withLock { $0 })
  report("inner-comparison-cancellation")
  print("P2_BORROW_RUNTIME passed cases=7")
 }
}
'''
NEGATIVES={
 'escape':("func illegal(_ c:inout JSONTraversalContext)->() throws -> Bool { { try c.equalArrayElements(at:[],lhs:0,rhs:0) } }","escaping closure captures 'inout' parameter",False),
 'send':("func illegal(_ c:inout JSONTraversalContext)->@Sendable () throws -> Bool { { try c.equalArrayElements(at:[],lhs:0,rhs:0) } }","capture of 'c' with non-Sendable type",False),
 'method':("func illegal(_ c:inout JSONTraversalContext)->([JSONLocationComponent],Int,Int) throws -> Bool { c.equalArrayElements }","cannot reference 'mutating' method as function value",False),
 'task':("func illegal(_ c:inout JSONTraversalContext) { _ = Task { try c.equalArrayElements(at:[],lhs:0,rhs:0) } }","escaping closure captures 'inout' parameter",False),
 'external':("func illegal(_ c:inout JSONTraversalContext) throws { _=try c.equalArrayElements(at:[],lhs:0,rhs:0) }","cannot find type 'JSONTraversalContext' in scope",True)
}
CHECKS={'delegate-differential','one-admission','exact-cumulative-delta','inclusive-work','terminal-failure','root-state-release','inner-comparison-cancellation'}
TARGET='JSONNavigation'
MODULES=['JSON','JSONNavigation']
CHECK_PREFIX='P2_BORROW_CHECK'
RUNTIME_LINE='P2_BORROW_RUNTIME passed cases=7'
SUMMARY='P2_BORROW_COMPILER {status} positive=2 negative=10 runtime_cases=7/config commands=20'
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True);args=parser.parse_args();out=ROOT/args.output;out.mkdir(parents=True,exist_ok=True)
 inputs=[{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
 receipt={'status':'running','source_head':checkout_head(ROOT),'source_inputs':inputs,'source_manifest_sha256':hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest(),'commands':[],'runtime_results':{},'policy':'Only same-ledger package delegate; compiler crash/unrelated diagnostic/empty runtime fails. Original 2-positive/20-negative proof remains separate and required.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,command,expected=None):
  try:p=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=1200);text=p.stdout+p.stderr;code=p.returncode
  except (OSError,subprocess.TimeoutExpired) as error:text=str(error);code=None
  diagnostics=re.findall(r': error: ([^\n]+)',text);crash=code is not None and code<0 or any(x in text for x in ['Stack dump:','Assertion failed','fatal error encountered during compilation','Found ownership error'])
  passed=not crash and (code==0 if expected is None else code is not None and code>0 and any(expected.lower() in d.lower() for d in diagnostics))
  log=out/(name+'.log');log.write_text(text.replace(str(ROOT),'.'))
  receipt['commands'].append({'name':name,'command':[c.replace(str(ROOT),'.') for c in command],'exit_code':code,'status':'passed' if passed else 'failed','expected_diagnostic':expected,'primary_diagnostics':diagnostics,'compiler_crash':crash,'log':log.relative_to(ROOT).as_posix(),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()});save()
  if not passed:raise ValueError(name)
  return p.stdout
 try:
  identity=re.sub(r'[^a-zA-Z0-9_]','_',ROOT.name.lower());identity='_'+identity if identity[0].isdigit() else identity
  source=out/'positive.swift';source.write_text(POSITIVE)
  for config in ['debug','release']:
   run(config+'-build',['swift','build','-c',config,'--target',TARGET,'-Xswiftc','-warnings-as-errors'])
   binpath=pathlib.Path(run(config+'-path',['swift','build','-c',config,'--show-bin-path']).strip());modules=binpath/'Modules' if (binpath/'Modules').is_dir() else binpath
   common=['swiftc','-swift-version','6','-warnings-as-errors','-I',str(modules),'-Onone' if config=='debug' else '-O','-parse-as-library']
   run(config+'-positive-codegen',common+['-package-name',identity,'-module-name','P2BorrowProbe','-c',str(source),'-o',str(out/(config+'-positive.o'))])
   for name,(body,diagnostic,external) in NEGATIVES.items():
    file=out/(name+'.swift');file.write_text(''.join('import '+m+'\n' for m in MODULES)+body+'\n')
    run(config+'-'+name,common+['-package-name','outside_p2_consumer' if external else identity,'-module-name','P2BorrowProbe','-c',str(file),'-o',str(out/(config+'-'+name+'.o'))],diagnostic)
   objects=[]
   for module in MODULES:
    aggregate=binpath/(module+'.o');selected=[aggregate] if aggregate.is_file() else sorted((binpath/(module+'.build')).glob('*.o'));assert selected,'Missing '+module+' objects';objects.extend(str(p) for p in selected)
   binary=out/(config+'-runtime');run(config+'-link',common+['-package-name',identity,str(source),*objects,'-o',str(binary)])
   text=run(config+'-runtime',[str(binary)]);cases=re.findall(r'^'+re.escape(CHECK_PREFIX)+r' (\S+) passed$',text,re.M)
   if len(cases)!=len(CHECKS) or set(cases)!=CHECKS or RUNTIME_LINE not in text.splitlines():raise ValueError('Runtime identity/count mismatch')
   receipt['runtime_results'][config]=cases;save()
  receipt['status']='passed'
 except (ValueError,AssertionError,OSError,subprocess.TimeoutExpired) as error:receipt.update(status='failed',error=str(error))
 save();print(SUMMARY.format(status=receipt['status']));return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
