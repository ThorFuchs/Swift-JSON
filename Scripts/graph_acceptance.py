# SPDX-License-Identifier: Apache-2.0
"""Exact graph identities and genuine compiler outcomes; no broad exit-zero gate."""
import json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
POLICY=json.loads((ROOT/'Documentation/Qualification/GraphCases.json').read_text())
EXPECTED=frozenset(POLICY['functions']) | frozenset(POLICY['public_functions'])
SHARED=frozenset({'JSONInspectionTests.graphG30ConcurrentViewsHaveIndependentHealth()', 'JSONInspectionTests.graphGP14ConcurrentQueries()'})
def check_graph_cases(events,shared=False):
 names=[n for n in events['function_names'] if n.startswith('JSONInspectionTests.graphG')]
 return len(names)==len(set(names)) and set(names)==(SHARED if shared else EXPECTED)
def check_graph_receipt(data,context=False):
 commands=data.get('commands',[]);expected_count=18 if context else 28;negative_count=8 if context else 18
 if data.get('status')!='passed' or len(commands)!=expected_count or len({c.get('name') for c in commands})!=expected_count:return False
 negatives=[c for c in commands if c.get('expected_diagnostic')]
 if len(negatives)!=negative_count:return False
 for c in commands:
  if c.get('status')!='passed' or c.get('compiler_crash') is not False:return False
  if c.get('expected_diagnostic'):
   if c.get('exit_code',0)<=0 or not any(c['expected_diagnostic'].lower() in d.lower() for d in c.get('primary_diagnostics',[])):return False
  elif c.get('exit_code')!=0:return False
 return True

PUBLIC_CHECKS = frozenset(POLICY['public_consumer_checks'])
def check_public_graph_receipt(data):
 commands=data.get('commands',[]);results=data.get('consumer_results',{})
 if data.get('status')!='passed' or len(commands)!=45 or len({c.get('name') for c in commands})!=45 or set(results)!={'debug','release','address'}:return False
 negatives=[c for c in commands if c.get('expected_diagnostic')]
 if len(negatives)!=26:return False
 for c in commands:
  if c.get('status')!='passed' or c.get('compiler_crash') is not False:return False
  if c.get('expected_diagnostic'):
   if c.get('exit_code',0)<=0 or not any(c['expected_diagnostic'] in d for d in c.get('primary_diagnostics',[])):return False
  elif c.get('exit_code')!=0:return False
 for row in results.values():
  names=row.get('cases',[])
  if len(names)!=16 or len(set(names))!=16 or set(names)!=PUBLIC_CHECKS:return False
  if not all(isinstance(row.get(k),int) and row[k]>0 for k in ['work_units','logical_retained_bytes','peak_logical_retained_bytes','admitted_nodes']):return False
 return True
