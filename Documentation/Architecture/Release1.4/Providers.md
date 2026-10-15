# Offline provider schema helpers

PR27 adds the portable C5 helpers to JSONSchema, with no new product or root dependency.
The parent is main-reconciled aded3c9930f580bd4fb902bba002ab75ed199a7b; all earlier
reconciliation, resource-fix and release records remain history.

`OpenAIJSONSchemaBridge(profile:limits:)` is an immutable checked-Sendable facade.
Select `.openAIResponsesFormatV1` or `.openAIResponsesFunctionV1` explicitly.
`check` and `checkWithReport` first perform native offline compilation, then return
`JSONSchemaProviderCompatibility`. Its bounded typed issues distinguish unsupported
and unverified declarations; keys remain `.key(JSONKey)` and array positions `.index`.
`isCompatible` remains false when zero issue capacity truncates every issue.

`responseFormat` returns the native object to insert at Responses `text.format`.
`functionTool` returns one flat Responses function tool with object `parameters`.
Both set strict true and retain the original schema object, order, numeric values,
number lexemes and scalar-distinct keys. They never insert required/default/null,
strip constraints or bundle external documents. Metadata remains native JSON text.
The complete value, Data and String methods have WithReport counterparts. Native
preserved-number writing, output and result-copy overlap belong to that one ledger.

The [frozen profile tables](ProviderProfiles.json) identify purposes, capability
category, revision, keyword/format allowlists, all finite presets, source dates and
counting rules. Provider ceilings and conservative local policy are separate.
Fine-tuned models and unqualified declarations are not automatically accepted.
Objects explicitly declare their properties map, including an empty map.
Title/description are retained metadata; const and string length keywords remain
unverified in this initial local subset. The function-name ASCII/64-byte rule is
an explicit conservative local policy, separate from output-format metadata rules.
The implementation guarantees local checks and unchanged request construction;
it does not promise that any model, service revision or account will accept them.

## Completion and failures

The CLI offers `schema provider openai-format|openai-tool SCHEMA --name NAME`, optional
`--description`, and explicit offline `--resource URI=PATH`. Success exits0 with a
fragment. Completed profile incompatibility exits1 with `{compatible,profile,revision,
capabilityCategory,issues,truncated}` and no schema/parameters candidate. A report
then says completed:true. Missing resources/native schema errors exit5; quota/overflow
exit6, IO exit7 and cancellation130. They never become compatibility false. CLI
terminal reports keep cumulative remaining work; public helper throws end that
operation without a successful report. Named outputs retain ordinary atomic rules.

Only qualified portable helpers are advertised. `apple-check` remains unavailable
(exit2) before input IO; no FoundationModels import, placeholder success or fake
Apple-typed API is introduced. Provider-brief P2/P3 and optional GeneratedContent
work remain outside this C5 closure. No API request, credential lookup, model
session or online resolver exists in these helpers.

Completed application output is a different boundary. The caller must first handle
transport failure, refusal and incomplete generation, then parse completed text
with JSONParser and validate it with JSONSchemaValidator. Validation false differs
from thrown operational errors. Arbitrary streaming deltas and valid prefixes are
not completed output. No OpenAI event-envelope client is added here.

## Qualification and review

Meaningful Swift Testing covers 13 schema functions and eight additional CLI functions:
exact value/text/data/report parity, scalar keys, metadata, optional/null, closure,
typed paths, local references/productive recursion, cross-definition depth, external
resources, invalid native schemas/regexes, truncation, all custom capacities, inclusive
work/output/retention boundaries, terminal latching, in-loop cancellation and sharing.
`Tools/CLIQualification/ProviderConsumer` imports only JSON/JSONSchema and executes14
public checks, including instance-invalid versus operational error and cumulative work.
The process harness executes32 focused scenarios plus the five unchanged provider
fixtures; all six authored C5 vectors are now required by native/Linux/CLI CI.
Native exact comparison checks the complete fragment; a mere exit0 is insufficient.
Static dependency/call inspection establishes absence of a network client or model
session; no paid API/service-acceptance or socket-trace claim is made.

CI retains precise platform inventories: 369 Apple/355 Linux root functions and199
parameter cases, with65 schema and85 CLI functions. TSan covers12 Apple/11 Linux
shared functions. All49 baseline metric probes and every inherited case/exclusion
remain guarded. The WASI core expected schema inventory increases to65; fresh WASI
helper/platform execution must be identified separately before claiming it passed.

Review corrected a depth gap across referenced definitions, rejected nonproductive
reference/combinator cycles, preserved productive cycles without a global seen-set
rejection, retained UInt64 capacities on wasm32, charged filtered graph scans and
reserved envelope/path storage before growth and preserved document retrieval URI
through native reference resolution. A strengthened C5 harness initially used the comparator's wrong expected
container; its actual array-of-document-text contract was restored, preserving full
native comparison. Compiler-driven fixes are recorded in private receipts; no test
or supported baseline was weakened. Final source-bound native/safety/docs/Linux,
archive/reproduction, exact commands/exits/counts and remaining limitations accompany
the separate return. This document is not itself an assertion that a pending lane passed.
