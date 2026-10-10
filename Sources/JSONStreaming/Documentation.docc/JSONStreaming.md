# ``JSONStreaming``

Pull-driven events and values, strict NDJSON, root-array elements and awaited sinks.

Sources are caller-owned AsyncSequences of owned ``JSONByteChunk`` values.
Each iterator has exclusive mutable state, performs one pull at a time and
creates no detached producer or prefetch queue. Sequence Sendable conformance
is conditional on the source. Caller source allocation precedes library chunk
admission; an oversized delivered chunk is rejected before copying it.

``JSONEventSequence`` emits provisional syntax events. A scalar/end-container
event does not certify the document. ``JSONValueSequence`` returns a complete
value only after its framing boundary is certified. Single-document completion
requires closing syntax, trailing whitespace and EOF. Whitespace-separated
records require actual separation; adjacent roots are rejected.

``NDJSONValueSequence`` respects LF/CRLF physical record boundaries, rejects
blank/malformed records and accepts a valid final record without a final LF.
There is no skipped-record recovery. Error locations include absolute byte and
physical record positions.

``JSONTopLevelArraySequence`` emits indexed elements followed by one explicit
document-completed summary. Earlier elements remain provisional with respect
to the enclosing document. A malformed/truncated tail produces no completion.
Each element has its own value quotas; root depth includes the outer array and
iterator-lifetime input/work/record/node counters remain cumulative. Record
state is retired at boundaries; the scalar implementation retains no reusable
scratch pool and holds only the currently admitted chunk and active element.

``JSONAsyncWriter`` awaits full acceptance of each bounded chunk before the
next handoff. Cancellation/error stops further pulls/writes; bytes already
accepted by a sink cannot be recalled. Application code that requires atomic
publication must stage bytes in its own sink.

## Topics

### Guides

- <doc:CompletionAndBackpressure>

### Pull sequences
- ``JSONByteChunk``
- ``JSONEvent``
- ``JSONEventSequence``
- ``JSONValueSequence``
- ``JSONStreamingOptions``
- ``JSONFraming``

### Record framing and completion
- ``NDJSONValueSequence``
- ``NDJSONOptions``
- ``JSONTopLevelArraySequence``
- ``JSONTopLevelArrayEvent``

### Awaited output
- ``JSONAsyncWriter``
