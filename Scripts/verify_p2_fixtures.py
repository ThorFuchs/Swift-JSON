#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Independent pair/scalar/Decimal fixture premises, not Swift engine qualification."""
import hashlib,json,pathlib
from decimal import Decimal
ROOT=pathlib.Path(__file__).resolve().parents[1]
DIRECTORY=ROOT/'Tests/JSONInspectionTests/P2Fixtures'
class Object(list): pass
def read(name):
    return json.loads((DIRECTORY/(name+'.json')).read_text(),parse_int=Decimal,parse_float=Decimal,object_pairs_hook=Object)
def equivalent(a,b):
    if type(a) is not type(b): return False
    if isinstance(a,Object):
        return len(a)==len(b) and all(any(k==other and equivalent(v,value) for other,value in b) for k,v in a)
    if isinstance(a,list):return len(a)==len(b) and all(equivalent(x,y) for x,y in zip(a,b))
    return a==b

def main():
    manifest=json.loads((ROOT/'Documentation/Qualification/P2Fixtures.json').read_text())
    expected={r['path']:r['sha256'] for r in manifest['files']}
    assert len(expected)==20 and set(expected)=={p.name for p in DIRECTORY.iterdir() if p.is_file()}
    for name,digest in expected.items():assert hashlib.sha256((DIRECTORY/name).read_bytes()).hexdigest()==digest,name
    for name,indices in {'set-empty':[],'set-nulls':[0],'set-arrays':[0,1],
                         'set-equality':[0,2,3,4,6,7,8,10,11,12,13]}.items():
        values=read(name);actual=[]
        for i,value in enumerate(values):
            if not any(equivalent(values[first],value) for first in actual):actual.append(i)
        assert actual==indices,(name,actual)
    for name,shape in {'matrix-0x0':(0,0),'matrix-2x0':(2,0),'matrix-1x0':(1,0),'matrix-2x2':(2,2),
                       'matrix-3x1':(3,1),'matrix-exact':(2,2),'matrix-ragged':None,'matrix-string-cell':None,'matrix-nonarray-row':None}.items():
        rows=read(name);width=len(rows[0]) if rows and type(rows[0]) is list else 0
        valid=all(type(row) is list and len(row)==width and all(type(cell) is Decimal for cell in row) for row in rows)
        assert ((len(rows),width) if valid else None)==shape,name
    # These assertions inspect data premises; no graph/store runtime is implemented.
    graph={name:dict(read(name)) for name in ['graph-duplicate-id','graph-dangling-edge','graph-cycle']}
    ids=[dict(node)['id'] for node in graph['graph-duplicate-id']['nodes']];assert len(ids)>len(set(ids))
    dangling=graph['graph-dangling-edge'];ids={dict(node)['id'] for node in dangling['nodes']}
    assert any(dict(edge)['target'] not in ids for edge in dangling['edges'])
    assert len(graph['graph-cycle']['edges'])==2
    premise=dict(read('graph-design-premises'))
    scalar=[dict(node)['id'] for node in dict(premise['scalarIDs'])['nodes']];assert scalar[0]!=scalar[1]
    assert 'id' not in dict(dict(premise['missingID'])['nodes'][0]) and dict(dict(premise['nullID'])['nodes'][0])['id'] is None
    store=dict(read('store-design-premises'));collections=dict(store['collections']);assert 'é' in collections and 'e\u0301' in collections
    record=dict(collections['records'][2]);assert record['id']!=record['_id']
    assert dict(collections['data'][0])['$ref']=='ordinary payload' and len(store['malformedMarkers'])==4
    ordinary=dict(read('store-ref-data-only'));assert '$ref' in json.dumps(ordinary,ensure_ascii=False)
    print('P2_FIXTURES passed pinned=20 matrix_shapes=9 set_oracles=4 design_only=6')
if __name__=='__main__':main()
