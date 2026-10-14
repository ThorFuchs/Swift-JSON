# Reachable core coverage and diagnostic calibration

This wave adds 22 meaningful Swift Testing functions on the isolated 1.2.1 branch:
21 in JSON and one public Patch integration case. Existing schema-output and
value-presence cases gain exact assertions. Root discovery is 298 functions and
173 parameterized invocations; QA is 125 functions and shared-state safety 22.

The cases cover preserved numeric spelling, finite/nonfinite/subnormal conversion,
EOF source documents and typed spans, exact foreign keys and delegated native
numbers, nested conversion failures, scratch release, scalar prefix sorting,
absent-member edits, reused containers, integer dictionaries, exhaustive bounded
work-quota sweeps, persistence sink refusal, mapped-error work, nested array
editing, and escaped schema-output Pointers. Production source and APIs are
unchanged from the previously qualified best-effort diagnostic repair.

A deliberately bounded exhaustive sweep asserts every insufficient work quota
and the exact successful boundary. Source-mapped error construction, payload
field construction, selection, projection and ordinary refusals retain one owned
ledger. Native model Codable paths are relative to the selected projection root;
read-access failures retain the complete typed JSON path.

The source receipts preserve the initial compiler mistakes and an incorrect
selected-root path assumption. That failing run produced 33 assertions; correction
follows the inspected existing API rather than weakening a released contract.
The first WASI setup also failed because a concurrent SwiftPM lock message entered
manifest JSON. It ran no WASI behavior tests and is retained beside the sequential
rerun. No production test or corpus case was excluded to obtain a pass.

## Performance disposition

No new timing comparison ran. Five native observations failed the predeclared
quiet-host gate: load1 31.14–35.19 on ten logical cores; CPU idle 0.24–10.22%.
The readiness command exited 2, and no other session/application was stopped.
The user explicitly authorized recording a blocker if competing activity persisted.
The frozen original short/long runs, binaries and input hashes remain preserved.

The +11.983% longer diagnostic median remains above the unchanged 10% review
trigger. Its paired changes range from -0.53% to +73.21%; attribution is unresolved.
Retain the required correctness repair and recalibrate on a genuinely quiet host
before the 1.2.1 release decision. No threshold, quota or optimization was changed.
Historical streaming performance disposition is unchanged. Logical retained bytes
and owned work are equal in the original pairs; neither describes process RSS
or arbitrary caller instruction quotas.

## Scope and remaining work

Coverage retains its full denominator, including 53 authored lines in unused
JSONFingerprint/JSONOperationContext helpers. Guarded states, arithmetic defenses,
generic-expression continuations and unavailable branch/MC/DC counters are
explicitly distinguished from asserted public behavior. Execution percentages
alone establish no exhaustive assertion or decision coverage.

The broader E2E/mutation acceptance plan remains open. No Apple-device scope,
WASI sanitizer, backend, API, dependency, optimization, sibling 1.3.0 file,
merge, tag or release publication is added by this wave.

## Qualified outcomes

Native debug/release/full ASan passed 298 functions / 173 parameterized
invocations; TSan passed 22 functions. All 49 cap probes, strict-memory
compilation, public consumers, independent policies and 582-symbol DocC passed.
Both Linux architectures passed full qualification/safety and complete atomic
exports. Node/WasmKit scoped WASI passed 38 commands. Actual source and every
downloaded command log were compared with the final tested commit.

| Module | Authored lines | Authored regions |
| --- | ---: | ---: |
| JSON | 3381/3443 (98.20%) | 3316/3427 (96.76%) |
| JSONSchema | 2389/2417 (98.84%) | 2954/3091 (95.57%) |
| JSONRegexRuntime | 650/659 (98.63%) | 668/695 (96.12%) |
| JSONStreaming | 228/232 (98.28%) | 256/269 (95.17%) |
| JSONPatch | 184/185 (99.46%) | 210/212 (99.06%) |

All five modules meet the proposed 98/95 review targets without denominator
changes. Native and both Linux totals agree. The residual review retains 111
never-hit code-region mappings, including unused helpers and generic variants.
This does not prove branch or MC/DC completeness.

[Actual outcomes and evidence index](CoreClosureOutcomes.json) distinguish the
scopes and include the final [Native run](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38572760920)
and [Linux run](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38572755403).
The materialized companion bundle supplies profiles, native/Linux objects, WASI
modules, logs, source identities and original calibration inputs/binaries;
private build artifacts remain outside Git and public source archives.
