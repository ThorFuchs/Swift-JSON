# swift-json command reference

This reference describes the 1.4 feature candidate. Build with Swift6.4+ and
language6. Native qualification requires macOS/SDK27+; Linux executable evidence
is recorded separately for Ubuntu24.04/glibc x86_64 and ARM64. Library deployment
minimums remain macOS/iOS27. No CLI entry point is intended for mobile libraries.

```sh
swift build -c release --product swift-json
.build/release/swift-json help query
.build/release/swift-json --version --json
```

Install the executable with its complete `Swift-JSON_JSONSchema.bundle` sibling,
including all nine pinned Draft2020-12 files. Copying only the binary does not
constitute a qualified schema installation. Preserve LICENSE, NOTICE and third
party notices when redistributing. Initial distribution is a reproducible source
archive; no Homebrew entry, PATH mutation, `jq` alias or binary publication is made.

| Command | Completed behavior |
| --- | --- |
| `format [INPUT]` | One strict document; two-space JSON+LF and preserved numbers by default |
| `validate [INPUT] --schema PATH` | Offline instance verdict `{valid,issues,truncated}`; schema optional |
| `pointer POINTER [INPUT]` | RFC6901 selection, explicit null preserved; allowed absence exits4 |
| `patch [INPUT] --patch PATH` | Staged RFC6902; failed operation emits no candidate; root removal emits none |
| `query FILTER [INPUT...]` | Ordered pull filter outputs; native values framing by default |
| `stream check\|cat\|array [INPUT...]` | Complete framing summary, compact records, or provisional root-array elements |
| `schema check SCHEMA` | Compile an offline object/Boolean schema; completed metadata, no instance evaluation |
| `render [INPUT]` | Static HTML by default; explicit interactive HTML, tab-pretty text or Markdown |

`INPUT` defaults to `-` (stdin); stdin may be supplied once. `--` terminates options,
including leading-dash operands. Repeatable `--resource URI=PATH` gives explicit
schema resources. It does not fetch the URI. `validate --max-issues N` gives bounded
best-effort diagnostics; operational errors never become validation false.

Common options are `--limits conservative|balanced|offline`, `--limits-file PATH`,
`--output PATH`, `--overwrite`, `--diagnostics human|json` and `--report none|json`.
Default profile is balanced. Config is strict native JSON:

```json
{"version":1,"cli":{"totalResults":100},"json":{"numberDigits":1024}}
```

Version may be omitted with meaning1. Unknown fields, duplicate keys, nonintegral,
negative or overflowing maxima fail. Ordinary caps may be zero to forbid use;
required positive native configuration fields retain their constraints. Config,
argv, query, bindings, resources, codec, filter, diagnostics and sinks belong to
one cumulative job. All sixteen CLI caps and all49 native caps remain finite.
See [the job contract](Foundation.md) and [exact arithmetic](Arithmetic.md).

Format/query accept `--compact` (`-c`), `--indent 0...8` or `--tab`; conflicts fail.
`--sort-keys` (`-S`) uses decoded scalar ordering. `--number-style preserved|normalized`
selects lexeme output. Render text/Markdown use real tabs, with a JSON code fence
for Markdown. HTML `--presentation static|interactive`, `--theme system|light|dark`
and `--title TEXT` are explicit; static is expanded and script-free. `--html PATH`
is shorthand for HTML output and conflicts with another output/format choice.

Query supports `-f/--filter-file PATH`, `--input-framing document|values|ndjson`,
`-n`, `-s`, `-R`, finite file/string/JSON bindings, `$ARGS`, `--args` and `--jsonargs`.
Driver, `input` and `inputs` share one cursor. `-n` does not eagerly read, but the
job still checks unconsumed tails before success. `-n`/`-s` conflict; raw input and
explicit JSON framing conflict. Malformed filter-file UTF-8 exits3, raw-binding
UTF-8 exits5, and missing files exit7.

```sh
swift-json query --compact '.items[] | select(.active) | .name' input.json
swift-json query -n 'def twice(f): f,f; [twice(1,2)]'
swift-json query -n --division-scale 2 --rounding half-even -- '1/8,3/8,-1/8'
swift-json query -n --arg name Ada '$ARGS.named'
```

The dialect includes generators, constructors, exact comparisons/arithmetic,
conditions, typed catches, reductions/foreach, lexical filter functions,
explicit-stack loops/traversal, path assignment/deletion, scalar string helpers,
stable bounded collections and format encoders. See [core](QueryCore.md) and
[advanced semantics](Advanced.md). Approximate math, regex, environment/modules,
networking, shell execution and daemon/server features are deliberately excluded.
This is a specified dialect, not an unrestricted jq-compatibility claim. Numbers
remain exact; `1/3` is a catchable language error unless explicit scale/half-even
policy is selected. No Double/Decimal arithmetic or Foundation JSON conversion
serves as numeric authority. Canonically equivalent scalar sequences remain distinct.

`-r`, `--raw-output0` and `-j` are exclusive; raw-output0 rejects embedded NUL
before writing that record. Nonstrings still use native JSON writing. `-a` escapes
JSON as ASCII with valid surrogate pairs and conflicts with raw output. `-e`
uses the final semantic result after all required completion: false/null exits1,
no results exits4. Zero, empty string/array/object are truthy. A later operational
failure takes precedence. `--unbuffered` completes each record handoff before the next.

| Exit | Meaning |
| --- | --- |
| 0 | Completed success |
| 1 | Completed invalid instance, or query `-e` final false/null |
| 2 | Usage/configuration or known unavailable capability |
| 3 | Query source/compile failure |
| 4 | Query `-e` empty, or explicitly allowed missing Pointer |
| 5 | Strict input, uncaught language, patch or schema operational failure |
| 6 | Finite resource exhaustion/overflow |
| 7 | Local IO, broken pipe or no-progress sink |
| 130 | Cancellation/handled SIGINT |

Data uses stdout/the selected file. Diagnostics/reports use stderr. JSON mode
emits compact version1 JSONL, with stable `kind`, category/code and resource
fields. Reports distinguish completed/incomplete, provisional/committed results,
monotonic totals, remaining work, peak logical retention and resolved limits.
Record/byte totals include admitted auxiliary documents/files as well as primary
input. Diagnostic inability does not erase the originating failure. Logical
retention does not cap RSS, allocator overhead, foreign instructions or kernel time.

Named output uses owned exclusive staging in the destination directory and installs
only after required EOF, write and close. Failure preserves a preexisting target;
no final output symlink or input/output alias is accepted. No crash-durability/fsync
promise is made. Stdout may contain an accepted prefix after a late failure;
cancellation cannot recall accepted bytes. Collectors/replay/slurp/sort need finite
storage; pull evaluation does not imply constant memory for every filter.

Known schema-provider commands remain unavailable because their qualified helper
prerequisite is absent at this source base. Their authored success/rejection cases
remain blocked. Portable HTML needs neither Apple PDF preparation nor transfer
providers. WASI CLI feasibility is distinct from compiled libraries/private kernel;
Node poll_oneoff currently fails with IO exit7, while five WasmKit commands pass; POSIX SIGINT bridging remains unavailable. Actual receipts
and remaining mandatory gates determine release readiness.


## Qualified portable provider increment

`schema provider openai-format SCHEMA --name NAME` emits the exact native object for
Responses text.format. `openai-tool` emits one flat Responses function tool, with
strict true and object parameters. Both accept bounded `--description` and explicit
`--resource URI=PATH`; external-reference export remains incompatible without a
bundling policy. No network request, credential, model session or schema lowering
occurs. Incompatibility/unverified declarations exit1 with bounded typed issues,
while malformed schema/missing refs5, finite resource6, IO7 and cancellation130 remain
errors. `apple-check` stays unavailable and is omitted from help. See
[the actual helper/profile/consumer contract](Providers.md). Earlier unavailable
provider observations in this file are preserved history, superseded by this increment.
