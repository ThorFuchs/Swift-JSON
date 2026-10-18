#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Execute public native CI lanes with command, source and environment receipts."""
import argparse, datetime, hashlib, json, os, pathlib, re, subprocess, sys
from archive_candidate import files
from preflight import collect, collect_linux
from testing_events import read_events, ROOT_PARAMETER_CASES
from test_discovery import DISCOVERY, ROOT_COUNTS, SHARED_COUNTS, PARAMETER_INVOCATIONS, check_restored

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHARED_TESTS = 'independentCodecFacadesAndExactValuesCanBeSharedAcrossTasks|concurrentSchemaEvaluationsHaveExclusiveDynamicRegexAndAnnotationState|sharedRegexProgramHasExclusiveConcurrentSearchState|immutableIndexedObjectCanBeSharedAcrossTasks|qaSharedPayloadAndRootHaveIndependentConcurrentReadScopes|sha256InputCapacityAndConcurrentInvocationsRemainIndependent|sharedFormattedHTMLRendererHasIndependentConcurrentInvocations|sharedAnnotatedDocumentRendererHasIndependentConcurrentInvocations|sharedExportPreparationsHaveIndependentConcurrentState|applePDFSimultaneousJobsHaveIndependentStateAndCancellation|sharedFilterPlanHasIndependentConcurrentInvocations|structuredSharedRendererPlansHaveInvocationOwnedState|sharedProviderBridgeHasIndependentConcurrentInvocations|e2SharedBridgeInputsHaveInvocationOwnedState|e2SharedCompiledPlanFacadeHasIndependentInvocationState'
SHARED_TESTS += '|compositionIndependentScopesCanBeSharedAcrossTasks'
SHARED_TESTS += '|qaStreaming|qaE2E(SharedPlan|RootImport|NDJSONImport|AwaitedSink|ExactWorkflow)'
SHARED_TESTS += '|g1SharedPreparedGeneratorHasIndependentConcurrentInvocations|g3SharedTypedGeneratorHasIndependentConcurrentInvocations|g4SharedAdvancedGeneratorHasIndependentConcurrentInvocations|g5SharedPreparationSeparatesConcurrentFailureAndSuccessHealth'
SHARED_TESTS += '|navigationSharedImmutableRootIndependentInvocations'
SHARED_TESTS += '|inspectionI17CoverageSpansReplacementAndSharedInvocations'
SHARED_TESTS += '|snapshotS19NavigationParityAndIndependentInvocations|snapshotV22ConcurrentLookupsUseIndependentAdmissionAndHealth'
R0_TESTS = 'readerProbe|indexProbes|duplicateRecognitionPrecedesValueAndClosingSyntax'

def snapshot():
    return [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]

def commands(lane, output):
    # The qualification executable resolves output paths from its repository root.
    output = output.relative_to(ROOT)
    if lane == 'inspection':
        result = [['python3', '-B', 'Scripts/public_check.py'],
                ['swift', 'test', '--filter', 'inspection|snapshot'],
                ['swift', 'test', '-c', 'release', '--filter', 'inspection|snapshot'],
                ['swift', 'test', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/inspection-address', '--filter', 'inspection|snapshot'],
                ['swift', 'build', '--target', 'JSONInspection', '--scratch-path', '.build/inspection-strict',
                 '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
                ['python3', '-B', 'Scripts/qualify_navigation_reducer.py', '--output', str(output / 'owned-codegen')]]
        return [c + ['--disable-xctest'] if sys.platform == 'linux' and c[:2] == ['swift', 'test'] else c for c in result]
    if lane == 'schema-examples-qualification':
        return commands('schema-examples-advanced', ROOT / output) + [['python3', '-B', 'Scripts/qualify_schema_example_matrix.py', '--output', str(output / 'matrix')]]
    if lane == 'schema-examples-advanced':
        return commands('schema-examples-construction', ROOT / output) + [['python3', '-B', 'Scripts/qualify_schema_example_advanced.py', '--output', str(output / 'advanced')]]
    if lane in ('schema-examples-determinism', 'schema-examples-construction'):
        # G2 changes only the opt-in generator. Reuse unchanged-core schema receipts;
        # keep the broader schema-examples lane and every full release gate intact.
        baseline = commands('schema-examples', ROOT / output)
        return baseline[:4] + [
            ['swift', 'test', '-c', 'release', '--jobs', '2', '--test-product', 'JSONSchemaExamplesTests'],
            ['python3', '-B', 'Scripts/qualify_schema_example_ownership.py', '--output', str(output / 'ownership')],
        ] + baseline[5:] + ([['python3', '-B', 'Scripts/qualify_schema_example_generation.py', '--output', str(output / 'generation')]] if lane == 'schema-examples-construction' else [])
    if lane == 'schema-examples-safety':
        return [
            ['swift', 'test', '-c', 'release', '--jobs', '2', '--test-product', 'JSONSchemaExamplesTests', '--sanitize', 'address', '--scratch-path', '.build/schema-examples-address'],
            ['swift', 'test', '-c', 'release', '--jobs', '2', '--test-product', 'JSONSchemaExamplesTests', '--sanitize', 'thread', '--scratch-path', '.build/schema-examples-thread', '--filter', 'g1SharedPreparedGeneratorHasIndependentConcurrentInvocations|g3SharedTypedGeneratorHasIndependentConcurrentInvocations|g4SharedAdvancedGeneratorHasIndependentConcurrentInvocations|g5SharedPreparationSeparatesConcurrentFailureAndSuccessHealth'],
            ['swift', 'build', '--target', 'JSONSchemaExamples', '--jobs', '2', '--scratch-path', '.build/schema-examples-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
        ]
    if lane == 'schema-examples':
        return [
            ['python3', '-B', 'Scripts/public_check.py'],
            ['swift', 'package', 'dump-package'],
            ['swift', 'package', 'show-dependencies', '--format', 'json'],
            ['swift', 'test', '--jobs', '2', '--test-product', 'JSONSchemaExamplesTests', '--filter', 'JSONSchemaExamplesTests'],
            ['swift', 'test', '--jobs', '2', '--test-product', 'JSONSchemaTests'],
            ['python3', '-B', 'Scripts/qualify_schema_examples.py', '--output', str(output / 'consumer'), '--scratch-path', '.build'],
        ]
    if lane == 'composition':
        result = [
            ['swift', 'test', '--filter', 'composition|composed|caughtOperationalFailureCannotComplete'],
            ['swift', 'test', '-c', 'release', '--filter', 'composition|composed|caughtOperationalFailureCannotComplete'],
            ['swift', 'run', '--package-path', 'Tools/CompositionQualification', 'CompositionConsumer'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/CompositionQualification', 'CompositionConsumer'],
            ['swift', 'test', '--package-path', 'Tools/CompositionQualification'],
            ['swift', 'test', '-c', 'release', '--package-path', 'Tools/CompositionQualification'],
            ['swift', 'test', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/composition-address', '--package-path', 'Tools/CompositionQualification'],
            ['python3', '-B', 'Scripts/qualify_composition_scale.py', '--output', str(output / 'scale')],
            ['python3', '-B', 'Scripts/qualify_composition.py', '--output', str(output / 'compiler-negative')],
        ]
        return [c + ['--disable-xctest'] if sys.platform == 'linux' and c[:2] == ['swift', 'test'] else c for c in result]
    if lane == 'navigation':
        return [['python3', '-B', 'Scripts/public_check.py'],
                ['swift', 'test', '--filter', 'navigation'],
                ['swift', 'test', '-c', 'release', '--filter', 'navigation'],
                ['swift', 'build', '--target', 'JSONNavigation', '--scratch-path', '.build/navigation-strict',
                 '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
                ['python3', '-B', 'Scripts/qualify_navigation.py', '--output', str(output / 'consumer')]]
    if lane == 'archive':
        return [['python3', '-B', 'Scripts/public_check.py'],
                ['python3', '-B', 'Scripts/qualify_native_reproduction.py', '--output', str(output / 'reproduction')]]
    if lane in ('coverage', 'linux-coverage'):
        return [['python3', '-B', 'Scripts/test_qualification_harness.py'],
                ['python3', '-B', 'Scripts/coverage.py', '--output', str(output / 'export')]]
    if lane in ('wasm', 'wasm-qa'):
        return [
            ['python3', '-B', 'Scripts/public_check.py'],
            ['python3', '-B', 'Scripts/wasm_support.py', '--output', str(output / 'probes')] + (['--scope', 'root-qa'] if lane == 'wasm-qa' else []),
        ]
    if lane == 'linux-qa':
        return [['python3', '-B', 'Scripts/public_check.py'],
                ['python3', '-B', 'Scripts/test_qualification_harness.py'],
                ['swift', 'test', '--disable-xctest'], ['swift', 'test', '-c', 'release', '--disable-xctest'],
                commands('qa', ROOT / output)[2] + ['--disable-xctest'],
                commands('safety', ROOT / output)[1] + ['--disable-xctest'],
                commands('safety', ROOT / output)[2]]
    if lane == 'linux':
        # Root behavior/corpora remain required. SwiftData and Apple SDK/lifetime
        # probes are separate Apple acceptance; they never become Linux passes.
        return [c for c in commands('native', ROOT / output)
                if not any(x in c for x in ['Tools/MobileQualification', '--mode', 'Scripts/qualify_cli_ownership.py'])] + [
            ['python3', '-B', 'Scripts/qualify_linux_reproduction.py', '--output', str(output / 'reproduction')]]
    if lane == 'linux-safety':
        # Every behavior case uses Swift Testing. Do not start the generated
        # zero-case XCTest runners, which leak in the pinned Linux runtime.
        return [['python3', '-B', 'Scripts/linux_runtime_diagnostics.py', '--output', str(output / 'runtime-diagnostics')]] + [
            c + ['--disable-xctest'] if c[:2] == ['swift', 'test'] else c
            for c in commands('safety', ROOT / output)]
    if lane == 'qa':
        return [
            ['swift', 'test', '--filter', 'qa'],
            ['swift', 'test', '-c', 'release', '--filter', 'qa'],
            ['swift', 'test', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/ci-address', '--filter', 'qa'],
        ]
    if lane == 'export':
        return [
            ['python3', '-B', 'Scripts/public_check.py'],
            ['python3', '-B', 'Scripts/verify_html_assets.py'],
            ['swift', 'test', '--filter', 'export|Export|apple'],
            ['swift', 'test', '-c', 'release', '--filter', 'export|Export|apple'],
            ['python3', '-B', 'Scripts/qualify_json_export.py', '--output', str(output / 'apple')],
        ]
    if lane == 'browser':
        return [
            ['python3', '-B', 'Scripts/verify_html_assets.py'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/JSONHTMLBrowser', 'BrowserFixtures', str(output / 'fixtures')],
            ['python3', '-B', 'Scripts/qualify_html_browser.py', '--fixtures', str(output / 'fixtures'), '--output', str(output / 'browser')],
        ]
    if lane == 'cli':
        return [['swift', 'build', '-c', 'release', '--product', 'swift-json'], ['swift', 'test', '--filter', 'cli|sharedFilterPlan'], ['python3', '-B', 'Scripts/qualify_cli.py', '--binary', '.build/release/swift-json', '--output', str(output / 'subprocess.json')],
            ['python3', '-B', 'Scripts/qualify_cli_integration.py', '--binary', '.build/release/swift-json', '--output', str(output / 'integration-subprocess.json')], ['python3', '-B', 'Scripts/qualify_cli_limits.py', '--binary', '.build/release/swift-json', '--output', str(output / 'cli-limits.json')], ['swift', 'build', '-c', 'release', '--package-path', 'Tools/CLIQualification', '--product', 'CLIExactCompare'], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C1', '--output', str(output / 'foundation-vectors.json')], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C2', '--output', str(output / 'vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C3', '--output', str(output / 'arithmetic-vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C4', '--output', str(output / 'advanced-vectors.json')], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C5', '--output', str(output / 'integration-vectors.json')], ['swift', 'run', '-c', 'release', '--package-path', 'Tools/CLIQualification', 'ProviderConsumer'], ['python3', '-B', 'Scripts/qualify_schema_providers.py', '--binary', '.build/release/swift-json', '--output', str(output / 'providers.json')]]
    if lane == 'native':
        return [
            ['python3', '-B', 'Scripts/public_check.py'],
            ['python3', '-B', 'Scripts/generate_cli_identity.py', '--check'],
            ['python3', '-B', 'Scripts/test_qualification_harness.py'],
            ['swift', 'package', 'dump-package'],
            ['swift', 'package', 'show-dependencies', '--format', 'json'],
            ['swift', 'build', '-c', 'release'],
            ['python3', '-B', 'Scripts/verify_testing_events.py'],
            ['swift', 'test'], ['swift', 'test', '-c', 'release'],
            ['python3', '-B', 'Scripts/qualify_cli.py', '--binary', '.build/release/swift-json', '--output', str(output / 'subprocess.json')],
            ['python3', '-B', 'Scripts/qualify_cli_integration.py', '--binary', '.build/release/swift-json', '--output', str(output / 'integration-subprocess.json')], ['python3', '-B', 'Scripts/qualify_cli_limits.py', '--binary', '.build/release/swift-json', '--output', str(output / 'cli-limits.json')],
            ['swift', 'build', '-c', 'release', '--package-path', 'Tools/CLIQualification', '--product', 'CLIExactCompare'],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C1', '--output', str(output / 'foundation-vectors.json')], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C2', '--output', str(output / 'vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C3', '--output', str(output / 'arithmetic-vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C4', '--output', str(output / 'advanced-vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C5', '--output', str(output / 'integration-vectors.json')],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/CLIQualification', 'ProviderConsumer'],
            ['python3', '-B', 'Scripts/qualify_schema_providers.py', '--binary', '.build/release/swift-json', '--output', str(output / 'providers.json')],
            ['python3', '-B', 'Scripts/qualify_cli_ownership.py', '--output', str(output / 'cli-ownership')],
            ['python3', '-B', 'Scripts/qualify_release_1_1.py', '--mode', 'ownership', '--output', str(output / 'ownership.json')],
            ['python3', '-B', 'Scripts/qualify_release_1_1.py', '--mode', 'reader', '--output', str(output / 'reader.json')],
            ['swift', 'run', '-c', 'release', '--package-path', 'Examples/Consumer', 'Consumer'],
            ['python3', '-B', 'Scripts/qualify_schema_examples.py', '--output', str(output / 'schema-examples'), '--scratch-path', '.build'],
            ['python3', '-B', 'Scripts/qualify_schema_example_ownership.py', '--output', str(output / 'schema-example-ownership')],
            ['python3', '-B', 'Scripts/qualify_schema_example_generation.py', '--output', str(output / 'schema-example-generation')],
            ['python3', '-B', 'Scripts/qualify_schema_example_advanced.py', '--output', str(output / 'schema-example-advanced')],
            ['python3', '-B', 'Scripts/qualify_schema_example_matrix.py', '--output', str(output / 'schema-example-matrix')],
            ['python3', '-B', 'Scripts/qualify_distribution.py', '--output', str(output / 'distribution')],
            ['python3', '-B', 'Scripts/qualify_ergonomics.py'],
            ['python3', '-B', 'Scripts/qualify_navigation.py', '--output', str(output / 'navigation')],
            ['python3', '-B', 'Scripts/qualify_inspection.py', '--output', str(output / 'inspection-consumer')],
            ['python3', '-B', 'Scripts/qualify_snapshot.py', '--output', str(output / 'snapshot-consumer')],
            ['python3', '-B', 'Scripts/qualify_navigation_reducer.py', '--output', str(output / 'owned-codegen')],
            ['swift', 'test', '--package-path', 'Tools/MobileQualification'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/MobileQualification', 'MobileQualification'],
            ['swift', 'test', '--package-path', 'Tools/MCPReadiness'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/MCPReadiness', 'MCPReadiness', str(output / 'consumer.json')],
            ['swift', 'test', '--package-path', 'Tools/Qualification'],
            ['python3', '-B', 'Scripts/qualification_watchdog.py', '--timeout', '900', '--output', str(output / 'watchdog.json'), '--', 'swift', 'run', '-c', 'release', '--package-path', 'Tools/Qualification', 'Qualification', '--all', '--registry', 'Documentation/Qualification/FixtureRegistry.json', '--output', str(output / 'qualification.json')],
        ]
    if lane == 'safety':
        return [
            ['swift', 'test', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/ci-address'],
            ['swift', 'test', '-c', 'release', '--sanitize', 'thread', '--scratch-path', '.build/ci-thread', '--filter', SHARED_TESTS],
            ['swift', 'build', '--scratch-path', '.build/ci-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
            ['python3', '-B', 'Scripts/qualify_schema_example_lifetime.py', '--output', str(output / 'corpus-lifetime')],
        ]
    if lane == 'r0':
        return [
            ['swift', 'test', '--filter', R0_TESTS],
            ['python3', '-B', 'Scripts/qualify_release_1_1.py', '--mode', 'ownership', '--output', str(output / 'ownership.json')],
            ['python3', '-B', 'Scripts/qualify_release_1_1.py', '--mode', 'sdk', '--output', str(output / 'sdk.json')],
        ]
    return [['python3', '-B', 'Scripts/build_documentation.py']]

def materialized_outcomes(output):
    qualification = json.loads((output / 'qualification.json').read_text())
    consumer = json.loads((output / 'consumer.json').read_text())
    watchdog = json.loads((output / 'watchdog.json').read_text())
    if qualification['status'] != 'passed' or qualification['errors'] or watchdog['status'] != 'passed' or watchdog['exit_code'] != 0:
        raise ValueError('Independent qualification receipt failed')
    expected = {'nst/JSONTestSuite': (318, 287, 31), 'json-schema-org/JSON-Schema-Test-Suite': (2337, 2300, 37)}
    suites = qualification['suites']
    if {s['repository'] for s in suites} != set(expected) or len(suites) != 2:
        raise ValueError('Missing independent suite receipt')
    for suite in suites:
        if (suite['observed_cases'], suite['passed_cases'], suite['policy_cases']) != expected[suite['repository']] or suite['failed_cases'] or suite['unexpected_skips'] or len(suite['cases']) != suite['observed_cases']:
            raise ValueError('Missing, changed or failing independent case outcomes')
    authored = {a['name']: a for a in qualification['authored']}
    for name, count in [('authored_public_semantics', 82), ('public_budget_and_counter_boundaries', 9), ('deterministic_malformed_utf8_replay', 4396)]:
        if authored[name]['observed'] != count or authored[name]['failed']:
            raise ValueError('Missing or failing authored qualification')
    if consumer['status'] != 'passed' or (consumer['positiveCases'], consumer['negativeCases'], consumer['operationalErrors']) != (8, 12, 2) or len(consumer['outcomes']) != 20 or any(c['actual'] != c['expected'] for c in consumer['outcomes']):
        raise ValueError('Missing or failing rooted consumer outcomes')
    return {name: {'sha256': hashlib.sha256((output / name).read_bytes()).hexdigest()} for name in ['qualification.json', 'consumer.json', 'watchdog.json']}

def check_result(command, code, log, events=None):
    counts = [int(n) for n in re.findall(r'Test run with (\d+) tests? in[^\n]*passed', log)]
    passed = code == 0
    if events is not None: counts = events['bundle_counts']
    if command[:2] == ['swift', 'test']:
        expected = [DISCOVERY['composition_external_functions']] if 'Tools/CompositionQualification' in command else [12] if 'composition|composed|caughtOperationalFailureCannotComplete' in command else [79] if 'JSONSchemaTests' in command else [4 if 'thread' in command else 98] if 'JSONSchemaExamplesTests' in command else [88] if 'cli|sharedFilterPlan' in command else sorted(DISCOVERY['export_functions'].values()) if 'export|Export|apple' in command else [14] if 'Tools/WasmAudit' in command else sorted(DISCOVERY['qa_functions'].values()) if 'qa' in command else [7] if R0_TESTS in command else [3] if 'Tools/MCPReadiness' in command or 'Tools/MobileQualification' in command else [1] if 'Tools/Qualification' in command else sorted(SHARED_COUNTS.values()) if 'thread' in command else sorted(ROOT_COUNTS.values())
        if 'JSONSchemaExamplesTests' in command and events is not None:
            passed = passed and events['module_function_counts'] == {'JSONSchemaExamplesTests': expected[0]} and events['parameter_case_invocations'] == 0
        if 'JSONSchemaTests' in command and events is not None:
            parameters = {name: ROOT_PARAMETER_CASES[name] for name in ['successfulAlternativesCannotSwallowRegexExhaustion(keyword:)', 'URIIdentityUsesSyntaxNormalizationWithoutUnicodeFolding(input:expected:)']}
            passed = passed and events['module_function_counts'] == {'JSONSchemaTests': 79} and events['parameterized_functions'] == parameters and events['parameter_case_invocations'] == 12
        if 'navigation' in command:
            expected = [DISCOVERY['root_functions']['JSONNavigationTests']]
            if events is not None:
                passed = passed and events['module_function_counts'] == {'JSONNavigationTests': expected[0]} and events['parameter_case_invocations'] == 0
        if any(f in command for f in ['inspection', 'inspection|snapshot']):
            expected = [DISCOVERY['root_functions']['JSONInspectionTests']]
            if events is not None:
                passed = passed and events['module_function_counts'] == {'JSONInspectionTests': expected[0]} and events['parameter_case_invocations'] == 0
        passed = passed and sorted(counts) == expected
        if 'Tools/CompositionQualification' in command and events is not None:
            passed = passed and events['module_function_counts'] == {'CompositionScaleTests': DISCOVERY['composition_external_functions']} and events['parameter_case_invocations'] == 0
        if 'qa' in command and events is not None:
            passed = passed and events['module_function_counts'] == DISCOVERY['qa_functions'] and check_restored(events)
        if 'thread' in command and 'JSONSchemaExamplesTests' not in command and events is not None:
            passed = passed and events['module_function_counts'] == SHARED_COUNTS
        if '--filter' not in command and '--test-product' not in command and not any(x.startswith('Tools/') for x in command):
            if events is not None:
                passed = passed and events['module_function_counts'] == ROOT_COUNTS and check_restored(events)
            passed = passed and (events['parameterized_functions'] == ROOT_PARAMETER_CASES if events is not None else sum(int(n) for n in re.findall(r'with (\d+) test cases passed', log)) == PARAMETER_INVOCATIONS)
        if 'Tools/Qualification' in command:
            probes = re.findall(r'^CAP_PROBE (\w+) (\S+)$', log, re.MULTILINE)
            matrix = json.loads((ROOT / 'Documentation/Qualification/LimitsMatrix.json').read_text())
            expected_probes = {m['metric']: m['public_probe_outcome'] for m in matrix['metrics']}
            passed = passed and len(probes) == 49 and dict(probes) == expected_probes
    if command[:3] == ['python3', '-B', 'Scripts/qualify_cli.py'] and passed:
        data = json.loads(log.strip().splitlines()[-1])
        passed = data['observed'] == data['passed'] == 53 and data['failed'] == 0
    if command[:3] == ['python3', '-B', 'Scripts/qualify_composition_scale.py'] and passed:
        data = json.loads(log.strip().splitlines()[-1])
        passed = data['status'] == 'passed' and (data['cells'], data['completed_imports'], data['operational_refusals']) == (8, 5, 3) and data['adoption_status'] == 'bounded_fixtures_only' and data['simple_strategy_capacity_status'] == 'blocked' and data['unmet_capacity_targets'] == ['balanced-128-128']
    if command[:3] == ['python3', '-B', 'Scripts/qualify_cli_integration.py'] and passed:
        d = json.loads(log.strip().splitlines()[-1])
        passed = d['status'] == 'passed' and (d['observed'], d['passed'], d['failed']) == (37, 37, 0)
    if command[:3] == ['python3', '-B', 'Scripts/qualify_cli_limits.py'] and passed:
        data = json.loads(log.strip().splitlines()[-1])
        passed = data['observed'] == data['passed'] == 33 and data['failed'] == 0 and data['metrics'] == 16
    if command[:3] == ['python3', '-B', 'Scripts/qualify_schema_providers.py'] and passed:
        data = json.loads(log.strip().splitlines()[-1])
        passed = data['status'] == 'passed' and (data['observed'], data['passed'], data['failed']) == (37, 37, 0) and data['input_unchanged'] and data['static_no_network_client_or_model_session'] and len(data['frozen_inputs']) == 6
    if command[:3] == ['python3', '-B', 'Scripts/qualify_cli_cases.py'] and passed:
        data = json.loads(log.strip().splitlines()[-1])
        expected = {'C1':12,'C2':38,'C3':17,'C4':38,'C5':6}[command[command.index('--gate')+1]]
        passed = data['observed'] == data['passed'] == expected and data['failed'] == data['policy'] == data['blocked'] == 0
    if command == ['swift', 'package', 'dump-package'] and passed:
        d = json.loads(log)
        passed = sorted(p['name'] for p in d['products']) == ['JSON', 'JSONBridges', 'JSONHTML', 'JSONInspection', 'JSONNavigation', 'JSONPatch', 'JSONSchema', 'JSONSchemaExamples', 'JSONStreaming', 'swift-json'] and not d['dependencies'] and d['swiftLanguageVersions'] == ['6'] and d['toolsVersion']['_version'] == '6.4.0' and d['platforms'] == [{'options': [], 'platformName': 'macos', 'version': '27.0'}, {'options': [], 'platformName': 'ios', 'version': '27.0'}]
        passed = passed and {p['name']: p['targets'] for p in d['products']} == dict({name: [name] for name in ['JSON', 'JSONSchema', 'JSONSchemaExamples', 'JSONStreaming', 'JSONPatch', 'JSONHTML', 'JSONBridges', 'JSONNavigation', 'JSONInspection']}, **{'swift-json': ['JSONCLI']})
        targets = {t['name']: t for t in d['targets']}
        passed = passed and set(targets) == {'JSON', 'JSONNavigation', 'JSONNavigationTests', 'JSONInspection', 'JSONInspectionTests', 'JSONIntegrationTests', 'JSONBridges', 'JSONBridgesTests', 'JSONSchema', 'JSONSchemaExamples', 'JSONSchemaExamplesTests', 'JSONStreaming', 'JSONPatch', 'JSONHTML', 'JSONRegexRuntime', 'JSONTests', 'JSONSchemaTests', 'JSONStreamingTests', 'JSONPatchTests', 'JSONHTMLTests', 'JSONRegexRuntimeTests', 'JSONFilterRuntime', 'JSONCLIEngine', 'JSONCLI', 'JSONCLITests'} and targets['JSONHTML']['dependencies'] == [{'byName': ['JSON', None]}] and targets['JSONBridges']['dependencies'] == [{'byName': ['JSON', None]}] and targets['JSONFilterRuntime']['dependencies'] == [{'byName': ['JSON', None]}] and targets['JSONCLI']['type'] == 'executable'
        passed = passed and targets['JSONNavigation']['dependencies'] == [{'byName': ['JSON', None]}] and targets['JSONNavigationTests']['dependencies'] == [{'byName': ['JSONNavigation', None]}, {'byName': ['JSON', None]}]
        passed = passed and targets['JSONSchemaExamples']['dependencies'] == [{'byName': ['JSON', None]}, {'byName': ['JSONSchema', None]}] and targets['JSON']['dependencies'] == [] and targets['JSONSchema']['dependencies'] == [{'byName': ['JSON', None]}, {'byName': ['JSONRegexRuntime', None]}]
        passed = passed and targets['JSONInspection']['dependencies'] == [{'byName': ['JSON', None]}, {'byName': ['JSONNavigation', None]}] and targets['JSONInspectionTests']['dependencies'] == [{'byName': ['JSONInspection', None]}, {'byName': ['JSONNavigation', None]}, {'byName': ['JSON', None]}]
    if command[:3] == ['python3', '-B', 'Scripts/qualify_schema_example_matrix.py']:
        passed = passed and 'SCHEMA_EXAMPLES_MATRIX passed schemas=64 certified=512 invalid=64 processes=2' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_schema_example_lifetime.py']:
        passed = passed and 'SCHEMA_EXAMPLES_CORPUS passed mode=owned scopes=128 values=6 exact=1' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_schema_example_advanced.py']:
        passed = passed and 'SCHEMA_EXAMPLES_ADVANCED passed required=10 incomplete=8 profiles=2 seeds=4 per_process=144 processes=2 witnesses=155' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_schema_example_generation.py']:
        passed = passed and 'SCHEMA_EXAMPLES_GENERATION passed cases=24 profiles=2 seeds=4 per_process=192 processes=2 proofs=2' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_schema_example_ownership.py']:
        passed = passed and 'SCHEMA_EXAMPLES_OWNERSHIP passed positive=1 negatives=8' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_schema_examples.py']:
        passed = passed and 'SCHEMA_EXAMPLES_COMPILER passed public_cases=15 negatives=2' in log.splitlines() and 'SCHEMA_EXAMPLES_DOCUMENTATION_COMPILER passed snippets=10 processes=2' in log.splitlines()
    if command == ['swift', 'package', 'show-dependencies', '--format', 'json'] and passed:
        passed = json.loads(log)['dependencies'] == []
    if command[:2] == ['swift', 'run'] and 'CompositionConsumer' in command:
        passed = passed and bool(re.search(r'^COMPOSITION_CONSUMER passed positive=2 negative=4 work=[1-9][0-9]* peak=[1-9][0-9]* version=1$', log, re.MULTILINE))
    if command[:2] == ['swift', 'run'] and 'ProviderConsumer' in command:
        passed = passed and 'PROVIDER_CONSUMER passed cases=14' in log.splitlines()
    if command[:2] == ['swift', 'run'] and 'Tools/MobileQualification' in command:
        passed = passed and all(line in log.splitlines() for line in ['PUBLIC_BEHAVIOR passed fixtures=8', 'STREAM_CANCELLATION passed', 'DISK_PERSISTENCE passed containers=3 rows=8', 'MOBILE_QUALIFICATION passed cases=3'])
    if command[:3] == ['python3', '-B', 'Scripts/verify_testing_events.py']:
        passed = passed and 'TESTING_EVENT_RECEIPTS passed cases=19' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_ergonomics.py']:
        passed = passed and 'ERGONOMICS_COMPILER passed commands=8 guide_fences=3' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_navigation_reducer.py']:
        passed = passed and 'REDUCER_CODEGEN passed positive=2 negative=20' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_snapshot.py']:
        passed = passed and 'SNAPSHOT_COMPILER passed configurations=2 consumer_cases=14 address_cases=14 guide_fences=3 negative_probes=18' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_inspection.py']:
        passed = passed and 'INSPECTION_COMPILER passed configurations=2 consumer_cases=12 address_cases=12 guide_fences=3 negative_probes=8' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_navigation.py']:
        passed = passed and 'NAVIGATION_COMPILER passed configurations=2 consumer_cases=18 negative_probes=8' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/verify_html_assets.py']:
        passed = passed and 'JSONHTML_ASSETS passed count=2' in log.splitlines()
    if 'BrowserFixtures' in command:
        passed = passed and 'JSONHTML_BROWSER_FIXTURES passed count=15' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/qualify_html_browser.py']:
        passed = passed and 'JSONHTML_BROWSER passed engines=3 cases=76 skips=0' in log.splitlines()
    if 'Scripts/test_qualification_harness.py' in command:
        passed = passed and 'HARNESS_TESTS passed cases=15' in log.splitlines()
    return passed, counts

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lane', choices=['composition', 'navigation', 'inspection', 'native', 'safety', 'docs', 'r0', 'qa', 'linux', 'linux-safety', 'wasm', 'browser', 'export', 'cli', 'schema-examples', 'schema-examples-safety', 'schema-examples-determinism', 'schema-examples-construction', 'schema-examples-advanced', 'schema-examples-qualification', 'coverage', 'linux-coverage', 'linux-qa', 'wasm-qa', 'archive'], required=True)
    parser.add_argument('--output')
    args = parser.parse_args()
    output = ROOT / (args.output or '.build/ci/' + args.lane)
    output.mkdir(parents=True, exist_ok=True)
    inputs = snapshot()
    repository = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, capture_output=True, text=True)
    is_checkout = repository.returncode == 0 and pathlib.Path(repository.stdout.strip()).resolve() == ROOT.resolve()
    commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True) if is_checkout else None
    environment = collect_linux() if args.lane.startswith('linux') or (args.lane in ('composition', 'inspection') and sys.platform == 'linux') else collect()
    receipt = {'schema_version': 1, 'lane': args.lane, 'status': 'blocked', 'environment': environment, 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'git_commit': commit.stdout.strip() if commit is not None and commit.returncode == 0 else None, 'github_run_id': os.environ.get('GITHUB_RUN_ID'), 'source_inputs': inputs, 'source_manifest_sha256': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(), 'commands': []}
    def save():
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    save()
    if receipt['environment']['status'] != 'passed':
        print(json.dumps(receipt['environment'], indent=2))
        return 2
    receipt['status'] = 'running'
    for index, command in enumerate(commands(args.lane, output)):
        plugin_path = os.environ.get('SWIFT_JSON_TESTING_PLUGIN_PATH')
        if command[:2] == ['swift', 'test'] and plugin_path:
            command += ['-Xswiftc', '-plugin-path', '-Xswiftc', plugin_path]
        event_path = output / ('command-%02d.events.jsonl' % index) if command[:2] == ['swift', 'test'] else None
        if event_path is not None:
            event_path.unlink(missing_ok=True)
            command = command + ['--event-stream-output-path', str(event_path.relative_to(ROOT))]
        print('Running ' + ' '.join(command), flush=True)
        log_path = output / ('command-%02d.log' % index)
        with log_path.open('w') as stream:
            try:
                result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=21600 if args.lane in ('wasm', 'wasm-qa') else 3500 if args.lane == 'archive' else 1800)
                code = result.returncode
            except (OSError, subprocess.TimeoutExpired) as error:
                stream.write('\n' + str(error) + '\n')
                code = None
        log = log_path.read_text(errors='replace').replace(str(ROOT), '.')
        log_path.write_text(log)
        events = None
        event_error = None
        try:
            if event_path is not None:
                events = read_events(event_path.read_text())
            passed, counts = check_result(command, code, log, events=events)
        except (OSError, KeyError, ValueError, TypeError) as error:
            passed, counts = False, []
            event_error = str(error)
        entry = {'command': [x.replace(str(ROOT), '.') for x in command], 'exit_code': code, 'status': 'passed' if passed else 'failed', 'log': log_path.relative_to(ROOT).as_posix(), 'log_sha256': hashlib.sha256(log_path.read_bytes()).hexdigest(), 'swift_testing_function_counts': counts, 'parameterized_case_invocations': sum(int(n) for n in re.findall(r'with (\d+) test cases passed', log))}
        if events is not None:
            entry['console_parameterized_case_invocations'] = entry['parameterized_case_invocations']
            entry['parameterized_case_invocations'] = events['parameter_case_invocations']
            entry['swift_testing_events'] = dict(events, path=event_path.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(event_path.read_bytes()).hexdigest())
        if event_error is not None:
            entry['event_error'] = event_error
        receipt['commands'].append(entry)
        print(json.dumps(entry), flush=True)
        if not passed:
            receipt['status'] = 'blocked' if args.lane == 'browser' and code == 2 else 'failed'
            break
        save()
    else:
        receipt['status'] = 'passed'
    if receipt['status'] == 'passed' and args.lane in ('native', 'linux'):
        try:
            receipt['materialized_outcomes'] = materialized_outcomes(output)
        except (OSError, KeyError, ValueError, TypeError) as error:
            receipt['status'] = 'failed'
            receipt['evidence_error'] = str(error)
            print('Native evidence failed: ' + str(error), flush=True)
    if receipt['status'] == 'passed' and args.lane in ('wasm', 'wasm-qa'):
        try:
            wasi = json.loads((output / 'probes/wasi.json').read_text())
            if wasi['status'] != 'passed' or wasi['root_counts'] != DISCOVERY['wasi_root_functions']:
                raise ValueError('Missing WASI qualification boundary')
            if args.lane == 'wasm-qa' and (wasi.get('scope') != 'root-qa' or wasi.get('qa_counts') != DISCOVERY['qa_functions']):
                raise ValueError('Missing scoped WASI QA boundary')
            receipt['materialized_wasi'] = {'path':'probes/wasi.json','sha256':hashlib.sha256((output / 'probes/wasi.json').read_bytes()).hexdigest()}
        except (OSError,KeyError,ValueError,TypeError) as error:
            receipt['status'] = 'failed'; receipt['evidence_error'] = str(error)
    if receipt['status'] == 'passed' and args.lane in ('coverage', 'linux-coverage'):
        try:
            coverage = json.loads((output / 'export/coverage.json').read_text())
            if coverage['status'] != 'passed' or coverage['root_counts'] != ROOT_COUNTS or coverage['parameterized_invocations'] != PARAMETER_INVOCATIONS or coverage['omitted_binary_probe']['status'] != 'rejected' or set(coverage['modules']) != set(DISCOVERY['coverage_modules']):
                raise ValueError('Missing complete current-module coverage boundary')
            receipt['materialized_coverage'] = {'path': 'export/coverage.json', 'sha256': hashlib.sha256((output / 'export/coverage.json').read_bytes()).hexdigest()}
        except (OSError, KeyError, ValueError, TypeError) as error:
            receipt['status'] = 'failed'; receipt['evidence_error'] = str(error)
    if receipt['status'] == 'passed' and args.lane == 'archive':
        try:
            reproduction = json.loads((output / 'reproduction/reproduction.json').read_text())
            native_path = output / 'reproduction/native/receipt.json'
            native = json.loads(native_path.read_text())
            candidate = output / 'reproduction/candidate.tar.gz'
            if (reproduction['status'] != 'passed' or not reproduction['outside_git_verified']
                or not reproduction['byte_equal_rebuild'] or not reproduction['byte_equal_extracted_rebuild']
                or reproduction['archive_sha256'] != hashlib.sha256(candidate.read_bytes()).hexdigest()
                or reproduction['native_receipt_sha256'] != hashlib.sha256(native_path.read_bytes()).hexdigest()
                or native['status'] != 'passed' or native['git_commit'] is not None
                or not native['source_inputs_unchanged'] or native['source_inputs'] != inputs
                or reproduction['native_commands'] != len(commands('native', output))):
                raise ValueError('Missing full source-bound Git-free reproduction')
            receipt['materialized_reproduction'] = {'path': 'reproduction/reproduction.json',
                'sha256': hashlib.sha256((output / 'reproduction/reproduction.json').read_bytes()).hexdigest()}
        except (OSError, KeyError, ValueError, TypeError) as error:
            receipt['status'] = 'failed'; receipt['evidence_error'] = str(error)
    receipt['source_inputs_unchanged'] = snapshot() == inputs
    if not receipt['source_inputs_unchanged']:
        receipt['status'] = 'failed'
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    return 0 if receipt['status'] == 'passed' else 1

if __name__ == '__main__':
    sys.exit(main())
