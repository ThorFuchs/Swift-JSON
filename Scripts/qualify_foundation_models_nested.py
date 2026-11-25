#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""JF4.2: nested native schema import and independent public SwiftPM consumer."""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

spec=importlib.util.spec_from_file_location('jf4',Path(__file__).with_name('qualify_foundation_models_ergonomics.py'))
jf4=importlib.util.module_from_spec(spec); spec.loader.exec_module(jf4)
jf33=jf4.jf33; prior=jf4.prior
need,strict,same=prior.need,prior.strict,prior.same
BASE='458f8900d8d3c1c58a8ec1bf4d076c2f7a38f708'
SOURCE=prior.SOURCE
JF4=jf4.JF4
EXAMPLE=JF4/'Consumer/Sources/JF42Consumer/NestedExample.swift'
ALLOWED={str(JF4/n) for n in ('PreparedGeneration.swift','LocalSchemaImport.swift','LocalSchemaImportTests.swift','NestedGenerableTests.swift',
    'Consumer/Package.swift','Consumer/Sources/JF42Consumer/NestedExample.swift','Consumer/Sources/JF42Consumer/Consumer.swift')} | {
    str(SOURCE/'SchemaBridge.swift'),'Scripts/qualify_foundation_models_nested.py','Scripts/test_foundation_models_nested.py',
    'Documentation/Architecture/FoundationModels/JF4.2.md'}
TESTS=('jf42CanonicalLocalGraph','jf42RejectReferenceShapes','jf42RejectCyclesScopesAndUnusedDefinitions',
       'jf42RejectUnqualifiedConstraintsAndDepth','jf42CumulativeImportBudget','jf42CancellationDuringLocalImport',
       'jf42AppleNestedRoundtrip','jf42AppleNestedValidation','jf42AppleActualReferenceImport')
FILTER=strict('{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":20}},"required":["query","limit"],"additionalProperties":false}')
CANONICAL={'type':'object','properties':{'primary':FILTER,'alternatives':{'type':'array','items':FILTER,'minItems':strict('2'),'maxItems':strict('2')},
    'fallback':FILTER},'required':['primary','alternatives'],'additionalProperties':False}
TYPED={'absent':'{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}]}',
       'present':'{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}],"fallback":{"query":"Docs","limit":3}}'}
INVALID={
    'primary-range':('maximum','/primary/limit'),
    'array-range':('minimum','/alternatives/1/limit'),
    'array-count':('minItems','/alternatives'),
    'fallback-null':('type','/fallback'),
    'extra':('','/primary/extra'),
    'required':('required','/primary'),
}
ROUTES=('decodeJSON','decodeContent','export','import')


def trace(raw, keyword, instance):
    """Independent exact keyword-location calculation for this bounded profile."""
    node=raw; result=[]
    def follow():
        nonlocal node
        if isinstance(node,dict) and '$ref' in node:
            result.append('$ref')
            node=raw['$defs'][jf33.token(node['$ref'])]
    for token in instance.split('/')[1:]:
        follow()
        if node.get('type')=='array':
            need(token.isascii() and token.isdecimal(),'invalid array instance location')
            result.append('items'); node=node['items']
        else:
            need(node.get('type')=='object','invalid object instance location')
            if token in node['properties']:
                result.extend(('properties',token)); node=node['properties'][token]
            else:
                result.append('additionalProperties'); node=node['additionalProperties']
    follow()
    if keyword:
        need(isinstance(node,dict) and keyword in node,'diagnostic keyword not in schema')
        result.append(keyword)
    else:
        need(node is False,'empty keyword is not a false subschema')
    return '/'+'/'.join(t.replace('~','~0').replace('/','~1') for t in result)


def verify_nested(schema, typed, invalid):
    need(isinstance(schema,str),'nested schema receipt shape')
    raw=strict(schema)
    changes,additions,rewrites=jf33.independent_delta(CANONICAL,raw)
    need(not changes,'nested type constraint/annotation drift')
    values=prior.keyed(typed,TYPED)
    for name,row in values.items():
        need(set(row)=={'id','source','returned'} and same(strict(row['source']),strict(TYPED[name]))
             and same(strict(row['returned']),strict(TYPED[name])),name+': typed fidelity drift')
    observed={}
    for row in invalid:
        need(isinstance(row,dict) and set(row)=={'id','route','issue'},'invalid receipt shape')
        key=(row['id'],row['route'])
        need(key[0] in INVALID and key[1] in ROUTES and key not in observed,'unknown/duplicate invalid route')
        keyword,instance=INVALID[key[0]]
        expected={'keyword':keyword,'keywordLocation':trace(raw,keyword,instance),'instanceLocation':instance}
        need(same(row['issue'],expected),'nested diagnostic drift: '+str(key))
        observed[key]=row
    need(set(observed)=={(name,route) for name in INVALID for route in ROUTES},'missing invalid route')
    return {'schema':schema,'typed':values,'invalid':sorted(observed.values(),key=lambda r:(r['id'],r['route'])),
            'localReferences':sum(k=='localReference' for k,_,_ in rewrites),
            'annotations':sorted([list(p) for p in additions])}


def verify(log, regression):
    names=prior.pass_set(log,TESTS)
    rows={k:[] for k in ('RAW','SCHEMA','TYPED','INVALID','IMPORTED')}
    for line in log.splitlines():
        if line.startswith('JF42_'):
            kind,payload=line[5:].split(' ',1)
            need(kind in rows,'unknown nested receipt'); rows[kind].append(strict(payload))
    need(len(rows['RAW'])==len(rows['SCHEMA'])==len(rows['IMPORTED'])==1,'missing/duplicate nested schema receipt')
    need(same(strict(rows['RAW'][0]),strict(rows['SCHEMA'][0])),'canonical import changed actual macro schema')
    result=verify_nested(rows['SCHEMA'][0],rows['TYPED'],rows['INVALID'])
    imported=rows['IMPORTED'][0]
    anchor=regression['reverse']['nested']['raw']['schema']
    need(same(strict(imported),strict(anchor)),'actual local reference import drift')
    need(isinstance(strict(imported).get('$defs'),dict),'missing imported reference graph')
    result.update(tests=names,imported=imported)
    return result


def verify_consumer(log, positive, regression):
    rows=[strict(l[len('JF42_CONSUMER '):]) for l in log.splitlines() if l.startswith('JF42_CONSUMER ')]
    need(len(rows)==1 and set(rows[0])=={'nested','canonical','projected','returned'},'consumer receipt shape')
    row=rows[0]; nested=row['nested']
    need(set(nested)=={'schema','typed','invalid'},'consumer nested receipt shape')
    result=verify_nested(nested['schema'],nested['typed'],nested['invalid'])
    need(same(strict(row['canonical']),strict(positive['simple']['schema'])),'consumer DSL source drift')
    need(same(strict(row['projected']),strict(regression['reverse']['simple']['raw']['schema'])),'consumer DSL projection drift')
    need(same(strict(row['returned']),strict('{"query":"Swift"}')),'consumer DSL value drift')
    return {'nested':result,'canonical':row['canonical'],'projected':row['projected'],'returned':row['returned']}


def stable(a,b):
    for key in ('schema','imported'):
        if key in a: need(same(strict(a[key]),strict(b[key])),'schema mode drift: '+key)
    for name,row in a['typed'].items():
        need(same(strict(row['returned']),strict(b['typed'][name]['returned'])),'nested value mode drift')
    need(same(a['invalid'],b['invalid']) and a['localReferences']==b['localReferences']
         and same(a['annotations'],b['annotations']),'nested diagnostic mode drift')


def stable_consumer(a,b):
    stable(a['nested'],b['nested'])
    for key in ('canonical','projected','returned'):
        need(same(strict(a[key]),strict(b[key])),'consumer mode drift: '+key)


def qualify(root,work,out,args):
    jf3=prior.load(root/'Scripts/qualify_foundation_models_schemas.py','jf3'); jf2=prior.load(root/'Scripts/qualify_foundation_models_values.py','jf2')
    fidelity=prior.load(root/'Scripts/qualify_foundation_models_fidelity.py','jf22'); jf1=jf2.jf1
    need(re.fullmatch('[0-9a-f]{40}',args.sha) and jf1.capture(root,'git','rev-parse','HEAD')==args.sha,'source SHA mismatch')
    need(not jf1.capture(root,'git','status','--porcelain'),'use a clean checkout')
    need(jf1.capture(root,'git','hash-object','Package.swift')==jf1.MANIFEST_BLOB,'manifest drift')
    need(set(jf1.capture(root,'git','diff','--name-only',BASE,args.sha).splitlines())==ALLOWED,'unexpected JF4.2 delta')
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
    manifest.write_text(text.replace(anchor,'.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONSchema", "JSONFoundationModels", "JSONSchemaDSL"], resources: [.copy("ReverseMatrix.json")])'))
    target=package/'Sources'/jf1.PRODUCT; target.mkdir(); tests=package/'Tests'/jf2.TEST_TARGET; tests.mkdir()
    for src in (root/'Tools/FoundationModelsSpike/JF2/ValueBridge.swift',root/SOURCE/'SchemaBridge.swift',root/SOURCE/'StructuralProof.swift',root/JF4/'PreparedGeneration.swift',root/JF4/'LocalSchemaImport.swift'): shutil.copyfile(src,target/src.name)
    for src in (root/'Tools/FoundationModelsSpike/JF2/ValueBridgeTests.swift',root/'Tools/FoundationModelsSpike/JF2/FidelityTests.swift',root/SOURCE/'SchemaBridgeTests.swift',root/prior.NEW_TEST,root/prior.FIXTURES,root/SOURCE/'StructuralProofTests.swift',root/JF4/'ArgumentBoundaryTests.swift',root/JF4/'DeveloperExperienceTests.swift',root/JF4/'LocalSchemaImportTests.swift',root/JF4/'NestedGenerableTests.swift',root/EXAMPLE): shutil.copyfile(src,tests/src.name)
    after=json.loads(jf1.run(package,out,'candidate-manifest','swift','package','dump-package')); normalized=copy.deepcopy(after)
    test=[t for t in normalized['targets'] if t['name']==jf2.TEST_TARGET]; need(len(test)==1,'test target missing')
    test=test[0]; need(test['resources']==[{'path':'ReverseMatrix.json','rule':{'copy':{}}}],'resource delta'); test['resources']=[]
    deps=test['dependencies']; schema=[d for d in deps if d.get('byName')==['JSONSchema',None]]
    dsl=[d for d in deps if d.get('byName')==['JSONSchemaDSL',None]]
    need(len(deps)==4 and len(schema)==1 and len(dsl)==1,'test dependency delta'); deps.remove(schema[0]); deps.remove(dsl[0]); jf2.inspect_manifests(before,normalized)
    consumer=work/'JF42Consumer'; shutil.copytree(root/JF4/'Consumer',consumer)
    nested={}; consumers={}; ergonomics={}; structural={}; matrices={}; schemas={}; values={}
    for config in ('debug','release'):
        command=('swift','test','-c',config,'--jobs','2','--test-product',jf2.TEST_TARGET,'--disable-xctest','--no-parallel','--filter')
        matrices[config]=prior.verify(jf1.run(package,out,config+'-jf32-regression',*command,'jf32'),positive,outside)
        (out/'reverse-regressions.json').write_text(json.dumps(matrices,ensure_ascii=True,indent=2)+'\n')
        structural[config]=jf33.verify(jf1.run(package,out,config+'-jf33',*command,'jf33'),positive,outside,matrices[config])
        (out/'structural-matrix.json').write_text(json.dumps(structural,ensure_ascii=True,indent=2)+'\n')
        ergonomics[config]=jf4.verify(jf1.run(package,out,config+'-jf41-regression',*command,'jf4[A-Z]'),jf3.GUIDED,positive,matrices[config])
        (out/'ergonomics.json').write_text(json.dumps(ergonomics,ensure_ascii=True,indent=2)+'\n')
        nested[config]=verify(jf1.run(package,out,config+'-jf42',*command,'jf42'),matrices[config])
        (out/'nested-typed.json').write_text(json.dumps(nested,ensure_ascii=True,indent=2)+'\n')
        jf1.run(consumer,out,config+'-consumer-build','swift','build','-c',config,'--jobs','2','--product','JF42Consumer')
        consumers[config]=verify_consumer(jf1.run(consumer,out,config+'-consumer-run','swift','run','-c',config,'--skip-build','JF42Consumer'),positive,matrices[config])
        (out/'external-consumer.json').write_text(json.dumps(consumers,ensure_ascii=True,indent=2)+'\n')
        schemas[config]=jf3.verify(jf1.run(package,out,config+'-jf31-regression',*command,'jf3[A-Z]'),'apple',fidelity)
        (out/'schema-regressions.json').write_text(json.dumps(schemas,ensure_ascii=True,indent=2)+'\n')
        values[config]=fidelity.verify(jf1.run(package,out,config+'-jf22-regression',*command,'jf2'))
        (out/'value-regressions.json').write_text(json.dumps(values,ensure_ascii=True,indent=2)+'\n')
    stable(nested['debug'],nested['release']); stable_consumer(consumers['debug'],consumers['release']); jf4.stable(ergonomics['debug'],ergonomics['release']); jf33.stable(structural['debug'],structural['release']); prior.stable(matrices['debug'],matrices['release']); fidelity.stable(values['debug'],values['release'])
    for kind,raw in schemas['debug']['schemas'].items(): need(same(strict(raw),strict(schemas['release']['schemas'][kind])),'schema regression drift')
    need(jf1.capture(root,'git','rev-parse','HEAD')==args.sha and not jf1.capture(root,'git','status','--porcelain'),'source drift')


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('sha'); parser.add_argument('output_parent',type=Path)
    parser.add_argument('--min-free-gib',type=int,default=20); args=parser.parse_args(); need(args.min_free_gib>=1,'positive disk preflight')
    root=Path(__file__).resolve().parents[1]; parent=args.output_parent.expanduser().resolve(); need(parent!=root and root not in parent.parents,'output must be outside checkout')
    os.umask(0o077); parent.mkdir(parents=True,exist_ok=True); work=Path(tempfile.mkdtemp(prefix='jf42-',dir=parent)); out=work/'evidence'; out.mkdir()
    outcome='FAILED_OR_INCOMPLETE'
    try: qualify(root,work,out,args); outcome='APPLE_NESTED_ERGONOMICS_CANDIDATE_PASS'
    except (Exception,KeyboardInterrupt) as error:
        (out/'failure.txt').write_text(f'{type(error).__name__}: {error}\n'); print('JF4.2 failed:',error,file=sys.stderr)
    finally:
        (out/'decision.json').write_text(json.dumps({'outcome':outcome,'product_admission':'NOT_ADMITTED'},indent=2)+'\n')
        with tarfile.open(str(work)+'.tar.gz','w:gz') as archive: archive.add(out,arcname='evidence')
        print(f'ARCHIVE: {work}.tar.gz ({outcome})',flush=True); print(f'Disposable workspace retained: {work}',flush=True)
    return int(outcome=='FAILED_OR_INCOMPLETE')


if __name__=='__main__': sys.exit(main())
