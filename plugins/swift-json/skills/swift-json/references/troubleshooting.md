# Troubleshooting

- **No local Swift executor:** provide version-matched guidance and mark compilation
  unrun. Plugin availability in a conversational host does not provide Xcode or Swift.
- **Unsupported compiler or Apple SDK:** record the actual version and missing
  requirement. Do not lower tools 6.4/language 6 or the macOS 15 / iOS 18 minimums
  (27 before 1.9.0) to make examples compile. The 1.9.0 development SDK is macOS 27.
- **Missing module:** inspect the resolved source's Package.swift and the target's
  explicit product dependencies. Inspection, Transform and the DSLs need 1.7.0+,
  located streaming 1.8.0+, batches, the store and `selectIndices` 1.9.0+.
- **Unknown signature:** use the immutable source map or matching checkout. Do not
  invent a synonym, unsafe reflection or fallback engine.
- **Inexact conversion:** retain JSONNumber, choose a wider exact integer when
  appropriate, or make finite rounding an explicit application decision.
- **Schema false versus error:** inspect isValid only on completed results.
  Preserve thrown resource/cancellation errors. diagnosticsComplete describes
  diagnostic collection, not semantic evaluation completion.
- **Work exhaustion:** retain the violated metric. Reduce input/scope, choose a
  justified finite policy, or return the error. Do not reset a nested helper.
- **Store build fails:** read `JSONStoreFailure.code`, `phase` and `path`. Fix the
  profile or data; do not disable reference checks or invent missing records.
- **Old position refused:** a rebuilt store issues new positions; look them up again.
- **Stream ends early:** check the actual framing, consume to the required EOF,
  and distinguish earlier yielded records from certification of later syntax.
- **Host does not discover the skill:** confirm its documented repo-scoped path in
  a disposable workspace. Do not change personal/global settings as a side effect.
  Manifest validation, discovery, installation and useful execution are distinct.

Report the dependency commit/tree, commands and actual exits. No successful build
establishes a new performance, RSS, platform or conformance guarantee.
