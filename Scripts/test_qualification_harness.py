        harness = ['python3', '-B', 'Scripts/test_qualification_harness.py']
        self.assertTrue(check_result(harness, 0, 'HARNESS_TESTS passed cases=26')[0])
        for stale in ['HARNESS_TESTS passed cases=32', 'HARNESS_TESTS passed cases=31', 'HARNESS_TESTS passed cases=30', 'HARNESS_TESTS passed cases=10', 'HARNESS_TESTS passed cases=11', 'HARNESS[...]
