# Standalone Swift 6.4 capture reductions

These original Apache-2.0 programs need no package or imports. Copy each `.swift.txt`
file to a temporary `.swift` file, then compile with `swiftc -swift-version 6 -c`.
Use object emission: typechecking alone does not run the failing SIL cleanup.
Keep compiler signals distinct from expected diagnostics.

| Program | Swift 6.4 result |
| --- | --- |
| ImplicitCapture | Compiler abort in SILGenCleanup |
| ExplicitCapture | Ordinary borrowed-parameter diagnostic |
| ImplicitLocalFunction | Compiler abort in SILGenCleanup |
| ExplicitLocalFunction | Object emitted |

Only the callback parameter spelling differs within each pair. The public API
gate retains its original inferred programs; these reductions explain the
[compiler diagnosis](../../../Documentation/Architecture/CompositionCompiler.md)
without the library implementation.
