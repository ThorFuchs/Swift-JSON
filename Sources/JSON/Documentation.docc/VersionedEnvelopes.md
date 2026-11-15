# Versioned envelopes

Store a typed, versioned payload as canonical bytes with a content digest.

## Overview

A ``JSONEnvelope`` wraps one payload with the caller's name for its kind
(``JSONEnvelope/type``) and the schema version of that kind
(``JSONEnvelope/version``). It is meant for records that a store keeps for a
long time, where later code must recognize what a record is, migrate older
versions and notice damage.

```swift
let envelope = try JSONEnvelope(type: "mcp.task", version: 3, payload: task)
let encoding = try envelope.encode()
store.save(encoding.data, key: encoding.digest)

let restored = try JSONEnvelope.decode(store.load(key))
```

### Wire format

Format version 1 is one RFC 8785 canonical object with exactly six members:

```json
{"digest":"sha256:87245ae1c062ec8fd5e2ab1ac60fbc44f6822d6176fe850381db1fd6e97c7810","format":"swift-json-envelope","formatVersion":1,"payload":{"id":7,"state":"done"},"type":"mcp.task","version":3}
```

- `format` is always `swift-json-envelope`; `formatVersion` is always `1`.
- `type` is a non-empty string of at most 256 UTF-8 bytes; `version` is an
  integer from 1 through 2^53 − 1.
- `digest` is `sha256:` followed by the lowercase hexadecimal SHA-256 of the
  payload's canonical bytes.

Because the whole envelope is canonical, equal envelopes encode to equal bytes.
Equal payloads, compared with the exact model's equality, have equal digests, so
the digest works as a content address independent of the type and version.

### Decoding

``JSONEnvelope/decode(_:options:)`` accepts any strict JSON spelling of the
object, recomputes the payload digest and compares it with the recorded one. A
well-formed value that is not a valid envelope throws a ``JSONEnvelopeFailure``:
a wrong marker or member set, an unsupported format version, an invalid type,
version or digest field, or a digest mismatch. Syntax, resource and number
failures stay `JSONFailure`.

### Numbers

The payload is canonicalized with ``JSONCanonicalWriter``. By default
(``JSONCanonicalWriter/NumberPolicy/preserving``) a number that binary64 cannot
spell exactly, such as `0.10000000000000001`, is refused rather than changed.
With ``JSONCanonicalWriter/NumberPolicy/rounding`` such numbers are rounded
before hashing, and decoding must use the same policy.

## Topics

- ``JSONEnvelope``
- ``JSONEnvelopeOptions``
- ``JSONEnvelopeEncoding``
- ``JSONEnvelopeFailure``
