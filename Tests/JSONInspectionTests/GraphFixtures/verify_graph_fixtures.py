#!/usr/bin/env python3
"""Checks authored graph-fixture bytes and independent design-premise oracle; no Swift tests."""
from pathlib import Path
import json,hashlib
from generate_graph_fixtures import reference
base=Path(__file__).resolve().parent
assert (base/'GRAPH-FIXTURE-ORACLE.json').exists()
m=json.loads((base/'GRAPH-FIXTURE-ORACLE.json').read_text())
seen=set()
for item in m['cases']:
 fn=item['file'];assert fn not in seen;seen.add(fn)
 data=(base/fn).read_bytes()
 assert hashlib.sha256(data).hexdigest()==item['sha256'],fn
 val=reference(json.loads(data.decode()),item['profile'])
 assert val==item['expected'],(fn,val,item['expected'])
print('NAV11 fixture verification PASS',len(seen),'cases; design-only oracle')
