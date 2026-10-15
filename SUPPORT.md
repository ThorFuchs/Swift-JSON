# Support and maintenance

Swift-JSON is maintained by [Thorsten Fuchs (@ThorFuchs)](https://github.com/ThorFuchs).
Use [GitHub Issues](https://github.com/ThorFuchs/Swift-JSON/issues) for reproducible
defects, documentation corrections and focused feature proposals. For security
reports, use the private route in [SECURITY.md](SECURITY.md).

The stable support policy is **the latest published 1.x release**. Fixes are shipped
in that line; users of older 1.x versions should upgrade. The `main` branch tracks
development and receives best-effort maintenance. No paid support, response-time SLA or older-line
backport commitment is implied.

The package requires Swift tools/compiler 6.4+ and Swift language mode 6.
Apple deployment minima are macOS 27 and iOS/iPadOS 27, with SDK 27+.
Linux qualification covers Swift 6.4 on 64-bit Ubuntu 24.04/glibc, ARM64 and x86_64.
WASI core libraries have a separate host-specific qualification scope; this does
not claim full CLI/WASI support. Apple PDF and native transfer are Apple-only.
See the [Linux](Documentation/Architecture/Linux.md) and
[WASI](Documentation/Architecture/WebAssembly.md) contracts and the exact release assets.
Reports should include resolved commit/version, OS/architecture, compiler/SDK,
resource profile and a minimal reproducible input.

Within 1.x, changes follow semantic versioning: compatible fixes in patch releases,
compatible additions in minor releases, and breaking public-contract changes in a
new major release. Review observable exact-number/scalar, error, completion and
accounting semantics as part of API compatibility. Published default-limit changes
must be explicit in the changelog and release notes; finite limits are policy,
not an RSS or throughput SLA.

Normal changes use pull requests and appropriate native checks. The maintainer
owns review and releases; contribution guidance is in [CONTRIBUTING.md](CONTRIBUTING.md).
