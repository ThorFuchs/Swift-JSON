# Swift-JSON developer kit

Kit **0.2.0** is the source candidate in this repository. Its library pin is
released **Swift-JSON 1.9.0**. Those version numbers are separate. The kit
supplies consumer instructions and examples; the library API is unchanged.

The previous **0.1.0 preview**, pinned to library 1.6.1, remains available from its
[dedicated download release](https://github.com/ThorFuchs/Swift-JSON/releases/tag/developer-kit-v0.1.0).
A `developer-kit-v0.2.0` download release does not exist yet; publishing it is a
separate maintainer decision.

The kit supplies one focused `swift-json` skill: identify an application's actual
dependency, choose the smallest version-matched public products, implement exact
JSON behavior and verify it in that consumer. It contains no connector, server,
hook, API-key setup, telemetry or automatic download/execution helper.
The root library package, product graph and deployment floors are unchanged.

## Install in Claude Code

This repository is a Claude Code plugin marketplace. In a Claude Code session:

```text
/plugin marketplace add ThorFuchs/Swift-JSON
/plugin install swift-json@swift-json
```

The root [marketplace file](../.claude-plugin/marketplace.json) lists the plugin
from `./plugins/swift-json`; its [Claude Code manifest](../plugins/swift-json/.claude-plugin/plugin.json)
carries the same name, version and description as the portable manifest. The skill
is discovered from `skills/swift-json`. Both commands persist user settings, so
they are the user's action. `claude plugin validate .` and
`claude plugin validate ./plugins/swift-json` passed with Claude Code 2.1.92
on 2026-11-11. Installation from GitHub and end-to-end use in a session are not
recorded yet.

## Use with Codex

For a standalone trial, copy `plugins/swift-json/skills/swift-json` (or the
standalone skill ZIP's `swift-json` folder) to `.agents/skills/swift-json` in an
**isolated disposable consumer workspace**. Start a fresh Codex context there
and invoke `$swift-json`. Keep the library's contributor AGENTS.md separate from
this optional consumer skill. Do not install into a personal/global directory
merely to author or validate the kit.

For a plugin discovery trial, place the plugin folder in a disposable workspace
at `plugins/swift-json` and follow the official
[repo marketplace example](https://developers.openai.com/plugins/build/plugins#install-a-local-plugin-manually)
with source.path `./plugins/swift-json`. The portable root `plugin.json` uses fixed
skills/ discovery and needs no compatibility overlay. Kit 0.1.0's Codex CLI
0.162.0-alpha.17.2 discovery observation has not been repeated for 0.2.0.

## Contents and compatibility

The canonical [skill](../plugins/swift-json/skills/swift-json/SKILL.md) lives under
the portable [plugin manifest](../plugins/swift-json/plugin.json) and the Claude
Code manifest. The same skill bytes produce a standalone distribution. Supporting
references are progressively loaded; assessment criteria are excluded from both
archives. The [compatibility/source map](../plugins/swift-json/skills/swift-json/references/compatibility.json)
binds the exact 1.9.0 commit `f2a0d12` and tree `6b54387` and 50 immutable
declaration/DocC hashes to fourteen recipes.

Release 1.9.0 has twelve libraries: JSON, JSONSchema, JSONSchemaExamples,
JSONStreaming, JSONPatch, JSONHTML, JSONBridges, JSONNavigation, JSONInspection,
JSONTransform, JSONValueDSL and JSONSchemaDSL; swift-json is a separate executable.
The [version reference](../plugins/swift-json/skills/swift-json/references/versions.md)
records which release added which API, so the skill does not use a 1.7–1.9 API in
a consumer resolved to an older version, upgrade a dependency silently or claim
that unfamiliar revisions were qualified by testing 1.9.0.

Compilation requires a local executor, Swift tools/compiler 6.4+ and language
mode 6. Deployment minimums are macOS 15 and iOS/iPadOS 18; development uses
Xcode 27 with the macOS 27 SDK. Linux/WASI retain their separately documented
qualified scopes. An informational host can use the guidance without being able
to run Swift. Successful discovery does not prove installation, useful execution
or every host/platform combination.

## Validate and package

`python3 -B Scripts/ci.py --lane docs` runs the kit checks with the
documentation build. They can also run alone from a checkout:

```sh
python3 -B Tools/DeveloperKitAcceptance/test_kit.py
python3 -B Scripts/validate_developer_kit.py
python3 -B Scripts/package_developer_kit.py --output /absolute/new/kit-a
python3 -B Scripts/package_developer_kit.py --output /absolute/new/kit-b
```

The validator checks the kit's content, not a diff: the exact payload file set,
both host manifests and their agreement, the repository marketplace entry, skill
frontmatter and links, the absence of private paths and untested Swift fences,
the consumer's twelve imports, exact 1.9.0 pin and recipe markers, and every
local hash. When the pinned commit is present locally (CI checks out full
history) it regenerates the compatibility map from that commit's bytes and
requires an exact match; otherwise it reports that comparison as not run.
After changing a kit file, run `validate_developer_kit.py --write-compatibility`
to refresh the map, then review the diff.

Each package directory contains `swift-json-plugin-0.2.0.zip`,
`swift-json-skill-0.2.0.zip` and `ASSETS.json`. ZIP members have stable order,
timestamps and modes; compare both builds' bytes. Each ZIP has a self-excluded
member manifest. The standalone skill payload is byte-identical to the plugin's
skills/swift-json subtree. Supply `--plugin-zip PATH --skill-zip PATH` to verify
both distributions against the canonical files. For complete metadata-schema
validation, pass a local copy of the
[Agent Plugins 1.0.0 schema](https://agent-plugins.org/schemas/1.0.0/plugin.schema.json)
with `--schema PATH` in an environment with jsonschema installed. Static
validation does not prove semantic correctness, installation or agent usability.

## Execute the public recipes

The [recipe index](../plugins/swift-json/skills/swift-json/references/recipes.md)
points to a single executable Swift source. The 1.6 recipes assert exact values
above 2^53, absent/null and scalar keys, exact/rounded conversion, valid/invalid
schema verdicts, operational exhaustion and diagnostic incompleteness, certified
examples, NDJSON final-no-newline/truncation/terminal limits, physical/virtual
coverage, staged Patch failure and inert HTML data. The 1.7–1.9 recipes add
located root-array byte spans, observed shape evidence and snapshots, ordered
batches with `optionalValues`, the configured store with integer IDs, complete
follow and owner-bound positions, bounded Transform with `selectIndices`, and
the value and schema DSLs.

With the supported native toolchain selected, run:

```sh
python3 -B Tools/DeveloperKitAcceptance/run_recipes.py --output /absolute/new/recipe-run
```

This command writes the source copy and isolated SwiftPM cache/config/security/
scratch plus logs and receipt.json. The new directory must be outside every Git
checkout. It resolves the public HTTPS dependency with exact 1.9.0, checks the
effective mirror absence, resolved revision/tree, the twelve-library product
inventory, empty root dependency graph, source-map hashes and tagged CLI
identity. It executes behavior assertions in Debug and Release; failure exits
nonzero. A path dependency does not substitute for this test. It downloads the
library and builds it twice, so it is not part of a CI lane.

Finite quotas remain cumulative within their documented invocation. Separate
public calls do not create an application-wide ledger automatically. Diagnostic
completeness is distinct from schema validity, and logical retained bytes are
distinct from process RSS or caller instruction quotas.

## Maintain and review

Authoring guidance was refreshed on **2026-10-18** from official OpenAI
[plugin packaging](https://developers.openai.com/plugins/build/plugins),
[skill authoring](https://developers.openai.com/plugins/build/skills) and
[standalone skills](https://learn.chatgpt.com/docs/build-skills) documentation,
and on **2026-11-11** from the Claude Code
[plugin manifest](https://code.claude.com/docs/en/plugins/manifest-reference),
[marketplace](https://code.claude.com/docs/en/plugins/marketplace-reference) and
[skills](https://code.claude.com/docs/en/skills) references. The marketplace
description sits under `metadata` because older Claude Code releases reject a
top-level `description`.

Record actual tool/host versions, commands, exits, source/kit hashes and
limitations with each candidate. Forward-test the
[evaluation cases](../Tools/DeveloperKitAcceptance/evaluation_cases.json) in fresh
contexts without supplying hidden rubrics; compile resulting coding artifacts.
Keep deterministic recipe assertions distinct from agent-use observations and
host discovery distinct from installation. The focused
[acceptance harness](../Tools/DeveloperKitAcceptance/README.md) explains this boundary.
The library-source archive includes `plugins/swift-json/` and `.claude-plugin/`;
other plugin subtrees need their own explicit archive-policy review.
Existing compiler/performance/platform holds retain their previous scope; this
kit does not reopen or promote them.
