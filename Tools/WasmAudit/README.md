# Public WASI consumer

This separate qualification package imports the four public products and adds
no external dependencies. The library root dependency graph stays empty.
It now exercises balanced defaults and exact persistence; the initial audit
receipts at commit 5ca1079 retain the original blocked observations.

Use the matching official Swift 6.4.0 compiler and full-language SDK:

```sh
swift build --package-path Tools/WasmAudit --swift-sdk swift-6.4.0-RELEASE_wasm --scratch-path .build/wasm-audit-consumer
```

The command and its SwiftPM resource bundle reside under
`.build/wasm-audit-consumer/out/Products/Debug-webassembly-wasm32` with Swift Build.
Pass the absolute module path. `core`, `profiles`, `resources`, `schema`,
`streaming` and `benchmark` are public command modes. For Node:

```sh
node Tools/WasmAudit/run-node.mjs /absolute/path/WasmAudit.wasm schema --resources
```

For WasmKit, preopen the directory containing the command and bundle:

```sh
wasmkit run --dir /absolute/path /absolute/path/WasmAudit.wasm schema
```

`missing-resources` intentionally runs without a preopen and requires a structured
meta-schema failure, with no trap. The 13 Swift Testing functions have the same
public semantics on native and WASI. The broader root/corpus/49-cap/frozen consumer
qualification runs through `python3 Scripts/ci.py --lane wasm`; source paths and
private build outputs stay outside archives. `--repo` grants fixture access only
for qualification, and `command -- ...` passes explicit executable arguments.

See the [WASI contract](../../Documentation/Architecture/WebAssembly.md) for
cooperative cancellation, safety/measurement policy and unqualified host modes.

The integrated JSONHTML consumer adds the fifth public product and a fourteenth
Swift Testing function covering six exact HTML/export/budget/cancellation/backend
checks. Node runs all six root test bundles (including 49 portable HTML functions);
Node and WasmKit run the 14-function public consumer. Apple transfer and PDF are
not portable backend claims. See [receiving qualification](../../Documentation/Architecture/Release1.3/ReceivingQualification.md).
