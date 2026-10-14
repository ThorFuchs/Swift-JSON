# SPDX-License-Identifier: Apache-2.0
"""Count completed Swift Testing ABI events, independently of human console summaries."""
import collections
import json

ROOT_PARAMETER_CASES = {
    'cliEveryCounterHasInclusiveCheckedBoundaryAndTerminalFailure(metric:)': 16,
    'cliCompilerEnforcesCapsAtActualSourceTokenAndIRGrowth(metric:)': 4,
    'cliQueryManyTinyRecordsDoNotRetainTheWholeInputJob(records:)': 2,
    'cliConflictingAndUnknownOptionsReject(argv:)': 4,
    'equivalentDecimalSpellings(text:)': 4, 'inclusiveAdmission(attempt:)': 3,
    'numberGrammarIsStrict(text:)': 10, 'exactDivisibilityUsesDecimalMathematics(a:b:expected:)': 6,
    'strictArrayIndexGrammar(text:)': 5, 'malformedUTF8(bytes:)': 4,
    'invalidPointerEscapes(text:)': 4, 'invalidCancellationConfiguration(quantum:)': 3,
    'strictMalformedInput(text:)': 10, 'negativeZeroHasOneIdentity(text:)': 3,
    'everyByteSplitUsesIdenticalGrammar(text:)': 4, 'malformedRootArrayNeverCompletes(text:)': 6,
    'streamEverySplitAgreesWithNativeParser(text:)': 3,
    'successfulAlternativesCannotSwallowRegexExhaustion(keyword:)': 3,
    'URIIdentityUsesSyntaxNormalizationWithoutUnicodeFolding(input:expected:)': 9,
    'malformedRegexGrammarIsACompilationFailure(pattern:)': 12,
    'unknownOrMisspelledPropertyNamesFailCompilation(pattern:)': 10,
    'nativeRegexScalarPortVectors(pattern:subject:expected:)': 10,
    'pinnedUnicodePropertiesAndIdentifierNames(pattern:subject:expected:)': 21,
    'scalarBacktrackingSemantics(pattern:subject:expected:)': 43,
}


def read_events(text):
    tests = {}
    suites = {}
    started = collections.Counter()
    ended = collections.Counter()
    case_started = collections.Counter()
    case_ended = collections.Counter()
    runs = collections.Counter()
    records = 0
    # JSONL delimiters are LF, not Unicode line separators inside valid strings.
    for line in text.split('\n'):
        if not line:
            continue
        row = json.loads(line)
        records += 1
        payload = row['payload']
        kind = payload['kind']
        if row['kind'] == 'test':
            if kind in ('function', 'suite'):
                identifier = payload['id']
                if identifier in tests or identifier in suites:
                    raise ValueError('Duplicate test discovery')
                (tests if kind == 'function' else suites)[identifier] = payload
        elif row['kind'] == 'event':
            if kind in ('issueRecorded', 'testSkipped'):
                raise ValueError('Issue or skipped test in event stream')
            if kind in ('runStarted', 'runEnded'):
                runs[kind] += 1
            elif kind in ('testStarted', 'testEnded', 'testCaseStarted', 'testCaseEnded'):
                identifier = payload['testID']
                if payload.get('iteration', 1) != 1:
                    raise ValueError('Unexpected repeated test iteration')
                table = {'testStarted': started, 'testEnded': ended,
                         'testCaseStarted': case_started, 'testCaseEnded': case_ended}[kind]
                table[identifier] += 1
    identifiers = set(tests)
    all_identifiers = identifiers | set(suites)
    if not identifiers or set(started) != all_identifiers or set(ended) != all_identifiers:
        raise ValueError('Missing discovered/start/completed function identity')
    if any(started[k] != 1 or ended[k] != 1 for k in all_identifiers):
        raise ValueError('Duplicate function or suite execution')
    if any(not any(k.startswith(s + '/') or k.startswith(s + '.') for k in identifiers) for s in suites):
        raise ValueError('Suite contains no discovered function')
    if runs['runStarted'] == 0 or runs['runStarted'] != runs['runEnded']:
        raise ValueError('Incomplete test run')
    if case_started != case_ended:
        raise ValueError('Incomplete parameterized case execution')
    parameter_ids = {k for k, v in tests.items() if v.get('isParameterized', False)}
    if set(case_ended) != parameter_ids:
        raise ValueError('Parameterized discovery/completion mismatch')
    modules = collections.Counter(k.split('.')[0] for k in identifiers)
    parameters = {tests[k]['name']: case_ended[k] for k in parameter_ids}
    if len(parameters) != len(parameter_ids):
        raise ValueError('Ambiguous parameterized function name')
    return {'event_records': records, 'module_function_counts': dict(sorted(modules.items())),
            'bundle_counts': sorted(modules.values()), 'function_count': len(identifiers), 'suite_count': len(suites),
            'parameter_case_invocations': sum(case_ended.values()),
            'parameterized_functions': dict(sorted(parameters.items()))}
