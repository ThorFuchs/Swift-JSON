#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Regress the guide navigator's runtime fetch contract, beyond static HTML links."""
import json
import pathlib
import sys
import tempfile
import unittest

from build_documentation_site import (PRODUCTS, install_guide_navigation_index,
                                      verify_navigation_indexes, verify_site, landing, SOURCE_VERSION, STABLE_VERSION)


class GuideNavigationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.site = pathlib.Path(self.directory.name)
        for product in PRODUCTS:
            root = self.site / product
            routes = ['/documentation/' + product.lower(), '/documentation/documentation/guide']
            for route in routes:
                page = root / route.lstrip('/') / 'index.html'
                page.parent.mkdir(parents=True)
                page.write_text('<!doctype html><title>Fixture</title>')
            index = {'includedArchiveIdentifiers': ['org.swift-json.' + product],
                     'interfaceLanguages': {'swift': [
                         {'title': product, 'type': 'module', 'path': routes[0], 'children': [
                             {'title': 'Guide', 'type': 'article', 'path': routes[1]}]}]}}
            path = root / 'index/index.json'
            path.parent.mkdir()
            path.write_text(json.dumps(index) + '\n')
            install_guide_navigation_index(root, product)
        self.native = self.site / 'JSON/index/index.json'
        self.alias = self.site / 'JSON/index/documentation/index.json'

    def mutate_native(self, mutate):
        index = json.loads(self.native.read_text())
        mutate(index)
        self.native.write_text(json.dumps(index))
        self.alias.write_bytes(self.native.read_bytes())

    def test_all_catalogs_keep_native_bytes_and_existing_files(self):
        before = {p.relative_to(self.site): p.read_bytes() for p in self.site.rglob('*') if p.is_file()}
        page = landing('2b24f47e7405821240cf8dfc66b840c9a7f8efa5')
        self.assertIn('Unreleased ' + SOURCE_VERSION + ' documentation', page)
        self.assertIn('Explore ' + str(len(PRODUCTS)) + ' Swift libraries', page)
        self.assertIn('/releases/tag/' + STABLE_VERSION, page)
        self.assertIn('/tree/' + STABLE_VERSION + '/Sources', page)
        self.assertIn('Development main includes JSONInspection', page)
        records = verify_navigation_indexes(self.site)
        self.assertEqual({r['product'] for r in records}, set(PRODUCTS))
        for product in PRODUCTS:
            install_guide_navigation_index(self.site / product, product)
            self.assertEqual((self.site / product / 'index/index.json').read_bytes(),
                             (self.site / product / 'index/documentation/index.json').read_bytes())
        self.assertEqual(before, {p.relative_to(self.site): p.read_bytes()
                                  for p in self.site.rglob('*') if p.is_file()})

    def test_missing_native_index_rejected(self):
        self.native.unlink()
        with self.assertRaises(FileNotFoundError):
            verify_navigation_indexes(self.site)

    def test_malformed_native_index_rejected(self):
        self.native.write_text('{broken')
        with self.assertRaises(json.JSONDecodeError):
            install_guide_navigation_index(self.site / 'JSON', 'JSON')

    def test_foreign_catalog_rejected_even_with_equal_alias(self):
        self.mutate_native(lambda x: x.update(includedArchiveIdentifiers=['org.swift-json.JSONSchema']))
        with self.assertRaisesRegex(ValueError, 'catalog differs'):
            verify_navigation_indexes(self.site)

    def test_wrong_swift_root_rejected(self):
        self.mutate_native(lambda x: x['interfaceLanguages'].update(swift=[]))
        with self.assertRaisesRegex(ValueError, 'Swift navigation root'):
            verify_navigation_indexes(self.site)

    def test_missing_guide_index_fails_despite_valid_html(self):
        self.alias.unlink()
        self.assertEqual(verify_site(self.site), 0)  # The old static check missed this defect.
        with self.assertRaises(FileNotFoundError):
            verify_navigation_indexes(self.site)

    def test_stale_alias_rejected_even_when_json_is_equivalent(self):
        self.alias.write_text(json.dumps(json.loads(self.native.read_text()), indent=2))
        with self.assertRaisesRegex(ValueError, 'differs from native bytes'):
            verify_navigation_indexes(self.site)

    def test_other_products_alias_rejected(self):
        self.alias.write_bytes((self.site / 'JSONSchema/index/index.json').read_bytes())
        with self.assertRaisesRegex(ValueError, 'differs from native bytes'):
            verify_navigation_indexes(self.site)

    def test_missing_indexed_route_rejected(self):
        (self.site / 'JSON/documentation/documentation/guide/index.html').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing or escaping navigation route'):
            verify_navigation_indexes(self.site)

    def test_guide_missing_from_index_rejected(self):
        self.mutate_native(lambda x: x['interfaceLanguages']['swift'][0].update(children=[]))
        with self.assertRaisesRegex(ValueError, 'Missing authored guides'):
            verify_navigation_indexes(self.site)

    def test_escaping_indexed_route_rejected(self):
        self.mutate_native(lambda x: x['interfaceLanguages']['swift'][0]['children'][0].update(
            path='/documentation/../../outside'))
        with self.assertRaisesRegex(ValueError, 'Missing or escaping navigation route'):
            verify_navigation_indexes(self.site)

    def test_symlink_alias_rejected(self):
        self.alias.unlink()
        self.alias.symlink_to(self.native)
        with self.assertRaisesRegex(ValueError, 'differs from native bytes'):
            verify_navigation_indexes(self.site)
        with self.assertRaisesRegex(ValueError, 'Symlink guide navigation index'):
            install_guide_navigation_index(self.site / 'JSON', 'JSON')


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(GuideNavigationTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    passed = result.wasSuccessful() and result.testsRun == 12
    print('DOCUMENTATION_SITE_TESTS ' + ('passed' if passed else 'failed') + ' cases=' + str(result.testsRun))
    sys.exit(0 if passed else 1)
