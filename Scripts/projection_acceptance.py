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
