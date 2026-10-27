# Stable and development source lines

| Line | Source identity | Public scope |
| --- | --- | --- |
| Published 1.6.0 | `f975ac1c5a18af9b422db0994cbc551fd37eee2f` | Eight libraries plus CLI, eight catalogs, 1,077 authored declarations |
| Published 1.6.1 (latest stable) | `e431f157ececc0cf3d061192420b0e36a9062f83` | Same eight-library public API and runtime as 1.6.0; no Inspection |
| Consolidated development source | Main, retaining N2 admitted at `2b24f47e7405821240cf8dfc66b840c9a7f8efa5` | Twelve libraries plus CLI; thirteen catalogs including shared JSONDSLCore; compiler-derived API inventory required |

Source versions do not establish publication. Consult the
[official releases](https://github.com/ThorFuchs/Swift-JSON/releases) for published
versions and their exact assets. The immutable 1.6.0 publication remains recorded
in the [original qualification notes](Release1.6.0.md). The 1.6.1 edition is
described in [maintenance notes](Release1.6.1.md).

The [public website](https://thorfuchs.github.io/Swift-JSON/) tracks development
main, including unreleased Inspection. Stable release assets contain their own
eight-catalog compiled DocC reference; the main website is not an identical stable
reference. Installation examples retain the compatible `from: "1.6.0"` requirement.
The compatible requirement can resolve 1.6.1; use `exact: "1.6.1"` and retain
Package.resolved when reproducing the independently verified patch release.

Navigation's 56 declarations are common to both lines. Inspection's original 44 array-evidence declarations and NAV8 snapshot/projection
additions are only on development main. N3 snapshots, private P1, DSL, independent composition/root
proposals and lower deployment floors are not part of this maintenance edition.
Swift tools/compiler 6.4+, language mode 6 and Apple OS/SDK 27+ remain required;
the separately qualified Ubuntu 24.04/glibc and full-language WASI scopes remain.

Applicable documentation/identity corrections are carried to main without
overwriting its version or N2. With squash/rebase integration, the maintenance
tip need not be an ancestor of main: use the exact commit/content mapping in
the release qualification receipt. No tag or release follows automatically from
a source version, merged PR, documentation deployment or successful CI run.

NAV8 completes source-attached N3 snapshots and public P1 tree/sparse-table views
within the existing Inspection product; see [the completion contract](../Architecture/StructuralIntelligence/NAV8Completion.md).
Stable 1.6.1 has neither. Consolidated development source stays 1.7.0-dev with thirteen products. G4 controlled
performance remains HOLD without speed claims; this is distinct from technical
qualification and does not authorize any release/tag.

## Forward release plan

See the [1.7–2.0 roadmap](../ReleaseRoadmap.md) for the proposed shared-version
sequence, current product inventory, direct Navigation ownership and remaining
source-bound release gates. The proposal creates no release or new API approval.

## Historical JTX10 unpublished 1.7.0 candidate

The isolated JTX10 successor integrates main
`1a0306d076a08c8c43281f91412a11cd744ff3f6` with accepted Transform
`21199f9af5bf50f1d473c6d3e67b91ae91f75089`. It reports 1.7.0 and has ten libraries
plus CLI, ten catalogs and 1,214 authored declarations (Inspection 95, Transform 42).
It does not change the stable 1.6 line, publish a tag, merge main or retire proposals.
The earlier main/development observations above retain their historical scope.
Use [the candidate contract](Release1.7.0.md) and actual source-bound receipts.
