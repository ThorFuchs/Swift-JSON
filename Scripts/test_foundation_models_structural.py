#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline controls; synthetic native receipts are not native evidence."""
import copy
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import unittest

here=Path(__file__).parent
spec=importlib.util.spec_from_file_location('gate',here/'qualify_foundation_models_structural.py')
gate=importlib.util.module_from_spec(spec); spec.loader.exec_module(gate)
positive,outside=gate.prior.fixtures(here.parent/gate.prior.FIXTURES)


def fixture():
    rows=[]; regression={'reverse':{}}
    for name,v in positive.items():
        raw=json.loads(v['schema']); expected=[c['valid'] for c in v['cases']]
        if name=='simple': raw.update(title='Object',**{'x-order':['query']})
        if name in ('nested','nested-generated','object-array'):
            path=gate.REWRITES[name][0][1]; key=gate.REWRITES[name][0][2]
            parent=raw
            for part in path[:-1]: parent=parent[part]
            target=parent[path[-1]]; parent[path[-1]]={'$ref':'#/$defs/'+key}; raw['$defs']={key:target}
            if name=='nested-generated':
                raw.update(title='Object',**{'x-order':['child']}); target.update(title=key,**{'x-order':['name']})
        if name=='required-order': raw['required']=list(reversed(raw['required']))
        # Use the original numeric text for all unchanged fixtures, including
        # Int64 limits. The one intentionally rounded case is a synthetic failure.
        text=json.dumps(raw,ensure_ascii=True) if name in gate.REWRITES or name=='simple' else v['schema']
        if name=='precise-decimal-bound': text=v['schema'].replace('0.12345678901234567890123456789','0.12345678901234568').replace('0.12345678901234567890123456791','0.12345678901234568')
        old={'raw':{'outcome':'profileRejected' if '$defs' in raw else 'returned','schema':text,'verdicts':expected},
             'exact':{'outcome':'rejected' if name in gate.REWRITES or name in ('simple','precise-decimal-bound') else 'accepted'},
             'optIn':{'outcome':'rejected' if name in gate.REWRITES or name=='precise-decimal-bound' else 'accepted'}}
        regression['reverse'][name]=old
        if name=='precise-decimal-bound': row=dict(id=name,outcome='rejected',issue='changedConstraint',path=['properties','n','minimum'])
        else:
            rewrites=[dict(kind=k,path=list(p),**({'definition':d} if d is not None else {})) for k,p,d in gate.REWRITES.get(name,[])]
            row=dict(id=name,outcome='accepted',schema=text,verdicts=expected,additions=[list(p) for p in sorted(gate.ADDITIONS.get(name,set()))],rewrites=rewrites)
        rows.append(('MATRIX',row))
    for name,v in outside.items(): rows.append(('OUTSIDE',dict(id=name,outcome='rejected',issue=v['issue'],path=v['path'])))
    return rows,regression


def log(rows):
    return ''.join('JF33_'+kind+' '+json.dumps(row,ensure_ascii=True)+'\n' for kind,row in rows)+''.join('✔ Test '+name+'() passed after 0.001 seconds.\n' for name in gate.TESTS)+f'✔ Test run with {len(gate.TESTS)} tests in 0 suites passed after 0.1 seconds.\n'


class Controls(unittest.TestCase):
    def setUp(self): self.rows,self.regression=fixture()
    def verify(self): return gate.verify(log(self.rows),positive,outside,self.regression)
    def row(self,name): return next(r for k,r in self.rows if r['id']==name)
    def test_reference_fixture_delimiters(self):
        # Inspect the actual Swift literals, not a separately authored corpus.
        path=here.parent/gate.SOURCE/'StructuralProofTests.swift'
        expected={'hoistedChild','escaped','once','siblings','unused','scoped',
                  'alias','dynamic','rootRef','cyclic','mutual','aliasBoth','added'}
        found=set()
        for line in path.read_text().splitlines():
            match=re.fullmatch(r'\s*(?:private )?let (\w+) = (#+)"(\{.*\})"\2',line)
            if not match: continue
            name, hashes, payload=match.groups()
            if '"#' not in payload: continue
            self.assertNotIn(name,found); found.add(name)
            self.assertNotIn('"'+hashes,payload,name)
            self.assertIsInstance(gate.strict(payload),dict,name)
        self.assertEqual(found,expected)
    def test_swift_fixture_syntax(self):
        path=here.parent/gate.SOURCE/'StructuralProofTests.swift'
        # Syntax-only preflight; actual package typechecking and test execution
        # still require the supported Apple toolchain in the qualification lane.
        result=subprocess.run(['swiftc','-frontend','-parse',str(path)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
    def test_complete_receipts(self):
        result=self.verify(); self.assertEqual(len(result['tests']),10); self.assertEqual(len(result['matrix']),19); self.assertEqual(len(result['outside']),12); gate.stable(result,self.verify())
    def test_missing_and_duplicate(self):
        for rows in (self.rows[:-1],self.rows+[self.rows[0]]):
            with self.assertRaises(ValueError): gate.verify(log(rows),positive,outside,self.regression)
    def test_wrong_target(self):
        self.row('nested')['rewrites'][0]['definition']='Wrong'
        with self.assertRaisesRegex(ValueError,'rewrite evidence'): self.verify()
    def test_missing_required_rewrite(self):
        self.row('required-order')['rewrites']=[]
        with self.assertRaisesRegex(ValueError,'rewrite evidence'): self.verify()
    def test_missing_annotation(self):
        self.row('nested-generated')['additions'].pop()
        with self.assertRaisesRegex(ValueError,'annotation evidence'): self.verify()
    def test_decimal_rejection(self):
        self.row('precise-decimal-bound')['outcome']='accepted'
        with self.assertRaisesRegex(ValueError,'decimal loss'): self.verify()
    def test_raw_drift(self):
        self.row('large-integer-bound')['schema']=self.row('large-integer-bound')['schema'].replace('9007199254740993','9007199254740992')
        with self.assertRaisesRegex(ValueError,'returned schema'): self.verify()
    def test_instance_drift(self):
        self.row('nested')['verdicts'][0]=False
        with self.assertRaisesRegex(ValueError,'instance drift'): self.verify()
    def test_preflight_drift(self):
        self.row('nullable')['path']=[]
        with self.assertRaisesRegex(ValueError,'preflight drift'): self.verify()
    def test_old_policy_drift(self):
        self.regression['reverse']['nested']['optIn']['outcome']='accepted'
        with self.assertRaisesRegex(ValueError,'historical policy'): self.verify()
    def test_fragment_decoding(self):
        self.assertEqual(gate.token('#/$defs/A~1B~0C%25'),'A/B~C%')
        self.assertEqual(gate.token('#/$defs/A%252FB'),'A%2FB')
        for ref in ['#/$defs/A~2','#/$defs/A%GG','https://x/#/$defs/A','#/$defs/A/type','#']:
            with self.assertRaises(ValueError): gate.token(ref)
    def test_independent_reference_rejection(self):
        source=gate.strict(positive['nested']['schema']); raw=gate.strict(self.regression['reverse']['nested']['raw']['schema'])
        for edit in ('unused','sibling','missing','scope'):
            altered=copy.deepcopy(raw)
            if edit=='unused': altered['$defs']['unused']={'type':'string'}
            elif edit=='sibling': altered['properties']['child']['description']='extra'
            elif edit=='missing': altered['properties']['child']['$ref']='#/$defs/Missing'
            else: altered['$defs']['Child']['$id']='https://example.invalid/scope'
            with self.assertRaises(ValueError): gate.independent_delta(source,altered)
    def test_skip_and_missing_test(self):
        good=log(self.rows)
        for bad in (good+'Test jf33Other() skipped.\n',good.replace('✔ Test '+gate.TESTS[0]+'() passed after 0.001 seconds.\n','')):
            with self.assertRaises(ValueError): gate.verify(bad,positive,outside,self.regression)
    def test_mode_drift(self):
        a=self.verify(); b=copy.deepcopy(a); b['matrix']['nested']['rewrites'][0]['definition']='Other'
        with self.assertRaisesRegex(ValueError,'rewrite drift'): gate.stable(a,b)


if __name__=='__main__': unittest.main()
