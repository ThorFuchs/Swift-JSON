# CLI integration and distribution

The 1.4 integration branch starts at advanced filters `8d00757`, draft PR #26.
Its prerequisite is renderer `3c1e8a1a` (PR #21). Transfer/RTF/PDF and parallel
1.2 graphs remain unchanged. The native executable has six root products and
no external root dependencies. No public query library is exposed.

`stream check|cat|array` borrows the same job context as native parsing/writing.
check waits for every required EOF before emitting `{completed,inputRecords}`.
cat uses strict document/values/NDJSON framing and compact JSON+LF. array yields
complete elements provisionally; closing syntax, trailing whitespace and EOF
remain mandatory. A late error preserves an existing named output through
exclusive staging, while previously accepted stdout bytes cannot be recalled.

`schema check SCHEMA --resource URI=PATH` compiles an explicit offline Draft2020-12
object or Boolean schema and emits completed metadata, without instance evaluation.
Resource files, native meta-schemas, compilation and output share cumulative work.
No reference fetch occurs. Known provider adapters return exit2/capabilityUnavailable:
qualified helper declarations are absent at both renderer base and the observed
transfer branch. Their mandatory authored success/rejection vectors remain blocked;
a rejection test for unavailability is not a provider qualification success.

JSONHTML provides static (expanded, script-free) and explicitly interactive HTML.
Text/Markdown use actual tab indentation and preserved exact number lexemes.
No Apple PDF preparation or transfer-provider runtime is needed for these commands.
The command-specific help and JSON version metadata enumerate only compiled
capabilities; source-checkout revision remains `unknown`. Malformed UTF-8 in a
filter file is compile exit3; malformed raw binding text remains input exit5;
missing files remain IO exit7. Operational failures bypass language catches.

The real POSIX sink delegates progress to a private tested handoff loop. Short
writes, readiness retries and foreign calls have checked progress/cancellation;
zero progress is terminal IO. One handoff is outstanding, with no queued whole
output. Caller/foreign instruction time and kernel latency are outside quotas.
Finite work is monotonic; live ownership refunds never refund consumed work.

Distribution qualification copies the real release binary and schema bundle
into a directory with spaces, executes outside the checkout, tests leading-dash
input names and rejects a tampered sibling meta-schema. SwiftPM may retain a
build-directory fallback; absence is tested separately only from clean reproduction
with that original bundle unavailable. No assumption that copying only the binary
is sufficient is made. Package-wide and selected-library claims stay distinct.

`Tools/CLIQualification` also has a qualification-only five-library mobile target.
It imports JSON/Schema/Streaming/Patch/HTML, with no CLI, private filter, stdio or
Apple export requirement. iOS/iPadOS share the iOS27 deployment declaration.
WASI CLI feasibility and private wasm32 arithmetic outcomes are separate; a
compiled kernel is not an argv/filesystem/signal/resource-qualified CLI.

Final-source receipts, exact acceptance statuses, archive/reproduction, installed
consumers, platform observations and performance limitations accompany the return
bundle. No merge, release tag, publication, PATH change or remote CI activation
is performed by these adapters.

## Native and platform milestone

Native, safety and core/HTML WASI lanes passed unchanged source manifest
`68463696a494417a6509e7330cec0343a9199cb10f806cadfe4ff4d7506c9964`.
Native executed25 commands, debug/release297 functions/199 parameter cases.
ASan matches those counts; TSan covers8 shared functions and strict-memory
compilation has zero warnings. Baseline suites/cap/exclusion counts are retained.
The affected CLI review lane then passed77 functions,53 foundation and36 integration
subprocess cases,33 real site/report checks for16 caps, and105 C1-C4 vectors.
The6 authored C5 rows have4 passes and2 blocked provider rows, not policy successes.
An independent500-case bounded malformed-query replay had no crashes/timeouts.

The source review reproduced invalid presentation/framing being masked by input
or compiler errors. Early argument checks and two real subprocess regressions
now preserve usage exit2. Clean-source Git identity is recorded only when the
queried top-level checkout is the actual source directory; ancestor Git is ignored.
The predecessor clean928-file archive passed ten CLI-lane commands; its incidental
ancestor Git SHA is explicitly non-authoritative. Final successor extraction uses
archive/file hashes and isolated Git discovery.

WASI now has narrow WASILibc/entry guards, with native signal behavior unchanged.
The CLI module compiles with matched Swift6.4.0 SDK. WasmKit0.3.1 executes exact
format, Cartesian query, completed root-array stream, offline schema and static
HTML commands. The first Node26.5.0 version execution with file-backed output failed IO exit7:
actual poll_oneoff returned WASI errno28; tracing is qualification-only. The
corrected module passes version/format/query/root-array/static HTML with pipe
stdio. Explicit schema-file reading and regular-file stdout still fail poll
with errno28 and exit7. Descriptor layout is recorded in the return matrix;
these partial successes do not qualify all file/stdin/stdout adapters. No
blocking fallback is used.
CLI POSIX SIGINT bridging is absent on WASI, so these five command outcomes are
a limited disposition, not full CLI qualification.

The preserved WASI lane executes220 core/HTML functions in debug/release and173
parameter cases,13 public consumer functions on each host,49 actual cap outcomes,
20 explicitly rooted downstream vectors, unchanged independent suites and native
strict-memory compilation. The earlier104-count JSON harness was corrected upward
to107 after actual discovery/passes; its failed receipt is retained. New CLI tests
are compiled but are outside that core/HTML execution claim. Unsupported ASan/TSan
WASI instrumentation retains its explicit original policy rather than a safety pass.

The selected five-library target compiled on iPhoneOS/iPhoneSimulator SDK27.2 with
no CLI/filter target contamination. Release-native slow-sink medians were0.3144s
for2000 and3.5305s for20000 records on a heavily loaded host; logical retention
stayed about66.5KB and process RSS about7.6MB. These distinct observations support
bounded logical pipeline state, not quiet-host throughput or hard RSS promises.
Final-head hosted checks/reproduction and the return manifests bind the successor.


## Checked resource successor

Clean installation of predecessor `9a773f3` reproduced a SIGTRAP when the sibling
schema bundle and SwiftPM fallback were both absent. Its archive `cf72bb6c…`
and failed receipt remain immutable and are not release qualification evidence.
The successor replaces the generated trapping Bundle.module accessor with finite,
checked app/framework/command lookup. Apple `.bundle` and Linux `.resources`
layouts retain all nine size/SHA pins; a corrupt present bundle is not bypassed.
Missing resources throw a schema metaSchema error. The actual installed consumer
now requires exit5/no output for missing and tampered resources, with a positive
sibling-resource case. One new Swift Testing function exercises missing lookup,
shared work/retention, quota failure and in-loop cancellation.

`Scripts/ci.py --lane native` passed25 commands with298 root functions/199 parameter
cases; safety passed ASan298/199, TSan8 and strict-memory/warnings-as-errors. The
CLI adapter boundary is now53 foundation +37 integration subprocesses,77 CLI
functions/26 parameter cases,33 checks across16 CLI metrics, and105 C1-C4 vectors.
The resource-fix runtime/source manifest is
`c81e1eb3526a2f67546af9a1d906638ef1b506721390876d4bab8da5343619f8`.
Native, resumed safety and resumed WASI receipts record unchanged source inputs.
WASI executes221 core/HTML functions in debug/release with173 parameter cases,
all49 cap outcomes, public/rooted consumers and the unchanged pinned independent
suite counts. Missing-resource and strict-memory probes pass. CLI WASI runtime
support remains the separate limited disposition above. Both selected mobile
SDK consumers passed on27.2 without CLI contamination.

Disk-full safety/WASI attempts and a SwiftPM lock-banner failure remain failed or
incomplete records. Only completed caches owned by this CLI worktree were cleared;
source and materialized receipts were preserved, and separate complete reruns passed.
Resource-fix slow-sink release medians are0.0803s/2.7205s for2000/20000 records;
peak logical retention is about66.5KB and measured RSS about7.5MB on a loaded host.
There is no quiet-host throughput or hard RSS claim. Final-head hosted checks,
source archive, clean extraction and acceptance closure are bound by the returned
freeze/evidence records. Mandatory provider CL078/CL079 remain blocked.
