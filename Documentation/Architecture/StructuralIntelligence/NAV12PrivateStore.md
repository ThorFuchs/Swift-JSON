# Private configured-store construction

This D1 experiment belongs to JSONInspection at package access. It adds no public
product or declaration. Ordinary Navigation, shape, snapshot and projection entry
points retain their admission, accounting and completion contracts. This is
complete construction only: no follow, query, graph, persistence or resolver API.

The closed native profile has version `nav12.store-profile/1`, an absolute typed
`collectionsAt`, explicit collection declarations and disabled/strict references.
Each collection selects exactly its own direct array member, declares its exact
ID key, and orders reference fields with required/optional presence and nullable
policy. The strict `collection-id/1` marker has exactly two string members,
`collection` and `id`. There is no wire-profile parser; unsupported versions,
unknown configuration arguments and non-Boolean nullable values are compiler
refusals. Decoded-scalar JSONKey/text comparison remains the identity authority.

Construction is one invocation using the original read scope and meter:

1. Validate fixed finite limits; prepare the complete profile on the exclusive
   profile-only capability, before source admission.
2. Admit the entire canonical root, source label/bytes and source map once.
3. Select the exact typed collections object.
4. Validate every physical collection header, then missing declarations.
5. Validate every record and ID; report the second duplicate and first ID path.
6. Validate every configured field's presence, null policy and marker shape.
7. Resolve all staged target names and IDs, preserving link order.
8. Check metadata, transfer the original document once and complete atomically.

Each phase completes before the next begins. Source collections/rows use physical
insertion/index order; fields use configured order. Thus a later malformed marker
precedes an earlier dangling link. Operational errors and cancellation throw and
cannot publish a partial store. Cycles remain links between source-local records;
construction never follows them. Position tokens contain a private instance owner
and checked collection/row ordinals. They are neither semantic IDs nor persistent
identities. Empty collections, absent slots, null slots and links remain distinct.

Source errors retain exact typed physical/requested paths. Missing-member spans
refer to the nearest existing parent; duplicates retain the first ID path.
Selection preserves the core access cause/location. Replacing a root does not
invent source bytes or spans.

The twelve inclusive prototype caps are: 256 collections; 10,000 records per
collection and in total; 16 reference declarations per collection and 4,096 total;
100,000 configured slots (including absent/null) and 100,000 links; 4,096 UTF-8
bytes per identity; 1,048,576 profile-text bytes; 16,777,216 ID/marker alias bytes;
128 path components; 33,554,432 logical overlay bytes. Zero is finite and accepted;
negative values and Int.max are invalid. The original 49 native caps still apply.

Reservations precede growth: 512 fixed bytes, 128 per collection declaration,
64 per field/record/reference slot, 32 per text alias/staged link, text bytes,
8 per temporary header/row slot and the existing 32-byte typed path component
weight plus key text. Original native helpers charge scans, exact comparisons,
member lookup, path building and source spans to the same ledger. Marker text
reservations are released only after all targets resolve and staging is cleared;
work is never refunded. Path and scratch reservations conservatively remain in
the invocation's overlay accounting; the final overlay is not a precise live heap
measurement. Fixed immutable record access does not start a hidden operation.

The caps are policy, not jointly achievable capacity guarantees. The S0 estimate
35,163,280 bytes already exceeds the overlay cap before paths/scratch. Linear
exact duplicate/target scans deliberately retain the correct bounded baseline;
large configurations can exhaust native work before reaching count maxima.
Logical retention differs from heap/RSS, and observer/caller work is not owned
instruction work. No timing, throughput or performance improvement is claimed.

`Scripts/ci.py --lane store` requires twelve exact Swift Testing identities,
65 native vectors plus one strict-parser case, R01–R10, Debug/Release, ASan,
targeted TSan, strict memory compilation and the private consumer. Three remaining
frozen vectors use real compiler diagnostics in both configurations. Premise-only
Python observations and future F01–F03 follow cases are not engine successes.
`--lane store-preparation` retains D0 lifecycle/codegen gates. Full native/Linux
lanes retain the independent suites, all 49 cap witnesses and 126 maintenance IDs.
Receipts establish actual execution; this document does not certify a platform.
