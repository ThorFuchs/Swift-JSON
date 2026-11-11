    if 'Scripts/test_qualification_harness.py' in command:
        passed = passed and 'HARNESS_TESTS passed cases=26' in log.splitlines()
