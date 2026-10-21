# NAV10 exact set and matrix public candidate

This unreleased 1.7.0-dev increment selectively integrates the package-only
algorithms from [PR #64](https://github.com/ThorFuchs/Swift-JSON/pull/64), donor
`6aa5fab9af3990b1ef21604611f0f8e0cf20179a`, onto main
`1a0306d076a08c8c43281f91412a11cd744ff3f6`. Published 1.6.1 is unchanged.
The first private checkpoint preserves all 46 SSET01–18/MAT01–18/CORE01–10
functions and exact donor source bytes except regenerated CLI identity.
Historical NAV9 ADRs retain their original private-stage disposition.

## Public boundary

Within existing JSONInspection, promote JSONStructuralSetProjection,
JSONNumericMatrixProjection and JSONP2ProjectionFailure. Keep factory signatures,
get-only metadata and separately bounded accessors. Initializers remain fileprivate;
reducers/accounting are internal and the noncopyable traversal context is package-only.
There is no new target, product or external dependency. JSONInspection continues to
import JSON and JSONNavigation; neither re-exports Inspection. The existing
Navigation56/Inspection95 declarations must be verified unchanged from compiler
graphs. The candidate adds 33 authored declarations, subject to actual graph audit.

The sole new Navigation helper compares original positions in the already-admitted
array through core JSONComparison on the original exclusive meter. Neither the
set nor the matrix introduces a comparator, number model, source root or ledger.
Original source transfer is one-shot at complete finalization. Public promotion
changes access and documentation only; donor construction/access algorithms are
preserved. Original 2-positive/20-negative ownership codegen and additional P2
same-meter/terminal/cancellation proof remain required.

Set metadata describes first-occurrence original offsets; `member(at:)` indexes
the representatives list. Exact decimal equality can merge different spellings,
but the first original lexeme is returned. Object equality ignores member order;
arrays and decoded scalar sequences remain ordered/exact. There is no hash-based
identity, arbitrary-candidate contains, set algebra or persistent identifier.

Matrix construction completely checks all rows/cells, rectangular width and numeric
kind. It never converts to binary floating values. Transpose exchanges metadata
and logical coordinate mapping only. Zero by nonzero metadata survives transpose,
without claiming a lossless bare-JSON exporter. No arithmetic is included.

## Resource and precedence contracts

Factories reject negative capacities before full source admission. Valid selection
and all scans/finalization use one original traversal invocation. Unselected source
and coherent source maps are admitted too. Default additional inclusive capacities:
100,000 representatives, 100,000 rows, 100,000 columns, 1,000,000 numeric cells.
All 49 existing core metrics/profiles remain unchanged.

Logical output overlays stay version 1: 128 fixed view bytes; 8 per representative;
exact typed selection; one captured source. These are policy weights, not heap/RSS.
Caller alias retention and callback instructions remain caller work.

Later reads are new complete-source-admitted operations with their own finite limits
and report. Set bounds precede admission; matrix row bounds precede column bounds,
then admission. Invalid indices never return null/zero. Core selection, resource and
cancellation errors retain their types. Operational failure publishes no partial
view/read report; independent retries do not continue a failed cumulative operation.

## Qualification contract

The original 46 donor functions remain unchanged in meaning and identity. Eight new
public-only Swift Testing functions add metamorphic first representatives/orientation,
typed selections, configuration/bounds precedence, repeated-read work, parser/shape
refusals, concurrent mixed health and cancellation recovery. The separate external
SwiftPM consumer imports only JSON and JSONInspection and requires 20 named outcomes.
Three DocC fences compile/execute independently per configuration. Twelve external
negative probes per configuration prove constructor/getter/context/meter/reducer
isolation, contextual operation typing and source attachment. Borrow-escape negatives
remain in the original exclusive-context compiler matrix.

The obsolete donor tests that external packages cannot name the now-public P2 types
are replaced by reducer/accounting invisibility probes; constructor/mutation/private
runtime proofs remain. This is an intentional API promotion, not a removed safety
obligation. Harness policies reject missing cases, duplicate/renamed identities,
incidental compiler diagnostics, crashes and incomplete receipts.

Current required discovery: 130 Inspection functions, 833 Mac/817 Linux/729 WASI
root functions; 325 native/Linux and 288 WASI parameter invocations. Shared scopes
are 54 Mac/53 Linux functions. These are expected inventories, not executed passes.
Actual native/safety/docs/archive, Linux architectures, WASI scopes, SDK links and
public consumers must bind to final source. SDK success is not mobile runtime.

G4 remains HOLD with zero accepted timed samples and no performance claims. Existing
90% idle in each of three intervals and 10% comparable review trigger remain.
Only a draft PR is authorized; merge/tag/publication require a later owner decision.
