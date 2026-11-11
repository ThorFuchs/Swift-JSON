#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise Git-free reproduction process completion and timeout handling."""
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import qualify_native_reproduction as reproduction
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

    def test_timeout_remains_primary_when_partial_evidence_copy_fails(self):
        import io
        import json
        import tarfile
        from contextlib import redirect_stdout

        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            data = io.BytesIO()
            with tarfile.open(fileobj=data, mode='w:gz') as archive:
                member = tarfile.TarInfo('Swift-JSON/input')
                member.size = 1
                archive.addfile(member, io.BytesIO(b'x'))

            def make_archive(path, _files):
                path.write_bytes(data.getvalue())

            def timeout(_command, cwd, _stream, timeout):
                (cwd / '.build/ci/native').mkdir(parents=True)
                raise subprocess.TimeoutExpired('native', timeout)

            with patch.object(reproduction, 'ROOT', root), \
                 patch.object(reproduction, 'files', return_value=[]), \
                 patch.object(reproduction, 'archive', side_effect=make_archive), \
                 patch.object(reproduction, 'verify', return_value=1), \
                 patch.object(reproduction, 'run_native', side_effect=timeout), \
                 patch.object(reproduction.shutil, 'copytree', side_effect=OSError('copy failed')), \
                 patch.object(sys, 'argv', ['reproduction', '--output', 'out']), \
                 redirect_stdout(io.StringIO()):
                self.assertEqual(reproduction.main(), 1)
            receipt = json.loads((root / 'out/reproduction.json').read_text())
            self.assertEqual(receipt['status'], 'failed')
            self.assertIn('3300-second limit', receipt['error'])
            self.assertEqual(receipt['followup_error'], 'copy failed')
            self.assertTrue(receipt['commands'][0]['timed_out'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
