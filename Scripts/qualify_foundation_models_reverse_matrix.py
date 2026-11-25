#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""JF3.2: actual Apple reverse-schema matrix with independent receipt checks."""
import argparse
import copy
from decimal import Decimal
import importlib.util
import json
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

BASE = '441d273380cf93da45c5150073bf1225f3e3e7dc'
SOURCE = Path('Tools/FoundationModelsSpike/JF3')
FIXTURES = SOURCE / 'ReverseMatrix.json'
NEW_TEST = SOURCE / 'ReverseMatrixTests.swift'
ALLOWED = {str(FIXTURES), str(NEW_TEST), 'Scripts/qualify_foundation_models_reverse_matrix.py',
           'Scripts/test_foundation_models_reverse_matrix.py', 'Documentation/Architecture/FoundationModels/JF3.2.md'}
TESTS = ('jf32CanonicalFixtures', 'jf32OutsideProfile', 'jf32AppleReverseMatrix', 'jf32ApplePreflightRejections')
REVERSE_IDS = ('simple', 'prepared', 'empty', 'nested', 'nested-generated', 'string-array', 'object-array',
               'nested-array', 'boolean', 'integer-range', 'large-integer-bound', 'int64-bound', 'number-range',
               'precise-decimal-bound', 'optional', 'enum', 'metadata-names', 'required-order', 'mixed')
OUTSIDE_IDS = ('nullable', 'open-object', 'pattern', 'composition', 'constant', 'definitions', 'format',
               'unknown-annotation', 'dialect', 'non-ascii-name', 'bad-x-order', 'boolean-root')
ANNOTATIONS = {'title', 'description', 'x-order'}


def need(ok, message):
    if not ok: raise ValueError(message)


def strict(text):
    def pairs(items):
        result = {}
        for k, v in items:
            need(k not in result, 'duplicate JSON key'); result[k] = v
        return result
    def invalid_constant(_): raise ValueError('non-JSON constant')
    return json.loads(text, parse_int=Decimal, parse_float=Decimal, parse_constant=invalid_constant, object_pairs_hook=pairs)


def same(a, b):
    if type(a) is not type(b): return False
    if isinstance(a, dict): return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, list): return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    return a == b


def keyed(rows, ids):
    result = {}
    for row in rows:
        need(isinstance(row, dict) and row.get('id') in ids and row['id'] not in result, 'unexpected/duplicate row')
        result[row['id']] = row
    need(set(result) == set(ids), 'missing row')
    return result


def fixtures(path):
    raw = strict(path.read_text())
    need(set(raw) == {'reverse', 'outside'}, 'fixture envelope')
    positive = keyed(raw['reverse'], REVERSE_IDS); outside = keyed(raw['outside'], OUTSIDE_IDS)
    count = 0
    for name, row in positive.items():
        need(set(row) == {'id', 'schema', 'cases'} | ({'anchor'} if name in ('simple','prepared') else set()), 'fixture shape')
        need(isinstance(strict(row['schema']), dict), 'expected object schema')
        cases = row['cases']; need(len({c['id'] for c in cases}) == len(cases), 'duplicate instance')
        need({c['valid'] for c in cases} == {True, False}, 'missing positive or negative instance')
        for c in cases:
            need(set(c) == {'id','source','valid'} and type(c['valid']) is bool, 'instance shape'); strict(c['source'])
        count += len(cases)
    need(count == 62 and positive['simple']['anchor'] == 'annotations' and positive['prepared']['anchor'] == 'exact', 'fixture cardinality/anchors')
    for row in outside.values():
        need(set(row) == {'id','schema','issue','path'} and row['issue'] in ('unsupportedShape','unsupportedDeclaration') and isinstance(row['path'],list), 'outside shape')
        strict(row['schema'])
    return positive, outside


def delta(a, b, path=()):
    """Compare only schema positions, never treat property names as annotations."""
    changes, additions = set(), set()
    for k, value in a.items():
        loc = path + (k,)
        reason = 'changedAnnotation' if k in ANNOTATIONS else 'changedConstraint'
        if k not in b: changes.add((reason, loc)); continue
        other = b[k]
        if k == 'properties':
            if len(value) != len(other): changes.add((reason, loc)); continue
            for prop, child in value.items():
                if prop not in other: changes.add((reason, loc + (prop,))); continue
                c, d = delta(child, other[prop], loc + (prop,)); changes |= c; additions |= d
        elif k == 'items':
            c, d = delta(value, other, loc); changes |= c; additions |= d
        elif not same(value, other): changes.add((reason, loc))
    for k in b.keys() - a.keys():
        loc = path + (k,)
        if k in ('title', 'x-order'): additions.add(loc)
        else: changes.add(('changedAnnotation' if k == 'description' else 'changedConstraint', loc))
    return changes, additions


def profile(raw, depth=1):
    # Independent conservative shape/keyword check, not a replacement for native compilation.
    if not isinstance(raw, dict) or depth > 16: return False
    t = raw.get('type')
    if t not in ('object','array','string','integer','number','boolean') or (depth == 1 and t != 'object'): return False
    allowed = {'type','title','description'} | ({'properties','required','additionalProperties','x-order'} if t=='object' else
              {'items','minItems','maxItems'} if t=='array' else {'enum'} if t=='string' else {'minimum','maximum'} if t in ('integer','number') else set())
    if not raw.keys() <= allowed or any(not isinstance(raw[k],str) for k in ('title','description') if k in raw): return False
    if t == 'object':
        p, r = raw.get('properties'), raw.get('required')
        if not isinstance(p,dict) or len(p)>128 or not isinstance(r,list) or raw.get('additionalProperties') is not False: return False
        if not all(isinstance(k,str) and k and k.isascii() for k in p): return False
        def names(v): return isinstance(v,list) and all(isinstance(k,str) and k in p for k in v) and len(v)==len(set(v))
        if not names(r): return False
        if 'x-order' in raw and (not names(raw['x-order']) or len(raw['x-order'])!=len(p)): return False
        return all(profile(x,depth+1) for x in p.values())
    if t=='array': return profile(raw.get('items'),depth+1)
    if 'enum' in raw: return isinstance(raw['enum'],list) and 0<len(raw['enum'])<=128 and all(isinstance(v,str) for v in raw['enum'])
    return True


def verify_attempt(attempt, raw, source, expected, allow, name):
    status = raw['outcome']; observed = attempt.get('outcome')
    if status in ('codecRejected','nativeInvalid'):
        need(attempt == {'outcome':status,'errorType':raw['errorType']}, name+': inconsistent operational rejection'); return
    if status == 'profileRejected':
        need(attempt == {k:raw[k] for k in ('outcome','issue','path')}, name+': inconsistent profile rejection'); return
    returned = strict(raw['schema']); changes, additions = delta(source, returned)
    errors = changes | (set() if allow else {('annotationAdditionDenied',p) for p in additions})
    if errors:
        need(set(attempt)=={'outcome','issue','path'} and observed=='profileRejected' and (attempt['issue'],tuple(attempt['path'])) in errors, name+': unsafe acceptance or wrong diagnostic')
    else:
        need(set(attempt)=={'outcome','schema','additions','verdicts'} and observed=='accepted', name+': expected successful projection')
        need(same(strict(attempt['schema']),returned) and same(attempt['verdicts'],expected) and same(raw['verdicts'],expected), name+': accepted output/validation drift')
        paths = [tuple(p) for p in attempt['additions']]
        need(len(paths)==len(set(paths)) and set(paths)==additions, name+': incorrect annotation additions')


def pass_set(log, expected):
    log = re.sub(r'\x1b\[[0-9;]*m', '', log)
    names = re.findall(r'^.*?\bTest (\w+)\(\) passed(?: after|$)', log, re.M)
    need(len(names) == len(expected) and set(names) == set(expected), 'incorrect test pass set')
    need(re.findall(r'Test run with (\d+) tests? in[^\n]*passed', log) == [str(len(expected))], 'incorrect test total')
    need(not re.search(r'\b(?:known issue|skipped|skipping)\b', '\n'.join(l for l in log.splitlines() if 'Test ' in l), re.I), 'skipped/known issue')
    return sorted(names)


def verify(log, positive, outside):
    names = pass_set(log, TESTS)
    records = {kind:[] for kind in ('REVERSE','RAW','PORTABLE_REJECT','APPLE_EXACT_REJECT','APPLE_OPTIN_REJECT')}
    for line in log.splitlines():
        if line.startswith('JF32_'):
            kind,payload = line[5:].split(' ',1); need(kind in records, 'unknown receipt'); records[kind].append(strict(payload))
    rows = keyed(records['REVERSE'], positive)
    raw_rows = keyed(records['RAW'], [n for n,r in rows.items() if 'schema' in r['raw']])
    for kind in ('PORTABLE_REJECT','APPLE_EXACT_REJECT','APPLE_OPTIN_REJECT'):
        rejects = keyed(records[kind],outside)
        for name,r in rejects.items(): need(r == {k:outside[name][k] for k in ('id','issue','path')}, name+': wrong preflight diagnostic')
    for name,row in rows.items():
        v=positive[name]; source=strict(v['schema']); expected=[c['valid'] for c in v['cases']]
        need(set(row)=={'id','source','canonical','raw','exact','optIn'} and same(strict(row['source']),source) and same(row['canonical'],expected), name+': canonical drift')
        need(profile(source), name+': fixture outside profile')
        raw=row['raw']; status=raw['outcome']
        if status=='codecRejected':
            need(set(raw)=={'outcome','errorType'} and isinstance(raw['errorType'],str) and (raw['errorType'] in ('Swift.DecodingError','Swift.EncodingError') or raw['errorType'].startswith('FoundationModels.')), name+': unexpected codec error')
        else:
            need(raw_rows[name]=={'id':name,'schema':raw['schema']}, name+': raw receipt mismatch')
            parsed=strict(raw['schema'])
            if status=='nativeInvalid': need(set(raw)=={'outcome','schema','errorType'} and raw['errorType'].endswith('.JSONSchemaCompilationFailure'), name+': native failure classification')
            elif status in ('returned','profileRejected'):
                fields={'outcome','schema','verdicts'} | ({'issue','path'} if status=='profileRejected' else set())
                need(set(raw)==fields and profile(parsed)==(status=='returned'), name+': profile disagreement')
                need(isinstance(raw['verdicts'],list) and len(raw['verdicts'])==len(expected) and all(type(b) is bool for b in raw['verdicts']), name+': raw verdict shape')
                if status=='profileRejected': need(raw['issue'] in ('unsupportedShape','unsupportedDeclaration') and isinstance(raw['path'],list), name+': invalid profile diagnosis')
            else: raise ValueError(name+': unknown raw status')
        for key,allow in [('exact',False),('optIn',True)]: verify_attempt(row[key],raw,source,expected,allow,name+'/'+key)
        if v.get('anchor')=='exact': need(row['exact']['outcome']==row['optIn']['outcome']=='accepted', 'prepared anchor drift')
        elif v.get('anchor')=='annotations': need(row['exact'].get('issue')=='annotationAdditionDenied' and row['optIn']['outcome']=='accepted', 'annotation anchor drift')
    return {'tests':names,'reverse':rows,'preflight':records['APPLE_EXACT_REJECT']}


def stable(a,b):
    for name,row in a['reverse'].items():
        other=b['reverse'][name]
        for key in ('raw','exact','optIn'):
            left,right=row[key],other[key]
            need(left['outcome']==right['outcome'] and left.get('verdicts')==right.get('verdicts'), name+': mode disposition drift')
            if 'schema' in left: need('schema' in right and same(strict(left['schema']),strict(right['schema'])), name+': mode schema drift')
            if 'additions' in left: need(set(map(tuple,left['additions']))==set(map(tuple,right.get('additions',[]))), name+': mode additions drift')
            # A different first path among independently valid deltas is not a semantic drift.
            if 'errorType' in left: need(left['errorType']==right.get('errorType'), name+': mode error drift')


def load(path,name):
    spec=importlib.util.spec_from_file_location(name,path); module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module); return module


def qualify(root,work,out,args):
    jf3=load(root/'Scripts/qualify_foundation_models_schemas.py','jf3'); jf2=load(root/'Scripts/qualify_foundation_models_values.py','jf2')
    fidelity=load(root/'Scripts/qualify_foundation_models_fidelity.py','jf22'); jf1=jf2.jf1
    need(re.fullmatch('[0-9a-f]{40}',args.sha) and jf1.capture(root,'git','rev-parse','HEAD')==args.sha,'source SHA mismatch')
    need(not jf1.capture(root,'git','status','--porcelain'),'use a clean checkout')
    need(jf1.capture(root,'git','hash-object','Package.swift')==jf1.MANIFEST_BLOB,'manifest drift')
    need(set(jf1.capture(root,'git','diff','--name-only',BASE,args.sha).splitlines())==ALLOWED,'unexpected JF3.2 delta')
    swift=jf1.capture(root,'swift','--version'); host=jf1.capture(root,'uname','-sm'); os_version=jf1.capture(root,'sw_vers','-productVersion')
    need(host=='Darwin arm64' and int(os_version.split('.')[0])>=27 and re.search(r'Swift version 6\.4\.2(?:\s|$)',swift),'native Swift 6.4.2 ARM64 macOS 27 required')
    sdk=jf1.capture(root,'xcrun','--sdk','macosx','--show-sdk-version'); need(sdk=='27.2','anchor SDK 27.2 required')
    need(shutil.disk_usage(work).free>=args.min_free_gib*1024**3,'insufficient workspace disk')
    positive,outside=fixtures(root/FIXTURES)
    (out/'provenance.json').write_text(json.dumps(dict(sha=args.sha,base=BASE,host=host,os=os_version,swift=swift,sdk=sdk,
        xcode=jf1.capture(root,'xcodebuild','-version'),manifest_blob=jf1.MANIFEST_BLOB,fixture_sha256=hashlib.sha256((root/FIXTURES).read_bytes()).hexdigest()),indent=2)+'\n')
    package=work/'Swift-JSON'; package.mkdir(); archive=work/'source.tar'
    subprocess.run(['git','archive','--format=tar','--output='+str(archive),args.sha,'Package.swift','Sources','Tests'],cwd=root,check=True)
    subprocess.run(['tar','-xf',str(archive),'-C',str(package)],check=True); archive.unlink()
    before=json.loads(jf1.run(package,out,'baseline-manifest','swift','package','dump-package'))
    manifest=package/'Package.swift'; text=jf2.graft(manifest.read_text())
    anchor='.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONFoundationModels"])'
    need(text.count(anchor)==1,'unexpected graft anchor')
    manifest.write_text(text.replace(anchor,'.testTarget(name: "JSONFoundationModelsTests", dependencies: ["JSON", "JSONSchema", "JSONFoundationModels"], resources: [.copy("ReverseMatrix.json")])'))
    target=package/'Sources'/jf1.PRODUCT; target.mkdir(); tests=package/'Tests'/jf2.TEST_TARGET; tests.mkdir()
    for src in (root/'Tools/FoundationModelsSpike/JF2/ValueBridge.swift',root/SOURCE/'SchemaBridge.swift'): shutil.copyfile(src,target/src.name)
    for src in (root/'Tools/FoundationModelsSpike/JF2/ValueBridgeTests.swift',root/'Tools/FoundationModelsSpike/JF2/FidelityTests.swift',root/SOURCE/'SchemaBridgeTests.swift',root/NEW_TEST,root/FIXTURES): shutil.copyfile(src,tests/src.name)
    after=json.loads(jf1.run(package,out,'candidate-manifest','swift','package','dump-package')); normalized=copy.deepcopy(after)
    test=[t for t in normalized['targets'] if t['name']==jf2.TEST_TARGET]; need(len(test)==1,'test target missing')
    test=test[0]; need(test['resources']==[{'path':'ReverseMatrix.json','rule':{'copy':{}}}],'resource delta'); test['resources']=[]
    deps=test['dependencies']; schema=[d for d in deps if d.get('byName')==['JSONSchema',None]]
    need(len(deps)==3 and len(schema)==1,'test dependency delta'); deps.remove(schema[0]); jf2.inspect_manifests(before,normalized)
    matrices={}; schemas={}; values={}
    for config in ('debug','release'):
        command=('swift','test','-c',config,'--jobs','2','--test-product',jf2.TEST_TARGET,'--disable-xctest','--no-parallel','--filter')
        matrices[config]=verify(jf1.run(package,out,config+'-jf32',*command,'jf32'),positive,outside)
        (out/'reverse-matrix.json').write_text(json.dumps(matrices,ensure_ascii=True,indent=2)+'\n')
        schemas[config]=jf3.verify(jf1.run(package,out,config+'-jf31-regression',*command,'jf3[A-Z]'),'apple',fidelity)
        (out/'schema-regressions.json').write_text(json.dumps(schemas,ensure_ascii=True,indent=2)+'\n')
        values[config]=fidelity.verify(jf1.run(package,out,config+'-jf22-regression',*command,'jf2'))
        (out/'value-regressions.json').write_text(json.dumps(values,ensure_ascii=True,indent=2)+'\n')
    stable(matrices['debug'],matrices['release']); fidelity.stable(values['debug'],values['release'])
    for kind,raw in schemas['debug']['schemas'].items(): need(same(strict(raw),strict(schemas['release']['schemas'][kind])),'schema regression drift')
    need(jf1.capture(root,'git','rev-parse','HEAD')==args.sha and not jf1.capture(root,'git','status','--porcelain'),'source drift')


def main():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('sha'); parser.add_argument('output_parent',type=Path)
    parser.add_argument('--min-free-gib',type=int,default=20); args=parser.parse_args(); need(args.min_free_gib>=1,'positive disk preflight')
    root=Path(__file__).resolve().parents[1]; parent=args.output_parent.expanduser().resolve(); need(parent!=root and root not in parent.parents,'output must be outside checkout')
    os.umask(0o077); parent.mkdir(parents=True,exist_ok=True); work=Path(tempfile.mkdtemp(prefix='jf32-',dir=parent)); out=work/'evidence'; out.mkdir()
    outcome='FAILED_OR_INCOMPLETE'
    try: qualify(root,work,out,args); outcome='APPLE_REVERSE_SCHEMA_MATRIX_PASS'
    except (Exception,KeyboardInterrupt) as error:
        (out/'failure.txt').write_text(f'{type(error).__name__}: {error}\n'); print('JF3.2 failed:',error,file=sys.stderr)
    finally:
        (out/'decision.json').write_text(json.dumps({'outcome':outcome,'product_admission':'NOT_ADMITTED'},indent=2)+'\n')
        with tarfile.open(str(work)+'.tar.gz','w:gz') as archive: archive.add(out,arcname='evidence')
        print(f'ARCHIVE: {work}.tar.gz ({outcome})',flush=True); print(f'Disposable workspace retained: {work}',flush=True)
    return int(outcome=='FAILED_OR_INCOMPLETE')


if __name__=='__main__': sys.exit(main())
