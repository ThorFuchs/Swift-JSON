#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Reproducible source candidate, explicit contents and independent hash verification."""
import argparse,gzip,hashlib,io,json,pathlib,tarfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
TOP=('Sources','Tests','Examples','Tools','Scripts','Documentation','Licenses','.github')
SKIP={'.build','.git','.swiftpm','__pycache__','DerivedData','Artifacts'}
ROOT_FILES=('Package.swift','AGENTS.md','README.md','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md','SUPPORT.md','RELEASING.md','LICENSE','NOTICE','THIRD_PARTY_NOTICES.md','.gitignore','.editorconfig','.gitattributes')
def files(root=ROOT):
 selected=[]
 for top in TOP:
  for path in (root/top).rglob('*'):
   rel=path.relative_to(root)
   if any(p in SKIP for p in rel.parts) or path.name=='.DS_Store' or path.suffix in ('.pyc','.xcuserstate'):continue
   if path.is_symlink():raise ValueError('Unexpected symlink '+str(rel))
   if path.is_file():selected.append(path)
 for name in ROOT_FILES:
  path=root/name
  if path.is_file():selected.append(path)
 return sorted(set(selected),key=lambda p:p.relative_to(root).as_posix())
def archive(destination,selected,root=ROOT):
 records=[]
 for path in selected:
  rel=path.relative_to(root).as_posix();data=path.read_bytes()
  if path.suffix=='.log' and str(root).encode() in data:raise ValueError('Unnormalized workspace path in public log: '+rel)
  records.append((rel,data,hashlib.sha256(data).hexdigest(),0o755 if path.stat().st_mode&0o111 else 0o644))
 manifest=''.join(digest+'  '+path+'\n' for path,_,digest,_ in records).encode()
 records.append(('MANIFEST.sha256',manifest,hashlib.sha256(manifest).hexdigest(),0o644))
 destination.parent.mkdir(parents=True,exist_ok=True)
 with destination.open('wb') as stream:
  with gzip.GzipFile(fileobj=stream,mode='wb',filename='',mtime=0,compresslevel=9) as zipped:
   with tarfile.open(fileobj=zipped,mode='w',format=tarfile.GNU_FORMAT) as tar:
    for name,data,_,mode in sorted(records):
     entry=tarfile.TarInfo('Swift-JSON/'+name);entry.size=len(data);entry.mode=mode
     entry.mtime=0;entry.uid=entry.gid=0;entry.uname=entry.gname=''
     tar.addfile(entry,io.BytesIO(data))
 return records
def verify(path):
 with tarfile.open(path,'r:gz') as tar:
  members=tar.getmembers();names=[p.name for p in members]
  if len(names)!=len(set(names)):raise ValueError('Duplicate archive entries')
  if any(not p.isfile() or '..' in pathlib.PurePosixPath(p.name).parts or not p.name.startswith('Swift-JSON/') for p in members):raise ValueError('Unsafe archive entry')
  manifest=tar.extractfile('Swift-JSON/MANIFEST.sha256').read().decode()
  listed=[]
  for line in manifest.splitlines():
   digest,name=line.split('  ',1)
   if len(digest)!=64 or any(c not in '0123456789abcdef' for c in digest):raise ValueError('Invalid manifest digest')
   rel=pathlib.PurePosixPath(name)
   if rel.is_absolute() or '..' in rel.parts or name=='MANIFEST.sha256':raise ValueError('Unsafe manifest path')
   listed.append('Swift-JSON/'+name);data=tar.extractfile('Swift-JSON/'+name).read()
   if hashlib.sha256(data).hexdigest()!=digest:raise ValueError('Archive hash mismatch: '+name)
  if len(listed)!=len(set(listed)) or set(names)!=set(listed)|{'Swift-JSON/MANIFEST.sha256'}:raise ValueError('Manifest does not exactly cover archive files')
 return len(members)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',default='Artifacts/Swift-JSON-public-candidate.tar.gz');a=p.parse_args()
 selected=files();output=ROOT/a.output;second=output.with_suffix('.repro.gz')
 records=archive(output,selected);archive(second,selected)
 digest=hashlib.sha256(output.read_bytes()).hexdigest()
 if digest!=hashlib.sha256(second.read_bytes()).hexdigest():raise ValueError('Archives differ')
 second.unlink();count=verify(output)
 report={'schema_version':1,'status':'passed','command':'python3 Scripts/archive_candidate.py --output '+a.output,'archive':a.output,'sha256':digest,'bytes':output.stat().st_size,'files':count,'byte_equal_rebuild':True,'manifest_verified_entries':len(records)-1,'format':'GNU tar + gzip, sorted entries, mtime 0, uid/gid 0, normalized modes','contents':[p for p,_,_,_ in records],'publication_performed':False}
 output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='contents'},indent=2))
if __name__=='__main__':main()
