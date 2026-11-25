#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline controls on synthetic receipts, not native FoundationModels evidence."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

here=Path(__file__).parent
spec=importlib.util.spec_from_file_location('gate',here/'qualify_foundation_models_reverse_matrix.py')
gate=importlib.util.module_from_spec(spec); spec.loader.exec_module(gate)
positive,outside=gate.fixtures(here.parent/gate.FIXTURES)


def fixture():
    rows=[]
    for name,v in positive.items():
        source=v['schema']; verdicts=[c['valid'] for c in v['cases']]
        raw={'outcome':'returned','schema':source,'verdicts':verdicts}
        accept={'outcome':'accepted','schema':source,'additions':[],'verdicts':verdicts}
        exact=copy.deepcopy(accept); opt=copy.deepcopy(accept)
        if name=='simple':
            aug=json.loads(source); aug.update(title='Object',**{'x-order':['query']}); text=json.dumps(aug)
            raw['schema']=text; exact={'outcome':'profileRejected','issue':'annotationAdditionDenied','path':['title']}
            opt.update(schema=text,additions=[['title'],['x-order']])
        elif name=='large-integer-bound':
            text=source.replace('9007199254740993','9007199254740992'); raw['schema']=text
            raw['verdicts']=[True,False,False,False]
            exact=opt={'outcome':'profileRejected','issue':'changedConstraint','path':['properties','n','maximum']}
        elif name=='nested-generated':
            aug=json.loads(source); aug['properties']['child']['title']='Child'; text=json.dumps(aug)
            raw['schema']=text; exact={'outcome':'profileRejected','issue':'annotationAdditionDenied','path':['properties','child','title']}
            opt.update(schema=text,additions=[['properties','child','title']])
        elif name=='empty':
            raw=exact=opt={'outcome':'codecRejected','errorType':'Swift.DecodingError'}
        elif name=='nested-array':
            raw={'outcome':'profileRejected','schema':'{}','issue':'unsupportedShape','path':[],'verdicts':[True]*len(verdicts)}
            exact=opt={k:raw[k] for k in ('outcome','issue','path')}
        elif name=='int64-bound':
            raw={'outcome':'nativeInvalid','schema':'{"type":3}','errorType':'JSONSchema.JSONSchemaCompilationFailure'}
            exact=opt={k:raw[k] for k in ('outcome','errorType')}
        if 'schema' in raw: rows.append(('RAW',{'id':name,'schema':raw['schema']}))
        rows.append(('REVERSE',dict(id=name,source=source,canonical=verdicts,raw=raw,exact=exact,optIn=opt)))
    for name,v in outside.items():
        for kind in ('PORTABLE_REJECT','APPLE_EXACT_REJECT','APPLE_OPTIN_REJECT'):
            rows.append((kind,{k:v[k] for k in ('id','issue','path')}))
    return rows


def verify(rows,names=gate.TESTS):
    log=''.join('JF32_'+k+' '+json.dumps(v,ensure_ascii=True)+'\n' for k,v in rows)
    log+=''.join('✔ Test '+n+'() passed after 0.001 seconds.\n' for n in names)
    log+=f'✔ Test run with {len(names)} tests in 0 suites passed after 0.01 seconds.\n'
    return gate.verify(log,positive,outside)


def record(rows,name,kind='REVERSE'):
    return next(v for k,v in rows if k==kind and v['id']==name)


class Controls(unittest.TestCase):
    def setUp(self): self.rows=fixture()
    def test_complete(self):
        r=verify(self.rows); self.assertEqual(len(r['reverse']),19); self.assertEqual(len(r['preflight']),12); gate.stable(r,r)
    def test_exact_number_and_scalar_semantics(self):
        self.assertFalse(gate.same(gate.strict('9007199254740993'),gate.strict('9007199254740992')))
        self.assertFalse(gate.same(gate.strict('true'),gate.strict('1')))
        self.assertFalse(gate.same(gate.strict(r'"e\u0301"'),gate.strict(r'"\u00e9"')))
        self.assertTrue(gate.same(gate.strict('20'),gate.strict('2e1')))
        with self.assertRaises(ValueError): gate.strict('{"x":1,"x":2}')
    def test_missing_duplicate_and_unknown(self):
        for rows in (self.rows[1:],self.rows+self.rows[:1],self.rows+[('UNKNOWN',{})]):
            with self.assertRaises(ValueError): verify(rows)
    def test_unsafe_acceptance(self):
        r=record(self.rows,'large-integer-bound'); r['optIn']={'outcome':'accepted','schema':r['raw']['schema'],'additions':[],'verdicts':r['canonical']}
        with self.assertRaisesRegex(ValueError,'unsafe acceptance'): verify(self.rows)
    def test_wrong_constraint_path(self):
        record(self.rows,'large-integer-bound')['optIn']={'outcome':'profileRejected','issue':'changedConstraint','path':['properties','n','minimum']}
        with self.assertRaisesRegex(ValueError,'wrong diagnostic'): verify(self.rows)
    def test_nested_annotation_scope(self):
        record(self.rows,'nested-generated')['optIn']['additions']=[['title']]
        with self.assertRaisesRegex(ValueError,'incorrect annotation additions'): verify(self.rows)
    def test_raw_disagreement(self):
        record(self.rows,'prepared','RAW')['schema']='{}'
        with self.assertRaisesRegex(ValueError,'raw receipt mismatch'): verify(self.rows)
    def test_type_aware_verdicts(self):
        record(self.rows,'prepared')['canonical']=[1,0]
        with self.assertRaisesRegex(ValueError,'canonical drift'): verify(self.rows)
    def test_preflight_path(self):
        record(self.rows,'nullable','APPLE_OPTIN_REJECT')['path']=[]
        with self.assertRaisesRegex(ValueError,'wrong preflight diagnostic'): verify(self.rows)
    def test_operational_rejection(self):
        record(self.rows,'empty')['raw']['errorType']='JSON.JSONFailure'
        with self.assertRaisesRegex(ValueError,'unexpected codec error'): verify(self.rows)
    def test_false_profile_rejection(self):
        r=record(self.rows,'prepared'); r['raw'].update(outcome='profileRejected',issue='unsupportedShape',path=[])
        with self.assertRaisesRegex(ValueError,'profile disagreement'): verify(self.rows)
    def test_required_test_set(self):
        with self.assertRaises(ValueError): verify(self.rows,gate.TESTS[:-1])
    def test_skip_not_pass(self):
        with self.assertRaises(ValueError):
            gate.pass_set(''.join(f'Test {n}() passed\n' for n in gate.TESTS)+'Test run with 4 tests in 0 suites passed\nTest other() skipped.\n',gate.TESTS)
    def test_mode_drift(self):
        a=verify(self.rows); b=copy.deepcopy(a); b['reverse']['prepared']['optIn']['outcome']='profileRejected'
        with self.assertRaisesRegex(ValueError,'mode disposition drift'): gate.stable(a,b)
    def test_property_names_not_metadata(self):
        a=gate.strict(positive['metadata-names']['schema']); b=copy.deepcopy(a); b['properties']['title']['description']='Changed'
        changes,additions=gate.delta(a,b)
        self.assertEqual(changes,{('changedAnnotation',('properties','title','description'))}); self.assertFalse(additions)


if __name__=='__main__': unittest.main()
