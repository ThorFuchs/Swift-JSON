#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""JF3.3 structural proof qualification; historical runners stay immutable."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from urllib.parse import unquote_to_bytes
import importlib.util
spec = importlib.util.spec_from_file_location("jf32", Path(__file__).with_name("qualify_foundation_models_reverse_matrix.py"))
prior = importlib.util.module_from_spec(spec); spec.loader.exec_module(prior)

BASE = 'e9f401e5f428740346ddf6d0c44d69a61aa50073'
SOURCE = prior.SOURCE
ALLOWED = {str(SOURCE / n) for n in ('SchemaBridge.swift', 'StructuralProof.swift', 'StructuralProofTests.swift')} | {
    'Scripts/qualify_foundation_models_structural.py', 'Scripts/test_foundation_models_structural.py',
    'Documentation/Architecture/FoundationModels/JF3.3.md',
    'Documentation/Architecture/FoundationModels/JF3.3-NativeReview.md'}
TESTS = ('jf33PairedProofAndCanonicalAuthority', 'jf33ReferenceGrammarAndEscaping',
         'jf33RejectsSiblingScopesAndUnusedDefinitions', 'jf33RejectsCyclesAndProvesEachSharedUse',
         'jf33RequiredIsSetButGuidanceIsOrdered', 'jf33NeverHidesNumericOrMetadataLoss',
         'jf33CumulativeBudgetBoundary', 'jf33CancellationDuringProof',
         'jf33AppleStructuralMatrix', 'jf33AppleOutsideProfile')
REWRITES = {
    'nested': [('localReference', ('properties', 'child'), 'Child')],
    'nested-generated': [('localReference', ('properties', 'child'), 'properties.child')],
    'object-array': [('localReference', ('properties', 'rows', 'items'), 'Row')],
    'required-order': [('requiredPermutation', ('required',), None)],
}
ADDITIONS = {'simple': {('title',), ('x-order',)}, 'nested-generated': {
    ('title',), ('x-order',), ('properties','child','title'), ('properties','child','x-order')}}
need, strict, same = prior.need, prior.strict, prior.same


def token(fragment):
    need(isinstance(fragment,str) and fragment.startswith('#') and not re.search(r'%(?![0-9a-fA-F]{2})',fragment), 'invalid local fragment')
    parts = unquote_to_bytes(fragment[1:]).decode('utf-8').split('/')
    need(len(parts)==3 and parts[0]=='' and parts[1]=='$defs', 'not a direct root definition')
    need(not re.search(r'~(?![01])',parts[2]), 'invalid pointer escape')
    return parts[2].replace('~1','/').replace('~0','~')


def independent_delta(source, raw):
    """Fixed-corpus replay only, using small bounded expansion independently of Swift's paired proof."""
    need(prior.profile(source) and isinstance(raw,dict), 'source/root profile')
    defs = raw.get('$defs',{})
    need(isinstance(defs,dict) and len(defs)<=128 and ('$defs' not in raw or bool(defs)), 'definition table')
    used=set(); rewrites=[]; visits=0
    def expand(node, path=(), active=(), root=False, depth=1):
        nonlocal visits
        visits+=1; need(visits<=10000 and depth<=16 and isinstance(node,dict),'expansion limit/shape')
        if '$ref' in node:
            need(not root and set(node)=={'$ref'}, 'reference siblings or root')
            key=token(node['$ref']); need(key in defs and key not in active, 'dangling/cyclic reference')
            target=defs[key]; need(isinstance(target,dict) and target.get('type')=='object' and '$ref' not in target,'not concrete object definition')
            used.add(key); rewrites.append(('localReference',path,key))
            return expand(target,path,active+(key,),False,depth)
        need(root or '$defs' not in node, 'nested definitions')
        result={}
        for key,value in node.items():
            if root and key=='$defs': continue
            if key=='properties':
                need(isinstance(value,dict),'properties shape')
                result[key]={k:expand(v,path+(key,k),active,False,depth+1) for k,v in value.items()}
            elif key=='items': result[key]=expand(value,path+(key,),active,False,depth+1)
            else: result[key]=value
        return result
    expanded=expand(raw,root=True)
    need(used==set(defs),'unused definition')
    need(prior.profile(expanded),'expanded shape outside profile')
    def required(a,b,path=()):
        if not isinstance(a,dict) or not isinstance(b,dict): return
        if 'required' in a and 'required' in b and not same(a['required'],b['required']):
            if len(a['required'])==len(b['required']) and set(a['required'])==set(b['required']):
                rewrites.append(('requiredPermutation',path+('required',),None)); b['required']=a['required']
        if isinstance(a.get('properties'),dict) and isinstance(b.get('properties'),dict):
            for k in a['properties'].keys() & b['properties'].keys(): required(a['properties'][k],b['properties'][k],path+('properties',k))
        if 'items' in a and 'items' in b: required(a['items'],b['items'],path+('items',))
    required(source,expanded)
    changes,additions=prior.delta(source,expanded)
    return changes,additions,rewrites


def verify(log, positive, outside, regression):
    names=prior.pass_set(log,TESTS)
    records={'MATRIX':[], 'OUTSIDE':[]}
    for line in log.splitlines():
        if line.startswith('JF33_'):
            kind,payload=line[5:].split(' ',1); need(kind in records,'unknown receipt'); records[kind].append(strict(payload))
    rows=prior.keyed(records['MATRIX'],positive); excluded=prior.keyed(records['OUTSIDE'],outside)
    for name,row in excluded.items():
        need(row=={'id':name,'outcome':'rejected','issue':outside[name]['issue'],'path':outside[name]['path']},name+': canonical preflight drift')
    old=regression['reverse']
    need(sum(r['exact']['outcome']=='accepted' for r in old.values())==13 and sum(r['optIn']['outcome']=='accepted' for r in old.values())==14,'historical policy acceptance drift')
    for name,row in rows.items():
        source=strict(positive[name]['schema']); expected=[c['valid'] for c in positive[name]['cases']]
        raw=old[name]['raw']; need(raw['outcome'] in ('returned','profileRejected'),name+': unexpected raw failure')
        changes,adds,rewrites=independent_delta(source,strict(raw['schema']))
        need(set(rewrites)==set(REWRITES.get(name,[])) and adds==ADDITIONS.get(name,set()),name+': structural anchor drift')
        if name=='precise-decimal-bound':
            need(changes=={('changedConstraint',('properties','n','minimum')),('changedConstraint',('properties','n','maximum'))},'decimal anchor drift')
            need(row=={'id':name,'outcome':'rejected','issue':'changedConstraint','path':['properties','n','minimum']},'decimal loss accepted or wrong diagnostic')
            continue
        need(not changes,name+': unproved constraint or metadata mutation')
        need(set(row)=={'id','outcome','schema','verdicts','additions','rewrites'} and row['outcome']=='accepted',name+': expected acceptance')
        need(same(strict(row['schema']),strict(raw['schema'])) and same(row['verdicts'],expected) and same(raw['verdicts'],expected),name+': returned schema/instance drift')
        paths=[tuple(p) for p in row['additions']]
        need(len(paths)==len(set(paths)) and set(paths)==adds,name+': annotation evidence drift')
        actual=[]
        for r in row['rewrites']:
            need(set(r)==({'kind','path','definition'} if r.get('kind')=='localReference' else {'kind','path'}),name+': rewrite shape')
            actual.append((r['kind'],tuple(r['path']),r.get('definition')))
        need(len(actual)==len(set(actual)) and set(actual)==set(rewrites),name+': rewrite evidence drift')
    return {'tests':names,'matrix':rows,'outside':excluded}


def stable(a,b):
    for name,row in a['matrix'].items():
        other=b['matrix'][name]
        if row['outcome']=='rejected': need(row==other,name+': rejection drift'); continue
        need(other['outcome']=='accepted' and same(strict(row['schema']),strict(other['schema'])) and same(row['verdicts'],other['verdicts']),name+': mode drift')
        need(set(map(tuple,row['additions']))==set(map(tuple,other['additions'])),name+': addition drift')
        def keys(r): return {(w['kind'],tuple(w['path']),w.get('definition')) for w in r['rewrites']}
        need(keys(row)==keys(other),name+': rewrite drift')


def qualify(root,work,out,args):
    jf3=prior.load(root/'Scripts/qualify_foundation_models_schemas.py','jf3'); jf2=prior.load(root/'Scripts/qualify_foundation_models_values.py','jf2')
    fidelity=prior.load(root/'Scripts/qualify_foundation_models_fidelity.py','jf22'); jf1=jf2.jf1
    need(re.fullmatch('[0-9a-f]{40}',args.sha) and jf1.capture(root,'git','rev-parse','HEAD')==args.sha,'source SHA mismatch')
    need(not jf1.capture(root,'git','status','--porcelain'),'use a clean checkout')
    need(jf1.capture(root,'git','hash-object','Package.swift')==jf1.MANIFEST_BLOB,'manifest drift')
    need(set(jf1.capture(root,'git','diff','--name-only',BASE,args.sha).splitlines())==ALLOWED,'unexpected JF3.3 delta')
    swift=jf1.capture(root,'swift','--version'); host=jf1.capture(root,'uname','-sm'); os_version=jf1.capture(root,'sw_vers','-productVersion')
    need(host=='Darwin arm64' and int(os_version.split('.')[0])>=27 and re.search(r'Swift version 6\.4\.2(?:\s|$)',swift),'native Swift 6.4.2 ARM64 macOS 27 required')
    sdk=jf1.capture(root,'xcrun','--sdk','macosx','--show-sdk-version'); need(sdk=='27.2','anchor SDK 27.2 required')
    need(shutil.disk_usage(work).free>=args.min_free_gib*1024**3,'insufficient workspace disk')
    positive,outside=prior.fixtures(root/prior.FIXTURES)
    (out/'provenance.json').write_text(json.dumps(dict(sha=args.sha,base=BASE,host=host,os=os_version,swift=swift,sdk=sdk,
        xcode=jf1.capture(root,'xcodebuild','-version'),manifest_blob=jf1.MANIFEST_BLOB,fixture_sha256=hashlib.sha256((root/prior.FIXTURES).read_bytes()).hexdigest()),indent=2)+'\n')
    package=work/'Swift-JSON'; package.mkdir(); archive=work/'source.tar'
    subprocess.run(['git','archive','--format=tar','--output='+str(archive),args.sha,'Package.swift','Sources','Tests'],cwd=root,check=True)
    subprocess.run(['tar','-xf',str(archive),'-C',str(package)],check=True); archive.unlink()
    before=json.loads(jf1.run(package,out,'baseline-manifest','swift','package','dump-package'))
    manifest=package/'Package.swift'; text=jf2.graft(manifest.read_text())
    anchor='.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONFoundationModels"])'
    need(text.count(anchor)==1,'unexpected graft anchor')
    manifest.write_text(text.replace(anchor,'.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONSchema", "JSONFoundationModels"], resources: [.copy("ReverseMatrix.json")])'))
    target=package/'Sources'/jf1.PRODUCT; target.mkdir(); tests=package/'Tests'/jf2.TEST_TARGET; tests.mkdir()
    for src in (root/'Tools/FoundationModelsSpike/JF2/ValueBridge.swift',root/SOURCE/'SchemaBridge.swift',root/SOURCE/'StructuralProof.swift'): shutil.copyfile(src,target/src.name)
    for src in (root/'Tools/FoundationModelsSpike/JF2/ValueBridgeTests.swift',root/'Tools/FoundationModelsSpike/JF2/FidelityTests.swift',root/SOURCE/'SchemaBridgeTests.swift',root/prior.NEW_TEST,root/prior.FIXTURES,root/SOURCE/'StructuralProofTests.swift'): shutil.copyfile(src,tests/src.name)
    after=json.loads(jf1.run(package,out,'candidate-manifest','swift','package','dump-package')); normalized=copy.deepcopy(after)
    test=[t for t in normalized['targets'] if t['name']==jf2.TEST_TARGET]; need(len(test)==1,'test target missing')
    test=test[0]; need(test['resources']==[{'path':'ReverseMatrix.json','rule':{'copy':{}}}],'resource delta'); test['resources']=[]
    deps=test['dependencies']; schema=[d for d in deps if d.get('byName')==['JSONSchema',None]]
    need(len(deps)==3 and len(schema)==1,'test dependency delta'); deps.remove(schema[0]); jf2.inspect_manifests(before,normalized)
    structural={}; matrices={}; schemas={}; values={}
    for config in ('debug','release'):
        command=('swift','test','-c',config,'--jobs','2','--test-product',jf2.TEST_TARGET,'--disable-xctest','--no-parallel','--filter')
        matrices[config]=prior.verify(jf1.run(package,out,config+'-jf32-regression',*command,'jf32'),positive,outside)
        (out/'reverse-regressions.json').write_text(json.dumps(matrices,ensure_ascii=True,indent=2)+'\n')
        structural[config]=verify(jf1.run(package,out,config+'-jf33',*command,'jf33'),positive,outside,matrices[config])
        (out/'structural-matrix.json').write_text(json.dumps(structural,ensure_ascii=True,indent=2)+'\n')
        schemas[config]=jf3.verify(jf1.run(package,out,config+'-jf31-regression',*command,'jf3[A-Z]'),'apple',fidelity)
        (out/'schema-regressions.json').write_text(json.dumps(schemas,ensure_ascii=True,indent=2)+'\n')
        values[config]=fidelity.verify(jf1.run(package,out,config+'-jf22-regression',*command,'jf2'))
        (out/'value-regressions.json').write_text(json.dumps(values,ensure_ascii=True,indent=2)+'\n')
    stable(structural['debug'],structural['release']); prior.stable(matrices['debug'],matrices['release']); fidelity.stable(values['debug'],values['release'])
    for kind,raw in schemas['debug']['schemas'].items(): need(same(strict(raw),strict(schemas['release']['schemas'][kind])),'schema regression drift')
    need(jf1.capture(root,'git','rev-parse','HEAD')==args.sha and not jf1.capture(root,'git','status','--porcelain'),'source drift')


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('sha'); parser.add_argument('output_parent',type=Path)
    parser.add_argument('--min-free-gib',type=int,default=20); args=parser.parse_args(); need(args.min_free_gib>=1,'positive disk preflight')
    root=Path(__file__).resolve().parents[1]; parent=args.output_parent.expanduser().resolve(); need(parent!=root and root not in parent.parents,'output must be outside checkout')
    os.umask(0o077); parent.mkdir(parents=True,exist_ok=True); work=Path(tempfile.mkdtemp(prefix='jf33-',dir=parent)); out=work/'evidence'; out.mkdir()
    outcome='FAILED_OR_INCOMPLETE'
    try: qualify(root,work,out,args); outcome='APPLE_STRUCTURAL_SCHEMA_PASS'
    except (Exception,KeyboardInterrupt) as error:
        (out/'failure.txt').write_text(f'{type(error).__name__}: {error}\n'); print('JF3.3 failed:',error,file=sys.stderr)
    finally:
        (out/'decision.json').write_text(json.dumps({'outcome':outcome,'product_admission':'NOT_ADMITTED'},indent=2)+'\n')
        with tarfile.open(str(work)+'.tar.gz','w:gz') as archive: archive.add(out,arcname='evidence')
        print(f'ARCHIVE: {work}.tar.gz ({outcome})',flush=True); print(f'Disposable workspace retained: {work}',flush=True)
    return int(outcome=='FAILED_OR_INCOMPLETE')


if __name__=='__main__': sys.exit(main())
