# SPDX-License-Identifier: Apache-2.0
"""One exact discovery contract for native, safety and WASI qualification."""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
DISCOVERY = json.loads((ROOT / 'Documentation/Qualification/TestDiscovery.json').read_text())
ROOT_COUNTS = DISCOVERY['root_functions']
PARAMETER_INVOCATIONS = DISCOVERY['parameterized_invocations']

def check_root(log):
    counts = [int(n) for n in re.findall(r'Test run with (\d+) tests? in[^\n]*passed', log)]
    invocations = sum(int(n) for n in re.findall(r'with (\d+) test cases passed', log))
    return sorted(counts) == sorted(ROOT_COUNTS.values()) and invocations == PARAMETER_INVOCATIONS
