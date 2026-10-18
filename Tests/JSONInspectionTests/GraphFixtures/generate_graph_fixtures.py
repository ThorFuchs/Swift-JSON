#!/usr/bin/env python3
"""Independent design-fixture generator. NOT a Swift-JSON semantic or runtime qualification."""
from pathlib import Path
import json, hashlib
base=Path(__file__).resolve().parent
cases={
 'g01-empty':({'nodes':[],'edges':[]},{},'valid'),
 'g02-simple':({'nodes':[{'id':'A'},{'id':'B'},{'id':'C'}], 'edges':[{'from':'A','to':'B'},{'from':'A','to':'C'},{'from':'B','to':'C'}]}, {},'valid'),
 'g03-unicode-scalars':({'nodes':[{'id':'é'},{'id':'e\u0301'}],'edges':[{'from':'é','to':'e\u0301'}]}, {},'valid'),
 'g04-empty-and-special-ids':({'nodes':[{'id':''},{'id':'a/b~c'},{'id':'0'}], 'edges':[{'from':'','to':'a/b~c'},{'from':'0','to':''}]},{},'valid'),
 'g05-duplicate-id':({'nodes':[{'id':'A','name':'x'},{'id':'A','name':'y'}],'edges':[]},{},'duplicate_node_id'),
 'g06-equal-payload-distinct-id':({'nodes':[{'id':'A','same':{'x':1}},{'id':'B','same':{'x':1}}],'edges':[]},{},'valid'),
 'g07-node-id-missing':({'nodes':[{'name':'A'}],'edges':[]},{},'node_id_missing'),
 'g08-node-id-null':({'nodes':[{'id':None}],'edges':[]},{},'node_id_null'),
 'g09-node-id-number':({'nodes':[{'id':22}],'edges':[]},{},'node_id_wrong_kind'),
 'g10-node-row-not-object':({'nodes':['A'],'edges':[]},{},'node_row_wrong_kind'),
 'g11-edge-source-missing':({'nodes':[{'id':'A'}],'edges':[{'to':'A'}]},{},'edge_source_missing'),
 'g12-edge-target-null':({'nodes':[{'id':'A'}],'edges':[{'from':'A','to':None}]},{},'edge_target_null'),
 'g13-edge-target-number':({'nodes':[{'id':'A'}],'edges':[{'from':'A','to':3}]},{},'edge_target_wrong_kind'),
 'g14-edge-row-not-object':({'nodes':[{'id':'A'}],'edges':[3]},{},'edge_row_wrong_kind'),
 'g15-dangling':({'nodes':[{'id':'A'}],'edges':[{'from':'A','to':'B'}]},{},'dangling_endpoint'),
 'g15b-dangling-empty':({'nodes':[],'edges':[{'from':'A','to':'A'}]},{},'dangling_endpoint'),
 'g16-duplicate-edge':({'nodes':[{'id':'A'},{'id':'B'}],'edges':[{'from':'A','to':'B'},{'from':'A','to':'B'}]},{},'duplicate_directed_edge'),
 'g17-reverse-edges':({'nodes':[{'id':'A'},{'id':'B'}],'edges':[{'from':'A','to':'B'},{'from':'B','to':'A'}]},{},'valid'),
 'g18-self-edge':({'nodes':[{'id':'A'}],'edges':[{'from':'A','to':'A'}]},{},'valid'),
 'g19-cycle':({'nodes':[{'id':'A'},{'id':'B'},{'id':'C'}],'edges':[{'from':'A','to':'B'},{'from':'B','to':'C'},{'from':'C','to':'A'}]},{},'valid'),
 'g20-isolate':({'nodes':[{'id':'A'},{'id':'B'},{'id':'ISO'}],'edges':[{'from':'A','to':'B'}]},{},'valid'),
 'g21-bfs-source-edge-order':({'nodes':[{'id':x} for x in ['A','B','C','D']],'edges':[{'from':'A','to':'D'},{'from':'A','to':'B'},{'from':'A','to':'C'}]},{},'valid'),
 'g22-diamond':({'nodes':[{'id':x} for x in ['A','B','C','D']],'edges':[{'from':'A','to':'B'},{'from':'A','to':'C'},{'from':'B','to':'D'},{'from':'C','to':'D'}]},{},'valid'),
 'g23-numeric-object-key':({'0':{'nodes':[{'key/id':'0'},{'key/id':'A'}],'edges':[{'src~':'0','dst':'A'}]}},{'nodes_at':[{'key':'0'},{'key':'nodes'}],'edges_at':[{'key':'0'},{'key':'edges'}],'node_id_key':'key/id','edge_source_key':'src~','edge_target_key':'dst'},'valid'),
 'g24-overlap':({'data':[{'id':'A'}]},{'nodes_at':[{'key':'data'}],'edges_at':[{'key':'data'}]},'overlap'),
 'g25-wrong-nodes-array':({'nodes':{},'edges':[]},{},'nodes_not_array'),
 'g26-wrong-edges-array':({'nodes':[],'edges':{}},{},'edges_not_array'),
}
def tok_path(root,segs):
 val=root
 for seg in segs:
  if 'key' in seg:
   if not isinstance(val,dict):raise TypeError('path_expected_object')
   val=val[seg['key']]
  else:
   if not isinstance(val,list):raise TypeError('path_expected_array')
   val=val[seg['index']]
 return val
def reference(obj, prof):
 np=prof.get('nodes_at',[{'key':'nodes'}]);ep=prof.get('edges_at',[{'key':'edges'}]);node=prof.get('node_id_key','id'); fr=prof.get('edge_source_key','from');to=prof.get('edge_target_key','to')
 if np==ep or (len(np)<=len(ep) and np==ep[:len(np)]) or (len(ep)<=len(np) and ep==np[:len(ep)]):return {'kind':'overlap'}
 try:nodes=tok_path(obj,np);edges=tok_path(obj,ep)
 except Exception:return {'kind':'missing_or_invalid_selection'}
 if not isinstance(nodes,list):return {'kind':'nodes_not_array'}
 if not isinstance(edges,list):return {'kind':'edges_not_array'}
 ids=[]
 for i,n in enumerate(nodes):
  if not isinstance(n,dict):return {'kind':'node_row_wrong_kind','node_index':i}
  if node not in n:return {'kind':'node_id_missing','node_index':i}
  if n[node] is None:return {'kind':'node_id_null','node_index':i}
  if not isinstance(n[node],str):return {'kind':'node_id_wrong_kind','node_index':i}
  if n[node] in ids:return {'kind':'duplicate_node_id','node_index':i,'first_index':ids.index(n[node])}
  ids.append(n[node])
 pairs=[];outgoing=[[] for _ in nodes]
 for eindex,e in enumerate(edges):
  if not isinstance(e,dict):return {'kind':'edge_row_wrong_kind','edge_index':eindex}
  for field,field_name in ((fr,'edge_source'),(to,'edge_target')):
   if field not in e:return {'kind':field_name+'_missing','edge_index':eindex}
   if e[field] is None:return {'kind':field_name+'_null','edge_index':eindex}
   if not isinstance(e[field],str):return {'kind':field_name+'_wrong_kind','edge_index':eindex}
  if e[fr] not in ids or e[to] not in ids:return {'kind':'dangling_endpoint','edge_index':eindex}
  pair=(ids.index(e[fr]),ids.index(e[to]))
  if pair in pairs:return {'kind':'duplicate_directed_edge','edge_index':eindex,'first_index':pairs.index(pair)}
  pairs.append(pair);outgoing[pair[0]].append(eindex)
 visited=[False]*len(ids);order=[];queue=[]
 if nodes:
  queue=[0];visited[0]=True;head=0
  while head<len(queue):
   n=queue[head];head+=1;order.append(n)
   for idx in outgoing[n]:
    target=pairs[idx][1]
    if not visited[target]:visited[target]=True;queue.append(target)
 return {'kind':'valid','ids_codepoints':[[ord(ch) for ch in s] for s in ids], 'edge_pairs':[list(pair) for pair in pairs],'outgoing_edge_ordinals':outgoing,'bfs_from_node0':order}
if __name__ == "__main__":
    manifest=[]
    for name,(data,profile,expected) in sorted(cases.items()):
     raw=json.dumps(data,indent=2,ensure_ascii=False)+'\n'; path=base/(name+'.json');path.write_text(raw)
     actual=reference(data,profile)
     if actual['kind']!=expected:raise ValueError((name,expected,actual))
     manifest.append({'name':name,'file':path.name,'sha256':hashlib.sha256(raw.encode()).hexdigest(),'profile':profile,'expected':actual})
    (base/'GRAPH-FIXTURE-ORACLE.json').write_text(json.dumps({'disclaimer':'Independent test-data oracle, NOT Swift-JSON validation','cases':manifest},ensure_ascii=False,indent=2)+'\n')
    print('generated',len(manifest),'cases')
