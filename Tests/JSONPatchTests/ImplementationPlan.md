# JSONPatch behavioral tests

Implement with Swift Testing; no passing placeholder tests. Native execution is pending.

All six RFC 6902 operations; strict paths/index/dash rules, irrelevant
extra operation members, missing required members, exact test, root removal and
recreation, move target after removal, descendant move rejection, copy isolation,
multi-operation failure leaves original input unchanged. Meter each compare/copy.

RFC 7396 object recursion, null-member removal, scalar/array replacement, root
null preserving a null document, exact keys/numbers, staged output and cumulative
growth/work/depth. Do not inherit old array-concatenating deep merge semantics.

Use authored fixtures and pinned independent suites, plus exact boundary and
adversarial reproductions. Keep case counts and evidence in qualification ledgers.
