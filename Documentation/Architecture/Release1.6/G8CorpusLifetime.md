# G8 synthetic corpus lifetime repair

The first hosted S3 qualification at c629114 passed all 98 generator behavior
functions on both Linux architectures, but the complete ASan command exited 1.
Linux LeakSanitizer reported 129 bytes in four allocations from the stored
`JSONSchemaExampleCorpus.synthetic` initializer. Those failed receipts remain
failed. See [the initial Linux run](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38822602731).

The fixed corpus is now a read-only computed static property. Each access constructs
the same six ordered values for the caller's lifetime: null, false, zero, "example",
empty array and empty object. The original global cache is removed. This is a source
compatible getter for callers; the unreleased declaration changes from stored `let`
to computed `var`. No setter, approximate bridge or extra product is introduced.

Caller corpus/options construction still precedes checked preparation. Preparation
admits and hashes every value under its existing cumulative ledger. This repair
changes neither corpus contents/order, transport versions, seed/profile choices nor
resource policies. It does not promise an allocation count, process RSS bound or
controlled performance result. The compiler/runtime report does not by itself prove
an invocation-owned reference cycle; the repair removes process-lifetime JSON storage.

The existing exact-corpus Swift Testing case now exercises repeated reads, exact
encoding and independent caller mutation. Its original digest/order assertions and
all other functions remain required. No test count, cap, timeout or sanitizer check
is reduced. A separate generated public consumer performs 128 scoped corpus/options
reads with exact encoding/copy assertions under Release ASan. Linux explicitly enables
leak detection with no leak suppressions. It must exit zero and emit the exact marker.

`Scripts/ci.py --lane safety` appends this process check after the existing full
ASan, TSan and strict-memory commands. `linux-safety` retains its runtime diagnostic
and all four safety commands. Existing exact requirements remain 644 Mac / 628 Linux /
540 WASI functions, 325 Mac/Linux / 288 WASI parameter invocations, 45 Mac / 44 Linux
sharing functions and all 49 core cap probes. Native QA and fresh hosted Linux/native
checks qualify the changed source; earlier static-corpus results are baseline evidence.

Current-main composition/navigation integration and combined-source G8 review remain
separate. No sibling checkout, protection, tag, release or documentation deployment
is changed by the repair.
