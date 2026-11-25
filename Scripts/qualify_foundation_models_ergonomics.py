#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""JF4.1 native ergonomics and all earlier Foundation Models regression gates."""
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

spec=importlib.util.spec_from_file_location('jf33',Path(__file__).with_name('qualify_foundation_models_structural.py'))
jf33=importlib.util.module_from_spec(spec); spec.loader.exec_module(jf33)
prior=jf33.prior
need,strict,same=prior.need,prior.strict,prior.same
BASE='7f63b2c38a578b1fd8c49bb64c95a4d7c98bb3f0'
SOURCE=prior.SOURCE
JF4=Path('Tools/FoundationModelsSpike/JF4')
ALLOWED={str(JF4/n) for n in ('PreparedGeneration.swift','ArgumentBoundaryTests.swift','DeveloperExperienceTests.swift')} | {
    'Tools/FoundationModelsSpike/JF2/ValueBridge.swift',
    'Scripts/qualify_foundation_models_ergonomics.py','Scripts/test_foundation_models_ergonomics.py',
    'Documentation/Architecture/FoundationModels/JF4.1.md',
    'Documentation/Architecture/FoundationModels/JF4.1-NativeReview.md'}
TESTS=('jf4ValidatedExportBeforeForeignCallback','jf4ValidatedImportRejectsInvalidIncompleteMalformed',
       'jf4TypedRoundtripAndValidationOrdering','jf4RejectsChangedTypedValuesEvenIfValid',
       'jf4EncodeValidatesTypedRepresentation','jf4SchemaValidDoesNotWaiveValueFidelity',
       'jf4CumulativeTypedBudgetBoundary','jf4CancellationAfterTypedCallback',
       'jf4AppleTypedPublicRoundtrip','jf4AppleValidationPrecedesTypedConversion',
       'jf4AppleDSLPreparedGeneration','jf4AppleSchemaValidButUnrepresentableValue')
TYPED={'absent':'{"query":"Swift","limit":2,"sort":"date","tags":["a","b"]}',
       'present':'{"query":"Swift","limit":2,"sort":"date","tags":["a","b"],"note":"exact"}'}
def diagnostic(keyword, keyword_location, instance_location):
    return {'keyword':keyword,'keywordLocation':keyword_location,'instanceLocation':instance_location}


DIAGNOSTICS={'null-note':diagnostic('type','/properties/note/type','/note'),
             'range':diagnostic('maximum','/properties/limit/maximum','/limit'),
             'enum':diagnostic('enum','/properties/sort/enum','/sort'),
             'count':diagnostic('minItems','/properties/tags/minItems','/tags'),
             'required':diagnostic('required','/required',''),
             'unknown':diagnostic('','/additionalProperties','/extra')}
INVALID={(name,route):issue for name,issue in DIAGNOSTICS.items()
         for route in ('decodeJSON','decodeContent','export','import')}
INVALID[('range','encodeTyped')]=DIAGNOSTICS['range']
INVALID[('nested-required','dslExport')]=diagnostic('required','/properties/child/required','/child')


def verify(log,guided,positive,regression):
    names=prior.pass_set(log,TESTS)
    rows={k:[] for k in ('SCHEMA','TYPED','INVALID','DSL','NUMBER')}
    for line in log.splitlines():
        if line.startswith('JF4_'):
            kind,payload=line[4:].split(' ',1)
            need(kind in rows,'unknown JF4 receipt'); rows[kind].append(strict(payload))
    need(len(rows['SCHEMA'])==len(rows['DSL'])==len(rows['NUMBER'])==1,'missing/duplicate singleton receipts')
    schema=rows['SCHEMA'][0]
    expected_schema=strict(guided); expected_schema['title']='JF4SearchArguments'
    need(isinstance(schema,str) and same(strict(schema),expected_schema),'typed schema drift')
    typed=prior.keyed(rows['TYPED'],TYPED)
    for name,row in typed.items():
        need(set(row)=={'id','source','returned'} and same(strict(row['source']),strict(TYPED[name])) and same(strict(row['returned']),strict(TYPED[name])),name+': typed fidelity drift')
    invalid={}
    for row in rows['INVALID']:
        need(isinstance(row,dict) and set(row)=={'id','route','issues'},'invalid receipt shape')
        key=(row['id'],row['route'])
        need(key in INVALID and key not in invalid,'unknown/duplicate invalid receipt')
        issues=row['issues']
        need(same(issues,[INVALID[key]]),'missing or changed intended diagnostic')
        invalid[key]=row
    need(set(invalid)==set(INVALID),'missing invalid receipts')
    dsl=rows['DSL'][0]; nested=regression['reverse']['nested']['raw']
    need(isinstance(dsl,dict) and set(dsl)=={'canonical','projected','returned'},'DSL receipt shape')
    need(same(strict(dsl['canonical']),strict(positive['nested']['schema'])),'DSL canonical drift')
    need(same(strict(dsl['projected']),strict(nested['schema'])),'DSL actual projection drift')
    need(same(strict(dsl['returned']),strict('{"child":{"name":"Swift"}}')),'DSL value drift')
    number=rows['NUMBER'][0]
    need(number=={'accepted':'9007199254740992','rejected':'9007199254740993','issue':'changedValue'},'number fidelity drift')
    return {'tests':names,'schema':schema,'typed':typed,'invalid':sorted(invalid.values(),key=lambda r:(r['id'],r['route'])),'dsl':dsl,'number':number}


def stable(a,b):
    need(same(strict(a['schema']),strict(b['schema'])),'typed schema mode drift')
    for name,row in a['typed'].items():
        need(same(strict(row['returned']),strict(b['typed'][name]['returned'])),'typed value mode drift')
    for key in a['dsl']: need(same(strict(a['dsl'][key]),strict(b['dsl'][key])),'DSL mode drift')
    need(a['number']==b['number'],'numeric mode drift')
    for x,y in zip(a['invalid'],b['invalid']):
        need(x['id']==y['id'] and x['route']==y['route'] and same(x['issues'],y['issues']),'diagnostic mode drift')


def qualify(root,work,out,args):
    jf3=prior.load(root/'Scripts/qualify_foundation_models_schemas.py','jf3'); jf2=prior.load(root/'Scripts/qualify_foundation_models_values.py','jf2')
    fidelity=prior.load(root/'Scripts/qualify_foundation_models_fidelity.py','jf22'); jf1=jf2.jf1
    need(re.fullmatch('[0-9a-f]{40}',args.sha) and jf1.capture(root,'git','rev-parse','HEAD')==args.sha,'source SHA mismatch')
    need(not jf1.capture(root,'git','status','--porcelain'),'use a clean checkout')
    need(jf1.capture(root,'git','hash-object','Package.swift')==jf1.MANIFEST_BLOB,'manifest drift')
    need(set(jf1.capture(root,'git','diff','--name-only',BASE,args.sha).splitlines())==ALLOWED,'unexpected JF4 delta')
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
    for src in (root/'Tools/FoundationModelsSpike/JF2/ValueBridge.swift',root/SOURCE/'SchemaBridge.swift',root/SOURCE/'StructuralProof.swift',root/JF4/'PreparedGeneration.swift'): shutil.copyfile(src,target/src.name)
    for src in (root/'Tools/FoundationModelsSpike/JF2/ValueBridgeTests.swift',root/'Tools/FoundationModelsSpike/JF2/FidelityTests.swift',root/SOURCE/'SchemaBridgeTests.swift',root/prior.NEW_TEST,root/prior.FIXTURES,root/SOURCE/'StructuralProofTests.swift',root/JF4/'ArgumentBoundaryTests.swift',root/JF4/'DeveloperExperienceTests.swift'): shutil.copyfile(src,tests/src.name)
    after=json.loads(jf1.run(package,out,'candidate-manifest','swift','package','dump-package')); normalized=copy.deepcopy(after)
    test=[t for t in normalized['targets'] if t['name']==jf2.TEST_TARGET]; need(len(test)==1,'test target missing')
    test=test[0]; need(test['resources']==[{'path':'ReverseMatrix.json','rule':{'copy':{}}}],'resource delta'); test['resources']=[]
    deps=test['dependencies']; schema=[d for d in deps if d.get('byName')==['JSONSchema',None]]
    dsl=[d for d in deps if d.get('byName')==['JSONSchemaDSL',None]]
    need(len(deps)==4 and len(schema)==1 and len(dsl)==1,'test dependency delta'); deps.remove(schema[0]); deps.remove(dsl[0]); jf2.inspect_manifests(before,normalized)
    ergonomics={}; structural={}; matrices={}; schemas={}; values={}
    for config in ('debug','release'):
        command=('swift','test','-c',config,'--jobs','2','--test-product',jf2.TEST_TARGET,'--disable-xctest','--no-parallel','--filter')
        matrices[config]=prior.verify(jf1.run(package,out,config+'-jf32-regression',*command,'jf32'),positive,outside)
        (out/'reverse-regressions.json').write_text(json.dumps(matrices,ensure_ascii=True,indent=2)+'\n')
        structural[config]=jf33.verify(jf1.run(package,out,config+'-jf33',*command,'jf33'),positive,outside,matrices[config])
        (out/'structural-matrix.json').write_text(json.dumps(structural,ensure_ascii=True,indent=2)+'\n')
        ergonomics[config]=verify(jf1.run(package,out,config+'-jf4',*command,'jf4'),jf3.GUIDED,positive,matrices[config])
        (out/'ergonomics.json').write_text(json.dumps(ergonomics,ensure_ascii=True,indent=2)+'\n')
        schemas[config]=jf3.verify(jf1.run(package,out,config+'-jf31-regression',*command,'jf3[A-Z]'),'apple',fidelity)
        (out/'schema-regressions.json').write_text(json.dumps(schemas,ensure_ascii=True,indent=2)+'\n')
        values[config]=fidelity.verify(jf1.run(package,out,config+'-jf22-regression',*command,'jf2'))
        (out/'value-regressions.json').write_text(json.dumps(values,ensure_ascii=True,indent=2)+'\n')
    stable(ergonomics['debug'],ergonomics['release']); jf33.stable(structural['debug'],structural['release']); prior.stable(matrices['debug'],matrices['release']); fidelity.stable(values['debug'],values['release'])
    for kind,raw in schemas['debug']['schemas'].items(): need(same(strict(raw),strict(schemas['release']['schemas'][kind])),'schema regression drift')
    need(jf1.capture(root,'git','rev-parse','HEAD')==args.sha and not jf1.capture(root,'git','status','--porcelain'),'source drift')


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('sha'); parser.add_argument('output_parent',type=Path)
    parser.add_argument('--min-free-gib',type=int,default=20); args=parser.parse_args(); need(args.min_free_gib>=1,'positive disk preflight')
    root=Path(__file__).resolve().parents[1]; parent=args.output_parent.expanduser().resolve(); need(parent!=root and root not in parent.parents,'output must be outside checkout')
    os.umask(0o077); parent.mkdir(parents=True,exist_ok=True); work=Path(tempfile.mkdtemp(prefix='jf4-',dir=parent)); out=work/'evidence'; out.mkdir()
    outcome='FAILED_OR_INCOMPLETE'
    try: qualify(root,work,out,args); outcome='APPLE_ERGONOMICS_CANDIDATE_PASS'
    except (Exception,KeyboardInterrupt) as error:
        (out/'failure.txt').write_text(f'{type(error).__name__}: {error}\n'); print('JF4.1 failed:',error,file=sys.stderr)
    finally:
        (out/'decision.json').write_text(json.dumps({'outcome':outcome,'product_admission':'NOT_ADMITTED'},indent=2)+'\n')
        with tarfile.open(str(work)+'.tar.gz','w:gz') as archive: archive.add(out,arcname='evidence')
        print(f'ARCHIVE: {work}.tar.gz ({outcome})',flush=True); print(f'Disposable workspace retained: {work}',flush=True)
    return int(outcome=='FAILED_OR_INCOMPLETE')


if __name__=='__main__': sys.exit(main())
