# Contributing

Choose the source line deliberately: maintenance changes use the 1.6 line;
new capabilities target development. This checkout is unreleased 1.7.0-dev consolidation source; preserve the reviewed
component APIs/algorithms and qualify every combined source. Keep the lines' API inventories
separate and map applicable maintenance corrections forward by content/commit,
without assuming a squashed maintenance tip is an ancestor of main. See the
[release-line matrix](Documentation/Qualification/ReleaseLines.md).

Open a focused pull request against the appropriate source line (`release/1.6`
for maintenance, `main` for development) at
[ThorFuchs/Swift-JSON](https://github.com/ThorFuchs/Swift-JSON). Maintainer:
[@ThorFuchs](https://github.com/ThorFuchs). Contributions require Swift 6.4+,
Swift language mode 6 and macOS/SDK 27+ for native validation.

Read [AGENTS.md](AGENTS.md) and the relevant [behavior contracts](Documentation/README.md).
Describe the observable change, its reason, tests run and material limitations.
Use Swift Testing for behavior, adversarial inputs and boundaries. Keep a minimal
failing input and deterministic seed for parser, number and regex regressions.
Exercise public consumers in addition to tests using internal access.

Run the affected lanes from the root:

```sh
python3 Scripts/ci.py --lane native
python3 Scripts/ci.py --lane safety
python3 Scripts/ci.py --lane docs
```

For Linux changes also run `python3 Scripts/ci.py --lane linux` and
`--lane linux-safety` on an actual Swift 6.4+ Ubuntu 24.04/glibc runtime.
Linux results supplement the Apple gates; see the [platform contract](Documentation/Architecture/Linux.md).

Keep APIs neutral and exact, budgets cumulative and mutable state invocation-owned.
Do not add platforms, permissive parsing, online schema resolution, fallback engines
or runtime dependencies without an explicit design review. Benchmark and fixture
tools use separate packages. Preserve upstream pins and licenses when adapting
code. Original contributions use Apache-2.0.

Use [Issues](https://github.com/ThorFuchs/Swift-JSON/issues) for defects and support,
and [SECURITY.md](SECURITY.md) for private reports. Do not submit secrets or private
application fixtures. See [SUPPORT.md](SUPPORT.md) for the maintenance policy.

Public API changes need useful Swift documentation comments and a focused guide when
semantics span multiple calls. README Swift examples must match their compiled consumer.
See [documentation tooling](Documentation/DocumentationTooling.md) for coverage checks,
compiled examples and native DocC builds.

The optional [consumer developer kit](Documentation/AgentDeveloperKit.md) is
separate from these contributor instructions. Keep its canonical skill, pinned
public recipes and standalone/plugin distributions in sync through the focused
acceptance harness; independent review precedes merge and distribution.
