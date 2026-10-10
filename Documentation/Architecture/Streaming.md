# Streaming and completion



These contracts describe the public behavior and its resource boundaries.

## Streaming and sink contracts

JSONByteChunk owns a finite UTF-8 byte buffer; it is checked Sendable. Ownership across await is explicit. Internal Span views never escape the synchronous borrow of an owned chunk, enter stored parser state or cross suspension. Avoid a public borrowed chunk protocol until native lifetime checking proves it adds value without burdening consumers.

JSONEventSequence<Source>, JSONValueSequence<Source> and NDJSONValueSequence<Source> accept caller AsyncSequence sources whose elements are JSONByteChunk. The sequence stores source/configuration; its iterator owns mutable parser and framing state. Conditional Sendable is allowed only when all stored source state is checked Sendable. Iterators are exclusive invocation state and must not be used concurrently. Each next() advances only far enough to return the next result, request one source chunk or fail.

The API does not promise background execution merely because it is async. W01 verifies explicit isolation annotations on Swift 6.4. Bounded synchronous parser/validator calls use the caller executor; asynchronous parsing convenience that deliberately offloads CPU uses a documented @concurrent entry point with Sendable inputs. Pull iteration preserves the caller's isolation and backpressure unless the API explicitly promises otherwise. No default MainActor, detached producer, actor pool or unbounded AsyncStream is introduced.

| Framing mode | Acceptance rule |
| --- | --- |
| Single document | One root; completion event occurs only after end-of-input confirms no trailing non-whitespace |
| Concatenated values | Explicit opt-in; require at least one JSON whitespace byte between records, preventing adjacent numeric tokens from ambiguous splitting |
| NDJSON | One complete value per physical LF or CRLF line; permit final nonempty line without LF; empty or whitespace-only lines fail by default |
| Events | Scalar/container/key events are provisional until the corresponding accepted record/document completion boundary |
| Values | Yield only after the selected framing boundary validates the complete record |

For concatenated records, a boundary is accepted when required separating whitespace or EOF confirms a complete grammar; do not allow {"a":1}{"b":2} by silent convenience. NDJSON line numbering is one-based, with absolute byte offsets retained. Escaped \n inside a string is not a physical line delimiter. Invalid UTF-8, malformed and truncated lines throw; no lenient-skip default. Single-document events may reveal most of a value before EOF, so an application must not treat them as an accepted message.

JSONAsyncWriter emits owned chunks through an async throwing closure or sink protocol with a **full-chunk acceptance** contract. A successful return means every byte of that chunk was accepted. A native OutputStream adapter, if added, implements a checked partial-write loop and reports no-progress/closed/error outcomes. The core async writer does not reinterpret a short-write count as success.

Only one sink handoff is outstanding. No next chunk is generated until it returns. Cancellation/throw releases owned buffers, stops pulling and prevents further handoffs; previously accepted bytes cannot be recalled. Source/sink cancellation beyond awaited calls is the caller's responsibility unless its explicit source/sink protocol includes a cancellation operation. Do not imply that ending iteration always cancels an arbitrary AsyncSequence's external task.

Large-stream tests use a generator that allocates one admitted chunk at a time and a slow consumer/sink. Do not preload a complete Data fixture and label it streaming-memory proof. Measure owned state and process retention separately, with a stable warm-up and no retained consumer outputs.

## E06 Top-level array streaming

Add JSONTopLevelArraySequence or equivalent, returning an explicit JSON array stream event: element(index, value) and documentCompleted(summary). It consumes one root array through the shared strict token machine and materializes only the current element. No selector language or Archive-specific model is needed.

This serves large export files and datasets whose records are array elements rather than separate NDJSON lines. Each yielded value is a complete valid JSON subtree; the enclosing document is not certified until the closing bracket, trailing whitespace and EOF have all been checked. A malformed tail throws after any earlier yields. Early termination or cancellation never produces documentCompleted.

The contract cannot promise atomic whole-document acceptance while releasing elements before EOF. A downstream importer can stage elements until the completion marker, or explicitly use provisional ingestion under its own persistence rules. No such application transaction or Vault mutation belongs in this package.

The new mode needs a documented resource composition:

| Bound | Application |
| --- | --- |
| Core value/node/string/number/retained limits | Per materialized element; retained buffers remain charged until relinquished |
| Core maxDepth | Entire parser stack, including the root array |
| Stream totalInputBytes | Entire enclosing document, including separators and trailing whitespace |
| Stream totalRecords | Returned array elements |
| Stream totalWorkUnits | Entire iteration; never reset between elements |
| New totalScannedNodes | Entire document; includes root and every element's descendants |
| Pending result | One event containing at most one admitted element |

The ordinary document-parser inputBytes cap remains unchanged. This explicit array-stream mode uses the finite stream totalInputBytes ceiling for its enclosing document; otherwise a larger file would still stop at the ordinary 32 MiB balanced document cap despite avoiding a whole DOM. Per-element admission retains the applicable core ceilings. All input bytes are validated; no ignored invalid tail or skipped malformed number is permitted.

Proposed totalScannedNodes defaults are 2,000,000 conservative, 16,000,000 balanced and 128,000,000 offline. Existing stream byte/work/record limits still provide additional ceilings. All additions use checked arithmetic.

Start with root arrays only. Nested array selection under a Pointer would require validating and retaining enough surrounding state, handling duplicate paths/resources and explaining completion of the enclosing document. That belongs to the deferred projection experiment, not an accidental extension of this reader.

Tests cover empty arrays, all kinds of elements, boundaries inside escapes/numbers, missing separators, trailing commas, depth including the outer array, trailing garbage, truncation, final completion exactly once, cancellation, large outer documents with small elements, slow consumers and generation without preloading the file. Validate every byte split for representative adversarial inputs and measure bounded state independent of element count.

## E09 Private buffer and scanning optimization

Reuse scratch within an exclusively owned streaming iterator or another explicit invocation context. Reset semantic state and counters at their documented boundaries, release caller results normally and keep only a bounded amount of scratch. An unusually large record must not leave a permanent unbounded high-water allocation.

Propose a maxReusableBufferBytes ceiling of 512 KiB conservative, 2 MiB balanced and 8 MiB offline at record boundaries. Live capacity remains part of retainedBytes. Temporary admitted work may require more capacity; after the record it is released or trimmed to the reuse ceiling. These values are initial calibration policy, not measured optimal sizes.

Do not change immutable Sendable parser/coder facades into hidden mutable caches. Across independent calls, buffer pooling or a public reusable workspace is deferred until measurement justifies its ownership/API cost. A process-wide coder pool would conflict with A1.

After a correct scalar baseline, qualify byte-specialized whitespace, structural and string scans. IkigaJSON's word-scanning code and historical Swift Extras string-reader split provide concrete reference patterns. No unsafe source is copied wholesale. Swift Span borrows stay synchronous and an explicit scalar tail handles short/alignment/boundary cases.

Every block scan charges bytes and observes the cancellation quantum. Do not invoke an opaque whole-input search that can exceed the work-check interval. Padding or unsafe reads must not depend on callers supplying inaccessible bytes past a buffer. UTF-8, escaped quotes, backslashes, raw controls and surrogate boundaries still use the strict validation path. Fuzz scalar-versus-fast equivalence, including every tail size and malformed split; promote a fast path only after native performance and safety checks.
