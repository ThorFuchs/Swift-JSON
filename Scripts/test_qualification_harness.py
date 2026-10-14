#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Negative coverage/discovery harness tests; never substitutes for Swift behavior."""
import copy
import json
import pathlib
import tempfile
import unittest
from coverage import executable_objects, validate_export
from test_discovery import DISCOVERY, ROOT_COUNTS, PARAMETER_INVOCATIONS, check_root
from ci import check_result, commands

class HarnessTests(unittest.TestCase):
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
        (self.root/(name+'.xctest')).touch()
        with self.assertRaisesRegex(ValueError,'Missing or ambiguous'):
            executable_objects(self.root)

if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(HarnessTests))
    print('HARNESS_TESTS '+('passed' if result.wasSuccessful() else 'failed')+' cases='+str(result.testsRun))
    raise SystemExit(0 if result.wasSuccessful() else 1)
