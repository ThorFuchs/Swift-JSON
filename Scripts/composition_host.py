#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Low-observer-cost Darwin host admission; no process enumeration during timing.

The SDK's mach/host_info.h defines HOST_CPU_LOAD_INFO=3 and four natural_t
cpu_ticks in USER/SYSTEM/IDLE/NICE order. Preserve raw snapshots in receipts.
All CPU activity, including this observer, remains in the denominator.
"""
import ctypes
import math
import platform
import resource
import time


def interval(before, after):
    if len(before) != 4 or len(after) != 4 or any(type(v) is not int or not 0 <= v < 2**32 for v in [*before, *after]):
        raise ValueError('Invalid HOST_CPU_LOAD_INFO counters')
    delta = [(b-a) % 2**32 for a, b in zip(before, after)]
    if not sum(delta):
        raise ValueError('CPU counters did not advance')
    return {'delta_ticks': delta, 'idle_percent': 100 * delta[2] / sum(delta)}


def admitted(window):
    values = window['interval_idle_percent']
    return len(values) == 3 and all(math.isfinite(v) and 90 <= v <= 100 for v in values)


class DarwinCPU:
    def __init__(self):
        if platform.system() != 'Darwin':
            raise OSError('Darwin host CPU counters required')
        self.lib = ctypes.CDLL('/usr/lib/libSystem.B.dylib')
        self.lib.mach_host_self.restype = ctypes.c_uint32
        self.lib.host_statistics.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(ctypes.c_uint32)]
        self.lib.host_statistics.restype = ctypes.c_int
        self.lib.mach_port_deallocate.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
        self.lib.mach_port_deallocate.restype = ctypes.c_int
        self.port = self.lib.mach_host_self()

    def close(self):
        if self.port:
            code = self.lib.mach_port_deallocate(ctypes.c_uint32.in_dll(self.lib, 'mach_task_self_').value, self.port)
            self.port = 0
            if code:
                raise OSError('mach_port_deallocate failed: '+str(code))

    def snapshot(self):
        ticks = (ctypes.c_uint32 * 4)()
        count = ctypes.c_uint32(4)
        code = self.lib.host_statistics(self.port, 3, ticks, ctypes.byref(count))
        if code or count.value != 4:
            raise OSError('HOST_CPU_LOAD_INFO failed: '+str((code, count.value)))
        return {'monotonic_seconds': time.monotonic(), 'cpu_ticks': list(ticks)}

    def window(self):
        usage = resource.getrusage(resource.RUSAGE_SELF)
        snapshots = [self.snapshot()]
        for _ in range(3):
            time.sleep(1)
            snapshots.append(self.snapshot())
        rows = [interval(a['cpu_ticks'], b['cpu_ticks']) for a, b in zip(snapshots, snapshots[1:])]
        after = resource.getrusage(resource.RUSAGE_SELF)
        return {'method': 'host_statistics(HOST_CPU_LOAD_INFO)', 'snapshots': snapshots,
                'intervals': rows, 'interval_idle_percent': [r['idle_percent'] for r in rows],
                'first_cumulative_snapshot_excluded': True,
                'observer_cpu_seconds': after.ru_utime+after.ru_stime-usage.ru_utime-usage.ru_stime}
