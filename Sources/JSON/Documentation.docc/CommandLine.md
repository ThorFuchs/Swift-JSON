# Use the command-line executable

Run strict JSON workflows through the package's `swift-json` executable.

The prospective 1.4 package keeps five library products and adds one executable.
The CLI engine and query runtime are package-private; applications continue to
choose the library products they need. The root package has no external dependencies.

Build from a qualified feature checkout with Swift 6.4 or later:

```sh
swift build -c release --product swift-json
.build/release/swift-json format --compact input.json
.build/release/swift-json pointer /items/0 input.json
.build/release/swift-json validate --schema schema.json input.json
.build/release/swift-json patch --patch operations.json input.json
.build/release/swift-json render --format html input.json --output inspection.html
```

Input defaults to standard input. Formatting preserves admitted numeric spellings
and object order by default. `--number-style normalized` uses the core writer's
exact coefficient/exponent spelling. `--tab` emits actual tab indentation.

An explicitly supplied schema registry is offline. An ordinary invalid verdict
exits 1; malformed JSON, resource exhaustion, cancellation and operational schema
failures do not become false verdicts. A present null value is distinct from a
missing Pointer target and from Patch root removal.

`--output PATH` installs a file only after complete successful execution. Existing
files need `--overwrite`; stdout bytes already accepted before a later failure
cannot be recalled. `--report json` writes cumulative accounting to stderr, leaving
stdout for result bytes. All profiles are finite. Logical retained bytes describe
owned package state, not process RSS or kernel work.

The foundation increment advertises only its qualified commands. Query, advanced
adapters and provider-specific functionality have separate qualification gates.
