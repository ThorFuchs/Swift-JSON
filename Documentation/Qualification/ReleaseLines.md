# Stable and development source lines

| Line | Source identity | Public scope |
| --- | --- | --- |
| Published 1.6.0 | `f975ac1c5a18af9b422db0994cbc551fd37eee2f` | Eight libraries plus CLI, eight catalogs, 1,077 authored declarations |
| 1.6.1 maintenance | Pre-N2 base `e8b2864276d55f16479d7cce12c88b57cc754e44` plus the source-bound maintenance metadata | Same public API and runtime as 1.6.0; no Inspection |
| Unreleased 1.7.0-dev | Main, retaining N2 admitted at `2b24f47e7405821240cf8dfc66b840c9a7f8efa5` | Nine libraries plus CLI, nine catalogs, 1,121 authored declarations |

Source versions do not establish publication. Consult the
[official releases](https://github.com/ThorFuchs/Swift-JSON/releases) for published
versions and their exact assets. The immutable 1.6.0 publication remains recorded
in the [original qualification notes](Release1.6.0.md). The 1.6.1 edition is
described in [maintenance notes](Release1.6.1.md).

The [public website](https://thorfuchs.github.io/Swift-JSON/) tracks development
main, including unreleased Inspection. Stable release assets contain their own
eight-catalog compiled DocC reference; the main website is not an identical stable
reference. Installation examples retain the compatible `from: "1.6.0"` requirement.
Pin a reviewed version/commit and retain Package.resolved for reproducibility.

Navigation's 56 declarations are common to both lines. Inspection's 44 are only
on development main. N3 snapshots, private P1, DSL, independent composition/root
proposals and lower deployment floors are not part of this maintenance edition.
Swift tools/compiler 6.4+, language mode 6 and Apple OS/SDK 27+ remain required;
the separately qualified Ubuntu 24.04/glibc and full-language WASI scopes remain.

Applicable documentation/identity corrections are carried to main without
overwriting its version or N2. With squash/rebase integration, the maintenance
tip need not be an ancestor of main: use the exact commit/content mapping in
the release qualification receipt. No tag or release follows automatically from
a source version, merged PR, documentation deployment or successful CI run.
