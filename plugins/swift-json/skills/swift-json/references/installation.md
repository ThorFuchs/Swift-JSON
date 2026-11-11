# Local use and installation choices

Kit 0.2.0 is a review candidate, not a directory-published plugin. Review its
manifests and files before enabling it. The payload has one instruction-only
skill: no service, connector, authentication, hook or telemetry. Running
recipes needs a local executor and the library's supported Swift tools.

## Claude Code

The Swift-JSON repository is also a Claude Code plugin marketplace. Its root
`.claude-plugin/marketplace.json` lists this plugin from `./plugins/swift-json`,
whose `.claude-plugin/plugin.json` carries the Claude Code identity. In a
session the user runs `/plugin marketplace add ThorFuchs/Swift-JSON`, then
`/plugin install swift-json@swift-json`. Adding a marketplace and installing a
plugin persist user settings, so they are the user's explicit action, never a
recipe step. The skill is discovered from `skills/swift-json` and is invoked as
`/swift-json:swift-json` or chosen automatically from its description.
`claude plugin validate` checks the manifests; it does not prove useful execution.

## Codex and portable hosts

For a disposable Codex standalone trial, extract the standalone ZIP and copy
its `swift-json` folder to `.agents/skills/swift-json` in an **isolated consumer
workspace**, then start a fresh Codex context there and invoke `$swift-json`.
Do not put it into the library root or a personal skill directory merely to
test it. Host versions differ; successful JSON validation does not prove
discovery or installation.

The plugin ZIP contains the portable root `plugin.json`, the Claude Code
manifest and `skills/swift-json`. Current OpenAI authoring guidance supports
repo/local marketplace discovery; test marketplace configuration only in a
disposable workspace and install only after user authorization. CLI marketplace
configuration/installation commands can persist user settings, so are not an
automatic recipe step.

Authoring references (observed dates are in the compatibility map):

- [Portable plugin layout](https://developers.openai.com/plugins/build/plugins)
- [Skill workflow authoring](https://developers.openai.com/plugins/build/skills)
- [Standalone discovery and invocation](https://learn.chatgpt.com/docs/build-skills)
- [Claude Code plugin manifest](https://code.claude.com/docs/en/plugins/manifest-reference)
- [Claude Code marketplaces](https://code.claude.com/docs/en/plugins/marketplace-reference)

Both manifests carry the same name, version, description, license and
repository; skills are discovered at the fixed skills/ path. Informational use
on another host does not imply that host can execute Swift. Installation and
public distribution remain separate review decisions.
