#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Select explicitly fetched suite resources without introducing a runtime resolver."""
import json, pathlib, urllib.parse, hashlib
root=pathlib.Path(__file__).resolve().parents[1]
suite=root/'Tests/Fixtures/External/schema'
remotes={}
ids={}
def refs(value,base):
    if isinstance(value,dict):
        if isinstance(value.get('$id'),str): base=urllib.parse.urljoin(base,value['$id'])
        if base: ids.setdefault(urllib.parse.urldefrag(base)[0],None)
        for key,child in value.items():
            if key in ('$ref','$dynamicRef','$schema') and isinstance(child,str):
                yield urllib.parse.urldefrag(urllib.parse.urljoin(base,child))[0]
            elif isinstance(child,(dict,list)): yield from refs(child,base)
    elif isinstance(value,list):
        for child in value: yield from refs(child,base)
for path in sorted((suite/'remotes').rglob('*.json')):
    name=path.relative_to(suite).as_posix()
    uri='http://localhost:1234/'+path.relative_to(suite/'remotes').as_posix()
    value=json.loads(path.read_text())
    remotes[uri]=(name,value)
    before=set(ids); list(refs(value,uri))
    for identifier in set(ids)-before: ids[identifier]=uri
selections=[]
for path in sorted((suite/'tests/draft2020-12').rglob('*.json')):
    groups=json.loads(path.read_text())
    for index,group in enumerate(groups):
        pending=list(refs(group['schema'],'')); selected=set()
        while pending:
            uri=pending.pop()
            retrieval=uri if uri in remotes else ids.get(uri)
            if retrieval in remotes and retrieval not in selected:
                selected.add(retrieval)
                pending.extend(refs(remotes[retrieval][1],retrieval))
        selections.append({'file':path.relative_to(suite).as_posix(),'group':index,
            'resources':[remotes[uri][0] for uri in sorted(selected)]})
output=root/'Tests/Fixtures/Schema/ResourceSelection.json'
output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps({'suite_commit':'5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8','groups':selections},indent=2)+'\n')
print(len(selections),'groups;',hashlib.sha256(output.read_bytes()).hexdigest())
