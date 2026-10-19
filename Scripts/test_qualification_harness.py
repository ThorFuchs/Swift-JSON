#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Negative coverage/discovery harness tests; never substitutes for Swift behavior."""
import copy
import json
import pathlib
import subprocess
from qualify_release_1_1 import checkout_head
from generate_cli_identity import rendered
import tempfile
import unittest
from coverage import executable_objects, shared_objects, validate_export, without_schema_objects
from test_discovery import DISCOVERY, ROOT_COUNTS, PARAMETER_INVOCATIONS, check_root, check_restored, RESTORED_FUNCTIONS
from ci import check_result, commands
from projection_acceptance import EXPECTED as PROJECTION_FUNCTIONS, PUBLIC_CHECKS, check_projection_cases, check_public_projection_receipt

class HarnessTests(unittest.TestCase):
    def test_public_projection_receipt_rejects_incomplete_and_incidental_successes(self):
        valid = dict(status='passed', commands=[dict(name=str(i), status='passed',
            compiler_crash=False, expected_diagnostic='inaccessible' if i < 18 else None,
            primary_diagnostics=['inaccessible'] if i < 18 else [], exit_code=1 if i < 18 else 0)
            for i in range(37)], consumer_results={config: dict(cases=sorted(PUBLIC_CHECKS),
                work_units=1, logical_retained_bytes=1, peak_logical_retained_bytes=1, admitted_nodes=1)
                for config in ['debug', 'release', 'address']})
        self.assertTrue(check_public_projection_receipt(valid))
        broken = copy.deepcopy(valid); broken['commands'].pop()
        self.assertFalse(check_public_projection_receipt(broken))
        broken = copy.deepcopy(valid); broken['commands'][0]['primary_diagnostics'] = ['unrelated warning']
        self.assertFalse(check_public_projection_receipt(broken))
        broken = copy.deepcopy(valid); broken['commands'][0]['compiler_crash'] = True
        self.assertFalse(check_public_projection_receipt(broken))
        broken = copy.deepcopy(valid); broken['commands'][0]['exit_code'] = 0
        self.assertFalse(check_public_projection_receipt(broken))
        for config in ['debug', 'release', 'address']:
            for mode in ['missing', 'duplicate', 'renamed', 'zero-resource']:
                broken = copy.deepcopy(valid); row = broken['consumer_results'][config]
                if mode == 'missing': row['cases'].pop()
                elif mode == 'duplicate': row['cases'][0] = row['cases'][1]
                elif mode == 'renamed': row['cases'][0] = 'unexpected'
                else: row['work_units'] = 0
                self.assertFalse(check_public_projection_receipt(broken))

    def test_prepared_entry_rejects_missing_renamed_and_wrong_module_cases(self):
        command = ['swift', 'test', '--filter', 'navigationPreparedD0']
        names = list(DISCOVERY['prepared_entry_function_ids'])
        events = dict(bundle_counts=[10], module_function_counts={'JSONNavigationTests': 10},
                      parameter_case_invocations=0, function_names=names)
        self.assertTrue(check_result(command, 0, '', events)[0])
        for broken in [dict(events, function_names=names[:-1]),
                       dict(events, function_names=names[:-1]+['Other.renamed()']),
                       dict(events, parameter_case_invocations=1),
                       dict(events, bundle_counts=[9]),
                       dict(events, module_function_counts={'WrongModule': 10})]:
            self.assertFalse(check_result(command, 0, '', broken)[0])

    def test_composition_discovery_and_capacity_limits_are_not_blanket_successes(self):
        command = ['swift', 'test', '--package-path', 'Tools/CompositionQualification']
        events = dict(bundle_counts=[5], module_function_counts={'CompositionScaleTests': 5},
                      parameter_case_invocations=0)
        self.assertTrue(check_result(command, 0, '', events)[0])
        for broken in [dict(events, bundle_counts=[4]),
                       dict(events, module_function_counts={'WrongModule': 5}),
                       dict(events, parameter_case_invocations=1)]:
            self.assertFalse(check_result(command, 0, '', broken)[0])
        command = ['python3', '-B', 'Scripts/qualify_composition_scale.py']
        report = dict(status='passed', cells=8, completed_imports=5, operational_refusals=3,
                      adoption_status='bounded_fixtures_only', simple_strategy_capacity_status='blocked',
                      unmet_capacity_targets=['balanced-128-128'])
        self.assertTrue(check_result(command, 0, json.dumps(report))[0])
        for broken in [dict(report, completed_imports=8), dict(report, operational_refusals=0),
                       dict(report, unmet_capacity_targets=[]), dict(report, adoption_status='all_imports_qualified')]:
            self.assertFalse(check_result(command, 0, json.dumps(broken))[0])

        # Combined-source checks must retain both independently owned optional products.
        for module, count, command in [
            ('JSONNavigationTests', 57, ['swift', 'test', '--filter', 'navigation']),
            ('JSONInspectionTests', 76, ['swift', 'test', '--filter', 'inspection|snapshot|projectionP']),
            ('JSONSchemaExamplesTests', 98, ['swift', 'test', '--test-product', 'JSONSchemaExamplesTests']),
        ]:
            events = dict(bundle_counts=[count], module_function_counts={module: count},
                          parameter_case_invocations=0, function_names=sorted(PROJECTION_FUNCTIONS) if module == 'JSONInspectionTests' else [])
            self.assertTrue(check_result(command, 0, '', events)[0])
            for broken in [dict(events, bundle_counts=[count-1]),
                           dict(events, module_function_counts={'WrongModule': count}),
                           dict(events, parameter_case_invocations=1)]:
                self.assertFalse(check_result(command, 0, '', broken)[0])
        policy = DISCOVERY
        for key in ('root_functions', 'portable_root_functions', 'wasi_root_functions'):
            self.assertEqual(policy[key]['JSONNavigationTests'], 57)
            self.assertEqual(policy[key]['JSONSchemaExamplesTests'], 98)
            self.assertEqual(policy[key]['JSONInspectionTests'], 76)
            self.assertEqual(policy[key]['JSONIntegrationTests'], 32)
        for key in ('shared_state_functions', 'portable_shared_state_functions'):
            self.assertEqual(policy[key]['JSONNavigationTests'], 2)
            self.assertEqual(policy[key]['JSONSchemaExamplesTests'], 4)
            self.assertEqual(policy[key]['JSONInspectionTests'], 4)
            self.assertEqual(policy[key]['JSONIntegrationTests'], 11)

    def test_private_projection_identities_cannot_be_missing_renamed_or_duplicated(self):
        names = sorted(PROJECTION_FUNCTIONS)
        self.assertEqual(len(names), 32)
        self.assertTrue(check_projection_cases({'function_names': names}))
        for broken in [names[:-1], names + names[:1],
                       ['WrongModule.' + names[0].split('.', 1)[1]] + names[1:],
                       [names[0].replace('projectionP01', 'projectionP99')] + names[1:]]:
            self.assertFalse(check_projection_cases({'function_names': broken}))
        shared = ['JSONInspectionTests.projectionP16SharedViewsHaveIndependentHealthAndLegacyStatistics()']
        self.assertTrue(check_projection_cases({'function_names': shared}, shared=True))
        self.assertFalse(check_projection_cases({'function_names': []}, shared=True))

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.names = ['Sources/JSON/A.swift', 'Sources/JSONPatch/B.swift']
        self.policy = dict(root_functions={'JSONTests':1, 'JSONPatchTests':1},
                           coverage_unmapped={'Sources/JSON/Declaration.swift':'declaration'}, coverage_generated=[])
        for name in [*self.names, *self.policy['coverage_unmapped']]:
            source = self.root / name; source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text('// isolated harness fixture\n')
        summary = {kind:dict(count=2, covered=1) for kind in ['lines','regions','functions']}
        summary.update({kind:dict(count=0, covered=0) for kind in ['branches','mcdc']})
        self.export = dict(data=[dict(files=[dict(filename=str(self.root/name), summary=copy.deepcopy(summary)) for name in self.names])])

    def test_complete_denominator_and_unavailable_counters(self):
        result = validate_export(self.export, self.root, self.policy)
        self.assertEqual(result['authored']['lines'], dict(count=4, covered=2, percent=50))
        self.assertIsNone(result['authored']['branches']['percent'])
        self.assertFalse(result['branch_counters_available'])
        self.assertEqual(set(result['modules']), {'JSON','JSONPatch'})

    def test_integration_bundle_does_not_create_a_library_denominator(self):
        self.policy['root_functions']['JSONIntegrationTests'] = 20
        self.policy['coverage_modules'] = ['JSON', 'JSONPatch']
        result = validate_export(self.export, self.root, self.policy)
        self.assertEqual(set(result['modules']), {'JSON', 'JSONPatch'})
        objects = {name:object() for name in ['JSONSchemaTests/runner', 'JSONIntegrationTests/runner',
            'JSONSchemaTests', 'JSONIntegrationTests', 'JSONSchema', 'JSONTests/runner']}
        self.assertEqual(set(without_schema_objects(objects)), {'JSONTests/runner'})
        self.export['data'][0]['files'].pop()
        with self.assertRaisesRegex(ValueError, 'Incomplete library export'):
            validate_export(self.export, self.root, self.policy)

    def test_module_policy_cannot_hide_a_mapped_library(self):
        self.policy['coverage_modules'] = ['JSON']
        with self.assertRaisesRegex(ValueError, 'module policy differs'):
            validate_export(self.export, self.root, self.policy)

    def test_omitted_module_is_not_a_higher_percentage(self):
        self.export['data'][0]['files'].pop()
        with self.assertRaisesRegex(ValueError, 'Incomplete library export'):
            validate_export(self.export, self.root, self.policy)

    def test_duplicate_mapping_is_rejected(self):
        self.export['data'][0]['files'].append(self.export['data'][0]['files'][0])
        with self.assertRaisesRegex(ValueError, 'duplicate library mapping'):
            validate_export(self.export, self.root, self.policy)

    def test_unknown_library_mapping_is_rejected(self):
        self.export['data'][0]['files'][0]['filename'] = str(self.root/'Sources/JSON/Old.swift')
        with self.assertRaisesRegex(ValueError, 'Unexpected'):
            validate_export(self.export, self.root, self.policy)

    def test_new_mapping_requires_review_of_unmapped_disposition(self):
        entry = copy.deepcopy(self.export['data'][0]['files'][0])
        entry['filename'] = str(self.root/'Sources/JSON/Declaration.swift')
        self.export['data'][0]['files'].append(entry)
        with self.assertRaisesRegex(ValueError, 'classification changed'):
            validate_export(self.export, self.root, self.policy)

    def test_impossible_counters_are_rejected(self):
        for count,covered in [(1,2),(-1,0),(True,0),(2,0.5)]:
            broken = copy.deepcopy(self.export)
            broken['data'][0]['files'][0]['summary']['lines'].update(count=count,covered=covered)
            with self.assertRaisesRegex(ValueError, 'Invalid coverage counter'):
                validate_export(broken, self.root, self.policy)
        broken = copy.deepcopy(self.export)
        broken['data'][0]['files'][0]['segments'] = [[1,1,2**63-1,True,True,False]]
        with self.assertRaisesRegex(ValueError, 'Saturated LLVM coverage counter'):
            validate_export(broken, self.root, self.policy)

    def test_stale_classification_cannot_exclude_a_missing_file(self):
        (self.root/'Sources/JSON/Declaration.swift').unlink()
        with self.assertRaisesRegex(ValueError, 'absent source'):
            validate_export(self.export, self.root, self.policy)

    def test_exact_discovery_rejects_missing_duplicate_and_changed_parameters(self):
        summaries = ['Test run with '+str(n)+' tests in 0 suites passed' for n in ROOT_COUNTS.values()]
        cases = 'with '+str(PARAMETER_INVOCATIONS)+' test cases passed'
        valid = '\n'.join([*summaries,cases])
        self.assertTrue(check_root(valid))
        self.assertTrue(check_result(['swift','test'],0,valid)[0])
        for broken in ['\n'.join([*summaries[:-1],cases]), valid+'\n'+summaries[0], valid.replace(cases,'with 1 test cases passed'), '']:
            self.assertFalse(check_root(broken))
            self.assertFalse(check_result(['swift','test'],0,broken)[0])
        self.assertFalse(check_result(['swift','test'],1,valid)[0])
        identity = {'function_names': sorted(RESTORED_FUNCTIONS)}
        self.assertTrue(check_restored(identity))
        identity['function_names'][0] = 'JSONTests.unrelatedReplacement()'
        self.assertFalse(check_restored(identity))
        harness = ['python3', '-B', 'Scripts/test_qualification_harness.py']
        self.assertTrue(check_result(harness, 0, 'HARNESS_TESTS passed cases=18')[0])
        for stale in ['HARNESS_TESTS passed cases=10', 'HARNESS_TESTS passed cases=11', 'HARNESS_TESTS passed cases=12', 'HARNESS_TESTS passed cases=13', 'HARNESS_TESTS passed cases=14', 'HARNESS_TESTS passed cases=15', 'HARNESS_TESTS passed cases=16', '']:
            self.assertFalse(check_result(harness, 0, stale)[0])
        lifetime = ['python3', '-B', 'Scripts/qualify_schema_example_lifetime.py']
        marker = 'SCHEMA_EXAMPLES_CORPUS passed mode=owned scopes=128 values=6 exact=1'
        self.assertTrue(check_result(lifetime, 0, marker)[0])
        self.assertFalse(check_result(lifetime, 1, marker)[0])
        for stale in ['', marker.replace('128', '1'), marker.replace('exact=1', 'exact=0')]:
            self.assertFalse(check_result(lifetime, 0, stale)[0])
        # Scoped portability lanes retain exact discovery and safety rather
        # than describing an exit-zero subset as full qualification.
        output = pathlib.Path(__file__).resolve().parents[1] / 'Artifacts/HarnessProbe'
        linux = commands('linux-qa', output)
        self.assertEqual(sum(c[:2] == ['swift','test'] for c in linux), 4)
        self.assertTrue(all('--disable-xctest' in c for c in linux if c[:2] == ['swift','test']))
        qa = '\n'.join('Test run with '+str(n)+' tests in 0 suites passed' for n in DISCOVERY['qa_functions'].values())
        self.assertTrue(check_result(linux[4], 0, qa)[0])
        self.assertFalse(check_result(linux[4], 0, qa+'\nTest run with 1 test in 0 suites passed')[0])
        self.assertIn('--scope', commands('wasm-qa', output)[1])
        self.assertNotIn('--scope', commands('wasm', output)[1])
        self.assertEqual(commands('coverage', output), commands('linux-coverage', output))
        self.assertEqual(commands('linux-coverage', output)[1][1:3], ['-B', 'Scripts/coverage.py'])

    def test_darwin_executable_membership_is_exact(self):
        for name in ROOT_COUNTS:
            p = self.root / (name+'.xctest') / 'Contents/MacOS' / name
            p.parent.mkdir(parents=True); p.touch()
        self.assertEqual(set(executable_objects(self.root)),set(ROOT_COUNTS))
        p.unlink()
        with self.assertRaisesRegex(ValueError,'Missing or ambiguous'):
            executable_objects(self.root)

    def test_linux_runner_and_ambiguous_layout(self):
        for name in ROOT_COUNTS:
            (self.root/(name+'-test-runner')).touch()
        self.assertEqual(set(executable_objects(self.root)),set(ROOT_COUNTS))
        self.assertEqual(shared_objects(self.root), {})  # Static-linked backend remains valid.
        targets = set(ROOT_COUNTS) | set(DISCOVERY['coverage_modules'])
        for target in targets: (self.root/(target+'.so')).touch()
        self.assertEqual(set(shared_objects(self.root)), targets)
        (self.root/'libJSON.so').touch()
        with self.assertRaisesRegex(ValueError, 'Ambiguous instrumented library'):
            shared_objects(self.root)
        (self.root/(name+'.xctest')).touch()
        with self.assertRaisesRegex(ValueError,'Missing or ambiguous'):
            executable_objects(self.root)

    def test_checkout_identity_rejects_enclosing_git_and_accepts_own_checkout(self):
        self.assertIsNone(checkout_head(self.root))
        subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', 'init', '-q', str(self.root)], check=True)
        subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false', '-c', 'user.name=Harness', '-c', 'user.email=harness@example.invalid',
                        'commit', '--allow-empty', '-qm', 'owned fixture'], cwd=self.root, check=True)
        expected = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=self.root, text=True).strip()
        self.assertEqual(checkout_head(self.root), expected)
        nested = self.root / 'archive'; nested.mkdir()
        self.assertIsNone(checkout_head(nested))

    def test_cli_identity_ignores_git_time_and_generated_output_but_detects_source_change(self):
        (self.root / 'Package.swift').write_text('// package fixture\n')
        source = self.root / 'Sources/JSONCLIEngine'; source.mkdir(parents=True)
        owned = source / 'CLIReleaseVersion.swift'; owned.write_text('let version = "1.5.1"\n')
        first = rendered(self.root)
        (self.root / '.git').mkdir(); (self.root / '.git/HEAD').write_text('unrelated')
        (source / 'CLIBuildIdentity.swift').write_text('previous generated value')
        self.assertEqual(rendered(self.root), first)
        owned.write_text('let version = "1.5.2"\n')
        self.assertNotEqual(rendered(self.root), first)

if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(HarnessTests))
    print('HARNESS_TESTS '+('passed' if result.wasSuccessful() else 'failed')+' cases='+str(result.testsRun))
    raise SystemExit(0 if result.wasSuccessful() else 1)
