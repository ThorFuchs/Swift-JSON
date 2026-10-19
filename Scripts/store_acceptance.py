# SPDX-License-Identifier: Apache-2.0
"""Exact native store identities; premise checks and compiler cases stay separate."""
import json
import pathlib
import re
from test_discovery import DISCOVERY

ROOT = pathlib.Path(__file__).resolve().parents[1]
VECTORS = json.loads((ROOT / 'Tests/JSONInspectionTests/StoreFixtures/VECTORS.json').read_text())['cases']
FUNCTIONS = frozenset(DISCOVERY['store_function_ids'])
SHARED = frozenset({'JSONInspectionTests.storeR06TerminalQuotasNeverPublishAndImmutableConcurrentHealth()'})

def check_store_tests(events, log, shared=False, scoped=False):
    expected = SHARED if shared else FUNCTIONS
    names = [x for x in events['function_names'] if x.startswith('JSONInspectionTests.store')]
    if len(names) != len(set(names)) or set(names) != expected:
        return False
    if scoped and (events['module_function_counts'] != {'JSONInspectionTests': len(expected)} or
                   events['parameterized_functions'] != ({} if shared else {'storeD1NativeVector(id:)': 65}) or
                   events['parameter_case_invocations'] != (0 if shared else 65)):
        return False
    observed = re.findall(r'^STORE_VECTOR (D\d+) passed driver=(\S+) phase=(\S+) kind=(\S+)', log, re.M)
    expected_vectors = [] if shared else [(x['id'], x['execution_kind'], str(x['expected']['phase']), x['expected']['kind'])
        for x in VECTORS if x['execution_kind'] in ('native-build', 'strict-parser')]
    runtime = re.findall(r'^STORE_RUNTIME (R\d+) passed$', log, re.M)
    return sorted(observed) == sorted(expected_vectors) and sorted(runtime) == (['R06'] if shared else ['R%02d' % n for n in range(1,11)])

def check_store_consumer(data):
    commands = data.get('commands', [])
    if data.get('status') != 'passed' or len(commands) != 26 or len({c['name'] for c in commands}) != 26:
        return False
    for c in commands:
        if not c.get('passed') or c.get('compiler_crash') is not False:
            return False
        expected = c.get('expected')
        if expected:
            if c.get('exit', 0) <= 0 or not any(expected.lower() in d.lower() for d in c.get('primary_diagnostics', [])):
                return False
        elif c.get('exit') != 0:
            return False
    results = data.get('vector_compiler_results', [])
    expected = {(i, c) for i in ('D051','D053','D069') for c in ('debug','release')}
    return len(results) == 6 and {(x['id'], x['configuration']) for x in results} == expected and all(
        x.get('passed') and x.get('driver') == 'profile-schema/compiler-negative' for x in results)
