#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Experimental full-codegen capability lifetime matrix; a compiler crash fails."""
import argparse,hashlib,json,os,pathlib,re,subprocess,sys
from archive_candidate import files
from qualify_release_1_1 import checkout_head
ROOT=pathlib.Path(__file__).resolve().parents[1];W=ROOT
parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);args=parser.parse_args()
O=ROOT/args.output;O.mkdir(parents=True,exist_ok=True)
env=dict(os.environ)
identity=re.sub(r'[^a-zA-Z0-9_]', '_', ROOT.name.lower())
if not identity or identity[0].isdigit(): identity='_'+identity
positive='''import JSON
import JSONNavigation
struct Reducer: JSONTraversalOwnedReducer {
 mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction { try context.work(7); return .continue }
 mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> UInt64 { try context.work(11); return summary.visitedCount }
}
func probe(_ walk: JSONTraversal) throws -> UInt64 { var reducer = Reducer(); return try walk.inspectOwned(reducer: &reducer).result }
'''
probes={
 'positive':(positive,None),
 'return':('func illegal(_ context: inout JSONTraversalContext) -> JSONTraversalContext { consume context }','inout'),
 'escape':('func illegal(_ context: inout JSONTraversalContext) -> () throws -> Void { { try context.checkpoint() } }','escaping closure captures'),
 'send':('func illegal(_ context: inout JSONTraversalContext) -> @Sendable () throws -> Void { { try context.checkpoint() } }','Sendable'),
 'forge':('func illegal() throws { let scope = try JSONReadScope(.init(root: .null), limits: .balanced); _ = JSONTraversalContext(scope: scope) }','inaccessible'),
 'store':('final class Box { var value: JSONTraversalContext? }; func illegal(_ context: inout JSONTraversalContext) -> Box { let b = Box(); b.value = consume context; return b }','inout'),
 'method-reference':('func illegal(_ context: inout JSONTraversalContext) -> () throws -> Void { context.checkpoint }','mutating'),
 'task':('func illegal(_ context: inout JSONTraversalContext) { Task { try context.checkpoint() } }','inout'),
 'global':('@MainActor var saved: JSONTraversalContext?; @MainActor func illegal(_ context: inout JSONTraversalContext) { saved = consume context }','inout'),
 'copy':('func illegal(_ context: inout JSONTraversalContext) { let a = copy context; _ = a }','copy'),
 'external':('func illegal(_ context: inout JSONTraversalContext) throws { try context.checkpoint() }','cannot find'),
}
# A source archive is intentionally outside Git; a container may also refuse
# repository ownership. Never borrow a parent checkout or alter Git trust/config.
# Exact input hashes remain authoritative and every compiler case still executes.
head=checkout_head(ROOT)
working_diff=None
if head is not None:
 diff=subprocess.run(['git','diff','HEAD'],cwd=W,capture_output=True)
 if diff.returncode == 0: working_diff=hashlib.sha256(diff.stdout).hexdigest()
inputs=[{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]
r={'status':'running','source_head':head,'working_diff_sha256':working_diff,
   'git_identity_status':'available' if head is not None else 'unavailable_or_not_root_checkout',
   'provenance_policy':'Only this root checkout; unavailable Git identity is null, never a parent SHA or a weakened safe.directory setting.',
   'source_inputs':inputs,'source_manifest_sha256':hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest(),
   'commands':[]}
configs=['debug','release']
for config in configs:
 build=['swift','build','-c',config,'--target','JSONNavigation','-Xswiftc','-warnings-as-errors']
 p=subprocess.run(build,cwd=W,env=env,capture_output=True);(O/(config+'-build.log')).write_bytes(p.stdout+p.stderr)
 if p.returncode: raise SystemExit(p.returncode)
 for name,(source,expected) in probes.items():
  if name!='positive':source='import JSON\nimport JSONNavigation\n'+source+'\n'
  file=O/(name+'.swift');file.write_text(source)
  binpath=pathlib.Path(subprocess.check_output(['swift','build','-c',config,'--show-bin-path'],cwd=W,env=env,text=True).strip());mod=binpath/'Modules' if (binpath/'Modules').exists() else binpath;package='outside_consumer' if name=='external' else identity
  cmd=['swiftc','-swift-version','6','-warnings-as-errors','-package-name',package,'-module-name','ReducerOwnershipProbe','-I',str(mod),'-O' if config=='release' else '-Onone','-parse-as-library','-c',str(file),'-o',str(O/(config+'-'+name+'.o'))]
  p=subprocess.run(cmd,cwd=W,env=env,capture_output=True,timeout=60);data=p.stdout+p.stderr;log=O/(config+'-'+name+'.log');log.write_bytes(data)
  crash=p.returncode<0 or any(t in data for t in [b'Stack dump:',b'Assertion failed',b'fatal error encountered during compilation',b'Found ownership error'])
  passed=not crash and (p.returncode==0 if expected is None else p.returncode>0 and expected.lower().encode() in data.lower())
  r['commands'].append(dict(name=config+'-'+name,command=cmd,exit=p.returncode,source_sha256=hashlib.sha256(file.read_bytes()).hexdigest(),log=str(log.relative_to(ROOT)),log_sha256=hashlib.sha256(data).hexdigest(),compiler_crash=crash,expected=expected,status='passed' if passed else 'failed'))
  print(config,name,p.returncode,'PASS' if passed else 'FAIL',flush=True)
r['status']='passed' if all(c['status']=='passed' for c in r['commands']) else 'blocked'
(O/'receipt.json').write_text(json.dumps(r,indent=2)+'\n')

print("REDUCER_CODEGEN "+r["status"]+" positive=2 negative=20")
raise SystemExit(0 if r["status"]=="passed" else 1)
