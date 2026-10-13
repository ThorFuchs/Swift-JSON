# Linux platform contract

This additive development branch prepares all four public products for 64-bit
Linux with Swift tools/compiler 6.4+ and Swift language mode 6. Initial execution
qualification targets Ubuntu 24.04 with glibc on ARM64 and x86_64. A platform
preflight identifies the actual runtime; cross-compilation alone cannot qualify
behavior or safety. Architecture-specific receipts must pass before claiming
that architecture qualified. Apple minimums remain macOS/SDK 27 and iOS/SDK 27.

The root manifest keeps an empty dependency graph and the same four products.
Linux does not need a SwiftPM deployment-platform entry. Foundation file/resource
access remains platform infrastructure; JSON semantics come from the package's
strict codec, exact decimal model and decoded scalar identity.

## Portable schema integrity

Packaged Draft 2020-12 resources retain their nine exact byte sizes and SHA-256
pins. An original package-private FIPS 180-4 SHA-256 implementation replaces
CryptoKit. It exposes no cryptography API or product and has no external dependency.
There is one implementation on Apple and Linux, with no alternate engine.

Schema loading passes its active cumulative compilation meter into hashing.
Byte ingestion, schedule expansion, compression rounds and hex output charge
work before execution and check cancellation at the configured quantum.
336 logical scratch bytes are admitted before state/schedule allocation, then
128 bytes cover the simultaneous hex buffer and returned string. Scratch is
released after success, operational rejection or cancellation; callers account
for the 64-byte returned digest until releasing it. These weights describe logical
retention, not process RSS, allocator metadata or cryptographic throughput.
Standard UInt32 wrapping arithmetic implements SHA-256; resource counters remain
checked UInt64 arithmetic. Integrity mismatch is a compilation failure; exhausted
quotas and cancellation remain operational errors.

Independent Python hashlib vectors cover 24 deterministic lengths around padding
and block boundaries. Standard empty/abc/56-byte/million-a answers, cumulative
N/N-1 work, scratch admission, input quota, quantum, cancellation, corruption and
concurrent invocation cases supplement the unchanged schema and Unicode corpora.
The trusted qualification executable mirrors the core byte for byte, enforced
by the public inventory check. Its fixture hashing is harness work; library
operations always use the real checked meter.

## Qualification boundary

Run `python3 Scripts/ci.py --lane linux` and `--lane linux-safety` on the Linux
runtime. These preserve exact test discovery, all 49 cap probes, both pinned
independent suites, authored replay and the 20 explicitly rooted public consumer
cases. SwiftData examples and Apple SDK/compiler ownership probes remain in the
Apple lanes; they do not become Linux evaluated successes. DocC qualification
continues on the supported Mac toolchain.

The pinned Swift 6.4 Linux runtime leaks from an empty XCTest runner and
Foundation's `Data(contentsOf:)` empty-file read. Isolated sanitizer probes
reproduce both with no JSON imports. Linux safety starts only Swift Testing
(all 180 functions and 173 invocations remain) and trusted fixture I/O uses
explicitly closed FileHandle reads, including the zero-byte JSON rejection case.
Address/Leak Sanitizer and Thread Sanitizer remain enabled without suppressions.
Diagnostic upstream failures are recorded separately from package behavior.

The public consumer resolves its copied Resources directory relative to bundleURL;
Linux Foundation can already point resourceURL into that directory. Both layouts
retain the same frozen definition/vector bytes and all 20 explicitly rooted cases.
Linux qualification also verifies a byte-equal source archive, extracts it into a
clean directory, builds all products and executes six integrity/resource cases
and the four-product public consumer from that extracted source.

WebAssembly, browser hosting, other distributions, musl deployment and 32-bit
profile calibration require separate qualification. This change adds none of
those claims. The concurrent schema-builder accounting change is a separate
integration dependency; this branch preserves its base implementation untouched.
