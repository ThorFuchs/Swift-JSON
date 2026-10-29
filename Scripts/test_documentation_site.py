#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Regress the guide navigator's runtime fetch contract, beyond static HTML links."""
import json
import hashlib
import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

from build_documentation_site import (PRODUCTS, install_guide_navigation_index,
                                      verify_navigation_indexes, verify_site, landing,
                                      observed_release, source_version)
from documentation_release import (API_URL, MAX_METADATA_BYTES, REPOSITORY,
                                   decode_metadata, fetch_metadata, load_metadata, release_metadata)


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
        self.assertIn('Swift-JSON documentation', page)
        self.assertNotIn('Unreleased', page)
        self.assertIn('Explore ' + str(len(PRODUCTS)) + ' Swift libraries', page)
        self.assertIn('/releases/latest', page)
        self.assertIn('This local preview has no observed release metadata.', page)
        self.assertIn('These native DocC references track <code>main</code>', page)
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


class ReleaseMetadataTests(unittest.TestCase):
    def fixture(self, tag='2.4.6'):
        name = 'Swift-JSON-' + tag.removeprefix('v') + '-DocC.tar.gz'
        return {'id': 42, 'tag_name': tag, 'html_url': REPOSITORY + '/releases/tag/' + tag,
                'draft': False, 'prerelease': False, 'published_at': '2026-10-29T09:00:00Z',
                'assets': [{'name': name, 'state': 'uploaded', 'size': 1024,
                            'browser_download_url': REPOSITORY + '/releases/download/' + tag + '/' + name}]}

    def test_observed_version_changes_links_without_source_edits(self):
        for tag in ('2.4.6', 'v3.2.1'):
            with self.subTest(tag=tag):
                release = release_metadata(self.fixture(tag))
                page = landing(None, release)
                self.assertIn('Swift-JSON ' + tag.removeprefix('v'), page)
                self.assertIn(release['release_url'], page)
                self.assertIn(release['source_url'], page)
                self.assertIn(release['documentation_url'], page)
                self.assertNotIn('no observed release metadata', page)

    def test_draft_prerelease_and_unpublished_metadata_rejected(self):
        for field, value in (('draft', True), ('prerelease', True), ('published_at', None), ('draft', None), ('id', True)):
            with self.subTest(field=field, value=value):
                data = self.fixture()
                data[field] = value
                with self.assertRaisesRegex(ValueError, 'published'):
                    release_metadata(data)

    def test_untrusted_tags_and_foreign_release_urls_rejected(self):
        for tag in ('2.4.6-rc.1', 'latest', '../escape', '<script>', '02.4.6'):
            with self.subTest(tag=tag), self.assertRaisesRegex(ValueError, 'stable semantic version'):
                release_metadata(self.fixture(tag))
        data = self.fixture()
        data['html_url'] = 'https://example.com/releases/tag/2.4.6'
        with self.assertRaisesRegex(ValueError, 'this repository'):
            release_metadata(data)

    def test_missing_docc_asset_keeps_tagged_source_without_fabricated_download(self):
        data = self.fixture()
        data['assets'] = []
        release = release_metadata(data)
        self.assertIsNone(release['documentation_url'])
        page = landing(None, release)
        self.assertIn(release['source_url'], page)
        self.assertNotIn('compiled DocC catalogs', page)
        self.assertNotIn('/releases/download/', page)

    def test_ambiguous_unavailable_or_foreign_asset_rejected(self):
        data = self.fixture()
        data['assets'] *= 2
        with self.assertRaisesRegex(ValueError, 'Ambiguous'):
            release_metadata(data)
        for field, value in (('state', 'new'), ('size', 0), ('browser_download_url', 'https://example.com/a.tar.gz')):
            data = self.fixture()
            data['assets'][0][field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'unavailable or has a foreign URL'):
                release_metadata(data)

    def test_snapshot_replay_has_exact_digest_and_finite_input(self):
        raw = (json.dumps(self.fixture(), indent=2) + '\n').encode()
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'release.json'
            path.write_bytes(raw)
            self.assertEqual(load_metadata(path), decode_metadata(raw))
        self.assertEqual(decode_metadata(raw)['metadata_sha256'], hashlib.sha256(raw).hexdigest())
        with self.assertRaisesRegex(ValueError, '2 MiB'):
            decode_metadata(b' ' * (MAX_METADATA_BYTES + 1))
        with self.assertRaises(json.JSONDecodeError):
            decode_metadata(b'{malformed')

    def test_fetch_is_bounded_and_records_actual_response(self):
        raw = json.dumps(self.fixture()).encode()
        response = mock.MagicMock(status=200, url=API_URL)
        response.__enter__.return_value = response
        response.read.return_value = raw
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'snapshot.json'
            with mock.patch.dict(os.environ, {'GITHUB_TOKEN': 'test-read-token'}, clear=True), \
                    mock.patch('documentation_release.urllib.request.build_opener') as opener:
                opener.return_value.open.return_value = response
                result = fetch_metadata(path)
                request = opener.return_value.open.call_args.args[0]
                self.assertEqual(request.full_url, API_URL)
                self.assertEqual(request.get_method(), 'GET')
                self.assertEqual(request.get_header('Authorization'), 'Bearer test-read-token')
                self.assertEqual(opener.return_value.open.call_args.kwargs, {'timeout': 30})
            response.read.assert_called_once_with(MAX_METADATA_BYTES + 1)
            self.assertEqual(path.read_bytes(), raw)
            self.assertEqual(result, load_metadata(path))

    def test_api_failure_never_overwrites_snapshot_with_stale_or_partial_success(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'snapshot.json'
            path.write_bytes(b'preserved previous input')
            with mock.patch('documentation_release.urllib.request.build_opener') as opener:
                opener.return_value.open.side_effect = OSError('HTTP unavailable')
                with self.assertRaises(OSError):
                    fetch_metadata(path)
            self.assertEqual(path.read_bytes(), b'preserved previous input')

    def test_only_unconfigured_local_preview_can_omit_metadata(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(observed_release())
        with mock.patch.dict(os.environ, {'GITHUB_ACTIONS': 'true'}, clear=True):
            with self.assertRaisesRegex(ValueError, 'requires an observed'):
                observed_release()
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.dict(os.environ, {'SWIFT_JSON_RELEASE_METADATA': str(pathlib.Path(directory) / 'missing.json')}, clear=True):
                with self.assertRaises(FileNotFoundError):
                    observed_release()

    def test_source_version_is_independent_of_observed_release(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'Sources/JSONCLIEngine/CLIReleaseVersion.swift'
            path.parent.mkdir(parents=True)
            path.write_text('package enum CLIReleaseVersion {\n    package static let value = "9.8.0-dev"\n}\n')
            with mock.patch('build_documentation_site.ROOT', pathlib.Path(directory)):
                self.assertEqual(source_version(), '9.8.0-dev')
                path.write_text('no version declaration')
                with self.assertRaisesRegex(ValueError, 'Missing or ambiguous'):
                    source_version()


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    passed = result.wasSuccessful() and result.testsRun == 22
    print('DOCUMENTATION_SITE_TESTS ' + ('passed' if passed else 'failed') + ' cases=' + str(result.testsRun))
    sys.exit(0 if passed else 1)
