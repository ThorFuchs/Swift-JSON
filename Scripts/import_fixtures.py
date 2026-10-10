#!/usr/bin/env python3
"""Import exact pinned local fixture blobs and licenses without altering source."""
import argparse, hashlib, json, pathlib, subprocess, sys

ROOT=pathlib.Path(__file__).resolve().parents[1]
def git(source,*args):
    return subprocess.check_output(['git','-C',str(source),*args],text=True).strip()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kind',choices=['syntax','schema'],required=True)
    parser.add_argument('--source',type=pathlib.Path,required=True)
    args=parser.parse_args();source=args.source.resolve()
    registry_path=ROOT/'Documentation/Qualification/FixtureRegistry.json'
    registry=json.loads(registry_path.read_text())
    repo='nst/JSONTestSuite' if args.kind=='syntax' else 'json-schema-org/JSON-Schema-Test-Suite'
    suite=next(r for r in registry['suites'] if r['repository']==repo)
    if git(source,'rev-parse','HEAD')!=suite['commit']:raise ValueError('Fixture checkout differs from required pin')
    entries=[]
    for line in git(source,'ls-tree','-r',suite['commit']).splitlines():
        meta,path=line.split('\t',1);mode,kind,sha=meta.split()
        if kind!='blob':continue
        selected=(path.startswith('test_parsing/') and path.endswith('.json')) if args.kind=='syntax' else (
            path.startswith('tests/draft2020-12/') and path.endswith('.json') or path.startswith('remotes/') and path.endswith('.json'))
        license_file=pathlib.PurePosixPath(path).name.lower() in ('license','license.txt','license.md','notice','notice.txt','copying')
        if selected or license_file:entries.append({'path':path,'blob_sha':sha,'license':license_file})
    if not entries or not any(e['license'] for e in entries):raise ValueError('Missing fixtures or license')
    count=0;data_files=[]
    for e in entries:
        rel=pathlib.PurePosixPath(e['path'])
        if rel.is_absolute() or '..' in rel.parts:raise ValueError('Unsafe path')
        data=source.joinpath(*rel.parts).read_bytes()
        actual=hashlib.sha1(b'blob '+str(len(data)).encode()+bytes([0])+data).hexdigest()
        if actual!=e['blob_sha']:raise ValueError('Dirty/missing pinned fixture: '+e['path'])
        if not e['license']:
            if args.kind=='syntax':count+=1
            elif e['path'].startswith('tests/draft2020-12/'):
                count+=sum(len(group['tests']) for group in json.loads(data))
        data_files.append((e,data))
    if not count:raise ValueError('Zero fixture cases')
    destination=ROOT/'Tests/Fixtures/External'/args.kind
    if destination.exists():raise ValueError('Destination already exists; preserve it and review before replacing')
    destination.mkdir(parents=True)
    file_manifest=[]
    for e,data in data_files:
        target=destination/e['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        file_manifest.append({**e,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
    manifest={'repository':repo,'commit':suite['commit'],'expected_cases':count,'files':file_manifest}
    (destination/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    suite.update(status='imported',fixture_path=str(destination.relative_to(ROOT)),expected_cases=count,
                 observed_cases=0,execution='not_run',manifest=str((destination/'manifest.json').relative_to(ROOT)),
                 license_paths=[str((destination/e['path']).relative_to(ROOT)) for e in entries if e['license']])
    registry_path.write_text(json.dumps(registry,indent=2)+'\n')
    print(json.dumps({'status':'imported','repository':repo,'cases':count,'native_execution':'not_run'},indent=2))
    return 0
if __name__=='__main__':
    try:sys.exit(main())
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        print('Import failed: '+str(error),file=sys.stderr);sys.exit(1)
