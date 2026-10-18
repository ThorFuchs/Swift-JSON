#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Behavior tests for native admission and the matched comparison's rejection paths."""
import copy
import unittest
from unittest.mock import patch
from composition_host import DarwinCPU, admitted, interval
from qualify_composition_performance import NAMES, check_samples, completion_counters


class PerformanceHarnessTests(unittest.TestCase):
    def test_interval_uses_deltas_not_boot_totals(self):
        row = interval([900, 900, 9000, 0], [903, 907, 9090, 0])
        self.assertEqual(row, {'delta_ticks': [3, 7, 90, 0], 'idle_percent': 90})

    def test_natural_counter_wrap_is_preserved(self):
        self.assertEqual(interval([2**32-2, 0, 0, 0], [1, 0, 27, 0])['idle_percent'], 90)

    def test_malformed_or_frozen_counters_are_errors(self):
        for before, after in [([0]*4, [0]*4), ([0]*3, [1]*4), ([0]*4, [True, 0, 1, 0]),
                              ([0]*4, [0, 0, 2**32, 0]), ([0]*4, [0, -1, 2, 0])]:
            with self.assertRaises(ValueError): interval(before, after)

    def test_every_interval_must_meet_unchanged_threshold(self):
        self.assertTrue(admitted({'interval_idle_percent': [90, 90, 90]}))
        for values in [[100, 89.999, 100], [99, 99], [], [99]*4, [100, float('nan'), 100],
                       [100, float('inf'), 100], [100, 101, 100]]:
            self.assertFalse(admitted({'interval_idle_percent': values}))

    def test_window_excludes_initial_snapshot_and_waits_three_intervals(self):
        cpu = object.__new__(DarwinCPU)
        snapshots = [{'cpu_ticks': [900+i, 500+i, 100+i*18, 0]} for i in range(4)]
        with patch.object(cpu, 'snapshot', side_effect=snapshots) as read, patch('composition_host.time.sleep') as sleep:
            window = cpu.window()
        self.assertEqual(read.call_count, 4)
        self.assertEqual(sleep.call_args_list, [unittest.mock.call(1)]*3)
        self.assertEqual(window['interval_idle_percent'], [90]*3)
        self.assertTrue(window['first_cumulative_snapshot_excluded'])

    def test_missing_duplicate_or_changed_workload_is_rejected(self):
        rows = [dict(name=n, iterations=i, seconds=[0.01]*9) for n, i in NAMES.items()]
        check_samples(rows)
        for changed in [rows[:-1], rows+[rows[0]], [dict(r, iterations=1) for r in rows]]:
            with self.assertRaises(ValueError): check_samples(changed)

    def test_nonfinite_or_incomplete_samples_cannot_pass(self):
        rows = [dict(name=n, iterations=i, seconds=[0.01]*9) for n, i in NAMES.items()]
        for value in [0, -1, float('nan'), float('inf')]:
            changed = copy.deepcopy(rows); changed[0]['seconds'][0] = value
            with self.assertRaises(ValueError): check_samples(changed)
        rows[0]['seconds'].pop()
        with self.assertRaises(ValueError): check_samples(rows)

    def test_completion_overlap_does_not_add_disjoint_stage_peaks(self):
        self.assertEqual(completion_counters((10, 1000, 500, 40)), (60, 1000, 924, 40))
        self.assertEqual(completion_counters((10, 1000, 900, 40)), (60, 1324, 1324, 40))


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PerformanceHarnessTests))
    complete = result.wasSuccessful() and result.testsRun == 8
    print('PERFORMANCE_HARNESS '+('passed' if complete else 'failed')+' cases='+str(result.testsRun))
    raise SystemExit(0 if complete else 1)
