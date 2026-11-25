#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline JF3 receipt checks, not native schema tests."""
import importlib.util
import re
from pathlib import Path
import unittest

here = Path(__file__).parent
spec = importlib.util.spec_from_file_location('jf3', here / 'qualify_foundation_models_schemas.py')
gate = importlib.util.module_from_spec(spec); spec.loader.exec_module(gate)
fidelity = gate.load(here / 'qualify_foundation_models_fidelity.py', 'jf22')


def passes(names):
    return ''.join(f'✔ Test {name}() passed after 0.001 seconds.\n' for name in names) + f'✔ Test run with {len(names)} tests in 0 suites passed after 0.1 seconds.\n'


def fixture():
    return passes(gate.PORTABLE + gate.APPLE) + ''.join(kind + ' ' + raw + '\n' for kind, raw in [('JF3_IMPORT', gate.GUIDED), ('JF3_REVERSE', gate.SIMPLE_AUGMENTED), ('JF3_EXACT', gate.SIMPLE_AUGMENTED)])


class Controls(unittest.TestCase):
    def test_apple_receipts(self):
        result = gate.verify(fixture(), 'apple', fidelity)
        self.assertEqual(len(result['tests']), 11)
        self.assertEqual(len(result['schemas']), 3)

    def test_linux_scope(self):
        self.assertEqual(len(gate.verify(passes(gate.PORTABLE), 'linux', fidelity)['tests']), 8)
        with self.assertRaises(ValueError): gate.verify(fixture(), 'linux', fidelity)

    def test_missing_duplicate_and_wrong_tests(self):
        for names in ((), gate.PORTABLE, gate.PORTABLE + (gate.APPLE[0],)*3):
            with self.assertRaises(ValueError): gate.verify(passes(names), 'apple', fidelity)

    def test_missing_and_duplicate_schema(self):
        line = 'JF3_EXACT ' + gate.SIMPLE_AUGMENTED + '\n'
        for bad in (fixture().replace(line, ''), fixture() + line):
            with self.assertRaisesRegex(ValueError, 'schema receipt'): gate.verify(bad, 'apple', fidelity)

    def test_metadata_drift(self):
        with self.assertRaisesRegex(ValueError, 'unexpected schema receipt'):
            gate.verify(fixture().replace('"x-order":["query"]', '"x-order":[]'), 'apple', fidelity)

    def test_constraint_drift(self):
        for bad in (fixture().replace('"maximum":20', '"maximum":21'), fixture().replace('"additionalProperties":false', '"additionalProperties":true')):
            with self.assertRaisesRegex(ValueError, 'unexpected schema receipt'): gate.verify(bad, 'apple', fidelity)

    def test_skip_not_pass(self):
        for suffix in ('Test jf3Unknown() skipped.\n', 'Test jf3Unknown() passed with a known issue.\n'):
            with self.assertRaises(ValueError): gate.verify(fixture() + suffix, 'apple', fidelity)

    def test_negative_fixtures_are_complete_schema_json(self):
        source = (here.parent / 'Tools/FoundationModelsSpike/JF3/SchemaBridgeTests.swift').read_text()
        section = source.split('// JF3_NEGATIVE_FIXTURES_BEGIN\n')[1].split('// JF3_NEGATIVE_FIXTURES_END')[0]
        expected = {
            'all-of': ('unsupportedDeclaration', 'allOf'),
            'definitions': ('unsupportedDeclaration', '$defs'),
            'pattern-properties': ('unsupportedDeclaration', 'patternProperties'),
            'unknown-annotation': ('unsupportedDeclaration', 'x-custom'),
            'explicit-dialect': ('unsupportedDeclaration', '$schema'),
            'open-object': ('unsupportedShape', 'additionalProperties'),
            'nullable-property': ('unsupportedShape', 'properties'),
            'non-ascii-property': ('unsupportedShape', 'properties'),
            'invalid-order': ('unsupportedShape', 'x-order'),
        }
        seen = set()
        for line in section.splitlines():
            if not line.strip():
                continue
            match = re.fullmatch(r'\s*\("([^"]+)", #"(.*?)"#, \.(\w+)\),', line)
            self.assertIsNotNone(match, line)
            name, raw, reason = match.groups()
            self.assertNotIn(name, seen)
            self.assertIn(name, expected)
            seen.add(name)
            value = fidelity.strict(raw)
            self.assertEqual(value['type'], 'object')
            self.assertEqual(reason, expected[name][0])
            self.assertIn(expected[name][1], value)
            if name == 'nullable-property':
                self.assertEqual(value['properties']['query']['type'], ['string', 'null'])
        self.assertEqual(seen, set(expected))

    def test_raw_numeric_and_scalar_comparison(self):
        self.assertFalse(fidelity.same(fidelity.strict('9007199254740993'), fidelity.strict('9007199254740992')))
        self.assertFalse(fidelity.same(fidelity.strict('true'), fidelity.strict('1')))
        self.assertTrue(fidelity.same(fidelity.strict('20'), fidelity.strict('2e1')))
        self.assertFalse(fidelity.same(fidelity.strict(r'"e\u0301"'), fidelity.strict(r'"\u00e9"')))


if __name__ == '__main__':
    unittest.main()
