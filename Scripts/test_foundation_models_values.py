#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline runner controls; not Swift or Foundation Models test results."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('jf2', Path(__file__).with_name('qualify_foundation_models_values.py'))
jf2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jf2)


def pair():
    before = dict(products=[dict(name=n, targets=[n]) for n in sorted(jf2.jf1.PRODUCTS)],
                  targets=[dict(name=n) for n in sorted(jf2.jf1.PRODUCTS)], dependencies=[],
                  platforms=[{'options': [], 'platformName': 'macos', 'version': '15.0'},
                             {'options': [], 'platformName': 'ios', 'version': '18.0'}],
                  toolsVersion={'_version': '6.4.0'}, swiftLanguageVersions=['6'])
    after = copy.deepcopy(before)
    after['products'].append(dict(name=jf2.jf1.PRODUCT, targets=[jf2.jf1.PRODUCT], type={'library': ['automatic']}))
    after['targets'].append(dict(name=jf2.jf1.PRODUCT, type='regular', settings=[], resources=[],
                                 dependencies=[{'byName': ['JSON', None]}, {'byName': ['JSONSchema', None]}]))
    after['targets'].append(dict(name=jf2.TEST_TARGET, type='test', settings=[], resources=[],
                                 dependencies=[{'byName': ['JSON', None]}, {'byName': [jf2.jf1.PRODUCT, None]}]))
    return before, after


def receipt(names):
    return ''.join(f'✔ Test {n}() passed after 0.001 seconds.\n' for n in names) + f'✔ Test run with {len(names)} tests in 0 suites passed after 0.002 seconds.\n'


class Controls(unittest.TestCase):
    def test_graft(self):
        source = '    products: [\n    ],\n    targets: [\n    ],\n'
        grafted = jf2.graft(source)
        self.assertEqual(grafted.count('.testTarget(name: "JSONFoundationModelsTests"'), 1)
        self.assertEqual('\n'.join(l for l in grafted.split('\n') if 'JSONFoundationModels' not in l), source)

    def test_valid_manifest(self):
        jf2.inspect_manifests(*pair())

    def test_unexpected_test_target(self):
        b, a = pair(); a['targets'][-1]['dependencies'][0]['byName'][0] = 'Unrelated'
        with self.assertRaisesRegex(ValueError, 'test target dependencies'):
            jf2.inspect_manifests(b, a)

    def test_existing_contract_protected(self):
        b, a = pair(); a['platforms'][0]['version'] = '27.0'
        with self.assertRaisesRegex(ValueError, 'unrelated manifest'):
            jf2.inspect_manifests(b, a)

    def test_real_test_sets_required(self):
        self.assertEqual(len(jf2.verify_test_log(receipt(jf2.PORTABLE), 'linux')), 8)
        self.assertEqual(len(jf2.verify_test_log(receipt(jf2.PORTABLE + jf2.APPLE), 'apple')), 10)

    def test_zero_missing_or_duplicate_tests_rejected(self):
        for names in ((), jf2.PORTABLE, jf2.PORTABLE + (jf2.APPLE[0], jf2.APPLE[0])):
            with self.subTest(names=names), self.assertRaises(ValueError):
                jf2.verify_test_log(receipt(names), 'apple')

    def test_skips_and_known_issues_rejected(self):
        original = receipt(jf2.PORTABLE)
        for suffix in ('✘ Test jf2Other() skipped.\n', 'Test jf2Other() passed with a known issue.\n'):
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                jf2.verify_test_log(original + suffix, 'linux')


if __name__ == '__main__':
    unittest.main()
