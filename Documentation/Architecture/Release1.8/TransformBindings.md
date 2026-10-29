# Transform bindings — commissioned 1.8 candidate

The maintainer commissioned the source-definition codec, indexed selection and
compile reporting on 29 October 2026. Base is b8ddeb26042005a06360f50fcf20b1f840e66d1c.
This additive train preserves the existing 42 authored Transform declarations,
ordinary execution/CLI semantics, thirteen products and empty root dependencies.
Implementation and a successful spike are not release or downstream admission.


## Sprint 2 current selection contract

The maintainer commissioned the public selection increment on 29 October 2026.
Its exact base is Sprint 1 commit 70df9ba8d47322abf0d4aec1439256d7a5e97e94.
Historical Sprint 1 scope/evidence below remain source-bound. This increment
ships the selection facade in JSONTransform without a new product/dependency or
changes to the private compiler/VM, ordinary execution or CLI adapters.

Selection convention V1 is explicit: input [0,...,N-1], reserved declared `$values`
containing the admitted population, and exactly the other declared bindings from
the caller. Overriding values or missing/foreign/invalid binding names fails.
The finite population default is 65,536; zero is valid. Native and Transform
limits remain additional ceilings, including live collection slots. Projection
slots/text/metadata and numeric construction are admitted before owned growth.
Population admission occurs once, including unused tails, on the same context as
projection, VM work, native index validation, output leases and completion.

Optional input/inputs callbacks use existing query semantics and explicit caller
code. They cannot expand the declared population. Nil is provider EOF, null is a
value. Provider admission/calls triggered by evaluation consume the same finite
input/work/retention policy; arbitrary callback instructions and prior caller
allocations remain caller work. A separate health cell supplies prepaid entry
snapshots and prevents context borrowing during reentry. Provider/reentry/cancel
failures latch before accepting another value or another callback.

Public positions retain one shared population owner and a per-output slot lease.
The population owner includes unforgeable invocation identity. Completion exists
only after explicit evaluator EOF and successful cleanup; its identity/report
lease does not retain the population. Completion.ordinal(of:) rejects foreign
positions through constant metadata inspection, without reopening a completed
operation. Raw ordinals/caller mappings are not stable IDs or read grants.

Boundary invalidity bypasses query catches. Uncaught language, resource, provider,
cancellation and lifecycle failures latch. Caught errors, abandoned prefixes and
late failures cannot certify. A first operational failure wins over a later caller
error; otherwise caller errors retain identity. Escaped scopes/closures cannot
resume after close. report() drains deferred refunds after success/error/cancel;
work never refunds. Completion.statistics is a close-time snapshot; current
terminal accounting is observed through the guarded scope. Scope/position/
completion handles are deliberately non-Sendable; plans remain checked Sendable.

Completion, report, scope and position constructors are inaccessible to public
callers. The generic JSONOperationReport initializer cannot construct a selection
witness. No provenance propagation, second interpreter, VM serialization, online
resolution, Content code/lock or unbounded streaming/sort promise is introduced.
See the [public guide](../../../Sources/JSONTransform/Documentation.docc/IndexedSelection.md) for usage.

## Definition V1

JSONTransformProgramDefinition stores exact source and unique ASCII variable names
in ascending UTF-8 order. It does not add source storage to compiled plans. There
is no synthesized String-based equality/hash or serialized VM/host state.

Canonical encoding is compact UTF-8 without a BOM or newline, with fields in this
order: definition, version, dialect, source, variables. Their values are
"swift-json-transform-source", mathematical integer 1, "swift-json-query-v1", the
exact source string, and the ordered name array. Native JSONWriter supplies all
escaping: direct non-ASCII UTF-8, escaped quote/backslash, lowercase control-byte
escapes. This format is distinct from an implementation digest and execution policy.

Decoding accepts one strict native JSON document with exactly those five decoded
keys and correct field types. Equivalent JSON escaping, field order, whitespace
and numeric spelling of version 1 are accepted; re-encoding is canonical. Unknown
fields, duplicate decoded keys/names and unknown versions/dialects fail. This is
strict semantic decoding, not a canonical-input assertion. A storage gateway that
requires canonical input must compare against bounded canonical output under its
own explicitly reviewed policy. Query syntax is checked by the existing compiler,
not the codec. Names use [A-Za-z_][A-Za-z0-9_]* without dollar prefixes and are
validated before any Set conversion. No credentials, files, closures, Content
objects, SCCV/SCCD data, artifact hashes or online resolution are encoded.

The finite codec defaults are source 1 MiB, 128 names, 128 bytes/name, 8192 total name
bytes and 2 MiB wire bytes, alongside the existing balanced JSON limits. Native work
meters sorting, parsing, scanning, construction and writing; retention is reserved
before owned growth. Limits are checked at invocation entry; helpers share that
one meter. Existing 49 core policies and their probes are unchanged. Logical bytes
are reservations, not RSS. Supplied input storage and later caller copies are caller
work. Prepare, decode, encode and compile are explicitly separate operations; no
decode-and-compile convenience secretly restarts a single composed invocation.

Successful preparation/codec operations return native reports. Compilation uses
the existing compiler/context and returns actual native work. The additive
compileWithReport path preserves old compile behavior; the definition adapter
also charges its owned variable Set construction. No public meter is exposed.

## Historical Sprint 1 selection plan

The proposed convention is an invocation-owned ordered array [0,...,N-1] as input
and a reserved explicit values binding containing the complete population. The
selection convention needs its own revision, separate from the language/wire
revisions. Reserved-name collisions and provider policy must be frozen before
public selection API admission. Content-specific mapping/identity stays outside.

The existing query engine alone filters/sorts; it must explicitly emit numeric
ordinals. Native mathematical integer conversion admits 42.0 and negative zero as
their exact integer identities; fractions, negative values, other kinds, overflow,
native-width failure and out-of-population values fail. Output order/repeats are
preserved. Deterministic tie keys belong in the program; no hidden deduplication.

One invocation must own population admission, index construction, VM evaluation,
numeric checks and typed output slots. Position handles need an unforgeable owner
and a joint population lease even when the numeric output was newly computed.
An explicit EOF state is required to certify completion. A caught boundary error
or abandoned prefix cannot produce a completion witness. Generic JSONOperationReport
has a public pairing initializer and is not that witness; public completion will
need a private initializer and owner-produced statistics. Query catches cannot
swallow boundary failures. First cause, cancellation and terminal lease refunds
must remain observable without reopening execution. Handles stay guarded and
non-Sendable; immutable plans/definitions remain checked Sendable.

Sprint 1 keeps this experiment solely in IndexedSelectionSpike.swift in the test
target. It reuses FilterVM/TransformRuntimeContext and native values; it is not a
second interpreter or a shipped selection facade. Its 1024 population bound and
test provider are experimental, not approved public defaults/provider semantics.
Full reentry/public compiler-negative/lifetime/profile qualification belongs to
the next increment. General provenance propagation, persistence of executions,
unbounded input/sort guarantees and Content implementation are outside scope.

## Qualification and admission

Run Scripts/ci.py lanes transform-bindings and transform-bindings-safety for this
sprint's actual cases and public consumer. Preserve the original 23 Transform cases,
all old suites/fixtures and CLI checks. Source/CLI identity, public declarations,
native strict-memory checks and DocC must bind the final checkpoint. Full Native,
Linux ARM64/x86_64, WASI and relevant Apple checks are required for the eventual
release; unavailable/unrun lanes stay open. Earlier 1.8 receipts and 1.7 performance
waivers do not qualify these source changes. Existing performance/allocation holds
remain. No merge, tag, publication or cross-session message is commissioned here.

The downstream S06/S13 profile mapping and deliberate Content lock selection remain
separate decisions after a qualified public binding. M0 stays independent; no S04
history, Content repository, source pin or admission gate is changed by this train.

The [Sprint 1 qualification record](../../Qualification/TransformBindings1.8.md)
separates completed local checks from the remaining public-selection/release gates.
