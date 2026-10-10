# Fixture policy

core-regressions.json contains original independent input/expectation vectors.
It is not a passing test suite. Implement Swift Testing cases that feed the
actual engines and verify semantics, budgets and progress. Invalid UTF-8 uses
hex bytes so no host text decoder repairs it before the JSON engine sees it.

External suites are intentionally absent. Import exact pinned sources with
Scripts/import_fixtures.py; preserve licenses and a file manifest. Missing or
empty suites fail qualification. Large/performance inputs are generated without
retaining the whole stream; private conversation payloads never enter this repo.
