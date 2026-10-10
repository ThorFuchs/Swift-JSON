# External public API consumer

This is a separate package, using products through a path dependency. It must
never use @testable, package-only internals or the private regex target. The
implemented scenarios assert exact model, codec/Codable, Pointer, both Patch
standards, schema documents/registry, streaming completion and awaited sinks.
Compiler/evaluator/inspection scenarios remain required before full G02 passes.

Prove imports with Foundation/all products and JSON module/type naming; cover
exact number/object construction, parse/write, typed coding with standard models,
presence, Pointer, both Patch forms, schema compile/validate/inspection, operation
reports and streaming completion. Keep examples aligned with README/DocC.

Run `swift run --package-path Examples/Consumer Consumer` from the repo root.
Each scenario must assert observable results and fail on an error. Compile-time
visibility and runtime assertions together qualify public ergonomics. The qualification lane copies
only compiled examples into public documentation; no fictional installation URL.
