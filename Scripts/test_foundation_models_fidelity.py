#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline receipt controls only. No FoundationModels execution here."""
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('jf22', Path(__file__).with_name('qualify_foundation_models_fidelity.py'))
gate = importlib.util.module_from_spec(spec); spec.loader.exec_module(gate)


def line(kind, row):
    return kind + ' ' + json.dumps(row, ensure_ascii=True, separators=(',', ':')) + '\n'


def fixture():
    # Synthetic passing receipt: historical anchor observations + representative
    # new cases, not predictions or fabricated native evidence.
    changed = {'root-safe-above': '9007199254740992', 'root-int64-max': '9223372036854776000',
               'root-precise-decimal': '0.12345678901234568', 'unicode-keys': '{"é":1}'}
    log = ''
    for name, source in gate.vectors().items():
        if name == 'root-small-exponent':
            log += line('JF22_VALUE', dict(id=name, source=source, exportOutcome='frameworkRejected', importOutcome='notAttempted'))
            continue
        complete, equal = gate.ANCHORS.get(name, (True, True))
        raw = changed.get(name, source)
        log += line('JF22_RAW ' + name, raw)
        log += line('JF22_VALUE', dict(id=name, source=source, raw=raw, complete=complete, equal=equal,
                                     exportOutcome='incompleteContent' if not complete else 'accepted' if equal else 'changedValue',
                                     importOutcome='accepted' if complete else 'incompleteContent'))
    schema = json.loads('{"title":"JF22GuidedArguments","type":"object","properties":{"query":{"type":"string","description":"Search query"},"limit":{"type":"integer","minimum":1,"maximum":20},"sort":{"type":"string","enum":["date","title"]},"tags":{"type":"array","items":{"type":"string"},"minItems":2,"maxItems":2},"note":{"type":"string"}},"required":["query","limit","sort","tags"],"x-order":["query","limit","sort","tags","note"],"additionalProperties":false}')
    log += line('JF22_SCHEMA', schema)
    for name, (source, verdict) in gate.guide_cases().items():
        log += line('JF22_GUIDE', dict(id=name, source=json.dumps(source, default=int), expected=verdict, actual=verdict))
    log += line('JF22_TYPED', dict(source='{"query":"test","limit":2,"sort":"date","tags":["a","b"],"note":null}',
                                 returned='{"query":"test","limit":2,"sort":"date","tags":["a","b"]}',
                                 inputValid=False, outputValid=True, equal=False))
    log += ''.join(f'✔ Test {name}() passed after 0.001 seconds.\n' for name in gate.OLD_TESTS + gate.NEW_TESTS)
    return log + '✔ Test run with 14 tests in 0 suites passed after 0.02 seconds.\n'


def change(log, kind, name, **updates):
    lines = log.splitlines(keepends=True)
    for i, text in enumerate(lines):
        if text.startswith(kind + ' '):
            row = json.loads(text[len(kind) + 1:])
            if name is None or row.get('id') == name:
                row.update(updates); lines[i] = line(kind, row)
                return ''.join(lines)
    raise AssertionError('missing synthetic row')


class Controls(unittest.TestCase):
    def setUp(self):
        self.log = fixture()

    def test_complete_matrix(self):
        result = gate.verify(self.log)
        self.assertEqual(len(result['values']), 52)
        self.assertEqual(len(result['guides']), 14)
        self.assertEqual(len(result['tests']), 14)
        gate.stable(result, gate.verify(self.log))

    def test_exact_semantics(self):
        for a, b in [('true', '1'), ('9007199254740992', '9007199254740993'), ('{"a":null}', '{}'),
                     (r'"e\u0301"', r'"\u00e9"'), ('[1,2]', '[2,1]')]:
            self.assertFalse(gate.same(gate.strict(a), gate.strict(b)))
        self.assertTrue(gate.same(gate.strict('{"a":1.00,"b":2}'), gate.strict('{"b":2,"a":1e0}')))
        for text in ['NaN', '{"x":1,"x":2}']:
            with self.assertRaises(ValueError): gate.strict(text)

    def test_missing_and_duplicate_rows(self):
        row = next(l for l in self.log.splitlines(keepends=True) if l.startswith('JF22_VALUE '))
        for altered in (self.log.replace(row, '', 1), self.log + row):
            with self.assertRaises(ValueError): gate.verify(altered)

    def test_raw_mismatch(self):
        with self.assertRaisesRegex(ValueError, 'raw receipt mismatch'):
            gate.verify(change(self.log, 'JF22_VALUE', 'ordinary', raw='{}'))

    def test_false_equality(self):
        with self.assertRaisesRegex(ValueError, 'exact equality mismatch'):
            gate.verify(change(self.log, 'JF22_VALUE', 'unicode-keys', equal=True))

    def test_export_and_import_policy(self):
        for key, value, name in [('exportOutcome','accepted','unicode-keys'), ('exportOutcome','changedValue','root-safe-above'),
                                 ('importOutcome','accepted','root-large-exponent')]:
            with self.assertRaisesRegex(ValueError, 'policy violation'):
                gate.verify(change(self.log, 'JF22_VALUE', name, **{key: value}))

    def test_historical_drift(self):
        with self.assertRaisesRegex(ValueError, 'historical SDK behavior drift'):
            gate.verify(change(self.log, 'JF22_VALUE', 'root-large-exponent', complete=True, exportOutcome='accepted', importOutcome='accepted'))

    def test_guide_isolation(self):
        for updates in ({'actual': True}, {'source': '{"query":"test","limit":21,"sort":"date","tags":["a","b"],"note":null}'}):
            with self.assertRaisesRegex(ValueError, 'isolated guide verdict mismatch'):
                gate.verify(change(self.log, 'JF22_GUIDE', 'range-high', **updates))

    def test_schema_annotation_drift(self):
        with self.assertRaisesRegex(ValueError, 'observed guide schema drift'):
            gate.verify(change(self.log, 'JF22_SCHEMA', None, **{'x-order': []}))

    def test_typed_observation_drift(self):
        with self.assertRaisesRegex(ValueError, 'typed optionality observation drift'):
            gate.verify(change(self.log, 'JF22_TYPED', None, equal=True))

    def test_test_set_and_skip(self):
        missing = self.log.replace('✔ Test jf22AppleGuideValidation() passed after 0.001 seconds.\n', '')
        for altered in (missing, self.log + 'Test jf22Other() skipped.\n'):
            with self.assertRaises(ValueError): gate.verify(altered)

    def test_mode_drift(self):
        a, b = gate.verify(self.log), gate.verify(self.log)
        b['values']['object-one']['exportOutcome'] = 'changedValue'
        with self.assertRaisesRegex(ValueError, 'disposition drift'): gate.stable(a, b)


if __name__ == '__main__':
    unittest.main()
