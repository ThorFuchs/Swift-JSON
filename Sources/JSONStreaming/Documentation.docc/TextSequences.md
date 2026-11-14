# JSON text sequences

Read and write RFC 7464 `application/json-seq` streams.

## Overview

A JSON text sequence frames each JSON text with a leading record separator byte
(RS, `0x1E`) and, when written, a trailing LF. Because RS can never appear
unescaped inside JSON, a reader can find the next text even after a malformed
one. That makes the format useful for logs and long-running streams where one
damaged record should not hide the rest.

``JSONTextSequence`` reads texts from caller-owned chunks with the same pull
model, cumulative iterator budget and per-text value quotas as
``NDJSONValueSequence``:

```swift
for try await value in JSONTextSequence(chunks) {
    handle(value)
}
```

Each text runs from an RS to the next RS or the end of input and is parsed by
the strict grammar, so surrounding whitespace is allowed and a text may span
several lines. Consecutive RS bytes are not empty texts.

### Truncated and malformed texts

A top-level number, `true`, `false` or `null` that does not end in whitespace
may have been cut short ("123" could be the start of "1234"), so RFC 7464
section 2.4 treats it as possibly truncated. The reader reports it as an
`unexpectedEOF` syntax failure. Bytes before the first RS are malformed as well.

By default a malformed text ends the sequence with its failure, located by
absolute byte offset, text number (`record`) and line and column within the
text. With ``JSONTextSequenceOptions/MalformedTexts/skip`` the reader skips
malformed texts and continues with the next RS, as RFC 7464 recommends;
``JSONTextSequence/Iterator/skippedTexts`` counts them. Resource failures,
cancellation and source errors are never skipped.

### Writing

``JSONTextSequenceWriter`` writes each value as RS, the strict writer's bytes
and LF. ``JSONTextSequenceWriter/encode(_:)`` produces a complete sequence under
one ledger. ``JSONTextSequenceWriter/write(_:to:)`` writes one text in awaited,
bounded chunks, like ``JSONAsyncWriter``; call it once per value. Bytes a sink
has accepted cannot be recalled, but a reader recognizes a partially written
text as malformed.

## Topics

- ``JSONTextSequence``
- ``JSONTextSequenceOptions``
- ``JSONTextSequenceWriter``
