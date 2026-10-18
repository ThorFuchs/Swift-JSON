# Developer kit acceptance

This separate harness exercises the instructions-only kit. It changes no library
source, root test inventory, CI lane or product contract. Expected agent-task
assessment criteria belong here, outside the distributed skill.

From the repository root, run:

```sh
python3 -B Tools/DeveloperKitAcceptance/test_kit.py
python3 -B Scripts/validate_developer_kit.py
python3 -B Scripts/package_developer_kit.py --output /absolute/new/distribution-a
python3 -B Scripts/package_developer_kit.py --output /absolute/new/distribution-b
```

Compare both ZIP hashes, and validate both distributions with
`validate_developer_kit.py --plugin-zip PATH --skill-zip PATH`.
For full manifest-schema validation, retain the current official
Agent Plugins 1.0.0 schema and pass its local path as `--schema PATH` in an
environment with jsonschema installed. Without it the checker explicitly reports
schema validation unrun. The distributed skill has no Python dependencies.

The public consumer runner explains and records its writes:

```sh
python3 -B Tools/DeveloperKitAcceptance/run_recipes.py --output /absolute/new/consumer-run
```

Select Swift 6.4+/language 6 and macOS/SDK 27+ in the environment first. The runner
requires a new directory outside **every** Git checkout; it creates an isolated
source copy/cache/config/security/scratch and resolves public exact 1.6.1. It
checks the actual pin/tree/product graph, CLI identity and Debug/Release recipe
assertions. Assertions throw on failure even in Release. A path dependency,
library test run or inherited cache does not substitute for this consumer check.

The packaged asset source is the sole recipe source. Its `// RECIPE` markers and
the compatibility/source map bind each guide entry to executed Swift. All eight
imports are deliberate acceptance coverage, not recommended default dependencies.

For agent-use evaluation, provide each evaluator only the packaged skill, a fresh
task prompt and relevant raw consumer/source facts. Keep assessment criteria out
of that context. Capture generated source and compile/run coding tasks against
the exact public dependency; separately score version boundaries and non-triggers.
Use at least six tasks spanning new integration, exactness, streaming/limits,
stable/development boundary and a Foundation-only non-trigger. Keep host/version,
kit hashes, prompts, outputs, commands and observed shortcomings. A handful of
tasks cannot establish a general effectiveness rate. A recipe assertion run is
not an agent-use evaluation, and discovery is not installation.
