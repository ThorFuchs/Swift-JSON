# SPDX-License-Identifier: Apache-2.0
"""One exact discovery contract for native, safety and WASI qualification."""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DISCOVERY = json.loads((ROOT / 'Documentation/Qualification/TestDiscovery.json').read_text())
ROOT_COUNTS = DISCOVERY['portable_root_functions' if sys.platform == 'linux' else 'root_functions']
SHARED_COUNTS = DISCOVERY['portable_shared_state_functions' if sys.platform == 'linux' else 'shared_state_functions']
PARAMETER_INVOCATIONS = DISCOVERY['parameterized_invocations']

def check_root(log):
    counts = [int(n) for n in re.findall(r'Test run with (\d+) tests? in[^\n]*passed', log)]
    invocations = sum(int(n) for n in re.findall(r'with (\d+) test cases passed', log))
    return sorted(counts) == sorted(ROOT_COUNTS.values()) and invocations == PARAMETER_INVOCATIONS

RESTORED_FUNCTIONS = frozenset(json.loads(
    (ROOT / 'Documentation/Qualification/Release1.5.1/Restoration.json').read_text())['restored_function_names'])
if len(RESTORED_FUNCTIONS) != 126:
    raise ValueError('Changed pinned maintenance inventory')

def check_restored(events):
    return RESTORED_FUNCTIONS.issubset(events['function_names'])
