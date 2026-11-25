#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Offline negative controls; no Apple framework or Swift 6.4 claim."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('jf1', Path(__file__).with_name('qualify_foundation_models.py'))
jf1 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jf1)


def manifest_pair():
    before = dict(products=[dict(name=n, targets=[n]) for n in sorted(jf1.PRODUCTS)],
                  targets=[dict(name=n) for n in sorted(jf1.PRODUCTS)], dependencies=[],
                  platforms=[{'options': [], 'platformName': 'macos', 'version': '15.0'},
                             {'options': [], 'platformName': 'ios', 'version': '18.0'}],
                  toolsVersion={'_version': '6.4.0'}, swiftLanguageVersions=['6'],
                  packageKind={'root': ['/baseline']})
    after = copy.deepcopy(before)
    after['packageKind'] = {'root': ['/candidate']}
    after['products'].append(dict(name=jf1.PRODUCT, targets=[jf1.PRODUCT], type={'library': ['automatic']}))
    after['targets'].append(dict(name=jf1.PRODUCT, type='regular', settings=[], resources=[],
                                 dependencies=[{'byName': ['JSON', None]}, {'byName': ['JSONSchema', None]}]))
    return before, after


class Controls(unittest.TestCase):
    def test_exact_graft(self):
        original = '    products: [\n    ],\n    targets: [\n    ],\n'
        result = jf1.graft(original)
        self.assertEqual(result.count('name: "JSONFoundationModels"'), 2)
        self.assertEqual('\n'.join(l for l in result.split('\n') if 'JSONFoundationModels' not in l), original)
        with self.assertRaisesRegex(ValueError, 'anchor'):
            jf1.graft('wrong')

    def test_isolated_manifest(self):
        jf1.inspect_manifests(*manifest_pair())

    def test_existing_target_change_rejected(self):
        b, a = manifest_pair()
        a['targets'][0]['dependencies'] = [{'byName': [jf1.PRODUCT, None]}]
        with self.assertRaisesRegex(ValueError, 'existing product/target'):
            jf1.inspect_manifests(b, a)

    def test_external_dependency_rejected(self):
        b, a = manifest_pair(); a['dependencies'].append({'url': 'external'})
        with self.assertRaisesRegex(ValueError, 'unrelated manifest'):
            jf1.inspect_manifests(b, a)

    def test_floor_change_rejected(self):
        b, a = manifest_pair(); a['platforms'][0]['version'] = '27.0'
        with self.assertRaisesRegex(ValueError, 'unrelated manifest'):
            jf1.inspect_manifests(b, a)

    def test_bridge_dependency_rejected(self):
        b, a = manifest_pair(); a['targets'][-1]['dependencies'][0]['byName'][0] = 'Other'
        with self.assertRaisesRegex(ValueError, 'bridge dependencies'):
            jf1.inspect_manifests(b, a)

    def test_resolver_graph(self):
        g = {'dependencies': [{'identity': 'swift-json', 'dependencies': []}]}
        jf1.assert_resolver_graph(g, 'test')
        g['dependencies'][0]['dependencies'].append({'identity': 'other'})
        with self.assertRaisesRegex(ValueError, 'external resolution'):
            jf1.assert_resolver_graph(g, 'test')

    def test_consumer_products(self):
        plain = jf1.consumer_manifest(Path('/example/Swift-JSON'))
        bridge = jf1.consumer_manifest(Path('/example/Swift-JSON'), True)
        self.assertNotIn(jf1.PRODUCT, plain)
        self.assertIn('.macOS(.v15)', plain)
        self.assertIn(jf1.PRODUCT, bridge)
        self.assertIn('.macOS("27.0")', bridge)

    def test_observations_are_not_passes(self):
        receipt = ''.join(f'JF1_BEGIN {n}\nJF1_END {n} ' + ('REJECTED' if n == 'decimal' else 'OBSERVED') + '\n' for n in jf1.CASES) + 'JF1_PROBE_COMPLETE\n'
        results = jf1.observe(receipt)
        self.assertEqual(results['decimal'], 'REJECTED')
        self.assertEqual(len(results), len(jf1.CASES))
        for bad in (receipt.replace('JF1_BEGIN decimal\n', ''), receipt + receipt, receipt.replace('JF1_PROBE_COMPLETE\n', ''), receipt.replace('OBSERVED', 'PASS')):
            with self.subTest(bad=bad[-40:]), self.assertRaises(ValueError):
                jf1.observe(bad)


if __name__ == '__main__':
    unittest.main()
