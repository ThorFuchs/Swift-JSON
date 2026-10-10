# Release process

No version tag or GitHub release exists yet. Maintainer: @ThorFuchs. Publication
requires a separate explicit instruction; CI never creates tags or releases.

1. Require passed native, safety and documentation lanes for the exact candidate
   commit on macOS/SDK 27+ and Swift 6.4+ with language mode 6.
2. Review four public products, the empty root dependency graph, compiled external
   consumers, populated pinned suites, policy exclusions, all 49 finite caps,
   schema/regex behavior and cancellation boundaries.
3. Review licenses, provenance, public file inventory and documentation links.
   Keep private records, credentials, input clones and build outputs out of source
   archives and Git history.
4. Measure changed workloads on an idle supported host. A 10% median or retention
   change triggers review. Preserve the documented streaming regression disposition;
   logical retained bytes do not imply an RSS guarantee.
5. Update CHANGELOG.md and compatibility notes, then run
   `python3 Scripts/archive_candidate.py --output Artifacts/Swift-JSON-public-candidate.tar.gz`.
   Verify embedded hashes, byte-equal rebuild and a clean extracted build/test with
   `Scripts/ci.py --lane native`.
6. Retain source identity, environment, command exits, nonzero counts and receipts.
   Verify private reporting, support routes and branch protections.

Tagging 1.0.0 and creating its release are deliberate maintainer actions after
this review. A successful CI run alone does not authorize them.
