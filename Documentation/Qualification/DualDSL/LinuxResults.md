# Dual DSL P1.2 Linux qualification

[Recovery run 38680343090](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38680343090)
passed all four jobs at `6f6bd90467aae0354dc5dcfdc7e125a5f6e8d2de`.
Both ARM64 and x86_64 used Ubuntu 24.04, Swift 6.4.0 and the unchanged official
multi-architecture image pin
`swift@sha256:31d14d727f4451f25e29bac9c42563a098c39ac66415e8bad970f48038e38aca`.
The actual environment and every command/log digest are in the downloaded receipts.

Each architecture passed 16 full qualification commands and four safety commands.
Debug, Release and ASan each required eight exact bundles, 329 functions and all
173 parameter invocations. Shared-state TSan required 12 portable functions;
strict-memory-safety compilation passed. Six intended compiler negatives rejected
in each of two configurations, with public positive and qualified-name collision
consumers. The separate public DSL consumer passed real valid/invalid/operational
outcomes. All 49 cap probes and unchanged independent corpus policies passed:
318 syntax cases (287 evaluated/31 policy), 2337 schema cases (2300 evaluated/37
policy), 82 authored, nine budget and 4396 malformed replay cases. Policy cases
are not evaluated successes, and operational errors are not false verdicts.

Both jobs independently rebuilt identical candidate bytes, verified the manifest,
extracted without Git metadata, built all products, ran six integrity/resource
functions and executed the public consumer with compiled README DSL examples.
Archive SHA-256 is
`3f00c91f205bbafb9c722e6bb5d5c0f4ba9996c359f046a16d12bac91699e547`,
1,352,635 bytes, 931 entries including its 930-file source manifest. This matches
the local immutable source archive byte-for-byte. Every job's source-input map
matches that archive, with unchanged-source assertions and actual Git SHA recorded.

[First run 38679209482](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38679209482)
is retained as failed. Its two safety jobs passed; its full lanes passed nine
commands then stopped before the DSL compiler probes when Git rejected container
checkout ownership. The recovery trusts only the exact ephemeral GITHUB_WORKSPACE
and asserts HEAD equals GITHUB_SHA before qualification. No wildcard trust, host
configuration or test relaxation was added. Git identity and full privacy/history
checks now execute, rather than being skipped for an unreadable Git checkout.

The native results remain separately qualified, including the transparent ENOSPC
continuation and the retained PDF timeout followed by an unchanged complete passing
safety rerun. No Apple/device claim is inferred from Linux. Additional iPhoneOS and
iPhoneSimulator 27.2 SDK builds (minimum 27) passed the public DSL consumer. Matching
Swift 6.4 WASI builds compiled portable root bundles, and all 47 new DSL tests passed
Debug and Release in Node; the public release consumer also passed WasmKit. These
additional scopes do not imply a new full WASI corpus/sanitizer or physical-device run.

Only reporting/qualification records may follow this tested source identity in the
freeze commit. Library, test, manifest, consumer and qualification-harness source
are unchanged since the implementation commit. The workflow change is confined
to exact container checkout identity verification; protected checks and release
publication remain separate. Trusted unmetered authoring and finite finalization
retain their explicit resource boundary.
