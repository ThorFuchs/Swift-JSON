#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Guard negative ownership evidence against incidental diagnostics and crashes."""
import unittest
from qualify_transform_ownership import ordinary_rejection


class OwnershipEvidenceTests(unittest.TestCase):
    def test_primary_domain_rejection_is_accepted(self):
        self.assertTrue(ordinary_rejection(1, "case.swift:3:4: error: cannot find type 'FilterVM' in scope", "cannot find type 'FilterVM'"))

    def test_diagnostic_followed_by_crash_is_not_a_pass(self):
        diagnostic = "case.swift:3:4: error: cannot find type 'FilterVM' in scope\n"
        for code, suffix in [(-11, ''), (1, 'Stack dump:'), (1, 'Assertion failed'), (1, 'Please submit a bug report')]:
            with self.subTest(code=code, suffix=suffix):
                self.assertFalse(ordinary_rejection(code, diagnostic + suffix, "cannot find type 'FilterVM'"))

    def test_import_failure_or_note_cannot_replace_primary_error(self):
        for text in ["case.swift:1:1: error: no such module 'JSON'\ncase.swift:3:4: error: cannot find type 'FilterVM' in scope",
                     "case.swift:3:4: error: unrelated failure\ncase.swift:3:4: note: cannot find type 'FilterVM' in scope"]:
            self.assertFalse(ordinary_rejection(1, text, "cannot find type 'FilterVM'"))


if __name__ == '__main__':
    unittest.main()
