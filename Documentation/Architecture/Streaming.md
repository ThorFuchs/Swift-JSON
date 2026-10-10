# Streaming and completion

These contracts describe the public behavior and its resource boundaries.

## Streaming and sink contracts

JSONByteChunk owns a byte buffer and is checked Sendable. Construction is unmetered; readers reject chunks exceeding chunkBytes on delivery. Ownership across await is explicit. Internal Span views never escape the synchronous borrow of an owned chunk, enter stored parser state or cross suspension. Avoid a public borrowed chunk protocol until native lifetime checking proves it adds value without burdening consumers.

JSONEventSequence<Source>, JSONValueSequence<Source> and NDJSONValueSequence<Source> accept caller AsyncSequence sources whose elements are JSONByteChunk. The sequence stores source/configuration; its iterator owns mutable parser and framing state. Conditional Sendable is allowed only when all stored source state is checked Sendable. Iterators are exclusive invocation state and must not be used concurrently. Each next() advances only far enough to return the next result, request one source chunk or fail.

The API does not promise background execution merely because it is async. Bounded synchronous parser/validator calls use the caller executor. The current public interface has no CPU-offloading convenience. Pull iteration preserves the caller's isolation and backpressure unless the API explicitly promises otherwise. No default MainActor, detached producer, actor pool or unbounded AsyncStream is introduced.

| Framing mode | Acceptance rule |
| --- | --- |
| Single document | One root; completion event occurs only after end-of-input confirms no trailing non-whitespace |
| Concatenated values | Explicit opt-in; require at least one JSON whitespace byte between records, preventing adjacent numeric tokens from ambiguous splitting |
| NDJSON | One complete value per physical LF or CRLF line; permit final nonempty line without LF; empty or whitespace-only lines fail |
| Events | Scalar/container/key events are provisional until the corresponding accepted record/document completion boundary |
| Values | Yield only after the selected framing boundary validates the complete record |

For concatenated records, a boundary is accepted when required separating whitespace or EOF confirms a complete grammar; do not allow {"a":1}{"b":2} by silent convenience. NDJSON line numbering is one-based, with absolute byte offsets retained. Escaped \n inside a string is not a physical line delimiter. Invalid UTF-8, malformed and truncated lines throw; no lenient-skip default. Single-document events may reveal most of a value before EOF, so an application must not treat them as an accepted message.

JSONAsyncWriter emits owned chunks through an async throwing closure or sink protocol with a **full-chunk acceptance** contract. A successful return means every byte of that chunk was accepted. A native OutputStream adapter, if added, implements a checked partial-write loop and reports no-progress/closed/error outcomes. The core async writer does not reinterpret a short-write count as success.

Only one sink handoff is outstanding. No next chunk is generated until it returns. Cancellation/throw releases owned buffers, stops pulling and prevents further handoffs; previously accepted bytes cannot be recalled. Source/sink cancellation beyond awaited calls is the caller's responsibility unless its explicit source/sink protocol includes a cancellation operation. Do not imply that ending iteration always cancels an arbitrary AsyncSequence's external task.

Large-stream tests use a generator that allocates one admitted chunk at a time and a slow consumer/sink. Do not preload a complete Data fixture and label it streaming-memory proof. Measure owned state and process retention separately, with a stable warm-up and no retained consumer outputs.

## Root-array streaming

JSONTopLevelArraySequence returns an explicit array stream event: element(index, value) and documentCompleted(summary). It consumes one root array through the shared strict token machine and materializes only the current element. It has no selector language.

This serves large export files and datasets whose records are array elements rather than separate NDJSON lines. Each yielded value is a complete valid JSON subtree; the enclosing document is not certified until the closing bracket, trailing whitespace and EOF have all been checked. A malformed tail throws after any earlier yields. Early termination or cancellation never produces documentCompleted.

The contract cannot promise atomic whole-document acceptance while releasing elements before EOF. A downstream importer can stage elements until the completion marker, or explicitly use provisional ingestion under its own persistence rules. Application persistence is outside the package.

Its resource composition is:

| Bound | Application |
| --- | --- |
| Core value/node/string/number/retained limits | Per materialized element; retained buffers remain charged until relinquished |
| Core maxDepth | Entire parser stack, including the root array |
| Stream totalInputBytes | Entire enclosing document, including separators and trailing whitespace |
| Stream totalRecords | Returned array elements |
| Stream totalWorkUnits | Entire iteration; never reset between elements |
| totalScannedNodes | Entire document; includes root and every element's descendants |
| Pending result | One event containing at most one admitted element |

The ordinary document-parser inputBytes cap remains unchanged. This explicit array-stream mode uses the finite stream totalInputBytes ceiling for its enclosing document; otherwise a larger file would still stop at the ordinary 32 MiB balanced document cap despite avoiding a whole DOM. Per-element admission retains the applicable core ceilings. All input bytes are validated; no ignored invalid tail or skipped malformed number is permitted.

The totalScannedNodes defaults are 2,000,000 conservative, 16,000,000 balanced and 128,000,000 offline. Existing stream byte/work/record limits still provide additional ceilings. All additions use checked arithmetic.

The reader accepts root arrays only. Nested array selection under a Pointer would require validating and retaining enough surrounding state, handling duplicate paths/resources and explaining completion of the enclosing document. That belongs to the deferred projection experiment, not an accidental extension of this reader.

Tests cover empty arrays, all kinds of elements, boundaries inside escapes/numbers, missing separators, trailing commas, depth including the outer array, trailing garbage, truncation, final completion exactly once, cancellation, large outer documents with small elements, slow consumers and generation without preloading the file. Validate every byte split for representative adversarial inputs and measure bounded state independent of element count.

## Qualified scalar state retention

The selected reader uses scalar scanning and releases record state at boundaries.
It retains no reusable scratch pool. maxReusableBufferBytes remains a finite
boundary ceiling for scratch retention; current retained scratch is zero. Live
owned state is still charged to retainedBytes. No SIMD scanner, global coder pool
or cross-invocation workspace is selected. See [performance](../Performance/README.md).
