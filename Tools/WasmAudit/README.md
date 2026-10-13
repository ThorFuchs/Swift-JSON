# WebAssembly audit consumer

This separate development tool imports all four public products from the local
package. It adds no root product or remote dependency. Its 13 Swift Testing
functions check explicit conservative behavior and record the default-profile
and persistence blockers. A test confirming a blocker does not qualify that
blocked capability.

Use the matching Swift.org 6.4.0 toolchain and `swift-6.4.0-RELEASE_wasm` SDK,
with WasmKit and Node on PATH:

```sh
python3 Scripts/ci.py --lane wasm-audit
```

The lane runs host consumer tests, cross-builds every library and the consumer,
and executes the same module and all 13 compiled Swift Testing functions in both
WasmKit and Node/V8. The two engines each exercise 12 named feature groups. Schema
cases require an explicit WASI preopen of the build-product directory containing
the copied nine-resource bundle. The unmounted failure remains in the receipt.
No debug bundle override is required for the mounted probes.

The harness also records profile rejection, bare-host import requirements,
the unchanged root suite's missing Dispatch module and Embedded Swift's missing
Foundation module. These nonzero/blocked outcomes remain separate from evaluated
successes. An exit-zero completed audit is not a WebAssembly support gate.

The [audit contract](../../Documentation/Architecture/WebAssemblyAudit.md)
describes the findings and the work required before adding a support claim.
No browser, worker-thread, hard memory or throughput qualification is implied.
