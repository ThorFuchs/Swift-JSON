#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Focused adversarial checks for the kit's packaging and source boundaries."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
from validate_developer_kit import files, read_archive, safe_name, validate_plugin
from package_developer_kit import archive


class KitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="swift-json-kit-test-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.plugin = self.folder / "plugin"
        shutil.copytree(ROOT / "plugins/swift-json", self.plugin)

    def manifest(self, transform):
        path = self.plugin / "plugin.json"
        data = json.loads(path.read_text())
        transform(data)
        path.write_text(json.dumps(data))

    def test_canonical_manifest_and_links(self):
        result = validate_plugin(self.plugin)
        self.assertEqual(result["recipes"], 8)
        self.assertEqual(result["skill_files"], 10)

    def test_service_component_is_rejected(self):
        self.manifest(lambda x: x.update(hooks="./hooks.json"))
        with self.assertRaisesRegex(ValueError, "component"):
            validate_plugin(self.plugin)

    def test_compatibility_skill_field_is_not_portable_metadata(self):
        self.manifest(lambda x: x.update(skills="./skills"))
        with self.assertRaisesRegex(ValueError, "component"):
            validate_plugin(self.plugin)

    def test_kit_version_drift_is_rejected(self):
        self.manifest(lambda x: x.update(version="0.2.0"))
        with self.assertRaisesRegex(ValueError, "identity"):
            validate_plugin(self.plugin)

    def test_changed_recipe_cannot_keep_old_hash(self):
        path = self.plugin / "skills/swift-json/assets/consumer/Sources/Consumer/Consumer.swift"
        path.write_text(path.read_text() + "\n// changed consumer\n")
        with self.assertRaisesRegex(ValueError, "stale local source map"):
            validate_plugin(self.plugin)

    def test_broken_reference_is_rejected(self):
        path = self.plugin / "skills/swift-json/references/semantics.md"
        path.write_text(path.read_text() + "\n[Missing](absent.md)\n")
        with self.assertRaisesRegex(ValueError, "broken/escaping"):
            validate_plugin(self.plugin)

    def test_private_marker_is_rejected(self):
        path = self.plugin / "skills/swift-json/references/semantics.md"
        path.write_text(path.read_text() + "\n/private/tmp/private-fixture\n")
        with self.assertRaisesRegex(ValueError, "private marker"):
            validate_plugin(self.plugin)

    def test_escaping_symlink_is_rejected(self):
        (self.plugin / "secret").symlink_to(self.folder.parent)
        with self.assertRaisesRegex(ValueError, "symlink"):
            validate_plugin(self.plugin)

    def test_traversing_and_platform_paths_are_rejected(self):
        for name in ["../secret", "/secret", "x/../../secret", "x//file", "C:/file", "x\\file", "x/./file"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                safe_name(name)

    def test_zip_symlink_is_rejected(self):
        path = self.folder / "symlink.zip"
        with zipfile.ZipFile(path, "w") as out:
            entry = zipfile.ZipInfo("swift-json/link")
            entry.create_system = 3
            entry.external_attr = 0o120777 << 16
            out.writestr(entry, "../../outside")
        with self.assertRaisesRegex(ValueError, "non-regular"):
            read_archive(path)

    def test_zip_traversal_is_rejected_before_extraction(self):
        path = self.folder / "traversal.zip"
        with zipfile.ZipFile(path, "w") as out:
            out.writestr("../outside", "data")
        with self.assertRaisesRegex(ValueError, "unsafe archive path"):
            read_archive(path)

    def test_rebuild_and_canonical_skill_identity(self):
        plugin_files = {"swift-json/" + p: b for p, b in files(self.plugin).items()}
        skill_files = {"swift-json/" + p: b for p, b in files(self.plugin / "skills/swift-json").items()}
        a, b, c = [self.folder / name for name in ("plugin-a.zip", "plugin-b.zip", "skill.zip")]
        archive(a, plugin_files)
        archive(b, plugin_files)
        archive(c, skill_files)
        self.assertEqual(a.read_bytes(), b.read_bytes())
        pa, sa = read_archive(a), read_archive(c)
        self.assertEqual(pa, plugin_files)
        self.assertEqual(sa, skill_files)
        for p, data in skill_files.items():
            self.assertEqual(data, pa[p.replace("swift-json/", "swift-json/skills/swift-json/", 1)])

    def test_archive_replacement_is_refused(self):
        path = self.folder / "existing.zip"
        path.write_bytes(b"preserved")
        with self.assertRaisesRegex(ValueError, "replace"):
            archive(path, {})
        self.assertEqual(path.read_bytes(), b"preserved")


if __name__ == "__main__":
    unittest.main(verbosity=2)
