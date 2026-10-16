# G4 conservative advanced proposals

G4 extends G3 commit 3951b99 on the isolated 1.6 branch. The original compiler,
qualified offline plan and complete root validator retain exclusive semantic
authority. No schema evaluator, public API, dependency or platform is added.

The ten additional must-generate fixtures and eight may-fail fixtures are distinct
acceptance groups. Every successful proposal must pass full native validation and
strict roundtrip. A may-fail fixture may also succeed; unsupported/exhausted is
incomplete search, never a proof of unsatisfiability. Operational errors and
cancellation terminate the invocation and cannot be counted as incomplete search.

Two narrow extensions are selected:

* Array length includes each active contains declaration's minimum (default one).
  Only when contains applies are minContains/maxContains consulted. The first N
  items receive that declaration's qualified contains child in conjunction with
  their own prefix/items constraints. Several contains declarations remain separate
  conjuncts. The native validator alone counts actual matches, checks maxima and
  propagates evaluated-location annotations. Avoiding extra matches or finding
  disjoint matching partitions remains incomplete; no independent matcher runs.
* A private proposal-only scanner handles fully anchored ASCII sequences: printable
  literals, escaped regex punctuation, a single printable ASCII range per character
  class, and exact {n} repetition. Variation chooses within each range. It does
  not match strings, invert arbitrary regex, accept malformed schemas or replace
  native regex. Unsupported syntax falls back to the existing finite token/filler
  search and still requires native certification. Output bounds are checked before
  append; source scans, repeat counts, output copies and rejection paths share the
  invocation ledger. No Foundation regex or private runtime dependency is added.

Existing finite alternatives handle the conditional fixture without interpreting
if/then/else: the rejected adult/age-zero object consumes work, then a later child
proposal can pass. Optional dependent/pattern/name declarations may be satisfied
by an empty object; that demonstrates fixture coverage, not general constructive
support. Unevaluated-location semantics are certified by native annotations, not
reimplemented. Static references use compiler-qualified identities, including
explicit external registry resources and anchor/base transitions. Dynamic targets
are not guessed; reaching a dynamic-scope edge remains unsupported. Omitting an
optional recursive/dynamic child may produce a valid finite witness.

Algorithm becomes s3-candidates-v4. The trace v2 grammar is unchanged: existing
typed-request/offer events suffice, and the trace envelope binds the new algorithm.
Snapshot/corpus/policy v1 and SplitMix64 v1 remain unchanged. G3 vectors and archives
remain immutable historical evidence; no cross-version/platform identity is claimed.
All new helpers reuse the one noncopyable generation meter. G5's broader lifecycle
review and G6-G8 integration/platform/release gates remain separate.
