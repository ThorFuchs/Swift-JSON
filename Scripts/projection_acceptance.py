# SPDX-License-Identifier: Apache-2.0
"""Pin the full private proof identities, not a blanket nonzero/exit-zero gate."""
import json
import pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
EXPECTED = frozenset(json.loads((ROOT / 'Documentation/Qualification/ProjectionCases.json').read_text())['functions'])
SHARED = frozenset({'JSONInspectionTests.projectionP16SharedViewsHaveIndependentHealthAndLegacyStatistics()'})
def check_projection_cases(events, shared=False):
    observed = [name for name in events['function_names'] if name.startswith('JSONInspectionTests.projectionP')]
    return len(observed) == len(set(observed)) and set(observed) == (SHARED if shared else EXPECTED)

PUBLIC_CHECKS = frozenset(json.loads((ROOT / 'Documentation/Qualification/ProjectionCases.json').read_text())['public_consumer_checks'])

def check_public_projection_receipt(data):
    commands = data.get('commands', [])
    results = data.get('consumer_results', {})
    if (data.get('status') != 'passed' or len(commands) != 37
            or len({c.get('name') for c in commands}) != 37
            or set(results) != {'debug', 'release', 'address'}):
        return False
    if not all(c.get('status') == 'passed' and c.get('compiler_crash') is False for c in commands):
        return False
    negatives = [c for c in commands if c.get('expected_diagnostic')]
    if len(negatives) != 18 or not all(c['exit_code'] > 0 and any(
            c['expected_diagnostic'] in d for d in c['primary_diagnostics']) for c in negatives):
        return False
    if not all(c['exit_code'] == 0 for c in commands if not c.get('expected_diagnostic')):
        return False
    for result in results.values():
        cases = result.get('cases', [])
        if len(cases) != 16 or len(set(cases)) != 16 or set(cases) != PUBLIC_CHECKS:
            return False
        if not all(isinstance(result.get(k), int) and result[k] > 0 for k in
                   ['work_units', 'logical_retained_bytes', 'peak_logical_retained_bytes', 'admitted_nodes']):
            return False
    return True
