# Support and maintenance

Swift-JSON is maintained by [Thorsten Fuchs (@ThorFuchs)](https://github.com/ThorFuchs).
Use [GitHub Issues](https://github.com/ThorFuchs/Swift-JSON/issues) for reproducible
defects, documentation corrections and focused feature proposals. For security
reports, use the private route in [SECURITY.md](SECURITY.md).

The stable support policy is **the latest published 1.x release**. Fixes are shipped
in that line; users of older 1.x versions should upgrade. Before the first stable
release, `main` is a candidate with best-effort maintenance. There is currently no
1.0.0 tag or GitHub release. No paid support, response-time SLA or older-line
backport commitment is implied.

The package requires Swift tools/compiler 6.4+, Swift language mode 6 and
macOS/SDK 27+. Native qualification began on Apple Silicon; other platforms or
architectures are not claimed qualified. Reports should include the resolved
commit/version, native toolchain, resource profile and a minimal reproducible input.

Within 1.x, changes follow semantic versioning: compatible fixes in patch releases,
compatible additions in minor releases, and breaking public-contract changes in a
new major release. Review observable exact-number/scalar, error, completion and
accounting semantics as part of API compatibility. Published default-limit changes
must be explicit in the changelog and release notes; finite limits are policy,
not an RSS or throughput SLA.

Normal changes use pull requests and appropriate native checks. The maintainer
owns review and releases; contribution guidance is in [CONTRIBUTING.md](CONTRIBUTING.md).
