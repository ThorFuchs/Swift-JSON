# NAV5 N2 public-surface decision

Source reviewed: 462f3ea33d462e00ed4fc241fc4fff1d1d0ff95c, descendant of fresh
main 7d72c8825982550f0ee87218136fda12d8bae13b. Status: accepted for an isolated
public-product candidate, subject to fresh qualification; no merge/release approval.

Keep all existing public declarations in JSONShapeEvidence.swift and
JSONShapeInspector.swift, including internal-only setters and the selected-array
report. No facade, overload, alias or existing module declaration is added. The
inspector's only semantic delegates are JSONTraversal.inspectOwned and its original
JSONReadScope/JSONWorkMeter. Exact key comparison and optional source-span lookup
use that capability. The package-private reducer and capability remain inaccessible
to external packages. No competing API was found in the current source graph;
independent DSL/composition/schema branches remain outside this candidate.

## Integer proof

Swift's supported platforms use a signed Int no wider than UInt64. Array/object
counts are nonnegative Int. Mandatory admission bounds the entire canonical graph
before observation. For a selected array, 0 <= wanted <= total <= Int.max and each
row is observed once in increasing index order. Before examined += 1, examined <
wanted <= total, so the increment cannot exceed Int.max. Each six-kind row bucket
is at most UInt64(examined) <= UInt64(Int.max), strictly below UInt64.max.

Canonical JSONObject contains each decoded-scalar key once. Each column's present
count increases at most once per observed object row. Thus explicitNull <= present
<= observedObjectRows <= UInt64(examined), and each column kind bucket <= present.
The missing subtraction observedObjectRows - present and nonobject subtraction
UInt64(examined) - observedObjectRows cannot underflow. First-row ordinal is the
preincrement examined value; column indices come from bounded array indices.
No multiplication or unchecked count addition is used by this reducer. The core
meter performs checked work/retention arithmetic before growth and increments;
operational overflow remains a typed resource failure. This proof depends on the
current single physical selection, depth-one traversal, and canonical duplicate
rejection; broader scopes would require a new audit.

## Frozen meaning and costs

Complete row coverage does not imply complete descendant traversal. Prefix traits
describe only examined rows. Source admission is complete even for prefix zero.
Present includes explicit null; missing excludes nonobject rows. First-seen columns
follow exact source insertion order. Rectangular width is structural, never numeric
matrix or schema admission. Empty evidence has no positive inferred trait.

Negative prefix/column configuration precedes admission. Maximum columns defaults
to 100,000 inclusive. Overlay v1 stays 256 fixed logical bytes, 192 per returned
column plus exact UTF-8 key bytes and core selection-path weights. No new resource
profile or fresh meter is introduced. Logical retention is not RSS. The metered
linear column search can be quadratic in total columns/members.

## Required proof binding

Retain I01-I17 without changing identities/meaning. Add a separate external SwiftPM
consumer with exact outcomes, compiled DocC examples, core-only import rejection,
and package-capability access rejection. Native, Linux, WASI, SDK, safety, discovery,
49 metrics/126 identities, source archive and unmodified 2-positive/20-negative
full-codegen ownership matrix must bind to the final source. Unexecuted lanes remain
pending, not historical successes promoted to fresh ones.
