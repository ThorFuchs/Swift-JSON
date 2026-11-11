#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Execute public native CI lanes with command, source and environment receipts."""
import argparse, datetime, hashlib, json, os, pathlib, re, subprocess, sys
from archive_candidate import files
from preflight import collect, collect_linux
from testing_events import read_events, ROOT_PARAMETER_CASES
from p2_acceptance import check_p2_cases, check_borrow_receipt, check_private_receipt, check_exact_cases, check_exact_receipt
from graph_acceptance import check_graph_cases, check_graph_receipt, check_public_graph_receipt
from store_acceptance import check_store_tests, check_store_consumer
from qualify_structural_workflows import check_receipt as check_workflow_consumer
from qualify_structural_acceptance import check_receipt as check_structural_acceptance
from projection_acceptance import check_projection_cases, check_public_projection_receipt
from test_discovery import DISCOVERY, ROOT_COUNTS, SHARED_COUNTS, PARAMETER_INVOCATIONS, check_restored

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHARED_TESTS = 'independentCodecFacadesAndExactValuesCanBeSharedAcrossTasks|concurrentSchemaEvaluationsHaveExclusiveDynamicRegexAndAnnotationState|sharedRegexProgramHasExclusiveConcurrentSearchState|immutableIndexedObjectCanBeSharedAcrossTasks|qaSharedPayLoadAndRootHaveIndependentConcurrentReadScopes|sharedFormattedHTMLRendererHasIndependentConcurrentInvocations|sharedAnnotatedDocumentRendererHasIndependentConcurrentInvocations|sharedExportPreparationsHaveIndependentConcurrentState|applePDFSimultaneousJobsHaveIndependentStateAndCancellation|sharedFilterPlanHasIndependentConcurrentInvocations|structuredSharedRendererPlanHasIndependentInvocationOwnedState|sharedProviderBridgeHasIndependentConcurrentInvocations|g2SharedBridgeInputsHaveInvocationOwnedState|g2SharedCompiledPlanFacadeHasIndependentInvocationState|g3SharedBridgeInputsHaveIndependentConcurrentState|g4SharedAdvancedGeneratorHasIndependentConcurrentInvocations|g5SharedPreparationSeparatesConcurrentFailureAndSuccessHealth|navigationSharedImmutableRootIndependentInvocations|navigationPreparedD0IndependentConcurrentHealth|inspectionI17CoverageSpansReplacementAndSharedInvocations|snapshotS19NavigationParityAndIndependentInvocations|snapshotV22ConcurrentLookupsUseIndependentAdmissionAndHealth|jtxPlanIsSendableAndExecutionsHaveIndependentHealth|projectionP16SharedViewsHaveIndependentHealthAndLegacyStatistics|exactProjectionPUB07SharedPublicViewsKeepIndependentHealth|p2SetSSET18SharedImmutableViewsHaveIndependentLedgers|p2MatrixMAT18SharedTransposesHaveIndependentReads|graphG30ConcurrentViewsHaveIndependentHealth|graphGP14ConcurrentQueries|dslSharedFinalizationAndPlansAreInvocationOwned|storeR06TerminalQuotasNeverPublishAndImmutableConcurrentHealth|selectionSharedImmutablePlanHasIndependentPopulationAndFailureHealth|bindingSharedDefinitionAndCompilationHaveIndependentHealth|bindingSharedSelectionSpikeReusesOnePlanIndependently|workflowSharedImmutablePlansHaveIndependentBatchAndStoreHealth|acceptance18SharedPlansKeepIndependentCrossProductHealth'
R0_TESTS = 'readerProbe|indexProbes|duplicateRecognitionPrecedesValueAndClosingSyntax'

def snapshot():
    return [{'path': p.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files()]

def commands(lane, output):
    # The qualification executable resolves output paths from its repository root.
    output = output.relative_to(ROOT)
    if lane in ('transform-bindings', 'transform-bindings-safety'):
        def portable(values):
            return [c + ['--disable-xctest'] if sys.platform == 'linux' and c[:2] == ['swift', 'test'] else c for c in values]
        if lane.endswith('safety'):
            return portable([
                ['swift', 'test', '--test-product', 'JSONTransformTests', '-c', 'release', '--jobs', '2', '--sanitize', 'address', '--scratch-path', '.build/bindings-address'],
                ['swift', 'test', '--test-product', 'JSONTransformTests', '-c', 'release', '--jobs', '2', '--sanitize', 'thread', '--scratch-path', '.build/bindings-thread', '--filter', 'jtxPlanIsSendableAndExecutionsHaveIndependentHealth|bindingShared|selectionShared'],
                ['swift', 'build', '--target', 'JSONTransform', '--jobs', '2', '--scratch-path', '.build/bindings-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
            ])
        return portable([
            ['python3', '-B', 'Scripts/public_check.py'],
            ['python3', '-B', 'Scripts/generate_cli_identity.py', '--check'],
            ['python3', '-B', 'Scripts/test_qualification_harness.py'],
            ['swift', 'test', '--test-product', 'JSONTransformTests', '--jobs', '2'],
            ['swift', 'test', '--test-product', 'JSONTransformTests', '-c', 'release', '--jobs', '2'],
            ['python3', '-B', 'Scripts/qualify_transform_bindings.py', '--output', str(output / 'public-consumer')],
            ['python3', '-B', 'Scripts/qualify_transform_selection.py', '--output', str(output / 'selection-consumer')],
        ])
    if lane in ('structural-acceptance', 'structural-acceptance-safety'):
        if lane.endswith('safety'):
            result = [
                ['swift', 'test', '--test-product', 'JSONIntegrationTests', '-c', 'release', '--jobs', '2', '--sanitize', 'address', '--scratch-path', '.build/workflow-address', '--filter', 'JSONIntegrationTests'],
                ['swift', 'test', '--test-product', 'JSONIntegrationTests', '-c', 'release', '--jobs', '2', '--sanitize', 'thread', '--scratch-path', '.build/workflow-thread', '--filter', 'acceptance18SharedPlansKeepIndependentCrossProductHealth'],
                ['swift', 'build', '--target', 'JSONIntegrationTests', '--jobs', '2', '--scratch-path', '.build/workflow-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
            ]
        else:
            result = [
                ['python3', '-B', 'Scripts/public_check.py'],
                ['python3', '-B', 'Scripts/generate_cli_identity.py', '--check'],
                ['python3', '-B', 'Scripts/test_qualification_harness.py'],
                ['swift', 'test', '--test-product', 'JSONIntegrationTests', '--jobs', '2', '--filter', 'JSONIntegrationTests'],
                ['swift', 'test', '--test-product', 'JSONIntegrationTests', '-c', 'release', '--jobs', '2', '--filter', 'JSONIntegrationTests'],
                ['python3', '-B', 'Scripts/qualify_structural_acceptance.py', '--output', str(output / 'public-acceptance')],
                ['swift', 'test', '--package-path', 'Tools/Qualification', '--scratch-path', '.build/workflow-consumer', '--jobs', '2'],
            ]
        return [c + ['--disable-xctest'] if sys.platform == 'linux' and c[:2] == ['swift', 'test'] else c for c in result]
    if lane in ('structural-workflows', 'structural-workflows-safety'):
        if lane.endswith('safety'):
            result = [
                ['swift', 'test', '--test-product', 'JSONInspectionTests', '-c', 'release', '--jobs', '2', '--sanitize', 'address', '--scratch-path', '.build/workflow-address', '--filter', 'workflow'],
                ['swift', 'test', '--test-product', 'JSONInspectionTests', '-c', 'release', '--jobs', '2', '--sanitize', 'thread', '--scratch-path', '.build/workflow-thread', '--filter', 'workflowSharedImmutablePlansHaveIndependentBatchAndStoreHealth'],
                ['swift', 'build', '--target', 'JSONInspection', '--jobs', '2', '--scratch-path', '.build/workflow-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
            ]
        else:
            result = [
                ['python3', '-B', 'Scripts/public_check.py'],
                ['python3', '-B', 'Scripts/generate_cli_identity.py', '--check'],
                ['python3', '-B', 'Scripts/test_qualification_harness.py'],
                ['swift', 'test', '--test-product', 'JSONInspectionTests', '--jobs', '2', '--filter', 'workflow'],
                ['swift', 'test', '--test-product', 'JSONInspectionTests', '-c', 'release', '--jobs', '2', '--filter', 'workflow'],
                ['swift', 'test', '--test-product', 'JSONInspectionTests', '--jobs', '2', '--filter', 'store'],
                ['swift', 'test', '--test-product', 'JSONInspectionTests', '-c', 'release', '--jobs', '2', '--filter', 'store'],
                ['python3', '-B', 'Scripts/qualify_store.py', '--output', str(output / 'store-boundaries')],
                ['python3', '-B', 'Scripts/qualify_structural_workflows.py', '--output', str(output / 'public-consumer')],
            ]
        return [c + ['--disable-xctest'] if sys.platform == 'linux' and c[:2] == ['swift', 'test'] else c for c in result]
    if lane == 'store':
        return [
            ['python3', '-B', 'Scripts/public_check.py'],
            ['python3', '-B', 'Scripts/test_qualification_harness.py'],
            ['swift', 'test', '--test-product', 'JSONInspectionTests', '--filter', 'store'],
            ['swift', 'test', '--test-product', 'JSONInspectionTests', '-c', 'release', '--filter', 'store'],
            ['swift', 'test', '--test-product', 'JSONInspectionTests', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/store-address', '--filter', 'store'],
            ['swift', 'test', '--test-product', 'JSONInspectionTests', '-c', 'release', '--sanitize', 'thread', '--scratch-path', '.build/store-thread', '--filter', 'storeR06TerminalQuotasNeverPublishAndImmutableConcurrentHealth'],
            ['swift', 'build', '--target', 'JSONInspection', '--scratch-path', '.build/store-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
            ['python3', '-B', 'Scripts/qualify_store.py', '--output', str(output / 'private-consumer')],
        ]
    if lane == 'store-preparation':
        return [
            ['python3', '-B', 'Scripts/public_check.py'],
            ['swift', 'test', '--test-product', 'JSONNavigationTests', '--filter', 'navigationPreparedD0'],
            ['swift', 'test', '--test-product', 'JSONNavigationTests', '-c', 'release', '--filter', 'navigationPreparedD0'],
            ['swift', 'test', '--test-product', 'JSONNavigationTests', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/store-preparation-address', '--filter', 'navigationPreparedD0'],
            ['swift', 'test', '--test-product', 'JSONNavigationTests', '-c', 'release', '--sanitize', 'thread', '--scratch-path', '.build/store-preparation-thread', '--filter', 'navigationPreparedD0IndependentConcurrentHealth'],
            ['swift', 'build', '--target', 'JSONInspection', '--scratch-path', '.build/store-preparation-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
            ['python3', '-B', 'Scripts/qualify_navigation_reducer.py', '--output', str(output / 'original-owned-codegen')],
            ['python3', '-B', 'Scripts/qualify_store_preparation.py', '--output', str(output / 'prepared-codegen')],
        ]
    if lane == 'inspection':
        result = [['python3', '-B', 'Scripts/public_check.py'],
                ['swift', 'test', '--filter', 'inspection|snapshot|projectionP|p2|exactProjectionPUB|graphG|store|workflow'],
                ['swift', 'test', '-c', 'release', '--filter', 'inspection|snapshot|projectionP|p2|exactProjectionPUB|graphG|store|workflow'],
                ['swift', 'test', '-c', 'release', '--sanitize', 'address', '--scratch-path', '.build/inspection-address', '--filter', 'inspection|snapshot|projectionP|p2|exactProjectionPUB|graphG|store|workflow'],
                ['swift', 'build', '--target', 'JSONInspection', '--scratch-path', '.build/inspection-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
                ['python3', '-B', 'Scripts/qualify_navigation_reducer.py', '--output', str(output / 'owned-codegen')],
                ['python3', '-B', 'Scripts/qualify_graph_context.py', '--output', str(output / 'graph-context')],
                ['python3', '-B', 'Scripts/qualify_graph.py', '--output', str(output / 'graph-compiler')],
                ['python3', '-B', 'Scripts/qualify_public_graph.py', '--output', str(output / 'public-graph-consumer')],
                ['python3', '-B', 'Scripts/qualify_store_preparation.py', '--output', str(output / 'prepared-codegen')],
                ['python3', '-B', 'Scripts/qualify_store.py', '--output', str(output / 'private-store-consumer')],
                ['python3', '-B', 'Scripts/qualify_structural_workflows.py', '--output', str(output / 'public-workflow-consumer')],
                ['python3', '-B', 'Scripts/qualify_structural_acceptance.py', '--output', str(output / 'structural-acceptance')],
                ['python3', '-B', 'Scripts/qualify_projections.py', '--output', str(output / 'projection-codegen')],
                ['python3', '-B', 'Scripts/verify_p2_fixtures.py'],
                ['python3', '-B', 'Scripts/qualify_p2_borrowing.py', '--output', str(output / 'p2-borrowing')],
                ['python3', '-B', 'Scripts/qualify_p2.py', '--output', str(output / 'p2-isolation')],
                ['python3', '-B', 'Scripts/qualify_exact_projections.py', '--output', str(output / 'exact-projection-consumer')],
                ['python3', '-B', 'Scripts/qualify_public_projections.py', '--output', str(output / 'public-projection-consumer')]]
        return [c + ['--disable-xctest'] if sys.platform == 'linux' and c[:2] == ['swift', 'test'] else c for c in result]
    if lane == 'schema-examples-qualification':
        return commands('schema-examples-advanced', ROOT / output) + [['python3', '-B', 'Scripts/qualify_schema_example_matrix.py', '--output', str(output / 'matrix')]]
    if lane == 'schema-examples-advanced':
        return commands('schema-examples-construction', ROOT / output) + [['python3', '-B', 'Scripts/qualify_schema_example_advanced.py', '--output', str(output / 'advanced')]]
    if lane in ('schema-examples-determinism', 'schema-examples-construction'):
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
                ['swift', 'build', '--target', 'JSONNavigation', '--scratch-path', '.build/navigation-strict', '-Xswiftc', '-strict-memory-safety', '-Xswiftc', '-warnings-as-errors'],
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
        return [c for c in commands('native', ROOT / output)
                if not any(x in c for x in ['Tools/MobileQualification', 'Scripts/qualify_release_1_1.py', 'Scripts/qualify_cli_ownership.py'])] + [
            ['python3', '-B', 'Scripts/qualify_linux_reproduction.py', '--output', str(output / 'reproduction')]]
    if lane == 'linux-safety':
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
        return [['swift', 'build', '-c', 'release', '--product', 'swift-json'], ['swift', 'test', '--test-product', 'JSONCLITests', '--filter', 'cli|sharedFilterPlan'], ['python3', '-B', 'Scripts/qualify_cli.py', '--binary', '.build/release/swift-json', '--output', str(output / 'subprocess.json')], ['python3', '-B', 'Scripts/qualify_cli_integration.py', '--binary', '.build/release/swift-json', '--output', str(output / 'integration-subprocess.json')], ['python3', '-B', 'Scripts/qualify_cli_limits.py', '--binary', '.build/release/swift-json', '--output', str(output / 'cli-limits.json')], ['swift', 'build', '-c', 'release', '--package-path', 'Tools/CLIQualification', '--product', 'CLIExactCompare'], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C1', '--output', str(output / 'foundation-vectors.json')], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C2', '--output', str(output / 'vectors.json')], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C3', '--output', str(output / 'arithmetic-vectors.json')], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C4', '--output', str(output / 'advanced-vectors.json')], ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C5', '--output', str(output / 'integration-vectors.json')], ['swift', 'run', '-c', 'release', '--package-path', 'Tools/CLIQualification', 'ProviderConsumer'], ['python3', '-B', 'Scripts/qualify_schema_providers.py', '--binary', '.build/release/swift-json', '--output', str(output / 'providers.json')]]
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
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C1', '--output', str(output / 'foundation-vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C2', '--output', str(output / 'vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C3', '--output', str(output / 'arithmetic-vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C4', '--output', str(output / 'advanced-vectors.json')],
            ['python3', '-B', 'Scripts/qualify_cli_cases.py', '--binary', '.build/release/swift-json', '--comparator', 'Tools/CLIQualification/.build/release/CLIExactCompare', '--gate', 'C5', '--output', str(output / 'integration-vectors.json')],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/CLIQualification', 'ProviderConsumer'],
            ['python3', '-B', 'Scripts/qualify_schema_providers.py', '--binary', '.build/release/swift-json', '--output', str(output / 'providers.json')],
            ['python3', '-B', 'Scripts/qualify_cli_ownership.py', '--output', str(output / 'cli-ownership')],
            ['python3', '-B', 'Scripts/test_transform_ownership.py'],
            ['python3', '-B', 'Scripts/qualify_transform_ownership.py', '--output', str(output / 'transform-ownership')],
            ['python3', '-B', 'Scripts/qualify_transform.py', '--output', str(output / 'transform-consumer')],
            ['python3', '-B', 'Scripts/qualify_transform_bindings.py', '--output', str(output / 'transform-binding-consumer')],
            ['python3', '-B', 'Scripts/qualify_transform_selection.py', '--output', str(output / 'transform-selection-consumer')],
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
            ['python3', '-B', 'Scripts/qualify_dual_dsl.py', '--mode', 'imports', '--output', str(output / 'dsl-imports')],
            ['swift', 'run', '--package-path', 'Examples/DualDSL', 'DualDSLConsumer'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Examples/DualDSL', 'DualDSLConsumer'],
            ['python3', '-B', 'Scripts/qualify_navigation.py', '--output', str(output / 'navigation')],
            ['python3', '-B', 'Scripts/qualify_inspection.py', '--output', str(output / 'inspection-consumer')],
            ['python3', '-B', 'Scripts/qualify_snapshot.py', '--output', str(output / 'snapshot-consumer')],
            ['python3', '-B', 'Scripts/qualify_projections.py', '--output', str(output / 'projection-codegen')],
            ['python3', '-B', 'Scripts/verify_p2_fixtures.py'],
            ['python3', '-B', 'Scripts/qualify_p2_borrowing.py', '--output', str(output / 'p2-borrowing')],
            ['python3', '-B', 'Scripts/qualify_p2.py', '--output', str(output / 'p2-isolation')],
            ['python3', '-B', 'Scripts/qualify_exact_projections.py', '--output', str(output / 'exact-projection-consumer')],
            ['python3', '-B', 'Scripts/qualify_public_projections.py', '--output', str(output / 'public-projection-consumer')],
            ['python3', '-B', 'Scripts/qualify_navigation_reducer.py', '--output', str(output / 'owned-codegen')],
            ['python3', '-B', 'Scripts/qualify_graph_context.py', '--output', str(output / 'graph-context')],
            ['python3', '-B', 'Scripts/qualify_graph.py', '--output', str(output / 'graph-compiler')],
            ['python3', '-B', 'Scripts/qualify_public_graph.py', '--output', str(output / 'public-graph-consumer')],
            ['python3', '-B', 'Scripts/qualify_store_preparation.py', '--output', str(output / 'prepared-codegen')],
            ['python3', '-B', 'Scripts/qualify_store.py', '--output', str(output / 'private-store-consumer')],
            ['python3', '-B', 'Scripts/qualify_structural_workflows.py', '--output', str(output / 'public-workflow-consumer')],
            ['python3', '-B', 'Scripts/qualify_structural_acceptance.py', '--output', str(output / 'structural-acceptance')],
            ['swift', 'test', '--package-path', 'Tools/MobileQualification'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/MobileQualification', 'MobileQualification'],
            ['swift', 'test', '--package-path', 'Tools/MCPReadiness'],
            ['swift', 'run', '-c', 'release', '--package-path', 'Tools/MCPReadiness', 'MCPReadiness', str(output / 'consumer.json')],
            ['swift', 'test', '--package-path', 'Tools/Qualification'],
            ['python3', '-B', 'Scripts/qualification_watchdog.py', '--timeout', '900', '--output', str(output / 'watchdog.json'), '--', 'swift', 'run', '-c', 'release', '--package-path', 'Tools/Qualification', 'Qualification', '--all', '--registry', 'Documentation/Qualification/FixureRegistry.json', '--output', str(output / 'qualification.json')],
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
    return [['python3', '-B', 'Scripts/qualify_exact_projections.py', '--output', str(output / 'exact-projection-consumer')],
            ['python3', '-B', 'Scripts/build_documentation.py']]

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
    selected_filter = command[command.index('--filter') + 1] if '--filter' in command else None
    store_test = selected_filter in ('store', 'storeR06TerminalQuotasNeverPublishAndImmutableConcurrentHealth')
    workflow_test = selected_filter in ('workflow', 'workflowSharedImmutablePlansHaveIndependentBatchAndStoreHealth')
    acceptance_test = selected_filter in ('acceptance18', 'acceptance18SharedPlansKeepIndependentCrossProductHealth')
    prepared_test = selected_filter in ('navigationPreparedD0', 'navigationPreparedD0IndependentConcurrentHealth')
    if command[:2] == ['swift', 'test']:
        expected = [DISCOVERY['composition_external_functions']] if 'Tools/CompositionQualification' in command else [12] if 'composition|composed|caughtOperationalFailureCannotComplete' in command else [79] if 'JSONSchemaTests' in command and 'thread' not in command else [12] if 'JSONSchemaExamplesTests' in command else [8] if 'qa' in command else [DISCOVERY['root_functions']['JSONInspectionTests']] if 'inspection|snapshot|projectionP|p2|exactProjectionPUB|graphG|store|workflow' in command else [DISCOVERY['root_functions']['JSONNavigationTests']] if 'navigation' in command else [12]
        if 'JSONSchemaExamplesTests' in command and events is not None:
            passed = passed and events['module_function_counts'] == {'JSONSchemaExamplesTests': expected[0]} and events['parameter_case_invocations'] == 0
        if 'JSONSchemaTests' in command and events is not None:
            parameters = {name: ROOT_PARAMETER_CASES[name] for name in ['successfulAlternativesCannotSwallowRegexExhaustion(keyword:)', 'URIIdentityUsesSyntaxNormalizationWithoutUnicodeFolding(input:expected:)']}
            passed = passed and events['module_function_counts'] == {'JSONSchemaTests': 79} and events['parameterized_functions'] == parameters and events['parameter_case_invocations'] == 12
        if 'JSONTransformTests' in command:
            ids = set(DISCOVERY['transform_function_ids'])
            if 'thread' in command:
                ids = {n for n in ids if 'bindingShared' in n or 'selectionShared' in n or 'jtxPlanIsSendableAndExecutionsHaveIndependentHealth' in n}
            elif selected_filter == 'selection':
                ids = {n for n in ids if '.selection' in n}
            elif selected_filter == 'binding':
                ids = {n for n in ids if '.binding' in n}
            expected = [len(ids)]
            passed = passed and events is not None and events['module_function_counts'] == {'JSONTransformTests': len(ids)} and set(events['function_names']) == ids and len(events['function_names']) == len(ids)
        if 'navigation' in command:
            expected = [DISCOVERY['root_functions']['JSONNavigationTests']]
            if events is not None:
                passed = passed and events['module_function_counts'] == {'JSONNavigationTests': expected[0]} and events['parameter_case_invocations'] == 0
        if any(f in command for f in ['inspection', 'inspection|snapshot|projectionP|p2|exactProjectionPUB|graphG|store|workflow']):
            expected = [DISCOVERY['root_functions']['JSONInspectionTests']]
            if events is not None:
                passed = passed and events['module_function_counts'] == {'JSONInspectionTests': expected[0]} and events['parameter_case_invocations'] == 65
        if prepared_test:
            expected_ids = set(DISCOVERY['prepared_entry_function_ids'])
            if 'navigationPreparedD0IndependentConcurrentHealth' in command:
                expected_ids = {x for x in expected_ids if 'IndependentConcurrentHealth' in x}
            expected = [len(expected_ids)]
            if events is not None:
                passed = passed and events['module_function_counts'] == {'JSONNavigationTests': len(expected_ids)} and set(events['function_names']) == expected_ids and events['parameter_case_invocations'] == 0
        if store_test:
            shared_store = any(x.startswith('storeR06') for x in command)
            expected = [1 if shared_store else 12]
            passed = passed and events is not None and check_store_tests(events, log, shared=shared_store, scoped=True)
        if workflow_test:
            expected_ids = set(DISCOVERY['workflow_function_ids'])
            if selected_filter != 'workflow':
                expected_ids = {x for x in expected_ids if 'SharedImmutablePlans' in x}
            expected = [len(expected_ids)]
            passed = passed and events is not None and events['module_function_counts'] == {'JSONInspectionTests': len(expected_ids)} and set(events['function_names']) == expected_ids and len(events['function_names']) == len(expected_ids)
        if selected_filter == 'JSONIntegrationTests':
            expected_ids = set(DISCOVERY['integration_function_ids'])
            expected = [len(expected_ids)]
            passed = passed and events is not None and events['module_function_counts'] == {'JSONIntegrationTests': len(expected_ids)} and set(events['function_names']) == expected_ids and len(events['function_names']) == len(expected_ids)
        if acceptance_test:
            expected_ids = set(DISCOVERY['structural_acceptance_function_ids'])
            if selected_filter != 'acceptance18':
                expected_ids = {x for x in expected_ids if 'SharedPlans' in x}
            expected = [len(expected_ids)]
            passed = passed and events is not None and events['module_function_counts'] == {'JSONIntegrationTests': len(expected_ids)} and set(events['function_names']) == expected_ids and len(events['function_names']) == len(expected_ids)
        passed = passed and sorted(counts) == expected
        if 'Tools/CompositionQualification' in command and events is not None:
            passed = passed and events['module_function_counts'] == {'CompositionScaleTests': DISCOVERY['composition_external_functions']} and events['parameter_case_invocations'] == 0
        if 'qa' in command and events is not None:
            passed = passed and events['module_function_counts'] == DISCOVERY['qa_functions'] and check_restored(events)
        if 'thread' in command and 'JSONSchemaExamplesTests' not in command and 'JSONTransformTests' not in command and not prepared_test and not store_test and not workflow_test and not acceptance_test:
            passed = passed and events is not None and events['module_function_counts'] == SHARED_COUNTS
        if '--filter' not in command and '--test-product' not in command and not any(x.startswith('Tools/') for x in command):
            if events is not None:
                passed = passed and events['module_function_counts'] == ROOT_COUNTS and check_restored(events)
            passed = passed and (events['parameterized_functions'] == ROOT_PARAMETER_CASES if events is not None else sum(int(n) for n in re.findall(r'with (\d+) test cases passed', log)) == 343)
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
        passed = data['status'] == 'passed' and (data['cells'], data['completed_imports'], data['operational_refusals']) == (8, 5, 3)
    if command[:3] == ['python3', '-B', 'Scripts/qualify_cli_integration.py'] and passed:
        d = json.loads(log.strip().splitlines()[-1])
        passed = d['status'] == 'passed' and (d['observed'], d['passed'], d['failed']) == (37, 37, 0)
    if command[:3] == ['python3', '-B', 'Scripts/qualify_schema_providers.py'] and passed:
        data = json.loads(log.strip().splitlines()[-1])
        passed = data['status'] == 'passed' and (data['observed'], data['passed'], data['failed']) == (37, 37, 0)
    if command[:3] == ['python3', '-B', 'Scripts/qualify_cli_cases.py'] and passed:
        data = json.loads(log.strip().splitlines()[-1])
        expected = {'C1':12,'C2':38,'C3':17,'C4':38,'C5':6}[command[command.index('--gate')+1]]
        passed = data['observed'] == data['passed'] == expected and data['failed'] == data['policy'] == data['blocked'] == 0
    if command[:2] == ['swift', 'run'] and 'Examples/DualDSL' in command:
        passed = passed and 'DUAL_DSL_CONSUMER passed valid=1 invalid=2 operational=1 exact_keys=2 nested_arrays=1' in log.splitlines()
    if command[:3] == ['python3', '-B', 'Scripts/test_qualification_harness.py']:
        passed = passed and 'HARNESS_TESTS passed cases=35' in log.splitlines()
    return passed, counts

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lane', choices=['transform-bindings', 'transform-bindings-safety', 'structural-acceptance', 'structural-acceptance-safety', 'structural-workflows', 'structural-workflows-safety', 'store', 'store-preparation', 'inspection', 'schema-examples-qualification', 'schema-examples-advanced', 'schema-examples-determinism', 'schema-examples-construction', 'schema-examples-safety', 'schema-examples', 'composition', 'navigation', 'archive', 'coverage', 'linux-coverage', 'wasm', 'wasm-qa', 'linux-qa', 'linux', 'linux-safety', 'qa', 'export', 'browser', 'cli', 'native', 'safety', 'r0'])
    parser.add_argument('--output')
    parser.add_argument('--skip-host-measurements', action='store_true', help='For WASI runtime qualification only: record optional host timings as NOT RUN.')
    args = parser.parse_args()
    if args.skip_host_measurements and args.lane not in ('wasm', 'wasm-qa'):
        parser.error('--skip-host-measurements applies only to WASI lanes')
    output = ROOT / (args.output or '.build/ci/' + args.lane)
    output.mkdir(parents=True, exist_ok=True)
    inputs = snapshot()
    repository = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, capture_output=True, text=True)
    is_checkout = repository.returncode == 0 and pathlib.Path(repository.stdout.strip()).resolve() == ROOT.resolve()
    commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True) if is_checkout else None
    environment = collect_linux() if args.lane.startswith('linux') or (args.lane in ('transform-bindings', 'transform-bindings-safety', 'composition', 'inspection', 'structural-workflows', 'structural-workflows-safety', 'store', 'store-preparation', 'navigation', 'coverage')) else collect()
    receipt = {'schema_version': 1, 'lane': args.lane, 'status': 'blocked', 'environment': environment, 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'git_commit': commit.stdout.strip() if commit else None, 'commands': []}
    def save():
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    save()
    if receipt['environment']['status'] != 'passed':
        print(json.dumps(receipt['environment'], indent=2))
        return 2
    receipt['status'] = 'running'
    for index, command in enumerate(commands(args.lane, output)):
        if args.skip_host_measurements and command[:3] == ['python3', '-B', 'Scripts/wasm_support.py']:
            command += ['--skip-host-measurements']
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
        entry = {'command': [x.replace(str(ROOT), '.') for x in command], 'exit_code': code, 'status': 'passed' if passed else 'failed', 'log': log_path.relative_to(ROOT).as_posix(), 'log_sha256': hashlib.sha256(log_path.read_bytes()).hexdigest(), 'counts': counts}
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
    receipt['source_inputs_unchanged'] = snapshot() == inputs
    if not receipt['source_inputs_unchanged']:
        receipt['status'] = 'failed'
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    return 0 if receipt['status'] == 'passed' else 1

if __name__ == '__main__':
    sys.exit(main())
