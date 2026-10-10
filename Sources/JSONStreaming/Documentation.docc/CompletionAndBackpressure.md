# Completion and backpressure

Choose framing, consume through its certified boundary and await output acceptance.

## Choose a pull reader

| Reader | What it yields | Certified boundary |
| --- | --- | --- |
| JSONEventSequence | Provisional syntax plus completion events | Record boundary or single-document EOF |
| JSONValueSequence | Complete values | Configured single-document or whitespace boundary |
| NDJSONValueSequence | Complete physical records | LF/CRLF or valid final record at EOF |
| JSONTopLevelArraySequence | Provisional indexed elements, then completion | Outer closing array, trailing whitespace and EOF |

Each reader uses owned ``JSONByteChunk`` values from a caller AsyncSequence.
An iterator owns its mutable state and must be advanced serially. No detached
producer or prefetch queue starts. Oversized chunks fail admission after the
source delivers them; prior source allocation is caller-owned.

NDJSON rejects blank/malformed records and never skips them. Whitespace-separated
roots require actual separation. The root-array reader always expects one root
array, regardless of the general framing option.

## Treat early elements as provisional

A complete subtree does not certify the enclosing document. A stream can yield
several valid elements and then encounter a malformed closing tail or trailing data.
Only ``JSONTopLevelArrayEvent/documentCompleted(_:)`` certifies the document.
Stopping iteration early, cancellation or failure produces no completion event.

Consumers requiring atomic whole-document acceptance must stage provisional
results until completion. Consumers choosing incremental acceptance own their
persistence rules. A single-document JSONValueSequence instead waits until EOF
before yielding its whole materialized root.

Core quotas apply per root-array element; maxDepth includes the outer container.
Iterator-lifetime input, work, records and totalScannedNodes remain cumulative.
State is retired at record boundaries. The selected scalar reader retains no
reusable scratch pool. Returned values retained by caller code are caller retention.

## Await every write

``JSONAsyncWriter`` invokes a Sendable async throwing sink with one bounded owned
chunk at a time. Returning successfully accepts the entire chunk. The writer awaits
that acceptance before handing off another chunk, providing explicit backpressure.

Error or cancellation stops later pulls/writes. Previously accepted bytes cannot
be recalled; stage bytes in a caller-owned sink when publication must be atomic.
Caller source and sink code remain outside owned instruction quotas. Cancellation
checks on return from caller I/O do not preempt arbitrary work inside that callback.

## Topics

- ``JSONEventSequence``
- ``JSONValueSequence``
- ``NDJSONValueSequence``
- ``JSONTopLevelArraySequence``
- ``JSONAsyncWriter``
