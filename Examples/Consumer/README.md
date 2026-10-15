# External public API consumer

This is a separate package, using products through a path dependency. It must
never use @testable, package-only internals or the private regex target. The
implemented scenarios assert exact model, codec/Codable, Pointer, both Patch
standards, schema documents/registry, streaming completion and awaited sinks.
Compiler, evaluator and declaration-inspection scenarios execute in this consumer.

Prove imports with Foundation/all products and JSON module/type naming; cover
exact number/object construction, parse/write, typed coding with standard models,
presence, Pointer, both Patch forms, schema compile/validate/inspection, operation
reports and streaming completion. Keep examples aligned with README/DocC.

Run `swift run --package-path Examples/Consumer Consumer` from the repo root.
Each scenario must assert observable results and fail on an error. Compile-time
visibility and runtime assertions together qualify public ergonomics. Examples
use the public APIs documented in README and the product DocC catalogs.

The fifth product, JSONHTML, additionally checks exact highlighted output, checked
Sendable reports, one admission and a cumulative work refusal using public APIs.

The sixth optional product, JSONBridges, is imported explicitly for the E2 numeric
examples. Three synchronized guide fences execute alongside all README examples.
Core-only and unsupported-Float compiler rejections are checked separately by
Scripts/qualify_ergonomics.py in debug and release configurations.
