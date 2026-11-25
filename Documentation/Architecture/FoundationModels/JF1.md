# JF1 — Foundation Models compatibility and package isolation

**Status:** spike implemented; native qualification and packaging admission pending.
**Date:** 2026-11-25. Baseline: `c2e4aea7cf63bdf8236c22cc9ba0c6a3abeb5201` (prepared 1.10.0 source).
This is a diagnostic feature branch, not a new public product or release.

## Decision under test

Prefer an opt-in JSONFoundationModels library inside Swift-JSON. Preserve all
13 existing products, zero external package dependencies, Swift tools 6.4,
Swift language mode 6, macOS 15/iOS 18 floors, Linux and WASI contracts.
If actual resolution, build, linkage or deployment qualification shows a
conflict, use a separate package/repository. No root manifest change in JF1.

The [application integration roadmap](https://github.com/ThorFuchs/Swift-MCP-Server-HTTP/blob/9c87f45f0122f9112e862dc8b300e4c15b0b790b/Docs/Release/APPLICATION_INTEGRATION_ROADMAP.md)
is the cross-SDK direction. This spike stays within Swift-JSON ownership.
No Core or HTTP changes are needed or authorized by it.

Apple's SDK supplies FoundationModels without an external SwiftPM package
dependency on supported Apple platforms. The announced open-source core
is not yet a qualified Linux dependency in this project. Do not use an
unverified external package, replace the framework with a stub, or count an
empty guarded module as a functional bridge. JF1 uses only public SDK APIs
and intentionally scopes Apple API execution to macOS 27; precise earlier
availability is a subsequent admission decision.

## Experiment design

Scripts/qualify_foundation_models.py takes an exact clean source commit and
an output directory outside its checkout. It materializes two disposable
copies of the same tracked manifest, Sources and Tests. In the candidate
only it inserts one library product and one target, depending on JSON and
JSONSchema, and copies the probe into that target. Compare evaluated
SwiftPM manifests, preserving every existing product/target and the
package-level dependency/platform/language contract. No tracked file is
modified. The 14-product experiment must not be confused with the
13-product released/prepared inventory.

Ordinary independent consumers select JSON and JSONSchema only. They
reference the two disposable packages by path so the exact experimental
source is under control. This is a local package-resolution experiment,
not evidence of a published remote package. Inspect the resolved graph,
verbose build output, link on the macOS 15 deployment floor, inspect
Mach-O linked libraries with otool, and run exact integer/schema smoke
tests. The absence of FoundationModels from those link commands does not
by itself establish the behavior of every existing consumer.

The optional target is also compiled at the existing package floor and
for iOS 18 device and simulator. Ordinary iOS consumer target builds
supplement the deployment-floor checks. These are compilation checks, not
iOS runtime tests. On Linux the conditional target has only an unavailable
marker. The WASI lane builds the ordinary consumer, checks the wasm
artifact header and compiles the guarded target; it does not execute WASI.

## Public API observations (no model execution)

The bridge consumer runs thirteen independent fixed synthetic cases in
Debug and Release. It exercises:

- @Generable and @Guide with integer range, string choices, array count,
  description and optional property; serialize generationSchema with
  Swift-JSON's native Codable encoder, compare with Foundation JSONEncoder
  as an independent diagnostic control, compile with JSONSchemaCompiler,
  and inspect five positive/negative/optional instance verdicts.
- DynamicGenerationSchema object/property/primitive/guide construction and
  GenerationSchema(root:dependencies:).
- Typed construction from GeneratedContent and the generatedContent return.
- Ten value roundtrips: ordinary nested values, explicit null, absence,
  integer beyond 2^53, Int64.max, high-precision decimal, exponent, distinct
  Unicode scalar keys, decomposed string and nested arrays/objects.

An independent executable probes the public GenerationSchema Decodable
conformance and a canonical JSON Schema -> GenerationSchema -> JSON
roundtrip. A reverse compile failure preserves the earlier forward evidence.
Foundation encoding is a diagnostic control, never JSON authority.
Each case records OBSERVED or REJECTED, with exact native values and
comparisons in the log. Neither disposition is a semantic-equivalence
certificate. A completed observation can contain a false equality or
an unexpected validation verdict. Review the raw receipts before deciding
which shapes JF2/JF3 can admit. These fixed diagnostic calls do not claim
one production cumulative work budget across Apple-owned callbacks.

## Execution and evidence

From the exact clean feature branch checkout:

    python3 -I Scripts/test_foundation_models_spike.py
    python3 -I Scripts/qualify_foundation_models.py "$(git rev-parse HEAD)" "$HOME/JF1-Evidence" --lane apple

On the actual Swift 6.4.2 Linux host, use --lane linux. With the matched
Swift.org 6.4.2 WASI SDK installed, use --lane wasi --swift-sdk
swift-6.4.2-RELEASE_wasm (verify the actual installed SDK ID). No SDK is
downloaded or installed by the runner. The default free workspace disk
preflight is 20 GiB, not a measured upper bound. Use a quiet host and
an external output volume when needed; builds/caches can use additional
internal storage. No hosted CI or artifact upload. The evidence-only
archive retains manifest/graph/build/link/runtime logs, process exits
and provenance. Disposable build workspaces remain for inspection.
A failure retains available evidence; it does not become a pass.

Local editing-host evidence: Python 3.13.5, 9/9 offline test methods
passed; Python syntax compiled; both Swift probe files passed frontend
parse on Linux Swift 6.2.1. The guarded Apple branch was not typechecked
against the Apple SDK. Synthetic manifest controls validate policy, not
the actual SwiftPM 6.4 graph. No native SDK, Linux Swift 6.4.2 or WASI
execution has occurred for this branch. No Foundation Models API result
or final package placement is admitted.

## Admission and next work

JF1 is complete only after review of actual Apple API and package-isolation
observations and appropriate portable evidence. Before promoting a root
product, run the unchanged existing native, platform-floor, Linux and WASI
qualification lanes via Scripts/ci.py, and deliberately review their exact
product/API/documentation inventories for any additive candidate.
Repeat affected full lanes on the eventual admitted product; do not
bypass their current 13-product checks in the disposable experiment.
No deployment floor or test-count relaxation. Separate compile-only
and runtime scopes. Only then decide monorepo versus separate package.

JF2: checked value bridge with exact/explicitly projected/unsupported
outcomes, finite owned work, cancellation and metadata policy.
JF3: bounded schema compatibility and native validation; do not assume
arbitrary Draft 2020-12 equivalence from a Codable roundtrip.
JF4: public typed convenience, DocC and external consumer.
No API freeze, tag, merge, product count change or release in this batch.

## Public reference material

- [WWDC26 Foundation Models](https://developer.apple.com/videos/play/wwdc2026/241/)
- [GeneratedContent](https://developer.apple.com/documentation/foundationmodels/generatedcontent)
- [Generable.generationSchema](https://developer.apple.com/documentation/foundationmodels/generable/generationschema)
- [DynamicGenerationSchema](https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema)
- [GenerationGuide](https://developer.apple.com/documentation/foundationmodels/generationguide)
- [Apple utilities: GenerationSchema Codable](https://github.com/apple/foundation-models-utilities/blob/6c5a04c917b244f5b312d50cff305a8d3316d818/skills/foundation-models-language-model-protocol/SKILL.md)
- [SE-0273](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0273-swiftpm-conditional-target-dependencies.md): conditional target dependencies do not imply conditional resolution.
