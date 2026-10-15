# Release process

Maintainer: @ThorFuchs. Version tags use semantic versions such as `1.0.0`.
Publication requires an explicit maintainer instruction; CI never creates tags
or releases. Published version tags are protected against updates and deletion.

1. Require passed native, safety and documentation lanes for the exact candidate
   commit on macOS/SDK 27+ and Swift 6.4+ with language mode 6.
2. Review eight public products (including JSONHTML, opt-in JSONBridges and the
   two opt-in DSLs), the empty root dependency graph, compiled external
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
7. Create an annotated version tag at the exact qualified commit. Check its target
   before pushing: published tags cannot be moved. Prepare release notes, the source
   archive, the matching compiled DocC archive, a public qualification receipt and
   SHA-256 checksums. Upload only reviewed public assets; private maintainer records
   remain outside Git and the public release.
8. Verify the release assets against the checksum file and confirm that a separate
   SwiftPM consumer resolves the version tag. A draft release is preparation;
   publish it only when publication has been explicitly requested.

Creating a version tag and its GitHub release are deliberate maintainer actions after
this review. A successful CI run alone does not authorize them.

For 1.1.0, apply the maintainer-approved
[qualification policy](Documentation/Architecture/Release1.1/QualificationPolicy.json):
both mobile SDKs and iPhone/iPad simulator behavior/disk phases remain required,
along with physical iPhone checks. Physical iPad qualification is deferred and
does not block this release. Preserve that limitation in release notes; never
present simulator data as physical-device performance or memory evidence.
