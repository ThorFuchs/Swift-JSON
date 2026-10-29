# Persist exact source definitions

Store a versioned source definition without serializing compiled VM state.
Definitions are immutable and checked Sendable; source keeps its decoded scalar
spelling and declared ASCII names are unique in ascending UTF-8 order.

```swift
import JSON
import JSONTransform

let definition = try JSONTransformProgramDefinition.prepare(
    source: "$amount", variables: ["amount"]).result
let bytes = try definition.encode().result
let restored = try JSONTransformProgramDefinition.decode(bytes).result
let compiled = try restored.compile()
let amount = JSON.number(try JSONNumber(parsing: "9007199254740993"))
let output = try compiled.result.withExecution(input: .null, bindings: ["amount": amount]) {
    try $0.next()?.value
}
precondition(output.result == amount)
precondition(compiled.statistics[.workUnits] > 0)
```

Prepare, decode, encode and compile each have their own explicit finite operation.
Within an operation all helpers share one ledger. Codec limits bound source/names,
wire bytes, native traversal, sorting and logical retention. Execution limits are
supplied separately. Logical reservations are not RSS or caller instruction quotas.

The closed V1 object contains definition, version, dialect, source and variables
in that canonical order. Strict decoding accepts equivalent native JSON spelling
and field order, then encoding emits canonical compact bytes. It rejects unknown
fields, duplicate keys/names and unsupported revisions. Canonical-input checking
is a separate gateway policy; codec decoding alone does not assert byte identity.
Malformed JSON remains a native JSON error; invalid query syntax is a compiler
error when compilation is explicitly requested. Neither schema validation nor a
new numeric or query engine is introduced.

Use ``JSONTransformProgram/compileWithReport(_:variables:limits:)`` when compiling
ordinary source with successful native work statistics. These reports are data;
they are not unforgeable selection-completion witnesses. The indexed selection
experiment remains test-only in this sprint, with no public selection API.
