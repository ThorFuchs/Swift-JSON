# Configured store S0 preflight — design questions only

NAV9 StoreADR and pinned premise fixtures describe explicit collections/records/ID
configuration. No id/_id guessing, normalization or globally persistent surrogate
identity. Equal payloads at separate positions remain physical records. Duplicate
IDs are scoped to exact collection identity; scalar-distinct collection names must
remain separate even when Swift String equality would merge them.

Ask for exact failure precedence for missing/null/wrong-kind IDs, duplicate IDs,
malformed markers, unknown collections, dangling records, optional absent fields
and explicit null. `$ref` remains ordinary JSON unless a reference field is explicitly
configured. Test ambiguous marker shapes, literal slash/tilde keys, scalar-distinct
IDs, self/mutual cycles and a late dangling target after output-cap exhaustion.

Admission, exact lookup, configured following, visited positions and bounded output
must share one invocation ledger. Store following cannot silently become schema
reference resolution, network loading, graph inference or recursive unmetered work.
Freeze follow depth/cycle/optional-field policy before NAV12 implementation. No store
index/resolver/runtime or public API is added here.
