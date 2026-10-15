#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify compiler crash classification independently of the Swift fixtures."""
import unittest
from qualify_composition import compiler_outcome

class CompilerHarnessTests(unittest.TestCase):
    def test_expected_rejection(self):
        self.assertEqual(compiler_outcome(1, "error: borrowed", False, 'borrowed'), 'rejected')

    def test_missing_module_never_rejects(self):
        self.assertEqual(compiler_outcome(1, "no such module JSON; borrowed", False, 'borrowed'), 'failed')

    def test_signal_is_not_rejection(self):
        self.assertEqual(compiler_outcome(-6, "borrowed", False, 'borrowed'), 'compiler_abort')

    def test_fatal_diagnostic_is_not_rejection(self):
        self.assertEqual(compiler_outcome(1, "borrowed; fatal error encountered during compilation", False, 'borrowed'), 'compiler_abort')

    def test_stack_dump_is_not_rejection(self):
        self.assertEqual(compiler_outcome(1, "borrowed; Stack dump:", False, 'borrowed'), 'compiler_abort')

    def test_negative_cannot_emit_object(self):
        self.assertEqual(compiler_outcome(1, "error: borrowed", True, 'borrowed'), 'failed')

    def test_positive_requires_emission(self):
        self.assertEqual(compiler_outcome(0, '', True), 'compiled')
        self.assertEqual(compiler_outcome(0, '', False), 'failed')

    def test_unrelated_error_is_not_rejection(self):
        self.assertEqual(compiler_outcome(1, "error: invalid syntax", False, 'borrowed'), 'failed')

if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CompilerHarnessTests)
    result = unittest.TextTestRunner().run(suite)
    passed = result.wasSuccessful() and result.testsRun == 8 and not result.skipped
    if passed: print('COMPOSITION_COMPILER_HARNESS passed cases=8')
    raise SystemExit(0 if passed else 1)
