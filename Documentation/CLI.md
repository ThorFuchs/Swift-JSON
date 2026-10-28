# Command-line workflows

The `swift-json` executable, introduced in 1.5.0, accompanies eight libraries in 1.6.0. It uses the
same exact decimal/scalar model, strict grammar, explicit offline schema resources
and finite cumulative limits. It has no network provider, shell filter or universal
jq compatibility claim.

Build the selected release or source checkout with Swift 6.4+:

```sh
swift build -c release --product swift-json
swift run swift-json help
swift run swift-json query --compact '.items[] | select(.active) | .name' input.json
swift run swift-json validate --schema schema.json input.json
swift run swift-json stream check --framing ndjson records.ndjson
swift run swift-json render input.json --output inspection.html
```

`help COMMAND` describes options. Named output uses owned staging and installs only
after complete input/EOF and successful writes; `--overwrite` is explicit. Stdout
can retain an accepted prefix after a later streaming failure. Diagnostics and
optional JSON reports go to stderr; invalidity differs from operational failure.

| Exit | Meaning |
| --- | --- |
| 0 | Completed success |
| 1 | Completed invalidity, provider incompatibility or query false/null with `-e` |
| 2 | Usage/configuration or an explicitly unavailable capability |
| 3 | Query compilation failure |
| 4 | Empty query with `-e`, or explicitly allowed absent Pointer |
| 5 | Strict JSON, uncaught query, Patch or schema operational failure |
| 6 | Resource quota/overflow |
| 7 | IO, broken pipe or no-progress sink |
| 130 | Cancellation or handled SIGINT |

Use `--limits conservative|balanced|offline` and an optional versioned limits file.
Reports retain cumulative work and remaining allowances. Logical retained bytes do
not cap RSS or caller/SDK instructions. Exact division needs an explicit finite
scale and rounding policy when the mathematical result repeats.

Offline `schema provider openai-format|openai-tool` commands check frozen local
profiles and construct request fragments. They make no API request or remote
acceptance guarantee. Apple model/schema helpers and full CLI/WASI execution remain
outside the qualified CLI scope. Apple/Linux acceptance receipts identify actual
source, compiler and architecture; library WASI results are a separate boundary.

## Version and source identity

Development main and a versioned release candidate are distinct sources. Read
`--version` and `--version --json` from the selected checkout: development main
uses `1.7.0-dev`, while a separately frozen 1.7.0 candidate uses `1.7.0` after its
version metadata and source identity are updated and qualified. Neither value
establishes publication. Latest stable remains `1.6.1`.

The [source-line matrix](Qualification/ReleaseLines.md) and
[consolidation contract](Qualification/Consolidation2026.md) describe the current
twelve-library source. The [older RC contract](Qualification/Release1.7.0.md)
retains its ten-library inventory and scoped performance exception as history;
it does not qualify a later combined candidate.

The frozen 1.5.0 executable reports `1.4.0-dev` and revision `unknown`; its release
notes disclose that limitation. The 1.5.1 maintenance release corrects it, and
1.6.0 reports `1.6.0`. Both use the same source-identity interface:

```sh
swift run swift-json --version
swift run swift-json --version --json
```

Human output identifies the source version. JSON adds `revisionKind` with value
`source-sha256`; `revision` is `sha256:` plus a lowercase 64-digit digest. This
digest hashes the ordered content manifest for `Package.swift` and every file in
`Sources`, excluding only generated `CLIBuildIdentity.swift`. The manifest uses
UTF-8 relative paths and SHA-256 file digests. It is a source-content identity,
not a Git commit, binary digest, wall-clock build ID or assertion of publication.

Generate with `python3 Scripts/generate_cli_identity.py`; CI runs `--check` and
rejects stale output. Generation and the executable need no Git checkout, network,
timestamp or environment-derived version. Public subprocess acceptance runs both
version forms from an owned temporary directory outside the checkout.

The [CLI reference](Architecture/Release1.4/CLIReference.md),
[filter dialect](Architecture/Release1.4/QueryCore.md),
[arithmetic](Architecture/Release1.4/Arithmetic.md),
[advanced filters](Architecture/Release1.4/Advanced.md) and
[provider contract](Architecture/Release1.4/Providers.md) define exact semantics.

## Provisional programmatic transformations

The unpublished 1.7.0 candidate offers an optional public library over the
same compiler and pull VM used by `swift-json query`. It does not change the CLI
flags, framing, input cursor, diagnostics, staged files or exit codes documented
here. Public library users supply exact native values and an explicit optional
provider; the CLI retains process/file ownership and closing-syntax/EOF checks.
See the [public API](Architecture/API.md#provisional-jsontransform-extraction-17-feature-branch)
and [runnable consumer](../Tools/TransformQualification). This product is not in
stable 1.6.1 and this note does not publish 1.7.0.
