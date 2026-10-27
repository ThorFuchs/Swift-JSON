# Release process

Use the [release roadmap](Documentation/ReleaseRoadmap.md) for the proposed 1.7–2.0
sequence. All SwiftPM products in a repository tag share that version; a roadmap
is not tag, publication or new public API approval.

Keep the [stable/development matrix](Documentation/Qualification/ReleaseLines.md)
source-bound. Prepare 1.6 maintenance releases from the pre-N2 line, not current
main. Preserve published tags/assets and map applicable maintenance changes to
1.7.0-dev explicitly. Squash/rebase settings do not preserve maintenance-tip
ancestry; no merge-setting change is required. A clean path/revision consumer
is preparation evidence only: independently resolve the actual version tag after
publication. Metadata-only maintenance reuses unchanged-workload performance
dispositions; this does not close any held controlled-performance gate.

See the [maintenance CI procedure](Documentation/Qualification/MaintenanceCI.md)
for branch coverage, source-bound checks and build-incident handling.

Maintainer: @ThorFuchs. Version tags use semantic versions such as `1.0.0`.
Publication requires an explicit maintainer instruction; CI never creates tags
or releases. Published version tags are protected against updates and deletion.

1. Require passed native, safety, documentation and Git-free archive lanes for
   the exact candidate commit on macOS/SDK 27+ and Swift 6.4+ with language mode 6.
   Retain both ARM64 and x86_64 Linux behavior/safety receipts for portable changes.
2. Derive the exact branch-specific product, catalog and API inventory from the
   candidate manifest and compiler graphs. The 1.6 maintenance line has eight
   libraries plus CLI, eight catalogs and 1,077 authored declarations; 1.7-dev
   consolidation has twelve libraries plus CLI and thirteen catalogs including
   the shared JSONDSLCore reference. Derive authored counts from compiler graphs. Inspection
   is not a 1.6 patch feature. Review the empty root dependency graph, compiled
   external consumers, populated pinned suites, policy exclusions, all 49 finite
   caps, schema/regex behavior and cancellation boundaries.
3. Review licenses, provenance, public file inventory and documentation links.
   Keep private records, credentials, input clones and build outputs out of source
   archives and Git history.
4. Measure changed workloads on an idle supported host unless a specific maintainer
   exception is recorded for the actual final source. The frozen RC6fe8067's
   loaded-host observations and one-time Transform allocation-instrumentation
   waiver remain historical scoped evidence. Later44/150 and119/150 windows are
   partial, not population/overhead passes. A combined1.7 candidate needs an
   explicit scope mapping and final-source disposition; do not infer blanket
   acceptance from the version number. Preserve Navigation G4 HOLD, the unchanged
   10% review trigger and historical streaming disposition. Logical retention is
   not RSS/heap allocation. See [current preparation](Documentation/Qualification/Release1.7Preparation.md)
   and the [historical contract](Documentation/Qualification/Release1.7.0.md).
5. Update CHANGELOG.md and compatibility notes, then run
   `python3 Scripts/archive_candidate.py --output Artifacts/Swift-JSON-public-candidate.tar.gz`.
   Verify embedded hashes, byte-equal rebuild and a clean extracted build/test with
   `Scripts/ci.py --lane native`. The automated `--lane archive` performs the
   complete native lane outside Git and verifies a byte-equal extracted rebuild.
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
