# SPDX-License-Identifier: Apache-2.0
"""Exact NAV9 prototype identities and compiler receipts, never exit-zero alone."""
import json
import pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
POLICY = json.loads((ROOT / 'Documentation/Qualification/P2Cases.json').read_text())
EXPECTED = frozenset(POLICY['functions'])
SHARED = frozenset(POLICY['shared_functions'])
BORROW_CHECKS = frozenset({'delegate-differential', 'one-admission', 'exact-cumulative-delta',
    'inclusive-work', 'terminal-failure', 'root-state-release', 'inner-comparison-cancellation'})

def check_p2_cases(events, shared=False):
    observed = [n for n in events['function_names'] if n.startswith('JSONInspectionTests.p2')]
    return len(observed) == len(set(observed)) and set(observed) == (SHARED if shared else EXPECTED)

def check_borrow_receipt(data):
    commands = data.get('commands', [])
    names = {config + '-' + name for config in ['debug','release'] for name in
             ['build','path','positive-codegen','escape','send','method','task','external','link','runtime']}
    if data.get('status') != 'passed' or len(commands) != 20 or {c.get('name') for c in commands} != names:
        return False
    for c in commands:
        expected = c.get('expected_diagnostic')
        code = c.get('exit_code')
        if c.get('status') != 'passed' or c.get('compiler_crash') is not False:
            return False
        if expected:
            if not isinstance(code,int) or code <= 0 or not any(expected.lower() in d.lower() for d in c.get('primary_diagnostics', [])):
                return False
        elif code != 0: return False
    outcomes = data.get('runtime_results', {})
    return set(outcomes) == {'debug','release'} and all(len(v)==7 and set(v)==BORROW_CHECKS for v in outcomes.values())


def check_private_receipt(data):
    commands = data.get('commands', [])
    names = {config + '-' + name for config in ['debug','release'] for name in
             ['build','path','positive-codegen','external-set','external-matrix','external-error',
              'set-constructor','matrix-constructor','matrix-mutation','link','runtime']}
    if data.get('status') != 'passed' or len(commands) != 22 or {c.get('name') for c in commands} != names:
        return False
    for c in commands:
        expected = c.get('expected_diagnostic')
        code = c.get('exit_code')
        if c.get('status') != 'passed' or c.get('compiler_crash') is not False: return False
        if expected:
            if not isinstance(code,int) or code <= 0 or not any(expected.lower() in d.lower() for d in c.get('primary_diagnostics', [])): return False
        elif code != 0: return False
    expected = {'set-exact','matrix-exact','zero-shape','typed-refusal','one-admission','independent-read'}
    results = data.get('runtime_results', {})
    return set(results) == {'debug','release'} and all(len(v)==6 and set(v)==expected for v in results.values())
