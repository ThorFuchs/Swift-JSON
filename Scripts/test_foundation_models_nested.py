#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline controls. Synthetic receipts never count as native SDK evidence."""
import copy
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

here=Path(__file__).parent
spec=importlib.util.spec_from_file_location('jf42',here/'qualify_foundation_models_nested.py')
gate=importlib.util.module_from_spec(spec); spec.loader.exec_module(gate)
positive,outside=gate.prior.fixtures(here.parent/gate.prior.FIXTURES)


def fixture():
    raw=json.loads(json.dumps(gate.CANONICAL,default=int))
    target=raw['properties']['primary']
    target.update(title='JF42Filter',**{'x-order':['query','limit']})
    raw['properties']['primary']={'$ref':'#/$defs/JF42Filter'}
    raw['properties']['alternatives']['items']={'$ref':'#/$defs/JF42Filter'}
    raw['properties']['fallback']={'$ref':'#/$defs/JF42Filter'}
    raw['$defs']={'JF42Filter':target}
    raw.update(title='JF42Request',**{'x-order':['primary','alternatives','fallback']})
    text=json.dumps(raw)
    nested=json.loads(positive['nested']['schema'])
    child=nested['properties']['child']; nested['properties']['child']={'$ref':'#/$defs/Child'}
    nested['$defs']={'Child':child}
    imported=json.dumps(nested)
    simple=json.loads(positive['simple']['schema']); simple.update(title='Object',**{'x-order':['query']})
    regression={'reverse':{'nested':{'raw':{'schema':imported}},'simple':{'raw':{'schema':json.dumps(simple)}}}}
    typed=[dict(id=name,source=value,returned=value) for name,value in gate.TYPED.items()]
    invalid=[dict(id=name,route=route,issue=dict(keyword=keyword,keywordLocation=gate.trace(raw,keyword,path),instanceLocation=path))
             for name,(keyword,path) in gate.INVALID.items() for route in gate.ROUTES]
    rows=[('RAW',text),('SCHEMA',text),('IMPORTED',imported)]
    rows.extend(('TYPED',r) for r in typed); rows.extend(('INVALID',r) for r in invalid)
    consumer=dict(nested=dict(schema=text,typed=copy.deepcopy(typed),invalid=copy.deepcopy(invalid)),
                  canonical=positive['simple']['schema'],projected=json.dumps(simple),returned='{"query":"Swift"}')
    return rows,regression,consumer


def log(rows):
    return ''.join('JF42_'+kind+' '+json.dumps(value,ensure_ascii=True)+'\n' for kind,value in rows)+''.join(
        '✔ Test '+name+'() passed after 0.001 seconds.\n' for name in gate.TESTS)+f'✔ Test run with {len(gate.TESTS)} tests in 0 suites passed after 0.1 seconds.\n'


def consumer_log(row):
    return 'JF42_CONSUMER '+json.dumps(row,ensure_ascii=True)+'\n'


class Controls(unittest.TestCase):
    def setUp(self): self.rows,self.regression,self.consumer=fixture()
    def verify(self): return gate.verify(log(self.rows),self.regression)
    def external(self): return gate.verify_consumer(consumer_log(self.consumer),positive,self.regression)
    def row(self,kind): return next(v for k,v in self.rows if k==kind)
    def replace_schema(self,raw):
        self.rows=[(k,json.dumps(raw) if k in ('RAW','SCHEMA') else v) for k,v in self.rows]
    def test_complete_receipts(self):
        result=self.verify()
        self.assertEqual(len(result['tests']),9); self.assertEqual(len(result['typed']),2)
        self.assertEqual(len(result['invalid']),24); self.assertEqual(result['localReferences'],3)
        gate.stable(result,self.verify()); gate.stable_consumer(self.external(),self.external())
    def test_missing_duplicate_unknown(self):
        for rows in (self.rows[:-1],self.rows+[self.rows[0]],self.rows+[('OTHER',{})],self.rows+[self.rows[-1]]):
            with self.assertRaises(ValueError): gate.verify(log(rows),self.regression)
    def test_raw_import_fidelity(self):
        self.rows[0]=('RAW','{}')
        with self.assertRaisesRegex(ValueError,'canonical import'): self.verify()
    def test_constraint_drift(self):
        raw=json.loads(self.row('SCHEMA')); raw['$defs']['JF42Filter']['properties']['limit']['maximum']=21
        self.replace_schema(raw)
        with self.assertRaisesRegex(ValueError,'constraint/annotation drift'): self.verify()
    def test_unsafe_reference_shapes(self):
        baseline=self.row('SCHEMA')
        for kind in ('sibling','missing','unused','scope','cycle'):
            raw=json.loads(baseline)
            if kind=='sibling': raw['properties']['primary']['description']='extra'
            elif kind=='missing': raw['properties']['primary']['$ref']='#/$defs/Missing'
            elif kind=='unused': raw['$defs']['Unused']={'type':'object'}
            elif kind=='scope': raw['$defs']['JF42Filter']['$id']='https://example.invalid/scope'
            else: raw['$defs']['JF42Filter']['properties']['cycle']={'$ref':'#/$defs/JF42Filter'}
            rows,_,_=fixture()
            self.rows=rows; self.replace_schema(raw)
            with self.assertRaises(ValueError): self.verify()
    def test_typed_fidelity(self):
        self.row('TYPED')['returned']=self.row('TYPED')['returned'][:-1]+',"fallback":null}'
        with self.assertRaisesRegex(ValueError,'typed fidelity'): self.verify()
    def test_diagnostic_paths(self):
        row=self.row('INVALID'); old=copy.deepcopy(row['issue'])
        for field,value in [('keyword','wrong'),('keywordLocation','/wrong'),('instanceLocation','/wrong')]:
            row['issue']=dict(old,**{field:value})
            with self.assertRaisesRegex(ValueError,'nested diagnostic drift'): self.verify()
    def test_reference_trace(self):
        raw=json.loads(self.row('SCHEMA'))
        self.assertEqual(gate.trace(raw,'minimum','/alternatives/1/limit'),
                         '/properties/alternatives/items/$ref/properties/limit/minimum')
        self.assertEqual(gate.trace(raw,'','/primary/extra'),'/properties/primary/$ref/additionalProperties')
    def test_import_anchor(self):
        self.rows[2]=('IMPORTED','{}')
        with self.assertRaisesRegex(ValueError,'local reference import drift'): self.verify()
    def test_consumer_source_and_value(self):
        for key in ('canonical','projected','returned'):
            original=self.consumer[key]; self.consumer[key]='{}'
            with self.assertRaisesRegex(ValueError,'consumer DSL'): self.external()
            self.consumer[key]=original
    def test_consumer_nested_rejection(self):
        self.consumer['nested']['invalid'].pop()
        with self.assertRaisesRegex(ValueError,'missing invalid route'): self.external()
    def test_skip_or_missing_test(self):
        good=log(self.rows)
        for bad in (good+'Test jf42Unknown() skipped.\n',good.replace('✔ Test '+gate.TESTS[0]+'() passed after 0.001 seconds.\n','')):
            with self.assertRaises(ValueError): gate.verify(bad,self.regression)
    def test_mode_drift(self):
        a=self.verify(); b=copy.deepcopy(a); b['invalid'][0]['issue']['keywordLocation']='/wrong'
        with self.assertRaisesRegex(ValueError,'diagnostic mode drift'): gate.stable(a,b)
    def test_swift_fixture_sources(self):
        text=(here.parent/gate.EXAMPLE).read_text()
        rows=re.findall(r'\("([^"]+)", #"(.*?)"#(?:, "([^"]*)", "([^"]*)")?\),',text)
        self.assertEqual(len(rows),8)
        self.assertEqual({r[0] for r in rows},set(gate.TYPED)|set(gate.INVALID))
        for name,source,keyword,location in rows:
            value=gate.strict(source)
            if name in gate.TYPED: self.assertTrue(gate.same(value,gate.strict(gate.TYPED[name])))
            else: self.assertEqual((keyword,location),gate.INVALID[name])
        # Verify every full JSON literal in the portable fixtures parses and
        # cannot accidentally close the Swift raw string around a URI fragment.
        source=(here.parent/gate.JF4/'LocalSchemaImportTests.swift').read_text()
        for hashes,payload in re.findall(r'(#+)"(\{.*?\})"\1(?=[,\n)])',source):
            self.assertNotIn('"'+hashes,payload)
            gate.strict(payload)
    def test_swift_syntax(self):
        root=here.parent
        paths=[root/p for p in sorted(gate.ALLOWED) if p.endswith('.swift')]
        self.assertEqual(len(paths),8)
        with tempfile.TemporaryDirectory() as directory:
            for index,path in enumerate(paths):
                with self.subTest(path=path.name):
                    result=subprocess.run(['swiftc','-frontend','-parse',str(path)],capture_output=True,text=True)
                    self.assertEqual(result.returncode,0,result.stderr)
                    source=path.read_text()
                    guard='#if (os(macOS) || os(iOS)) && canImport(FoundationModels)'
                    if guard in source:
                        self.assertEqual(source.count(guard),1)
                        self.assertEqual(source.count('#endif'),1)
                        unguarded=Path(directory)/f'Active{index}.swift'
                        unguarded.write_text(source.replace(guard,'').replace('#endif',''))
                        result=subprocess.run(['swiftc','-frontend','-parse',str(unguarded)],capture_output=True,text=True)
                        self.assertEqual(result.returncode,0,result.stderr)


if __name__=='__main__': unittest.main()
