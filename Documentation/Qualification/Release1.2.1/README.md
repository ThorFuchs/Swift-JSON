# 1.2.1 test quality work

This proposed patch-release work extends tests and qualification on the published
1.2.0 implementation. It changes no product API or behavior at the planning stage.

- [Audit of existing unit, integration and platform evidence](Audit.md)
- [Native five-module coverage baseline](CoverageBaseline.json)
- [Eight-work-package test expansion plan](Plan.md)
- [Machine-readable acceptance groups](AcceptanceMatrix.json)
- [Implemented first wave and remaining scope](Wave1.md)

Source baseline: `25fb04f747e583209b4c4511abf39e11ef5b4f80` (`1.2.0`).
Native baseline: 192 root functions, 173 parameterized invocations; 96.06% authored
executable lines and 91.39% regions. These execution measures do not establish
assertion completeness or unsupported branch/device coverage.

Recommended first wave: complete coverage export/cardinality checks, explicit
Codable containers and precise failures, then held source/sink backpressure.
Subsequent waves expand combined schema/regex decisions, Patch, public end-to-end
flows and bounded adversarial/mutation evidence. Existing independent suites,
all 49 caps and platform-specific limitations remain authoritative.

First wave implemented and natively qualified: 23 new Swift Testing functions,
215/173 root discoveries, complete coverage export and negative omission probe.
See [actual outcomes](Wave1Outcomes.json) for receipts and remaining scope.

The [second wave](Wave2.md) adds foreign-coder and 128-bit probes plus causal
streaming gates. Each wave retains its own source identity and native receipts.

Second wave natively qualified: 29 new functions, 244/173 roots, 71 QA and 18 TSan
functions. [Actual outcomes](Wave2Outcomes.json) retain unsupported typed 128-bit
Codable and platform/remaining-plan limitations.

The [portability/completion follow-up](Portability.md) adds a 566-case public
completion matrix and narrowly scoped Linux/WASI QA lanes. Its current
discovery is 245/173 roots, 72 QA and 19 shared-state functions; actual platform
results remain separate from the historical native waves.

The portability follow-up is [qualified within its declared scopes](PortabilityOutcomes.json).
Atomic coverage corrects saturated async counters to 97.46% lines / 93.04% regions;
the structural completion gap is reviewed with its denominator retained.
