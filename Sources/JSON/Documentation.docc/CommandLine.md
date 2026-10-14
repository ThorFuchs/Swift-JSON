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

Query uses a pull generator over strict whitespace-separated values by default:

```sh
.build/release/swift-json query --compact -- '.items[] | select(.active) | .name' input.json
.build/release/swift-json query --null-input -- '0.1 + 0.2' </dev/null
.build/release/swift-json query --null-input --division-scale 4 --rounding half-even -- '1 / 3' </dev/null
```

Use `--` before filters or filenames beginning with a dash. Missing query fields
produce null; wrong types raise catchable language errors. Native Pointer presence
remains explicit. Driver and `input`/`inputs` share one cursor. An earlier yield
never certifies the remaining syntax: successful execution drains malformed tails.
Null-input jobs still finish the shared source; use an empty source such as
`/dev/null` for standalone calculations.

Arithmetic uses exact bounded decimals. `1 / 8` terminates exactly; default `1 / 3`
raises `inexactDivision`. The explicit scale/half-even pair quantizes divisions and
counts nonzero discarded remainders in the cumulative stderr report. Builtin round
uses ties away from zero. Constructed objects replace duplicate names at their first
position; parsed duplicate keys remain errors. Scalar-distinct keys stay distinct.

Advanced filters include lexical functions, reductions, finite collections, scalar
strings, interpolation and staged path mutation. Regex and approximate math remain
explicit compile errors. Platform distribution and provider-specific adapters retain
their separate qualification gates. This feature checkout is not a released 1.4 candidate.
