# Local use and installation choices

This is a review candidate for kit 0.1.0, not an endorsed or directory-published
plugin. Review its manifest and files before enabling it. The payload has one
instruction-only skill: no service, connector, authentication, hook or telemetry.
Running recipes needs a local executor and the library's supported Swift tools.

For a disposable Codex standalone trial, extract the standalone ZIP and copy
its `swift-json` folder to `.agents/skills/swift-json` in an **isolated consumer
workspace**, then start a fresh Codex context there and invoke `$swift-json`.
The host should discover that repo-scoped skill. Do not put it into the library
root or a personal skill directory merely to test it. Host versions differ;
successful JSON validation does not prove discovery or installation.

The plugin ZIP contains a portable root plugin.json and skills/swift-json.
Current OpenAI authoring guidance supports repo/local marketplace discovery;
test marketplace configuration only in a disposable workspace. In the desktop
plugin directory select the local source, inspect the package and install only
after user authorization. This kit does not create a marketplace or enable
itself. CLI marketplace configuration/installation commands can persist user
settings, so are not an automatic recipe step.

Authoring references refreshed 2026-10-18:

- [Portable plugin layout](https://developers.openai.com/plugins/build/plugins)
- [Skill workflow authoring](https://developers.openai.com/plugins/build/skills)
- [Standalone discovery and invocation](https://learn.chatgpt.com/docs/build-skills)

Root portable identity is canonical; skills are discovered at the fixed skills/
path. This kit has no compatibility overlay, so no overlay merge is assumed.
Informational use on another host does not imply that host can execute Swift.
Installation and public distribution remain separate review decisions.
