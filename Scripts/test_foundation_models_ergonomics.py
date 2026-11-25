#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline receipt controls; synthetic evidence is not native Apple execution."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

here=Path(__file__).parent
spec=importlib.util.spec_from_file_location('jf4',here/'qualify_foundation_models_ergonomics.py')
gate=importlib.util.module_from_spec(spec); spec.loader.exec_module(gate)
positive,outside=gate.prior.fixtures(here.parent/gate.prior.FIXTURES)
GUIDED='{"title":"JF3GuidedArguments","type":"object","properties":{"query":{"type":"string","description":"Search query"},"limit":{"type":"integer","minimum":1,"maximum":20},"sort":{"type":"string","enum":["date","title"]},"tags":{"type":"array","items":{"type":"string"},"minItems":2,"maxItems":2},"note":{"type":"string"}},"required":["query","limit","sort","tags"],"x-order":["query","limit","sort","tags","note"],"additionalProperties":false}'


def fixture():
    schema=json.loads(GUIDED); schema['title']='JF4SearchArguments'
    canonical=positive['nested']['schema']; raw=json.loads(canonical)
    child=raw['properties']['child']; raw['properties']['child']={'$ref':'#/$defs/Child'}
    raw['$defs']={'Child':child}
    projected=json.dumps(raw)
    regression={'reverse':{'nested':{'raw':{'schema':projected}}}}
    rows=[('SCHEMA',json.dumps(schema)),('DSL',dict(canonical=canonical,projected=projected,returned='{"child":{"name":"Swift"}}')),
          ('NUMBER',dict(accepted='9007199254740992',rejected='9007199254740993',issue='changedValue'))]
    rows.extend(('TYPED',dict(id=name,source=text,returned=text)) for name,text in gate.TYPED.items())
    rows.extend(('INVALID',dict(id=name,route=route,issues=[keyword])) for (name,route),keyword in gate.INVALID.items())
    return rows,regression


def log(rows):
    return ''.join('JF4_'+kind+' '+json.dumps(value,ensure_ascii=True)+'\n' for kind,value in rows)+''.join(
        '✔ Test '+name+'() passed after 0.001 seconds.\n' for name in gate.TESTS)+f'✔ Test run with {len(gate.TESTS)} tests in 0 suites passed after 0.1 seconds.\n'


class Controls(unittest.TestCase):
    def setUp(self): self.rows,self.regression=fixture()
    def verify(self): return gate.verify(log(self.rows),GUIDED,positive,self.regression)
    def row(self,kind): return next(v for k,v in self.rows if k==kind)
    def test_complete_receipts(self):
        a=self.verify()
        self.assertEqual(len(a['tests']),12); self.assertEqual(len(a['typed']),2); self.assertEqual(len(a['invalid']),26)
        gate.stable(a,self.verify())
    def test_missing_and_duplicate(self):
        for rows in (self.rows[:-1],self.rows+[self.rows[0]],self.rows+[self.rows[-1]]):
            with self.assertRaises(ValueError): gate.verify(log(rows),GUIDED,positive,self.regression)
    def test_wrong_diagnostic(self):
        self.row('INVALID')['issues']=['wrong']
        with self.assertRaisesRegex(ValueError,'intended diagnostic'): self.verify()
    def test_typed_null_versus_absence(self):
        self.row('TYPED')['returned']=self.row('TYPED')['returned'][:-1]+',"note":null}'
        with self.assertRaisesRegex(ValueError,'typed fidelity'): self.verify()
    def test_typed_value_drift(self):
        self.row('TYPED')['returned']=self.row('TYPED')['returned'].replace('"limit":2','"limit":true')
        with self.assertRaisesRegex(ValueError,'typed fidelity'): self.verify()
    def test_schema_drift(self):
        self.rows[0]=('SCHEMA',self.rows[0][1].replace('"maximum": 20','"maximum": 21'))
        with self.assertRaisesRegex(ValueError,'typed schema drift'): self.verify()
    def test_dsl_projection_drift(self):
        self.row('DSL')['projected']=self.row('DSL')['canonical']
        with self.assertRaisesRegex(ValueError,'DSL actual projection drift'): self.verify()
    def test_dsl_value_drift(self):
        self.row('DSL')['returned']='{"child":{"name":"different"}}'
        with self.assertRaisesRegex(ValueError,'DSL value drift'): self.verify()
    def test_number_policy_drift(self):
        self.row('NUMBER')['issue']='accepted'
        with self.assertRaisesRegex(ValueError,'number fidelity drift'): self.verify()
    def test_skipped_or_missing_test(self):
        good=log(self.rows)
        for bad in (good+'Test jf4Other() skipped.\n',good.replace('✔ Test '+gate.TESTS[0]+'() passed after 0.001 seconds.\n','')):
            with self.assertRaises(ValueError): gate.verify(bad,GUIDED,positive,self.regression)
    def test_mode_drift(self):
        a=self.verify(); b=copy.deepcopy(a); b['invalid'][0]['issues']=['unexpected']
        with self.assertRaisesRegex(ValueError,'diagnostic mode drift'): gate.stable(a,b)
    def test_swift_syntax(self):
        # Parse complete actual sources; typechecking still belongs to the target lane.
        root=here.parent
        paths=[root/gate.JF4/name for name in ('PreparedGeneration.swift','ArgumentBoundaryTests.swift','DeveloperExperienceTests.swift')]
        paths.append(root/'Tools/FoundationModelsSpike/JF2/ValueBridge.swift')
        for path in paths:
            with self.subTest(path=path.name):
                result=subprocess.run(['swiftc','-frontend','-parse',str(path)],capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)


if __name__=='__main__': unittest.main()
