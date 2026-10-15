#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify compiler crash classification independently of the Swift fixtures."""
import unittest
from qualify_composition import compiler_outcome

class CompilerHarnessTests(unittest.TestCase):
    def test_expected_rejection(self):
        log = "/tmp/swift-json/Escape.swift:2:17: error: 'scope' cannot be captured by an escaping closure since it is a borrowed parameter"
        self.assertEqual(compiler_outcome(1, log, False, 'borrowed', 'Escape.swift'), 'rejected')

    def test_module_cache_keyword_is_not_an_ownership_rejection(self):
        log = """<unknown>:0: error: unable to open output file 'SwiftShims.pcm': 'Operation not permitted'
Swift.swiftinterface:5:8: error: could not build Objective-C module 'SwiftShims'
Swift.swiftinterface:3:1: note: compiler flags include -enable-experimental-feature BitwiseCopyable
"""
        self.assertEqual(compiler_outcome(1, log, False, 'Copyable', 'RootCopy.swift'), 'failed')

    def test_expected_keyword_in_source_note_is_not_an_error(self):
        log = """/tmp/RootCopy.swift:3:8: note: expected Copyable ownership rule
Swift.swiftinterface:3:1: note: BitwiseCopyable
"""
        self.assertEqual(compiler_outcome(1, log, False, 'Copyable', 'RootCopy.swift'), 'failed')

    def test_missing_module_never_rejects(self):
        log = "/tmp/Escape.swift:2:17: error: no such module JSON; scope is borrowed"
        self.assertEqual(compiler_outcome(1, log, False, 'borrowed', 'Escape.swift'), 'failed')

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
        log = "/tmp/Escape.swift:2:17: error: invalid syntax"
        self.assertEqual(compiler_outcome(1, log, False, 'borrowed', 'Escape.swift'), 'failed')

if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(CompilerHarnessTests)
    result = unittest.TextTestRunner().run(suite)
    passed = result.wasSuccessful() and result.testsRun == 10 and not result.skipped
    if passed: print('COMPOSITION_COMPILER_HARNESS passed cases=10')
    raise SystemExit(0 if passed else 1)
