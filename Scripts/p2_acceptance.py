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
             ['build','path','positive-codegen','external-set-reducer','external-matrix-reducer','external-accounting',
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

PUBLIC_POLICY = json.loads((ROOT / 'Documentation/Qualification/ExactProjectionCases.json').read_text())
PUBLIC_FUNCTIONS = frozenset(PUBLIC_POLICY['functions'])
PUBLIC_SHARED = frozenset(PUBLIC_POLICY['shared_functions'])
PUBLIC_CHECKS = frozenset(PUBLIC_POLICY['consumer_checks'])

def check_exact_cases(events, shared=False):
    names = [n for n in events['function_names'] if n.startswith('JSONInspectionTests.exactProjectionPUB')]
    return len(names) == len(set(names)) and set(names) == (PUBLIC_SHARED if shared else PUBLIC_FUNCTIONS)

def check_exact_receipt(data):
    commands = data.get('commands', [])
    results = data.get('consumer_results', {})
    negatives = ['core-import-isolation','forged-set','forged-matrix','representatives-readonly',
                 'dimensions-readonly','source-readonly','context-isolation','meter-isolation',
                 'reducer-isolation','accounting-isolation','wrong-view-operation','no-source-rebinding']
    expected_names = {'address'} | {c+'-'+n for c in ['debug','release'] for n in
        ['build','binpath',*negatives,*['guide-'+str(i)+suffix for i in range(3) for suffix in ['', '-run']]]} | {'debug','release'}
    if data.get('status') != 'passed' or len(commands) != 43 or {c.get('name') for c in commands} != expected_names:
        return False
    if set(results) != {'debug','release','address'}: return False
    for command in commands:
        if command.get('compiler_crash') is not False or command.get('status') != 'passed': return False
        diagnostic = command.get('expected_diagnostic')
        code = command.get('exit_code')
        if diagnostic:
            if not isinstance(code,int) or code <= 0 or not any(diagnostic in d for d in command.get('primary_diagnostics', [])): return False
        elif code != 0: return False
    if len([c for c in commands if c.get('expected_diagnostic')]) != 24: return False
    for result in results.values():
        names = result.get('cases', [])
        if len(names) != 20 or set(names) != PUBLIC_CHECKS: return False
        if not all(isinstance(result.get(k),int) and result[k] > 0 for k in ['work_units','logical_retained_bytes','peak_logical_retained_bytes','admitted_nodes']): return False
        costs = result.get('access_costs', [])
        if len(costs) != 3 or any(len(c)!=6 for c in costs): return False
        try:
            if [int(c[0]) for c in costs] != [0,16,128] or any(int(c[1]) != int(c[0])+7 or int(c[4]) != 0 or int(c[5]) <= 0 for c in costs): return False
            if not int(costs[0][2]) < int(costs[1][2]) < int(costs[2][2]): return False
        except (ValueError,TypeError): return False
    return True
