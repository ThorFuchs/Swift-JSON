# 1.2.1 first test wave

Base: published 1.2.0, `25fb04f747e583209b4c4511abf39e11ef5b4f80`.
This isolated increment implements T00 measurement/discovery and a focused T01
Codable-container subset. Production Sources, APIs, products, platform declarations,
runtime dependencies, finite profiles, fixture pins and required check names remain
unchanged. Later 1.3 feature work is outside this branch.

## Added behavior

[CodableContainerTests.swift](../../../Tests/JSONTests/CodableContainerTests.swift)
adds 23 nonparameterized Swift Testing functions using public JSON interfaces:

- Keyed/unkeyed nested containers, named/default/unkeyed super containers, explicit
  empty values and repeated keyed requests/replacement preserving insertion order.
- All 14 standard Bool/String/Float/Double/signed/unsigned primitive overloads,
  nil and generic exact JSON values against independently specified golden values.
- Unkeyed decodeNil/index/end behavior and recovery after ordinary type errors;
  unknown fields, key presence and explicit null.
- Complete typed coding paths for missing keys, wrong kinds and inexact integer
  projection; underlying structured causes and floating range errors.
- All nonthrowing keyed/unkeyed child-request resource failures, contains/allKeys
  failure latching, conflicting containers, unset roots and caught cancellation.
- Identical complete nested operations succeeding at N and failing at N−1 under
  one cumulative work ledger, with exact domain/metric/limit/attempted/overflow
  assertions. Caller errors remain distinct; fresh invocations remain independent.

The root expectation changes from 192 to **215** functions. Parameterized discovery
stays **173**; these numbers are distinct from vectors looped within a function.
The existing QA filter includes the new cases, with exact **34/3/3/2** module counts.
No passing placeholder, softened original expectation or test-only private caller
is added. The two unused helpers retain their original uncovered disposition.

## Measurement and qualification harness

Run `python3 Scripts/ci.py --lane coverage` on the supported native toolchain.
Its exporter collects each instrumented executable and merged profile, binds source
and binary identities, checks the full source denominator and classifies generated
and unmapped files. It must reject an actual export with the schema binary omitted.
Branch/MC/DC unavailability is explicit. Ten negative/positive Python harness tests
exercise tooling boundaries; they are separate from Swift behavior counts.

[TestDiscovery.json](../TestDiscovery.json) replaces duplicated current root-count
constants in native and WASI tooling. All 49 metric probes and independent policy
counts remain exact. The coverage lane is an additional local native lane; Linux
layout fixture tests do not certify execution on Linux. The existing native/safety
and focused QA lanes are required for this increment, with command receipts and
final source identities retained outside the public source distribution.

## Remaining plan scope

The broader [plan](Plan.md) remains active. Foreign coder probe matrices, wider
numeric strategy combinations, precise source/preview diagnostics, held I/O gates,
schema/regex/Patch decision expansion, public end-to-end scenarios and adversarial
assurance are later waves. The proposed 98% line/95% region targets have not been
declared achieved by adding these cases. New Linux/WASI and device results are not
implied by a native run. No release or remote action is part of this increment.
