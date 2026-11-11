#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise Git-free reproduction process completion and timeout handling."""
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest

from qualify_native_reproduction import run_native


class NativeReproductionTimeoutTests(unittest.TestCase):
    def test_preserves_success_and_failure_exit_codes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            with (root / 'log').open('w') as stream:
                for code in (0, 7):
                    self.assertEqual(run_native([sys.executable, '-c', f'raise SystemExit({code})'],
                                                root, stream, 5), code)

    def test_timeout_stops_a_child_before_it_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            marker = root / 'late-write'
            ready = root / 'child-ready'
            child = ('import pathlib,sys,time; pathlib.Path(sys.argv[1]).write_text("ready"); '
                     'time.sleep(2.5); pathlib.Path(sys.argv[2]).write_text("late")')
            parent = ('import subprocess,sys,time; '
                      'subprocess.Popen([sys.executable,"-c",sys.argv[1],sys.argv[2],sys.argv[3]]); '
                      'time.sleep(10)')
            with (root / 'log').open('w') as stream:
                with self.assertRaises(subprocess.TimeoutExpired):
                    run_native([sys.executable, '-c', parent, child, str(ready), str(marker)],
                               root, stream, 1)
            self.assertTrue(ready.exists(), 'child must start before the timeout')
            time.sleep(2.6)
            self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
