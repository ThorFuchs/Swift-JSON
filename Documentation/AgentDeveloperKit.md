# Swift-JSON developer kit

Kit **0.1.0 preview** is available from its
[dedicated download release](https://github.com/ThorFuchs/Swift-JSON/releases/tag/developer-kit-v0.1.0).
Its library pin is released **Swift-JSON 1.6.1**. Those version numbers are separate.
The preview supplies consumer instructions and examples; the library API is unchanged.

## Download the preview

- [Skills-only plugin ZIP](https://github.com/ThorFuchs/Swift-JSON/releases/download/developer-kit-v0.1.0/swift-json-plugin-0.1.0.zip)
- [Standalone skill ZIP](https://github.com/ThorFuchs/Swift-JSON/releases/download/developer-kit-v0.1.0/swift-json-skill-0.1.0.zip)
- [Qualification snapshot](https://github.com/ThorFuchs/Swift-JSON/releases/download/developer-kit-v0.1.0/DeveloperKit-0.1.0-Qualification.json)
- [SHA-256 checksums](https://github.com/ThorFuchs/Swift-JSON/releases/download/developer-kit-v0.1.0/SHA256SUMS)

Use the two named kit ZIPs for these instructions. GitHub's automatic source
archives capture the development repository at the kit tag; stable library
consumers should continue to resolve the separate **1.6.1** library version.

Standalone skill and local plugin discovery were observed with Codex CLI
0.162.0-alpha.17.2. Plugin installation/enabling, desktop end-to-end use and
public plugin-directory availability remain unverified. This is a downloadable
preview with those explicit limits. The qualification snapshot records its
prepublication evidence date; publication/download checks are recorded separately.

The kit supplies one focused `swift-json` skill: identify an application's actual
dependency, choose the smallest version-matched public products, implement exact
JSON behavior and verify it in that consumer. It contains no connector, server,
hook, API-key setup, telemetry or automatic download/execution helper.
The root library package, product graph and deployment floors are unchanged.

## Contents and compatibility

The canonical [skill](../plugins/swift-json/skills/swift-json/SKILL.md) lives under
the minimal portable [plugin manifest](../plugins/swift-json/plugin.json).
The same skill bytes produce a standalone distribution. Supporting references
are progressively loaded; assessment criteria are excluded from both archives.
The [compatibility/source map](../plugins/swift-json/skills/swift-json/references/compatibility.json)
binds the exact 1.6.1 commit/tree and immutable declarations to each recipe.

Stable 1.6.1 has eight libraries: JSON, JSONSchema, JSONSchemaExamples,
JSONStreaming, JSONPatch, JSONHTML, JSONBridges and JSONNavigation; swift-json
is a separate executable. The [release](https://github.com/ThorFuchs/Swift-JSON/releases/tag/1.6.1)
and its eight-catalog DocC asset establish that stable scope. Main and the live
documentation website remain **unreleased 1.7.0-dev** with JSONInspection.
The skill does not import Inspection for a stable consumer, silently upgrade a
dependency or claim that unfamiliar revisions were qualified by testing 1.6.1.

Compilation requires a local executor, Swift tools/compiler 6.4+ and language
mode 6. Native Apple qualification uses macOS/SDK 27+; iOS/iPadOS minimum is 27.
Linux/WASI retain their separately documented qualified scopes. An informational
host can use the guidance without being able to run Swift. Successful discovery
does not prove installation, useful execution or every host/platform combination.

## Build and inspect the candidate

Run these contributor checks from a Git checkout; the scope verifier needs its
recorded base and history. The scripts use Python's standard library, except optional full schema validation
using an existing local jsonschema installation. No root dependency is added.
Both output directories below must be new; files are never overwritten:

```sh
python3 -B Tools/DeveloperKitAcceptance/test_kit.py
python3 -B Scripts/validate_developer_kit.py
python3 -B Scripts/package_developer_kit.py --output /absolute/new/kit-a
python3 -B Scripts/package_developer_kit.py --output /absolute/new/kit-b
```

Each directory contains `swift-json-plugin-0.1.0.zip`,
`swift-json-skill-0.1.0.zip` and `ASSETS.json`. ZIP members have stable order,
timestamps and modes; compare both builds' bytes. Each ZIP has a self-excluded
member manifest. The standalone skill payload is byte-identical to the plugin's
skills/swift-json subtree. Archives contain no library checkout, build trees,
evaluation answers, private evidence or historical returns.

For complete metadata-schema validation, retain the current
[Agent Plugins 1.0.0 schema](https://agent-plugins.org/schemas/1.0.0/plugin.schema.json)
and pass its local path with `validate_developer_kit.py --schema PATH`.
Supply `--plugin-zip PATH --skill-zip PATH` to verify the two distributions against
their manifests and canonical files. Without `--schema`, the checker explicitly
reports that full schema validation was not run. Static validation does not prove
semantic correctness, installation or agent usability.

## Try it without changing personal settings

For a standalone trial, extract the skill ZIP and copy its swift-json folder to
`.agents/skills/swift-json` in an **isolated disposable consumer workspace**.
Start a fresh Codex context there and invoke `$swift-json`. Keep the library's
contributor AGENTS.md separate from this optional consumer skill. Do not install
into a personal/global directory merely to author or validate the kit.

For a plugin discovery trial, extract the plugin ZIP into a disposable workspace
at `plugins/swift-json`. Follow the official
[repo marketplace example](https://developers.openai.com/plugins/build/plugins#install-a-local-plugin-manually)
there, using source.path `./plugins/swift-json`. Do not create a marketplace in
the library checkout. Listing a local plugin is a discovery test; desktop
installation/enabling is a separate user action. No app restart is required by
the acceptance harness, and no personal configuration is changed automatically.

The portable root plugin.json uses fixed skills/ discovery. This kit needs no
compatibility overlay or presentation extension. Current official guidance says
an inline OpenAI extension replaces a compatibility overlay rather than merging
it; this candidate ships neither. No public directory presence or endorsement
is claimed.

## Execute the public recipes

The [recipe index](../plugins/swift-json/skills/swift-json/references/recipes.md)
points to a single executable Swift source. It asserts exact values above 2^53,
absent/null and scalar keys, exact/rounded conversion, valid/invalid schema
verdicts, operational exhaustion and diagnostic incompleteness, certified
examples, NDJSON final-no-newline/truncation/terminal limits, physical/virtual
coverage, staged Patch failure and inert HTML data.

With the supported native toolchain selected, run:

```sh
python3 -B Tools/DeveloperKitAcceptance/run_recipes.py --output /absolute/new/recipe-run
```

This command writes the source copy and isolated SwiftPM cache/config/security/
scratch plus logs and receipt.json. The new directory must be outside every Git
checkout. It resolves the public HTTPS dependency with exact 1.6.1, checks the
effective mirror absence, resolved revision/tree, all eight imports, empty root
dependency graph, source-map hashes and tagged CLI identity. It executes behavior
assertions in Debug and Release; failure exits nonzero. No resource fixtures are
injected from a local checkout. A path dependency does not substitute for this test.

Finite quotas remain cumulative within their documented invocation. Separate
public calls do not create an application-wide ledger automatically. Diagnostic
completeness is distinct from schema validity, and logical retained bytes are
distinct from process RSS or caller instruction quotas.

## Maintain and review

Authoring guidance was refreshed on **2026-10-18** from official
[plugin packaging](https://developers.openai.com/plugins/build/plugins),
[skill authoring](https://developers.openai.com/plugins/build/skills) and
[standalone skills](https://learn.chatgpt.com/docs/build-skills) documentation.
Use the portable root-manifest schema; the smaller compatibility example on the
skills page is not authority for adding a skills field to that root manifest.

Record actual tool/host versions, commands, exits, source/kit hashes and
limitations with each candidate. Forward-test representative tasks in fresh
contexts without supplying hidden rubrics; compile resulting coding artifacts.
Keep deterministic recipe assertions distinct from agent-use observations and
host discovery distinct from installation. The focused
[acceptance harness](../Tools/DeveloperKitAcceptance/README.md) explains this boundary.
Source admission was reviewed separately from this preview distribution.
Future revisions require review of their exact payload and compatibility evidence.
The library-source archive includes the reviewed `plugins/swift-json/` subtree;
other plugin subtrees need their own explicit archive-policy review. The existing
public inventory, privacy and link checks apply to this payload. Focused archive
regressions check exact canonical bytes, deterministic reproduction, generated-file
exclusions and symlink refusal. The standalone kit packager separately verifies
that both ZIPs contain the complete canonical payload.
Existing compiler/performance/platform holds and the maintenance branch protection
follow-up retain their previous scope; this kit does not reopen or promote them.
