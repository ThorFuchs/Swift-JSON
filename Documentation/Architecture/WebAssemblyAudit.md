# WebAssembly discovery audit

WebAssembly remains unqualified. This audit leaves every production source,
published profile, Apple/Linux lane and root manifest unchanged. The isolated
consumer and local CI lane provide reproducible evidence for the next decision.

## Executed target and tools

The official full-language Swift 6.4.0 SDK targets `wasm32-unknown-wasip1`.
The SDK archive is pinned to SHA-256
`f07b7be3c586d92d7a07051fc6d303b87ebea67eadc40640ba59d5a8b79aa86d`.
The [Swift SDK guide](https://www.swift.org/documentation/articles/wasm-getting-started.html)
requires a matching Swift.org host toolchain. The audit uses that toolchain
explicitly and does not change the Apple toolchain selection.

All four library products and package-private JSONRegexRuntime cross-build.
The separate consumer links them into a WASI command. WasmKit and Node/V8 execute
the same bytes, including guarded scoped reads and async source/sink behavior.
The [Node WASI API](https://nodejs.org/api/wasi.html) is an external test host;
it adds no Swift or npm dependency and is not a security boundary for untrusted
modules.

## Observations and evaluated behavior

| Slice | Actual audit boundary |
| --- | --- |
| Exact model/codec/Pointer | Conservative-profile exact UInt64/Decimal projections, scalar-distinct keys, order-independent equality, strict malformed-input rejection and Pointer resolution |
| Coding/read scope | Exact native model/Data coding, one cumulative scope, terminal escaped-cursor invalidation and released logical root/path state |
| Budgets and Patch | Composed builder quota rejection, parser exhaustion, RFC 6902/RFC 7396 and root absence distinct from null |
| Schema/regex | Nine integrity-pinned resources, explicitly rooted definition, exact minimum, invalid verdicts distinct from operational exhaustion, named capture/backreference and eight independent evaluations of one immutable plan |
| Streaming | One-byte pulls, complete root arrays, provisional elements followed by invalid tails, strict NDJSON, awaited output and no later writes after cancellation |
| Full root suite | Compilation blocked by the existing Dispatch-based cancellation observer; zero root cases evaluated |
| Embedded Swift | JSON target compilation blocked by missing Foundation; no reduced API is substituted |

The tool has 13 Swift Testing functions: 12 feature groups and one observation
of profile/persistence behavior. The two WASI engines each run these functions
and the public command modes. Tests asserting a known blocker remain observations,
not evaluated successes for the blocked defaults. These small probes do not
replace the pinned independent suites, all 49 cap probes or native safety lanes.

## Build modes and safety observations

The optimized command also passes all 12 feature groups in both engines; the
default/profile observations remain blocked in release mode. Full-library WASI
compilation with strict memory safety and warnings as errors succeeds. This is
compiler evidence, not a complete runtime safety qualification.

The matching compiler rejects Address Sanitizer for wasm32-unknown-wasip1.
SwiftPM accepts a Thread Sanitizer build command, but the captured verbose
compiler/linker commands contain no thread-sanitizer instrumentation options.
Its exit-zero build is not a Thread Sanitizer pass. Existing Apple/Linux sanitizer
lanes remain authoritative for those unchanged sources; a WASI safety policy
needs its own explicit review and evidence.

## Default profile and persistence blocker

`JSONLimits.validate()` currently checks every maximum against `Int.max`.
On wasm32, balanced `totalWorkUnits` is 2,147,483,648 and is rejected before
any operation. Offline also rejects `totalInputBytes` 68,719,476,736 and
`totalWorkUnits` 137,438,953,472. Thus even `JSONParser().parse("0")` fails
with configuration/invalidLimits. Conservative validates and enables the explicit
probes above. No default value is reduced in this audit.

`JSONCodablePayload` first validates balanced before intersecting explicit limits,
so passing conservative limits cannot open its persistence path on wasm32.
This is an operational configuration failure, not corrupt input or lost precision.

A support implementation should distinguish allocation/index capacities requiring
Int conversion from cumulative UInt64 work and lifetime counters. Audit every
actual narrowing conversion and checked growth path before choosing that change;
retain finite defaults and native rejected-configuration behavior where relevant.
Requalify all affected cap boundaries and composed operations on wasm32 and the
existing 64-bit platforms. A blanket weakened validator or silent profile clamp
would not establish support.

## Host and deployment boundary

The actual module imports WASI Preview 1 functions and exports memory and `_start`.
Bare WebAssembly instantiation without those imports fails. That probe runs in
Node; it is not a browser execution result. Browser hosting would require an
explicit host design and separate execution evidence. No JavaScript bridge, DOM,
worker or protocol API is added here.

The copied schema bundle must be shipped beside the command and its directory
preopened. Mounted discovery works in both engines; unmounted Foundation/SwiftPM
bundle discovery traps before a package schema error can be returned. This is
a deployment requirement and an error-boundary concern to resolve/document in a
support proposal. Loading arbitrary supplied registries does not eliminate the
compiler's official bootstrap resource requirement.

Swift tasks use the cooperative single-threaded WASI executor. The sharing probe
establishes separate invocation state in that execution model; it does not prove
worker parallelism, CPU offloading or preemption during synchronous validation.
Cancellation is checked at operation entry and after awaited sink acceptance.
No wall-clock cancellation guarantee is inferred.

## Proposed qualification sequence

1. Review the capacity/counter distinction and persistence intersection behavior,
   with wasm32 boundary cases and unchanged Apple/Linux tests.
2. Establish a portable cancellation-observer lane without deleting the existing
   native Dispatch rendezvous tests; preserve discovery/cardinality and fixture policies.
3. Freeze WASI resource packaging, host permissions and error behavior. Run the
   public frozen consumer, independent schema/syntax/regex/Unicode suites and all
   49 metric probes with populated outcomes.
4. Check available safety instrumentation, debug/release parity, clean extracted
   reproduction and runtime memory/retention/performance. Logical bytes remain
   distinct from linear memory or host RSS, and quotas remain distinct from fuel.

Only after these gates pass should a separate additive support PR update the
platform contract. Browser hosting, wasi-threads, wasm64 and Embedded Swift remain
separate decisions. E11/E12 and additional root dependencies remain out of scope.
